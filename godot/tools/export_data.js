// Exports the game data from ../js/data.js to data/game_data.json for the Godot port.
// The JS file stays the source of truth: edit it, then run `node godot/tools/export_data.js`.
const fs = require('fs'), path = require('path');
const { run } = require('../../tests/load')();
const keys = ['PROFS', 'RACES', 'JOBS', 'AB', 'STATUS', 'ELEMENTS', 'WTYPES', 'ITEMS', 'CONS', 'LOOT', 'RECIPES', 'MONSTERS', 'LAWS', 'TERRAIN', 'MAPS', 'MISSIONS', 'LOCS', 'ROUTES', 'ERRANDS', 'NAMES', 'BASE_JOBS', 'STARTER'];
const out = {};
for (const k of keys) out[k] = run(k);
const file = path.join(__dirname, '..', 'data', 'game_data.json');
fs.writeFileSync(file, JSON.stringify(out, null, 1) + '\n');
console.log('wrote', path.relative(process.cwd(), file), (fs.statSync(file).size / 1024).toFixed(1) + ' KB');
