"""The Boar's (an enemy) whole character, from the owner's one four-direction sheet (art_src/characters/boar_sheet.png).

The sheet is six blocks (IDLE, WALK, ATTACK / HURT, MAGIC, DEATH), each four frames across and four rows down: DOWN,
UP, LEFT, RIGHT. It has no separate eight-direction sheet, so this script writes the character's whole meta.json entry
and every frame (like idle_walk_sheet.py with `new`), plus the illustration and the portrait. Colour palettes are not used.

  python3 godot/tools/art/boar_sheet.py        (needs Pillow, numpy, scipy; run after eight_dir.py, which keeps the other entries)

Frames: animations/<kind>/<anim>_<s|n|w|e>_<k>.png on one canvas, the feet (the lowest wide row of the resting frames of a
direction) on one point, one pixel size for the whole character. The attack's arc and the magic aura are drawn in the frames
(`slash_in_frames`). Heavy, run and dash reuse the attack and the walk. Hit plays frames 1 and 2 of the HURT block.
"""
import json
import os

import numpy as np
from PIL import Image

import attack_sheet
import idle_walk_sheet

ROOT = idle_walk_sheet.ROOT
META = idle_walk_sheet.META
KEY = 'boar'
SRC = 'art_src/characters/boar_sheet.png'
SIZE = (1536, 1024)
# block boxes (x0, y0, x1, y1): the magenta panels; four equal columns and four equal rows in each
BLOCKS = {
    'idle': (94, 48, 532, 366), 'walk': (541, 48, 1016, 366), 'attack': (1026, 48, 1532, 366),
    'hurt': (95, 423, 532, 736), 'magic': (541, 424, 1020, 736), 'death': (1030, 424, 1532, 736),
}
ROWS = ['s', 'n', 'w', 'e']  # DOWN, UP, LEFT, RIGHT
PIXEL = 0.9  # the sheet's cells are about 60 px tall; the frames are drawn a little smaller
FOLDER = {'idle': 'idle', 'walk': 'walk', 'attack': 'attack', 'hurt': 'hurt', 'magic': 'magic', 'death': 'death'}
INSET = 3
ILLUSTRATION = (14, 772, 300, 1008)
FPS = {'idle': 4, 'walk': 8, 'attack': 10, 'hurt': 8, 'magic': 8, 'death': 6}


def cell(a, kind, d, k):
    x0, y0, x1, y1 = BLOCKS[kind]
    w, h = (x1 - x0) / 4.0, (y1 - y0) / 4.0
    cx0, cy0 = int(round(x0 + k * w)) + INSET, int(round(y0 + ROWS.index(d) * h)) + INSET
    cx1, cy1 = int(round(x0 + (k + 1) * w)) - INSET, int(round(y0 + (ROWS.index(d) + 1) * h)) - INSET
    return attack_sheet.cut_cell(a[cy0:cy1, cx0:cx1])


def feet_of(rgba):
    solid = rgba[..., 3] > 127
    counts = solid.sum(1)
    low = int(np.nonzero(counts >= max(6, 0.15 * counts.max()))[0].max())
    band = solid[max(low - 3, 0):low + 1]
    return float(np.nonzero(band.any(0))[0].mean()), float(low)


def main():
    sheet = Image.open(os.path.join(ROOT, SRC)).convert('RGB')
    assert sheet.size == SIZE, sheet.size
    a = np.asarray(sheet).astype(np.float32)
    cells = {(kind, d, k): cell(a, kind, d, k) for kind in BLOCKS for d in ROWS for k in range(4)}
    # per (kind, direction): the feet of its resting frames; every frame of the animation keeps its place relative to them
    rest = {'idle': (0, 1, 2, 3), 'walk': (0, 1, 2, 3), 'attack': (0, 3), 'hurt': (0, 3), 'magic': (0,), 'death': (0,)}
    feet = {}
    for kind in BLOCKS:
        for d in ROWS:
            fs = [feet_of(cells[(kind, d, k)]) for k in rest[kind]]
            feet[(kind, d)] = (float(np.median([f[0] for f in fs])), float(np.median([f[1] for f in fs])))
    # canvas: wide enough for every frame around the feet (arcs, auras), the feet near the bottom
    left = right = up = down = 0.0
    for (kind, d, k), c in cells.items():
        ys, xs = np.nonzero(c[..., 3] > 127)
        fx, fy = feet[(kind, d)]
        left, right = max(left, fx - xs.min()), max(right, xs.max() + 1 - fx)
        up, down = max(up, fy - ys.min()), max(down, ys.max() + 1 - fy)
    cw = int(2 * np.ceil(max(left, right) * PIXEL)) + 4
    ch = int(np.ceil(up * PIXEL)) + int(np.ceil(down * PIXEL)) + 4
    fx0, fy0 = cw // 2, int(np.ceil(up * PIXEL)) + 2
    out_dir = os.path.join(ROOT, 'assets', 'characters', KEY)
    anims = {}
    for (kind, d, k), c in cells.items():
        img = Image.fromarray(np.clip(c, 0, 255).astype(np.uint8), 'RGBA').convert('RGBa')
        w, h = round(img.width * PIXEL), round(img.height * PIXEL)
        small = img.resize((w, h), Image.LANCZOS).convert('RGBA')
        fx, fy = feet[(kind, d)]
        ox, oy = round(fx0 - fx * PIXEL), round(fy0 - fy * PIXEL)
        canvas = Image.new('RGBA', (cw, ch), (0, 0, 0, 0))
        sx0, sy0 = max(-ox, 0), max(-oy, 0)
        sx1, sy1 = min(w, cw - ox), min(h, ch - oy)
        canvas.alpha_composite(small.crop((sx0, sy0, sx1, sy1)), (ox + sx0, oy + sy0))
        fn = '%s_%s_%d.png' % (kind if kind not in ('hurt', 'death', 'magic') else {'hurt': 'hit', 'death': 'ko', 'magic': 'cast'}[kind], d, k)
        os.makedirs(os.path.join(out_dir, 'animations', FOLDER[kind]), exist_ok=True)
        canvas.save(os.path.join(out_dir, 'animations', FOLDER[kind], fn))
        anims.setdefault((kind, d), []).append('animations/%s/%s' % (FOLDER[kind], fn))
    scale = idle_walk_sheet.standard_scale(os.path.join(out_dir, 'animations'))

    def entry(frames, fps, loop, native, **extra):
        return dict({'frames': list(frames), 'fps': fps, 'loop': loop, 'native': native}, **extra)

    out = {}
    for d in ROWS:
        out['idle_' + d] = entry(anims[('idle', d)], 4, True, 'none', dir=d)
        out['walk_' + d] = entry(anims[('walk', d)], 8, True, 'none', dir=d)
        out['run_' + d] = entry(anims[('walk', d)], 10, True, 'none', dir=d)
        out['dash_' + d] = entry(anims[('walk', d)], 12, True, 'none', dir=d)
        out['attack_' + d] = entry(anims[('attack', d)], 10, False, 'right', strike=2)
        out['heavy_' + d] = entry(anims[('attack', d)], 10, False, 'right', strike=2)
        out['cast_' + d] = entry(anims[('magic', d)], 8, False, 'right', strike=2)
        out['hit_' + d] = entry(anims[('hurt', d)][1:3], 8, False, 'right', strike=-1)
        out['ko_' + d] = entry(anims[('death', d)], 6, False, 'right', strike=-1)
    # the older names the game falls back on: plain actions face down, front and back aliases
    out['attack'] = dict(out['attack_s'])
    out['heavy'] = dict(out['heavy_s'])
    out['cast'] = dict(out['cast_s'])
    out['hit'] = dict(out['hit_s'])
    out['ko'] = dict(out['ko_s'])
    for alias, src in (('idle_f', 'idle_s'), ('ready_f', 'idle_s'), ('walk_f', 'walk_s'), ('idle_b', 'idle_n'), ('ready_b', 'idle_n'), ('walk_b', 'walk_n'),
                       ('hit_f', 'hit_s'), ('hit_b', 'hit_n')):
        out[alias] = dict(out[src], native='left', dir='s' if alias.endswith('_f') else 'n')
    out['victory'] = dict(out['idle_s'])
    # illustration and portrait
    os.makedirs(os.path.join(out_dir, 'artwork'), exist_ok=True)
    os.makedirs(os.path.join(out_dir, 'portraits'), exist_ok=True)
    art = sheet.crop(ILLUSTRATION).convert('RGBA')
    art.save(os.path.join(out_dir, 'artwork', 'full_portrait.png'), optimize=True)
    art.save(os.path.join(out_dir, 'portraits', 'portrait_01.png'), optimize=True)
    text = open(META, encoding='utf-8').read()
    meta = json.loads(text)
    indent = 1 if '\n "' in text else 2
    meta[KEY] = {'size': [cw, ch], 'anchor': [fx0, fy0 + 1], 'scale': scale, 'eight_dir': True, 'slash_in_frames': True,
                 'portrait': 'portraits/portrait_01.png', 'portraits': ['portraits/portrait_01.png'], 'effects': {}, 'anims': out}
    with open(META, 'w', encoding='utf-8') as f:
        f.write(json.dumps(meta, indent=indent, ensure_ascii=False) + '\n')
    print('boar: canvas %dx%d, feet (%d, %d), meta scale %.4f' % (cw, ch, fx0, fy0, scale))


if __name__ == '__main__':
    main()
