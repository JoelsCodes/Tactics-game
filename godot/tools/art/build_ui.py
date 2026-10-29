#!/usr/bin/env python3
"""Builds the UI art in godot/assets/ui/ (procedural: no source images needed).

  python3 godot/tools/art/build_ui.py        (needs Pillow, numpy and scipy)

What it makes (all RGBA PNGs unless noted; nine-slice margins are what scripts/ui/hud/hud_style.gd uses):
  panel_stone.png   240x240, margin 40   slate-stone frame, bronze rim, gold inner trim, corner studs and
                                         brackets, translucent glass center ("glassmorphic" backing)
  panel_wood.png    240x240, margin 40   the same with a dark walnut frame (mitered corners)
  button_*.png      64x64, margin 20     normal / hover / pressed / disabled: bronze-trimmed plates
  bar_back.png      64x20, margin 8      inset frame for HP / SP / XP bars
  bar_fill.png      32x20, margin 6      white glossy fill, tinted per bar in code
  portrait_frame.png 96x96, margin 14    neutral gold bevel ring, tinted per side in code
  divider.png       320x16               ornate rule with a center diamond
  menu_bg.jpg       1280x720             moody backdrop for the menu screens
  slim_panel.png    96x96, margin 16     the battle HUD's sleek panel: smoky dark-brown glass, bronze edge,
                                         gold hairline, small corner diamonds
  plaque.png        120x40, margin 34    a title plaque: dark bar, gold hairlines, diamond end caps
  turn_banner.png   240x64               an arrow-shaped plate for "TURN n"
  fade_panel.png    320x72               a dark strip fading out to the right (Objectives)
  queue_card*.png   64x64, margin 10     a turn-queue card: normal (bronze edge) / now (cyan edge, glow)
  queue_arrow_*.png 28x72                gold chevron caps at the ends of the turn queue
  slot_*.png        64x64, margin 14     slim command buttons: normal / hover / pressed / disabled /
                                         primary (the gold-framed ATTACK)
  icon_*.png        48x48                command icons (attack, abilities, items, defend, summon, wait, move), white
                                         with a dark outline, tinted in code

The edge pieces of the panels are periodic (period 160 px = the stretched middle section), so tiling or
stretching the nine-slice shows no seams. Change the palette or the sizes here and re-run; then
`godot --headless --path godot --import`.
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'assets', 'ui')

GOLD = {'hi': (255, 232, 160), 'mid': (224, 180, 88), 'lo': (138, 96, 36)}
BRONZE = {'hi': (190, 134, 80), 'mid': (128, 86, 50), 'lo': (62, 38, 24)}
LINE_DARK = (14, 10, 9)
GLASS = (9, 12, 24)

PERIOD = 160  # the stretched middle of the panel edges


def rng(seed):
    return np.random.default_rng(seed)


def periodic_noise(shape, sigma, seed):
    """Noise in 0..1 that wraps around on both axes (so it tiles without a seam)."""
    n = gaussian_filter(rng(seed).standard_normal(shape), sigma=sigma, mode='wrap')
    n = (n - n.min()) / max(n.max() - n.min(), 1e-6)
    return n


def lerp(a, b, t):
    t = np.clip(t, 0, 1)[..., None]
    return np.asarray(a, np.float32) * (1 - t) + np.asarray(b, np.float32) * t


def ramp(t, lo, mid, hi):
    """A three-stop color ramp over t in 0..1 (array)."""
    t = np.clip(t, 0, 1)
    low = lerp(lo, mid, t * 2)
    high = lerp(mid, hi, t * 2 - 1)
    return np.where((t < .5)[..., None], low, high)


def rounded_sdf(w, h, r):
    """Distance inside a rounded rectangle (positive inside, 0 on the edge), per pixel center."""
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    xs += .5
    ys += .5
    cx = np.minimum(xs, w - xs)
    cy = np.minimum(ys, h - ys)
    inside = np.minimum(cx, cy)
    corner = (cx < r) & (cy < r)
    d = np.where(corner, r - np.hypot(r - cx, r - cy), inside)
    return d


def over(dst, src_rgb, src_a):
    """Composite src over dst (both float, dst RGBA premultiplied-free)."""
    a = np.clip(src_a, 0, 1)[..., None]
    da = dst[..., 3:4]
    out_a = a + da * (1 - a)
    rgb = (np.asarray(src_rgb, np.float32) * a + dst[..., :3] * da * (1 - a)) / np.maximum(out_a, 1e-5)
    return np.concatenate([rgb, out_a], axis=-1)


def band_alpha(d, lo, hi, soft=.8):
    """1 where lo <= d < hi with soft (anti-aliased) edges."""
    return np.clip(d - lo + .5 * soft, 0, soft) / soft * np.clip(hi - d + .5 * soft, 0, soft) / soft


def save(arr, name, fmt='PNG', **kw):
    os.makedirs(OUT, exist_ok=True)
    img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), 'RGBA' if arr.shape[-1] == 4 else 'RGB')
    img.save(os.path.join(OUT, name), fmt, **kw)
    print('wrote', name, img.size)


# ---------- panels ----------

def stone_band(w, h, seed=1):
    """Slate stone with faint veins; periodic every PERIOD px on both axes."""
    big = periodic_noise((PERIOD, PERIOD), 3.0, seed)
    fine = periodic_noise((PERIOD, PERIOD), 0.9, seed + 1)
    vein = np.abs(periodic_noise((PERIOD, PERIOD), 6.0, seed + 2) - .5) < .018
    ys, xs = np.mgrid[0:h, 0:w]
    n1 = big[ys % PERIOD, xs % PERIOD]
    n2 = fine[ys % PERIOD, xs % PERIOD]
    v = vein[ys % PERIOD, xs % PERIOD]
    base = np.asarray((40, 45, 60), np.float32)
    col = base[None, None, :] * (0.78 + 0.5 * n1[..., None]) * (0.92 + 0.16 * n2[..., None])
    col = np.where(v[..., None], col * 1.5 + 8, col)
    return col


def wood_band(w, h, seed=7):
    """Dark walnut: grain runs along each edge, mitered at the corners (with a joint line)."""
    along = periodic_noise((PERIOD, 64), (28, 0.8), seed)  # streaks along u (first axis)
    knots = periodic_noise((PERIOD, 64), (6, 6), seed + 3)
    ys, xs = np.mgrid[0:h, 0:w]
    dt, dl, dr, db = ys, xs, w - 1 - xs, h - 1 - ys
    d = np.minimum(np.minimum(dt, db), np.minimum(dl, dr))
    horizontal = np.minimum(dt, db) <= np.minimum(dl, dr)
    u = np.where(horizontal, xs, ys) % PERIOD
    v = np.where(horizontal, np.minimum(dt, db), np.minimum(dl, dr)) % 64
    g = along[u, v]
    k = knots[u, v]
    base = np.asarray((50, 33, 24), np.float32)
    col = base[None, None, :] * (0.62 + 0.9 * g[..., None]) * (0.92 + 0.2 * k[..., None])
    # fine growth lines
    lines = (np.sin((v + g * 9.0) * 1.9) * .5 + .5) ** 3
    col = col * (0.9 + 0.2 * lines[..., None])
    # mitered joint along the corner diagonals
    diag = np.abs(np.where(horizontal, 0, 0) + 0)  # placeholder to keep shapes explicit
    miter_tl = np.abs(xs - ys) <= 0
    seam = (np.abs(np.minimum(dt, db) - np.minimum(dl, dr)) <= 0.6) & (d < 24)
    col = np.where(seam[..., None], col * 0.45, col)
    return col


def panel(kind, size=240, margin=40, radius=11):
    w = h = size
    d = rounded_sdf(w, h, radius)
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    diag = (xs + ys) / (w + h)  # 0 top-left .. 1 bottom-right
    band = stone_band(w, h) if kind == 'stone' else wood_band(w, h)
    img = np.zeros((h, w, 4), np.float32)

    # 1. everything inside the outer edge starts as the band material
    inside = np.clip(d + .5, 0, 1)
    img[..., :3] = band
    img[..., 3] = inside

    # bevel on the band: lit from the top-left
    edge_dist = d
    bevel_hi = band_alpha(edge_dist, 5.2, 8.0, 2.5)
    bevel_lo = band_alpha(edge_dist, 14.0, 17.2, 2.5)
    light = np.clip(1.0 - diag * 1.6, -1, 1)[..., None]
    img[..., :3] = img[..., :3] * (1 + 0.28 * bevel_hi[..., None] * light) * (1 - 0.30 * bevel_lo[..., None] * np.clip(-light + .4, 0, 1))

    # 2. dark outline, bronze rim
    img = over(img, LINE_DARK, band_alpha(d, 0, 1.6))
    rim = ramp(1 - diag * 1.15, BRONZE['lo'], BRONZE['mid'], BRONZE['hi'])
    img = over(img, rim, band_alpha(d, 1.6, 4.8))
    img = over(img, (20, 14, 10), band_alpha(d, 4.8, 5.8) * .6)

    # 3. groove, gold trim, thin shadow line
    img = over(img, (10, 8, 8), band_alpha(d, 17.0, 18.6) * .85)
    gold = ramp(1 - diag * 1.25, GOLD['lo'], GOLD['mid'], GOLD['hi'])
    img = over(img, gold, band_alpha(d, 18.6, 20.8))
    img = over(img, (6, 6, 10), band_alpha(d, 20.8, 22.2) * .7)

    # 4. glass center: translucent dark, a little lighter at the top, darker toward the trim
    glass_mask = np.clip(d - 21.8, 0, 1)
    grad = np.clip(ys / h, 0, 1)
    a = 0.6 + 0.12 * grad + 0.2 * np.exp(-np.clip(d - 22, 0, None) / 9.0)  # translucent: frosted in game (shaders/ui_glass)
    sheen = np.exp(-ys / 34.0) * 0.07
    glass_rgb = np.asarray(GLASS, np.float32)[None, None, :] + (np.asarray((60, 72, 110), np.float32) * sheen[..., None])
    # the glass replaces the band's alpha inside the trim so the backdrop shows through
    inner = glass_mask > 0
    new_a = np.where(inner, img[..., 3] * (1 - glass_mask) + a * glass_mask, img[..., 3])
    new_rgb = np.where(inner[..., None], img[..., :3] * (1 - glass_mask[..., None]) + glass_rgb * glass_mask[..., None], img[..., :3])
    img = np.concatenate([new_rgb, new_a[..., None]], axis=-1)

    # 5. corner ornaments: studs on the band and gold brackets inside the trim
    for (cx, cy, sx, sy) in [(13, 13, 1, 1), (w - 13, 13, -1, 1), (13, h - 13, 1, -1), (w - 13, h - 13, -1, -1)]:
        r = np.hypot(xs - cx, ys - cy)
        img = over(img, (16, 11, 8), np.clip(5.6 - r, 0, 1))
        stud = ramp(1 - np.clip((r / 4.2), 0, 1) * .9 - ((xs - cx) * sx + (ys - cy) * sy) / 14.0, GOLD['lo'], GOLD['mid'], GOLD['hi'])
        img = over(img, stud, np.clip(4.4 - r, 0, 1))
        img = over(img, (255, 244, 200), np.clip(1.5 - np.hypot(xs - cx + sx * 1.3, ys - cy + sy * 1.3), 0, 1) * .8)
    k = 24  # bracket length
    for (ox, oy, sx, sy) in [(22.5, 22.5, 1, 1), (w - 22.5, 22.5, -1, 1), (22.5, h - 22.5, 1, -1), (w - 22.5, h - 22.5, -1, -1)]:
        along_x = (np.abs(ys - oy) < 1.1) & ((xs - ox) * sx >= 0) & ((xs - ox) * sx < k)
        along_y = (np.abs(xs - ox) < 1.1) & ((ys - oy) * sy >= 0) & ((ys - oy) * sy < k)
        fade_x = 1 - np.clip(((xs - ox) * sx) / k, 0, 1)
        fade_y = 1 - np.clip(((ys - oy) * sy) / k, 0, 1)
        m = (along_x * fade_x + along_y * fade_y).astype(np.float32)
        img = over(img, GOLD['mid'], np.clip(m, 0, 1) * .9)
    return img * np.asarray([1, 1, 1, 255], np.float32) if False else np.concatenate([img[..., :3], img[..., 3:4] * 255], axis=-1)


# ---------- buttons, bars, frames ----------

def button(state, size=64, radius=9):
    w = h = size
    d = rounded_sdf(w, h, radius)
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    img = np.zeros((h, w, 4), np.float32)
    t = ys / h
    if state == 'pressed':
        plate = ramp(1 - t, (140, 96, 36), (214, 168, 82), (246, 214, 130))
        rim = (60, 40, 16)
        line = (255, 236, 176)
    else:
        top, bot = {'normal': ((58, 63, 82), (30, 33, 46)), 'hover': ((84, 92, 124), (44, 50, 72)), 'disabled': ((36, 38, 46), (24, 25, 31))}[state]
        plate = lerp(top, bot, t)
        rim = {'normal': BRONZE['mid'], 'hover': GOLD['hi'], 'disabled': (70, 56, 46)}[state]
        line = {'normal': (170, 124, 66), 'hover': GOLD['mid'], 'disabled': (62, 54, 48)}[state]
    img[..., :3] = plate
    img[..., 3] = np.clip(d + .5, 0, 1)
    img = over(img, LINE_DARK, band_alpha(d, 0, 1.4))
    rim_arr = np.broadcast_to(np.asarray(rim, np.float32), img[..., :3].shape)
    if state != 'pressed':
        rim_arr = ramp(1 - (xs + ys) / (w + h) * 1.2, np.asarray(rim) * .55, np.asarray(rim) * .85, np.asarray(rim) * 1.15)
    img = over(img, rim_arr, band_alpha(d, 1.4, 3.4))
    img = over(img, line, band_alpha(d, 4.6, 5.6) * (.55 if state != 'disabled' else .35))
    # a soft top sheen on the plate
    if state != 'disabled':
        img = over(img, (255, 255, 255), np.clip(1 - (ys - 5) / 16, 0, 1) * np.clip(d - 5, 0, 1) * (.10 if state != 'pressed' else .22))
    if state == 'hover':
        img = over(img, (255, 236, 180), np.clip(1 - np.clip(d - 5.6, 0, 9) / 9, 0, 1) * np.clip(d - 5.2, 0, 1) * .16)
    return np.concatenate([img[..., :3], img[..., 3:4] * 255], axis=-1)


def bar_back(w=64, h=20, radius=7):
    d = rounded_sdf(w, h, radius)
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    img = np.zeros((h, w, 4), np.float32)
    img[..., :3] = (6, 8, 14)
    img[..., 3] = np.clip(d + .5, 0, 1) * .92
    img = over(img, LINE_DARK, band_alpha(d, 0, 1.2))
    rim = ramp(1 - (xs + ys) / (w + h) * 1.3, BRONZE['lo'], BRONZE['mid'], GOLD['mid'])
    img = over(img, rim, band_alpha(d, 1.2, 2.8))
    img = over(img, (0, 0, 0), np.clip(1 - (ys - 3) / 7, 0, 1) * np.clip(d - 2.6, 0, 1) * .55)  # inner shadow
    return np.concatenate([img[..., :3], img[..., 3:4] * 255], axis=-1)


def bar_fill(w=32, h=20, radius=6):
    d = rounded_sdf(w, h, radius)
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    t = ys / h
    img = np.zeros((h, w, 4), np.float32)
    img[..., :3] = lerp((255, 255, 255), (150, 150, 150), t) * 1.0
    img[..., :3] = np.where((t < .38)[..., None], img[..., :3] * 1.0 + 0, img[..., :3])
    img[..., :3] += np.clip(1 - np.abs(ys - 4.5) / 2.2, 0, 1)[..., None] * 60  # gloss line near the top
    img[..., :3] *= (0.93 + 0.07 * np.sin(xs * 0.9))[..., None]  # faint segmenting
    img[..., 3] = np.clip(d + .5, 0, 1)
    return np.concatenate([np.clip(img[..., :3], 0, 255), img[..., 3:4] * 255], axis=-1)


def portrait_frame(size=96, radius=11):
    d = rounded_sdf(size, size, radius)
    ys, xs = np.mgrid[0:size, 0:size].astype(np.float32)
    diag = (xs + ys) / (2 * size)
    img = np.zeros((size, size, 4), np.float32)
    ring = ramp(1 - diag * 1.2, (150, 150, 150), (215, 215, 215), (255, 255, 255))  # neutral: tinted in code
    img[..., :3] = ring
    img[..., 3] = band_alpha(d, 0, 4.2)
    img = over(img, (0, 0, 0), band_alpha(d, 0, 1.0) * .9)
    img = over(img, (0, 0, 0), band_alpha(d, 4.2, 6.0) * .55)
    return np.concatenate([img[..., :3], img[..., 3:4] * 255], axis=-1)


def divider(w=320, h=16):
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    cx, cy = w / 2, h / 2
    line = np.exp(-np.abs(ys - cy) * 1.6) * np.clip(1 - np.abs(xs - cx) / (w / 2), 0, 1) ** 0.6
    img = np.zeros((h, w, 4), np.float32)
    img[..., :3] = lerp(GOLD['lo'], GOLD['hi'], np.clip(1 - np.abs(xs - cx) / (w / 2), 0, 1))
    img[..., 3] = line * .85
    dia = np.clip(6.5 - (np.abs(xs - cx) + np.abs(ys - cy)), 0, 1)
    img = over(img, ramp(1 - (ys - cy + 6) / 12, GOLD['lo'], GOLD['mid'], GOLD['hi']), dia)
    img = over(img, (20, 12, 8), np.clip(1.6 - np.abs(np.abs(xs - cx) + np.abs(ys - cy) - 7.5), 0, 1) * .6)
    for s in (-1, 1):
        for off in (16, 26):
            r = np.hypot(xs - (cx + s * off), ys - cy)
            img = over(img, GOLD['mid'], np.clip(1.9 - r, 0, 1) * .9)
    return np.concatenate([img[..., :3], img[..., 3:4] * 255], axis=-1)


def menu_bg(w=1280, h=720):
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    u, v = xs / w - .5, ys / h - .5
    glow = np.exp(-((u / .55) ** 2 + ((v + .08) / .6) ** 2))
    base = lerp((8, 10, 18), (30, 36, 58), glow)
    lattice = np.abs(((xs + ys) % 96) - 48) < .8
    lattice2 = np.abs(((xs - ys) % 96) - 48) < .8
    base = base * (1 + .35 * ((lattice | lattice2)[..., None] * glow[..., None]))
    n = periodic_noise((h, w), 1.2, 11)
    base = base * (0.94 + 0.12 * n[..., None])
    vig = np.clip(1 - 0.9 * (u ** 2 + v ** 2) * 1.8, 0.25, 1)
    return np.clip(base * vig[..., None], 0, 255)


def icon(kind, size=48, ss=4):
    """A command icon drawn at ss x size and scaled down: white shape, dark outline, transparent."""
    from PIL import ImageDraw, ImageFilter
    S = size * ss
    shape = Image.new('L', (S, S), 0)
    d = ImageDraw.Draw(shape)
    u = S / 48.0  # drawing units: a 48 grid

    def P(*pts):
        return [(x * u, y * u) for x, y in pts]
    if kind == 'attack':  # a sword, point up-right
        d.polygon(P((38, 6), (42, 10), (20, 32), (16, 28)), fill=255)            # blade
        d.polygon(P((11, 25), (14, 22), (26, 34), (23, 37)), fill=255)           # guard
        d.polygon(P((15, 31), (18, 34), (10, 42), (7, 39)), fill=255)            # grip
        d.ellipse(P((4, 40), (9, 45)), fill=255)                                 # pommel
    elif kind == 'abilities':  # a four-point star with a small spark
        d.polygon(P((22, 4), (26, 18), (40, 22), (26, 26), (22, 40), (18, 26), (4, 22), (18, 18)), fill=255)
        d.polygon(P((38, 30), (40, 36), (46, 38), (40, 40), (38, 46), (36, 40), (30, 38), (36, 36)), fill=255)
    elif kind == 'items':  # a potion flask
        d.rectangle(P((19, 4), (29, 8)), fill=255)                               # cork
        d.rectangle(P((20, 8), (28, 16)), fill=255)                              # neck
        d.ellipse(P((8, 14), (40, 46)), fill=255)                                # body
    elif kind == 'defend':  # a heater shield
        d.polygon(P((24, 4), (41, 9), (40, 26), (24, 44), (8, 26), (7, 9)), fill=255)
    elif kind == 'wait':  # an hourglass
        d.rectangle(P((10, 4), (38, 8)), fill=255)
        d.rectangle(P((10, 40), (38, 44)), fill=255)
        d.polygon(P((13, 8), (35, 8), (26, 24), (35, 40), (13, 40), (22, 24)), fill=255)
    elif kind == 'summon':  # a relic crystal rising from a summoning circle
        d.polygon(P((24, 2), (33, 14), (24, 34), (15, 14)), fill=255)            # crystal
        d.ellipse(P((6, 32), (42, 46)), outline=255, width=int(3 * u))           # circle
        d.ellipse(P((14, 36), (34, 42)), fill=255)
        d.polygon(P((40, 6), (42, 11), (47, 13), (42, 15), (40, 20), (38, 15), (33, 13), (38, 11)), fill=255)
    elif kind == 'move':  # four arrows from the center
        for ang in range(4):
            import math
            c, sn = math.cos(ang * math.pi / 2), math.sin(ang * math.pi / 2)
            def R(x, y):
                return (24 + (x * c - y * sn), 24 + (x * sn + y * c))
            d.polygon(P(R(20, 0), R(12, -8), R(12, -3), R(5, -3), R(5, 3), R(12, 3), R(12, 8)), fill=255)
    a = np.asarray(shape.resize((size, size), Image.LANCZOS), np.float32) / 255
    # dark outline: dilate the shape a little
    o = np.asarray(shape.filter(ImageFilter.MaxFilter(ss * 2 + 1)).resize((size, size), Image.LANCZOS), np.float32) / 255
    img = np.zeros((size, size, 4), np.float32)
    img[..., :3] = 255 * a[..., None] + 12 * (1 - a[..., None])
    img[..., 3] = np.clip(np.maximum(a, o * .85), 0, 1) * 255
    return img


# ---------- the sleek battle HUD (dark smoky glass, thin bronze and gold lines) ----------

SMOKE = (20, 16, 14)


def rect_sdf(w, h, r=3):
    return rounded_sdf(w, h, r)


def finish(img):
    return np.concatenate([img[..., :3], img[..., 3:4] * 255], axis=-1)


def diamond(img, cx, cy, r, col=GOLD['mid']):
    ys, xs = np.mgrid[0:img.shape[0], 0:img.shape[1]].astype(np.float32)
    dd = np.abs(xs + .5 - cx) + np.abs(ys + .5 - cy)
    img = over(img, (12, 9, 8), np.clip(r + 1.4 - dd, 0, 1) * .9)
    return over(img, ramp(1 - (ys - cy + r) / (2 * r + 1e-3), GOLD['lo'], GOLD['mid'], GOLD['hi']), np.clip(r - dd, 0, 1))


def slim_panel(w=96, h=96):
    d = rect_sdf(w, h, 4)
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    img = np.zeros((h, w, 4), np.float32)
    img[..., :3] = lerp((34, 27, 23), SMOKE, ys / h)
    img[..., 3] = np.clip(d + .5, 0, 1) * (.62 + .16 * np.exp(-np.clip(d - 4, 0, None) / 6))
    img = over(img, LINE_DARK, band_alpha(d, 0, 1.2) * .9)
    img = over(img, ramp(1 - (xs + ys) / (w + h) * 1.2, BRONZE['lo'], BRONZE['mid'], BRONZE['hi']), band_alpha(d, 1.2, 2.6))
    img = over(img, GOLD['mid'], band_alpha(d, 5.0, 5.9) * .45)
    for cx, cy in [(5.5, 5.5), (w - 5.5, 5.5), (5.5, h - 5.5), (w - 5.5, h - 5.5)]:
        img = diamond(img, cx, cy, 3.2)
    return finish(img)


def plaque(w=120, h=40):
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    img = np.zeros((h, w, 4), np.float32)
    cy = h / 2
    body = (np.abs(ys + .5 - cy) < 13) & (xs > 12) & (xs < w - 12)
    img[..., :3] = lerp((40, 31, 26), (16, 12, 11), np.abs(ys - cy) / 13)
    img[..., 3] = body * .88
    for yy in (cy - 13, cy + 12):
        line = (np.abs(ys + .5 - yy - .5) < .8) & (xs > 10) & (xs < w - 10)
        img = over(img, GOLD['mid'], line * .9)
    for cx in (12, w - 12):
        img = diamond(img, cx, cy, 9)
        img = diamond(img, cx, cy, 4, GOLD['hi'])
    return finish(img)


def turn_banner(w=240, h=64):
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    tip = w - 4 - np.abs(ys + .5 - h / 2) * 0.9  # the arrow point on the right
    inside = np.clip(tip - xs, 0, 1) * np.clip(ys - 3, 0, 1) * np.clip(h - 3 - ys, 0, 1)
    edge = np.clip(1.6 - np.minimum(np.abs(tip - xs), np.minimum(np.abs(ys - 3), np.abs(h - 3 - ys))), 0, 1) * (xs <= tip + 1)
    img = np.zeros((h, w, 4), np.float32)
    img[..., :3] = lerp((54, 42, 34), (22, 17, 15), ys / h)
    img[..., 3] = inside * np.clip(.3 + xs / 40, 0, .92)  # fades in from the left screen edge
    img = over(img, ramp(xs / w, GOLD['lo'], GOLD['mid'], GOLD['hi']), edge * np.clip(xs / 60, 0, 1) * .95)
    return finish(img)


def fade_panel(w=320, h=72):
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    img = np.zeros((h, w, 4), np.float32)
    fade = np.clip(1.15 - xs / w, 0, 1) ** 1.4
    img[..., :3] = lerp((40, 31, 26), (14, 11, 10), ys / h)
    img[..., 3] = fade * .82
    for yy in (1, h - 2):
        img = over(img, GOLD['mid'], (np.abs(ys - yy) < .8) * fade * .8)
    return finish(img)


def queue_card(now=False, s=64):
    d = rect_sdf(s, s, 4)
    ys, xs = np.mgrid[0:s, 0:s].astype(np.float32)
    img = np.zeros((s, s, 4), np.float32)
    img[..., :3] = lerp((38, 32, 30) if not now else (26, 46, 54), SMOKE if not now else (12, 22, 28), ys / s)
    img[..., 3] = np.clip(d + .5, 0, 1) * .86
    if now:
        img = over(img, (120, 230, 255), band_alpha(d, 0, 2.4))
        img = over(img, (200, 250, 255), band_alpha(d, 0.6, 1.4) * .9)
        img = over(img, (90, 210, 240), np.exp(-np.clip(d - 2.4, 0, None) / 4) * np.clip(d - 2.2, 0, 1) * .35)
    else:
        img = over(img, LINE_DARK, band_alpha(d, 0, 1))
        img = over(img, BRONZE['mid'], band_alpha(d, 1, 2.2))
    return finish(img)


def queue_arrow(left, w=28, h=72):
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    x = xs if not left else (w - 1 - xs)
    dist = np.abs(x - (6 + np.abs(ys + .5 - h / 2) * -0.42 + 16))
    shape = np.clip(3.2 - dist, 0, 1) * (np.abs(ys + .5 - h / 2) < 26)
    img = np.zeros((h, w, 4), np.float32)
    img[..., :3] = ramp(1 - ys / h, GOLD['lo'], GOLD['mid'], GOLD['hi'])
    img[..., 3] = shape
    return finish(img)


def slot(state, s=64):
    d = rect_sdf(s, s, 5)
    ys, xs = np.mgrid[0:s, 0:s].astype(np.float32)
    img = np.zeros((s, s, 4), np.float32)
    top, bot = {'normal': ((52, 44, 40), (24, 20, 18)), 'hover': ((78, 64, 52), (34, 28, 24)),
                'pressed': ((150, 112, 54), (92, 64, 30)), 'disabled': ((30, 27, 26), (20, 18, 17)),
                'primary': ((112, 84, 46), (52, 38, 24))}[state]
    img[..., :3] = lerp(top, bot, ys / s)
    img[..., 3] = np.clip(d + .5, 0, 1) * (.9 if state != 'disabled' else .7)
    img = over(img, LINE_DARK, band_alpha(d, 0, 1.2))
    rim = {'normal': BRONZE['mid'], 'hover': GOLD['mid'], 'pressed': GOLD['hi'], 'disabled': (64, 52, 44), 'primary': GOLD['hi']}[state]
    width = 3.4 if state == 'primary' else 2.4
    img = over(img, ramp(1 - (xs + ys) / (2 * s) * 1.2, np.asarray(rim) * .6, np.asarray(rim) * .9, np.asarray(rim) * 1.1), band_alpha(d, 1.2, width))
    img = over(img, GOLD['mid'], band_alpha(d, width + 1.6, width + 2.4) * (.5 if state != 'disabled' else .2))
    if state in ('primary', 'hover'):
        img = over(img, (255, 220, 150), np.exp(-np.clip(d - width, 0, None) / 7) * np.clip(d - width, 0, 1) * .22)
    return finish(img)


def main():
    save(panel('stone'), 'panel_stone.png')
    save(panel('wood'), 'panel_wood.png')
    for s in ('normal', 'hover', 'pressed', 'disabled'):
        save(button(s), 'button_%s.png' % s)
    save(bar_back(), 'bar_back.png')
    save(bar_fill(), 'bar_fill.png')
    save(portrait_frame(), 'portrait_frame.png')
    save(divider(), 'divider.png')
    save(menu_bg(), 'menu_bg.jpg', 'JPEG', quality=90)
    save(slim_panel(), 'slim_panel.png')
    save(plaque(), 'plaque.png')
    save(turn_banner(), 'turn_banner.png')
    save(fade_panel(), 'fade_panel.png')
    save(queue_card(False), 'queue_card.png')
    save(queue_card(True), 'queue_card_now.png')
    save(queue_arrow(True), 'queue_arrow_l.png')
    save(queue_arrow(False), 'queue_arrow_r.png')
    for st in ('normal', 'hover', 'pressed', 'disabled', 'primary'):
        save(slot(st), 'slot_%s.png' % st)
    for k in ('attack', 'abilities', 'items', 'defend', 'summon', 'wait', 'move'):
        save(icon(k), 'icon_%s.png' % k)


if __name__ == '__main__':
    main()
