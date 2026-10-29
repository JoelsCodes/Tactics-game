"""Cuts a character's idle and walk animations from one of the owner's four-direction idle/walk sheets.

A sheet has two rows (IDLE on top, WALK below) and four panels per row: DOWN, RIGHT, UP, LEFT, four frames in each
(the direction changes every 4). The characters' own scripts (squire_idle_walk.py, ...) give this module their
config and are run after eight_dir.py, so the frames are kept for the whole game. The King's and Lyra's scripts (king_idle_walk.py, lyra_idle_walk.py) do the same job with
their own copy of this logic.

config keys:
  key        the character's sheet id (meta.json key and folder under assets/characters)
  src        the sheet's path under godot/, e.g. art_src/characters/squire_idle_walk_sheet.png
  size       the sheet image's size, (w, h): a guard that the boxes below fit
  canvas     the character's shared frame size (meta.json size)
  feet       where the feet go on the canvas (meta.json anchor, y minus 1)
  figure_px  the figure's height on the canvas, as on the character's other animations (the frames' pixel size;
             how tall it is drawn in the game is set by STANDARD_FIGURE)
  panels     {'s': (x0, x1), 'e': ..., 'n': ..., 'w': ...}: the x range of the DOWN, RIGHT, UP and LEFT panels
  rows       {'idle': (y0, y1), 'walk': (y0, y1)}: the y range of the two rows

Output: assets/characters/<key>/animations/{idle,walk}/<kind>_<s|e|n|w>_<0..3>.png, and meta.json's idle_<dir> and
walk_<dir> point at them: s, e, n, w use their own panel; the diagonals use the front art (se, sw) or the back art
(ne, nw), because the game draws four directions only.
"""
import json
import os
import re

import numpy as np
from PIL import Image
from scipy import ndimage as nd

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
META = os.path.join(ROOT, 'assets', 'characters', 'meta.json')
FRAMES = 4
# The owner's size standard: every character's idle figure is drawn this tall in the game (frame px x meta.json
# scale): the King's size, his 60 px idle at scale 2.0. Each idle/walk script sets its character's scale from it, so
# all of that character's animations (attacks, hurt, ...) grow or shrink together and every character stands as tall
# as the King. New characters get it by going through build() below.
STANDARD_FIGURE = 120.0
USES = {'s': 's', 'e': 'e', 'n': 'n', 'w': 'w', 'se': 's', 'sw': 's', 'ne': 'n', 'nw': 'n'}


def despill(a):
    """The sheet as an RGB image with the background's pink tint taken off the sprites' anti-aliased edges: a pixel with
    red and blue both well above green has them pulled down to just above green. Call it after the background mask is
    made from the original array `a`."""
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    cast = (np.minimum(r, b) - g > 40) & (np.abs(r - b) < 40)
    out = a.copy()
    cap = g + 20
    out[..., 0] = np.where(cast, np.minimum(r, cap), r)
    out[..., 2] = np.where(cast, np.minimum(b, cap), b)
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))


def standard_scale(anim_dir):
    """The meta.json scale that draws a character's idle figure STANDARD_FIGURE tall, from the median figure height
    of the four-direction idle frames just written to <anim_dir>/idle/ (older unused frames there are skipped)."""
    d = os.path.join(anim_dir, 'idle')
    hs = []
    for fn in sorted(os.listdir(d)):
        if re.fullmatch(r'idle_[senw]_\d+\.png', fn):
            rows = np.nonzero((np.asarray(Image.open(os.path.join(d, fn)).convert('RGBA'))[..., 3] > 0).any(1))[0]
            hs.append(rows[-1] - rows[0] + 1)
    return round(STANDARD_FIGURE / float(np.median(hs)), 4)


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
    sheet = despill(a)  # the cut-out sprites carry no pink edge
    rows, panels = cfg['rows'], cfg['panels']
    crops = {(kind, panel, k): _cut(sheet, magenta, cfg, kind, panel, k) for kind in rows for panel in panels for k in range(FRAMES)}
    # one pixel size for idle and walk (the idle sets it): the pose may change the figure's height a little, its size does not
    idle_scale = cfg['figure_px'] / float(np.median([c.height for (kd, _p, _k), c in crops.items() if kd == 'idle']))
    scale = {kind: idle_scale for kind in rows}
    out_dir = os.path.join(ROOT, 'assets', 'characters', cfg['key'], 'animations')
    for (kind, panel, k), crop in crops.items():
        os.makedirs(os.path.join(out_dir, kind), exist_ok=True)
        _frame(crop, scale[kind], cfg).save(os.path.join(out_dir, kind, '%s_%s_%d.png' % (kind, panel, k)))
    text = open(META, encoding='utf-8').read()
    meta = json.loads(text)
    indent = 1 if '\n "' in text else 2  # keep the file's own indent (a top-level key sits one indent in)
    anims = meta[cfg['key']]['anims']
    meta[cfg['key']]['scale'] = standard_scale(out_dir)
    for kind in rows:
        for d, panel in USES.items():
            anims['%s_%s' % (kind, d)]['frames'] = ['animations/%s/%s_%s_%d.png' % (kind, kind, panel, k) for k in range(FRAMES)]
    with open(META, 'w', encoding='utf-8') as f:
        f.write(json.dumps(meta, indent=indent, ensure_ascii=False) + '\n')
    print('%s idle and walk: %d frames cut from %s (scale idle %.4f, walk %.4f; meta scale %.4f)' % (cfg['key'], len(crops), cfg['src'], scale['idle'], scale['walk'], meta[cfg['key']]['scale']))
