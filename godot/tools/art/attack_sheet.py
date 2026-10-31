"""A character's four-direction attack, cut from one of the owner's attack sheets (used for the Ashen Squire and the King).

A sheet has four rows (DOWN, UP, LEFT, RIGHT) of four frames each (wind-up, sword raised, the slash with its arc,
recovery), on magenta, under a header bar per cell. The characters' own scripts (squire_attack.py, king_attack.py) give
this module their config and run after eight_dir.py (which writes meta.json from scratch), like the idle/walk scripts.

Written as attack_s, attack_n, attack_w and attack_e (4 frames each, the strike on the slash frame): the animator picks
`<action>_<dir>` for a character with eight-direction names, so the character swings the way it faces and nothing is
mirrored. The older one-direction `attack` stays in meta.json as the fallback.

The sprites are cut out of the magenta with their soft edges kept (the glow of the slash arc blends into the
background: the colour under it is worked back out, so no pink halo; colours inside the sprite are never touched). All
sixteen frames share one pixel size, set so the figure is as tall as in the idle (`figure_px`); each direction is placed
by its boots, and the four frames of a direction keep their places relative to each other, so the lunge and the arc move
as drawn. The shared canvas clips the far tip of a wide arc a little.

config keys:
  key        the character's sheet id (meta.json key and folder under assets/characters)
  src        the sheet's path under godot/
  size       the sheet image's size, (w, h): a guard that the boxes below fit
  canvas     the character's shared frame size (meta.json size)
  feet       where the feet go on the canvas (meta.json anchor, y minus 1)
  figure_px  fallback for the figure's height on the canvas, used when the built idle frames are missing (the real
             height is measured from them)
  widen      optional: horizontal stretch, as the idle and walk have (the King's 5%)
  cols       the x range of the four frames of a row
  rows       {'s': (y0, y1), 'n': ..., 'w': ..., 'e': ...}: the y range of the art under each row's header bars
  fps        frames per second
  strike     the frame that lands the blow
"""
import json
import os

import numpy as np
from PIL import Image
from scipy import ndimage as nd

import idle_walk_sheet

ROOT = idle_walk_sheet.ROOT
META = idle_walk_sheet.META
BG = np.array([243.0, 10.0, 220.0])  # the sheet's magenta
MIN_PIECE = 12  # px: smaller specks are dropped


def cut_cell(a):
    """RGBA float array (h, w, 4) of one cell: the magenta keyed out, edges kept soft, no pink under the arc's glow."""
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    strict = (r > 120) & (b > 120) & (g < 0.35 * np.minimum(r, b))
    m = np.minimum(r, b) - g  # how magenta a pixel is: about 230 on the background, about 0 or less on the art
    near = nd.binary_dilation(strict, iterations=5) & ~strict
    blend = near & (m > 25)  # the soft edge: part sprite, part background
    alpha = np.where(strict, 0.0, 1.0)
    est = np.clip(1.0 - m / 232.0, 0.0, 1.0)
    alpha = np.where(blend, est, alpha)
    alpha[alpha < 0.12] = 0.0
    rgb = a.copy()
    k = np.maximum(alpha, 1e-3)[..., None]
    mixed = (a - (1.0 - alpha)[..., None] * BG) / k  # the sprite's own colour: pixel = alpha * sprite + (1 - alpha) * magenta
    rgb = np.where(blend[..., None], np.clip(mixed, 0, 255), a)
    rgb = np.asarray(idle_walk_sheet.despill(rgb), dtype=np.float32)  # what pink is left in a violet glow comes off, as on the other sheets
    # drop specks
    lab, n = nd.label(alpha > 0.5)
    if n:
        sizes = nd.sum(alpha > 0.5, lab, range(1, n + 1))
        small = [i + 1 for i, s in enumerate(sizes) if s < MIN_PIECE]
        alpha[np.isin(lab, small)] = 0.0
    return np.dstack([rgb, alpha * 255.0])


def solid_box(rgba):
    """(x0, y0, x1, y1) of the drawn pixels (alpha over half), exclusive end."""
    ys, xs = np.nonzero(rgba[..., 3] > 127)
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def idle_figure_px(cfg):
    """The figure's height on the canvas in the character's built idle frames (median of the four directions): the
    attack is drawn at the same pixel size, so the character does not change size when he swings. `figure_px` is only
    the fallback when the idle frames are not there."""
    d = os.path.join(ROOT, 'assets', 'characters', cfg['key'], 'animations', 'idle')
    hs = []
    for dr in 'senw':
        for k in range(4):
            fn = os.path.join(d, 'idle_%s_%d.png' % (dr, k))
            if os.path.exists(fn):
                rows = np.nonzero((np.asarray(Image.open(fn).convert('RGBA'))[..., 3] > 0).any(1))[0]
                hs.append(rows[-1] - rows[0] + 1)
    return float(np.median(hs)) if hs else float(cfg['figure_px'])


def build(cfg):
    ROWS, COLS = cfg['rows'], cfg['cols']
    sheet = Image.open(os.path.join(ROOT, cfg['src'])).convert('RGB')
    assert sheet.size == tuple(cfg['size']), 'unexpected sheet size %s: the boxes are for %s' % (sheet.size, cfg['size'])
    a = np.asarray(sheet).astype(np.float32)
    cells = {(d, k): cut_cell(a[y0:y1, x0:x1]) for d, (y0, y1) in ROWS.items() for k, (x0, x1) in enumerate(COLS)}
    # the pixel size: the body as tall as in the idle (the first and last frames carry no arc)
    heights = [solid_box(cells[(d, k)])[3] - solid_box(cells[(d, k)])[1] for d in ROWS for k in (0, 3)]
    scale = idle_figure_px(cfg) / float(np.median(heights))
    # each direction's feet: where the boots are in its resting frames
    feet = {}
    for d in ROWS:
        xs, bottoms = [], []
        for k in (0, 3):
            solid = cells[(d, k)][..., 3] > 127
            counts = solid.sum(1)
            boots = int(np.nonzero(counts >= max(6, 0.15 * counts.max()))[0].max())  # the lowest wide row: the boots, not a sword tip below them
            band = solid[max(boots - 3, 0):boots + 1]
            xs.append(np.nonzero(band.any(0))[0].mean())
            bottoms.append(boots)
        feet[d] = (float(np.median(xs)), float(np.median(bottoms)))
    out_dir = os.path.join(ROOT, 'assets', 'characters', cfg['key'], 'animations', 'attack')
    os.makedirs(out_dir, exist_ok=True)
    cw, ch = cfg['canvas']
    fx, fy = cfg['feet']
    names = {}
    for d in ROWS:
        names[d] = []
        for k in range(4):
            img = Image.fromarray(np.clip(cells[(d, k)], 0, 255).astype(np.uint8), 'RGBA').convert('RGBa')
            sx = scale * cfg.get('widen', 1.0)
            w, h = round(img.width * sx), round(img.height * scale)
            small = img.resize((w, h), Image.LANCZOS).convert('RGBA')
            ox, oy = round(fx - feet[d][0] * sx), round(fy - feet[d][1] * scale)
            canvas = Image.new('RGBA', (cw, ch), (0, 0, 0, 0))
            sx0, sy0 = max(-ox, 0), max(-oy, 0)
            sx1, sy1 = min(w, cw - ox), min(h, ch - oy)
            canvas.alpha_composite(small.crop((sx0, sy0, sx1, sy1)), (ox + sx0, oy + sy0))
            fn = 'attack_%s_%d.png' % (d, k)
            canvas.save(os.path.join(out_dir, fn))
            names[d].append('animations/attack/' + fn)
    text = open(META, encoding='utf-8').read()
    meta = json.loads(text)
    indent = 1 if '\n "' in text else 2
    anims = meta[cfg['key']]['anims']
    meta[cfg['key']]['slash_in_frames'] = True  # the arc is drawn in his attack frames: the game adds no slash effect of its own
    for d, frames in names.items():
        anims['attack_' + d] = {'fps': cfg['fps'], 'loop': False, 'native': 'right', 'strike': cfg['strike'], 'frames': frames}
    with open(META, 'w', encoding='utf-8') as f:
        f.write(json.dumps(meta, indent=indent, ensure_ascii=False) + '\n')
    print('%s attack: 16 frames cut from %s (pixel scale %.4f, feet %s)' % (cfg['key'], cfg['src'], scale, {d: (round(x, 1), round(y, 1)) for d, (x, y) in feet.items()}))

