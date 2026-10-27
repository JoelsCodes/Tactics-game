// Hollowmark Tactics: rules engine. No DOM access, so it also runs under Node for tests.
'use strict';

const DIRS = [[0, -1], [1, 0], [0, 1], [-1, 0]]; // 0 N, 1 E, 2 S, 3 W (grid space)
const SLOTS = ['w', 'o', 'h', 'b', 'a'];
const FIGHT = { id: 'fight', name: 'Fight', fx: 'atk', pw: 1, rng: 'w', cat: 'phys', tgt: 'foe', mp: 0, aoe: 0, desc: 'Attack with the equipped weapon.' };
const COMBO = { id: 'combo', name: 'Combo', fx: 'atk', pw: 1, rng: 1, cat: 'phys', tgt: 'foe', mp: 0, aoe: 0, combo: 1, jpCost: 3, desc: 'Spend 3 JP. +50% damage for every ally next to the target.' };

let rnd = Math.random;
function setRng(f) { rnd = f; }
function ri(n) { return Math.floor(rnd() * n); }
function pick(a) { return a[ri(a.length)]; }
function clamp(v, a, b) { return Math.max(a, Math.min(b, v)); }
function dist(a, b) { return Math.abs(a.x - b.x) + Math.abs(a.y - b.y); }

// ---------- Units ----------
function grow(u, g) {
  for (const k of ['hp', 'mp', 'atk', 'def', 'mag', 'res', 'spd']) {
    const v = g[k] || 0;
    u.b[k] += Math.floor(v + rnd());
  }
}
// ---------- Proficiencies ----------
function newProfs() { const o = {}; for (const k in PROFS) o[k] = { lv: 1, xp: 0 }; return o; }
function ensureProfs(u) { if (!u.pf) u.pf = newProfs(); if (!u.mpl) u.mpl = newProfs(); if (!u.sk) u.sk = {}; }
// Which proficiency an action trains and spends MP from. Items and passives have none.
function pfOf(bu, ab) {
  if (ab.pf) return ab.pf;
  if (ab.cat === 'item' || ab.type === 'R' || ab.type === 'S') return null;
  switch (ab.fx) {
    case 'atk': { if (ab.rng === 'w') return (WTYPES[bu.s.wt] || WTYPES.fist).r > 1 ? 'shot' : 'strike'; return ab.rng > 1 ? 'shot' : 'strike'; }
    case 'mag': case 'drain': return 'arcane';
    case 'heal': case 'raise': case 'cure': case 'mp': return 'mend';
    case 'buff': return 'ward';
    default: return 'trick';
  }
}
function poolMax(bu, pf) { return Math.round(bu.s.mmp * PF_GAIN(bu.u.mpl[pf].lv)); }
function mpTotal(bu) { let n = 0; for (const k in bu.mps) n += bu.mps[k]; return n; }
// Takes up to n MP, from the fullest pools first. Returns how much was taken.
function drainMp(bu, n) {
  let left = n;
  const ks = Object.keys(bu.mps).sort((a, b) => bu.mps[b] - bu.mps[a]);
  for (const k of ks) { const m = Math.min(left, bu.mps[k]); bu.mps[k] -= m; left -= m; }
  return n - left;
}
function fillMp(bu, pf, n) { const m = Math.min(n, poolMax(bu, pf) - bu.mps[pf]); bu.mps[pf] += m; return m; }
// A use trains the skill's proficiency, and the MP level when it cost MP.
function trainProf(a, ab, ev) {
  const pf = pfOf(a, ab);
  if (!pf || a.mon || a.team !== 0) return;
  const e = a.u.pf[pf];
  if (e.lv < PF_MAX && ++e.xp >= PF_NEED(e.lv)) { e.xp = 0; e.lv++; ev.push({ type: 'prof', id: a.id, pf, kind: 'prof', lv: e.lv }); }
  const m = a.u.mpl[pf];
  if (ab.mp && m.lv < PF_MAX && ++m.xp >= PF_NEED(m.lv)) {
    const before = poolMax(a, pf);
    m.xp = 0; m.lv++;
    a.mps[pf] += poolMax(a, pf) - before;
    ev.push({ type: 'prof', id: a.id, pf, kind: 'mp', lv: m.lv });
  }
}
function newUnit(race, job, lv, name, id) {
  const r = RACES[race];
  const u = { id: id || ('u' + Math.floor(rnd() * 1e9).toString(36)), name: name || pick(NAMES[race]), race, job, sub: null, lv: 1, exp: 0,
    b: { hp: r.hp, mp: r.mp, atk: r.atk, def: r.def, mag: r.mag, res: r.res, spd: r.spd }, eq: { w: null, o: null, h: null, b: null, a: null },
    ms: {}, sk: {}, pf: newProfs(), mpl: newProfs(), r: null, s: null, jail: 0, errand: null };
  while (u.lv < lv) { u.lv++; grow(u, JOBS[job].g); }
  return u;
}
function newMonster(kind, lv, id) {
  const m = MONSTERS[kind];
  const u = { id: id || ('m' + Math.floor(rnd() * 1e9).toString(36)), name: m.name, race: 'monster', mon: kind, job: null, lv: 1, exp: 0,
    b: { hp: m.hp, mp: m.mp, atk: m.atk, def: m.def, mag: m.mag, res: m.res, spd: m.spd }, eq: {}, ms: {}, sk: {}, pf: newProfs(), mpl: newProfs(), r: null, s: null };
  while (u.lv < lv) { u.lv++; grow(u, m.g); }
  return u;
}
function itemsOf(u) { return SLOTS.map(s => u.eq && u.eq[s] && ITEMS[u.eq[s]]).filter(Boolean); }
function calcStats(u) {
  const s = { mhp: u.b.hp, mmp: u.b.mp, atk: u.b.atk, def: u.b.def, mag: u.b.mag, res: u.b.res, spd: u.b.spd, ev: 0, mv: 0, jp: 0 };
  if (u.mon) {
    const m = MONSTERS[u.mon];
    Object.assign(s, { mv: m.mv, jp: m.jp, ev: m.ev, wt: m.w });
    s.atk += m.watk;
    return s;
  }
  const j = JOBS[u.job];
  s.mv = j.mv; s.jp = j.jp; s.ev = j.ev; s.wt = 'fist';
  for (const it of itemsOf(u)) {
    for (const k in it.stats) s[k === 'hp' ? 'mhp' : k === 'mp' ? 'mmp' : k] += it.stats[k];
    if (it.slot === 'w') { s.wt = it.t; s.wel = it.el; }
  }
  if (u.s === 'fleet') s.mv += 1;
  if (u.r === 'dodge') s.ev += 15;
  return s;
}
function expNeeded() { return 100; }
function gainExp(u, n) {
  const out = [];
  if (u.mon || u.lv >= 50) return out;
  u.exp += Math.round(n * (u.s === 'expup' ? 1.5 : 1));
  while (u.exp >= expNeeded(u) && u.lv < 50) { u.exp -= expNeeded(u); u.lv++; grow(u, JOBS[u.job].g); out.push(u.lv); }
  return out;
}

// ---------- Jobs and abilities ----------
// Jobs are class templates (gear, movement, growth, look). Skills come from gear, not from the job.
function jobOpen(u, job) { return JOBS[job].races.includes(u.race); }
function jobsFor(race) { return Object.keys(JOBS).filter(k => JOBS[k].races.includes(race)); }
function canEquip(u, it, job) {
  if (u.mon) return false;
  const j = JOBS[job || u.job];
  if (it.slot === 'w') return j.w.includes(it.t);
  if (it.slot === 'o') return j.sh || u.s === 'shieldbearer';
  if (it.slot === 'h') return j.head.includes(it.t);
  if (it.slot === 'b') return j.body.includes(it.t);
  return true;
}
function taught(u) { const s = {}; for (const it of itemsOf(u)) for (const id of it.teach) s[id] = it.id; return s; }
function jobAbilities(job, type) { return Object.keys(AB).filter(id => AB[id].job === job && AB[id].type === (type || 'A')); }
// Skills in use: whatever the equipped gear teaches, plus any kept for good (u.ms).
function knownSkills(u) {
  const ids = Object.keys(taught(u));
  for (const id in u.ms) if (!ids.includes(id)) ids.push(id);
  return ids;
}
function actionSets(u, bu) {
  if (u.mon) return [{ name: MONSTERS[u.mon].name, list: MONSTERS[u.mon].abil.slice() }];
  const list = knownSkills(u).filter(id => AB[id] && AB[id].type === 'A');
  if (bu && bu.vessel && !list.includes(bu.vessel)) list.push(bu.vessel);
  return [{ name: 'Skills', list }];
}
// After a job change, unequip what the new job can't use. Returns removed item ids.
function setJob(u, job) {
  u.job = job;
  if (u.sub === job) u.sub = null;
  const removed = [];
  for (const s of SLOTS) { const id = u.eq[s]; if (id && !canEquip(u, ITEMS[id])) { removed.push(id); u.eq[s] = null; } }
  return removed;
}

// ---------- Battle setup ----------
function parseMap(key) {
  const M = MAPS[key];
  const tiles = M.rows.map(r => r.trim().split(/\s+/).map(tok => ({ t: tok[0], h: +tok.slice(1) })));
  return { key, name: M.name, w: tiles[0].length, d: tiles.length, tiles, deploy: M.deploy, props: M.props || [] };
}
function tileAt(B, x, y) { return x >= 0 && y >= 0 && x < B.map.w && y < B.map.d ? B.map.tiles[y][x] : null; }
function present(B) { return B.units.filter(u => !u.jailed); }
function unitAt(B, x, y) { return B.units.find(u => !u.jailed && u.x === x && u.y === y) || null; }
function alive(u) { return !u.ko && !u.jailed; }

function makeBU(u, team, x, y, f) {
  const s = calcStats(u);
  return { id: u.id, u, name: u.name, team, x, y, f, lv: u.lv, s, hp: s.mhp, mps: poolsFull(u, s), vessel: null, learned: [], st: {}, ko: false, jailed: false, ct: 0, jp: 0, cards: 0, brk: {}, moved: false, acted: false, race: u.race, job: u.job, mon: u.mon, ls: 0 };
}
function poolsFull(u, s) { ensureProfs(u); const o = {}; for (const k in PROFS) o[k] = Math.round(s.mmp * PF_GAIN(u.mpl[k].lv)); return o; }
function faceToward(a, x, y) {
  const dx = x - a.x, dy = y - a.y;
  if (!dx && !dy) return a.f;
  return Math.abs(dx) >= Math.abs(dy) ? (dx > 0 ? 1 : 3) : (dy > 0 ? 2 : 0);
}
function makeBattle(opts) {
  // opts: { map, party: [unit], enemies: [unit + x,y], law, inv: consumables object, mission }
  const map = parseMap(opts.map);
  const B = { map, units: [], law: opts.law, inv: opts.inv, mission: opts.mission || null, log: [], turnNo: 0, over: 0, stolenGil: 0, loot: {}, kos: 0 };
  opts.party.forEach((u, i) => { const [x, y] = map.deploy[i]; B.units.push(makeBU(u, 0, x, y, 0)); });
  for (const e of opts.enemies) B.units.push(makeBU(e.u, 1, e.x, e.y, 2));
  const c0 = centroid(B, 0), c1 = centroid(B, 1);
  for (const u of B.units) { const c = u.team ? c0 : c1; u.f = faceToward(u, c.x, c.y); u.ct = ri(40) + u.s.spd; }
  spawnObjects(B);
  return B;
}
// ---------- Vessel: field objects ----------
function vesselPool() { return Object.keys(AB).filter(id => AB[id].type === 'A' && AB[id].job); }
// OBJ_MIN..OBJ_MAX objects on free, passable tiles, each carrying a random skill.
function spawnObjects(B) {
  const free = [];
  for (let y = 0; y < B.map.d; y++) for (let x = 0; x < B.map.w; x++) if (TERRAIN[B.map.tiles[y][x].t].pass && !unitAt(B, x, y)) free.push([x, y]);
  const pool = vesselPool(), n = Math.min(free.length, OBJ_MIN + ri(OBJ_MAX - OBJ_MIN + 1));
  B.objs = [];
  for (let i = 0; i < n; i++) {
    const [x, y] = free.splice(ri(free.length), 1)[0];
    B.objs.push({ id: 'o' + i, x, y, skill: pool[ri(pool.length)] });
  }
}
function vesselRadius(B) { return VESSEL_RADIUS * Math.max(B.map.w, B.map.d); }
// Objects inside the dome around a unit (tile distance, plus the height difference).
function objsInReach(B, bu) {
  const r = vesselRadius(B), h0 = tileAt(B, bu.x, bu.y).h;
  return (B.objs || []).filter(o => Math.sqrt((o.x - bu.x) ** 2 + (o.y - bu.y) ** 2 + (tileAt(B, o.x, o.y).h - h0) ** 2) <= r);
}
// Taking an object is free: it uses neither the move nor the action. Replaces the held skill.
function pickup(B, bu, objId) {
  const o = objsInReach(B, bu).find(x => x.id === objId);
  if (!o || !alive(bu) || bu.mon) return [];
  B.objs.splice(B.objs.indexOf(o), 1);
  bu.vessel = o.skill;
  return [{ type: 'pickup', id: bu.id, obj: o.id, skill: o.skill }, { type: 'msg', text: bu.name + ' takes ' + AB[o.skill].name + ' into the vessel.' }];
}
// Counts a use of a vessel skill. At SK_NEED uses a player unit keeps it for good.
function trainVessel(a, abId, ev) {
  if (a.vessel !== abId || a.team !== 0 || a.mon || taught(a.u)[abId] || a.u.ms[abId]) return;
  const n = a.u.sk[abId] = (a.u.sk[abId] || 0) + 1;
  if (n >= SK_NEED) {
    delete a.u.sk[abId]; a.u.ms[abId] = 1; a.learned.push(abId);
    ev.push({ type: 'learn', id: a.id, skill: abId });
    ev.push({ type: 'msg', text: a.name + ' learned ' + AB[abId].name + '!' });
  }
}
function centroid(B, team) {
  const us = B.units.filter(u => u.team === team && alive(u));
  if (!us.length) return { x: 0, y: 0 };
  return { x: us.reduce((a, u) => a + u.x, 0) / us.length, y: us.reduce((a, u) => a + u.y, 0) / us.length };
}

// ---------- Stats in battle ----------
function eff(bu, k) {
  let v = bu.s[k] - (bu.brk[k] || 0);
  return Math.max(k === 'spd' ? 1 : 0, v);
}
function speed(bu) {
  let v = eff(bu, 'spd');
  if (bu.st.haste) v *= 1.5;
  if (bu.st.slow) v *= .5;
  return v;
}

// ---------- Turn order (CT) ----------
function nextActor(B) {
  for (let guard = 0; guard < 5000; guard++) {
    let best = null;
    for (const u of B.units) if (alive(u) && u.ct >= 100 && (!best || u.ct > best.ct)) best = u;
    if (best) return best;
    for (const u of B.units) {
      if (!alive(u)) continue;
      if (u.st.stop) { u.st.stop--; if (u.st.stop <= 0) delete u.st.stop; continue; }
      u.ct += speed(u);
    }
  }
  return null;
}
function turnOrder(B, n) {
  const sim = B.units.filter(alive).map(u => ({ u, ct: u.ct, sp: speed(u), stop: u.st.stop || 0 }));
  const out = [];
  for (let guard = 0; out.length < n && guard < 5000 && sim.length; guard++) {
    let best = null;
    for (const s of sim) if (s.ct >= 100 && (!best || s.ct > best.ct)) best = s;
    if (best) { out.push(best.u); best.ct -= 100; continue; }
    for (const s of sim) { if (s.stop > 0) { s.stop--; continue; } s.ct += s.sp; }
  }
  return out;
}
function startTurn(B, bu) {
  const ev = [];
  B.turnNo++;
  bu.moved = false; bu.acted = false;
  bu.start = { x: bu.x, y: bu.y, f: bu.f };
  if (bu.st.doom !== undefined) {
    bu.st.doom--;
    ev.push({ type: 'msg', text: bu.name + ': Doom ' + bu.st.doom });
    if (bu.st.doom <= 0) { koUnit(B, bu, ev); return { ev, skip: true }; }
  }
  if (bu.st.poison) { const d = Math.max(1, Math.round(bu.s.mhp / 8)); hurt(B, bu, d, ev); if (bu.ko) return { ev, skip: true }; }
  if (bu.st.regen) { const h = Math.max(1, Math.round(bu.s.mhp / 8)); bu.hp = Math.min(bu.s.mhp, bu.hp + h); ev.push({ type: 'heal', id: bu.id, v: h }); }
  const skip = !!bu.st.sleep;
  if (skip) ev.push({ type: 'msg', text: bu.name + ' is asleep.' });
  return { ev, skip };
}
function endTurn(B, bu) {
  bu.ct -= bu.moved && bu.acted ? 100 : bu.moved || bu.acted ? 80 : 60;
  bu.ct = Math.min(bu.ct, 60);
  for (const k of Object.keys(bu.st)) {
    if (k === 'doom' || k === 'stop') continue;
    bu.st[k]--;
    if (bu.st[k] <= 0) delete bu.st[k];
  }
}

// ---------- Movement ----------
function canMove(bu) { return !bu.moved && !bu.st.immobilize && !bu.st.sleep && !bu.st.stop; }
function reach(B, bu) {
  const mv = bu.st.immobilize ? 0 : eff(bu, 'mv'), jp = eff(bu, 'jp');
  const key = (x, y) => x + ',' + y;
  const seen = new Map([[key(bu.x, bu.y), { x: bu.x, y: bu.y, d: 0, prev: null }]]);
  const q = [[bu.x, bu.y]];
  while (q.length) {
    const [x, y] = q.shift();
    const cur = seen.get(key(x, y)), t0 = tileAt(B, x, y);
    if (cur.d >= mv) continue;
    for (const [dx, dy] of DIRS) {
      const nx = x + dx, ny = y + dy, t = tileAt(B, nx, ny);
      if (!t || !TERRAIN[t.t].pass || seen.has(key(nx, ny))) continue;
      const dh = t.h - t0.h;
      if (dh > jp || -dh > jp + 1) continue;
      const o = unitAt(B, nx, ny);
      if (o && !o.ko && o.team !== bu.team) continue;
      seen.set(key(nx, ny), { x: nx, y: ny, d: cur.d + 1, prev: key(x, y) });
      q.push([nx, ny]);
    }
  }
  const out = new Map();
  for (const [k, v] of seen) { const o = unitAt(B, v.x, v.y); if (!o || o === bu) out.set(k, v); }
  out.all = seen;
  return out;
}
function pathTo(R, x, y) {
  const p = [];
  let k = x + ',' + y;
  while (k) { const n = R.all.get(k); p.unshift([n.x, n.y]); k = n.prev; }
  return p;
}
function moveUnit(B, bu, x, y) {
  const last = [bu.x, bu.y];
  bu.x = x; bu.y = y; bu.moved = true;
  if (last[0] !== x || last[1] !== y) bu.f = faceToward({ x: last[0], y: last[1], f: bu.f }, x, y);
}

// ---------- Abilities in battle ----------
function abilityFor(id) {
  if (id === 'fight') return FIGHT;
  if (id === 'combo') return COMBO;
  if (id.startsWith('item:')) {
    const k = id.slice(5), c = CONS[k];
    return { id, name: c.name, fx: c.fx, pw: c.pw, cure: c.cure, rng: 1, aoe: 0, cat: 'item', mp: 0, tgt: c.fx === 'raise' ? 'ko' : 'ally', cons: k, desc: c.desc };
  }
  return AB[id];
}
function mpCost(bu, ab) { return Math.ceil((ab.mp || 0) * (bu.u.s === 'halfmp' ? .5 : 1)); }
// Why an ability can't be used right now, or '' if it can.
function blocked(B, bu, ab) {
  if (bu.st.disable || bu.st.sleep || bu.st.stop) return 'Cannot act';
  if (ab.cat === 'mag' && bu.st.silence) return 'Silenced';
  if (ab.mp && mpCost(bu, ab) > bu.mps[pfOf(bu, ab)]) return 'Not enough MP';
  if (ab.cons && !(B.inv && B.inv[ab.cons] > 0)) return 'None left';
  if (ab.combo && bu.jp < ab.jpCost) return 'Needs ' + ab.jpCost + ' JP';
  return '';
}
function rangeOf(bu, ab) {
  if (ab.rng === 'w') { const w = WTYPES[bu.s.wt] || WTYPES.fist; return { r: w.r, v: w.v, line: !!w.line }; }
  return { r: ab.rng, v: ab.v !== undefined ? ab.v : ab.fx === 'atk' ? 2 : 5, line: !!ab.line };
}
function rangeTiles(B, bu, ab, fx, fy) {
  fx = fx === undefined ? bu.x : fx; fy = fy === undefined ? bu.y : fy;
  const { r, v, line } = rangeOf(bu, ab), h0 = tileAt(B, fx, fy).h, out = [];
  for (let y = fy - r; y <= fy + r; y++) for (let x = fx - r; x <= fx + r; x++) {
    const t = tileAt(B, x, y);
    if (!t) continue;
    const d = Math.abs(x - fx) + Math.abs(y - fy);
    if (d > r || (line && x !== fx && y !== fy)) continue;
    if (r > 0 && d === 0 && (ab.tgt === 'foe' || ab.tgt === 'ko')) continue;
    if (Math.abs(t.h - h0) > v) continue;
    out.push([x, y]);
  }
  return out;
}
function areaTiles(B, ab, cx, cy) {
  if (!ab.aoe) return [[cx, cy]];
  const h0 = tileAt(B, cx, cy).h, out = [];
  for (let y = cy - ab.aoe; y <= cy + ab.aoe; y++) for (let x = cx - ab.aoe; x <= cx + ab.aoe; x++) {
    const t = tileAt(B, x, y);
    if (t && Math.abs(x - cx) + Math.abs(y - cy) <= ab.aoe && Math.abs(t.h - h0) <= 3) out.push([x, y]);
  }
  return out;
}
function targetsOf(B, a, ab, cx, cy) {
  const out = [];
  for (const [x, y] of areaTiles(B, ab, cx, cy)) {
    const t = unitAt(B, x, y);
    if (!t) continue;
    if (ab.tgt === 'ko' || ab.fx === 'raise') { if (t.ko && t.team === a.team) out.push(t); continue; }
    if (t.ko) continue;
    if (ab.fo && t.team === a.team) continue;
    if (ab.hits === 'allies' && t.team !== a.team) continue;
    out.push(t);
  }
  return out;
}

// ---------- Laws ----------
function elementOf(bu, ab) { return ab.el || (ab.fx === 'atk' ? bu.s.wel : null) || null; }
function lawMatch(lawId, bu, ab, cx, cy) {
  if (!lawId) return false;
  const L = LAWS[lawId];
  switch (L.k) {
    case 'cat': return ab.cat === L.v;
    case 'fx': return ab.fx === L.v || (L.v === 'heal' && ab.fx === 'raise');
    case 'status': return !!(ab.st && ab.st.some(s => STATUS[s].bad));
    case 'ranged': return ab.fx === 'atk' && Math.abs(cx - bu.x) + Math.abs(cy - bu.y) > 1;
    case 'el': return elementOf(bu, ab) === L.v;
    case 'w': return ab.fx === 'atk' && bu.s.wt === L.v && !ab.cons;
    case 'fight': return ab.id === 'fight';
  }
  return false;
}
function breaksLaw(B, bu, ab, cx, cy) { return !!(B.law && lawMatch(B.law.ban, bu, ab, cx, cy)); }

// ---------- Hit, damage ----------
function facingRel(a, t) {
  const dx = a.x - t.x, dy = a.y - t.y, [fx, fy] = DIRS[t.f];
  const dot = dx * fx + dy * fy, cross = Math.abs(dx * fy - dy * fx);
  if (dot > cross) return 'front';
  if (-dot > cross) return 'back';
  return 'side';
}
function hitChance(a, t, ab) {
  if (ab.fx !== 'atk' && ab.fx !== 'steal') return 100;
  if (a.team === t.team && ab.fx !== 'atk') return 100;
  if (t.st.sleep || t.st.stop) return 100;
  const rel = facingRel(a, t);
  if (ab.fx === 'steal') return clamp(50 + (speed(a) - speed(t)) * 4 + (rel === 'back' ? 20 : rel === 'side' ? 10 : 0), 5, 95);
  let ev = eff(t, 'ev') * (rel === 'front' ? 1 : rel === 'side' ? .5 : .2);
  let h = 100 - ev;
  if (a.u.s === 'concentrate') h += 25;
  if (a.st.blind) h *= .5;
  return Math.round(clamp(h, 5, 100));
}
function elemMult(t, el) {
  if (!el) return 1;
  if (t.mon) { const m = MONSTERS[t.mon]; if ((m.weak || []).includes(el)) return 1.5; if ((m.resist || []).includes(el)) return .5; }
  return 1;
}
function comboPower(B, a, t) {
  let n = 0;
  for (const [dx, dy] of DIRS) { const o = unitAt(B, t.x + dx, t.y + dy); if (o && o !== a && alive(o) && o.team === a.team) n++; }
  return 1 + n * .5;
}
// Expected (un-randomized) amount. Positive = damage, negative = healing.
function pfMult(a, ab) { const pf = a.u.pf && pfOf(a, ab); return pf ? PF_GAIN(a.u.pf[pf].lv) : 1; }
function baseAmount(B, a, t, ab) {
  const el = elementOf(a, ab);
  if (ab.fx === 'atk') {
    const A = eff(a, 'atk'), D = ab.pierce ? 0 : eff(t, 'def');
    let d = (A - D / 2) * ab.pw * (ab.hitsN || 1) * pfMult(a, ab);
    if (ab.combo) d *= comboPower(B, a, t);
    if (a.st.boost) d *= 1.5;
    if (a.u.s === 'watkup') d *= 1.2;
    if (t.st.protect && !ab.pierce) d *= .67;
    if (t.mon && MONSTERS[t.mon].physHalf) d *= .5;
    return Math.max(1, d * elemMult(t, el));
  }
  if (ab.fx === 'mag' || ab.fx === 'drain') {
    let d = ab.pw * eff(a, 'mag') / 20 * 40 / (40 + eff(t, 'res')) * pfMult(a, ab);
    if (a.u.s === 'magpowup') d *= 1.2;
    if (t.st.shell) d *= .67;
    return Math.max(1, d * elemMult(t, el));
  }
  if (ab.fx === 'heal') {
    if (ab.cat === 'item') return -ab.pw * (a.u.s === 'itemlore' ? 1.5 : 1);
    let h = ab.cat === 'mag' ? ab.pw * eff(a, 'mag') / 20 * pfMult(a, ab) : ab.pw * (1 + a.lv * .06) * pfMult(a, ab);
    if (a.u.s === 'magpowup' && ab.cat === 'mag') h *= 1.2;
    return -h;
  }
  if (ab.fx === 'mpdmg') return ab.pw * (1 + a.lv * .05);
  return 0;
}
function statusChance(a, t, ab) {
  let c = ab.ch === undefined ? 100 : ab.ch;
  if (ab.cat === 'mag') c += (eff(a, 'mag') - eff(t, 'res')) / 2;
  if (t.mon && MONSTERS[t.mon].boss) c *= .5;
  return Math.round(clamp(c, 5, 95));
}
// Preview for UI and AI
function predict(B, a, ab, t) {
  const hit = hitChance(a, t, ab), amt = baseAmount(B, a, t, ab);
  const p = { hit, amt: Math.round(amt) };
  if (ab.st) p.stCh = ab.fx === 'buff' ? 100 : statusChance(a, t, ab);
  return p;
}

// ---------- Applying effects ----------
function koUnit(B, bu, ev) {
  bu.hp = 0; bu.ko = true; bu.st = {}; bu.ct = 0;
  ev.push({ type: 'ko', id: bu.id });
  if (bu.team === 1) {
    B.kos++;
    if (bu.mon) for (const l of MONSTERS[bu.mon].loot) if (rnd() < .6 || MONSTERS[bu.mon].boss) B.loot[l] = (B.loot[l] || 0) + 1;
  }
}
function hurt(B, t, d, ev, src) {
  d = Math.max(0, Math.round(d));
  if (t.u.r === 'manashield' && mpTotal(t) > 0) { const m = drainMp(t, Math.min(mpTotal(t), d)); d -= m; if (m) ev.push({ type: 'mp', id: t.id, v: -m }); }
  t.hp -= d;
  ev.push({ type: 'dmg', id: t.id, v: d });
  if (t.st.sleep && src === 'phys') delete t.st.sleep;
  if (t.hp <= 0) koUnit(B, t, ev);
}
function addStatus(t, s, ev) {
  if (t.ko) return;
  if (s === 'haste') delete t.st.slow;
  if (s === 'slow') delete t.st.haste;
  t.st[s] = s === 'stop' ? 30 : STATUS[s].t;
  ev.push({ type: 'status', id: t.id, s });
}
function vary(v) { return v * (.9 + rnd() * .2); }

function applyTo(B, a, ab, t, ev, react) {
  const hit = hitChance(a, t, ab);
  if (ab.fx === 'atk' || ab.fx === 'steal') {
    if (rnd() * 100 >= hit) { ev.push({ type: 'miss', id: t.id }); return; }
  }
  const foe = t.team !== a.team;
  switch (ab.fx) {
    case 'atk': case 'mag': {
      let d = vary(baseAmount(B, a, t, ab));
      if (ab.fx === 'atk' && rnd() < .05) { d *= 1.5; ev.push({ type: 'msg', text: 'Critical!' }); }
      hurt(B, t, d, ev, ab.fx === 'atk' ? 'phys' : 'mag');
      if (foe) a.dealt = (a.dealt || 0) + 1;
      if (!t.ko) {
        if (ab.st) for (const s of ab.st) if (rnd() * 100 < statusChance(a, t, ab)) addStatus(t, s, ev);
        if (ab.brk) for (const k in ab.brk) { t.brk[k] = (t.brk[k] || 0) + ab.brk[k]; ev.push({ type: 'msg', text: t.name + ' ' + k.toUpperCase() + ' -' + ab.brk[k] }); }
        react.push({ t, ab });
      }
      break;
    }
    case 'drain': {
      const d = Math.min(t.hp, Math.round(vary(baseAmount(B, a, t, ab))));
      hurt(B, t, d, ev, 'mag');
      a.hp = Math.min(a.s.mhp, a.hp + d);
      ev.push({ type: 'heal', id: a.id, v: d });
      break;
    }
    case 'heal': {
      const h = Math.round(vary(-baseAmount(B, a, t, ab)));
      t.hp = Math.min(t.s.mhp, t.hp + h);
      ev.push({ type: 'heal', id: t.id, v: h });
      if (ab.cure) for (const s of ab.cure) if (t.st[s]) { delete t.st[s]; ev.push({ type: 'msg', text: t.name + ': ' + STATUS[s].name + ' cured' }); }
      break;
    }
    case 'mp': { let v = 0; for (const k in PROFS) v += fillMp(t, k, ab.pw); ev.push({ type: 'mp', id: t.id, v }); break; }
    case 'raise': {
      if (!t.ko) break;
      t.ko = false; t.hp = Math.max(1, Math.round(t.s.mhp * ab.pw / 100)); t.ct = 0;
      ev.push({ type: 'raise', id: t.id }); ev.push({ type: 'heal', id: t.id, v: t.hp });
      break;
    }
    case 'buff': for (const s of ab.st) addStatus(t, s, ev); break;
    case 'debuff': {
      let any = false;
      for (const s of ab.st) if (rnd() * 100 < statusChance(a, t, ab)) { addStatus(t, s, ev); any = true; }
      if (!any) ev.push({ type: 'miss', id: t.id });
      break;
    }
    case 'cure': {
      let any = false;
      for (const s of ab.cure) if (t.st[s]) { delete t.st[s]; any = true; }
      ev.push({ type: 'msg', text: any ? t.name + ' is cured.' : 'No effect on ' + t.name + '.' });
      break;
    }
    case 'mpdmg': {
      const v = drainMp(t, Math.min(mpTotal(t), Math.round(vary(baseAmount(B, a, t, ab)))));
      ev.push({ type: 'mp', id: t.id, v: -v });
      if (ab.drainmp) { fillMp(a, pfOf(a, ab), v); ev.push({ type: 'mp', id: a.id, v }); }
      break;
    }
    case 'quick': t.ct = Math.max(t.ct, 200); ev.push({ type: 'msg', text: t.name + ' acts next!' }); break;
    case 'steal': doSteal(B, a, t, ab, ev); break;
  }
}
function doSteal(B, a, t, ab, ev) {
  if (ab.what === 'gil') {
    if (t.mon && a.team === 0) { ev.push({ type: 'msg', text: 'Nothing to steal.' }); return; }
    const g = 20 * t.lv + ri(40);
    if (a.team === 0) B.stolenGil += g; else B.gilLost = (B.gilLost || 0) + g;
    ev.push({ type: 'msg', text: a.name + ' stole ' + g + ' gil!' });
    return;
  }
  const id = t.u.eq && t.u.eq[ab.what];
  if (!id) { ev.push({ type: 'msg', text: 'Nothing to steal.' }); return; }
  t.u.eq[ab.what] = null;
  const hpPct = t.hp / t.s.mhp;
  t.s = calcStats(t.u);
  t.hp = Math.max(1, Math.min(t.s.mhp, Math.round(t.s.mhp * hpPct)));
  for (const k in t.mps) t.mps[k] = Math.min(t.mps[k], poolMax(t, k));
  if (a.team === 0) (B.stolen = B.stolen || []).push(id); else (B.lost = B.lost || []).push({ unit: t.u.id, item: id });
  ev.push({ type: 'msg', text: a.name + ' stole ' + ITEMS[id].name + '!' });
}

// Run the reactions of damaged targets.
function reactions(B, a, ab, list, ev) {
  for (const { t } of list) {
    if (!alive(t) || !alive(a) || t.st.sleep || t.st.stop || t.st.disable) continue;
    const r = t.u.r, d = dist(a, t);
    if (r === 'laststand' && !t.ls && t.hp < t.s.mhp / 4) { t.ls = 1; ev.push({ type: 'msg', text: t.name + ': Last Stand!' }); addStatus(t, 'boost', ev); addStatus(t, 'protect', ev); continue; }
    if (r === 'autopotion') {
      const ok = t.team === 1 || (B.inv && B.inv.potion > 0);
      if (ok && t.hp < t.s.mhp) { if (t.team === 0) B.inv.potion--; const h = Math.min(50, t.s.mhp - t.hp); t.hp += h; ev.push({ type: 'msg', text: t.name + ': Auto-Potion' }); ev.push({ type: 'heal', id: t.id, v: h }); }
      continue;
    }
    if (ab.fx !== 'atk') continue;
    const wr = rangeOf(t, FIGHT);
    let pw = 0;
    if ((r === 'counter' || r === 'bonecrusher') && d === 1) pw = r === 'bonecrusher' ? 1.5 : 1;
    if (r === 'returnfire' && d > 1 && wr.r >= d) pw = 1;
    if (!pw) continue;
    ev.push({ type: 'msg', text: t.name + ': ' + AB[r].name + '!' });
    ev.push({ type: 'act', id: t.id, tx: a.x, ty: a.y, ab: 'fight' });
    t.f = faceToward(t, a.x, a.y);
    applyTo(B, t, Object.assign({}, FIGHT, { pw }), a, ev, []);
  }
}

function expFor(a, t, ab) {
  if (t.team === a.team) return 8;
  return 10 + Math.max(0, (t.lv - a.lv) * 4);
}
// Perform an ability at a center tile. Returns events for the UI.
function perform(B, a, abId, cx, cy) {
  const ab = abilityFor(abId), ev = [];
  const targets = targetsOf(B, a, ab, cx, cy);
  a.f = faceToward(a, cx, cy);
  ev.push({ type: 'act', id: a.id, tx: cx, ty: cy, ab: abId, el: elementOf(a, ab) });
  ev.push({ type: 'msg', text: a.name + ': ' + ab.name });
  if (ab.mp) a.mps[pfOf(a, ab)] -= mpCost(a, ab);
  if (ab.cons) B.inv[ab.cons]--;
  if (ab.combo) a.jp -= ab.jpCost;
  const usedBoost = a.st.boost && (ab.fx === 'atk');
  const react = [];
  const koBefore = new Set(B.units.filter(u => u.ko).map(u => u.id));
  let expGain = 0;
  for (const t of targets) {
    if (ab.cat === 'mag' && t.u.r === 'absorbmp' && ab.mp && t.team !== a.team) { const v = fillMp(t, pfOf(a, ab), mpCost(a, ab)); if (v) ev.push({ type: 'mp', id: t.id, v }); }
    applyTo(B, a, ab, t, ev, react);
    expGain += expFor(a, t, ab);
  }
  if (!targets.length) expGain = 4;
  if (usedBoost) delete a.st.boost;
  // Judge: law and JP
  if (B.law) {
    if (lawMatch(B.law.ban, a, ab, cx, cy)) penalize(B, a, ev);
    else if (lawMatch(B.law.fav, a, ab, cx, cy)) { a.jp++; ev.push({ type: 'jp', id: a.id, v: 1 }); }
  }
  for (const u of B.units) if (u.ko && !koBefore.has(u.id) && u.team !== a.team && alive(a)) { a.jp++; ev.push({ type: 'jp', id: a.id, v: 1 }); expGain += 10; }
  if (!a.jailed) reactions(B, a, ab, react, ev);
  trainProf(a, ab, ev);
  trainVessel(a, abId, ev);
  if (a.team === 0 && !a.mon) { const lv = gainExp(a.u, Math.min(60, expGain)); if (lv.length) levelUp(a, lv, ev); }
  a.acted = true;
  checkEnd(B);
  return ev;
}
function levelUp(a, lvls, ev) {
  const old = a.s;
  const oldMax = {};
  for (const k in PROFS) oldMax[k] = poolMax(a, k);
  a.s = calcStats(a.u); a.lv = a.u.lv;
  a.hp += a.s.mhp - old.mhp;
  for (const k in PROFS) a.mps[k] += poolMax(a, k) - oldMax[k];
  ev.push({ type: 'lvup', id: a.id, lv: a.lv });
}
function penalize(B, a, ev) {
  a.cards++;
  if (a.cards === 1) { ev.push({ type: 'card', id: a.id, red: false }); ev.push({ type: 'msg', text: 'Yellow card for ' + a.name + '! Next offense means jail.' }); return; }
  a.jailed = true;
  ev.push({ type: 'card', id: a.id, red: true });
  ev.push({ type: 'msg', text: 'Red card! ' + a.name + ' is sent to jail.' });
}
function checkEnd(B) {
  if (B.over) return B.over;
  const p = B.units.some(u => u.team === 0 && alive(u)), e = B.units.some(u => u.team === 1 && alive(u));
  if (!e) B.over = 1; else if (!p) B.over = -1;
  return B.over;
}
function usableIds(B, bu) {
  const ids = ['fight'];
  for (const s of actionSets(bu.u, bu)) ids.push(...s.list);
  if (bu.team === 0 && B.inv) for (const k in CONS) if (B.inv[k] > 0) ids.push('item:' + k);
  if (bu.jp >= COMBO.jpCost) ids.push('combo');
  return ids;
}

// ---------- AI ----------
function scoreAction(B, a, ab, cx, cy) {
  if (breaksLaw(B, a, ab, cx, cy)) return -999;
  const ts = targetsOf(B, a, ab, cx, cy);
  if (!ts.length) return -1;
  let s = 0;
  for (const t of ts) {
    const ally = t.team === a.team, sign = ally ? -1.5 : 1;
    switch (ab.fx) {
      case 'atk': case 'mag': case 'drain': {
        const h = hitChance(a, t, ab) / 100, d = baseAmount(B, a, t, ab);
        let v = Math.min(d, t.hp) / t.s.mhp * 100 * h;
        if (d >= t.hp) v += 50 * h;
        if (ab.st) for (const st of ab.st) if (!t.st[st]) v += 15 * statusChance(a, t, ab) / 100 * h;
        if (ab.brk) v += 6;
        s += sign * v;
        break;
      }
      case 'heal': {
        const miss = t.s.mhp - t.hp;
        const v = (t.hp < t.s.mhp * .7 ? Math.min(-baseAmount(B, a, t, ab), miss) / t.s.mhp * 100 : 0) + (ab.cure ? ab.cure.filter(x => t.st[x]).length * 10 : 0);
        s += ally ? v : -v;
        break;
      }
      case 'raise': s += 90; break;
      case 'buff': for (const st of ab.st) if (!t.st[st]) s += (ally ? 1 : -1) * (st === 'haste' ? 28 : 16); break;
      case 'debuff': for (const st of ab.st) if (!t.st[st]) s += (ally ? -1 : 1) * statusChance(a, t, ab) * (st === 'stop' || st === 'doom' ? .5 : .32); break;
      case 'cure': if (ally) s += ab.cure.filter(x => t.st[x]).length * 22; break;
      case 'steal': if (!ally) s += ab.what === 'gil' ? (t.mon ? 0 : 12) : t.u.eq && t.u.eq[ab.what] ? 22 : 0; break;
      case 'mpdmg': if (!ally && mpTotal(t) > 0) s += 10; break;
      case 'quick': if (ally && t !== a) s += 30; break;
      case 'mp': if (ally) s += (t.s.mmp * 6 - mpTotal(t)) > 20 ? 20 : 0; break;
    }
  }
  if (B.law && lawMatch(B.law.fav, a, ab, cx, cy)) s += 4;
  s -= mpCost(a, ab) * .2;
  return s;
}
function distField(B, team, bu) {
  // BFS distance (ignoring move limit) from units of `team` across passable tiles.
  const D = new Map(), q = [], jp = eff(bu, 'jp');
  for (const u of B.units) if (alive(u) && u.team === team) for (const [dx, dy] of DIRS) {
    const x = u.x + dx, y = u.y + dy, t = tileAt(B, x, y);
    if (t && TERRAIN[t.t].pass && !D.has(x + ',' + y)) { D.set(x + ',' + y, 1); q.push([x, y]); }
  }
  while (q.length) {
    const [x, y] = q.shift(), d = D.get(x + ',' + y), t0 = tileAt(B, x, y);
    for (const [dx, dy] of DIRS) {
      const nx = x + dx, ny = y + dy, t = tileAt(B, nx, ny);
      if (!t || !TERRAIN[t.t].pass || D.has(nx + ',' + ny) || Math.abs(t.h - t0.h) > jp + 1) continue;
      D.set(nx + ',' + ny, d + 1); q.push([nx, ny]);
    }
  }
  return D;
}
function aiPlan(B, a) {
  // A free pickup first: an empty vessel takes the nearest object in reach.
  let pick = null;
  if (!a.vessel && !a.mon) {
    let o = null;
    for (const c of objsInReach(B, a)) if (!o || dist(a, c) < dist(a, o)) o = c;
    if (o) { pickup(B, a, o.id); pick = o.skill; }
  }
  const ox = a.x, oy = a.y;
  const tiles = canMove(a) ? [...reach(B, a).values()] : [{ x: a.x, y: a.y }];
  const canAct = !a.acted && !a.st.disable;
  const ids = canAct ? usableIds(B, a).filter(id => !blocked(B, a, abilityFor(id))) : [];
  let best = null;
  const foeTeam = 1 - a.team, fd = distField(B, foeTeam, a);
  for (const T of tiles) {
    a.x = T.x; a.y = T.y;
    const near = fd.get(T.x + ',' + T.y) || 99;
    for (const id of ids) {
      const ab = abilityFor(id);
      if (ab.cat === 'item' && a.team === 1) continue;
      for (const [cx, cy] of rangeTiles(B, a, ab)) {
        let s = scoreAction(B, a, ab, cx, cy);
        if (s <= 0) continue;
        s -= (T.d || 0) * .3;
        if (ab.fx === 'heal' || ab.cat === 'mag') s += Math.min(near, 4) * .5; // casters prefer some distance
        if (!best || s > best.s) best = { s, x: T.x, y: T.y, id, cx, cy };
      }
    }
  }
  a.x = ox; a.y = oy;
  if (best && best.s > 2) { best.pick = pick; return best; }
  // Nothing worth doing: advance toward the nearest foe.
  let mv = null;
  for (const T of tiles) {
    const d = fd.get(T.x + ',' + T.y);
    if (d === undefined) continue;
    if (!mv || d < mv.d) mv = { d, x: T.x, y: T.y };
  }
  return { s: 0, x: mv ? mv.x : a.x, y: mv ? mv.y : a.y, id: null, pick };
}
function nearestFoe(B, a) {
  let best = null;
  for (const u of B.units) if (alive(u) && u.team !== a.team && (!best || dist(a, u) < dist(a, best))) best = u;
  return best;
}

// ---------- Laws per day ----------
function dailyLaw(day) {
  const keys = Object.keys(LAWS);
  let s = (day * 2654435761) >>> 0;
  const r = () => { s = (s * 1103515245 + 12345) >>> 0; return s / 4294967296; };
  const ban = keys[Math.floor(r() * keys.length)];
  let fav = keys[Math.floor(r() * keys.length)];
  if (fav === ban) fav = keys[(keys.indexOf(ban) + 1) % keys.length];
  return { ban, fav };
}

if (typeof module !== 'undefined') module.exports = { setRng };
