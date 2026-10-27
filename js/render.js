// Hollowmark Tactics: isometric battle renderer (canvas). Procedural art, no image assets.
'use strict';

const TW = 26, TH = 13, HS = 11; // tile half-width, half-height, height step (px at scale 1)
const TEAMCOL = ['#5aa8ff', '#ff6a5a'];
const V = { cv: null, g: null, B: null, rot: 0, scale: 1, panX: 0, panY: 0, w: 0, h: 0, dpr: 1, hl: new Map(), area: new Set(), active: null, cursor: null,
  floats: [], fx: [], polys: [], tween: null, running: false, t: 0, onFrame: null };

function viewInit(cv, B) {
  V.cv = cv; V.g = cv.getContext('2d'); V.B = B; V.floats = []; V.fx = []; V.hl = new Map(); V.area = new Set();
  for (const u of B.units) { u.vx = u.x; u.vy = u.y; u.vh = tileAt(B, u.x, u.y).h; }
  viewResize();
  const fit = Math.min(V.w / ((B.map.w + B.map.d) * TW + 20), V.h / ((B.map.w + B.map.d) * TH + 120));
  V.minScale = Math.max(.35, fit * .9);
  V.scale = clamp(Math.max(fit, 1.15), V.minScale, 2.2);
  centerOn(B.map.w / 2, B.map.d / 2, true);
  if (!V.running) { V.running = true; requestAnimationFrame(frame); }
}
function viewStop() { V.running = false; }
function viewResize() {
  const r = V.cv.getBoundingClientRect();
  V.dpr = Math.min(2, window.devicePixelRatio || 1);
  V.w = r.width; V.h = r.height;
  V.cv.width = Math.round(r.width * V.dpr); V.cv.height = Math.round(r.height * V.dpr);
}
function rotXY(x, y) {
  const w = V.B.map.w, d = V.B.map.d;
  switch (V.rot) {
    case 1: return [d - 1 - y, x];
    case 2: return [w - 1 - x, d - 1 - y];
    case 3: return [y, w - 1 - x];
  }
  return [x, y];
}
function iso(x, y, h) { const [rx, ry] = rotXY(x, y); return [(rx - ry) * TW * V.scale + V.panX, (rx + ry) * TH * V.scale - h * HS * V.scale + V.panY]; }
function centerOn(x, y, now) {
  const t = tileAt(V.B, Math.round(x), Math.round(y)), h = t ? t.h : 0;
  const [rx, ry] = rotXY(x, y);
  const px = V.w / 2 - (rx - ry) * TW * V.scale, py = V.h * .45 - ((rx + ry) * TH - h * HS) * V.scale;
  if (now) { V.panX = px; V.panY = py; V.tween = null; } else V.tween = { x: px, y: py };
}
function zoomBy(f, cx, cy) {
  cx = cx === undefined ? V.w / 2 : cx; cy = cy === undefined ? V.h / 2 : cy;
  const s = clamp(V.scale * f, V.minScale, 2.4), k = s / V.scale;
  V.panX = cx - (cx - V.panX) * k; V.panY = cy - (cy - V.panY) * k; V.scale = s; V.tween = null;
}
function rotateView(dir) {
  const a = V.active || { vx: V.B.map.w / 2, vy: V.B.map.d / 2 };
  V.rot = (V.rot + dir + 4) % 4;
  centerOn(a.vx, a.vy, true);
}
// Screen direction of a grid facing (for sprite mirroring and the facing picker)
function screenDir(f) {
  const [dx, dy] = DIRS[f];
  const [ax, ay] = rotXY(0, 0), [bx, by] = rotXY(dx, dy);
  const rx = bx - ax, ry = by - ay;
  return [rx - ry, (rx + ry) / 2];
}

function hash(x, y, k) { let h = (x * 374761393 + y * 668265263 + (k || 0) * 2147483647) >>> 0; h = (h ^ (h >>> 13)) * 1274126177 >>> 0; return (h & 0xffff) / 0xffff; }
function shade(hex, f) {
  const n = parseInt(hex.slice(1), 16);
  let r = n >> 16, g = (n >> 8) & 255, b = n & 255;
  if (f > 0) { r += (255 - r) * f; g += (255 - g) * f; b += (255 - b) * f; } else { r *= 1 + f; g *= 1 + f; b *= 1 + f; }
  return 'rgb(' + (r | 0) + ',' + (g | 0) + ',' + (b | 0) + ')';
}

function frame(ts) {
  if (!V.running) return;
  V.t = ts;
  if (V.tween) {
    V.panX += (V.tween.x - V.panX) * .18; V.panY += (V.tween.y - V.panY) * .18;
    if (Math.abs(V.tween.x - V.panX) < .5 && Math.abs(V.tween.y - V.panY) < .5) V.tween = null;
  }
  draw();
  if (V.onFrame) V.onFrame(ts);
  requestAnimationFrame(frame);
}

function draw() {
  const g = V.g, B = V.B;
  g.setTransform(V.dpr, 0, 0, V.dpr, 0, 0);
  const bg = g.createRadialGradient(V.w / 2, V.h * .4, 40, V.w / 2, V.h * .5, Math.max(V.w, V.h));
  bg.addColorStop(0, '#2a2f38'); bg.addColorStop(1, '#101216');
  g.fillStyle = bg; g.fillRect(0, 0, V.w, V.h);
  V.polys = [];
  const cells = [];
  for (let y = 0; y < B.map.d; y++) for (let x = 0; x < B.map.w; x++) { const [rx, ry] = rotXY(x, y); cells.push({ x, y, k: rx + ry, rx }); }
  cells.sort((a, b) => a.k - b.k || a.rx - b.rx);
  const byTile = new Map();
  for (const u of B.units) if (!u.jailed) {
    const k = Math.round(u.vx) + ',' + Math.round(u.vy);
    (byTile.get(k) || byTile.set(k, []).get(k)).push(u);
  }
  for (const c of cells) {
    drawTile(c.x, c.y);
    const us = byTile.get(c.x + ',' + c.y);
    for (const o of B.objs || []) if (o.x === c.x && o.y === c.y) drawObj(o);
    if (us) for (const u of us) drawUnit(u);
  }
  drawFx();
}

function drawTile(x, y) {
  const g = V.g, B = V.B, t = B.map.tiles[y][x], T = TERRAIN[t.t], s = V.scale;
  let h = t.h;
  if (T.water && t.t === 'W') h -= .35;
  const [cx, cy] = iso(x, y, h);
  const tw = TW * s, th = TH * s, depth = (h + 1.2) * HS * s;
  if (cx < -tw * 2 || cx > V.w + tw * 2 || cy < -th * 4 || cy - depth > V.h + 40) { /* still register for picking */ }
  const v = (hash(x, y) - .5) * .12;
  let top = T.c[0];
  // sides
  g.fillStyle = shade(T.c[1], v);
  g.beginPath(); g.moveTo(cx - tw, cy); g.lineTo(cx, cy + th); g.lineTo(cx, cy + th + depth); g.lineTo(cx - tw, cy + depth); g.closePath(); g.fill();
  g.fillStyle = shade(T.c[2], v);
  g.beginPath(); g.moveTo(cx + tw, cy); g.lineTo(cx, cy + th); g.lineTo(cx, cy + th + depth); g.lineTo(cx + tw, cy + depth); g.closePath(); g.fill();
  // strata lines on the sides
  g.strokeStyle = 'rgba(0,0,0,.18)'; g.lineWidth = 1;
  for (let i = 1; i <= Math.floor(h); i++) {
    const yy = cy + i * HS * s;
    g.beginPath(); g.moveTo(cx - tw, yy); g.lineTo(cx, yy + th); g.lineTo(cx + tw, yy); g.stroke();
  }
  // top
  let tv = v;
  if (T.water) tv += Math.sin(V.t / 600 + x * .8 + y * .6) * .06;
  if (T.lava) tv += Math.sin(V.t / 300 + x + y) * .12;
  g.fillStyle = shade(top, tv);
  g.beginPath(); g.moveTo(cx, cy - th); g.lineTo(cx + tw, cy); g.lineTo(cx, cy + th); g.lineTo(cx - tw, cy); g.closePath(); g.fill();
  g.strokeStyle = 'rgba(255,255,255,.10)'; g.beginPath(); g.moveTo(cx - tw, cy); g.lineTo(cx, cy - th); g.lineTo(cx + tw, cy); g.stroke();
  g.strokeStyle = 'rgba(0,0,0,.25)'; g.beginPath(); g.moveTo(cx - tw, cy); g.lineTo(cx, cy + th); g.lineTo(cx + tw, cy); g.stroke();
  // detail
  if (t.t === 'g' || t.t === 'm') {
    g.strokeStyle = shade(top, t.t === 'm' ? -.25 : .18); g.lineWidth = Math.max(1, s);
    for (let i = 0; i < 3; i++) {
      const px = cx + (hash(x, y, i) - .5) * tw * 1.1, py = cy + (hash(x, y, i + 9) - .5) * th * 1.1;
      g.beginPath(); g.moveTo(px, py); g.lineTo(px - 1.5 * s, py - 3 * s); g.moveTo(px, py); g.lineTo(px + 1.5 * s, py - 3 * s); g.stroke();
    }
  } else if (T.water) {
    g.strokeStyle = 'rgba(255,255,255,.22)'; g.lineWidth = Math.max(1, s * .8);
    const o = ((V.t / 900 + hash(x, y)) % 1) - .5;
    g.beginPath(); g.moveTo(cx - tw * .4 + o * tw * .5, cy + o * th); g.lineTo(cx + tw * .1 + o * tw * .5, cy + o * th - th * .25); g.stroke();
  } else if (t.t === 'b') {
    g.strokeStyle = 'rgba(0,0,0,.3)'; g.lineWidth = 1;
    for (let i = -2; i <= 2; i++) { g.beginPath(); g.moveTo(cx + i * tw * .3 - tw * .25, cy + i * th * .3 - th * .25 * -1 - th * .25); g.lineTo(cx + i * tw * .3 + tw * .25, cy + i * th * .3 + th * .25 - th * .25); g.stroke(); }
  } else if (t.t === 's' || t.t === 'r' || t.t === 'c') {
    g.strokeStyle = 'rgba(0,0,0,.2)'; g.lineWidth = 1;
    const px = cx + (hash(x, y, 3) - .5) * tw, py = cy + (hash(x, y, 4) - .5) * th;
    g.beginPath(); g.moveTo(px, py); g.lineTo(px + 4 * s, py + 2 * s); g.lineTo(px + 6 * s, py - 1 * s); g.stroke();
  } else if (T.lava) {
    g.fillStyle = 'rgba(255,220,120,.5)';
    g.beginPath(); g.arc(cx + Math.sin(V.t / 500 + x) * tw * .3, cy, 2 * s, 0, 7); g.fill();
  }
  // highlights
  const key = x + ',' + y, hc = V.hl.get(key);
  if (hc) {
    g.fillStyle = hc; g.beginPath(); g.moveTo(cx, cy - th); g.lineTo(cx + tw, cy); g.lineTo(cx, cy + th); g.lineTo(cx - tw, cy); g.closePath(); g.fill();
  }
  if (V.area.has(key)) {
    g.fillStyle = 'rgba(255,214,90,' + (.35 + Math.sin(V.t / 150) * .12) + ')';
    g.beginPath(); g.moveTo(cx, cy - th); g.lineTo(cx + tw, cy); g.lineTo(cx, cy + th); g.lineTo(cx - tw, cy); g.closePath(); g.fill();
  }
  if (V.cursor && V.cursor[0] === x && V.cursor[1] === y) {
    g.strokeStyle = '#ffe9a0'; g.lineWidth = 2;
    g.beginPath(); g.moveTo(cx, cy - th); g.lineTo(cx + tw, cy); g.lineTo(cx, cy + th); g.lineTo(cx - tw, cy); g.closePath(); g.stroke();
  }
  if (T.tree) drawTree(cx, cy, s, x, y);
  V.polys.push({ x, y, pts: [cx, cy - th, cx + tw, cy, cx + tw, cy + depth, cx, cy + th + depth, cx - tw, cy + depth, cx - tw, cy] });
}
function drawTree(cx, cy, s, x, y) {
  const g = V.g, sway = Math.sin(V.t / 1200 + x + y) * 1.2 * s;
  g.fillStyle = '#5a3f28'; g.fillRect(cx - 2.5 * s, cy - 14 * s, 5 * s, 14 * s);
  const greens = ['#2f5a2a', '#3d7034', '#4f8a40'];
  for (let i = 0; i < 3; i++) {
    g.fillStyle = greens[i];
    g.beginPath(); g.arc(cx + sway * (i + 1) * .5 + (i - 1) * 3 * s, cy - (18 + i * 7) * s, (12 - i * 2.5) * s, 0, 7); g.fill();
  }
}

// ---------- Units ----------
// Vessel objects: a gold crystal that hovers over its tile.
function drawObj(o) {
  const g = V.g, s = V.scale, t = tileAt(V.B, o.x, o.y);
  const [cx, cy0] = iso(o.x, o.y, t.h), bob = Math.sin(V.t / 400 + o.x * 2 + o.y) * 2 * s, cy = cy0 - 10 * s + bob;
  g.save();
  g.fillStyle = 'rgba(0,0,0,.3)'; g.beginPath(); g.ellipse(cx, cy0, 7 * s, 3 * s, 0, 0, 7); g.fill();
  g.shadowColor = '#ffd36a'; g.shadowBlur = 10 * s;
  g.fillStyle = '#ffd36a'; g.beginPath(); g.moveTo(cx, cy - 9 * s); g.lineTo(cx + 6 * s, cy); g.lineTo(cx, cy + 9 * s); g.lineTo(cx - 6 * s, cy); g.closePath(); g.fill();
  g.shadowBlur = 0; g.fillStyle = 'rgba(255,255,255,.55)'; g.beginPath(); g.moveTo(cx, cy - 9 * s); g.lineTo(cx + 6 * s, cy); g.lineTo(cx, cy); g.closePath(); g.fill();
  g.restore();
}
function drawUnit(u) {
  const g = V.g, s = V.scale, B = V.B;
  const [cx, cy0] = iso(u.vx, u.vy, u.vh);
  const t = tileAt(B, Math.round(u.vx), Math.round(u.vy));
  const wet = t && TERRAIN[t.t].water ? 4 * s : 0;
  const bob = u === V.active ? Math.sin(V.t / 200) * 1.2 * s : 0;
  const cy = cy0 + (u.hop || 0) * -s;
  g.save();
  g.fillStyle = 'rgba(0,0,0,.35)'; g.beginPath(); g.ellipse(cx, cy, 11 * s, 5 * s, 0, 0, 7); g.fill();
  g.strokeStyle = TEAMCOL[u.team]; g.lineWidth = 2 * s; g.globalAlpha = .9;
  g.beginPath(); g.ellipse(cx, cy, 12 * s, 5.5 * s, 0, 0, 7); g.stroke(); g.globalAlpha = 1;
  if (u.ko) { drawKO(u, cx, cy, s); g.restore(); return; }
  const [sdx, sdy] = screenDir(u.f), flip = sdx < 0 ? -1 : 1, back = sdy < 0;
  if (u.flash && V.t - u.flash < 300) g.globalAlpha = .4 + .6 * Math.abs(Math.sin((V.t - u.flash) / 40));
  g.translate(cx, cy + wet + bob); g.scale(flip * s, s);
  if (wet) { g.save(); g.beginPath(); g.rect(-30, -60, 60, 60 - wet / s); g.clip(); }
  sprite(g, u, back);
  if (wet) g.restore();
  g.restore();
  // overhead: active marker, HP bar, statuses
  const top = cy - (u.mon === 'sandmaw' || u.mon === 'wolfhound' || u.mon === 'ooze' ? 26 : 40) * s;
  if (u === V.active) {
    const ay = top - 10 * s + Math.sin(V.t / 180) * 2 * s;
    g.fillStyle = '#ffd36a'; g.beginPath(); g.moveTo(cx - 5 * s, ay - 6 * s); g.lineTo(cx + 5 * s, ay - 6 * s); g.lineTo(cx, ay); g.closePath(); g.fill();
  }
  const bw = 22 * s, bh = Math.max(2, 3 * s);
  g.fillStyle = 'rgba(0,0,0,.6)'; g.fillRect(cx - bw / 2 - 1, top - 1, bw + 2, bh + 2);
  const p = u.hp / u.s.mhp;
  g.fillStyle = p > .5 ? '#6ad06a' : p > .25 ? '#e8c050' : '#e05a4a'; g.fillRect(cx - bw / 2, top, bw * p, bh);
  const sts = Object.keys(u.st);
  sts.slice(0, 5).forEach((k, i) => { g.fillStyle = STATUS[k].col; g.beginPath(); g.arc(cx - bw / 2 + 3 * s + i * 5 * s, top - 4 * s, 2 * s, 0, 7); g.fill(); });
  if (u.cards) { g.fillStyle = '#f0d040'; g.fillRect(cx + bw / 2 + 2 * s, top - 3 * s, 4 * s, 6 * s); }
}
function drawKO(u, cx, cy, s) {
  const g = V.g;
  g.globalAlpha = .75;
  g.fillStyle = u.mon ? MONSTERS[u.mon].col : JOBS[u.job].col;
  g.beginPath(); g.ellipse(cx, cy - 2 * s, 12 * s, 4 * s, -.2, 0, 7); g.fill();
  g.fillStyle = u.mon ? shade(MONSTERS[u.mon].col, .2) : RACES[u.race].skin;
  g.beginPath(); g.arc(cx + 11 * s, cy - 4 * s, 4 * s, 0, 7); g.fill();
  g.globalAlpha = 1;
}
function rr(g, x, y, w, h, r) { g.beginPath(); g.moveTo(x + r, y); g.arcTo(x + w, y, x + w, y + h, r); g.arcTo(x + w, y + h, x, y + h, r); g.arcTo(x, y + h, x, y, r); g.arcTo(x, y, x + w, y, r); g.closePath(); }
// Draw a unit facing screen-right, feet at (0,0), ~36px tall.
function sprite(g, u, back) {
  if (u.mon) return monsterSprite(g, u, back);
  const j = JOBS[u.job], skin = RACES[u.race].skin, col = j.col, dark = shade(col, -.35), race = u.race;
  const k = race === 'mossling' ? .78 : race === 'saurian' ? 1.1 : 1;
  g.save(); g.scale(k, k);
  const step = u.walk ? Math.sin(V.t / 70) * 2 : 0;
  // legs
  g.fillStyle = '#2c2a30';
  if (race !== 'nuwa') { g.fillRect(-5, -10 + step * .3, 4, 10 - step * .3); g.fillRect(1, -10 - step * .3, 4, 10 + step * .3); }
  if (race === 'saurian') { g.fillStyle = shade(skin, -.2); g.beginPath(); g.moveTo(-5, -10); g.quadraticCurveTo(-16, -6, -18, 0); g.lineTo(-14, 0); g.quadraticCurveTo(-11, -5, -4, -6); g.fill(); }
  // weapon behind when facing away
  if (back) weaponSprite(g, u);
  // body
  g.fillStyle = col;
  if (race === 'nuwa') { g.beginPath(); g.moveTo(-6, -24); g.lineTo(6, -24); g.lineTo(9, 0); g.lineTo(-9, 0); g.closePath(); g.fill(); }
  else { rr(g, -7, -24, 14, 15, 4); g.fill(); }
  g.fillStyle = dark; g.fillRect(-7, -12, 14, 2.5);
  if (j.body && j.body[0] === 'heavy') { g.fillStyle = 'rgba(255,255,255,.25)'; g.fillRect(-6, -23, 12, 3); }
  // head
  const hy = race === 'mossling' ? -31 : -30, hr = race === 'mossling' ? 8 : race === 'saurian' ? 6.5 : 6;
  if (race === 'sylph') { g.fillStyle = skin; g.beginPath(); g.moveTo(-3, hy - 4); g.lineTo(-6, hy - 17); g.lineTo(0, hy - 5); g.fill(); g.beginPath(); g.moveTo(1, hy - 4); g.lineTo(3, hy - 18); g.lineTo(4, hy - 4); g.fill(); }
  if (race === 'nuwa') { g.fillStyle = shade(skin, -.15); g.beginPath(); g.ellipse(-6, hy + 3, 3, 9, .3, 0, 7); g.fill(); }
  g.fillStyle = skin; g.beginPath(); g.arc(0, hy, hr, 0, 7); g.fill();
  if (race === 'saurian' && !back) { g.beginPath(); g.ellipse(6, hy + 1.5, 6, 3.5, 0, 0, 7); g.fill(); }
  if (race === 'mossling') { g.strokeStyle = '#3a2a2a'; g.lineWidth = 1; g.beginPath(); g.moveTo(0, hy - hr); g.lineTo(1, hy - hr - 6); g.stroke(); g.fillStyle = '#e04a5a'; g.beginPath(); g.arc(1, hy - hr - 7, 2.5, 0, 7); g.fill(); }
  // hair / hat
  if (race === 'human' || race === 'sylph') { g.fillStyle = race === 'sylph' ? '#e8e0d0' : hairCol(u); g.beginPath(); g.arc(0, hy - 1, hr + .5, Math.PI * .95, Math.PI * 2.05); g.fill(); if (back) { g.beginPath(); g.arc(0, hy, hr, 0, 7); g.fill(); } }
  if (j.head && j.head[0] === 'hat' && (u.u.eq.h)) { g.fillStyle = dark; g.beginPath(); g.moveTo(-8, hy - 3); g.lineTo(8, hy - 3); g.lineTo(1, hy - 15); g.closePath(); g.fill(); }
  if (u.u.eq.h && ITEMS[u.u.eq.h].t === 'helm') { g.fillStyle = '#b8bcc4'; g.beginPath(); g.arc(0, hy - 1, hr + 1, Math.PI, Math.PI * 2); g.fill(); }
  // face
  if (!back) { g.fillStyle = '#1a1a1a'; g.fillRect(2.5, hy - 1.5, 1.8, 2.4); if (race === 'mossling') g.fillRect(-1.5, hy - 1.5, 1.8, 2.4); }
  // arm + weapon
  g.fillStyle = skin; g.fillRect(4, -21, 3.5, 9);
  if (!back) weaponSprite(g, u);
  if (u.u.eq.o && !back) { g.fillStyle = '#8a6a3a'; g.beginPath(); g.ellipse(-7, -16, 4, 6, 0, 0, 7); g.fill(); g.strokeStyle = '#d8c070'; g.lineWidth = 1; g.stroke(); }
  g.restore();
}
function hairCol(u) { const c = ['#3a2a1a', '#7a4a2a', '#c09050', '#2a2a2a', '#a04030']; return c[(u.id.charCodeAt(1) || 0) % c.length]; }
function weaponSprite(g, u) {
  const wt = u.s.wt;
  g.save(); g.translate(6, -13);
  g.lineCap = 'round';
  if (wt === 'bow' || wt === 'greatbow') { g.strokeStyle = '#8a5a2a'; g.lineWidth = 2; g.beginPath(); g.arc(2, -4, wt === 'bow' ? 9 : 12, -1.3, 1.3); g.stroke(); g.strokeStyle = '#ddd'; g.lineWidth = .7; g.beginPath(); g.moveTo(2 + 9 * Math.cos(-1.3), -4 + 9 * Math.sin(-1.3)); g.lineTo(2 + 9 * Math.cos(1.3), -4 + 9 * Math.sin(1.3)); g.stroke(); }
  else if (wt === 'gun') { g.fillStyle = '#4a3a2a'; g.fillRect(0, -3, 14, 3.5); g.fillStyle = '#888'; g.fillRect(8, -3.5, 9, 2); }
  else if (wt === 'staff' || wt === 'rod') { g.strokeStyle = wt === 'staff' ? '#8a6a3a' : '#5a4a6a'; g.lineWidth = 2; g.beginPath(); g.moveTo(0, 8); g.lineTo(3, -18); g.stroke(); g.fillStyle = wt === 'staff' ? '#e0f0ff' : '#ff9a5a'; g.beginPath(); g.arc(3, -19, 3, 0, 7); g.fill(); }
  else if (wt === 'spear') { g.strokeStyle = '#7a5a3a'; g.lineWidth = 2; g.beginPath(); g.moveTo(-4, 6); g.lineTo(8, -22); g.stroke(); g.fillStyle = '#ccd'; g.beginPath(); g.moveTo(8, -22); g.lineTo(11, -29); g.lineTo(6, -24); g.fill(); }
  else if (wt === 'instrument') { g.fillStyle = '#c8a050'; g.beginPath(); g.ellipse(3, -3, 4, 5, .4, 0, 7); g.fill(); }
  else if (wt === 'mace') { g.strokeStyle = '#7a5a3a'; g.lineWidth = 2; g.beginPath(); g.moveTo(0, 2); g.lineTo(4, -12); g.stroke(); g.fillStyle = '#aab'; g.beginPath(); g.arc(4, -13, 3.5, 0, 7); g.fill(); }
  else if (wt === 'fist') { g.fillStyle = '#aa8a5a'; g.beginPath(); g.arc(2, 0, 3, 0, 7); g.fill(); }
  else {
    const len = wt === 'greatsword' ? 22 : wt === 'knife' ? 9 : wt === 'rapier' ? 18 : 15;
    g.strokeStyle = '#dfe4ea'; g.lineWidth = wt === 'greatsword' ? 3.5 : wt === 'rapier' ? 1.3 : 2.5;
    g.beginPath(); g.moveTo(1, 0); g.lineTo(5, -len); g.stroke();
    g.strokeStyle = '#c0a050'; g.lineWidth = 2; g.beginPath(); g.moveTo(-2, -1); g.lineTo(4, 1); g.stroke();
    const it = u.u.eq && u.u.eq.w && ITEMS[u.u.eq.w];
    if (it && it.el) { g.strokeStyle = ELEMENTS[it.el]; g.globalAlpha = .5; g.lineWidth = 4; g.beginPath(); g.moveTo(2, -3); g.lineTo(5, -len); g.stroke(); }
  }
  g.restore();
}
function monsterSprite(g, u, back) {
  const m = MONSTERS[u.mon], c = m.col, d = shade(c, -.3), l = shade(c, .25);
  const wob = Math.sin(V.t / 250 + u.x) * 1;
  switch (m.shape) {
    case 'goblin':
      g.fillStyle = '#3a3028'; g.fillRect(-4, -8, 3, 8); g.fillRect(1, -8, 3, 8);
      g.fillStyle = '#6a4a30'; rr(g, -6, -19, 12, 12, 3); g.fill();
      g.fillStyle = c; g.beginPath(); g.arc(0, -24, 7, 0, 7); g.fill();
      g.beginPath(); g.moveTo(-5, -26); g.lineTo(-14, -30); g.lineTo(-5, -22); g.fill(); g.beginPath(); g.moveTo(5, -26); g.lineTo(13, -31); g.lineTo(5, -22); g.fill();
      if (!back) { g.fillStyle = '#ffde5a'; g.fillRect(2, -26, 2, 2); }
      g.strokeStyle = '#8a7a6a'; g.lineWidth = 2.5; g.beginPath(); g.moveTo(6, -12); g.lineTo(10, -22); g.stroke();
      break;
    case 'wolf':
      g.fillStyle = d; g.fillRect(-10, -9, 3, 9); g.fillRect(6, -9, 3, 9);
      g.fillStyle = c; g.beginPath(); g.ellipse(-1, -12, 13, 6, 0, 0, 7); g.fill();
      g.beginPath(); g.moveTo(-12, -13); g.lineTo(-19, -18 + wob); g.lineTo(-13, -10); g.fill();
      g.beginPath(); g.ellipse(12, -17, 6, 5, -.3, 0, 7); g.fill();
      g.beginPath(); g.moveTo(16, -17); g.lineTo(21, -15); g.lineTo(16, -14); g.fill();
      g.beginPath(); g.moveTo(9, -21); g.lineTo(10, -27); g.lineTo(13, -21); g.fill();
      if (!back) { g.fillStyle = '#ff5a3a'; g.fillRect(14, -19, 2, 2); }
      break;
    case 'ooze':
      g.fillStyle = c; g.globalAlpha *= .9;
      g.beginPath(); g.moveTo(-13, 0); g.quadraticCurveTo(-13 - wob, -20, 0, -21 + wob); g.quadraticCurveTo(13 + wob, -20, 13, 0); g.closePath(); g.fill();
      g.fillStyle = l; g.beginPath(); g.ellipse(-4, -14, 3, 5, -.4, 0, 7); g.fill();
      if (!back) { g.fillStyle = '#1a2a2a'; g.fillRect(2, -12, 2.5, 3.5); g.fillRect(7, -12, 2.5, 3.5); }
      break;
    case 'bug':
      g.fillStyle = d; for (let i = -1; i <= 1; i++) { g.fillRect(i * 7 - 1, -6, 2, 6); }
      g.fillStyle = c; g.beginPath(); g.ellipse(-2, -9, 14, 7, 0, 0, 7); g.fill();
      g.fillStyle = l; g.beginPath(); g.ellipse(-4, -12, 8, 3, 0, 0, 7); g.fill();
      g.fillStyle = c; g.beginPath(); g.arc(12, -10, 5, 0, 7); g.fill();
      g.strokeStyle = d; g.lineWidth = 2; g.beginPath(); g.moveTo(15, -12); g.quadraticCurveTo(22, -14 + wob, 20, -8); g.moveTo(15, -8); g.quadraticCurveTo(22, -6 - wob, 20, -3); g.stroke();
      break;
    case 'hag':
      g.fillStyle = '#2a2a24'; g.beginPath(); g.moveTo(-9, 0); g.lineTo(9, 0); g.lineTo(5, -26); g.lineTo(-5, -26); g.closePath(); g.fill();
      g.fillStyle = c; g.beginPath(); g.moveTo(-10, 0); g.lineTo(10, 0); g.lineTo(4, -22); g.lineTo(-6, -22); g.closePath(); g.fill();
      g.fillStyle = '#a0b090'; g.beginPath(); g.arc(1, -29, 6, 0, 7); g.fill();
      if (!back) { g.beginPath(); g.moveTo(6, -29); g.lineTo(11, -26); g.lineTo(6, -27); g.fill(); g.fillStyle = '#ffd040'; g.fillRect(3, -31, 2, 2); }
      g.fillStyle = '#1e1e1a'; g.beginPath(); g.moveTo(-10, -32); g.lineTo(11, -32); g.lineTo(-2, -48 + wob); g.closePath(); g.fill();
      g.strokeStyle = '#6a5a3a'; g.lineWidth = 2; g.beginPath(); g.moveTo(10, 0); g.lineTo(12, -30); g.stroke();
      g.fillStyle = '#7ef08a'; g.globalAlpha *= .8; g.beginPath(); g.arc(12, -32, 3 + wob * .5, 0, 7); g.fill();
      break;
  }
}

// ---------- Effects / floating numbers ----------
function floatText(u, text, col) {
  V.floats.push({ u, x: u.vx, y: u.vy, h: u.vh, text, col, t0: performance.now() });
}
function burst(x, y, col, kind) { const t = tileAt(V.B, x, y); V.fx.push({ x, y, h: t ? t.h : 0, col, kind, t0: performance.now() }); }
function drawFx() {
  const g = V.g, now = performance.now(), s = V.scale;
  V.fx = V.fx.filter(f => now - f.t0 < 600);
  for (const f of V.fx) {
    const p = (now - f.t0) / 600, [cx, cy] = iso(f.x, f.y, f.h);
    g.globalAlpha = 1 - p;
    g.strokeStyle = f.col; g.lineWidth = 3 * s;
    g.beginPath(); g.ellipse(cx, cy - 12 * s, (6 + p * 20) * s, (3 + p * 10) * s, 0, 0, 7); g.stroke();
    if (f.kind === 'mag') for (let i = 0; i < 6; i++) {
      const a = i / 6 * 6.28 + p * 3;
      g.fillStyle = f.col; g.beginPath(); g.arc(cx + Math.cos(a) * 14 * s * p, cy - 14 * s - p * 22 * s + Math.sin(a) * 6 * s, 2.5 * s, 0, 7); g.fill();
    }
    g.globalAlpha = 1;
  }
  V.floats = V.floats.filter(f => now - f.t0 < 1100);
  g.textAlign = 'center'; g.font = '700 ' + Math.round(15 * Math.max(.8, s)) + 'px ui-rounded, system-ui, sans-serif';
  for (const f of V.floats) {
    const p = (now - f.t0) / 1100, [cx, cy] = iso(f.x, f.y, f.h);
    const y = cy - 44 * s - p * 26;
    g.globalAlpha = p < .8 ? 1 : (1 - p) * 5;
    g.lineWidth = 3; g.strokeStyle = 'rgba(0,0,0,.8)'; g.strokeText(f.text, cx, y);
    g.fillStyle = f.col; g.fillText(f.text, cx, y);
    g.globalAlpha = 1;
  }
}

// ---------- Picking ----------
function inPoly(px, py, pts) {
  let c = false;
  for (let i = 0, j = pts.length - 2; i < pts.length; j = i, i += 2) {
    const xi = pts[i], yi = pts[i + 1], xj = pts[j], yj = pts[j + 1];
    if ((yi > py) !== (yj > py) && px < (xj - xi) * (py - yi) / (yj - yi) + xi) c = !c;
  }
  return c;
}
function pickTile(px, py) {
  // Units first (their sprites stand above tiles), front-most first.
  const s = V.scale;
  let hit = null, best = -1;
  for (const u of V.B.units) {
    if (u.jailed) continue;
    const [cx, cy] = iso(u.vx, u.vy, u.vh);
    if (Math.abs(px - cx) < 11 * s && py < cy + 4 * s && py > cy - 40 * s) {
      const [rx, ry] = rotXY(u.x, u.y);
      if (rx + ry > best) { best = rx + ry; hit = [u.x, u.y]; }
    }
  }
  if (hit) return hit;
  for (let i = V.polys.length - 1; i >= 0; i--) if (inPoly(px, py, V.polys[i].pts)) return [V.polys[i].x, V.polys[i].y];
  return null;
}
