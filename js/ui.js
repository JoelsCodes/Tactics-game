// Hollowmark Tactics: screens and battle controller, laid out like the FFTA menus
// (blue windows, hand cursor, help bar on top, Move/Action/Wait/Status, town -> Pub/Shop).
'use strict';

const S = { scr: 'title', unit: null, hl: null, slot: null, sel: null, kind: null, deploy: [], results: null, rstep: 0,
  shop: 'menu', cat: 'w', pub: 'menu', itab: 'w', back: null };
const $ = sel => document.querySelector(sel);
const esc = s => String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
const sleep = ms => new Promise(r => setTimeout(r, ms / (G && G.fast ? 2 : 1)));
const lawText = id => id ? LAWS[id].name : 'None';
const MOONS = ['Frostwane', 'Thawmoon', 'Seedmoon', 'Rainmoon', 'Sunmoon', 'Highmoon', 'Emberwane', 'Reapmoon', 'Mistmoon', 'Ashmoon', 'Duskmoon', 'Longnight'];
const dateStr = d => MOONS[Math.floor((d - 1) / 30) % 12] + ' ' + ((d - 1) % 30 + 1);
const STATN = { atk: 'W.Atk', def: 'W.Def', mag: 'M.Pow', res: 'M.Res', spd: 'Speed', hp: 'HP', mp: 'MP', ev: 'Evade', mv: 'Move', jp: 'Jump' };
const SLOTN = { w: 'R.Hand', o: 'L.Hand', h: 'Head', b: 'Body', a: 'Accessory' };

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
const pimg = (u, cls) => `<span class="pf ${cls || ''}"><img src="${portrait(u)}" alt=""></span>`;

// ---------- Window helpers ----------
const win = (inner, cls, extra) => `<div class="win ${cls || ''}" ${extra || ''}>${inner}</div>`;
// A menu row. The hand cursor sits on `.sel` rows.
function item(label, a, v, o) {
  o = o || {};
  return `<button class="it${o.sel ? ' sel' : ''}${o.cls ? ' ' + o.cls : ''}" data-a="${a}"${v !== undefined && v !== null ? ` data-v="${esc(v)}"` : ''}${o.dis ? ' disabled' : ''}><span class="l">${label}</span>${o.r !== undefined ? `<span class="r">${o.r}</span>` : ''}</button>`;
}
// Put the cursor on the first enabled row when nothing is highlighted.
function cursorFirst(html) { return html.includes(' sel"') || html.includes('it sel') ? html : html.replace(/class="it((?: [\w-]+)*)"(?![^>]*disabled)/, 'class="it sel$1"'); }
const cmd = (rows, cls) => win(cursorFirst(rows.join('')), 'cmd ' + (cls || ''));
const help = text => win(`<div class="helpt">${text || '&nbsp;'}</div>`, 'help');
// Lists where the first tap shows details in the help bar and the second tap confirms.
function tap2(key, fn) { if (S.hl !== key) { S.hl = key; render(); return; } S.hl = null; fn(); }
function bar(p, cls) { return `<i class="gauge ${cls}"><b style="width:${Math.max(0, Math.min(100, p * 100))}%"></b></i>`; }
function statusWin(u, extra) {
  const s = u.s || calcStats(u), hp = u.hp !== undefined ? u.hp : s.mhp, mp = u.mp !== undefined ? u.mp : s.mmp;
  const job = u.mon ? 'Monster' : JOBS[u.job].name, uu = u.u || u;
  const sts = u.st ? Object.keys(u.st).map(k => `<span class="stt" style="--c:${STATUS[k].col}">${STATUS[k].name}</span>`).join('') : '';
  return win(`${pimg(uu)}<div class="si">
    <div class="nm">${esc(u.name)}<span class="jb">${job}</span></div>
    <div class="row"><span class="k">Lv</span>${u.lv}${u.jp ? `<span class="k sp">JP</span>${u.jp}` : ''}${u.cards ? '<span class="ycard">Yellow</span>' : ''}</div>
    <div class="row"><span class="k">HP</span><span class="num">${hp}<small>/${s.mhp}</small></span>${bar(hp / s.mhp, 'hp')}</div>
    ${s.mmp ? `<div class="row"><span class="k">MP</span><span class="num">${mp}<small>/${s.mmp}</small></span>${bar(mp / s.mmp, 'mp')}</div>` : ''}
    ${sts ? `<div class="sts">${sts}</div>` : ''}${extra || ''}</div>`, 'stat t' + (u.team !== undefined ? u.team : 0));
}

// ---------- Shell ----------
function render() {
  const app = $('#app');
  app.className = 'scr-' + S.scr;
  if (S.scr === 'battle') return;
  app.innerHTML = `<div class="bd">${backdrop()}</div><div class="screen">${screen()}</div><div id="modal" hidden></div><div id="toast" hidden></div>`;
  if (S.scr === 'world') drawWorld();
}
function backdrop() {
  if (S.scr === 'world') return '<svg id="world" viewBox="0 0 100 140" preserveAspectRatio="xMidYMid meet" role="img" aria-label="World map"></svg>';
  if (S.scr === 'town' || S.scr === 'pub' || S.scr === 'shop') return townArt(S.scr);
  if (S.scr === 'title') return '<div class="titlebg"></div>';
  return '<div class="menubg"></div>';
}
function townArt(kind) {
  const warm = kind !== 'town';
  let roofs = '';
  const xs = [0, 14, 26, 40, 52, 66, 78, 90];
  xs.forEach((x, i) => {
    const h = 30 + (i * 37 % 17), w = 12 + (i % 3) * 2;
    roofs += `<rect x="${x}" y="${100 - h}" width="${w}" height="${h}" fill="#1a1f3a"/><path d="M${x - 2} ${100 - h}l${w / 2 + 2} -9 ${w / 2 + 2} 9z" fill="#262c52"/>`;
    for (let j = 0; j < 3; j++) if ((i + j) % 2) roofs += `<rect x="${x + 3 + j * 3}" y="${100 - h + 6 + j * 7}" width="2" height="3" fill="#ffd27a" opacity=".8"/>`;
  });
  return `<svg viewBox="0 0 100 100" preserveAspectRatio="xMidYMax slice" class="town"><defs><linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${warm ? '#3a1e2a' : '#22306a'}"/><stop offset="1" stop-color="${warm ? '#a0583a' : '#d08a5a'}"/></linearGradient></defs>
    <rect width="100" height="100" fill="url(#sky)"/><circle cx="74" cy="34" r="7" fill="#ffe2a0" opacity=".85"/>${roofs}<rect y="96" width="100" height="4" fill="#12152a"/></svg>`;
}
function screen() {
  switch (S.scr) {
    case 'title': return titleScr();
    case 'world': return worldScr();
    case 'menu': return menuScr();
    case 'units': return unitsScr();
    case 'unit': return unitScr();
    case 'equip': return equipScr();
    case 'abil': return abilScr();
    case 'job': return jobScr();
    case 'items': return itemsScr();
    case 'missions': return missionsScr();
    case 'laws': return lawsScr();
    case 'clan': return clanScr();
    case 'options': return optionsScr();
    case 'town': return townScr();
    case 'pub': return pubScr();
    case 'shop': return shopScr();
    case 'deploy': return deployScr();
    case 'results': return resultsScr();
  }
  return '';
}
function go(scr) { S.scr = scr; S.hl = null; render(); }
function toast(msg) {
  const t = $('#toast'); if (!t) return;
  t.innerHTML = win(esc(msg), 'toastw'); t.hidden = false;
  clearTimeout(toast.h); toast.h = setTimeout(() => { t.hidden = true; }, 1600);
}
function modal(html, cls) { const m = $('#modal'); m.innerHTML = `<div class="scrim" data-a="close"></div>${win(html, 'mwin ' + (cls || ''))}`; m.hidden = false; }
function closeModal() { const m = $('#modal'); if (m) { m.hidden = true; m.innerHTML = ''; } }
const backBtn = to => `<button class="win backbtn" data-a="go" data-v="${to}" aria-label="Back">◀</button>`;
const gilWin = () => win(`<span class="k">Gil</span> <span class="num">${G.gil.toLocaleString()}</span>`, 'gilw');

// ---------- Title ----------
function titleScr() {
  return `<div class="logo"><svg viewBox="0 0 64 80" width="56" height="70" aria-hidden="true"><path d="M8 4h48v40c0 18-14 28-24 32C22 72 8 62 8 44z" fill="#1b2c78" stroke="#ffe58a" stroke-width="3"/><path d="M32 16v44M20 30h24" stroke="#fff" stroke-width="3"/></svg>
    <h1>Hollowmark</h1><div class="sub">T A C T I C S</div></div>
  ${cmd([hasSave() ? item('Continue', 'continue') : '', item('New Game', 'newgame')].filter(Boolean), 'titlecmd')}
  <div class="copy">An original tactics tale</div>`;
}

// ---------- World map ----------
function worldScr() {
  const k = S.sel || G.loc, L = LOCS[k], law = todaysLaw(), M = nextMission();
  const rows = [];
  if (k !== G.loc) rows.push(locOpen(k) ? item('Travel', 'travel', k, { r: '1 day' }) : item('Sealed', 'noop', null, { dis: true }));
  else if (L.town) rows.push(item('Enter', 'go', 'town'));
  else {
    if (M && G.accepted === M.id && M.loc === k) rows.push(item('Engage', 'deploy', 'mission'));
    if (G.cleared[k]) rows.push(item('Patrol', 'deploy', 'skirmish'));
    if (!rows.length) rows.push(item('No mission here', 'noop', null, { dis: true }));
  }
  const hint = M ? (G.accepted === M.id ? `Mission: ${esc(M.name)} at ${LOCS[M.loc].name}.` : `New mission at the Harrowgate pub.`) : `Chapter 1 complete. Patrol to train your clan.`;
  return `<div class="topbar">${win(`<div class="date">${dateStr(G.day)}</div><div><span class="k">Gil</span> <span class="num">${G.gil.toLocaleString()}</span></div>`, 'datew')}<button class="win menubtn" data-a="go" data-v="menu">Menu</button></div>
  <div class="grow"></div>
  ${help(hint)}
  <div class="locrow">${win(`<div class="wt">${L.name}</div><div class="dim small">${L.town ? 'Town' : 'Battlefield' + (G.cleared[k] ? ' · Cleared' : '')}${k === G.loc ? ' · You are here' : ''}</div>
    <div class="lawl"><span class="k">Forbidden</span>${lawText(law.ban)}</div><div class="lawl"><span class="k">Recommended</span>${lawText(law.fav)}</div>`, 'locw')}${cmd(rows, 'loccmd')}</div>`;
}
function drawWorld() {
  const svg = $('#world'); if (!svg) return;
  let s = `<defs><pattern id="hatch" width="3" height="3" patternUnits="userSpaceOnUse"><path d="M0 3L3 0" stroke="rgba(255,255,255,.06)" stroke-width=".5"/></pattern></defs>
  <rect x="-60" y="-20" width="220" height="180" fill="#2a5a9a"/>
  <path d="M10 130 C2 110 8 92 14 80 C6 64 10 40 22 26 C34 10 58 6 76 12 C92 18 96 40 90 58 C98 74 94 98 84 112 C74 130 40 138 10 130Z" fill="#6f9a4c"/>
  <path d="M10 130 C2 110 8 92 14 80 C6 64 10 40 22 26 C34 10 58 6 76 12 C92 18 96 40 90 58 C98 74 94 98 84 112 C74 130 40 138 10 130Z" fill="url(#hatch)" stroke="#e8dcb0" stroke-width=".9"/>
  <path d="M18 48 C26 40 34 44 40 54 C44 64 36 74 26 72 C18 70 14 58 18 48Z" fill="#a08058" opacity=".75"/>
  <path d="M58 12 C60 30 52 44 56 58 C60 72 70 82 66 100 C64 110 70 120 74 128" fill="none" stroke="#4f8fd0" stroke-width="1.8"/>
  <g fill="#8a7454" stroke="#5a4a34" stroke-width=".3"><path d="M20 58l5-8 5 8z"/><path d="M27 56l4-6 4 6z"/><path d="M34 66l4-7 4 7z"/></g>
  <g fill="#3d6a30" stroke="#2a4a22" stroke-width=".3">${[[64, 26], [70, 22], [76, 30], [80, 24], [66, 36], [74, 38], [82, 34]].map(([x, y]) => `<circle cx="${x}" cy="${y}" r="3"/>`).join('')}</g>`;
  for (const [a, b] of ROUTES) {
    const A = LOCS[a], Bb = LOCS[b], open = locOpen(a) && locOpen(b);
    s += `<line x1="${A.x}" y1="${A.y}" x2="${Bb.x}" y2="${Bb.y}" stroke="#f0e2b0" stroke-width="1.1" stroke-dasharray="${open ? '2 1.4' : '.6 2'}" opacity="${open ? 1 : .45}"/>`;
  }
  const M = nextMission();
  for (const k in LOCS) {
    const L = LOCS[k], open = locOpen(k), sel = (S.sel || G.loc) === k, mis = M && G.accepted === M.id && M.loc === k;
    s += `<g class="node${open ? '' : ' locked'}" data-a="selloc" data-v="${k}" tabindex="0" role="button" aria-label="${L.name}">
      <circle cx="${L.x}" cy="${L.y}" r="9" fill="transparent"/>
      ${L.town ? `<g transform="translate(${L.x - 5} ${L.y - 5})"><rect x="1" y="4" width="8" height="6" fill="#e8dcc0" stroke="#2a2218" stroke-width=".5"/><path d="M0 4.5L5 0l5 4.5z" fill="#c0503a" stroke="#2a2218" stroke-width=".5"/></g>`
        : `<rect x="${L.x - 3.4}" y="${L.y - 3.4}" width="6.8" height="6.8" rx="1" fill="${G.cleared[k] ? '#7ed39a' : open ? '#f2e6c0' : '#8a8476'}" stroke="#2a2218" stroke-width=".6"/>`}
      ${mis ? `<path d="M${L.x + 3} ${L.y - 4}v-7l5 2-5 2" fill="#e0503a" stroke="#2a2218" stroke-width=".3"/>` : ''}
      <text x="${L.x}" y="${L.y + 9}" text-anchor="middle" class="nlabel">${L.name}</text>
    </g>`;
    if (sel) s += `<g class="mapcur" transform="translate(${L.x - 10} ${L.y})"><path d="M0 -1.6h4.5v-1.5h3.6v4.8H4.5v-0.2H0z" fill="#fff" stroke="#0b1238" stroke-width=".5"/></g>`;
  }
  const P = LOCS[G.loc];
  s += `<g class="me"><circle cx="${P.x}" cy="${P.y - 9}" r="2.6" fill="#ffe58a" stroke="#0b1238" stroke-width=".5"/><path d="M${P.x - 1.6} ${P.y - 7}l1.6 3 1.6-3z" fill="#ffe58a" stroke="#0b1238" stroke-width=".4"/></g>`;
  svg.innerHTML = s;
}

// ---------- Main menu ----------
function menuScr() {
  const H = { units: 'View and change your units.', items: 'View your items.', missions: 'Check your missions.', laws: 'Check today\'s laws.', clan: 'View clan information.', options: 'Change game settings.', save: 'Save your progress.' };
  const rows = [['units', 'Units'], ['items', 'Items'], ['missions', 'Missions'], ['laws', 'Laws'], ['clan', 'Clan'], ['options', 'Options'], ['save', 'Save']];
  const cur = S.hl || 'units';
  return `${help(H[cur] || '')}
  <div class="menulay">${cmd(rows.map(([k, n]) => item(n, 'mm', k, { sel: cur === k })).concat([item('Close', 'go', 'world')]), 'mainmenu')}
  <div class="col">${win(`<div class="wt">${esc(G.clan)}</div><div class="kvs"><span class="k">Members</span><span>${G.units.length}</span><span class="k">Gil</span><span class="num">${G.gil.toLocaleString()}</span><span class="k">Date</span><span>${dateStr(G.day)}</span></div>`, 'clanw')}
  ${win(`<div class="minis">${G.units.slice(0, 12).map(u => `<img src="${portrait(u)}" alt="${esc(u.name)}" title="${esc(u.name)}">`).join('')}</div>`, 'minisw')}</div></div>`;
}

// ---------- Units ----------
function unitTags(u) { return (u.errand ? '<span class="tag warn">Errand</span>' : '') + (u.jail ? `<span class="tag bad">Prison ${u.jail}</span>` : ''); }
function unitsScr() {
  return `${help('Select a unit.')}${backBtn('menu')}
  <div class="ugrid">${G.units.map(u => `<button class="win ucell" data-a="unit" data-v="${u.id}">${pimg(u)}<span class="nm">${esc(u.name)}</span><span class="jb">${JOBS[u.job].name}</span><span class="lvl"><span class="k">Lv</span>${u.lv}</span>${unitTags(u)}</button>`).join('')}</div>`;
}
function statsWin(s, prev) {
  const L = [['atk', 'W.Atk'], ['def', 'W.Def'], ['mag', 'M.Pow'], ['res', 'M.Res'], ['spd', 'Speed'], ['ev', 'Evade'], ['mv', 'Move'], ['jp', 'Jump']];
  return win(`<div class="sgrid">${L.map(([k, n]) => {
    let v = `<b>${s[k]}</b>`;
    if (prev && prev[k] !== s[k]) v = `<b class="${prev[k] < s[k] ? 'up' : 'dn'}">${prev[k] < s[k] ? '▲' : '▼'}${s[k]}</b>`;
    return `<span class="k">${n}</span>${v}`;
  }).join('')}</div>`, 'statsw');
}
function unitHead(u, nav) {
  const s = calcStats(u), i = G.units.indexOf(u);
  return win(`${pimg(u, 'big')}<div class="si">
    <div class="nm">${esc(u.name)}${u.leader ? '<span class="tag">Leader</span>' : ''}${unitTags(u)}</div>
    <div class="dim">${RACES[u.race].name} · ${JOBS[u.job].name}</div>
    <div class="row"><span class="k">Lv</span>${u.lv}<span class="k sp">Exp</span>${u.exp}</div>
    <div class="row"><span class="k">HP</span><span class="num">${s.mhp}</span><span class="k sp">MP</span><span class="num">${s.mmp}</span></div></div>
    ${nav ? `<div class="unav"><button data-a="cycle" data-v="-1" aria-label="Previous unit" ${i ? '' : 'disabled'}>◀</button><button data-a="cycle" data-v="1" aria-label="Next unit" ${i < G.units.length - 1 ? '' : 'disabled'}>▶</button></div>` : ''}`, 'uhead');
}
function unitScr() {
  const u = unitById(S.unit); if (!u) return unitsScr();
  const H = { equip: 'Change equipment.', abil: 'Set abilities and check what is being learned.', job: 'Change job.', dismiss: 'Dismiss this unit from the clan.' };
  const cur = S.hl || 'equip';
  return `${help(H[cur])}${backBtn('units')}${unitHead(u, true)}
  <div class="split">${cmd([item('Equip', 'um', 'equip', { sel: cur === 'equip' }), item('Abilities', 'um', 'abil', { sel: cur === 'abil' }), item('Job', 'um', 'job', { sel: cur === 'job' }), u.leader ? '' : item('Dismiss', 'um', 'dismiss', { sel: cur === 'dismiss' })].filter(Boolean), 'ucmd')}
  ${statsWin(calcStats(u))}</div>
  ${win(`<div class="kv"><span class="k">A-Ability</span>${JOBS[u.job].cmd}</div><div class="kv"><span class="k">A-Ability 2</span>${u.sub ? JOBS[u.sub].cmd : '—'}</div><div class="kv"><span class="k">R-Ability</span>${u.r ? AB[u.r].name : '—'}</div><div class="kv"><span class="k">S-Ability</span>${u.s ? AB[u.s].name : '—'}</div>`, 'abset')}`;
}
function itemsTeaching(id) { return Object.keys(ITEMS).filter(k => ITEMS[k].teach.includes(id)); }
function statStr(st) { return Object.keys(st).map(k => STATN[k] + '+' + st[k]).join('  '); }
function learnStr(it, u) {
  return it.teach.length ? 'Learn: ' + it.teach.map(id => { const a = AB[id], m = u && u.ms[id], no = u && !canLearn(u, id); return `<span class="lrn${m ? ' m' : ''}${no ? ' no' : ''}">${a.name}<small>(${JOBS[a.job].name})</small>${m ? '★' : ''}</span>`; }).join(' ') : '';
}
function equipScr() {
  const u = unitById(S.unit), s = calcStats(u);
  let list = '', prev = null, helpTxt = 'Select a slot.';
  if (S.slot) {
    const cands = Object.keys(G.inv).map(k => ITEMS[k]).filter(it => it.slot === S.slot && canEquip(u, it));
    const cur = u.eq[S.slot] && ITEMS[u.eq[S.slot]];
    if (S.hl && S.hl !== '-') {
      const it = ITEMS[S.hl], tmp = Object.assign({}, u, { eq: Object.assign({}, u.eq, { [S.slot]: S.hl }) });
      prev = s; helpTxt = `${it.name}: ${statStr(it.stats)}${it.el ? '  ' + it.el : ''}<br>${learnStr(it, u)}<br><span class="dim">Tap again to equip.</span>`;
      list = statsWin(calcStats(tmp), prev);
    } else if (S.hl === '-') { helpTxt = 'Remove the item. Tap again to confirm.'; const tmp = Object.assign({}, u, { eq: Object.assign({}, u.eq, { [S.slot]: null }) }); list = statsWin(calcStats(tmp), s); }
    else helpTxt = cur ? `${cur.name}: ${statStr(cur.stats)}<br>${learnStr(cur, u)}` : 'Select an item.';
    const rows = (cur ? [item('(Remove)', 'eqpick', '-', { sel: S.hl === '-' })] : []).concat(cands.map(it => item(it.name, 'eqpick', it.id, { sel: S.hl === it.id, r: '×' + G.inv[it.id] })));
    list = win(rows.length ? rows.join('') : '<div class="dim pad">Nothing to equip here.</div>', 'cmd eqlist') + (list || statsWin(s));
  }
  const slots = ['w', 'o', 'h', 'b', 'a'].map(k => {
    const dis = k === 'o' && !(JOBS[u.job].sh || u.s === 'shieldbearer'), id = u.eq[k];
    return item(`<span class="k slotk">${SLOTN[k]}</span>${id ? ITEMS[id].name : dis ? '<span class="dim">Can\'t equip</span>' : '—'}`, 'eqslot', k, { sel: S.slot === k, dis });
  });
  return `${help(helpTxt)}<button class="win backbtn" data-a="${S.slot ? 'eqback' : 'go'}" data-v="unit" aria-label="Back">◀</button>${unitHead(u)}${win(slots.join(''), 'cmd slots')}${S.slot ? list : statsWin(s)}`;
}
function abilScr() {
  const u = unitById(S.unit), t = taught(u);
  let helpTxt = 'Abilities from equipped gear can be used in this job. Earn AP to master them.';
  const sel = S.hl && AB[S.hl];
  if (sel) helpTxt = `${sel.name}: ${esc(sel.desc)}${sel.mp ? ' (' + sel.mp + ' MP)' : ''}<br><span class="dim">Taught by: ${itemsTeaching(sel.id).map(i => ITEMS[i].name).join(', ')}</span>`;
  const row = id => {
    const a = AB[id], m = u.ms[id], ap = u.ap[id] || 0, src = t[id] && canLearn(u, id);
    const r = m ? '<span class="mast">Mastered</span>' : src ? `<span class="apn">${ap}/${a.ap}</span>` : ap ? `<span class="dim">${ap}/${a.ap}</span>` : '<span class="dim">—</span>';
    return item(`${a.type !== 'A' ? `<span class="k">${a.type}</span> ` : ''}${a.name}`, 'abpick', id, { sel: S.hl === id, r, cls: m ? 'm' : src ? '' : 'off' });
  };
  const jobAb = Object.keys(AB).filter(id => AB[id].job === u.job);
  const other = Object.keys(t).filter(id => AB[id].job !== u.job && canLearn(u, id) && !u.ms[id]);
  return `${help(helpTxt)}${backBtn('unit')}
  ${win(`<div class="wt sm">Set Abilities</div>${item('<span class="k slotk">A-Ability</span>' + JOBS[u.job].cmd, 'noop', null, { dis: true, cls: 'fixed' })}${item('<span class="k slotk">A-Ability 2</span>' + (u.sub ? JOBS[u.sub].cmd : '—'), 'picksub')}${item('<span class="k slotk">R-Ability</span>' + (u.r ? AB[u.r].name : '—'), 'pickrs', 'R')}${item('<span class="k slotk">S-Ability</span>' + (u.s ? AB[u.s].name : '—'), 'pickrs', 'S')}`, 'cmd slots')}
  ${win(`<div class="wt sm">${JOBS[u.job].cmd} <span class="dim">(${JOBS[u.job].name})</span></div>${jobAb.map(row).join('')}${other.length ? `<div class="wt sm">Also learning</div>${other.map(row).join('')}` : ''}`, 'cmd ablist')}`;
}
function jobScr() {
  const u = unitById(S.unit), jl = jobsFor(u.race);
  let helpTxt = `${JOBS[u.job].name}: ${esc(JOBS[u.job].desc)}`;
  if (S.hl && JOBS[S.hl]) {
    const J = JOBS[S.hl], open = jobOpen(u, S.hl), req = Object.keys(J.req).map(k => `${JOBS[k].name} ×${J.req[k]}`).join(', ');
    helpTxt = `${J.name}: ${esc(J.desc)}<br><span class="dim">Move ${J.mv} · Jump ${J.jp} · ${J.w.map(w => WTYPES[w].name).join('/')}</span><br>${open ? (S.hl === u.job ? 'Current job.' : 'Tap again to change job.') : `<span class="bad">Requires: ${req} abilities mastered</span>`}`;
  }
  return `${help(helpTxt)}${backBtn('unit')}${unitHead(u)}
  ${win(`<div class="jgrid">${jl.map(j => { const open = jobOpen(u, j); return item(open ? JOBS[j].name : '<span class="dim">' + JOBS[j].name + '</span>', 'jobpick', j, { sel: S.hl ? S.hl === j : u.job === j, cls: (u.job === j ? 'cur' : '') + (open ? '' : ' lock'), r: open ? `<small>${masteredCount(u, j)}/${jobAbilities(j).length}</small>` : '🔒' }); }).join('')}</div>`, 'cmd jobs')}`;
}

// ---------- Items, missions, laws, clan, options ----------
function itemsScr() {
  const tabs = [['w', 'Weapons'], ['a', 'Armor'], ['c', 'Items'], ['l', 'Loot']];
  let rows = [];
  if (S.itab === 'w') rows = Object.keys(G.inv).filter(k => ITEMS[k].slot === 'w').map(k => item(ITEMS[k].name, 'ihl', k, { r: '×' + G.inv[k], sel: S.hl === k }));
  if (S.itab === 'a') rows = Object.keys(G.inv).filter(k => ITEMS[k].slot !== 'w').map(k => item(ITEMS[k].name, 'ihl', k, { r: '×' + G.inv[k], sel: S.hl === k }));
  if (S.itab === 'c') rows = Object.keys(G.cons).filter(k => G.cons[k]).map(k => item(CONS[k].name, 'ihl', 'c:' + k, { r: '×' + G.cons[k], sel: S.hl === 'c:' + k }));
  if (S.itab === 'l') rows = Object.keys(G.loot).filter(k => G.loot[k]).map(k => item(LOOT[k].name, 'ihl', 'l:' + k, { r: '×' + G.loot[k], sel: S.hl === 'l:' + k }));
  let h = 'Items in storage. Equipped gear is not listed.';
  if (S.hl) { if (S.hl.startsWith('c:')) h = CONS[S.hl.slice(2)].desc; else if (S.hl.startsWith('l:')) h = 'Loot. Combine at the Bazaar.'; else { const it = ITEMS[S.hl]; h = `${it.name}: ${statStr(it.stats)}<br>${learnStr(it)}`; } }
  return `${help(h)}${backBtn('menu')}<div class="tabsw">${tabs.map(([k, n]) => `<button class="win tab${S.itab === k ? ' on' : ''}" data-a="itab" data-v="${k}">${n}</button>`).join('')}</div>
  ${win(rows.join('') || '<div class="dim pad">Nothing here.</div>', 'cmd listw')}`;
}
function missionsScr() {
  const M = nextMission();
  return `${help('Missions accepted at the pub.')}${backBtn('menu')}
  ${M ? win(`<div class="wt">${esc(M.name)}</div><p>${esc(M.brief)}</p><div class="kv"><span class="k">Location</span>${LOCS[M.loc].name}</div><div class="kv"><span class="k">Status</span>${G.accepted === M.id ? 'Accepted' : 'Not accepted (visit the pub)'}</div><div class="kv"><span class="k">Reward</span>${M.reward.gil} gil · ${M.reward.ap} AP</div>`, 'textw')
    : win('<div class="wt">No story missions</div><p>Chapter 1 is complete. Patrol cleared areas and run errands.</p>', 'textw')}
  ${win(`<div class="wt sm">Cleared</div>${MISSIONS.slice(0, G.stage).map(m => `<div class="kv"><span class="mast">★</span> ${esc(m.name)}</div>`).join('') || '<div class="dim">None yet.</div>'}`, 'textw')}`;
}
function lawsScr() {
  const law = todaysLaw();
  return `${help('Laws are set by the Judges and change every day.')}${backBtn('menu')}
  ${win(`<div class="wt">${dateStr(G.day)}</div><div class="kv"><span class="k">Forbidden</span>${lawText(law.ban)}</div><div class="kv"><span class="k">Recommended</span>${lawText(law.fav)}</div>`, 'textw')}
  ${win(`<p>Breaking a law earns a <b class="ylw">yellow card</b>. A second offense earns a <b class="bad">red card</b> and the unit is sent to prison for 2 battles.</p><p>Knocking out a foe or using a recommended action earns <b>JP</b>. Units with 3 JP can use a <b>Combo</b>.</p><p>Story missions have their own laws.</p>`, 'textw')}`;
}
function clanScr() {
  return `${help('Clan information.')}${backBtn('menu')}
  ${win(`<div class="wt">${esc(G.clan)}</div><div class="kvs"><span class="k">Members</span><span>${G.units.length}/${CLAN_MAX}</span><span class="k">Gil</span><span class="num">${G.gil.toLocaleString()}</span><span class="k">Battles</span><span>${G.battles}</span><span class="k">Missions</span><span>${G.stage}/${MISSIONS.length}</span><span class="k">Date</span><span>${dateStr(G.day)}</span><span class="k">Recipes</span><span>${G.bazaar.length}/${RECIPES.length}</span></div>`, 'textw')}`;
}
function optionsScr() {
  return `${help('Change settings.')}${backBtn('menu')}
  ${cmd([item('Battle speed', 'fast', null, { r: G.fast ? 'Fast' : 'Normal' }), item('How to play', 'guide'), item('Return to title', 'totitle')])}`;
}

// ---------- Town / Pub / Shop ----------
function townScr() {
  const H = { pub: 'Take on missions and errands.', shop: 'Buy and sell items.', exit: 'Return to the world map.' };
  const cur = S.hl || 'pub';
  return `${help(H[cur])}<div class="topbar">${win(`<div class="wt">Harrowgate</div><div class="dim small">${dateStr(G.day)}</div>`, 'townw')}${gilWin()}</div><div class="grow"></div>
  ${cmd([item('Pub', 'town', 'pub', { sel: cur === 'pub' }), item('Shop', 'town', 'shop', { sel: cur === 'shop' }), item('Exit', 'town', 'exit', { sel: cur === 'exit' })], 'towncmd')}`;
}
function pubScr() {
  const M = nextMission();
  if (S.pub === 'menu') {
    const H = { missions: 'Take on a mission.', errands: 'Send a unit away on an errand.', prison: 'Pay bail for units in prison.', info: 'Hear what the regulars have to say.', exit: 'Leave the pub.' };
    const cur = S.hl || 'missions';
    return `${help(H[cur])}<div class="topbar">${win('<div class="wt">The Lantern Pub</div><div class="dim small">“What\'ll it be?”</div>', 'townw')}${gilWin()}</div><div class="grow"></div>
    ${cmd([['missions', 'Missions'], ['errands', 'Errands'], ['prison', 'Prison'], ['info', 'Info'], ['exit', 'Exit']].map(([k, n]) => item(n, 'pubm', k, { sel: cur === k })), 'towncmd')}`;
  }
  if (S.pub === 'missions') {
    let h = 'Select a mission.', rows = [];
    if (M) {
      rows.push(item(esc(M.name), 'pubmis', M.id, { sel: S.hl === M.id, r: G.accepted === M.id ? 'Accepted' : 'Story' }));
      if (S.hl === M.id) h = `${esc(M.brief)}<br><span class="dim">${LOCS[M.loc].name} · Forbidden: ${lawText(M.law.ban)} · Reward ${M.reward.gil} gil</span>${G.accepted === M.id ? '' : '<br>Tap again to accept.'}`;
    }
    return `${help(h)}<button class="win backbtn" data-a="pubm" data-v="menu" aria-label="Back">◀</button>${gilWin()}
    ${win(rows.join('') || '<div class="dim pad">No missions posted. Chapter 1 is complete.</div>', 'cmd listw')}`;
  }
  if (S.pub === 'errands') {
    let h = 'Select an errand.';
    const e = S.hl && ERRANDS.find(x => x.id === S.hl);
    if (e) h = `${e.name}: ${e.job ? (RACES[e.job] ? RACES[e.job].name : JOBS[e.job].name) + ', ' : ''}Lv ${e.minLv}+. Away ${e.len} battles. ${e.gil} gil${e.loot ? ' + ' + LOOT[e.loot].name : ''}.<br>Tap again to pick a unit.`;
    const busy = G.errands.map(x => { const ee = ERRANDS.find(y => y.id === x.eid), u = unitById(x.unit); return item(ee.name, 'noop', null, { dis: true, r: `${u ? esc(u.name) : '?'} · ${x.left}` }); });
    return `${help(h)}<button class="win backbtn" data-a="pubm" data-v="menu" aria-label="Back">◀</button>${gilWin()}
    ${win(G.board.map(id => { const ee = ERRANDS.find(y => y.id === id); return item(ee.name, 'errand', id, { sel: S.hl === id, r: ee.gil + 'g' }); }).join('') || '<div class="dim pad">No errands posted.</div>', 'cmd listw')}
    ${busy.length ? win('<div class="wt sm">Out on errands</div>' + busy.join(''), 'cmd listw') : ''}`;
  }
  if (S.pub === 'prison') {
    const jailed = G.units.filter(u => u.jail);
    return `${help(jailed.length ? 'Tap a unit to pay bail.' : 'Nobody from your clan is in prison.')}<button class="win backbtn" data-a="pubm" data-v="menu" aria-label="Back">◀</button>${gilWin()}
    ${win(jailed.map(u => item(esc(u.name), 'bail', u.id, { r: bailCost(u) + 'g', dis: G.gil < bailCost(u) })).join('') || '<div class="dim pad">Empty.</div>', 'cmd listw')}`;
  }
  const tips = ['They say every blade teaches something, if you carry it long enough.', 'Saurians make poor mages, but nobody hits harder.', 'A Judge never forgets a yellow card. Not until the battle ends, anyway.', 'Hit them from behind. Even the Hag can\'t see back there.', 'Strange bits off monsters? The shop\'s bazaar can make something of them.', 'Rogues in the quarry clan have quick hands. Watch your gear.'];
  return `${help('The regulars share what they know.')}<button class="win backbtn" data-a="pubm" data-v="menu" aria-label="Back">◀</button>
  ${win(tips.map(t => `<p>“${esc(t)}”</p>`).join(''), 'textw')}`;
}
function cmpMark(u, it) {
  if (it.slot === undefined) return '';
  if (!canEquip(u, it)) return '<span class="no">✕</span>';
  const cur = u.eq[it.slot] && ITEMS[u.eq[it.slot]];
  if (cur && cur.id === it.id) return '<span class="eq">E</span>';
  const key = it.slot === 'w' ? (it.t === 'rod' || it.t === 'staff' || it.t === 'instrument' ? 'mag' : 'atk') : it.slot === 'a' ? null : 'def';
  if (!key) return '<span class="eq">–</span>';
  const a = it.stats[key] || 0, b = cur ? cur.stats[key] || 0 : 0;
  return a > b ? '<span class="up">▲</span>' : a < b ? '<span class="dn">▼</span>' : '<span class="eq">=</span>';
}
function shopScr() {
  const top = `<div class="topbar">${win('<div class="wt">Harrowgate Shop</div><div class="dim small">“Steel for the road, coin for the keeper.”</div>', 'townw')}${gilWin()}</div>`;
  if (S.shop === 'menu') {
    const H = { buy: 'Buy weapons, armor and items.', sell: 'Sell items you don\'t need.', bazaar: 'Combine loot into new items.', exit: 'Leave the shop.' };
    const cur = S.hl || 'buy';
    return `${help(H[cur])}${top}<div class="grow"></div>${cmd([['buy', 'Buy'], ['sell', 'Sell'], ['bazaar', 'Bazaar'], ['exit', 'Exit']].map(([k, n]) => item(n, 'shopm', k, { sel: cur === k })), 'towncmd')}`;
  }
  const back = '<button class="win backbtn" data-a="shopm" data-v="menu" aria-label="Back">◀</button>';
  if (S.shop === 'buy') {
    const cats = [['w', 'Weapons'], ['a', 'Armor'], ['x', 'Acc.'], ['c', 'Items']];
    let rows, h = 'Select an item.', sel = null;
    if (S.cat === 'c') rows = shopCons().map(k => item(CONS[k].name, 'buyhl', 'c:' + k, { sel: S.hl === 'c:' + k, r: CONS[k].price }));
    else {
      const its = shopItems().filter(it => S.cat === 'w' ? it.slot === 'w' : S.cat === 'a' ? 'ohb'.includes(it.slot) : it.slot === 'a');
      rows = its.map(it => item(it.name, 'buyhl', it.id, { sel: S.hl === it.id, r: it.price }));
    }
    if (S.hl) {
      if (S.hl.startsWith('c:')) { const c = CONS[S.hl.slice(2)]; h = `${c.desc} <span class="dim">Have ${G.cons[S.hl.slice(2)] || 0}.</span>`; }
      else { sel = ITEMS[S.hl]; h = `${sel.slot === 'w' ? WTYPES[sel.t].name : sel.t === 'acc' ? 'Accessory' : sel.t[0].toUpperCase() + sel.t.slice(1)} · ${statStr(sel.stats)} <span class="dim">Have ${G.inv[sel.id] || 0}</span><br>${learnStr(sel)}`; }
      h += '<br><span class="dim">Tap again to buy.</span>';
    }
    const strip = sel ? win(`<div class="strip">${G.units.map(u => `<span class="sc"><img src="${portrait(u)}" alt="${esc(u.name)}">${cmpMark(u, sel)}</span>`).join('')}</div>`, 'stripw') : '';
    return `${help(h)}${back}${gilWin()}<div class="tabsw">${cats.map(([k, n]) => `<button class="win tab${S.cat === k ? ' on' : ''}" data-a="cat" data-v="${k}">${n}</button>`).join('')}</div>
    ${win(rows.join(''), 'cmd listw shopl')}${strip}`;
  }
  if (S.shop === 'sell') {
    const rows = Object.keys(G.inv).map(k => item(ITEMS[k].name, 'sellhl', 'item:' + k, { sel: S.hl === 'item:' + k, r: `×${G.inv[k]} <small>${sellPrice(k, 'item')}</small>` }))
      .concat(Object.keys(G.cons).filter(k => G.cons[k]).map(k => item(CONS[k].name, 'sellhl', 'cons:' + k, { sel: S.hl === 'cons:' + k, r: `×${G.cons[k]} <small>${sellPrice(k, 'cons')}</small>` })))
      .concat(Object.keys(G.loot).filter(k => G.loot[k]).map(k => item(LOOT[k].name, 'sellhl', 'loot:' + k, { sel: S.hl === 'loot:' + k, r: `×${G.loot[k]} <small>${sellPrice(k, 'loot')}</small>` })));
    return `${help(S.hl ? 'Tap again to sell.' : 'Select an item to sell. Equipped gear is not listed.')}${back}${gilWin()}${win(rows.join('') || '<div class="dim pad">Nothing to sell.</div>', 'cmd listw shopl')}`;
  }
  // Bazaar
  const known = knownRecipes(), hidden = RECIPES.length - known.length;
  let h = 'Combine loot to create items the shop doesn\'t sell. Once made, the item joins the shop\'s stock.';
  const r = S.hl && RECIPES.find(x => x.id === S.hl);
  if (r) { const it = ITEMS[r.out]; h = `${it.name}: ${statStr(it.stats)}<br>${learnStr(it)}<br>${Object.keys(r.need).map(k => `<span class="${(G.loot[k] || 0) >= r.need[k] ? 'ok' : 'bad'}">${LOOT[k].name} ${G.loot[k] || 0}/${r.need[k]}</span>`).join(' ')} <span class="${G.gil >= r.gil ? 'ok' : 'bad'}">${r.gil} gil</span>${canCraft(r) ? '<br>Tap again to combine.' : ''}`; }
  return `${help(h)}${back}${gilWin()}${win(known.map(x => item(ITEMS[x.out].name, 'bazhl', x.id, { sel: S.hl === x.id, r: canCraft(x) ? '<span class="ok">OK</span>' : '' })).join('') + (hidden ? `<div class="dim pad small">${hidden} more combination${hidden > 1 ? 's' : ''} not yet known.</div>` : ''), 'cmd listw shopl')}`;
}
function qtyModal(kind, id, mode) {
  const name = kind === 'cons' ? CONS[id].name : kind === 'loot' ? LOOT[id].name : ITEMS[id].name;
  const price = mode === 'buy' ? (kind === 'cons' ? CONS[id].price : ITEMS[id].price) : sellPrice(id, kind);
  const have = kind === 'cons' ? G.cons[id] || 0 : kind === 'loot' ? G.loot[id] || 0 : G.inv[id] || 0;
  const max = mode === 'buy' ? Math.max(1, Math.min(99, Math.floor(G.gil / price))) : have;
  S.q = { kind, id, mode, n: 1, max, price };
  qtyDraw();
}
function qtyDraw() {
  const q = S.q, name = q.kind === 'cons' ? CONS[q.id].name : q.kind === 'loot' ? LOOT[q.id].name : ITEMS[q.id].name;
  modal(`<div class="wt">${name}</div><div class="qty"><button class="win" data-a="qty" data-v="-1" aria-label="Fewer">◀</button><span class="num big">${q.n}</span><button class="win" data-a="qty" data-v="1" aria-label="More">▶</button></div>
    <div class="kv"><span class="k">${q.mode === 'buy' ? 'Cost' : 'Gain'}</span><span class="num">${q.n * q.price} gil</span></div>
    ${cmd([item(q.mode === 'buy' ? 'Buy' : 'Sell', 'qtyok', null, { dis: q.mode === 'buy' && G.gil < q.price }), item('Cancel', 'close')])}`);
}

// ---------- Deploy ----------
function deployScr() {
  const mission = S.kind === 'mission' ? nextMission() : null;
  const max = mission ? mission.deploy : 5, law = mission ? mission.law : todaysLaw();
  return `${help(`Select units to send into battle. ${S.deploy.length}/${max}`)}${backBtn('world')}
  ${win(`<div class="wt">${mission ? esc(mission.name) : 'Patrol: ' + LOCS[G.loc].name}</div>${mission ? `<p class="small">${esc(mission.brief)}</p>` : ''}<div class="lawl"><span class="k">Forbidden</span>${lawText(law.ban)}</div><div class="lawl"><span class="k">Recommended</span>${lawText(law.fav)}</div>`, 'textw')}
  <div class="ugrid">${G.units.map(u => {
    const ok = available(u), on = S.deploy.includes(u.id), n = S.deploy.indexOf(u.id) + 1;
    return `<button class="win ucell${on ? ' on' : ''}${ok ? '' : ' dis'}" ${ok ? `data-a="toggledeploy" data-v="${u.id}"` : 'disabled'}>${pimg(u)}<span class="nm">${esc(u.name)}</span><span class="jb">${JOBS[u.job].name}</span><span class="lvl"><span class="k">Lv</span>${u.lv}</span>${unitTags(u)}${on ? `<span class="pick">${n}</span>` : ''}</button>`;
  }).join('')}</div>
  <div class="stick">${cmd([item('Begin battle', 'fight', null, { dis: !S.deploy.length })], 'begin')}</div>`;
}

// ---------- Results ----------
function resultsScr() {
  const R = S.results;
  const lootStr = Object.keys(R.loot).map(k => LOOT[k].name + ' ×' + R.loot[k]).concat(Object.keys(R.items).map(k => CONS[k].name + ' ×' + R.items[k])).concat(R.stolen.map(id => ITEMS[id].name));
  if (S.rstep === 0) {
    return `${help(R.won ? 'The Judge declares your clan the victor.' : 'Your clan withdraws from the field.')}
    <div class="banner ${R.won ? 'win' : 'loss'}">${R.won ? (R.story ? 'Mission Complete!' : 'Victory!') : 'Defeat...'}</div>
    ${R.won ? win(`<div class="wt sm">Rewards</div><div class="kv"><span class="k">Gil</span><span class="num">+${R.gil}</span></div>${lootStr.map(s => `<div class="kv"><span class="k">Item</span>${esc(s)}</div>`).join('')}`, 'textw') : ''}
    ${R.gilLost ? win(`<span class="bad">Enemy thieves took ${R.gilLost} gil.</span>`, 'textw') : ''}
    ${R.lost.length ? win(`<span class="bad">Stolen: ${R.lost.map(x => ITEMS[x.item].name).join(', ')}</span>`, 'textw') : ''}
    ${R.story === 'm3' ? win(`<div class="wt sm">Chapter 1 complete</div><p>The Mire Hag sinks into the bog for the last time. Word of ${esc(G.clan)} spreads along the border roads.</p>`, 'textw') : R.story ? win('<p>New stock is in at the shop, and a new location has opened.</p>', 'textw') : ''}
    <div class="stick">${cmd([item('Next', 'rnext')])}</div>`;
  }
  if (S.rstep === 1) {
    return `${help('AP earned. Abilities are mastered at full AP.')}
    <div class="rlist">${R.units.map(x => {
      const u = unitById(x.id); if (!u) return '';
      const notes = x.mastered.map(id => `<div class="mast">Mastered ${AB[id].name}!</div>`).join('') + x.jobs.map(j => `<div class="ylw">New job: ${JOBS[j].name}</div>`).join('') + (R.jailed.includes(u.id) ? '<div class="bad">Sent to prison</div>' : '');
      return win(`${pimg(u)}<div class="si"><div class="nm">${esc(u.name)}<span class="jb">${JOBS[u.job].name}</span></div><div class="row"><span class="k">Lv</span>${u.lv}<span class="k sp">AP</span>+${x.ap}</div>${notes}</div>`, 'stat');
    }).join('')}</div>
    ${R.errands.length ? win(`<div class="wt sm">Errands</div>${R.errands.map(e => `<div class="kv">${esc(e.unit)}: ${esc(e.name)} — ${e.ok ? '<span class="ok">Success</span> +' + e.gil + ' gil' + (e.loot ? ', ' + LOOT[e.loot].name : '') : '<span class="bad">Failed</span>'}</div>`).join('')}`, 'textw') : ''}
    <div class="stick">${cmd([item('Next', 'rnext')])}</div>`;
  }
  const u = G.offer;
  return `${help(`${esc(u.name)} wants to join your clan.`)}
  ${win(`${pimg(u, 'big')}<div class="si"><div class="nm">${esc(u.name)}<span class="jb">${JOBS[u.job].name}</span></div><div class="dim">${RACES[u.race].name} · ${esc(RACES[u.race].desc)}</div><div class="row"><span class="k">Lv</span>${u.lv}</div></div>`, 'stat')}
  ${statsWin(calcStats(u))}
  <div class="stick">${cmd([item('Welcome aboard', 'recruit', '1', { dis: G.units.length >= CLAN_MAX }), item('Decline', 'recruit', '0')])}</div>`;
}

// ---------- Guide ----------
function guide() {
  modal(`<div class="wt">How to play</div><div class="guide">
  <p><b>Turns.</b> Units act in order of Speed. Each turn you may Move and use an Action once, in either order, then Wait and choose a facing. Skipping Move or Action brings your next turn sooner.</p>
  <p><b>Height and facing.</b> Jump limits how high a unit can climb. Attacks from the side or back hit far more often.</p>
  <p><b>Jobs.</b> Each race has its own jobs. New jobs open when you master abilities from other jobs.</p>
  <p><b>Abilities.</b> Gear teaches abilities. While it is equipped, the matching job can use them. Win battles to earn AP and master them for good. Set a second job's mastered actions as A-Ability 2, plus one R-Ability and one S-Ability.</p>
  <p><b>Laws.</b> A Judge watches every battle. Forbidden actions earn cards; two cards mean prison. KOs and recommended actions earn JP for Combos.</p>
  <p><b>Gear.</b> The shop stocks more after each story mission. Combine loot at the Bazaar for rare items. Rogues can steal enemy gear.</p>
  <p><b>Battle map.</b> Drag to pan, pinch or use +/− to zoom, ⟲⟳ to rotate.</p></div>
  ${cmd([item('Close', 'close')])}`, 'wide');
}

// ---------- Actions ----------
const ACT = {
  close: closeModal,
  noop: () => {},
  guide,
  go: v => { closeModal(); if (v === 'world') S.sel = null; if (v === 'shop') S.shop = 'menu'; if (v === 'pub') S.pub = 'menu'; S.slot = null; go(v); },
  newgame: v => {
    if (hasSave() && v !== 'ok') { modal(`<div class="wt">Start a new game?</div><p>Your current save will be replaced.</p>${cmd([item('Yes', 'newgame', 'ok'), item('No', 'close')])}`); return; }
    modal(`<div class="wt">Name your clan</div><input id="clanname" maxlength="16" value="Clan Briar" aria-label="Clan name">${cmd([item('OK', 'startgame')])}`);
  },
  startgame: () => { const n = (($('#clanname') || {}).value || '').trim() || 'Clan Briar'; closeModal(); newGame(n); save(); S.sel = null; go('world'); setTimeout(guide, 200); },
  continue: () => { load(); S.sel = null; go('world'); },
  totitle: () => go('title'),
  selloc: v => { S.sel = v; render(); },
  travel: v => { if (travel(v)) { save(); S.sel = null; render(); toast('Arrived at ' + LOCS[v].name); } },
  mm: v => {
    if (v === 'save') { save(); toast('Game saved.'); return; }
    S.unit = S.unit || G.units[0].id; go(v);
  },
  unit: v => { S.unit = v; go('unit'); },
  cycle: v => { const i = G.units.findIndex(u => u.id === S.unit), n = G.units[i + +v]; if (n) { S.unit = n.id; S.slot = null; S.hl = null; render(); } },
  um: v => {
    if (v === 'dismiss') { const u = unitById(S.unit); modal(`<div class="wt">Dismiss ${esc(u.name)}?</div><p>Their gear returns to storage.</p>${cmd([item('Dismiss', 'dismissok'), item('Cancel', 'close')])}`); return; }
    go(v);
  },
  dismissok: () => { dismiss(unitById(S.unit)); save(); closeModal(); go('units'); },
  eqslot: v => { S.slot = v; S.hl = null; render(); },
  eqback: () => { S.slot = null; S.hl = null; render(); },
  eqpick: v => tap2(v, () => { equip(unitById(S.unit), S.slot, v === '-' ? null : v); save(); render(); toast(v === '-' ? 'Removed.' : 'Equipped ' + ITEMS[v].name + '.'); }),
  abpick: v => { S.hl = S.hl === v ? null : v; render(); },
  picksub: () => {
    const u = unitById(S.unit), list = jobsFor(u.race).filter(j => j !== u.job && jobOpen(u, j));
    modal(`<div class="wt">A-Ability 2</div>${cmd([item('(None)', 'setsub', '')].concat(list.map(j => item(JOBS[j].cmd, 'setsub', j, { sel: u.sub === j, r: `<small>${jobAbilities(j).filter(id => u.ms[id]).length} learned</small>` }))))}${cmd([item('Cancel', 'close')])}`);
  },
  setsub: v => { unitById(S.unit).sub = v || null; save(); closeModal(); render(); },
  pickrs: v => {
    const u = unitById(S.unit), list = Object.keys(u.ms).filter(id => AB[id].type === v);
    modal(`<div class="wt">${v}-Ability</div>${cmd([item('(None)', 'setrs', v + ':')].concat(list.map(id => item(AB[id].name, 'setrs', v + ':' + id, { sel: (v === 'R' ? u.r : u.s) === id }))))}
      <p class="small dim">${list.length ? list.map(id => `${AB[id].name}: ${esc(AB[id].desc)}`).join('<br>') : 'None mastered yet. Armor and accessories teach these.'}</p>${cmd([item('Cancel', 'close')])}`);
  },
  setrs: v => { const [t, id] = v.split(':'), u = unitById(S.unit); if (t === 'R') u.r = id || null; else { u.s = id || null; if (u.eq.o && !canEquip(u, ITEMS[u.eq.o])) equip(u, 'o', null); } save(); closeModal(); render(); },
  jobpick: v => {
    const u = unitById(S.unit);
    if (!jobOpen(u, v) || v === u.job) { S.hl = v; render(); return; }
    tap2(v, () => { changeJob(u, v); save(); render(); toast('Job changed to ' + JOBS[v].name + '.'); });
  },
  itab: v => { S.itab = v; S.hl = null; render(); },
  ihl: v => { S.hl = v; render(); },
  fast: () => { G.fast = !G.fast; save(); render(); },
  town: v => { if (v === 'exit') { S.sel = null; go('world'); return; } S.shop = 'menu'; S.pub = 'menu'; go(v); },
  pubm: v => { if (v === 'exit') { go('town'); return; } S.pub = v; S.hl = null; render(); },
  pubmis: v => tap2(v, () => { if (G.accepted !== v) { G.accepted = v; save(); toast('Mission accepted.'); } S.hl = v; render(); }),
  errand: v => tap2(v, () => {
    const e = ERRANDS.find(x => x.id === v), ok = G.units.filter(u => errandOk(e, u));
    modal(`<div class="wt">${e.name}</div><p class="small dim">Needs ${e.job ? (RACES[e.job] ? RACES[e.job].name : JOBS[e.job].name) + ', ' : ''}Lv ${e.minLv}+. Higher level means better odds.</p>
      ${ok.length ? cmd(ok.map(u => item(`${esc(u.name)} <small class="dim">${JOBS[u.job].name} Lv${u.lv}</small>`, 'senderrand', v + ':' + u.id))) : '<p class="dim">Nobody available meets the requirements.</p>'}${cmd([item('Cancel', 'close')])}`);
  }),
  senderrand: v => { const [eid, uid] = v.split(':'); sendErrand(eid, unitById(uid)); closeModal(); render(); toast('Errand started.'); },
  bail: v => { if (bail(unitById(v))) { save(); render(); toast('Released from prison.'); } },
  shopm: v => { if (v === 'exit') { go('town'); return; } S.shop = v; S.hl = null; render(); },
  cat: v => { S.cat = v; S.hl = null; render(); },
  buyhl: v => tap2(v, () => { S.hl = v; render(); if (v.startsWith('c:')) qtyModal('cons', v.slice(2), 'buy'); else qtyModal('item', v, 'buy'); }),
  sellhl: v => tap2(v, () => { const [k, id] = v.split(':'); S.hl = v; render(); qtyModal(k, id, 'sell'); }),
  qty: v => { const q = S.q; q.n = Math.max(1, Math.min(q.max, q.n + +v)); qtyDraw(); },
  qtyok: () => {
    const q = S.q; let n = 0;
    for (let i = 0; i < q.n; i++) if (q.mode === 'buy' ? buy(q.id, q.kind) : sell(q.id, q.kind)) n++;
    save(); closeModal(); if (q.mode === 'sell') S.hl = null; render(); toast(`${q.mode === 'buy' ? 'Bought' : 'Sold'} ${n}.`);
  },
  bazhl: v => tap2(v, () => { const r = RECIPES.find(x => x.id === v); if (craft(r)) { save(); toast('Created ' + ITEMS[r.out].name + '!'); } else toast('Missing ingredients.'); render(); }),
  rnext: () => { S.rstep++; if (S.rstep === 2 && !G.offer) { S.sel = null; go('world'); return; } if (S.rstep > 2) { S.sel = null; go('world'); return; } render(); },
  recruit: v => { if (v === '1') acceptRecruit(); else { G.offer = null; save(); } S.sel = null; go('world'); },
  deploy: v => { S.kind = v; const max = v === 'mission' ? nextMission().deploy : 5; S.deploy = G.units.filter(available).slice(0, max).map(u => u.id); go('deploy'); },
  toggledeploy: v => {
    const max = S.kind === 'mission' ? nextMission().deploy : 5;
    if (S.deploy.includes(v)) S.deploy = S.deploy.filter(x => x !== v); else if (S.deploy.length < max) S.deploy.push(v); else toast('Up to ' + max + ' units.');
    render();
  },
  fight: () => startBattle(),
};
document.addEventListener('click', e => {
  const el = e.target.closest('[data-a]');
  if (!el || el.disabled) return;
  const f = ACT[el.dataset.a] || BACT[el.dataset.a];
  if (f) f(el.dataset.v, el, e);
});
document.addEventListener('keydown', e => { if ((e.key === 'Enter' || e.key === ' ') && e.target.matches('g[data-a]')) { e.preventDefault(); e.target.dispatchEvent(new MouseEvent('click', { bubbles: true })); } });

// =====================================================================
// Battle controller
// =====================================================================
const BS = { mode: 'idle', actor: null, resolve: null, ab: null, center: null, reach: null, set: null };
let B = null;

function startBattle() {
  B = buildBattle(S.kind, S.deploy);
  S.scr = 'battle';
  const app = $('#app');
  app.className = 'scr-battle';
  app.innerHTML = `<div class="bwrap"><canvas id="bv"></canvas>
    <div id="bhelp" class="bhelp">${help('')}</div>
    <div class="vctl"><button class="win ico" data-a="bmenu" aria-label="Battle menu">≡</button><button class="win ico" data-a="rot" data-v="-1" aria-label="Rotate left">⟲</button><button class="win ico" data-a="rot" data-v="1" aria-label="Rotate right">⟳</button><button class="win ico" data-a="zoom" data-v="1.2" aria-label="Zoom in">+</button><button class="win ico" data-a="zoom" data-v="0.83" aria-label="Zoom out">−</button></div>
    <div id="btgt" class="btgt"></div>
    <div id="bcmd" class="bcmd"></div>
    <div id="bstat" class="bstat"></div>
  </div><div id="modal" hidden></div><div id="toast" hidden></div>`;
  const cv = $('#bv');
  viewInit(cv, B);
  bindCanvas(cv);
  window.onresize = () => { if (S.scr === 'battle') viewResize(); };
  battleLoop();
}
function bHelp(t) { const h = $('#bhelp .helpt'); if (h) h.innerHTML = t || '&nbsp;'; }
function setCmd(html) { const c = $('#bcmd'); if (c) c.innerHTML = html || ''; }
function setStat(u) { const c = $('#bstat'); if (c) c.innerHTML = u ? statusWin(u) : ''; }
function setTgt(html) { const c = $('#btgt'); if (c) c.innerHTML = html || ''; }
function waitOk(html) { return new Promise(res => { BS.okRes = res; modal(html + cmd([item('OK', 'bok')])); }); }
async function battleLoop() {
  const law = B.law;
  await waitOk(`<div class="wt">${B.mission ? esc(B.mission.name) : 'Patrol: ' + esc(B.map.name)}</div><div class="judge">The Judge sets today's laws.</div><div class="kv"><span class="k">Forbidden</span>${lawText(law.ban)}</div><div class="kv"><span class="k">Recommended</span>${lawText(law.fav)}</div><p class="small dim">Defeat all enemies.</p>`);
  while (!B.over) {
    const a = nextActor(B);
    if (!a) break;
    BS.actor = a; V.active = a; centerOn(a.x, a.y);
    setStat(a); setTgt(''); setCmd('');
    bHelp(`${esc(a.name)}'s turn.`);
    const st = startTurn(B, a);
    await playEvents(st.ev);
    if (checkEnd(B)) break;
    if (!st.skip && !a.ko) {
      if (a.team === 0) await playerTurn(a); else await enemyTurn(a);
    }
    if (!a.ko && !a.jailed) endTurn(B, a);
    else if (a.ko) a.ct = 0;
  }
  V.active = null; V.facing = null;
  setCmd(''); setTgt('');
  await sleep(400);
  await waitOk(`<div class="banner ${B.over === 1 ? 'win' : 'loss'}">${B.over === 1 ? (B.mission ? 'Mission Complete!' : 'Victory!') : 'Defeat...'}</div>`);
  viewStop();
  S.results = finishBattle(B); S.rstep = 0;
  window.onresize = null;
  go('results');
}

// ----- Player turn -----
function playerTurn() { return new Promise(res => { BS.resolve = res; showMenu(); }); }
function endPlayerTurn() { BS.mode = 'idle'; V.facing = null; setCmd(''); const r = BS.resolve; BS.resolve = null; r && r(); }
const CMDHELP = { bmove: 'Move to another panel.', bact: 'Fight or use an ability.', bwait: 'End this unit\'s turn.', bstatus: 'Check unit status.' };
function showMenu() {
  const a = BS.actor;
  clearHL(); V.cursor = [a.x, a.y]; V.facing = null; setTgt('');
  BS.mode = 'menu';
  setStat(a);
  const canAct = !a.acted && !a.st.disable;
  const rows = [item('Move', 'bmove', null, { dis: !canMove(a) }), item('Action', 'bact', null, { dis: !canAct }), item('Wait', 'bwait'), item('Status', 'bstatus')];
  setCmd(cmd(rows, 'bc4'));
  const first = canMove(a) ? 'bmove' : canAct ? 'bact' : 'bwait';
  bHelp(CMDHELP[first]);
}
function clearHL() { V.hl = new Map(); V.area = new Set(); }
function lawTag(a, ab) {
  if (!B.law) return '';
  if (lawMatch(B.law.ban, a, ab, a.x, a.y) && LAWS[B.law.ban].k !== 'ranged') return 'forb';
  return '';
}
function showActionMenu() {
  const a = BS.actor;
  BS.mode = 'actmenu'; clearHL();
  const rows = [item('Fight', 'bpick', 'fight', { cls: lawTag(a, FIGHT) })];
  actionSets(a.u).forEach((s, i) => rows.push(item(s.name, 'bset', i, { dis: !s.list.length || (a.st.silence && s.list.every(id => AB[id].cat === 'mag')) })));
  const items = Object.keys(CONS).filter(k => B.inv[k] > 0);
  rows.push(item('Item', 'bset', 'item', { dis: !items.length }));
  if (a.jp >= COMBO.jpCost) rows.push(item('Combo', 'bpick', 'combo', { r: '3JP' }));
  rows.push(item('Back', 'bcancel'));
  setCmd(cmd(rows, 'bc4'));
  bHelp('Choose a command.');
}
function showAbilityList(set) {
  const a = BS.actor;
  BS.mode = 'ablist'; BS.set = set; S.hl = null;
  drawAbilityList();
}
function drawAbilityList() {
  const a = BS.actor, set = BS.set;
  const ids = set === 'item' ? Object.keys(CONS).filter(k => B.inv[k] > 0).map(k => 'item:' + k) : actionSets(a.u)[+set].list;
  const rows = ids.map(id => {
    const ab = abilityFor(id), why = blocked(B, a, ab), cost = ab.cons ? '×' + B.inv[ab.cons] : mpCost(a, ab) ? mpCost(a, ab) + 'MP' : '';
    return item(ab.name, 'bab', id, { dis: !!why, sel: S.hl === id, r: cost, cls: lawTag(a, ab) });
  });
  rows.push(item('Back', 'bact'));
  setCmd(win(cursorFirst(rows.join('')), 'cmd ablistb'));
  const h = S.hl && abilityFor(S.hl);
  bHelp(h ? `${esc(h.desc || '')}${lawTag(a, h) ? ' <span class="bad">Forbidden by law!</span>' : ''}<br><span class="dim">Tap again to use.</span>` : (set === 'item' ? 'Choose an item.' : 'Choose an ability.'));
}
function startTargeting(id) {
  const a = BS.actor, ab = abilityFor(id);
  BS.ab = id; BS.center = null; BS.mode = 'target';
  clearHL();
  for (const [x, y] of rangeTiles(B, a, ab)) V.hl.set(x + ',' + y, ab.tgt === 'foe' ? 'rgba(255,110,80,.45)' : 'rgba(110,220,140,.45)');
  if (ab.rng === 0) { BS.center = [a.x, a.y]; setArea(); }
  showTargetPanel();
}
const BACT = {
  rot: v => rotateView(+v),
  zoom: v => zoomBy(+v),
  bok: () => { closeModal(); const r = BS.okRes; BS.okRes = null; r && r(); },
  bmenu: () => modal(`<div class="wt">Battle</div>${cmd([item('Laws', 'blaws'), item('How to play', 'guide'), item('Retreat', 'flee'), item('Close', 'close')])}`),
  blaws: () => modal(`<div class="wt">Laws</div><div class="kv"><span class="k">Forbidden</span>${lawText(B.law.ban)}</div><div class="kv"><span class="k">Recommended</span>${lawText(B.law.fav)}</div><p class="small">First offense: yellow card. Second: red card and prison.</p>${cmd([item('Close', 'close')])}`),
  flee: () => { closeModal(); for (const u of B.units) if (u.team === 0) u.ko = true; B.over = -1; if (BS.resolve) endPlayerTurn(); },
  bstatus: () => {
    const a = BS.actor, s = { atk: eff(a, 'atk'), def: eff(a, 'def'), mag: eff(a, 'mag'), res: eff(a, 'res'), spd: Math.round(speed(a)), ev: eff(a, 'ev'), mv: eff(a, 'mv'), jp: eff(a, 'jp') };
    modal(statusWin(a) + statsWin(s) + win(`<div class="kv"><span class="k">A-Ability</span>${a.mon ? a.name : JOBS[a.u.job].cmd}</div><div class="kv"><span class="k">A-Ability 2</span>${a.u.sub ? JOBS[a.u.sub].cmd : '—'}</div><div class="kv"><span class="k">R-Ability</span>${a.u.r ? AB[a.u.r].name : '—'}</div><div class="kv"><span class="k">S-Ability</span>${a.u.s ? AB[a.u.s].name : '—'}</div>`, 'abset') + cmd([item('Close', 'close')]), 'bare');
  },
  bmove: () => {
    const a = BS.actor;
    BS.mode = 'move'; BS.reach = reach(B, a);
    clearHL();
    for (const [k, v] of BS.reach) if (v.d > 0) V.hl.set(k, 'rgba(90,150,255,.5)');
    setCmd(cmd([item('Cancel', 'bcancel')], 'bc4'));
    bHelp(`Select a destination. <span class="dim">Move ${eff(a, 'mv')} · Jump ${eff(a, 'jp')}</span>`);
  },
  bcancel: () => showMenu(),
  bact: () => showActionMenu(),
  bset: v => showAbilityList(v),
  bab: v => { if (S.hl !== v) { S.hl = v; drawAbilityList(); return; } S.hl = null; startTargeting(v); },
  bpick: v => startTargeting(v),
  bgo: () => doAct(),
  bwait: () => {
    BS.mode = 'face'; clearHL(); setTgt('');
    const a = BS.actor;
    V.facing = a; V.cursor = null; centerOn(a.x, a.y);
    const dirs = [0, 1, 2, 3].map(f => { const [dx, dy] = screenDir(f); return { f, pos: (dy < 0 ? 'n' : 's') + (dx < 0 ? 'w' : 'e') }; });
    const lbl = { ne: '↗', se: '↘', sw: '↙', nw: '↖' };
    setCmd(win(`<div class="facepad">${['nw', 'ne', 'sw', 'se'].map(p => { const d = dirs.find(x => x.pos === p); return `<button class="win${a.f === d.f ? ' on' : ''}" data-a="bface" data-v="${d.f}" aria-label="Face ${p.toUpperCase()}">${lbl[p]}</button>`; }).join('')}</div>${cursorFirst(item('OK', 'bfaceok'))}`, 'cmd bc4'));
    bHelp('Select a direction to face.');
  },
  bface: v => { const a = BS.actor; if (a.f === +v && BS.mode === 'face') { endPlayerTurn(); return; } a.f = +v; if (BS.mode === 'face') BACT.bwait(); },
  bfaceok: () => { if (BS.mode === 'face') endPlayerTurn(); },
};
function setArea() {
  V.area = new Set();
  if (!BS.center) return;
  const ab = abilityFor(BS.ab);
  for (const [x, y] of areaTiles(B, ab, BS.center[0], BS.center[1])) V.area.add(x + ',' + y);
}
function showTargetPanel() {
  const a = BS.actor, ab = abilityFor(BS.ab);
  if (!BS.center) { setTgt(''); setCmd(cmd([item('Cancel', 'bact')], 'bc4')); bHelp(`<b>${ab.name}</b> · Select a target.`); return; }
  const [cx, cy] = BS.center, ts = targetsOf(B, a, ab, cx, cy);
  V.cursor = BS.center;
  const wins = ts.slice(0, 3).map(t => {
    const p = predict(B, a, ab, t);
    let e = '';
    if (ab.fx === 'atk' || ab.fx === 'mag' || ab.fx === 'drain') e = `<span class="k">Dmg</span>${p.amt}`;
    else if (ab.fx === 'heal') e = `<span class="k">HP</span>+${-p.amt}`;
    else if (ab.fx === 'mpdmg') e = `<span class="k">MP</span>-${p.amt}`;
    else if (ab.fx === 'raise') e = 'Revive';
    if (p.stCh !== undefined && ab.st) e += ` <span class="k">${ab.st.map(s => STATUS[s].name).join('/')}</span>${p.stCh}%`;
    const hit = ab.fx === 'atk' || ab.fx === 'steal' ? `<span class="k">Hit</span>${p.hit}% ` : '';
    return statusWin(t, `<div class="pred">${hit}${e}</div>`);
  }).join('') + (ts.length > 3 ? win(`+${ts.length - 3} more`, 'more') : '');
  setTgt(wins);
  const bad = breaksLaw(B, a, ab, cx, cy);
  bHelp(`<b>${ab.name}</b>${bad ? ` <span class="bad">Forbidden by law! ${a.cards ? 'Red card: prison.' : 'Yellow card.'}</span>` : ts.length ? ' · Tap again or Execute.' : ' · No target there.'}`);
  setCmd(cmd([item('Execute', 'bgo', null, { dis: !ts.length }), item('Cancel', 'bact')], 'bc4'));
}
async function doAct() {
  const a = BS.actor, [cx, cy] = BS.center, id = BS.ab;
  BS.mode = 'busy'; clearHL(); setCmd(''); setTgt('');
  const ev = perform(B, a, id, cx, cy);
  await playEvents(ev);
  setStat(a);
  if (B.over || a.jailed || a.ko) { endPlayerTurn(); return; }
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
  BS.mode = 'busy'; clearHL(); setCmd('');
  moveUnit(B, a, x, y);
  a.f = f;
  await moveAnim(a, path);
  if (a.acted) BACT.bwait(); else showMenu();
}
async function enemyTurn(a) {
  setStat(a);
  await sleep(350);
  const p = aiPlan(B, a);
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
    V.cursor = [p.cx, p.cy];
    centerOn(p.cx, p.cy);
    bHelp(`<b>${ab.name}</b>`);
    const t = unitAt(B, p.cx, p.cy);
    if (t && !t.ko) setTgt(statusWin(t));
    await sleep(500);
    clearHL();
    const ev = perform(B, a, p.id, p.cx, p.cy);
    await playEvents(ev);
    setTgt('');
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
      case 'msg': bHelp(esc(e.text)); break;
      case 'dmg': u.flash = performance.now(); floatText(u, String(e.v), '#ffffff'); await sleep(140); break;
      case 'heal': floatText(u, String(e.v), '#7ef09a'); await sleep(120); break;
      case 'mp': floatText(u, (e.v > 0 ? '+' : '') + e.v + 'MP', '#8ac8ff'); await sleep(100); break;
      case 'miss': floatText(u, 'Miss', '#c8c8c8'); await sleep(120); break;
      case 'status': floatText(u, STATUS[e.s].name, STATUS[e.s].col); await sleep(140); break;
      case 'ko': floatText(u, 'KO', '#ff6a5a'); await sleep(220); break;
      case 'raise': floatText(u, 'Revived', '#7ef09a'); break;
      case 'jp': floatText(u, '+' + e.v + 'JP', '#ffe58a'); await sleep(100); break;
      case 'lvup': floatText(u, 'Level Up!', '#ffe58a'); await sleep(200); break;
      case 'card': toast(e.red ? `Red card! ${u.name} goes to prison.` : `Yellow card for ${u.name}!`); await sleep(700); break;
    }
  }
  if (BS.actor && (BS.mode === 'busy' || BS.mode === 'idle')) setStat(BS.actor);
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
  if (BS.mode === 'face') { const f = pickArrow(px, py); if (f !== null) BACT.bface(String(f)); return; }
  const t = pickTile(px, py);
  if (!t) return;
  const [x, y] = t, k = x + ',' + y;
  if (BS.mode === 'move') { if (V.hl.has(k)) doMove(x, y); else V.cursor = t; return; }
  if (BS.mode === 'target') {
    if (!V.hl.has(k)) { const u = unitAt(B, x, y); if (u) setTgt(statusWin(u)); return; }
    if (BS.center && BS.center[0] === x && BS.center[1] === y && targetsOf(B, BS.actor, abilityFor(BS.ab), x, y).length) { doAct(); return; }
    BS.center = [x, y]; setArea(); showTargetPanel();
    return;
  }
  if (BS.mode === 'menu' || BS.mode === 'actmenu' || BS.mode === 'ablist') {
    V.cursor = t;
    const u = unitAt(B, x, y);
    setTgt(u && u !== BS.actor ? statusWin(u) : '');
  }
}

// ---------- Boot ----------
window.addEventListener('DOMContentLoaded', () => { render(); });
