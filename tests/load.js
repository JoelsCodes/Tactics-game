// Loads the game scripts into one Node context (they are plain browser scripts sharing globals).
const fs = require('fs'), path = require('path'), vm = require('vm');
module.exports = function load() {
  const store = {};
  const ctx = vm.createContext({ console, localStorage: { getItem: k => store[k] || null, setItem: (k, v) => { store[k] = v; } } });
  for (const f of ['data.js', 'engine.js', 'game.js']) vm.runInContext(fs.readFileSync(path.join(__dirname, '../js', f), 'utf8'), ctx, { filename: f });
  return { ctx, run: s => vm.runInContext(s, ctx) };
};
