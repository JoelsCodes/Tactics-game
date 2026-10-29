#!/usr/bin/env python3
"""Cuts an eight-direction character atlas (a generated reference sheet on magenta, not a uniform
grid) into aligned animation frames for the game, plus effect sprites and a portrait.

  python3 godot/tools/art/eight_dir.py            (all characters in SHEETS; needs Pillow, numpy, scipy)
  then: godot --headless --path godot --import
        godot --headless --path godot --script res://tools/build_resources.gd

Writes, per character:
    assets/characters/<name>/<anim>_<n>.png     frames on one shared canvas, feet on one anchor point
    assets/characters/<name>/fx_<effect>_<n>.png effect sprites (slash, eruption, circle, burst, smoke...)
    assets/characters/<name>/portrait.png       the first portrait of the sheet
    assets/characters/<name>/manifest.json      every frame: source rectangle, file, feet point,
                                                animation, direction, fps, loop, strike frame
    assets/characters/meta.json                 the game's entry (merged with the other characters)

How it reads the sheet (see SHEETS):
  - each labeled section is a box; its rows are found from the thin dark-magenta divider lines
  - in movement rows frames are found as runs of sprite columns (narrow bits such as dust merge into
    the nearest frame); in action rows, where sword trails bridge neighbours, by the divider lines
  - magenta is keyed out with soft, despilled edges (magenta_key.key_magenta)
  - the feet are the bottom of the dark body pixels (the coat), centred on the lowest body rows, so
    effects (dust, eruptions) do not move the anchor; frames are placed on one canvas by their feet
"""
import json
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from magenta_key import key_magenta  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
KEY_INNER, KEY_OUTER = 85.0, 175.0  ## a little harder than the default, so no magenta rim stays on the dark outlines
DIRS = ['s', 'se', 'e', 'ne', 'n', 'nw', 'w', 'sw']  # screen directions, clockwise from straight down

SHEETS = {
    'king': {
        'src': 'art_src/characters/king_sheet.webp',
        'target_body': 136,  # body height the game's other characters are cut at (drawn at half size)
        # direction blocks: (x0, y0, x1, y1), rows top to bottom are idle, walk, run, dash
        'dir_blocks': {
            's': (64, 27, 480, 278), 'se': (484, 28, 825, 278), 'e': (828, 28, 1179, 278), 'ne_sheet': (1183, 28, 1530, 278),
            'n': (64, 311, 424, 556), 'nw_sheet': (426, 311, 793, 556), 'w': (797, 311, 1163, 556), 'sw': (1167, 311, 1530, 556),
        },
        # The sheet's UP-RIGHT / UP-LEFT blocks show the face (a generation error: they are near copies of
        # down-right / down-left), so walking away from the camera would look like moonwalking. Until a
        # corrected sheet arrives, the true back view (UP) is used for both upward diagonals.
        'dir_use': {'ne': 'n', 'nw': 'n'},
        'moves': [('idle', 4, True), ('walk', 8, True), ('run', 12, True), ('dash', 14, True)],
        # action blocks: name -> (box, fps, loop, native facing, strike frame or -1)
        'actions': {
            'attack': ((6, 588, 374, 735), 12, False, 'right', 3),
            'heavy': ((379, 588, 777, 735), 10, False, 'right', 6),
            'cast': ((782, 587, 1167, 736), 8, False, 'right', 9),
            'hit': ((1172, 588, 1363, 736), 8, False, 'right', -1),
            'ko': ((1365, 588, 1530, 736), 6, False, 'right', -1),
        },
        # frames left out of an animation: the last two heavy cells are only the ground eruption (the King is
        # hidden in it); the game plays that as the 'eruption' effect on the target instead
        'drop': {'heavy': [8, 9]},
        'fx_box': (6, 765, 1226, 825),
        # effect sprites in the particle row, left to right, grouped into sequences
        'fx_groups': [('swirl', 1), ('slash', 4), ('rend', 1), ('eruption', 5), ('circle', 1), ('burst', 1), ('smoke', 4)],
        'portrait_box': (10, 857, 150, 1016),
    },
}


# ---------- the other sheets: blocks found from the magenta panels ----------

def magenta_blocks(path, min_area=2500):
    """Boxes (x0, y0, x1, y1) of the big magenta panels of a sheet, in reading order (rows of similar y, then x)."""
    from scipy import ndimage as nd
    a = np.asarray(Image.open(os.path.join(ROOT, path)).convert('RGB')).astype(int)
    mag = (a[..., 0] > 170) & (a[..., 2] > 170) & (a[..., 1] < 110)
    lab, _ = nd.label(mag)
    boxes = []
    for i, sl in enumerate(nd.find_objects(lab)):
        if (lab[sl] == i + 1).sum() > min_area:
            boxes.append([sl[1].start, sl[0].start, sl[1].stop, sl[0].stop])
    boxes.sort(key=lambda b: (b[1] // 120, b[0]))
    return boxes


def merge_row(boxes, gap=4):
    """Neighbouring boxes of one row that are split by a thin divider are one block."""
    out = []
    for b in boxes:
        if out and abs(out[-1][1] - b[1]) < 20 and b[0] - out[-1][2] < gap:
            out[-1][2] = b[2]
            out[-1][3] = max(out[-1][3], b[3])
        else:
            out.append(list(b))
    return out


def sheet_8dir(name, cols):
    """Config for the sheets that share the King's layout: eight direction blocks (S SE E NE / N NW W SW, each
    with idle, walk, run, dash rows), four action blocks (melee, two skill blocks, hit / hurt / death) and
    the particle row. The action blocks have no reliable divider lines: `cols` gives the frames per row of
    each block (attack, heavy, cast, hurt_death) and the rows are cut into equal cells."""
    path = 'art_src/characters/%s_sheet.webp' % name
    boxes = magenta_blocks(path)
    rows = [b for b in boxes if b[1] < 560]
    act = merge_row([b for b in boxes if 560 <= b[1] < 740])
    fx = [b for b in boxes if b[1] >= 740][0]
    order = ['s', 'se', 'e', 'ne_sheet', 'n', 'nw_sheet', 'w', 'sw']
    return {
        'src': path, 'target_body': 136, 'moves': MOVES,
        'dir_blocks': {d: tuple(b) for d, b in zip(order, rows)},
        'dir_use': {'ne': 'n', 'nw': 'n'},
        'actions': {'attack': (tuple(act[0]), 12, False, 'right', -2), 'heavy': (tuple(act[1]), 10, False, 'right', -2),
                    'cast': (tuple(act[2]), 8, False, 'right', -2)},
        'hurt_death': (tuple(act[3]), 8, 6), 'cols': cols,
        'fx_box': tuple(fx),
    }


MOVES = [('idle', 4, True), ('walk', 8, True), ('run', 12, True), ('dash', 14, True)]
for _n, _cols in {'vesper': dict(attack=4, heavy=4, cast=5, hurt_death=4), 'squire': dict(attack=4, heavy=4, cast=4, hurt_death=4),
                  'choir': dict(attack=4, heavy=4, cast=4, hurt_death=4), 'wraith': dict(attack=4, heavy=4, cast=4, hurt_death=4)}.items():
    SHEETS[_n] = sheet_8dir(_n, _cols)

# Mira: a four-direction sheet (DOWN, UP, LEFT, RIGHT blocks of 4 frames per row); the diagonals use the
# nearest drawn direction (a step down-right shows the RIGHT frames, up-left the UP frames).
_mb = magenta_blocks('art_src/characters/mira_sheet.webp')
_mrow = [b for b in _mb if b[1] < 400]
_mact = merge_row([b for b in _mb if 400 <= b[1] < 620])
SHEETS['mira'] = {
    'src': 'art_src/characters/mira_sheet.webp', 'target_body': 136, 'moves': MOVES,
    'dir_blocks': {'s': tuple(_mrow[0]), 'n': tuple(_mrow[1]), 'w': tuple(_mrow[2]), 'e': tuple(_mrow[3])},
    'dir_use': {'se': 'e', 'sw': 'w', 'ne': 'n', 'nw': 'n'},
    # her action frames are drawn facing left
    'actions': {'attack': (tuple(_mact[0]), 12, False, 'left', -2), 'heavy': (tuple(_mact[1]), 10, False, 'left', -2),
                'cast': (tuple(_mact[2]), 8, False, 'left', -2)},
    'hurt_death': (tuple(_mact[3]), 8, 6), 'hurt_native': 'left',
    'cols': dict(attack=5, heavy=[5, 4], cast=5, hurt_death=4),
    'drop': {'heavy': [7, 8, 9]},  # the ground eruption alone: played as an effect
    'fx_box': tuple([b for b in _mb if b[1] >= 620][0]),
}

# ---------- reading the sheet ----------

def masks(a):
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    divider = (g < 45) & (r > 140) & (r < 236) & (b > 140) & (b < 236) & (np.abs(r - b) < 45)
    loose_div = (g < 70) & (r > 110) & (b > 110) & (np.abs(r - b) < 60) & ~((r > 236) & (b > 220))
    dm = np.sqrt(((a - np.array([255, 0, 255])) ** 2).sum(-1))
    sprite = (dm > 110) & ~divider
    return divider, loose_div, sprite


def line_positions(frac, minfrac):
    cols = np.nonzero(frac > minfrac)[0]
    groups = []
    for c in cols:
        if groups and c - groups[-1][-1] <= 2:
            groups[-1].append(c)
        else:
            groups.append([c])
    return [int(np.mean(g)) for g in groups]


def rows_in(divider, box, want=0, sprite=None):
    """Rows of a block between its divider lines. When the divider lines are too faint to count `want` rows,
    the rows are split where the sprites leave the most room (the least sprite pixels per image row)."""
    x0, y0, x1, y1 = box
    ys = [y0] + [y0 + p for p in line_positions(divider[y0:y1, x0:x1].mean(1), 0.3)] + [y1]
    rows = [(a, b) for a, b in zip(ys, ys[1:]) if b - a > 20]
    if want and len(rows) != want and sprite is not None:
        prof = sprite[y0:y1, x0:x1].sum(1).astype(float)
        H = y1 - y0
        cuts = [y0]
        for k in range(1, want):
            lo, hi = int(H * (k / want - 0.1)), int(H * (k / want + 0.1))
            window = prof[lo:hi]
            cuts.append(y0 + lo + int(np.argmin(np.convolve(window, np.ones(5) / 5, mode='same'))))
        cuts.append(y1)
        rows = list(zip(cuts, cuts[1:]))
    return rows


def sprite_runs(sprite, x0, y0, x1, y1, minw=14, gap=2):
    """Frames in a movement row: runs of columns holding sprite pixels; narrow runs join a neighbour."""
    on = sprite[y0:y1, x0:x1].sum(0) >= 2
    segs, i, n = [], 0, len(on)
    while i < n:
        if on[i]:
            j = i
            while j < n and (on[j] or (j + gap < n and on[j:j + gap + 1].any())):
                j += 1
            segs.append([i, j])
            i = j
        else:
            i += 1
    changed = True
    while changed and len(segs) > 1:
        changed = False
        for k, (a, b) in enumerate(segs):
            if b - a < minw:
                if k == 0:
                    segs[1][0] = a
                elif k == len(segs) - 1:
                    segs[k - 1][1] = b
                elif a - segs[k - 1][1] < segs[k + 1][0] - b:
                    segs[k - 1][1] = b
                else:
                    segs[k + 1][0] = a
                segs.pop(k)
                changed = True
                break
    return [(x0 + a, x0 + b) for a, b in segs]


def grid_cells(x0, x1, cols):
    """`cols` equal cells across a block."""
    w = (x1 - x0) / cols
    return [(int(round(x0 + i * w)), int(round(x0 + (i + 1) * w))) for i in range(cols)]


def divider_cells(loose_div, x0, y0, x1, y1, min_w=30):
    """Frames in an action row: cells between divider lines; slivers join the cell on their left."""
    cut = [x0] + [x0 + p for p in line_positions(loose_div[y0 + 4:y1 - 4, x0:x1].mean(0), 0.6)] + [x1]
    cells = [[a, b] for a, b in zip(cut, cut[1:]) if b - a > 6]
    # neighbouring slivers (bright spikes of an effect read as dividers) join each other first; a group
    # that reaches min_w is a frame, a short leftover joins the frame on its left
    out, pending = [], None
    for c in cells:
        if c[1] - c[0] >= min_w:
            if pending:
                (out[-1].__setitem__(1, pending[1]) if out else out.append(pending))
                pending = None
            out.append(c)
            continue
        pending = [pending[0], c[1]] if pending else list(c)
        if pending[1] - pending[0] >= min_w:
            out.append(pending)
            pending = None
    if pending:
        if out:
            out[-1][1] = pending[1]
        else:
            out.append(pending)
    return [tuple(c) for c in out]


def defringe(img):
    """Removes the magenta cast lossy compression left on opaque outline pixels: a pixel whose red and
    blue both stand well above green with red about equal to blue (magenta, not the violet-blue of the
    magic effects) is pulled to a neutral dark tone, and near-pure magenta becomes transparent."""
    a = np.asarray(img).astype(np.float32)
    r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    lift = np.minimum(r, b) - g
    magenta = (lift > 28) & (np.abs(r - b) < 0.35 * np.maximum(r, b) + 12) & (r > b - 40)
    strength = np.clip((lift - 28) / 60.0, 0, 1) * magenta
    grey = g + 0.25 * (np.minimum(r, b) - g)  # keep a little of the lightness
    a[..., 0] = r * (1 - strength) + grey * strength
    a[..., 2] = b * (1 - strength) + grey * strength
    vivid = magenta & (r > 170) & (b > 150) & (g < 90)
    a[..., 3] = np.where(vivid, al * 0.15, al)
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), 'RGBA')


def _equal_parts(run, n):
    a, b = run
    n = max(int(n), 1)
    step = (b - a) / n
    return [(int(round(a + i * step)), int(round(a + (i + 1) * step))) for i in range(n)]


def split_wide(runs, ratio=1.55):
    """Frames whose trails or dust merged with a neighbour show up as one run much wider than the rest:
    split such a run into as many equal parts as it is wider than the median run."""
    if len(runs) < 2:
        # one run: a whole row merged by its trails; a frame is about 90 px wide
        return [(a, b) for a, b in _equal_parts(runs[0], round((runs[0][1] - runs[0][0]) / 90.0))] if runs and runs[0][1] - runs[0][0] > 190 else runs
    med = float(np.percentile([b - a for a, b in runs], 25))
    out = []
    for a, b in runs:
        n = int(round((b - a) / med)) if (b - a) > ratio * med else 1
        step = (b - a) / max(n, 1)
        out += [(int(round(a + i * step)), int(round(a + (i + 1) * step))) for i in range(n)]
    return out


def trim(img):
    bb = img.getchannel('A').point(lambda v: 255 if v > 8 else 0).getbbox()
    return (img.crop(bb), bb) if bb else (img, (0, 0, img.width, img.height))


def body_mask(a):
    """Body pixels of a keyed RGBA frame (float array): opaque, not a bright glow or dust. Light armour and
    grey fur count (luminance up to 170); strongly saturated bright pixels (magic, trails) and near-white
    ones (dust, smoke) do not."""
    rgb = a[..., :3]
    lum = rgb.mean(-1)
    mx, mn = rgb.max(-1), rgb.min(-1)
    sat = (mx - mn) / np.maximum(mx, 1.0)
    glow = ((sat > 0.5) & (mx > 190)) | (lum > 200)
    return (a[..., 3] > 200) & (lum < 170) & ~glow


def feet(img):
    """Feet point of a keyed frame: bottom of the body pixels, centred on its lowest rows."""
    a = np.asarray(img).astype(np.float32)
    body = body_mask(a)
    rows = np.nonzero(body.sum(1) >= 2)[0]
    if len(rows) == 0:
        return img.width / 2.0, float(img.height)
    bottom = rows[-1]
    band = body[max(0, bottom - 4):bottom + 1]
    xs = np.nonzero(band.any(0))[0]
    return float(xs.mean()), float(bottom + 1)


def body_height(img):
    a = np.asarray(img).astype(np.float32)
    body = body_mask(a)
    rows = np.nonzero(body.sum(1) >= 2)[0]
    # hair is light: count from the top of any opaque pixel to the feet
    opaque = np.nonzero((a[..., 3] > 200).sum(1) >= 2)[0]
    return float(rows[-1] - opaque[0] + 1) if len(rows) and len(opaque) else float(img.height)


# ---------- building ----------

def cell_boxes(cfg, act, loose_div, box, ry0, ry1):
    if 'cols' in cfg:
        c = cfg['cols'][act]
        if isinstance(c, (list, tuple)):  # a count per row
            c = c[0] if ry0 - box[1] < (box[3] - box[1]) / 2 else c[-1]
        return grid_cells(box[0], box[2], c)
    return divider_cells(loose_div, box[0], ry0, box[2], ry1)


def cut_character(name, cfg):
    sheet = Image.open(os.path.join(ROOT, cfg['src'])).convert('RGB')
    a = np.asarray(sheet).astype(np.int32)
    divider, loose_div, sprite = masks(a)
    frames = {}  # anim -> [(img, src_rect)]

    def grab(rect):
        x0, y0, x1, y1 = rect
        img, bb = trim(defringe(key_magenta(sheet.crop((x0 + 1, y0 + 1, x1 - 1, y1 - 1)), KEY_INNER, KEY_OUTER)))
        return img, [x0 + 1 + bb[0], y0 + 1 + bb[1], x0 + 1 + bb[2], y0 + 1 + bb[3]]

    # frames are found from the body only: a staff's glowing orb, a trail or dust must not join two neighbours
    rgb = a.astype(np.float32)
    mx, mn = rgb.max(-1), rgb.min(-1)
    glow = (((mx - mn) / np.maximum(mx, 1.0) > 0.5) & (mx > 190)) | (rgb.mean(-1) > 200)
    bodyspr = sprite & ~glow
    for d, box in cfg['dir_blocks'].items():
        for (move, _fps, _loop), (ry0, ry1) in zip(cfg['moves'], rows_in(divider, box, len(cfg['moves']), sprite)):
            # (the dash row keeps its trails and dust: the body alone is a thin sliver there)
            runs = split_wide(sprite_runs(sprite if move == 'dash' else bodyspr, box[0] + 2, ry0 + 2, box[2] - 2, ry1 - 2))
            # pad each run toward its neighbours (halfway at most) so the keyed crop keeps the orb, trail and dust
            padded = []
            for i, (r0, r1) in enumerate(runs):
                lo = (runs[i - 1][1] + r0) // 2 if i else max(box[0] + 2, r0 - 14)
                hi = (r1 + runs[i + 1][0]) // 2 if i + 1 < len(runs) else min(box[2] - 2, r1 + 14)
                padded.append((max(lo, r0 - 14), min(hi, r1 + 14)))
            frames['%s_%s' % (move, d)] = [grab((sx0, ry0 + 2, sx1, ry1 - 2)) for sx0, sx1 in padded]
    hd_done = False
    for act, (box, *_rest) in cfg['actions'].items():
        if 'hurt_death' in cfg and act in ('hit', 'ko'):
            if not hd_done:  # one block: standing frames are the hurt animation, lying ones the knockout
                hd_done = True
                cells = []
                for ry0, ry1 in rows_in(divider, box, 2, sprite):
                    cells += [grab((cx0, ry0 + 2, cx1, ry1 - 2)) for cx0, cx1 in cell_boxes(cfg, 'hurt_death', loose_div, box, ry0, ry1)]
                frames['ko'] = [c for c in cells if c[0].width > 1.6 * c[0].height]
                frames['hit'] = [c for c in cells if c[0].width <= 1.6 * c[0].height]
            continue
        frames[act] = []
        for ry0, ry1 in rows_in(divider, box, 2 if 'cols' in cfg else 0, sprite):
            frames[act] += [grab((cx0, ry0 + 2, cx1, ry1 - 2)) for cx0, cx1 in cell_boxes(cfg, act, loose_div, box, ry0, ry1)]
        drop = cfg.get('drop', {}).get(act, [])
        frames[act] = [f for i, f in enumerate(frames[act]) if i not in drop]
    # slivers with hardly any body (stray sparkles cut off a neighbour) are not frames
    for k in frames:
        counts = [body_pixels(img) for img, _ in frames[k]]
        med = float(np.median(counts)) if counts else 0.0
        # (and cells that are only an effect: an eruption or a magic circle with the figure hidden in it)
        frames[k] = [f for f, c in zip(frames[k], counts) if c >= 0.35 * med and not (c < 0.7 * med and effect_pixels(f[0]) > 2.5 * c)]
    return sheet, sprite, frames


def body_pixels(img):
    return int(body_mask(np.asarray(img).astype(np.float32)).sum())


def effect_pixels(img):
    """Bright or glowing pixels of a frame (slash trails, sparks, eruptions): where the impact shows."""
    a = np.asarray(img).astype(np.float32)
    rgb = a[..., :3]
    mx, mn = rgb.max(-1), rgb.min(-1)
    sat = (mx - mn) / np.maximum(mx, 1.0)
    return int((((sat > 0.45) & (mx > 200)) | (rgb.mean(-1) > 225)) .__and__(a[..., 3] > 200).sum())


def auto_strike(frames, start=1):
    """The impact frame of a one-shot: the first frame (after `start`) whose effect pixels reach 55% of the
    animation's maximum and clearly exceed the wind-up's; -1 when the animation has no effect at all."""
    counts = [effect_pixels(img) for img, _ in frames]
    if not counts or max(counts) < 30:
        return -1
    base = max(counts[0], np.median(counts[:2]) if len(counts) > 1 else 0)
    for i in range(start, len(counts)):
        if counts[i] >= 0.55 * max(counts) and counts[i] > 1.8 * base:
            return i
    return int(np.argmax(counts))


FOLDERS = {'idle': 'idle', 'walk': 'walk', 'run': 'run', 'dash': 'dash', 'attack': 'attack', 'heavy': 'attack', 'cast': 'magic', 'hit': 'hurt', 'ko': 'death'}


def folder_of(anim):
    return FOLDERS[anim.split('_')[0]]


def with_hurt_death(cfg):
    """Sheets with one HIT / HURT / DEATH block: the hurt and knockout animations come from that block."""
    cfg = dict(cfg)
    if 'hurt_death' in cfg:
        box, hit_fps, ko_fps = cfg['hurt_death']
        cfg['actions'] = dict(cfg['actions'])
        nat = cfg.get('hurt_native', 'right')
        cfg['actions']['hit'] = (box, hit_fps, False, nat, -1)
        cfg['actions']['ko'] = (box, ko_fps, False, nat, -1)
    return cfg


def build(name, cfg):
    cfg = with_hurt_death(cfg)
    out_dir = os.path.join(ROOT, 'assets', 'characters', name)
    os.makedirs(out_dir, exist_ok=True)
    import shutil
    shutil.rmtree(os.path.join(out_dir, 'animations'), ignore_errors=True)
    for f in os.listdir(out_dir):  # frames of the older flat layout
        if f.endswith('.png') or f.endswith('.png.import'):
            os.remove(os.path.join(out_dir, f))
    sheet, sprite, frames = cut_character(name, cfg)
    # one scale for the whole character, from the median idle body height (keeps proportions across
    # directions; nearest-neighbour in the game, so the source pixels stay crisp)
    idle_h = np.median([body_height(img) for k, fl in frames.items() if k.startswith('idle_') for img, _ in fl])
    scale = cfg['target_body'] / idle_h
    # one canvas for all frames, feet on the same point
    fe = {k: [feet(img) for img, _ in fl] for k, fl in frames.items()}
    left = max(fx for k in fe for fx, _ in fe[k])
    right = max(img.width - fx for k in frames for (img, _), (fx, _) in zip(frames[k], fe[k]))
    up = max(fy for k in fe for _, fy in fe[k])
    down = max(img.height - fy for k in frames for (img, _), (_, fy) in zip(frames[k], fe[k]))
    W, H = int(np.ceil(left + right)) + 2, int(np.ceil(up + down)) + 2
    ax, ay = int(np.ceil(left)) + 1, int(np.ceil(up)) + 1
    manifest = {'source': cfg['src'], 'canvas': [W, H], 'feet': [ax, ay], 'scale': round(float(scale), 4), 'directions': DIRS,
                'direction_substitutes': cfg['dir_use'], 'animations': {}, 'effects': {}}
    anims = {}
    for anim, fl in frames.items():
        if anim.endswith('_sheet') or '_sheet' in anim:
            continue
        files = []
        for i, ((img, rect), (fx, fy)) in enumerate(zip(fl, fe[anim])):
            canvas = Image.new('RGBA', (W, H), (0, 0, 0, 0))
            canvas.paste(img, (int(round(ax - fx)), int(round(ay - fy))), img)
            fn = '%s/%s_%d.png' % (folder_of(anim), anim, i)
            os.makedirs(os.path.dirname(os.path.join(out_dir, 'animations', fn)), exist_ok=True)
            canvas.save(os.path.join(out_dir, 'animations', fn), optimize=True)
            fn = 'animations/' + fn
            files.append({'file': fn, 'source_rect': rect, 'source_feet': [round(fx, 1), round(fy, 1)]})
        manifest['animations'][anim] = {'frames': files}
    # movement animations per direction (with the substitutes), action animations
    for move, fps, loop in cfg['moves']:
        for d in DIRS:
            src = '%s_%s' % (move, cfg['dir_use'].get(d, d))
            anim = '%s_%s' % (move, d)
            anims[anim] = {'frames': [f['file'] for f in manifest['animations'][src]['frames']], 'fps': fps, 'loop': loop, 'native': 'none', 'dir': d}
            if src != anim:
                manifest['animations'][anim] = {'same_as': src}
            manifest['animations'][anim].update({'fps': fps, 'loop': loop, 'direction': d})
    for act, (_box, fps, loop, native, strike) in cfg['actions'].items():
        if strike == -2:  # found from the frames: where the effect peaks
            strike = auto_strike(frames[act])
        anims[act] = {'frames': [f['file'] for f in manifest['animations'][act]['frames']], 'fps': fps, 'loop': loop, 'native': native, 'strike': strike}
        manifest['animations'][act].update({'fps': fps, 'loop': loop, 'native_facing': native, 'strike_frame': strike})
    # the names every character has (2D viewer, older code): front = down-left, back = up, both natively left
    alias = {'idle_f': 'idle_sw', 'idle_b': 'idle_n', 'ready_f': 'idle_sw', 'ready_b': 'idle_n', 'walk_f': 'walk_sw', 'walk_b': 'walk_n',
             'hit_f': 'hit', 'hit_b': 'hit', 'victory': 'idle_s'}
    for k, src in alias.items():
        anims[k] = dict(anims[src])
        anims[k]['native'] = 'left' if src.endswith(('_sw', '_n', '_s')) else anims[src]['native']
    manifest['effects'] = 'cut by tools/art/king_extras.py into effects/<group>/ (listed in meta.json)'
    with open(os.path.join(out_dir, 'manifest.json'), 'w') as f:
        json.dump(manifest, f, indent=1)
    # Frames stay at source resolution; the game scales them by meta.scale (nearest), so pixels stay square.
    meta = {'size': [W, H], 'anchor': [ax, ay], 'scale': round(float(scale), 4), 'eight_dir': True,
            'portrait': 'portraits/portrait_01.png', 'anims': anims}
    print(name, 'canvas', W, H, 'feet', ax, ay, 'scale', meta['scale'],
          {a: len(v['frames']) for a, v in anims.items() if not a.endswith(('_f', '_b'))})
    return meta


def main():
    path = os.path.join(ROOT, 'assets', 'characters', 'meta.json')
    meta = json.load(open(path))
    for name, cfg in SHEETS.items():
        meta[name] = build(name, cfg)
    with open(path, 'w') as f:
        json.dump(meta, f, indent=1)


if __name__ == '__main__':
    main()
