// Exports the game data from ../js/data.js to data/game_data.json for the Godot port.
// The JS file stays the source of truth: edit it, then run `node godot/tools/export_data.js`.
if (!process.argv.includes('--force')) {
  console.error('Retired: the Godot port is now the source of truth (godot/data/game_data.json, scripts/rules.gd). Running this would overwrite it with the web version. Pass --force only if you really mean that.');
  process.exit(1);
}
const fs = require('fs'), path = require('path');
const { run } = require('../../tests/load')();
const keys = ['PROFS', 'RACES', 'JOBS', 'AB', 'STATUS', 'ELEMENTS', 'WTYPES', 'ITEMS', 'CONS', 'LOOT', 'RECIPES', 'MONSTERS', 'LAWS', 'TERRAIN', 'MAPS', 'MISSIONS', 'LOCS', 'ROUTES', 'ERRANDS', 'NAMES', 'BASE_JOBS', 'STARTER'];
const out = {};
for (const k of keys) out[k] = run(k);
const file = path.join(__dirname, '..', 'data', 'game_data.json');
fs.writeFileSync(file, JSON.stringify(out, null, 1) + '\n');
console.log('wrote', path.relative(process.cwd(), file), (fs.statSync(file).size / 1024).toFixed(1) + ' KB');
