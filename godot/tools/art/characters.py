"""Character sprites: cuts the seven character sheets into frames, picks the animation
frames listed in PICKS, aligns every frame to the same feet point and scale, and writes

    assets/characters/<name>/<anim>_<n>.png     frames on one shared canvas per character
    assets/characters/<name>/portrait.png       a head crop
    assets/characters/meta.json                 canvas size, feet anchor, animations

Two sheet layouts exist:

  TEMPLATE (knight, brute, gunman, dino, wolf): WALK 3 rows x 8, READY 3 rows x 4 (+2 rows x 8),
  HIT 3 rows x 4, STAND 2 rows x 8, ATTACK 2 rows, CAST 2 rows, HIT row, KO row.
  Odd columns of the second WALK row are back views; STAND columns 6-7 are back views.

  WIDE (hero, cardmage): a left half (WALK 4 rows x 9, STAND rows) and a right half
  (READY rows, ATTACK, CAST, HIT, KO) with the labels sitting on top of some sprites.

Frames are addressed like "walk.1.3" (section, row, column) for TEMPLATE sheets and
"L2.6" / "R5.3" (half, row, column) for WIDE sheets.
"""
import json
import os
import sys

import numpy as np
import scipy.ndimage as nd
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from sheet_cut import bg_of, dist, load, matte, runs, section_frames, trim  # noqa: E402

BODY_H = 136   # idle frame height after scaling (the game draws sprites at half size)
PORTRAIT = 96
# per character: (animation, frame index to crop, head crop size as a fraction of height, downward shift as a fraction of height)
PORTRAIT_CFG = {'wolf': ('ready_f', 0, .85, .0), 'dino': ('idle_f', 0, .62, 0), 'brute': ('idle_f', 0, .62, 0), 'gunman': ('idle_f', 0, .56, .05), 'knight': ('idle_f', 0, .5, .03)}

# ---------- TEMPLATE sheets ----------
# section: (x0, y0, x1, y1, expected frames per row or 0)
SECTIONS = {
    'walk': (0, 60, 1200, 560, 8), 'ready': (1200, 60, 1800, 560, 4), 'hit_top': (1800, 60, 2400, 560, 4),
    'ready_mid': (0, 570, 1200, 920, 8), 'stand': (1200, 570, 2400, 920, 8), 'attack': (0, 960, 2400, 1400, 0),
    'cast': (0, 1400, 1200, 1790, 0), 'hit': (1200, 1400, 2400, 1640, 0), 'ko': (1200, 1640, 2400, 1790, 0),
}
TEMPLATE_LABELS = [(16, 8, 152, 56), (1208, 8, 1372, 56), (1820, 8, 1976, 56), (22, 544, 180, 589), (1210, 544, 1400, 589),
                   (22, 910, 212, 958), (22, 1384, 150, 1432), (1220, 1384, 1310, 1432), (1220, 1616, 1290, 1664)]

# ---------- WIDE sheets ----------
WIDE_SPLIT = {'hero': 1230, 'cardmage': 1180}
WIDE_LABELS = {
    'hero': [(1308, 28, 1478, 68), (1782, 28, 1955, 68), (34, 29, 177, 68), (1302, 836, 1517, 886), (34, 843, 203, 882),
             (1316, 1480, 1411, 1530), (1829, 1480, 1896, 1520), (1308, 1268, 1469, 1327)],
    'cardmage': [(34, 28, 177, 70), (1243, 28, 1414, 70), (1697, 28, 1867, 70), (1238, 903, 1448, 944), (34, 908, 203, 948),
                 (1251, 1571, 1343, 1613), (1737, 1571, 1802, 1613), (1243, 1352, 1399, 1412)],
}

# ---------- picks ----------
# Every animation: frames (in order), fps, loop, and which way the art natively faces on screen.
# "left"/"right" is the way the sprite looks; the game mirrors it when the unit faces the other way.
T_PICKS = {
    'idle_f': (['ready.0.0', 'ready.0.2', 'ready.1.0', 'ready.1.2'], 3, True, 'left'),
    'idle_b': (['hit_top.2.0', 'hit_top.2.1'], 2, True, 'left'),
    'ready_f': (['stand.0.2', 'stand.0.3', 'stand.0.4', 'stand.0.3'], 4, True, 'left'),
    'ready_b': (['stand.0.7', 'stand.1.7'], 3, True, 'left'),
    'walk_f': (['walk.0.0', 'walk.0.2', 'walk.0.4', 'walk.0.6'], 8, True, 'left'),
    'walk_b': (['walk.1.1', 'walk.1.3', 'walk.1.5', 'walk.1.7'], 8, True, 'left'),
    'attack': (['attack.0.1', 'attack.0.2', 'attack.0.3', 'attack.0.4', 'attack.0.1'], 9, False, 'right'),
    'cast': (['cast.0.1', 'cast.0.2', 'cast.0.3', 'cast.0.4', 'cast.0.5', 'cast.0.6'], 7, False, 'left'),
    'hit_f': (['hit.0.1', 'hit.0.2'], 6, False, 'left'),
    'hit_b': (['hit_top.0.2', 'hit_top.0.3'], 6, False, 'left'),
    'victory': (['cast.0.1', 'cast.0.2'], 3, True, 'left'),
    'ko': (['ko.0.0', 'ko.0.1', 'ko.0.2'], 4, False, 'right'),
}
PICKS = {
    'knight': dict(T_PICKS),
    'brute': dict(T_PICKS),
    'gunman': dict(T_PICKS, ko=(['ko.0.0', 'ko.0.1', 'ko.0.2'], 4, False, 'right')),
    'dino': dict(T_PICKS, ko=(['ko.0.0', 'ko.0.1', 'ko.0.2'], 4, False, 'left')),
    'wolf': dict(T_PICKS),
    'hero': {
        'idle_f': (['R0.1', 'R0.2', 'R0.3', 'R0.4'], 3, True, 'left'),
        'idle_b': (['L6.3', 'L6.4'], 2, True, 'left'),
        'ready_f': (['L4.2', 'L4.3', 'L4.4', 'L4.3'], 4, True, 'left'),
        'ready_b': (['L6.4', 'L6.5'], 3, True, 'left'),
        'walk_f': (['L1.0', 'L1.2', 'L1.4', 'L1.6'], 8, True, 'left'),
        'walk_b': (['L2.6', 'L2.7', 'L3.6', 'L3.7'], 8, True, 'left'),
        'attack': (['L4.4', 'L5.2', 'R5.1', 'R5.2', 'L4.4'], 9, False, 'right'),
        'cast': (['R6.1', 'R6.2', 'R6.3', 'R6.6'], 7, False, 'left'),
        'hit_f': (['R7.1', 'R7.2'], 6, False, 'left'),
        'hit_b': (['L6.5', 'L6.5'], 6, False, 'left'),
        'victory': (['R6.5', 'R6.6'], 3, True, 'left'),
        'ko': (['R7.3', 'R7.4', 'R7.5'], 4, False, 'left'),
    },
    'cardmage': {
        'idle_f': (['R0.1', 'R0.2', 'R0.3', 'R0.4'], 3, True, 'left'),
        'idle_b': (['L3.6', 'L3.7'], 2, True, 'left'),
        'ready_f': (['L4.1', 'L4.2', 'L4.3', 'L4.4'], 4, True, 'left'),
        'ready_b': (['L6.3', 'L6.4'], 3, True, 'left'),
        'walk_f': (['L0.1', 'L0.3', 'L0.5', 'L0.7'], 8, True, 'left'),
        'walk_b': (['L2.6', 'L2.7', 'L3.6', 'L3.7'], 8, True, 'left'),
        'attack': (['R4.2', 'R5.2', 'R5.3', 'R4.5'], 9, False, 'right'),
        'cast': (['R6.1', 'R6.2', 'R6.3', 'R6.4', 'R6.6'], 7, False, 'left'),
        'hit_f': (['R7.1', 'R7.2'], 6, False, 'left'),
        'hit_b': (['L6.4', 'L6.4'], 6, False, 'left'),
        'victory': (['R6.5', 'R6.6'], 3, True, 'left'),
        'ko': (['R7.3', 'R7.4', 'R7.5'], 4, False, 'left'),
    },
}


# ---------- cutting ----------
def _split_merged(row, expected):
    """Split the widest boxes until the row has the expected number of frames."""
    row = list(row)
    while expected and len(row) < expected:
        w = [b[2] - b[0] for b in row]
        i = int(np.argmax(w))
        b = row[i]
        m = (b[0] + b[2]) // 2
        row[i:i + 1] = [(b[0], b[1], m, b[3]), (m, b[1], b[2], b[3])]
    return row


def cut_template(path):
    """{section: [[RGBA frame, ...] per row]}"""
    im, a = load(path)
    bg = bg_of(a)
    for (x0, y0, x1, y1) in TEMPLATE_LABELS:
        a[y0:y1, x0:x1] = bg
    out = {}
    for k, (x0, y0, x1, y1, exp) in SECTIONS.items():
        rows = [_split_merged(r, exp) for r in section_frames(a, bg, (x0, y0, x1, y1))]
        out[k] = [[trim(matte(a, b)) for b in r] for r in rows]
    return out


def cut_wide(name, path, col_gap=3):
    """{'L': [[frame]], 'R': [[frame]]}"""
    im, a = load(path)
    bg = bg_of(a)
    labels = WIDE_LABELS[name]
    H, W = a.shape[:2]
    out = {}
    for side, (x0, x1) in {'L': (0, WIDE_SPLIT[name]), 'R': (WIDE_SPLIT[name], W)}.items():
        sub = dist(a[:, x0:x1], bg) > 58
        for (lx0, ly0, lx1, ly1) in labels:
            sub[max(0, ly0 - 6):ly1 + 6, max(0, lx0 - 6 - x0):max(0, lx1 + 6 - x0)] = False
        sub = nd.binary_opening(sub, structure=np.ones((2, 2)))
        rows = []
        for (ry0, ry1) in runs(sub.sum(1) > 6, gap=4, minlen=30):
            band = sub[ry0:ry1]
            cols = runs(band.sum(0) > 1, gap=col_gap, minlen=6)
            changed = True
            while changed and len(cols) > 1:  # merge slivers into the nearest neighbour
                changed = False
                for i, (c0, c1) in enumerate(cols):
                    if c1 - c0 < 26:
                        j = i - 1 if (i > 0 and (i == len(cols) - 1 or c0 - cols[i - 1][1] <= cols[i + 1][0] - c1)) else i + 1
                        a0, a1 = cols[j]
                        cols[j] = (min(a0, c0), max(a1, c1))
                        del cols[i]
                        changed = True
                        break
            row = []
            for (cx0, cx1) in cols:
                ys = np.nonzero(band[:, cx0:cx1].any(1))[0]
                row.append((x0 + cx0, ry0 + int(ys.min()), x0 + cx1, ry0 + int(ys.max()) + 1))
            rows.append(row)
        a2 = a.copy()
        for (lx0, ly0, lx1, ly1) in labels:
            a2[ly0 - 6:ly1 + 6, lx0 - 6:lx1 + 6] = bg
        out[side] = [[trim(matte(a2, b)) for b in r] for r in rows]
    return out


def frame_at(cut, ref):
    parts = ref.split('.')
    if len(parts) == 3:
        return cut[parts[0]][int(parts[1])][int(parts[2])]
    return cut[ref[0]][int(ref[1:].split('.')[0])][int(ref.split('.')[1])]


# ---------- alignment ----------
def feet_anchor(img):
    """(x, y) of the feet: the bottom of the solid pixels, x from the lowest rows."""
    a = np.asarray(img)[..., 3] > 150
    ys, xs = np.nonzero(a)
    y1, y0 = ys.max(), ys.min()
    band = ys > y1 - max(4, (y1 - y0) * .08)
    return float(np.median(xs[band])), float(y1)


def scale_rgba(img, s):
    return img.convert('RGBa').resize((max(1, round(img.width * s)), max(1, round(img.height * s))), Image.LANCZOS).convert('RGBA')


def build_character(name, cut, out_root, picks):
    chosen = {}
    for anim, (refs, fps, loop, native) in picks.items():
        chosen[anim] = [frame_at(cut, r) for r in refs]
    s = BODY_H / chosen['idle_f'][0].height
    scaled, anchors = {}, {}
    for anim, frames in chosen.items():
        scaled[anim] = [scale_rgba(f, s) for f in frames]
        anchors[anim] = [feet_anchor(f) for f in scaled[anim]]
    allf = [(f, a) for anim in scaled for f, a in zip(scaled[anim], anchors[anim])]
    left = max(a[0] for f, a in allf)
    right = max(f.width - a[0] for f, a in allf)
    up = max(a[1] for f, a in allf)
    down = max(f.height - a[1] for f, a in allf)
    half = int(np.ceil(max(left, right))) + 2
    W, H = half * 2, int(np.ceil(up + down)) + 4
    ax, ay = half, int(np.ceil(up)) + 2
    d = os.path.join(out_root, 'characters', name)
    os.makedirs(d, exist_ok=True)
    for old in os.listdir(d):
        os.remove(os.path.join(d, old))
    anims = {}
    for anim, (refs, fps, loop, native) in picks.items():
        names = []
        for i, (f, a) in enumerate(zip(scaled[anim], anchors[anim])):
            canvas = Image.new('RGBA', (W, H), (0, 0, 0, 0))
            canvas.alpha_composite(f, (round(ax - a[0]), round(ay - a[1])))
            fn = f'{anim}_{i}.png'
            canvas.save(os.path.join(d, fn), optimize=True)
            names.append(fn)
        anims[anim] = {'frames': names, 'fps': fps, 'loop': loop, 'native': native}
    # portrait: the head of the first idle frame
    panim, pidx, pfrac, pshift = PORTRAIT_CFG.get(name, ('idle_f', 0, .46, 0))
    idle = chosen[panim][pidx]
    al = np.asarray(idle)[..., 3] > 128
    top = int(np.nonzero(al.any(1))[0].min())
    h = idle.height
    ys, xs = np.nonzero(al[top + int(h * .03): top + int(h * .30)])
    cx = float(np.median(xs))
    side = int(h * pfrac)
    cy = top + side * .5 - h * .01 + h * pshift
    box = (int(cx - side / 2), int(cy - side / 2), int(cx + side / 2), int(cy + side / 2))
    port = Image.new('RGBA', (side, side), (0, 0, 0, 0))
    port.alpha_composite(idle.crop(box))
    scale_rgba(port, PORTRAIT / side).save(os.path.join(d, 'portrait.png'), optimize=True)
    print(f'{name}: canvas {W}x{H}, feet {ax},{ay}, {sum(len(v["frames"]) for v in anims.values())} frames')
    return {'size': [W, H], 'anchor': [ax, ay], 'anims': anims}


def build_all(src_root, out_root):
    meta = {}
    for name in PICKS:
        path = os.path.join(src_root, 'characters', name + '.jpg')
        cut = cut_wide(name, path) if name in WIDE_SPLIT else cut_template(path)
        meta[name] = build_character(name, cut, out_root, PICKS[name])
    with open(os.path.join(out_root, 'characters', 'meta.json'), 'w') as f:
        json.dump(meta, f, indent=1)
    return meta
