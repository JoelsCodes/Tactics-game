@tool
extends EditorPlugin
## Claude Bridge: a tiny JSON-over-TCP server inside the Godot editor.
## The godot-mcp server (server.js) connects here and turns Claude's MCP tool
## calls into requests. One request per line: {"id", "method", "params", "token"?}
## One reply per line: {"id", "result"} or {"id", "error"}.
## Listens on 127.0.0.1 only. Scene edits go through the editor's undo/redo.

const DEFAULT_PORT := 6550
const MAX_FILE_BYTES := 1048576
const MAX_LIST := 2000

var _server: TCPServer
var _clients: Array = []
var _port := DEFAULT_PORT
# Some editor calls (save_scene shows a progress dialog) run the main loop
# again from inside a request; don't handle more requests until it returns.
var _busy := false


func _enter_tree() -> void:
	_add_setting("claude_bridge/port", DEFAULT_PORT, TYPE_INT)
	_add_setting("claude_bridge/token", "", TYPE_STRING)
	_add_setting("claude_bridge/allow_execute", false, TYPE_BOOL)
	_port = int(ProjectSettings.get_setting("claude_bridge/port", DEFAULT_PORT))
	var env_port := OS.get_environment("CLAUDE_BRIDGE_PORT")
	if env_port.is_valid_int():
		_port = env_port.to_int()
	_server = TCPServer.new()
	var err := _server.listen(_port, "127.0.0.1")
	if err != OK:
		push_error("Claude Bridge: could not listen on 127.0.0.1:%d (%s)" % [_port, error_string(err)])
		_server = null
		return
	print("Claude Bridge listening on 127.0.0.1:%d" % _port)


func _exit_tree() -> void:
	for c in _clients:
		c.peer.disconnect_from_host()
	_clients.clear()
	if _server:
		_server.stop()
		_server = null


func _add_setting(key: String, value: Variant, type: int) -> void:
	if not ProjectSettings.has_setting(key):
		ProjectSettings.set_setting(key, value)
	ProjectSettings.set_initial_value(key, value)
	ProjectSettings.add_property_info({"name": key, "type": type})


func _process(_delta: float) -> void:
	if _server == null or _busy:
		return
	while _server.is_connection_available():
		_clients.append({"peer": _server.take_connection(), "buf": PackedByteArray()})
	for c in _clients.duplicate():
		var peer: StreamPeerTCP = c.peer
		peer.poll()
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			_clients.erase(c)
			continue
		var buf: PackedByteArray = c.buf
		var n := peer.get_available_bytes()
		if n > 0:
			var got: Array = peer.get_data(n)
			if got[0] == OK:
				buf.append_array(got[1])
		while true:
			var i := buf.find(10)
			if i < 0:
				break
			var line := buf.slice(0, i).get_string_from_utf8()
			buf = buf.slice(i + 1)
			c.buf = buf
			if line.strip_edges() != "":
				_busy = true
				_handle_line(peer, line)
				_busy = false
		c.buf = buf


func _handle_line(peer: StreamPeerTCP, line: String) -> void:
	var msg = JSON.parse_string(line)
	if typeof(msg) != TYPE_DICTIONARY:
		_send(peer, {"id": null, "error": "invalid JSON"})
		return
	var id = msg.get("id")
	var token := str(ProjectSettings.get_setting("claude_bridge/token", ""))
	if token != "" and str(msg.get("token", "")) != token:
		_send(peer, {"id": id, "error": "bad or missing token (claude_bridge/token)"})
		return
	var params = msg.get("params", {})
	if typeof(params) != TYPE_DICTIONARY:
		params = {}
	var result = _dispatch(str(msg.get("method", "")), params)
	if result is Dictionary and result.has("__error"):
		_send(peer, {"id": id, "error": result.__error})
	else:
		_send(peer, {"id": id, "result": result})


func _send(peer: StreamPeerTCP, obj: Dictionary) -> void:
	peer.put_data((JSON.stringify(obj) + "\n").to_utf8_buffer())


func _err(msg: String) -> Dictionary:
	return {"__error": msg}


func _dispatch(method: String, p: Dictionary) -> Variant:
	match method:
		"ping": return {"pong": true, "godot": Engine.get_version_info().string}
		"get_editor_state": return _get_editor_state()
		"get_scene_tree": return _get_scene_tree(p)
		"get_node": return _get_node(p)
		"set_property": return _set_property(p)
		"add_node": return _add_node(p)
		"delete_node": return _delete_node(p)
		"select_nodes": return _select_nodes(p)
		"open_scene": return _open_scene(p)
		"save_scene": return _save_scene(p)
		"new_scene": return _new_scene(p)
		"list_files": return _list_files(p)
		"read_file": return _read_file(p)
		"write_file": return _write_file(p)
		"validate_script": return _validate_script(p)
		"list_node_types": return _list_node_types(p)
		"run_project": return _run_project(p)
		"stop_project": return _stop_project()
		"screenshot": return _screenshot(p)
		"execute": return _execute(p)
	return _err("unknown method: " + method)


# ---------- helpers ----------

func _root() -> Node:
	return EditorInterface.get_edited_scene_root()


func _rel(n: Node) -> String:
	var root := _root()
	return str(root.get_path_to(n)) if root else str(n.name)


## Finds a node in the edited scene. "" or "." is the scene root.
func _node(path: Variant) -> Node:
	var root := _root()
	if root == null:
		return null
	var s := str(path if path != null else "")
	if s == "" or s == "." or s == str(root.name):
		return root
	if s.begins_with(str(root.name) + "/"):
		s = s.substr(str(root.name).length() + 1)
	return root.get_node_or_null(NodePath(s))


func _res_path(p: Variant) -> String:
	var s := str(p if p != null else "").strip_edges()
	if s == "":
		return ""
	if not s.begins_with("res://"):
		s = "res://" + s.trim_prefix("/")
	if ".." in s.split("/"):
		return ""
	return s.simplify_path()


func _ser(v: Variant, depth := 0) -> Variant:
	match typeof(v):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT:
			return v
		TYPE_STRING, TYPE_STRING_NAME, TYPE_NODE_PATH:
			var s := str(v)
			return s if s.length() <= 4000 else s.substr(0, 4000) + "...(truncated)"
		TYPE_OBJECT:
			if not is_instance_valid(v):
				return null
			if v is Node:
				return {"node": _rel(v)}
			if v is Resource:
				return {"resource": v.get_class(), "path": v.resource_path} if v.resource_path != "" else {"resource": v.get_class()}
			return {"object": v.get_class()}
		TYPE_DICTIONARY:
			if depth > 4:
				return "{...}"
			var d := {}
			for k in v:
				d[str(k)] = _ser(v[k], depth + 1)
			return d
		TYPE_PACKED_BYTE_ARRAY:
			return {"bytes": v.size()}
	if v is Array or typeof(v) >= TYPE_PACKED_INT32_ARRAY:
		if depth > 4 or v.size() > 256:
			return "[%d items]" % v.size()
		var a := []
		for x in v:
			a.append(_ser(x, depth + 1))
		return a
	return var_to_str(v)


const _VECTORISH := [TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_VECTOR3, TYPE_VECTOR3I, TYPE_VECTOR4, TYPE_VECTOR4I, TYPE_COLOR, TYPE_RECT2, TYPE_RECT2I, TYPE_QUATERNION]

## Turns a JSON value into a Godot value of the target property type.
## Strings like "Vector2(10, 20)" or "Color(1, 0, 0, 1)" go through str_to_var,
## number arrays become vectors/colors, "res://..." loads a resource.
func _parse_value(raw: Variant, type: int) -> Variant:
	if typeof(raw) == TYPE_STRING:
		if type == TYPE_OBJECT:
			if raw == "":
				return null
			if raw.begins_with("res://"):
				return load(raw)
		elif type not in [TYPE_STRING, TYPE_STRING_NAME, TYPE_NODE_PATH]:
			var parsed = str_to_var(raw)
			if parsed != null:
				raw = parsed
	elif typeof(raw) == TYPE_ARRAY and type in _VECTORISH:
		var parts := PackedStringArray()
		for x in raw:
			parts.append(str(x))
		var parsed = str_to_var("%s(%s)" % [type_string(type), ", ".join(parts)])
		if parsed != null:
			return parsed
	if type == TYPE_NIL or type == TYPE_OBJECT:
		return raw
	return type_convert(raw, type)


func _prop_type(obj: Object, prop: String) -> int:
	for info in obj.get_property_list():
		if info.name == prop:
			return info.type
	return -1


func _global_class_script(cls: String) -> Script:
	for info in ProjectSettings.get_global_class_list():
		if info["class"] == cls:
			return load(info.path)
	return null


func _instantiate_type(type: String) -> Variant:
	var scr := _global_class_script(type)
	if scr:
		var base: String = scr.get_instance_base_type()
		if not ClassDB.is_parent_class(base, "Node"):
			return _err("%s does not extend Node" % type)
		var n: Node = ClassDB.instantiate(base)
		n.set_script(scr)
		return n
	if not ClassDB.class_exists(type) or not ClassDB.is_parent_class(type, "Node"):
		return _err("unknown Node type: %s (try godot_list_node_types)" % type)
	if not ClassDB.can_instantiate(type):
		return _err("%s cannot be instantiated (abstract)" % type)
	return ClassDB.instantiate(type)


# ---------- editor / scene ----------

func _get_editor_state() -> Dictionary:
	var root := _root()
	var sel := []
	for n in EditorInterface.get_selection().get_selected_nodes():
		sel.append(_rel(n))
	return {
		"project": ProjectSettings.get_setting("application/config/name", ""),
		"project_path": ProjectSettings.globalize_path("res://"),
		"godot": Engine.get_version_info().string,
		"main_scene": ProjectSettings.get_setting("application/run/main_scene", ""),
		"edited_scene": (root.scene_file_path if root else null),
		"edited_root": (str(root.name) if root else null),
		"open_scenes": Array(EditorInterface.get_open_scenes()),
		"selected": sel,
		"playing": EditorInterface.is_playing_scene(),
		"execute_enabled": bool(ProjectSettings.get_setting("claude_bridge/allow_execute", false)),
	}


func _get_scene_tree(p: Dictionary) -> Variant:
	var root := _root()
	if root == null:
		return _err("no scene is open in the editor")
	var start := _node(p.get("path", ""))
	if start == null:
		return _err("node not found: %s" % p.get("path"))
	return _tree(start, root, 0, int(p.get("max_depth", 32)))


func _tree(n: Node, root: Node, depth: int, max_depth: int) -> Dictionary:
	var d := {"name": str(n.name), "type": n.get_class(), "path": str(root.get_path_to(n))}
	if n.get_script():
		d.script = n.get_script().resource_path
	if n != root and n.scene_file_path != "":
		d.instance = n.scene_file_path
	var kids := []
	for c in n.get_children():
		if c.owner == root:
			kids.append(c)
	if kids.is_empty():
		return d
	if depth >= max_depth:
		d.child_count = kids.size()
		return d
	d.children = []
	for c in kids:
		d.children.append(_tree(c, root, depth + 1, max_depth))
	return d


func _get_node(p: Dictionary) -> Variant:
	var node := _node(p.get("path", ""))
	if node == null:
		return _err("node not found: %s" % p.get("path") if _root() else "no scene is open in the editor")
	var filter := str(p.get("filter", "")).to_lower()
	var props := {}
	var skip := PROPERTY_USAGE_GROUP | PROPERTY_USAGE_CATEGORY | PROPERTY_USAGE_SUBGROUP
	for info in node.get_property_list():
		if not (info.usage & PROPERTY_USAGE_EDITOR) or (info.usage & skip):
			continue
		if filter != "" and filter not in str(info.name).to_lower():
			continue
		props[info.name] = _ser(node.get(info.name))
	var kids := []
	for c in node.get_children():
		if c.owner == _root():
			kids.append(str(c.name))
	return {
		"path": _rel(node),
		"type": node.get_class(),
		"script": (node.get_script().resource_path if node.get_script() else null),
		"children": kids,
		"groups": Array(node.get_groups()).map(func(g): return str(g)),
		"properties": props,
	}


func _set_property(p: Dictionary) -> Variant:
	var node := _node(p.get("path", ""))
	if node == null:
		return _err("node not found: %s" % p.get("path"))
	var prop := str(p.get("property", ""))
	var type := _prop_type(node, prop)
	if type < 0:
		return _err("%s (%s) has no property '%s'" % [_rel(node), node.get_class(), prop])
	var value = _parse_value(p.get("value"), type)
	var ur := get_undo_redo()
	ur.create_action("Claude: set %s.%s" % [node.name, prop])
	ur.add_do_property(node, prop, value)
	ur.add_undo_property(node, prop, node.get(prop))
	ur.commit_action()
	return {"path": _rel(node), "property": prop, "value": _ser(node.get(prop))}


func _add_node(p: Dictionary) -> Variant:
	var root := _root()
	if root == null:
		return _err("no scene is open in the editor")
	var parent := _node(p.get("parent", "."))
	if parent == null:
		return _err("parent not found: %s" % p.get("parent"))
	var node: Node
	var scene := _res_path(p.get("scene", ""))
	if scene != "":
		var ps = load(scene)
		if not ps is PackedScene:
			return _err("not a scene: %s" % scene)
		node = ps.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	else:
		var made = _instantiate_type(str(p.get("type", "Node")))
		if made is Dictionary:
			return made
		node = made
	if str(p.get("name", "")) != "":
		node.name = str(p.name)
	var props = p.get("properties", {})
	if typeof(props) == TYPE_DICTIONARY:
		for k in props:
			var type := _prop_type(node, k)
			if type < 0:
				node.free()
				return _err("%s has no property '%s'" % [node.get_class(), k])
			node.set(k, _parse_value(props[k], type))
	var ur := get_undo_redo()
	ur.create_action("Claude: add %s" % node.name)
	ur.add_do_method(parent, "add_child", node, true)
	ur.add_do_method(node, "set_owner", root)
	ur.add_do_reference(node)
	ur.add_undo_method(parent, "remove_child", node)
	ur.commit_action()
	return {"path": _rel(node), "type": node.get_class(), "name": str(node.name)}


func _delete_node(p: Dictionary) -> Variant:
	var root := _root()
	var node := _node(p.get("path", ""))
	if node == null:
		return _err("node not found: %s" % p.get("path"))
	if node == root:
		return _err("refusing to delete the scene root")
	var parent := node.get_parent()
	var owned := [node]
	owned.append_array(node.find_children("*", "", true, false).filter(func(c): return c.owner == root))
	var path := _rel(node)
	var ur := get_undo_redo()
	ur.create_action("Claude: delete %s" % node.name)
	ur.add_do_method(parent, "remove_child", node)
	ur.add_undo_method(parent, "add_child", node, true)
	ur.add_undo_method(parent, "move_child", node, node.get_index())
	for c in owned:
		ur.add_undo_method(c, "set_owner", root)
	ur.add_undo_reference(node)
	ur.commit_action()
	return {"deleted": path}


func _select_nodes(p: Dictionary) -> Variant:
	var sel := EditorInterface.get_selection()
	sel.clear()
	var done := []
	for path in p.get("paths", []):
		var n := _node(path)
		if n == null:
			return _err("node not found: %s" % path)
		sel.add_node(n)
		done.append(_rel(n))
	if not done.is_empty():
		EditorInterface.edit_node(_node(done[-1]))
	return {"selected": done}


func _open_scene(p: Dictionary) -> Variant:
	var path := _res_path(p.get("path"))
	if path == "" or not ResourceLoader.exists(path):
		return _err("scene not found: %s" % p.get("path"))
	EditorInterface.open_scene_from_path(path)
	return {"edited_scene": _root().scene_file_path if _root() else null}


func _save_scene(p: Dictionary) -> Variant:
	var root := _root()
	if root == null:
		return _err("no scene is open in the editor")
	var path := _res_path(p.get("path", ""))
	if path != "":
		EditorInterface.save_scene_as(path)
		return {"saved": path}
	if root.scene_file_path == "":
		return _err("scene has never been saved; pass a path")
	var err := EditorInterface.save_scene()
	if err != OK:
		return _err("save failed: " + error_string(err))
	return {"saved": root.scene_file_path}


func _new_scene(p: Dictionary) -> Variant:
	var path := _res_path(p.get("path"))
	if path == "" or not path.ends_with(".tscn"):
		return _err("path must be a res://....tscn file")
	if FileAccess.file_exists(path) and not p.get("overwrite", false):
		return _err("%s already exists (pass overwrite=true)" % path)
	var made = _instantiate_type(str(p.get("root_type", "Node2D")))
	if made is Dictionary:
		return made
	var node: Node = made
	node.name = str(p.get("root_name", path.get_file().get_basename().to_pascal_case()))
	var ps := PackedScene.new()
	ps.pack(node)
	node.free()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := ResourceSaver.save(ps, path)
	if err != OK:
		return _err("could not save %s: %s" % [path, error_string(err)])
	EditorInterface.get_resource_filesystem().update_file(path)
	EditorInterface.open_scene_from_path(path)
	return {"created": path, "root": str(_root().name) if _root() else null}


# ---------- files ----------

func _list_files(p: Dictionary) -> Variant:
	var dir := _res_path(p.get("dir", "res://"))
	if dir == "":
		return _err("bad dir")
	if not DirAccess.dir_exists_absolute(dir):
		return _err("no such directory: %s" % dir)
	var exts := []
	for e in p.get("extensions", []):
		exts.append(str(e).trim_prefix(".").to_lower())
	var out := []
	_walk(dir, bool(p.get("recursive", true)), exts, out)
	return {"dir": dir, "files": out, "truncated": out.size() >= MAX_LIST}


func _walk(dir: String, recursive: bool, exts: Array, out: Array) -> void:
	var da := DirAccess.open(dir)
	if da == null:
		return
	da.include_hidden = false
	for d in da.get_directories():
		if out.size() >= MAX_LIST:
			return
		if d.begins_with("."):
			continue
		if recursive:
			_walk(dir.path_join(d), recursive, exts, out)
		else:
			out.append(dir.path_join(d) + "/")
	for f in da.get_files():
		if out.size() >= MAX_LIST:
			return
		if f.ends_with(".import") or f.ends_with(".uid"):
			continue
		if exts.is_empty() or f.get_extension().to_lower() in exts:
			out.append(dir.path_join(f))


func _read_file(p: Dictionary) -> Variant:
	var path := _res_path(p.get("path"))
	if path == "" or not FileAccess.file_exists(path):
		return _err("file not found: %s" % p.get("path"))
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return _err("cannot open %s" % path)
	if f.get_length() > MAX_FILE_BYTES:
		return _err("%s is larger than 1 MB" % path)
	return {"path": path, "content": f.get_as_text()}


func _write_file(p: Dictionary) -> Variant:
	var path := _res_path(p.get("path"))
	if path == "" or path.begins_with("res://.godot/"):
		return _err("bad path: %s" % p.get("path"))
	var content := str(p.get("content", ""))
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return _err("cannot write %s: %s" % [path, error_string(FileAccess.get_open_error())])
	f.store_string(content)
	f.close()
	# Scripts already loaded in the editor keep their old source until reloaded.
	if ResourceLoader.has_cached(path):
		var res = load(path)
		if res is Script:
			res.source_code = content
			res.reload(true)
	EditorInterface.get_resource_filesystem().update_file(path)
	return {"written": path, "bytes": content.to_utf8_buffer().size()}


func _validate_script(p: Dictionary) -> Variant:
	var src := str(p.get("source", ""))
	if src == "":
		var path := _res_path(p.get("path"))
		if path == "" or not FileAccess.file_exists(path):
			return _err("pass source or an existing path")
		src = FileAccess.get_file_as_string(path)
	var s := GDScript.new()
	s.source_code = src
	var err := s.reload()
	return {"ok": err == OK, "error": (null if err == OK else error_string(err) + " (details are in the Godot Output panel)")}


func _list_node_types(p: Dictionary) -> Variant:
	var base := str(p.get("base", "Node"))
	if not ClassDB.class_exists(base):
		return _err("unknown class: %s" % base)
	var filter := str(p.get("filter", "")).to_lower()
	var names := []
	for c in [base] + Array(ClassDB.get_inheriters_from_class(base)):
		if ClassDB.can_instantiate(c) and (filter == "" or filter in c.to_lower()):
			names.append(c)
	names.sort()
	var custom := []
	for info in ProjectSettings.get_global_class_list():
		var scr = load(info.path)
		if scr is Script and ClassDB.is_parent_class(scr.get_instance_base_type(), base):
			if filter == "" or filter in str(info["class"]).to_lower():
				custom.append({"class": info["class"], "base": info.base, "path": info.path})
	return {"types": names.slice(0, 400), "truncated": names.size() > 400, "script_classes": custom}


# ---------- running ----------

func _run_project(p: Dictionary) -> Variant:
	var scene := str(p.get("scene", "main"))
	if scene == "main":
		if str(ProjectSettings.get_setting("application/run/main_scene", "")) == "":
			return _err("no main scene set (Project Settings > Application > Run)")
		EditorInterface.play_main_scene()
	elif scene == "current":
		if _root() == null:
			return _err("no scene is open in the editor")
		EditorInterface.play_current_scene()
	else:
		var path := _res_path(scene)
		if path == "" or not ResourceLoader.exists(path):
			return _err("scene not found: %s" % scene)
		EditorInterface.play_custom_scene(path)
	return {"playing": scene}


func _stop_project() -> Variant:
	var was := EditorInterface.is_playing_scene()
	EditorInterface.stop_playing_scene()
	return {"stopped": was}


func _screenshot(p: Dictionary) -> Variant:
	var vp: Viewport
	match str(p.get("viewport", "2d")):
		"2d": vp = EditorInterface.get_editor_viewport_2d()
		"3d": vp = EditorInterface.get_editor_viewport_3d(0)
		"editor": vp = EditorInterface.get_base_control().get_viewport()
		_: return _err("viewport must be 2d, 3d or editor")
	var tex: Texture2D = vp.get_texture() if vp else null
	var img: Image = tex.get_image() if tex else null
	if img == null or img.is_empty():
		return _err("no image (is the editor running headless?)")
	var max_w := int(p.get("max_width", 1280))
	if img.get_width() > max_w:
		img.resize(max_w, int(img.get_height() * float(max_w) / img.get_width()))
	return {"png_base64": Marshalls.raw_to_base64(img.save_png_to_buffer()), "width": img.get_width(), "height": img.get_height()}


func _execute(p: Dictionary) -> Variant:
	if not ProjectSettings.get_setting("claude_bridge/allow_execute", false):
		return _err("execute is disabled; turn on Project Settings > claude_bridge/allow_execute (Advanced Settings) to allow it")
	var src := "@tool\nextends RefCounted\n\nfunc run(editor: EditorPlugin):\n"
	for line in str(p.get("code", "")).split("\n"):
		src += "\t" + line + "\n"
	src += "\treturn null\n"
	var s := GDScript.new()
	s.source_code = src
	var err := s.reload()
	if err != OK:
		return _err("code did not compile: %s (details are in the Godot Output panel)" % error_string(err))
	return {"result": _ser(s.new().run(self))}
