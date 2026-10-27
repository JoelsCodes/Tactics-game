// Records AI-vs-AI battles from the JS engine with a seeded RNG, so the Godot port
// can replay the same battles and check it gets identical results (tests/run_tests.gd).
// Writes tests/fixtures/trace_<stage>_<seed>.json. Run: node godot/tools/js_trace.js
const fs = require('fs'), path = require('path');
const { ctx: C, run } = require('../../tests/load')();
// Same LCG as Rules.seed() in scripts/rules.gd.
run(`var __s = 0; function seedLcg(n) { __s = n >>> 0; setRng(() => { __s = (Math.imul(__s, 1103515245) + 12345) >>> 0; return __s / 4294967296; }); }`);
const snap = 'B.units.map(u => [u.id, u.x, u.y, u.f, u.hp, mpTotal(u), Math.round(u.ct * 1000) / 1000, u.ko ? 1 : 0, u.jailed ? 1 : 0, Object.keys(u.st).sort().join(","), u.vessel || ""]).concat([B.objs.map(o => o.id + o.x + o.y + o.skill).join()])';

function record(stage, seed) {
  run(`seedLcg(${seed}); G = { units: [] };
    for (const [race, job, name] of [['human', 'squire', 'Rook'], ['saurian', 'warrior', 'Bram'], ['sylph', 'archer', 'Liss'], ['mossling', 'animist', 'Pip'], ['nuwa', 'sage', 'Oro'], ['human', 'mender', 'Tamsin']]) addUnit(newUnit(race, job, 1, name), true);
    for (const u of G.units) while (u.lv < ${1 + stage * 2}) { u.lv++; grow(u, JOBS[u.job].g); }
    __m = MISSIONS[${stage}];
    B = makeBattle({ map: __m.map, party: G.units.slice(0, __m.deploy), enemies: __m.enemies.map(enemyFromSpec), law: __m.law, inv: { potion: 6, phoenix: 2, antidote: 2 }, mission: __m });`);
  const start = run(`B.units.map(u => [u.id, u.name, u.team, u.x, u.y, u.f, u.s.mhp, u.s.atk, u.s.spd, u.ct])`);
  const turns = [];
  while (!run('B.over') && turns.length < 400) {
    const a = run('__a = nextActor(B)');
    const st = run('__st = startTurn(B, __a)');
    let plan = null;
    if (!run('checkEnd(B)') && !st.skip && !a.ko) {
      plan = run(`__p = aiPlan(B, __a); if (__p.x !== __a.x || __p.y !== __a.y) moveUnit(B, __a, __p.x, __p.y); if (__p.id) perform(B, __a, __p.id, __p.cx, __p.cy);
        if (__a.team === 1 && !__a.ko && !__a.jailed) { const f = nearestFoe(B, __a); if (f) __a.f = faceToward(__a, f.x, f.y); } __p`);
    }
    run('if (!__a.ko && !__a.jailed) endTurn(B, __a); else if (__a.ko) __a.ct = 0;');
    turns.push({ actor: a.id, skip: !!st.skip, plan: plan && { x: plan.x, y: plan.y, id: plan.id, cx: plan.cx === undefined ? null : plan.cx, cy: plan.cy === undefined ? null : plan.cy }, units: run(snap) });
  }
  return { stage, seed, over: run('B.over'), start, turns };
}
const dir = path.join(__dirname, '..', 'tests', 'fixtures');
for (const f of fs.readdirSync(dir)) if (f.startsWith('trace_')) fs.unlinkSync(path.join(dir, f));
// Two finished battles per story mission (some seeds stall: AI-vs-AI can loop on Lullaby).
for (let stage = 0; stage < 3; stage++) {
  for (let seed = 1, kept = 0; kept < 2 && seed < 50; seed++) {
    const t = record(stage, seed);
    if (!t.over) continue;
    kept++;
    fs.writeFileSync(path.join(dir, `trace_${stage}_${seed}.json`), JSON.stringify(t) + '\n');
    console.log(`mission ${stage + 1} seed ${seed}: ${t.turns.length} turns, ${t.over === 1 ? 'win' : 'loss'}`);
  }
}
