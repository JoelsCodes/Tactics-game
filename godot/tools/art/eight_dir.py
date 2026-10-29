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


def rows_in(divider, box):
    x0, y0, x1, y1 = box
    ys = [y0] + [y0 + p for p in line_positions(divider[y0:y1, x0:x1].mean(1), 0.3)] + [y1]
    return [(a, b) for a, b in zip(ys, ys[1:]) if b - a > 20]


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


def trim(img):
    bb = img.getchannel('A').point(lambda v: 255 if v > 8 else 0).getbbox()
    return (img.crop(bb), bb) if bb else (img, (0, 0, img.width, img.height))


def feet(img):
    """Feet point of a keyed frame: bottom of the dark body pixels, centred on its lowest rows."""
    a = np.asarray(img).astype(np.float32)
    lum = a[..., :3].mean(-1)
    body = (a[..., 3] > 200) & (lum < 110)
    rows = np.nonzero(body.sum(1) >= 2)[0]
    if len(rows) == 0:
        return img.width / 2.0, float(img.height)
    bottom = rows[-1]
    band = body[max(0, bottom - 4):bottom + 1]
    xs = np.nonzero(band.any(0))[0]
    return float(xs.mean()), float(bottom + 1)


def body_height(img):
    a = np.asarray(img).astype(np.float32)
    body = (a[..., 3] > 200) & (a[..., :3].mean(-1) < 140)
    rows = np.nonzero(body.sum(1) >= 2)[0]
    # hair is light: count from the top of any opaque pixel to the feet
    opaque = np.nonzero((a[..., 3] > 200).sum(1) >= 2)[0]
    return float(rows[-1] - opaque[0] + 1) if len(rows) and len(opaque) else float(img.height)


# ---------- building ----------

def cut_character(name, cfg):
    sheet = Image.open(os.path.join(ROOT, cfg['src'])).convert('RGB')
    a = np.asarray(sheet).astype(np.int32)
    divider, loose_div, sprite = masks(a)
    frames = {}  # anim -> [(img, src_rect)]

    def grab(rect):
        x0, y0, x1, y1 = rect
        img, bb = trim(defringe(key_magenta(sheet.crop((x0 + 1, y0 + 1, x1 - 1, y1 - 1)), KEY_INNER, KEY_OUTER)))
        return img, [x0 + 1 + bb[0], y0 + 1 + bb[1], x0 + 1 + bb[2], y0 + 1 + bb[3]]

    for d, box in cfg['dir_blocks'].items():
        for (move, _fps, _loop), (ry0, ry1) in zip(cfg['moves'], rows_in(divider, box)):
            frames['%s_%s' % (move, d)] = [grab((sx0, ry0 + 2, sx1, ry1 - 2)) for sx0, sx1 in sprite_runs(sprite, box[0] + 2, ry0 + 2, box[2] - 2, ry1 - 2)]
    for act, (box, *_rest) in cfg['actions'].items():
        frames[act] = []
        for ry0, ry1 in rows_in(divider, box):
            frames[act] += [grab((cx0, ry0 + 2, cx1, ry1 - 2)) for cx0, cx1 in divider_cells(loose_div, box[0], ry0, box[2], ry1)]
        drop = cfg.get('drop', {}).get(act, [])
        frames[act] = [f for i, f in enumerate(frames[act]) if i not in drop]
    # slivers with hardly any body (stray sparkles cut off a neighbour) are not frames
    for k in frames:
        counts = [body_pixels(img) for img, _ in frames[k]]
        med = float(np.median(counts)) if counts else 0.0
        frames[k] = [f for f, c in zip(frames[k], counts) if c >= 0.2 * med]
    return sheet, sprite, frames


def body_pixels(img):
    a = np.asarray(img).astype(np.float32)
    return int(((a[..., 3] > 200) & (a[..., :3].mean(-1) < 110)).sum())


def build(name, cfg):
    out_dir = os.path.join(ROOT, 'assets', 'characters', name)
    os.makedirs(out_dir, exist_ok=True)
    for f in os.listdir(out_dir):
        if f.endswith('.png') and not f.endswith('.import'):
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
            fn = '%s_%d.png' % (anim, i)
            canvas.save(os.path.join(out_dir, fn), optimize=True)
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
        anims[act] = {'frames': [f['file'] for f in manifest['animations'][act]['frames']], 'fps': fps, 'loop': loop, 'native': native, 'strike': strike}
        manifest['animations'][act].update({'fps': fps, 'loop': loop, 'native_facing': native, 'strike_frame': strike})
    # the names every character has (2D viewer, older code): front = down-left, back = up, both natively left
    alias = {'idle_f': 'idle_sw', 'idle_b': 'idle_n', 'ready_f': 'idle_sw', 'ready_b': 'idle_n', 'walk_f': 'walk_sw', 'walk_b': 'walk_n',
             'hit_f': 'hit', 'hit_b': 'hit', 'victory': 'idle_s'}
    for k, src in alias.items():
        anims[k] = dict(anims[src])
        anims[k]['native'] = 'left' if src.endswith(('_sw', '_n', '_s')) else anims[src]['native']
    # effects
    fxbox = cfg['fx_box']
    runs = sprite_runs(sprite, fxbox[0] + 2, fxbox[1] + 2, fxbox[2] - 2, fxbox[3] - 2)
    k = 0
    for gname, count in cfg['fx_groups']:
        files = []
        for i in range(count):
            if k >= len(runs):
                break
            sx0, sx1 = runs[k]
            k += 1
            img, bb = trim(key_magenta(sheet.crop((sx0, fxbox[1] + 2, sx1, fxbox[3] - 2))))
            fn = 'fx_%s_%d.png' % (gname, i)
            img.save(os.path.join(out_dir, fn), optimize=True)
            files.append({'file': fn, 'source_rect': [sx0 + bb[0], fxbox[1] + 2 + bb[1], sx0 + bb[2], fxbox[1] + 2 + bb[3]]})
        manifest['effects'][gname] = {'frames': files, 'fps': 14}
    manifest['effect_runs_found'] = len(runs)
    # portrait
    px0, py0, px1, py1 = cfg['portrait_box']
    sheet.crop((px0, py0, px1, py1)).save(os.path.join(out_dir, 'portrait.png'), optimize=True)
    with open(os.path.join(out_dir, 'manifest.json'), 'w') as f:
        json.dump(manifest, f, indent=1)
    # Frames stay at source resolution; the game scales them by meta.scale (nearest), so pixels stay square.
    meta = {'size': [W, H], 'anchor': [ax, ay], 'scale': round(float(scale), 4), 'eight_dir': True, 'portrait': 'portrait.png', 'anims': anims,
            'effects': {g: {'frames': [f['file'] for f in v['frames']], 'fps': v['fps']} for g, v in manifest['effects'].items()}}
    print(name, 'canvas', W, H, 'feet', ax, ay, 'scale', meta['scale'], 'fx runs', len(runs),
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
