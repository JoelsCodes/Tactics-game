"""Cuts a character's idle and walk animations from one of the owner's four-direction idle/walk sheets.

A sheet has two rows (IDLE on top, WALK below) and four panels per row: DOWN, RIGHT, UP, LEFT, four frames in each
(the direction changes every 4). The characters' own scripts (squire_idle_walk.py, ...) give this module their
config and are run after eight_dir.py and before the extras step that bakes the colour variants, so the frames are
kept for the whole game. The King's and Lyra's scripts (king_idle_walk.py, lyra_idle_walk.py) do the same job with
their own copy of this logic.

config keys:
  key        the character's sheet id (meta.json key and folder under assets/characters)
  src        the sheet's path under godot/, e.g. art_src/characters/squire_idle_walk_sheet.png
  size       the sheet image's size, (w, h): a guard that the boxes below fit
  canvas     the character's shared frame size (meta.json size)
  feet       where the feet go on the canvas (meta.json anchor, y minus 1)
  figure_px  the figure's height on the canvas, as on the character's other animations
  panels     {'s': (x0, x1), 'e': ..., 'n': ..., 'w': ...}: the x range of the DOWN, RIGHT, UP and LEFT panels
  rows       {'idle': (y0, y1), 'walk': (y0, y1)}: the y range of the two rows

Output: assets/characters/<key>/animations/{idle,walk}/<kind>_<s|e|n|w>_<0..3>.png, and meta.json's idle_<dir> and
walk_<dir> point at them: s, e, n, w use their own panel; the diagonals use the front art (se, sw) or the back art
(ne, nw), because the game draws four directions only.
"""
import json
import os

import numpy as np
from PIL import Image
from scipy import ndimage as nd

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
META = os.path.join(ROOT, 'assets', 'characters', 'meta.json')
FRAMES = 4
USES = {'s': 's', 'e': 'e', 'n': 'n', 'w': 'w', 'se': 's', 'sw': 's', 'ne': 'n', 'nw': 'n'}


def _cut(sheet, magenta, cfg, kind, panel, k):
    y0, y1 = cfg['rows'][kind]
    x0, x1 = cfg['panels'][panel]
    px0, px1 = x0 + 2, x1 - 2
    whole = nd.binary_opening(~magenta[y0:y1, px0:px1], np.ones((3, 3)))
    lab, n = nd.label(whole)
    sizes = nd.sum(whole, lab, range(1, n + 1))
    comps = [i + 1 for i, sz in enumerate(sizes) if sz > 600]
    if len(comps) == FRAMES:
        # the four sprites are separate shapes (a wide cloak may pass the cell's edge): cut each whole
        comps.sort(key=lambda i: np.nonzero(lab == i)[1].min())
        mask = nd.binary_fill_holes(lab == comps[k]) & ~magenta[y0:y1, px0:px1]
        ox = px0
    else:
        # the sprites touch: cut by the cell, the largest shape in it
        w = (x1 - x0) / float(FRAMES)
        cx0, cx1 = int(x0 + k * w) + 2, int(x0 + (k + 1) * w) - 2
        sub = nd.binary_opening(~magenta[y0:y1, cx0:cx1], np.ones((3, 3)))
        lab2, n2 = nd.label(sub)
        sizes2 = nd.sum(sub, lab2, range(1, n2 + 1))
        i = int(np.argmax(sizes2)) + 1
        mask = nd.binary_fill_holes(lab2 == i) & ~magenta[y0:y1, cx0:cx1]
        ox = cx0
    ys, xs = np.nonzero(mask)
    box = (ox + xs.min(), y0 + ys.min(), ox + xs.max() + 1, y0 + ys.max() + 1)
    crop = sheet.crop(box).convert('RGBA')
    m = mask[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    crop.putalpha(Image.fromarray((m * 255).astype(np.uint8)))
    return crop


def _frame(crop, scale, cfg):
    w, h = round(crop.width * scale), round(crop.height * scale)
    small = crop.resize((w, h), Image.LANCZOS)
    out = Image.new('RGBA', tuple(cfg['canvas']), (0, 0, 0, 0))
    out.alpha_composite(small, (cfg['feet'][0] - w // 2, cfg['feet'][1] - h + 1))
    return out


def build(cfg):
    src = os.path.join(ROOT, cfg['src'])
    sheet = Image.open(src).convert('RGB')
    assert sheet.size == tuple(cfg['size']), 'unexpected sheet size %s: the boxes are for %s' % (sheet.size, cfg['size'])
    a = np.asarray(sheet).astype(np.float32)
    R, G, B = a[..., 0], a[..., 1], a[..., 2]
    magenta = (R > 150) & (B > 150) & (G < 0.5 * np.minimum(R, B))  # the background and its tint
    rows, panels = cfg['rows'], cfg['panels']
    crops = {(kind, panel, k): _cut(sheet, magenta, cfg, kind, panel, k) for kind in rows for panel in panels for k in range(FRAMES)}
    scale = cfg['figure_px'] / float(np.median([c.height for (kind, _p, _k), c in crops.items() if kind == 'idle']))
    out_dir = os.path.join(ROOT, 'assets', 'characters', cfg['key'], 'animations')
    for (kind, panel, k), crop in crops.items():
        os.makedirs(os.path.join(out_dir, kind), exist_ok=True)
        _frame(crop, scale, cfg).save(os.path.join(out_dir, kind, '%s_%s_%d.png' % (kind, panel, k)))
    text = open(META, encoding='utf-8').read()
    meta = json.loads(text)
    indent = 2 if '\n  "' in text else 1
    anims = meta[cfg['key']]['anims']
    for kind in rows:
        for d, panel in USES.items():
            anims['%s_%s' % (kind, d)]['frames'] = ['animations/%s/%s_%s_%d.png' % (kind, kind, panel, k) for k in range(FRAMES)]
    with open(META, 'w', encoding='utf-8') as f:
        f.write(json.dumps(meta, indent=indent, ensure_ascii=False) + '\n')
    print('%s idle and walk: %d frames cut from %s (scale %.4f)' % (cfg['key'], len(crops), cfg['src'], scale))
