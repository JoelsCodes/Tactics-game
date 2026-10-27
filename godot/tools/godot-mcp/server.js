#!/usr/bin/env node
// godot-mcp: an MCP server (stdio) that lets Claude drive the Godot editor.
// It forwards tool calls to the Claude Bridge editor plugin
// (addons/claude_bridge) over a localhost TCP connection, one JSON per line.
// No dependencies. Env: GODOT_HOST, GODOT_PORT (6550), GODOT_TOKEN, GODOT_TIMEOUT_MS.
'use strict';
const net = require('net');
const readline = require('readline');

const HOST = process.env.GODOT_HOST || '127.0.0.1';
const PORT = +(process.env.GODOT_PORT || 6550);
const TOKEN = process.env.GODOT_TOKEN || '';
const TIMEOUT = +(process.env.GODOT_TIMEOUT_MS || 15000);
const VERSION = '0.1.0';

const str = (description) => ({ type: 'string', description });
const obj = (properties, required = []) => ({ type: 'object', properties, required });
const NODE_PATH = 'Node path relative to the edited scene root, e.g. "Player/Sprite2D". "" or "." is the root.';
const VALUE = 'JSON value. Numbers/bools/strings as-is; vectors and colors as arrays ([10, 20]) or Godot syntax ("Vector2(10, 20)", "Color(1, 0, 0)"); resources as "res://..." paths.';

const TOOLS = [
  ['godot_get_editor_state', 'get_editor_state', 'Project name, Godot version, edited scene, open scenes, selected nodes, whether the game is running. Call this first.', obj({})],
  ['godot_get_scene_tree', 'get_scene_tree', 'Node tree of the scene open in the editor (name, type, path, script, instanced scene).',
    obj({ path: str('Start node (default: root). ' + NODE_PATH), max_depth: { type: 'integer', description: 'Default 32.' } })],
  ['godot_get_node', 'get_node', 'Type, script, children, groups and inspector properties of one node.',
    obj({ path: str(NODE_PATH), filter: str('Only properties whose name contains this text, e.g. "position".') }, ['path'])],
  ['godot_set_property', 'set_property', 'Set an inspector property on a node (undoable with Ctrl+Z in the editor).',
    obj({ path: str(NODE_PATH), property: str('Property name, e.g. "position", "text", "modulate".'), value: { description: VALUE } }, ['path', 'property', 'value'])],
  ['godot_add_node', 'add_node', 'Add a node (built-in type, class_name script type, or an instanced .tscn) to the edited scene (undoable).',
    obj({ parent: str('Parent node, default root. ' + NODE_PATH), type: str('Node class, e.g. "Sprite2D", "Label", or a class_name.'),
      scene: str('Instead of type: a res://....tscn to instance.'), name: str('Node name.'),
      properties: { type: 'object', description: 'Property name -> value to set before adding. ' + VALUE } })],
  ['godot_delete_node', 'delete_node', 'Delete a node and its children from the edited scene (undoable).', obj({ path: str(NODE_PATH) }, ['path'])],
  ['godot_select_nodes', 'select_nodes', 'Select nodes in the editor and show the last one in the inspector.',
    obj({ paths: { type: 'array', items: { type: 'string' }, description: NODE_PATH } }, ['paths'])],
  ['godot_open_scene', 'open_scene', 'Open a scene in the editor.', obj({ path: str('res://....tscn') }, ['path'])],
  ['godot_save_scene', 'save_scene', 'Save the edited scene (optionally to a new path).', obj({ path: str('Optional res://....tscn for "save as".') })],
  ['godot_new_scene', 'new_scene', 'Create a new scene file with one root node and open it.',
    obj({ path: str('res://....tscn'), root_type: str('Root node class, default Node2D.'), root_name: str('Default: from the file name.'),
      overwrite: { type: 'boolean' } }, ['path'])],
  ['godot_list_files', 'list_files', 'List project files (res://). Skips .import files and hidden folders.',
    obj({ dir: str('Default res://'), recursive: { type: 'boolean', description: 'Default true.' },
      extensions: { type: 'array', items: { type: 'string' }, description: 'e.g. ["gd", "tscn"]' } })],
  ['godot_read_file', 'read_file', 'Read a text file from the project (max 1 MB).', obj({ path: str('res://...') }, ['path'])],
  ['godot_write_file', 'write_file', 'Create or overwrite a text file in the project (scripts, shaders, .tscn, etc.). Loaded scripts are reloaded.',
    obj({ path: str('res://...'), content: str('Full file content.') }, ['path', 'content'])],
  ['godot_validate_script', 'validate_script', 'Check whether GDScript compiles. Pass source or path. Error details only appear in the Godot Output panel.',
    obj({ source: str('GDScript source.'), path: str('res://....gd') })],
  ['godot_list_node_types', 'list_node_types', 'List instantiable node classes (and project class_name scripts) under a base class.',
    obj({ base: str('Default "Node". e.g. "Control", "Node3D".'), filter: str('Substring, e.g. "button".') })],
  ['godot_run_project', 'run_project', 'Run the game from the editor.', obj({ scene: str('"main" (default), "current", or a res://....tscn') })],
  ['godot_stop_project', 'stop_project', 'Stop the running game.', obj({})],
  ['godot_screenshot', 'screenshot', 'Screenshot of the editor 2D/3D viewport or the whole editor window.',
    obj({ viewport: { type: 'string', enum: ['2d', '3d', 'editor'], description: 'Default 2d.' }, max_width: { type: 'integer', description: 'Default 1280.' } })],
  ['godot_execute', 'execute', 'Run GDScript inside the editor (body of func run(editor: EditorPlugin)); the return value is sent back. Disabled unless the project setting claude_bridge/allow_execute is on.',
    obj({ code: str('GDScript statements, e.g. "return EditorInterface.get_open_scenes()".') }, ['code'])],
].map(([name, method, description, inputSchema]) => ({ name, method, description, inputSchema }));

// ---------- bridge connection ----------
let sock = null, connecting = null, nextId = 1;
const pending = new Map();

function connect() {
  if (sock) return Promise.resolve(sock);
  if (connecting) return connecting;
  connecting = new Promise((resolve, reject) => {
    const s = net.createConnection({ host: HOST, port: PORT });
    let buf = '';
    s.setEncoding('utf8');
    s.once('connect', () => { sock = s; connecting = null; resolve(s); });
    s.on('error', (e) => { if (sock !== s) { connecting = null; reject(e); } });
    s.on('data', (d) => {
      buf += d;
      let i;
      while ((i = buf.indexOf('\n')) >= 0) {
        const line = buf.slice(0, i); buf = buf.slice(i + 1);
        let msg; try { msg = JSON.parse(line); } catch { continue; }
        const p = pending.get(msg.id);
        if (!p) continue;
        pending.delete(msg.id); clearTimeout(p.timer);
        if (msg.error != null) p.reject(new Error(String(msg.error))); else p.resolve(msg.result);
      }
    });
    s.on('close', () => {
      if (sock === s) sock = null;
      for (const [id, p] of pending) { clearTimeout(p.timer); p.reject(new Error('connection to Godot closed')); pending.delete(id); }
    });
  });
  return connecting;
}

async function callGodot(method, params) {
  let s;
  try { s = await connect(); } catch (e) {
    throw new Error(`Could not reach the Godot editor at ${HOST}:${PORT} (${e.code || e.message}). Open the project in Godot and enable "Claude Bridge" under Project > Project Settings > Plugins.`);
  }
  const id = nextId++;
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => { pending.delete(id); reject(new Error(`Godot did not answer ${method} within ${TIMEOUT} ms`)); }, TIMEOUT);
    pending.set(id, { resolve, reject, timer });
    const msg = { id, method, params: params || {} };
    if (TOKEN) msg.token = TOKEN;
    s.write(JSON.stringify(msg) + '\n');
  });
}

// ---------- MCP (JSON-RPC 2.0 over stdio, one message per line) ----------
const send = (m) => process.stdout.write(JSON.stringify(m) + '\n');
const reply = (id, result) => send({ jsonrpc: '2.0', id, result });
const fail = (id, code, message) => send({ jsonrpc: '2.0', id, error: { code, message } });

async function toolCall(id, { name, arguments: args }) {
  const tool = TOOLS.find((t) => t.name === name);
  if (!tool) return fail(id, -32602, `Unknown tool: ${name}`);
  try {
    const result = await callGodot(tool.method, args);
    if (result && typeof result.png_base64 === 'string') {
      return reply(id, { content: [{ type: 'image', data: result.png_base64, mimeType: 'image/png' },
        { type: 'text', text: `${result.width}x${result.height}` }] });
    }
    reply(id, { content: [{ type: 'text', text: JSON.stringify(result, null, 2) }] });
  } catch (e) {
    reply(id, { content: [{ type: 'text', text: e.message }], isError: true });
  }
}

function handle(msg) {
  const { id, method, params } = msg;
  if (id === undefined || id === null) return; // notification
  switch (method) {
    case 'initialize':
      return reply(id, {
        protocolVersion: (params && params.protocolVersion) || '2025-06-18',
        capabilities: { tools: {} },
        serverInfo: { name: 'godot-mcp', version: VERSION },
        instructions: 'Controls the open Godot 4 editor. Start with godot_get_editor_state and godot_get_scene_tree. Node paths are relative to the edited scene root. Save with godot_save_scene after editing.',
      });
    case 'ping': return reply(id, {});
    case 'tools/list': return reply(id, { tools: TOOLS.map(({ name, description, inputSchema }) => ({ name, description, inputSchema })) });
    case 'tools/call': return toolCall(id, params || {});
    case 'resources/list': return reply(id, { resources: [] });
    case 'prompts/list': return reply(id, { prompts: [] });
    default: return fail(id, -32601, `Method not found: ${method}`);
  }
}

const rl = readline.createInterface({ input: process.stdin });
rl.on('line', (line) => {
  if (!line.trim()) return;
  let msg;
  try { msg = JSON.parse(line); } catch { return fail(null, -32700, 'Parse error'); }
  if (Array.isArray(msg)) msg.forEach(handle); else handle(msg);
});
rl.on('close', () => process.exit(0));
process.stderr.write(`godot-mcp ${VERSION}: bridge at ${HOST}:${PORT}\n`);
