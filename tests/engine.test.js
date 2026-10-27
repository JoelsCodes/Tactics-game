// Node tests for the rules engine: data integrity and full AI-vs-AI battles on each story map.
const load = require('./load');
const { ctx: C, run } = load();
let fails = 0;
const ok = (c, m) => { if (!c) { fails++; console.log('FAIL', m); } };

// Data integrity
const AB = run('AB'), ITEMS = run('ITEMS'), JOBS = run('JOBS');
const taughtBy = {};
for (const it of Object.values(ITEMS)) for (const id of it.teach) { ok(AB[id], it.id + ' teaches unknown ' + id); taughtBy[id] = 1; }
for (const id in AB) if (AB[id].job) ok(taughtBy[id], 'no item teaches ' + id);
for (const id in AB) if (AB[id].job) ok(JOBS[AB[id].job], id + ' has unknown job');
for (const r of run('RECIPES')) { ok(ITEMS[r.out], 'recipe out ' + r.out); for (const k in r.need) ok(run('LOOT')[k], 'loot ' + k); }
for (const [k, list] of Object.entries(run('STARTER'))) for (const id of list) ok(ITEMS[id], 'starter ' + id);
for (const k in run('MAPS')) { const m = run(`parseMap('${k}')`); ok(m.tiles.every(r => r.length === m.w), k + ' ragged rows'); for (const [x, y] of m.deploy) ok(run('TERRAIN')[m.tiles[y][x].t].pass, k + ' deploy on blocked tile'); }
for (const ms of run('MISSIONS')) { const m = run(`parseMap('${ms.map}')`); for (const e of ms.enemies) ok(run('TERRAIN')[m.tiles[e[3]][e[2]].t].pass, ms.id + ' enemy on blocked tile ' + e); }

// AI vs AI on each story mission, several seeds
function battle(stage, seed) {
  run(`newGame('Test'); G.stage = ${stage};`);
  run(`for (const u of G.units) { while (u.lv < ${1 + stage * 2}) { u.lv++; grow(u, JOBS[u.job].g); } }`);
  const B = run(`B = buildBattle('mission', G.units.slice(0, nextMission().deploy).map(u => u.id)); B`);
  let turns = 0;
  while (!B.over && turns < 400) {
    const a = run('nextActor(B)');
    C.__a = a;
    const st = run('startTurn(B, __a)');
    if (!run('checkEnd(B)') && !st.skip && !a.ko) {
      const p = run('aiPlan(B, __a)');
      C.__p = p;
      if (p.x !== a.x || p.y !== a.y) run('moveUnit(B, __a, __p.x, __p.y)');
      if (p.id) run('perform(B, __a, __p.id, __p.cx, __p.cy)');
    }
    if (!a.jailed) run('endTurn(B, __a)');
    turns++;
  }
  return { over: B.over, turns, cards: B.units.reduce((n, u) => n + u.cards, 0) };
}
const tally = {};
for (let stage = 0; stage < 3; stage++) for (let i = 0; i < 6; i++) {
  const r = battle(stage, i);
  ok(r.over !== 0, 'battle did not end, stage ' + stage);
  const k = 'mission ' + (stage + 1);
  tally[k] = tally[k] || { win: 0, loss: 0, turns: 0, cards: 0 };
  tally[k][r.over === 1 ? 'win' : 'loss']++; tally[k].turns += r.turns; tally[k].cards += r.cards;
}
console.log(tally);
// Results
run(`newGame('T2'); G.stage = 0; B = buildBattle('mission', G.units.slice(0,4).map(u=>u.id)); for (const u of B.units) if (u.team === 1) { u.ko = true; } B.over = 1; R = finishBattle(B);`);
ok(run('G.stage') === 1, 'stage advanced');
ok(run('G.gil') === 1100, 'gil reward ' + run('G.gil'));
// Systems
run(`newGame('T3'); u0 = G.units[0];`);
// Proficiencies: six of them, all level 1, each with its own MP pool at level 1.
ok(run(`Object.keys(PROFS).length === 6 && Object.keys(PROFS).every(k => u0.pf[k].lv === 1 && u0.mpl[k].lv === 1)`), 'six proficiencies at level 1');
run(`G.loc = 'briar'; B = buildBattle('skirmish', G.units.slice(0, 2).map(u => u.id)); a = B.units[1]; a.u.eq.w = 'emberrod'; a.u.eq.o = null; a.s = calcStats(a.u);`);
ok(run(`Object.keys(a.mps).length === 6 && Object.values(a.mps).every(v => v === poolMax(a, 'arcane'))`), 'one MP pool per proficiency');
ok(run(`jobOpen(u0, 'knight') && !jobOpen(u0, 'warrior')`), 'jobs open by race only');
ok(run(`actionSets(u0)[0].list.join() === 'focus,rush' && knownSkills(u0).includes('dodge')`), 'gear teaches skills: ' + run(`knownSkills(u0).join()`));
// Power scales 1 + 0.02 x level; MP is spent from the skill's own pool
run(`a.u.eq.w = 'emberrod'; a.s = calcStats(a.u); t = B.units.find(u => u.team === 1);`);
const p1 = run(`baseAmount(B, a, t, AB.fire)`);
run(`a.u.pf.arcane.lv = 11`);
ok(Math.abs(run(`baseAmount(B, a, t, AB.fire)`) / p1 - 1.22 / 1.02) < 1e-9, 'proficiency level 11 scales power by 1.22/1.02');
run(`a.u.pf.arcane.lv = 1; a.f = 0; a.x = 5; a.y = 5; t.x = 5; t.y = 4; t.hp = 999; perform(B, a, 'fire', t.x, t.y)`);
ok(run(`a.mps.arcane === poolMax(a, 'arcane') - 6 && a.mps.mend === poolMax(a, 'mend')`), 'fire spends only Arcane MP');
ok(run(`a.u.pf.arcane.xp === 1 && a.u.mpl.arcane.xp === 1 && a.u.pf.strike.xp === 0`), 'use trains its proficiency and MP level');
run(`a.u.pf.arcane.xp = PF_NEED(1) - 1; a.u.mpl.arcane.xp = PF_NEED(1) - 1; before = a.mps.arcane; perform(B, a, 'fire', t.x, t.y)`);
ok(run(`a.u.pf.arcane.lv === 2 && a.u.mpl.arcane.lv === 2 && a.mps.arcane === before - 6 + poolMax(a, 'arcane') - Math.round(a.s.mmp * 1.02)`), 'levels rise and the pool grows');
// Job change drops gear the new job cannot use
run(`changeJob(u0, 'archer')`);
ok(run(`u0.eq.w === null && G.inv.ironsword === 1 && u0.eq.o === null`), 'archer unequips sword and shield');
ok(run(`actionSets(u0)[0].list.length === 0`), 'archer has no skills without a bow');
run(`equip(u0, 'w', null); G.inv.huntbow = 1; equip(u0, 'w', 'huntbow')`);
ok(run(`actionSets(u0)[0].list.join() === 'aimlegs,blackout'`), 'bow teaches archer actions: ' + run(`actionSets(u0)[0].list.join()`));
// Vessel: 4-8 field objects, free dome pickup, three uses keep the skill
run(`G.loc = 'briar'; B = buildBattle('skirmish', G.units.slice(0, 2).map(u => u.id)); a = B.units[0]; o = null;`);
ok(run('B.objs.length >= 4 && B.objs.length <= 8'), 'objects spawn: ' + run('B.objs.length'));
ok(run('B.objs.every(o => !unitAt(B, o.x, o.y) && TERRAIN[tileAt(B, o.x, o.y).t].pass && AB[o.skill])'), 'objects on free tiles carrying skills');
run(`o = B.objs[0]; a.x = o.x; a.y = o.y; n0 = B.objs.length; ev = pickup(B, a, o.id)`);
ok(run('a.vessel === o.skill && B.objs.length === n0 - 1 && !a.moved && !a.acted'), 'pickup is free');
ok(run(`actionSets(a.u, a)[0].list.includes(a.vessel)`), 'vessel skill is usable');
run(`far = B.objs.length ? B.objs[0] : null; a.x = 0; a.y = 0;`);
ok(run(`B.objs.every(o => objsInReach(B, a).includes(o) === (Math.hypot(o.x, o.y, tileAt(B, o.x, o.y).h - tileAt(B, 0, 0).h) <= 0.3 * Math.max(B.map.w, B.map.d)))`), 'reach is a dome of 30% of the map');
run(`a.vessel = 'rendpow'; a.u.sk = {}; a.u.ms = {}; a.u.eq.w = null; t = B.units.find(u => u.team === 1);`);
for (let i = 0; i < 3; i++) run(`t.x = a.x; t.y = a.y; t.hp = 999; trainVessel(a, 'rendpow', [])`);
ok(run(`a.u.ms.rendpow === 1 && a.learned[0] === 'rendpow' && !a.u.sk.rendpow`), 'three uses keep a vessel skill for good');
// Base hub: rectangular, known tiles, props on walkable tiles, islands joined by bridges and stairs
const hub = run(`(() => { const M = parseMap('base'); let ok = M.tiles.every(r => r.length === M.w) && M.tiles.every(r => r.every(t => TERRAIN[t.t]));
  const walk = (x, y) => { const t = tileAt({ map: M }, x, y); return t && TERRAIN[t.t].pass; };
  const seen = new Set(['12,8']), q = [[12, 8]];
  while (q.length) { const [x, y] = q.pop(); for (const [dx, dy] of DIRS) { const nx = x + dx, ny = y + dy, k = nx + ',' + ny;
    if (!seen.has(k) && walk(nx, ny) && Math.abs(M.tiles[ny][nx].h - M.tiles[y][x].h) <= 1) { seen.add(k); q.push([nx, ny]); } } }
  let total = 0; for (let y = 0; y < M.d; y++) for (let x = 0; x < M.w; x++) if (walk(x, y)) total++;
  return { ok, w: M.w, d: M.d, total, reach: seen.size, props: M.props.every(p => walk(p.x, p.y)), n: M.props.length }; })()`);
ok(hub.ok && hub.w >= 24 && hub.d >= 20, 'base map is large and well formed ' + hub.w + 'x' + hub.d);
ok(hub.props && hub.n >= 6, 'base props sit on walkable tiles');
ok(hub.reach / hub.total > .9, 'base islands are connected by bridges and stairs: ' + hub.reach + '/' + hub.total);
// Law: two offenses -> yellow then red/jail
run(`G.loc = 'briar'; B = buildBattle('skirmish', G.units.slice(0, 3).map(u => u.id)); B.law = { ban: 'nofight', fav: null }; a = B.units[0]; t = B.units.find(u => u.team === 1); t.x = a.x + 1; t.y = a.y; `);
run(`perform(B, a, 'fight', t.x, t.y)`);
ok(run('a.cards') === 1 && !run('a.jailed'), 'yellow card');
run(`perform(B, a, 'fight', t.x, t.y)`);
ok(run('a.jailed'), 'red card jails');
run(`B.over = 1; R = finishBattle(B)`);
ok(run('u0.jail') === 2 && run('available(u0)') === false, 'jailed for 2 battles');
ok(run('bail(u0) || G.gil < bailCost(u0)'), 'bail');
// Steal weapon from an enemy clan unit
run(`newGame('T4'); G.units[0].job = 'rogue'; G.units[0].eq = { w: 'dagger', o: null, h: null, b: null, a: null }; G.units[0].ms.stealweapon = 1; G.loc = 'briar';
  B = buildBattle('skirmish', [G.units[0].id]); a = B.units[0]; e = newUnit('human', 'squire', 1); e.eq.w = 'ironsword'; t = makeBU(e, 1, a.x + 1, a.y, 3); B.units.push(t);`);
run(`setRng(() => 0.01); perform(B, a, 'stealweapon', t.x, t.y); setRng(Math.random)`);
ok(run(`B.stolen && B.stolen[0] === 'ironsword' && t.u.eq.w === null && t.s.wt === 'fist'`), 'steal weapon');
// Combo power grows with adjacent allies
run(`newGame('T5'); G.loc = 'briar'; B = buildBattle('skirmish', G.units.slice(0, 3).map(u => u.id)); [a, b2, c2] = B.units; t = B.units.find(u => u.team === 1);
  t.x = 5; t.y = 5; a.x = 4; a.y = 5; b2.x = 6; b2.y = 5; c2.x = 5; c2.y = 4;`);
ok(run('comboPower(B, a, t)') === 2, 'combo power with 2 helpers');
// Bazaar
run(`newGame('T6'); G.loot = { wolfpelt: 1, grimfang: 2 }; G.seen = { wolfpelt: 1 }; G.gil = 1000;`);
ok(run(`knownRecipes().some(r => r.id === 'r1') && craft(RECIPES[0])`), 'craft fang knife');
ok(run(`G.inv.fangknife === 1 && shopItems().some(i => i.id === 'fangknife')`), 'crafted item joins shop stock');
// Errands return with rewards
run(`newGame('T7'); G.board = ['e1']; u1 = G.units[1]; sendErrand('e1', u1); tickErrands(); r = tickErrands();`);
ok(run('u1.errand') === null && run('r.length') === 1, 'errand returns after its length');
console.log(fails ? fails + ' failure(s)' : 'all engine tests passed');
process.exit(fails ? 1 : 0);
