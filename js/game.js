// Hollowmark Tactics: campaign state (save, shop, bazaar, missions, rewards, errands, recruits).
'use strict';

const SAVE_KEY = 'hollowmark-save-1';
const CLAN_MAX = 16;
let G = null;

function newGame(clanName) {
  G = { v: 1, clan: clanName || 'Clan Briar', gil: 800, day: 1, stage: 0, loc: 'town', accepted: null, units: [], inv: {}, cons: { potion: 6, phoenix: 2, antidote: 2 }, loot: {},
    bazaar: [], errands: [], board: [], offer: null, battles: 0, cleared: {} };
  const party = [['human', 'squire', 'Rook'], ['saurian', 'warrior', 'Bram'], ['sylph', 'archer', 'Liss'], ['mossling', 'animist', 'Pip'], ['nuwa', 'sage', 'Oro'], ['human', 'mender', 'Tamsin']];
  for (const [race, job, name] of party) addUnit(newUnit(race, job, 1, name), true);
  G.units[0].leader = 1;
  refreshBoard();
  return G;
}
// Add a unit with its job's starter gear (gear is created, not taken from inventory).
function addUnit(u, gear) {
  if (gear) for (const id of STARTER[u.job] || []) { const it = ITEMS[id]; if (canEquip(u, it) && !u.eq[it.slot]) u.eq[it.slot] = id; }
  G.units.push(u);
  return u;
}
function save() { try { localStorage.setItem(SAVE_KEY, JSON.stringify(G)); } catch (e) { /* storage unavailable */ } }
function load() {
  try { const s = localStorage.getItem(SAVE_KEY); if (s) { G = JSON.parse(s); return true; } } catch (e) { /* ignore */ }
  return false;
}
function hasSave() { try { return !!localStorage.getItem(SAVE_KEY); } catch (e) { return false; } }
function unitById(id) { return G.units.find(u => u.id === id); }
function addItem(id, n) { G.inv[id] = (G.inv[id] || 0) + (n || 1); }
function takeItem(id) { if (!G.inv[id]) return false; if (--G.inv[id] <= 0) delete G.inv[id]; return true; }
function equip(u, slot, id) {
  if (u.eq[slot]) addItem(u.eq[slot]);
  u.eq[slot] = null;
  if (id && takeItem(id)) u.eq[slot] = id;
}
function changeJob(u, job) { for (const id of setJob(u, job)) addItem(id); }
function available(u) { return !u.jail && !u.errand; }

// ---------- Shop ----------
function shopItems() {
  return Object.values(ITEMS).filter(it => it.st <= G.stage || G.bazaar.includes(it.id));
}
function shopCons() { return Object.keys(CONS).filter(k => CONS[k].st <= G.stage); }
function buy(id, kind) {
  const price = kind === 'cons' ? CONS[id].price : ITEMS[id].price;
  if (G.gil < price) return false;
  G.gil -= price;
  if (kind === 'cons') G.cons[id] = (G.cons[id] || 0) + 1; else addItem(id);
  return true;
}
function sellPrice(id, kind) { return Math.floor((kind === 'cons' ? CONS[id].price : kind === 'loot' ? LOOT[id].price * 2 : ITEMS[id].price) / 2); }
function sell(id, kind) {
  const bag = kind === 'cons' ? G.cons : kind === 'loot' ? G.loot : G.inv;
  if (!bag[id]) return false;
  bag[id]--; if (!bag[id]) delete bag[id];
  G.gil += sellPrice(id, kind);
  return true;
}
function canCraft(r) { return G.gil >= r.gil && Object.keys(r.need).every(k => (G.loot[k] || 0) >= r.need[k]); }
function craft(r) {
  if (!canCraft(r)) return false;
  for (const k in r.need) { G.loot[k] -= r.need[k]; if (!G.loot[k]) delete G.loot[k]; }
  G.gil -= r.gil;
  addItem(r.out);
  if (!G.bazaar.includes(r.out)) G.bazaar.push(r.out);
  return true;
}
// Recipes appear once you have seen at least one of their ingredients.
function knownRecipes() { return RECIPES.filter(r => G.bazaar.includes(r.out) || Object.keys(r.need).some(k => G.seen && G.seen[k])); }

// ---------- Missions / travel ----------
function locOpen(k) {
  if (k === 'town' || k === 'briar') return true;
  if (k === 'quarry') return G.stage >= 1;
  if (k === 'mirewood') return G.stage >= 2;
  return false;
}
function nextMission() { return MISSIONS[G.stage] || null; }
function travel(k) {
  if (!locOpen(k) || k === G.loc) return false;
  G.loc = k; G.day++;
  return true;
}
function todaysLaw() { return dailyLaw(G.day); }
function avgLevel(us) { return Math.max(1, Math.round(us.reduce((a, u) => a + u.lv, 0) / Math.max(1, us.length))); }

function enemyFromSpec(spec) {
  const [kind, lv, x, y, ex] = spec;
  let u;
  if (MONSTERS[kind]) u = newMonster(kind, lv);
  else {
    const [race, job] = kind.split(':');
    u = newUnit(race, job, lv, ex && ex.name);
    for (const id of (ex && ex.eq) || STARTER[job] || []) { const it = ITEMS[id]; if (canEquip(u, it)) u.eq[it.slot] = id; }
    // Enemies know what their gear teaches, plus one more job ability.
    for (const id of Object.keys(taught(u))) if (AB[id].type === 'A' && AB[id].job === job) u.ms[id] = 1;
    const extra = jobAbilities(job).filter(id => !u.ms[id]);
    if (extra.length) u.ms[pick(extra)] = 1;
    if (job === 'warrior' || job === 'knight' || job === 'brawler') u.r = 'counter';
    if (ex && ex.leader) u.leader = 1;
  }
  return { u, x, y };
}
const SKIRMISH = {
  briar: { kinds: ['grimkin', 'wolfhound', 'human:rogue', 'human:archer', 'sylph:fencer'], spots: [[8, 1], [9, 2], [10, 0], [8, 3], [10, 3], [11, 1]] },
  quarry: { kinds: ['saurian:warrior', 'human:arcanist', 'sandmaw', 'grimkin', 'mossling:gunner', 'saurian:cleric'], spots: [[5, 1], [8, 1], [7, 0], [3, 2], [9, 0], [2, 1]] },
  mirewood: { kinds: ['ooze', 'sandmaw', 'wolfhound', 'nuwa:sage', 'mossling:animist', 'human:squire'], spots: [[6, 0], [4, 1], [8, 1], [9, 4], [2, 3], [10, 2]] },
};
function buildBattle(kind, partyIds) {
  const party = partyIds.map(unitById);
  let enemies, law, mission = null, map;
  if (kind === 'mission') {
    mission = nextMission();
    map = mission.map; law = mission.law;
    enemies = mission.enemies.map(enemyFromSpec);
  } else {
    map = G.loc; law = todaysLaw();
    const S = SKIRMISH[G.loc], lv = avgLevel(party), n = Math.min(S.spots.length, Math.max(3, party.length - 1 + ri(2)));
    enemies = S.spots.slice(0, n).map(([x, y]) => enemyFromSpec([pick(S.kinds), Math.max(1, lv - 1 + ri(3)), x, y]));
  }
  const B = makeBattle({ map, party, enemies, law, inv: G.cons, mission });
  B.kind = kind;
  return B;
}

// ---------- Results ----------
function finishBattle(B) {
  const won = B.over === 1;
  const res = { won, units: [], gil: 0, loot: {}, items: {}, stolen: B.stolen || [], lost: B.lost || [], jailed: [], unlocked: [], story: null };
  G.battles++;
  // Gear lost to enemy thieves is gone for good; gil too.
  if (B.gilLost) { G.gil = Math.max(0, G.gil - B.gilLost); res.gilLost = B.gilLost; }
  for (const bu of B.units.filter(b => b.team === 0)) {
    const u = bu.u, before = jobsFor(u.race).filter(j => jobOpen(u, j));
    if (bu.jailed) { u.jail = 2; res.jailed.push(u.id); }
    const ap = won ? (B.mission ? B.mission.reward.ap : 20) : 0;
    const got = ap ? gainAP(u, ap) : [];
    const now = jobsFor(u.race).filter(j => jobOpen(u, j) && !before.includes(j));
    res.units.push({ id: u.id, ap, mastered: got, jobs: now });
  }
  if (won) {
    for (const id of res.stolen) addItem(id);
    G.gil += B.stolenGil || 0;
    if (B.mission) {
      const r = B.mission.reward;
      res.gil = r.gil;
      Object.assign(res.items, r.items || {});
      for (const k in r.loot) res.loot[k] = (res.loot[k] || 0) + r.loot[k];
      G.cleared[B.mission.loc] = 1;
      G.stage++;
      G.accepted = null;
      res.story = B.mission.id;
    } else {
      res.gil = 80 + 30 * avgLevel(B.units.filter(b => b.team === 1).map(b => b.u)) + ri(60);
    }
    for (const k in B.loot) res.loot[k] = (res.loot[k] || 0) + B.loot[k];
    G.gil += res.gil;
    for (const k in res.loot) { G.loot[k] = (G.loot[k] || 0) + res.loot[k]; (G.seen = G.seen || {})[k] = 1; }
    for (const k in res.items) G.cons[k] = (G.cons[k] || 0) + res.items[k];
  }
  // Jail time and errands tick down after every battle.
  for (const u of G.units) if (u.jail && !res.jailed.includes(u.id)) u.jail--;
  res.errands = tickErrands();
  if (won && G.units.length < CLAN_MAX && rnd() < .45) G.offer = makeRecruit();
  if (won) refreshBoard();
  save();
  return res;
}
function makeRecruit() {
  const race = pick(Object.keys(RACES)), job = pick(BASE_JOBS[race]);
  const lv = Math.max(1, avgLevel(G.units) - 1 + ri(2));
  const u = newUnit(race, job, lv);
  for (const id of STARTER[job]) { const it = ITEMS[id]; if (canEquip(u, it)) u.eq[it.slot] = id; }
  return u;
}
function acceptRecruit() { if (G.offer && G.units.length < CLAN_MAX) G.units.push(G.offer); G.offer = null; save(); }
function dismiss(u) {
  if (u.leader) return false;
  for (const s of SLOTS) if (u.eq[s]) addItem(u.eq[s]);
  G.units = G.units.filter(x => x !== u);
  return true;
}
function bailCost(u) { return 100 * u.lv; }
function bail(u) { const c = bailCost(u); if (!u.jail || G.gil < c) return false; G.gil -= c; u.jail = 0; return true; }

// ---------- Errands ----------
function refreshBoard() {
  const open = ERRANDS.filter(e => !G.errands.some(x => x.eid === e.id));
  G.board = [];
  while (G.board.length < 3 && open.length) G.board.push(open.splice(ri(open.length), 1)[0].id);
}
function errandOk(e, u) {
  if (!available(u) || u.lv < e.minLv) return false;
  if (!e.job) return true;
  if (RACES[e.job]) return u.race === e.job;
  return u.job === e.job;
}
function sendErrand(eid, u) {
  const e = ERRANDS.find(x => x.id === eid);
  if (!errandOk(e, u)) return false;
  u.errand = eid;
  G.errands.push({ eid, unit: u.id, left: e.len });
  G.board = G.board.filter(x => x !== eid);
  save();
  return true;
}
function tickErrands() {
  const done = [];
  for (const x of G.errands) {
    x.left--;
    if (x.left > 0) continue;
    const e = ERRANDS.find(y => y.id === x.eid), u = unitById(x.unit);
    if (u) {
      u.errand = null;
      const ok = rnd() < Math.min(.95, .6 + (u.lv - e.minLv) * .1);
      const r = { name: e.name, unit: u.name, ok, gil: 0, loot: null, ap: 0, mastered: [] };
      if (ok) {
        G.gil += e.gil; r.gil = e.gil;
        if (e.loot) { G.loot[e.loot] = (G.loot[e.loot] || 0) + 1; (G.seen = G.seen || {})[e.loot] = 1; r.loot = e.loot; }
        r.ap = 25; r.mastered = gainAP(u, 25);
        gainExp(u, 60);
      }
      done.push(r);
    }
  }
  G.errands = G.errands.filter(x => x.left > 0);
  return done;
}
