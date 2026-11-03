"""A character's whole look from one of the owner's grid sheets (the Boar's, Merc's): six blocks (IDLE, WALK, ATTACK, HURT,
MAGIC, DEATH), each four frames across, with a row per direction (DOWN, UP, LEFT, RIGHT) or, for a block drawn only facing
the viewer, one row. There is no separate eight-direction sheet, so this writes the character's whole meta.json entry and
every frame (like idle_walk_sheet.py with `new`), plus the illustration and the portrait. Colour palettes are not used.
The characters' own scripts (boar_sheet.py, merc_sheet.py) give it a config; run them after eight_dir.py, which keeps the
other entries.

config keys: key, src, size (a guard), blocks {kind: dict(box=(x0, y0, x1, y1), rows=[(y0, y1) per row] (optional: equal rows),
dirs=['s','n','w','e'] or ['s'] for a single row)}, pixel (the frames' pixel size), illustration (box), hit (the HURT frames
that play as the hit, default 1:3).

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
ROWS = ['s', 'n', 'w', 'e']  # DOWN, UP, LEFT, RIGHT
FOLDER = {'idle': 'idle', 'walk': 'walk', 'attack': 'attack', 'hurt': 'hurt', 'magic': 'magic', 'death': 'death'}
INSET = 3


def cell(a, blk, d, k):
    """One cell of a block: the magenta keyed out, soft edges kept."""
    x0, y0, x1, y1 = blk['box']
    di = blk['dirs'].index(d)
    w = (x1 - x0) / 4.0
    if blk.get('rows'):
        ry0, ry1 = blk['rows'][di]
    else:
        h = (y1 - y0) / float(len(blk['dirs']))
        ry0, ry1 = int(round(y0 + di * h)), int(round(y0 + (di + 1) * h))
    cx0, cx1 = int(round(x0 + k * w)) + INSET, int(round(x0 + (k + 1) * w)) - INSET
    return attack_sheet.cut_cell(a[ry0 + INSET:ry1 - INSET, cx0:cx1])


def feet_of(rgba):
    solid = rgba[..., 3] > 127
    counts = solid.sum(1)
    low = int(np.nonzero(counts >= max(6, 0.15 * counts.max()))[0].max())
    band = solid[max(low - 3, 0):low + 1]
    return float(np.nonzero(band.any(0))[0].mean()), float(low)


def build(cfg):
    key, blocks, pixel = cfg['key'], cfg['blocks'], cfg['pixel']
    sheet = Image.open(os.path.join(ROOT, cfg['src'])).convert('RGB')
    assert sheet.size == tuple(cfg['size']), sheet.size
    a = np.asarray(sheet).astype(np.float32)
    cells = {(kind, d, k): cell(a, blk, d, k) for kind, blk in blocks.items() for d in blk['dirs'] for k in range(4)}
    # per (kind, direction): the feet of its resting frames; every frame of the animation keeps its place relative to them
    rest = {'idle': (0, 1, 2, 3), 'walk': (0, 1, 2, 3), 'attack': (0, 3), 'hurt': (0, 3), 'magic': (0,), 'death': (0,)}
    feet = {}
    for kind, blk in blocks.items():
        for d in blk['dirs']:
            fs = [feet_of(cells[(kind, d, k)]) for k in rest[kind]]
            feet[(kind, d)] = (float(np.median([f[0] for f in fs])), float(np.median([f[1] for f in fs])))
    # canvas: wide enough for every frame around the feet (arcs, auras), the feet near the bottom
    left = right = up = down = 0.0
    for (kind, d, k), c in cells.items():
        ys, xs = np.nonzero(c[..., 3] > 127)
        fx, fy = feet[(kind, d)]
        left, right = max(left, fx - xs.min()), max(right, xs.max() + 1 - fx)
        up, down = max(up, fy - ys.min()), max(down, ys.max() + 1 - fy)
    cw = int(2 * np.ceil(max(left, right) * pixel)) + 4
    ch = int(np.ceil(up * pixel)) + int(np.ceil(down * pixel)) + 4
    fx0, fy0 = cw // 2, int(np.ceil(up * pixel)) + 2
    out_dir = os.path.join(ROOT, 'assets', 'characters', key)
    names = {'hurt': 'hit', 'death': 'ko', 'magic': 'cast'}
    anims = {}
    for (kind, d, k), c in cells.items():
        img = Image.fromarray(np.clip(c, 0, 255).astype(np.uint8), 'RGBA').convert('RGBa')
        w, h = round(img.width * pixel), round(img.height * pixel)
        small = img.resize((w, h), Image.LANCZOS).convert('RGBA')
        fx, fy = feet[(kind, d)]
        ox, oy = round(fx0 - fx * pixel), round(fy0 - fy * pixel)
        canvas = Image.new('RGBA', (cw, ch), (0, 0, 0, 0))
        sx0, sy0 = max(-ox, 0), max(-oy, 0)
        sx1, sy1 = min(w, cw - ox), min(h, ch - oy)
        canvas.alpha_composite(small.crop((sx0, sy0, sx1, sy1)), (ox + sx0, oy + sy0))
        fn = '%s_%s_%d.png' % (names.get(kind, kind), d, k)
        os.makedirs(os.path.join(out_dir, 'animations', FOLDER[kind]), exist_ok=True)
        canvas.save(os.path.join(out_dir, 'animations', FOLDER[kind], fn))
        anims.setdefault((kind, d), []).append('animations/%s/%s' % (FOLDER[kind], fn))
    scale = idle_walk_sheet.standard_scale(os.path.join(out_dir, 'animations'))

    def entry(frames, fps, loop, native, **extra):
        return dict({'frames': list(frames), 'fps': fps, 'loop': loop, 'native': native}, **extra)

    lo, hi = cfg.get('hit', (1, 3))
    out = {}
    for d in ROWS:
        out['idle_' + d] = entry(anims[('idle', d)], 4, True, 'none', dir=d)
        out['walk_' + d] = entry(anims[('walk', d)], 8, True, 'none', dir=d)
        out['run_' + d] = entry(anims[('walk', d)], 10, True, 'none', dir=d)
        out['dash_' + d] = entry(anims[('walk', d)], 12, True, 'none', dir=d)
        out['attack_' + d] = entry(anims[('attack', d)], 10, False, 'right', strike=2)
        out['heavy_' + d] = entry(anims[('attack', d)], 10, False, 'right', strike=2)
    for kind, name, fps, strike in (('magic', 'cast', 8, 2), ('hurt', 'hit', 8, -1), ('death', 'ko', 6, -1)):
        frames = lambda d: anims[(kind, d)][lo:hi] if kind == 'hurt' else anims[(kind, d)]
        if len(blocks[kind]['dirs']) == 4:  # a row per direction
            for d in ROWS:
                out['%s_%s' % (name, d)] = entry(frames(d), fps, False, 'right', strike=strike)
            out[name] = dict(out['%s_s' % name])
        else:  # one row facing the viewer, mirrored by the game for the other side
            out[name] = entry(frames('s'), fps, False, 'right', strike=strike)
    out['attack'] = dict(out['attack_s'])
    out['heavy'] = dict(out['heavy_s'])
    hit_s, hit_n = out.get('hit_s', out['hit']), out.get('hit_n', out['hit'])
    for alias, src in (('idle_f', out['idle_s']), ('ready_f', out['idle_s']), ('walk_f', out['walk_s']), ('idle_b', out['idle_n']),
                       ('ready_b', out['idle_n']), ('walk_b', out['walk_n']), ('hit_f', hit_s), ('hit_b', hit_n)):
        out[alias] = dict(src, native='left', dir='s' if alias.endswith('_f') else 'n')
    out['victory'] = dict(out['idle_s'])
    # illustration and portrait
    os.makedirs(os.path.join(out_dir, 'artwork'), exist_ok=True)
    os.makedirs(os.path.join(out_dir, 'portraits'), exist_ok=True)
    art = sheet.crop(cfg['illustration']).convert('RGBA')
    art.save(os.path.join(out_dir, 'artwork', 'full_portrait.png'), optimize=True)
    art.save(os.path.join(out_dir, 'portraits', 'portrait_01.png'), optimize=True)
    text = open(META, encoding='utf-8').read()
    meta = json.loads(text)
    indent = 1 if '\n "' in text else 2
    meta[key] = {'size': [cw, ch], 'anchor': [fx0, fy0 + 1], 'scale': scale, 'eight_dir': True, 'slash_in_frames': True,
                 'portrait': 'portraits/portrait_01.png', 'portraits': ['portraits/portrait_01.png'], 'effects': {}, 'anims': out}
    with open(META, 'w', encoding='utf-8') as f:
        f.write(json.dumps(meta, indent=indent, ensure_ascii=False) + '\n')
    print('%s: canvas %dx%d, feet (%d, %d), meta scale %.4f' % (key, cw, ch, fx0, fy0, scale))
