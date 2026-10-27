// Hollowmark Tactics: screens and battle controller.
'use strict';

const S = { scr: 'title', unit: null, shopTab: 'buy', sel: null, deploy: [], battle: null, results: null };
const $ = sel => document.querySelector(sel);
const esc = s => String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
const sleep = ms => new Promise(r => setTimeout(r, ms / (G && G.fast ? 2 : 1)));
const lawText = id => id ? LAWS[id].name : 'None';

// ---------- Portraits (sprite rendered to a small canvas) ----------
const PCACHE = {};
function portrait(u) {
  const key = u.id + u.job + (u.mon || '') + JSON.stringify(u.eq || {});
  if (PCACHE[key]) return PCACHE[key];
  const c = document.createElement('canvas'); c.width = c.height = 96;
  const g = c.getContext('2d');
  g.translate(48, 86); g.scale(2, 2);
  const fake = { u, id: u.id, race: u.race, job: u.job, mon: u.mon, s: calcStats(u), x: 0, f: 1 };
  try { sprite(g, fake, false); } catch (e) { /* draw nothing */ }
  return (PCACHE[key] = c.toDataURL());
}
const pimg = (u, cls) => `<img class="${cls || 'pt'}" src="${portrait(u)}" alt="">`;

// ---------- Shell ----------
function render() {
  const app = $('#app');
  app.className = 'scr-' + S.scr;
  if (S.scr === 'battle') return;
  const tabs = S.scr !== 'title' && S.scr !== 'results' && S.scr !== 'deploy';
  app.innerHTML = (tabs ? hud() : '') + '<main id="main">' + screen() + '</main>' + (tabs ? navTabs() : '') + '<div id="sheet" hidden></div><div id="toast" hidden></div>';
  if (S.scr === 'map') drawWorld();
}
function hud() {
  return `<header class="hud"><div class="clan">${esc(G.clan)}</div><div class="hudr"><span class="gil">${G.gil.toLocaleString()} <small>gil</small></span><span class="day">Day ${G.day}</span><button class="ico" data-a="guide" aria-label="How to play">?</button></div></header>`;
}
function navTabs() {
  const t = [['map', 'World'], ['clan', 'Clan'], ['shop', 'Shop'], ['pub', 'Pub']];
  const cur = S.scr === 'unit' ? 'clan' : S.scr;
  return `<nav class="tabs">${t.map(([k, n]) => `<button data-a="tab" data-v="${k}" class="${cur === k ? 'on' : ''}">${n}</button>`).join('')}</nav>`;
}
function screen() {
  switch (S.scr) {
    case 'title': return titleScr();
    case 'map': return mapScr();
    case 'clan': return clanScr();
    case 'unit': return unitScr();
    case 'shop': return shopScr();
    case 'pub': return pubScr();
    case 'deploy': return deployScr();
    case 'results': return resultsScr();
  }
  return '';
}
function go(scr) { S.scr = scr; render(); const m = $('#main'); if (m) m.scrollTop = 0; }
function toast(msg) {
  const t = $('#toast'); if (!t) return;
  t.textContent = msg; t.hidden = false;
  clearTimeout(toast.h); toast.h = setTimeout(() => { t.hidden = true; }, 1800);
}
function sheet(html) { const s = $('#sheet'); s.innerHTML = `<div class="scrim" data-a="close"></div><div class="panel">${html}</div>`; s.hidden = false; }
function closeSheet() { const s = $('#sheet'); if (s) { s.hidden = true; s.innerHTML = ''; } }

// ---------- Title ----------
function titleScr() {
  return `<div class="title">
    <div class="crest"><svg viewBox="0 0 64 80" width="64" height="80" aria-hidden="true"><path d="M8 4h48v40c0 18-14 28-24 32C22 72 8 62 8 44z" fill="none" stroke="currentColor" stroke-width="3"/><path d="M32 16v44M20 30h24" stroke="currentColor" stroke-width="3"/></svg></div>
    <h1>Hollowmark<br><span>Tactics</span></h1>
    <p class="tag">Lead a clan across the borderlands. Learn jobs through the gear you carry, and fight under the eye of the Judges.</p>
    <div class="col">
      ${hasSave() ? '<button class="btn pri" data-a="continue">Continue</button>' : ''}
      <label class="fld"><span>Clan name</span><input id="clanname" maxlength="18" value="Clan Briar"></label>
      <button class="btn ${hasSave() ? '' : 'pri'}" data-a="newgame">${hasSave() ? 'Start over' : 'New game'}</button>
    </div>
  </div>`;
}

// ---------- World map ----------
function mapScr() {
  const k = S.sel || G.loc, L = LOCS[k], law = todaysLaw(), M = nextMission();
  let acts = '';
  if (k !== G.loc) acts += locOpen(k) ? `<button class="btn pri" data-a="travel" data-v="${k}">Travel here (1 day)</button>` : `<p class="muted">Locked. Clear the previous story mission first.</p>`;
  else if (L.town) acts += `<div class="row2"><button class="btn" data-a="tab" data-v="shop">Shop &amp; Bazaar</button><button class="btn" data-a="tab" data-v="pub">Pub</button></div>`;
  else {
    if (M && G.accepted === M.id && M.loc === k) acts += `<button class="btn pri" data-a="deploy" data-v="mission">Begin: ${esc(M.name)}</button>`;
    if (G.cleared[k]) acts += `<button class="btn" data-a="deploy" data-v="skirmish">Patrol (skirmish)</button>`;
    if (!acts) acts = `<p class="muted">Nothing to do here yet. Accept a mission at the Pub.</p>`;
  }
  const hint = M ? (G.accepted === M.id ? `Mission accepted: <b>${esc(M.name)}</b> at ${LOCS[M.loc].name}.` : `A new mission is posted at the Pub.`) : `Chapter 1 complete. Patrol cleared areas to train your clan.`;
  return `<section class="world"><svg id="world" viewBox="0 0 100 140" role="img" aria-label="World map"></svg></section>
  <section class="card loc">
    <div class="lochead"><h2>${esc(L.name)}</h2>${k === G.loc ? '<span class="pill">You are here</span>' : ''}</div>
    <p class="muted">${L.town ? esc(L.desc) : 'Battlefield: ' + MAPS[L.map].name + (G.cleared[k] ? ' · cleared' : '')}</p>
    <div class="law"><span class="lawk">Day ${G.day} law</span><span>Banned: <b>${lawText(law.ban)}</b></span><span>Favored: <b>${lawText(law.fav)}</b></span></div>
    ${acts}
    <p class="hint">${hint}</p>
  </section>`;
}
function drawWorld() {
  const svg = $('#world'); if (!svg) return;
  let s = `<defs><pattern id="hatch" width="3" height="3" patternUnits="userSpaceOnUse"><path d="M0 3L3 0" stroke="rgba(255,255,255,.05)" stroke-width=".5"/></pattern></defs>
  <rect width="100" height="140" fill="var(--sea)"/>
  <path d="M10 130 C2 110 8 92 14 80 C6 64 10 40 22 26 C34 10 58 6 76 12 C92 18 96 40 90 58 C98 74 94 98 84 112 C74 130 40 138 10 130Z" fill="var(--land)"/>
  <path d="M10 130 C2 110 8 92 14 80 C6 64 10 40 22 26 C34 10 58 6 76 12 C92 18 96 40 90 58 C98 74 94 98 84 112 C74 130 40 138 10 130Z" fill="url(#hatch)" stroke="var(--coast)" stroke-width=".8"/>
  <path d="M58 12 C60 30 52 44 56 58 C60 72 70 82 66 100 C64 110 70 120 74 128" fill="none" stroke="var(--river)" stroke-width="1.6" opacity=".8"/>
  <g fill="var(--hill)" opacity=".7"><path d="M20 58l5-8 5 8z"/><path d="M27 56l4-6 4 6z"/><path d="M34 66l4-7 4 7z"/></g>
  <g fill="var(--wood)" opacity=".8">${[[64, 26], [70, 22], [76, 30], [80, 24], [66, 36], [74, 38]].map(([x, y]) => `<circle cx="${x}" cy="${y}" r="3"/>`).join('')}</g>`;
  for (const [a, b] of ROUTES) {
    const A = LOCS[a], Bb = LOCS[b], open = locOpen(a) && locOpen(b);
    s += `<line x1="${A.x}" y1="${A.y}" x2="${Bb.x}" y2="${Bb.y}" stroke="var(--road)" stroke-width="1" stroke-dasharray="${open ? '2 1.5' : '.6 2'}" opacity="${open ? .9 : .4}"/>`;
  }
  const M = nextMission();
  for (const k in LOCS) {
    const L = LOCS[k], open = locOpen(k), sel = (S.sel || G.loc) === k, mis = M && G.accepted === M.id && M.loc === k;
    s += `<g class="node${open ? '' : ' locked'}" data-a="selloc" data-v="${k}" tabindex="0" role="button" aria-label="${L.name}">
      <circle cx="${L.x}" cy="${L.y}" r="9" fill="transparent"/>
      ${sel ? `<circle cx="${L.x}" cy="${L.y}" r="6.5" fill="none" stroke="var(--brass)" stroke-width=".8" stroke-dasharray="1.5 1"/>` : ''}
      ${L.town ? `<rect x="${L.x - 3.5}" y="${L.y - 3.5}" width="7" height="7" fill="var(--town)" stroke="var(--ink)" stroke-width=".6" transform="rotate(45 ${L.x} ${L.y})"/>`
        : `<circle cx="${L.x}" cy="${L.y}" r="3.6" fill="${G.cleared[k] ? 'var(--cleared)' : open ? 'var(--open)' : 'var(--lockc)'}" stroke="var(--ink)" stroke-width=".6"/>`}
      ${mis ? `<path d="M${L.x + 3} ${L.y - 4}v-7l5 2-5 2" fill="var(--danger)" stroke="var(--ink)" stroke-width=".3"/>` : ''}
      <text x="${L.x}" y="${L.y + 8.5}" text-anchor="middle" class="nlabel">${L.name}</text>
    </g>`;
  }
  const P = LOCS[G.loc];
  s += `<g class="me"><path d="M${P.x - 1} ${P.y - 4}v-9" stroke="var(--ink)" stroke-width=".6"/><path d="M${P.x - 1} ${P.y - 13}h6l-1.5 2 1.5 2h-6z" fill="var(--brass)"/></g>`;
  svg.innerHTML = s;
}

// ---------- Clan ----------
function unitTags(u) {
  return (u.leader ? '<span class="pill">Leader</span>' : '') + (u.errand ? '<span class="pill warn">On errand</span>' : '') + (u.jail ? `<span class="pill bad">Jail ${u.jail}</span>` : '');
}
function clanScr() {
  return `<div class="pagehead"><h2>${esc(G.clan)}</h2><span class="muted">${G.units.length}/${CLAN_MAX} members</span></div>
  <div class="roster">${G.units.map(u => {
    const s = calcStats(u);
    return `<button class="ucard" data-a="unit" data-v="${u.id}">${pimg(u)}<div class="uinfo"><b>${esc(u.name)}</b><span>${RACES[u.race].name} · ${JOBS[u.job].name}${u.sub ? ' / ' + JOBS[u.sub].name : ''}</span><span class="stats">Lv ${u.lv} · HP ${s.mhp} · MP ${s.mmp}</span>${unitTags(u)}</div></button>`;
  }).join('')}</div>`;
}
function statRow(s) {
  const L = [['HP', s.mhp], ['MP', s.mmp], ['Atk', s.atk], ['Def', s.def], ['Mag', s.mag], ['Res', s.res], ['Spd', s.spd], ['Move', s.mv], ['Jump', s.jp], ['Evade', s.ev]];
  return `<div class="statgrid">${L.map(([k, v]) => `<div><span>${k}</span><b>${v}</b></div>`).join('')}</div>`;
}
function unitScr() {
  const u = unitById(S.unit); if (!u) return clanScr();
  const s = calcStats(u), t = taught(u);
  const slots = [['w', 'Weapon'], ['o', 'Shield'], ['h', 'Head'], ['b', 'Body'], ['a', 'Accessory']];
  ensureProfs(u);
  const known = knownSkills(u);
  const abRow = id => {
    const a = AB[id], from = t[id] ? ITEMS[t[id]].name : 'Kept';
    return `<div class="abrow m"><div><b>${a.name}</b> <span class="kind">${a.type === 'A' ? (a.mp ? a.mp + ' MP' : 'Action') : a.type === 'R' ? 'Reaction' : 'Support'}${a.type === 'A' ? ' · ' + PROFS[pfOf({ s: s }, a)] : ''}</span><div class="small muted">${esc(a.desc)}</div></div><div class="abstate"><span class="muted small">${esc(from)}</span></div></div>`;
  };
  const profRows = Object.keys(PROFS).map(k => `<div class="abrow"><div><b>${PROFS[k]}</b></div><div class="abstate"><span class="small">Lv ${u.pf[k].lv} · MP Lv ${u.mpl[k].lv}</span></div></div>`).join('');
  return `<div class="pagehead"><button class="back" data-a="tab" data-v="clan" aria-label="Back to clan">‹</button><h2>${esc(u.name)}</h2>${unitTags(u)}</div>
  <section class="card uhead">${pimg(u, 'pt big')}<div class="uinfo">
    <span>${RACES[u.race].name} · Lv ${u.lv}</span>
    <span class="bar exp"><i style="width:${u.exp}%"></i></span><span class="small muted">EXP ${u.exp}/100</span>
  </div></section>
  <section class="card">
    <div class="kv" data-a="pickjob"><span>Job</span><b>${JOBS[u.job].name}</b><i>›</i></div>
    <div class="kv" data-a="picksub"><span>Secondary</span><b>${u.sub ? JOBS[u.sub].name : 'None'}</b><i>›</i></div>
    <div class="kv" data-a="pickrs" data-v="R"><span>Reaction</span><b>${u.r ? AB[u.r].name : 'None'}</b><i>›</i></div>
    <div class="kv" data-a="pickrs" data-v="S"><span>Support</span><b>${u.s ? AB[u.s].name : 'None'}</b><i>›</i></div>
  </section>
  ${statRow(s)}
  <h3>Equipment</h3>
  <section class="card">${slots.map(([k, n]) => {
    const id = u.eq[k], it = id && ITEMS[id];
    const dis = k === 'o' && !(JOBS[u.job].sh || u.s === 'shieldbearer');
    return `<div class="kv${dis ? ' dis' : ''}" ${dis ? '' : `data-a="pickeq" data-v="${k}"`}><span>${n}</span><b>${it ? it.name : dis ? 'Not usable' : '—'}${it ? `<small>${statStr(it.stats)}</small>` : ''}</b><i>${dis ? '' : '›'}</i></div>`;
  }).join('')}</section>
  <h3>Proficiencies</h3>
  <p class="small muted">Using a skill raises its proficiency (more power) and its MP level (bigger pool). Each proficiency has its own MP pool.</p>
  <section class="card">${profRows}</section>
  <h3>Skills</h3>
  <p class="small muted">Equipped gear teaches skills while it is worn.</p>
  <section class="card">${known.length ? known.map(abRow).join('') : '<p class="muted">Equip a weapon to gain skills.</p>'}</section>
  ${u.leader ? '' : `<button class="btn ghost danger" data-a="dismiss">Dismiss ${esc(u.name)}</button>`}`;
}
function itemsTeaching(id) { return Object.keys(ITEMS).filter(k => ITEMS[k].teach.includes(id)); }
function statStr(st) { return Object.keys(st).map(k => ({ atk: 'Atk', def: 'Def', mag: 'Mag', res: 'Res', spd: 'Spd', hp: 'HP', mp: 'MP', ev: 'Eva', mv: 'Move', jp: 'Jump' }[k] + ' +' + st[k])).join(' · '); }
function teachStr(it, u) {
  return it.teach.map(id => {
    const a = AB[id];
    return `<span class="teach">${a.name}${a.type === 'A' ? ` <small>${PROFS[pfOf({ s: { wt: it.t } }, a)]}</small>` : ''}</span>`;
  }).join('');
}
function pickEquip(slot) {
  const u = unitById(S.unit), cur = u.eq[slot] && ITEMS[u.eq[slot]];
  const list = Object.keys(G.inv).map(k => ITEMS[k]).filter(it => it.slot === slot && canEquip(u, it));
  sheet(`<h3>${{ w: 'Weapon', o: 'Shield', h: 'Head', b: 'Body', a: 'Accessory' }[slot]}</h3>
    ${cur ? `<button class="opt" data-a="equip" data-v="${slot}:"><b>Remove ${cur.name}</b></button>` : ''}
    ${list.length ? list.map(it => `<button class="opt" data-a="equip" data-v="${slot}:${it.id}"><div class="optl"><b>${it.name}</b><small>${statStr(it.stats)}${it.el ? ' · ' + it.el : ''} · owned ${G.inv[it.id]}</small><div>${teachStr(it, u)}</div></div></button>`).join('')
      : '<p class="muted">No usable items in your inventory for this slot. Buy some at the Shop.</p>'}
    <button class="btn" data-a="close">Close</button>`);
}
function pickJob() {
  const u = unitById(S.unit);
  sheet(`<h3>Change job</h3><div class="jobgrid">${jobsFor(u.race).map(j => {
    const J = JOBS[j], open = jobOpen(u, j);
    return `<button class="job${u.job === j ? ' cur' : ''}${open ? '' : ' lock'}" ${open ? `data-a="setjob" data-v="${j}"` : 'disabled'}><span class="sw" style="background:${J.col}"></span><b>${J.name}</b><small>${esc(J.desc)}</small></button>`;
  }).join('')}</div><p class="small muted">${esc(JOBS[u.job].desc)}</p><button class="btn" data-a="close">Close</button>`);
}
function pickSub() {
  const u = unitById(S.unit);
  sheet(`<h3>Secondary</h3><p class="small muted">Secondary jobs are retired. Skills now come from gear.</p>
    <button class="btn" data-a="close">Close</button>`);
}
function pickRS(type) {
  const u = unitById(S.unit);
  const list = knownSkills(u).filter(id => AB[id].type === type);
  sheet(`<h3>${type === 'R' ? 'Reaction' : 'Support'} ability</h3><p class="small muted">Choose from ${type === 'R' ? 'reactions' : 'supports'} taught by your equipped gear.</p>
    <button class="opt" data-a="setrs" data-v="${type}:"><b>None</b></button>
    ${list.length ? list.map(id => `<button class="opt${(type === 'R' ? u.r : u.s) === id ? ' cur' : ''}" data-a="setrs" data-v="${type}:${id}"><b>${AB[id].name}</b><small>${esc(AB[id].desc)}</small></button>`).join('') : '<p class="muted">Nothing equipped teaches one. Armor and accessories teach these.</p>'}
    <button class="btn" data-a="close">Close</button>`);
}

// ---------- Shop ----------
const KEEPER = ['Steel for the road, coin for the keeper.', 'New stock comes in when the roads get safer.', 'Bring me odd bits from your fights and I\'ll make something of them.', 'Every blade here teaches something, if you carry it long enough.'];
function shopScr() {
  const t = S.shopTab;
  let body = '';
  if (t === 'buy') {
    const its = shopItems();
    const grp = [['Weapons', its.filter(i => i.slot === 'w')], ['Shields & headgear', its.filter(i => i.slot === 'o' || i.slot === 'h')], ['Body armor', its.filter(i => i.slot === 'b')], ['Accessories', its.filter(i => i.slot === 'a')]];
    body = grp.map(([n, l]) => `<h3>${n}</h3><div class="card list">${l.map(it => `<div class="shoprow"><div class="optl"><b>${it.name}</b><small>${it.slot === 'w' ? WTYPES[it.t].name : it.t === 'acc' ? 'Accessory' : it.t[0].toUpperCase() + it.t.slice(1)} · ${statStr(it.stats)}${G.inv[it.id] ? ' · owned ' + G.inv[it.id] : ''}</small><div>${teachStr(it)}</div></div><button class="btn sm" data-a="buy" data-v="${it.id}" ${G.gil < it.price ? 'disabled' : ''}>${it.price}</button></div>`).join('')}</div>`).join('')
      + `<h3>Items</h3><div class="card list">${shopCons().map(k => `<div class="shoprow"><div class="optl"><b>${CONS[k].name}</b><small>${CONS[k].desc} · have ${G.cons[k] || 0}</small></div><button class="btn sm" data-a="buyc" data-v="${k}" ${G.gil < CONS[k].price ? 'disabled' : ''}>${CONS[k].price}</button></div>`).join('')}</div>`;
  } else if (t === 'sell') {
    const inv = Object.keys(G.inv), cons = Object.keys(G.cons).filter(k => G.cons[k]), loot = Object.keys(G.loot).filter(k => G.loot[k]);
    body = `<p class="small muted">Equipped gear is not listed. Unequip it first to sell it.</p>`
      + (inv.length ? `<h3>Equipment</h3><div class="card list">${inv.map(k => `<div class="shoprow"><div class="optl"><b>${ITEMS[k].name} ×${G.inv[k]}</b><small>${statStr(ITEMS[k].stats)}</small></div><button class="btn sm" data-a="sell" data-v="item:${k}">+${sellPrice(k, 'item')}</button></div>`).join('')}</div>` : '')
      + (cons.length ? `<h3>Items</h3><div class="card list">${cons.map(k => `<div class="shoprow"><div class="optl"><b>${CONS[k].name} ×${G.cons[k]}</b></div><button class="btn sm" data-a="sell" data-v="cons:${k}">+${sellPrice(k, 'cons')}</button></div>`).join('')}</div>` : '')
      + (loot.length ? `<h3>Loot</h3><div class="card list">${loot.map(k => `<div class="shoprow"><div class="optl"><b>${LOOT[k].name} ×${G.loot[k]}</b><small>Needed for Bazaar recipes</small></div><button class="btn sm" data-a="sell" data-v="loot:${k}">+${sellPrice(k, 'loot')}</button></div>`).join('')}</div>` : '')
      || '<p class="muted">Nothing to sell.</p>';
  } else {
    const known = knownRecipes(), hidden = RECIPES.length - known.length;
    body = `<p class="small muted">Combine loot from battles into gear you can't buy anywhere else. Once crafted, the item stays in the shop's stock.</p>
      <div class="card list">${known.map(r => {
        const it = ITEMS[r.out];
        return `<div class="shoprow"><div class="optl"><b>${it.name}</b><small>${it.slot === 'w' ? WTYPES[it.t].name : 'Accessory'} · ${statStr(it.stats)}</small><div>${teachStr(it)}</div><div class="need">${Object.keys(r.need).map(k => `<span class="${(G.loot[k] || 0) >= r.need[k] ? 'have' : ''}">${LOOT[k].name} ${G.loot[k] || 0}/${r.need[k]}</span>`).join('')}<span class="${G.gil >= r.gil ? 'have' : ''}">${r.gil} gil</span></div></div><button class="btn sm" data-a="craft" data-v="${r.id}" ${canCraft(r) ? '' : 'disabled'}>Craft</button></div>`;
      }).join('') || '<p class="muted pad">No recipes yet. Win battles to collect loot.</p>'}</div>
      ${hidden ? `<p class="small muted">${hidden} more recipe${hidden > 1 ? 's' : ''} will appear as you find new kinds of loot.</p>` : ''}`;
  }
  return `<div class="pagehead"><h2>Harrowgate Shop</h2></div><p class="keeper">“${KEEPER[G.day % KEEPER.length]}”</p>
  <div class="seg">${[['buy', 'Buy'], ['sell', 'Sell'], ['bazaar', 'Bazaar']].map(([k, n]) => `<button class="${t === k ? 'on' : ''}" data-a="shoptab" data-v="${k}">${n}</button>`).join('')}</div>${body}`;
}

// ---------- Pub ----------
function pubScr() {
  const M = nextMission();
  let mis;
  if (M) mis = `<div class="card mission"><div class="lochead"><h3>${esc(M.name)}</h3><span class="pill">Story</span></div>
    <p>${esc(M.brief)}</p>
    <p class="small muted">${LOCS[M.loc].name} · up to ${M.deploy} units · Banned: ${lawText(M.law.ban)} · Favored: ${lawText(M.law.fav)}</p>
    <p class="small muted">Reward: ${M.reward.gil} gil${G.stage < 3 ? ', new shop stock' : ''}</p>
    ${G.accepted === M.id ? `<p class="ok small">Accepted. Travel to ${LOCS[M.loc].name} on the World map.</p>` : `<button class="btn pri" data-a="accept">Accept mission</button>`}</div>`;
  else mis = `<div class="card"><h3>Chapter 1 complete</h3><p class="muted">The Hag is gone and the roads are quiet for now. Keep training: patrol cleared areas, run errands and master new jobs.</p></div>`;
  const busy = G.errands.map(x => { const e = ERRANDS.find(y => y.id === x.eid), u = unitById(x.unit); return `<div class="shoprow"><div class="optl"><b>${e.name}</b><small>${u ? esc(u.name) : '?'} · back in ${x.left} battle${x.left > 1 ? 's' : ''}</small></div></div>`; }).join('');
  const board = G.board.map(eid => { const e = ERRANDS.find(y => y.id === eid); return `<div class="shoprow"><div class="optl"><b>${e.name}</b><small>${e.job ? (RACES[e.job] ? RACES[e.job].name : JOBS[e.job].name) + ' · ' : ''}Lv ${e.minLv}+ · ${e.len} battles · ${e.gil} gil${e.loot ? ' + ' + LOOT[e.loot].name : ''}</small></div><button class="btn sm" data-a="errand" data-v="${eid}">Send</button></div>`; }).join('');
  const jailed = G.units.filter(u => u.jail);
  return `<div class="pagehead"><h2>The Lantern Pub</h2></div>
  <h3>Missions</h3>${mis}
  ${G.offer ? recruitCard() : ''}
  <h3>Errands</h3><p class="small muted">Send a unit away. They miss battles while gone, and come back with gil, loot and AP.</p>
  <div class="card list">${board || '<p class="muted pad">No errands posted. Check back after your next battle.</p>'}</div>
  ${busy ? `<h3>Out on errands</h3><div class="card list">${busy}</div>` : ''}
  ${jailed.length ? `<h3>Jail</h3><div class="card list">${jailed.map(u => `<div class="shoprow"><div class="optl"><b>${esc(u.name)}</b><small>Out after ${u.jail} more battle${u.jail > 1 ? 's' : ''}</small></div><button class="btn sm" data-a="bail" data-v="${u.id}" ${G.gil < bailCost(u) ? 'disabled' : ''}>Bail ${bailCost(u)}</button></div>`).join('')}</div>` : ''}
  <h3>Judges &amp; laws</h3><div class="card"><p class="small">Every battle is watched by a Judge. Each day bans one kind of action. Break it once for a yellow card; twice and the unit is sent to jail for 2 battles. Favored actions and knockouts earn JP, which pays for Combo attacks.</p></div>`;
}
function recruitCard() {
  const u = G.offer;
  return `<h3>Someone wants to join</h3><div class="card"><div class="ucard flat">${pimg(u)}<div class="uinfo"><b>${esc(u.name)}</b><span>${RACES[u.race].name} · ${JOBS[u.job].name} · Lv ${u.lv}</span><span class="small muted">${esc(RACES[u.race].desc)}</span></div></div>
  <div class="row2"><button class="btn pri" data-a="recruit" data-v="1" ${G.units.length >= CLAN_MAX ? 'disabled' : ''}>Welcome aboard</button><button class="btn" data-a="recruit" data-v="0">Decline</button></div></div>`;
}

// ---------- Deploy ----------
function deployScr() {
  const mission = S.kind === 'mission' ? nextMission() : null;
  const max = mission ? mission.deploy : 5, law = mission ? mission.law : todaysLaw();
  return `<div class="pagehead"><button class="back" data-a="tab" data-v="map" aria-label="Back to map">‹</button><h2>${mission ? esc(mission.name) : 'Patrol: ' + LOCS[G.loc].name}</h2></div>
  ${mission ? `<p class="brief">${esc(mission.brief)}</p>` : ''}
  <div class="law"><span class="lawk">Law</span><span>Banned: <b>${lawText(law.ban)}</b></span><span>Favored: <b>${lawText(law.fav)}</b></span></div>
  <p class="small muted">Choose up to ${max} units. ${S.deploy.length}/${max} selected.</p>
  <div class="roster">${G.units.map(u => {
    const ok = available(u), on = S.deploy.includes(u.id);
    return `<button class="ucard${on ? ' on' : ''}${ok ? '' : ' dis'}" ${ok ? `data-a="toggledeploy" data-v="${u.id}"` : 'disabled'}>${pimg(u)}<div class="uinfo"><b>${esc(u.name)}</b><span>${JOBS[u.job].name}${u.sub ? ' / ' + JOBS[u.sub].name : ''} · Lv ${u.lv}</span>${unitTags(u)}</div><span class="check">${on ? '✓' : ''}</span></button>`;
  }).join('')}</div>
  <div class="stick"><button class="btn pri" data-a="fight" ${S.deploy.length ? '' : 'disabled'}>Fight</button></div>`;
}

// ---------- Results ----------
function resultsScr() {
  const R = S.results;
  const unitsHtml = R.units.map(x => {
    const u = unitById(x.id); if (!u) return '';
    return `<div class="ucard flat">${pimg(u)}<div class="uinfo"><b>${esc(u.name)}</b><span>Lv ${u.lv} · ${JOBS[u.job].name}</span>
      ${(x.learned || []).map(id => `<span class="ok small">Learned ${AB[id].name}</span>`).join('')}
      ${R.jailed.includes(u.id) ? '<span class="bad small">Sent to jail</span>' : ''}</div></div>`;
  }).join('');
  const lootStr = Object.keys(R.loot).map(k => LOOT[k].name + ' ×' + R.loot[k]).concat(Object.keys(R.items).map(k => CONS[k].name + ' ×' + R.items[k])).concat(R.stolen.map(id => ITEMS[id].name + ' (stolen)'));
  const story = R.story === 'm3' ? `<div class="card"><h3>Chapter 1 complete</h3><p>The Mire Hag sinks into the bog for the last time. Word of ${esc(G.clan)} spreads along the border roads. The Bazaar now trades in the hag's charms.</p></div>` : R.story ? `<p class="gold">New stock is available at the shop, and a new location has opened.</p>` : '';
  return `<div class="result ${R.won ? 'win' : 'loss'}"><h1>${R.won ? 'Victory' : 'Defeat'}</h1>
  ${R.won ? `<p>+${R.gil} gil${lootStr.length ? ' · ' + lootStr.join(', ') : ''}</p>` : '<p>Your clan retreats to regroup. No rewards this time.</p>'}
  ${R.gilLost ? `<p class="bad">Enemy thieves took ${R.gilLost} gil.</p>` : ''}
  ${R.lost.length ? `<p class="bad">Lost to thieves: ${R.lost.map(x => ITEMS[x.item].name).join(', ')}</p>` : ''}</div>
  ${story}
  <div class="roster">${unitsHtml}</div>
  ${R.errands.length ? `<h3>Errands returned</h3><div class="card list">${R.errands.map(e => `<div class="shoprow"><div class="optl"><b>${esc(e.name)}</b><small>${esc(e.unit)}: ${e.ok ? 'success, +' + e.gil + ' gil' + (e.loot ? ', ' + LOOT[e.loot].name : '') + (e.mastered.length ? ', mastered ' + e.mastered.map(i => AB[i].name).join(', ') : '') : 'failed'}</small></div></div>`).join('')}</div>` : ''}
  ${G.offer ? recruitCard() : ''}
  <div class="stick"><button class="btn pri" data-a="tab" data-v="map">Continue</button></div>`;
}

// ---------- Guide ----------
function guide() {
  sheet(`<h3>How to play</h3><div class="guide">
  <p><b>Turns.</b> Units act in order of Speed (the strip at the top of the battle). On a turn you may Move and Act once each, in either order, then choose a facing. Skipping Move or Act makes your next turn come sooner.</p>
  <p><b>Height and facing.</b> Jump limits how high a unit can climb. Attacks from the side or back are much more likely to hit, so watch which way your units face when they wait.</p>
  <p><b>Jobs.</b> Each race has its own jobs. A job sets what gear you can wear, how far you move and how you grow.</p>
  <p><b>Skills.</b> Gear teaches skills while you wear it. Each skill belongs to one of six proficiencies. Using it raises that proficiency (more power) and its MP level (bigger MP pool). Every proficiency has its own pool.</p>
  <p><b>Laws.</b> Each day bans one kind of action. A first offense earns a yellow card, a second sends the unit to jail. Favored actions and KOs give JP. With 3 JP a unit can use a Combo, which grows stronger for every ally next to the target.</p>
  <p><b>Gear.</b> New stock appears after each story mission. Loot from battles can be combined at the Bazaar for gear the shop doesn't sell. Rogues can steal gear from enemy clans.</p>
  <p><b>Map controls.</b> Drag to pan, pinch or use +/− to zoom, and the rotate buttons to look around cliffs.</p>
  </div><label class="toggle"><input type="checkbox" id="fastopt" ${G && G.fast ? 'checked' : ''} data-a="fast"> Fast battle animations</label><button class="btn" data-a="close">Close</button>`);
}

// ---------- Actions ----------
const ACT = {
  close: closeSheet,
  guide,
  fast: (v, el) => { G.fast = el.checked; save(); },
  newgame: v => {
    if (hasSave() && v !== 'ok') { sheet(`<h3>Start over?</h3><p>Your current clan and progress will be replaced.</p><div class="row2"><button class="btn danger" data-a="newgame" data-v="ok">Start over</button><button class="btn" data-a="close">Cancel</button></div>`); return; }
    closeSheet(); newGame(($('#clanname') || {}).value || 'Clan Briar'); save(); S.sel = null; go('map'); setTimeout(guide, 300); },
  continue: () => { load(); S.sel = null; go('map'); },
  tab: v => { closeSheet(); S.sel = null; go(v); },
  selloc: v => { S.sel = v; render(); },
  travel: v => { if (travel(v)) { save(); S.sel = null; render(); toast('Day ' + G.day + ': arrived at ' + LOCS[v].name); } },
  unit: v => { S.unit = v; go('unit'); },
  pickeq: v => pickEquip(v),
  equip: v => { const [slot, id] = v.split(':'); equip(unitById(S.unit), slot, id || null); save(); closeSheet(); render(); },
  pickjob: () => pickJob(),
  setjob: v => { changeJob(unitById(S.unit), v); save(); closeSheet(); render(); toast('Job changed to ' + JOBS[v].name); },
  picksub: () => pickSub(),
  setsub: v => { unitById(S.unit).sub = v || null; save(); closeSheet(); render(); },
  pickrs: v => pickRS(v),
  setrs: v => { const [t, id] = v.split(':'), u = unitById(S.unit); if (t === 'R') u.r = id || null; else { u.s = id || null; if (u.eq.o && !canEquip(u, ITEMS[u.eq.o])) equip(u, 'o', null); } save(); closeSheet(); render(); },
  dismiss: () => { const u = unitById(S.unit); sheet(`<h3>Dismiss ${esc(u.name)}?</h3><p>Their equipment returns to your inventory. This can't be undone.</p><div class="row2"><button class="btn danger" data-a="dismissok">Dismiss</button><button class="btn" data-a="close">Keep</button></div>`); },
  dismissok: () => { dismiss(unitById(S.unit)); save(); closeSheet(); go('clan'); },
  shoptab: v => { S.shopTab = v; render(); },
  buy: v => { if (buy(v, 'item')) { save(); render(); toast('Bought ' + ITEMS[v].name); } },
  buyc: v => { if (buy(v, 'cons')) { save(); render(); toast('Bought ' + CONS[v].name); } },
  sell: v => { const [k, id] = v.split(':'); if (sell(id, k)) { save(); render(); } },
  craft: v => { const r = RECIPES.find(x => x.id === v); if (craft(r)) { save(); render(); toast('Crafted ' + ITEMS[r.out].name + '. Now sold in the shop.'); } },
  accept: () => { G.accepted = nextMission().id; save(); render(); toast('Mission accepted'); },
  errand: v => {
    const e = ERRANDS.find(x => x.id === v), ok = G.units.filter(u => errandOk(e, u));
    sheet(`<h3>${e.name}</h3><p class="small muted">Needs ${e.job ? (RACES[e.job] ? RACES[e.job].name : 'a ' + JOBS[e.job].name) + ', ' : ''}level ${e.minLv}+. Away for ${e.len} battles. Higher level means better odds.</p>
      ${ok.length ? ok.map(u => `<button class="opt" data-a="senderrand" data-v="${v}:${u.id}"><div class="ucard flat">${pimg(u)}<div class="uinfo"><b>${esc(u.name)}</b><span>${JOBS[u.job].name} · Lv ${u.lv}</span></div></div></button>`).join('') : '<p class="muted">Nobody available meets the requirements.</p>'}
      <button class="btn" data-a="close">Close</button>`);
  },
  senderrand: v => { const [eid, uid] = v.split(':'); sendErrand(eid, unitById(uid)); closeSheet(); render(); toast('Errand started'); },
  bail: v => { if (bail(unitById(v))) { save(); render(); toast('Released from jail'); } },
  recruit: v => { if (v === '1') acceptRecruit(); else { G.offer = null; save(); } render(); },
  deploy: v => { S.kind = v; const max = v === 'mission' ? nextMission().deploy : 5; S.deploy = G.units.filter(available).slice(0, max).map(u => u.id); go('deploy'); },
  toggledeploy: v => {
    const max = S.kind === 'mission' ? nextMission().deploy : 5;
    if (S.deploy.includes(v)) S.deploy = S.deploy.filter(x => x !== v); else if (S.deploy.length < max) S.deploy.push(v); else toast('Up to ' + max + ' units');
    render();
  },
  fight: () => startBattle(),
};
document.addEventListener('click', e => {
  const el = e.target.closest('[data-a]');
  if (!el || el.disabled) return;
  const f = ACT[el.dataset.a] || (BACT[el.dataset.a]);
  if (f) f(el.dataset.v, el, e);
});
document.addEventListener('keydown', e => { if ((e.key === 'Enter' || e.key === ' ') && e.target.matches('g[data-a]')) { e.preventDefault(); e.target.dispatchEvent(new MouseEvent('click', { bubbles: true })); } });

// =====================================================================
// Battle controller
// =====================================================================
const BS = { mode: 'idle', actor: null, resolve: null, ab: null, center: null, reach: null, inspect: null };
let B = null;

function startBattle() {
  B = buildBattle(S.kind, S.deploy);
  S.scr = 'battle';
  const app = $('#app');
  app.className = 'scr-battle';
  app.innerHTML = `<div class="bwrap">
    <div class="btop"><div id="order" class="order" aria-label="Turn order"></div>
      <div class="lawbar"><span>Banned: <b>${lawText(B.law.ban)}</b></span><span>Favored: <b>${lawText(B.law.fav)}</b></span><button class="ico" data-a="bmenu" aria-label="Battle menu">≡</button></div></div>
    <canvas id="bv"></canvas>
    <div class="vctl"><button class="ico" data-a="rot" data-v="-1" aria-label="Rotate left">⟲</button><button class="ico" data-a="rot" data-v="1" aria-label="Rotate right">⟳</button><button class="ico" data-a="zoom" data-v="1.2" aria-label="Zoom in">+</button><button class="ico" data-a="zoom" data-v="0.83" aria-label="Zoom out">−</button></div>
    <div id="blog" class="blog" aria-live="polite"></div>
    <div id="bp" class="bpanel"></div>
  </div><div id="sheet" hidden></div><div id="toast" hidden></div>`;
  const cv = $('#bv');
  viewInit(cv, B);
  bindCanvas(cv);
  window.onresize = () => { if (S.scr === 'battle') viewResize(); };
  battleLoop();
}
async function battleLoop() {
  logMsg(B.mission ? B.mission.name : 'Skirmish at ' + B.map.name);
  while (!B.over) {
    const a = nextActor(B);
    if (!a) break;
    BS.actor = a; V.active = a; centerOn(a.x, a.y);
    drawOrder();
    const st = startTurn(B, a);
    await playEvents(st.ev);
    if (checkEnd(B)) break;
    if (!st.skip && !a.ko) {
      if (a.team === 0) await playerTurn(a); else await enemyTurn(a);
    }
    if (!a.ko && !a.jailed) endTurn(B, a);
    else if (a.ko) a.ct = 0;
  }
  V.active = null;
  await sleep(500);
  panel(`<div class="bend ${B.over === 1 ? 'win' : 'loss'}"><b>${B.over === 1 ? 'Victory!' : 'Defeat'}</b></div>`);
  await sleep(1200);
  viewStop();
  S.results = finishBattle(B);
  window.onresize = null;
  go('results');
}
function logMsg(t) { const l = $('#blog'); if (!l) return; l.textContent = t; l.classList.remove('fade'); void l.offsetWidth; l.classList.add('fade'); }
function drawOrder() {
  const o = $('#order'); if (!o) return;
  const list = turnOrder(B, 9);
  if (BS.actor && list[0] !== BS.actor) list.unshift(BS.actor);
  o.innerHTML = list.slice(0, 9).map((u, i) => `<div class="oc t${u.team}${i === 0 ? ' cur' : ''}" title="${esc(u.name)}"><img src="${portrait(u.u)}" alt=""></div>`).join('');
}
function unitPanel(u) {
  const sts = Object.keys(u.st).map(k => `<span class="st" style="--c:${STATUS[k].col}">${STATUS[k].name}</span>`).join('');
  return `<div class="bu">${pimg(u.u, 'pt')}<div class="bui"><div><b>${esc(u.name)}</b> <small>Lv ${u.lv} · ${u.mon ? 'Monster' : JOBS[u.job].name}</small>${u.jp ? ` <span class="jp">${u.jp} JP</span>` : ''}${u.cards ? ' <span class="card-y">Yellow card</span>' : ''}</div>
    <div class="hpb"><i style="width:${u.hp / u.s.mhp * 100}%"></i></div><small>HP ${u.hp}/${u.s.mhp}${u.s.mmp ? ` · MP ${mpTotal(u)}` : ''} · CT ${Math.max(0, Math.round(u.ct))}</small>${sts ? `<div class="sts">${sts}</div>` : ''}</div></div>`;
}
function panel(html) { const p = $('#bp'); if (p) p.innerHTML = html; }

// ----- Player turn state machine -----
function playerTurn(a) {
  return new Promise(res => { BS.resolve = res; BS.mode = 'menu'; showMenu(); });
}
function showMenu() {
  const a = BS.actor;
  clearHL(); V.cursor = null;
  BS.mode = 'menu';
  const canAct = !a.acted && !a.st.disable;
  panel(unitPanel(a) + `<div class="cmds">
    <button data-a="bmove" ${canMove(a) ? '' : 'disabled'}>Move</button>
    <button data-a="bact" ${canAct ? '' : 'disabled'}>Act</button>
    ${a.vessel || objsInReach(B, a).length ? `<button data-a="bvessel">Vessel${objsInReach(B, a).length ? ' (' + objsInReach(B, a).length + ')' : ''}</button>` : ''}
    <button data-a="bwait">Wait</button>
    ${a.moved && !a.acted && (a.x !== a.start.x || a.y !== a.start.y) ? '<button data-a="bundo">Undo move</button>' : '<button data-a="bcenter">Find</button>'}
  </div>`);
}
function clearHL() { V.hl = new Map(); V.area = new Set(); }
function showInspect(u) {
  BS.inspect = u;
  panel(unitPanel(u) + `<div class="statline">Atk ${eff(u, 'atk')} · Def ${eff(u, 'def')} · Mag ${eff(u, 'mag')} · Res ${eff(u, 'res')} · Spd ${Math.round(speed(u))} · Move ${eff(u, 'mv')} · Jump ${eff(u, 'jp')} · Eva ${eff(u, 'ev')}</div><div class="cmds"><button data-a="bback">Back</button></div>`);
}
function actList(a) {
  const groups = [{ name: 'Basic', ids: ['fight'] }];
  for (const s of actionSets(a.u, a)) groups.push({ name: s.name, ids: s.list });
  const items = Object.keys(CONS).filter(k => B.inv[k] > 0).map(k => 'item:' + k);
  if (items.length) groups.push({ name: 'Items', ids: items });
  groups.push({ name: 'Judge', ids: ['combo'] });
  return groups;
}
const BACT = {
  rot: v => rotateView(+v),
  zoom: v => zoomBy(+v),
  bcenter: () => centerOn(BS.actor.x, BS.actor.y),
  bmenu: () => sheet(`<h3>Battle</h3><button class="opt" data-a="guide"><b>How to play</b></button><button class="opt" data-a="flee"><b>Retreat</b><small>Leave the battle. Counts as a defeat.</small></button><button class="btn" data-a="close">Close</button>`),
  flee: () => { closeSheet(); for (const u of B.units) if (u.team === 0) u.ko = true; B.over = -1; if (BS.resolve) { const r = BS.resolve; BS.resolve = null; r(); } },
  bback: () => { BS.inspect = null; if (BS.mode === 'menu') showMenu(); else if (BS.mode === 'target') showTargetPanel(); },
  bmove: () => {
    const a = BS.actor;
    BS.mode = 'move'; BS.reach = reach(B, a);
    clearHL();
    for (const [k, v] of BS.reach) if (v.d > 0) V.hl.set(k, 'rgba(90,168,255,.45)');
    panel(unitPanel(a) + `<p class="hintp">Tap a blue tile to move (Move ${eff(a, 'mv')}, Jump ${eff(a, 'jp')}).</p><div class="cmds"><button data-a="bcancel">Cancel</button></div>`);
  },
  bvessel: () => {
    const a = BS.actor, os = objsInReach(B, a);
    for (const o of os) V.hl.set(o.x + ',' + o.y, 'rgba(255,214,106,.45)');
    sheet(`<h3>${esc(a.name)}: Vessel</h3><p class="small muted">Take a nearby object into the vessel. It is free and does not use your turn. Use its skill three times to keep it for good. Reach: ${vesselRadius(B).toFixed(1)} tiles.</p>
      <div class="card"><b>Holding:</b> ${a.vessel ? esc(AB[a.vessel].name) + ` <small class="muted">${esc(AB[a.vessel].desc)}${a.u.sk[a.vessel] ? ' · ' + a.u.sk[a.vessel] + '/' + SK_NEED + ' uses' : ''}</small>` : '<span class="muted">Empty</span>'}</div>
      ${os.length ? os.map(o => `<button class="opt" data-a="bgrab" data-v="${o.id}"><div class="optl"><b>${esc(AB[o.skill].name)}</b><small>${PROFS[pfOf({ s: a.s }, AB[o.skill])]} · ${esc(AB[o.skill].desc)} · ${Math.abs(o.x - a.x) + Math.abs(o.y - a.y)} tiles</small></div></button>`).join('') : '<p class="muted">No objects within reach.</p>'}
      <button class="btn" data-a="close">Close</button>`);
  },
  bgrab: async v => { closeSheet(); await playEvents(pickup(B, BS.actor, v)); showMenu(); },
  bundo: () => { const a = BS.actor; a.x = a.start.x; a.y = a.start.y; a.f = a.start.f; a.vx = a.x; a.vy = a.y; a.vh = tileAt(B, a.x, a.y).h; a.moved = false; showMenu(); },
  bcancel: () => showMenu(),
  bact: () => {
    const a = BS.actor;
    const rows = actList(a).map(gp => gp.ids.length ? `<div class="agrp">${esc(gp.name)}</div>` + gp.ids.map(id => {
      const ab = abilityFor(id), why = blocked(B, a, ab);
      const law = B.law && (lawMatch(B.law.ban, a, ab, a.x, a.y) && LAWS[B.law.ban].k !== 'ranged');
      const fav = B.law && lawMatch(B.law.fav, a, ab, a.x, a.y) && LAWS[B.law.fav].k !== 'ranged';
      const cost = ab.cons ? '×' + B.inv[ab.cons] : mpCost(a, ab) ? mpCost(a, ab) + ' MP' : '';
      return `<button class="opt ab" data-a="bpick" data-v="${id}" ${why ? 'disabled' : ''}><div class="optl"><b>${ab.name}</b>${law ? ' <span class="lawwarn">Banned</span>' : ''}${fav ? ' <span class="lawfav">Favored</span>' : ''}<small>${why ? why : esc(ab.desc || '')}</small></div><span class="cost">${cost}</span></button>`;
    }).join('') : '').join('');
    sheet(`<h3>${esc(a.name)}: Act</h3><div class="ablist">${rows}</div><button class="btn" data-a="close">Cancel</button>`);
  },
  bpick: v => {
    closeSheet();
    const a = BS.actor, ab = abilityFor(v);
    BS.ab = v; BS.center = null; BS.mode = 'target';
    clearHL();
    for (const [x, y] of rangeTiles(B, a, ab)) V.hl.set(x + ',' + y, ab.tgt === 'foe' ? 'rgba(255,120,80,.42)' : 'rgba(110,220,140,.42)');
    if (ab.rng === 0) { BS.center = [a.x, a.y]; setArea(); }
    showTargetPanel();
  },
  bgo: () => doAct(),
  bwait: () => {
    BS.mode = 'face'; clearHL();
    const a = BS.actor;
    // Buttons laid out by screen direction (NE, SE, SW, NW).
    const dirs = [0, 1, 2, 3].map(f => { const [dx, dy] = screenDir(f); return { f, pos: (dy < 0 ? 'n' : 's') + (dx < 0 ? 'w' : 'e') }; });
    const lbl = { ne: '↗', se: '↘', sw: '↙', nw: '↖' };
    panel(unitPanel(a) + `<p class="hintp">Choose a facing. Foes behind you hit more often.</p><div class="facepad">${['nw', 'ne', 'sw', 'se'].map(p => { const d = dirs.find(x => x.pos === p); return `<button data-a="bface" data-v="${d.f}" class="${a.f === d.f ? 'on' : ''}" aria-label="Face ${p.toUpperCase()}">${lbl[p]}</button>`; }).join('')}</div><div class="cmds"><button data-a="bcancel">Back</button></div>`);
  },
  bface: v => {
    const a = BS.actor; a.f = +v;
    if (BS.mode === 'face') {
      BS.mode = 'idle'; panel('');
      const r = BS.resolve; BS.resolve = null; r && r();
    }
  },
};
function setArea() {
  V.area = new Set();
  if (!BS.center) return;
  const ab = abilityFor(BS.ab);
  for (const [x, y] of areaTiles(B, ab, BS.center[0], BS.center[1])) V.area.add(x + ',' + y);
}
function showTargetPanel() {
  const a = BS.actor, ab = abilityFor(BS.ab);
  if (!BS.center) { panel(unitPanel(a) + `<p class="hintp"><b>${ab.name}</b>: tap a highlighted tile to target.</p><div class="cmds"><button data-a="bcancel">Cancel</button></div>`); return; }
  const [cx, cy] = BS.center, ts = targetsOf(B, a, ab, cx, cy);
  const rows = ts.map(t => {
    const p = predict(B, a, ab, t);
    let eff = '';
    if (ab.fx === 'atk' || ab.fx === 'mag' || ab.fx === 'drain') eff = `${p.amt} dmg`;
    else if (ab.fx === 'heal') eff = `+${-p.amt} HP`;
    else if (ab.fx === 'mpdmg') eff = `${p.amt} MP dmg`;
    else if (ab.fx === 'raise') eff = 'Revive';
    if (p.stCh !== undefined && ab.st) eff += (eff ? ' · ' : '') + ab.st.map(s => STATUS[s].name).join('/') + ' ' + p.stCh + '%';
    const showHit = ab.fx === 'atk' || ab.fx === 'steal';
    return `<div class="trow t${t.team}"><b>${esc(t.name)}</b><span>${showHit ? p.hit + '% · ' : ''}${eff || ab.name}</span></div>`;
  }).join('');
  const bad = breaksLaw(B, a, ab, cx, cy);
  panel(`<div class="tgt"><div class="tgth"><b>${ab.name}</b>${bad ? `<span class="lawwarn">Breaks today's law: ${a.cards ? 'red card (jail)' : 'yellow card'}</span>` : ''}</div>
    ${rows || '<p class="hintp">No targets there.</p>'}</div>
    <div class="cmds"><button data-a="bgo" class="go" ${ts.length ? '' : 'disabled'}>Confirm</button><button data-a="bcancel">Cancel</button></div>`);
}
async function doAct() {
  const a = BS.actor, [cx, cy] = BS.center, id = BS.ab;
  BS.mode = 'busy'; clearHL(); panel(unitPanel(a));
  const ev = perform(B, a, id, cx, cy);
  await playEvents(ev);
  if (B.over || a.jailed || a.ko) { const r = BS.resolve; BS.resolve = null; r && r(); return; }
  if (a.moved || !canMove(a)) BACT.bwait(); else showMenu();
}
async function moveAnim(u, path) {
  u.walk = true;
  for (let i = 1; i < path.length; i++) {
    const [x0, y0] = path[i - 1], [x1, y1] = path[i];
    const h0 = tileAt(B, x0, y0).h, h1 = tileAt(B, x1, y1).h;
    u.f = faceToward({ x: x0, y: y0, f: u.f }, x1, y1);
    const dur = 150 / (G.fast ? 2 : 1), t0 = performance.now();
    await new Promise(res => {
      const step = () => {
        const p = Math.min(1, (performance.now() - t0) / dur);
        u.vx = x0 + (x1 - x0) * p; u.vy = y0 + (y1 - y0) * p;
        u.vh = h0 + (h1 - h0) * p; u.hop = h0 !== h1 ? Math.sin(p * Math.PI) * 10 : 0;
        if (p < 1) requestAnimationFrame(step); else res();
      };
      step();
    });
  }
  u.walk = false; u.hop = 0;
  u.vx = u.x; u.vy = u.y; u.vh = tileAt(B, u.x, u.y).h;
}
async function doMove(x, y) {
  const a = BS.actor, path = pathTo(BS.reach, x, y), f = a.f;
  BS.mode = 'busy'; clearHL();
  moveUnit(B, a, x, y);
  a.f = f;
  await moveAnim(a, path);
  if (a.acted) BACT.bwait(); else showMenu();
}
async function enemyTurn(a) {
  panel(unitPanel(a));
  await sleep(350);
  const p = aiPlan(B, a);
  if (p.pick) logMsg(a.name + ' takes ' + AB[p.pick].name + ' into the vessel.');
  if (p.x !== a.x || p.y !== a.y) {
    const R = reach(B, a), path = pathTo(R, p.x, p.y);
    for (const [x, y] of path) V.hl.set(x + ',' + y, 'rgba(255,120,80,.3)');
    await sleep(200);
    clearHL();
    moveUnit(B, a, p.x, p.y);
    centerOn(p.x, p.y);
    await moveAnim(a, path);
  }
  if (p.id) {
    const ab = abilityFor(p.id);
    for (const [x, y] of areaTiles(B, ab, p.cx, p.cy)) V.area.add(x + ',' + y);
    centerOn(p.cx, p.cy);
    logMsg(a.name + ': ' + ab.name);
    await sleep(450);
    clearHL();
    const ev = perform(B, a, p.id, p.cx, p.cy);
    await playEvents(ev);
  }
  if (!a.ko && !a.jailed) { const f = nearestFoe(B, a); if (f) a.f = faceToward(a, f.x, f.y); }
  await sleep(200);
}
function buById(id) { return B.units.find(u => u.id === id); }
async function playEvents(ev) {
  for (const e of ev) {
    const u = e.id && buById(e.id);
    switch (e.type) {
      case 'act': {
        const ab = abilityFor(e.ab) || FIGHT;
        if (u) { u.hop = 6; setTimeout(() => { u.hop = 0; }, 120); }
        const col = e.el ? ELEMENTS[e.el] : ab.fx === 'heal' || ab.fx === 'raise' ? '#8af0a0' : ab.fx === 'buff' ? '#ffe08a' : ab.fx === 'debuff' ? '#c8a0ff' : '#ffffff';
        for (const [x, y] of areaTiles(B, ab, e.tx, e.ty)) burst(x, y, col, ab.cat === 'mag' || ab.fx === 'mag' ? 'mag' : 'hit');
        await sleep(260);
        break;
      }
      case 'msg': logMsg(e.text); break;
      case 'dmg': u.flash = performance.now(); floatText(u, String(e.v), '#ffffff'); await sleep(140); break;
      case 'heal': floatText(u, '+' + e.v, '#7ef09a'); await sleep(120); break;
      case 'mp': floatText(u, (e.v > 0 ? '+' : '') + e.v + ' MP', '#8ac8ff'); await sleep(100); break;
      case 'miss': floatText(u, 'Miss', '#c8c8c8'); await sleep(120); break;
      case 'status': floatText(u, STATUS[e.s].name, STATUS[e.s].col); await sleep(140); break;
      case 'ko': floatText(u, 'KO', '#ff6a5a'); await sleep(220); break;
      case 'raise': floatText(u, 'Revived', '#7ef09a'); break;
      case 'jp': floatText(u, '+' + e.v + ' JP', '#ffd36a'); await sleep(100); break;
      case 'pickup': { const o = B.units.find(q => q.id === e.id); floatText(o, AB[e.skill].name, '#ffd36a'); await sleep(200); break; }
      case 'learn': floatText(u, 'Learned ' + AB[e.skill].name + '!', '#ffd36a'); await sleep(400); break;
      case 'prof': floatText(u, PROFS[e.pf] + (e.kind === 'mp' ? ' MP' : '') + ' Lv ' + e.lv, '#ffd36a'); await sleep(200); break;
      case 'lvup': floatText(u, 'Level up!', '#ffd36a'); await sleep(200); break;
      case 'card': toast(e.red ? `Red card: ${u.name} is jailed` : `Yellow card: ${u.name}`); await sleep(600); break;
    }
  }
  drawOrder();
  if (BS.actor && BS.mode !== 'menu' && BS.mode !== 'target' && BS.mode !== 'face' && BS.mode !== 'move') panel(unitPanel(BS.actor));
}

// ----- Canvas input: tap, drag-pan, pinch-zoom -----
function bindCanvas(cv) {
  const pts = new Map();
  let start = null, moved = false, pinch = null;
  cv.addEventListener('pointerdown', e => {
    cv.setPointerCapture(e.pointerId);
    pts.set(e.pointerId, [e.offsetX, e.offsetY]);
    if (pts.size === 1) { start = [e.offsetX, e.offsetY, V.panX, V.panY]; moved = false; }
    if (pts.size === 2) { const [a, b] = [...pts.values()]; pinch = { d: Math.hypot(a[0] - b[0], a[1] - b[1]), s: V.scale }; moved = true; }
  });
  cv.addEventListener('pointermove', e => {
    if (!pts.has(e.pointerId)) return;
    pts.set(e.pointerId, [e.offsetX, e.offsetY]);
    if (pts.size === 2 && pinch) {
      const [a, b] = [...pts.values()], d = Math.hypot(a[0] - b[0], a[1] - b[1]);
      zoomBy(pinch.s * d / pinch.d / V.scale, (a[0] + b[0]) / 2, (a[1] + b[1]) / 2);
      return;
    }
    if (start && pts.size === 1) {
      const dx = e.offsetX - start[0], dy = e.offsetY - start[1];
      if (Math.abs(dx) + Math.abs(dy) > 8) moved = true;
      if (moved) { V.tween = null; V.panX = start[2] + dx; V.panY = start[3] + dy; }
    }
  });
  const up = e => {
    pts.delete(e.pointerId);
    if (pts.size < 2) pinch = null;
    if (pts.size === 0 && start && !moved) tapCanvas(e.offsetX, e.offsetY);
    if (pts.size === 0) start = null;
  };
  cv.addEventListener('pointerup', up);
  cv.addEventListener('pointercancel', e => { pts.delete(e.pointerId); start = null; pinch = null; });
  cv.addEventListener('wheel', e => { e.preventDefault(); zoomBy(e.deltaY < 0 ? 1.1 : .9, e.offsetX, e.offsetY); }, { passive: false });
}
function tapCanvas(px, py) {
  const t = pickTile(px, py);
  if (!t) return;
  const [x, y] = t, k = x + ',' + y;
  V.cursor = t;
  if (BS.mode === 'move') { if (V.hl.has(k)) doMove(x, y); return; }
  if (BS.mode === 'target') {
    if (!V.hl.has(k)) { const u = unitAt(B, x, y); if (u) showInspect(u); return; }
    if (BS.center && BS.center[0] === x && BS.center[1] === y && targetsOf(B, BS.actor, abilityFor(BS.ab), x, y).length) { doAct(); return; }
    BS.center = [x, y]; setArea(); showTargetPanel();
    return;
  }
  if (BS.mode === 'menu') { const u = unitAt(B, x, y); if (u) showInspect(u); }
}

// ---------- Boot ----------
window.addEventListener('DOMContentLoaded', () => { render(); });
