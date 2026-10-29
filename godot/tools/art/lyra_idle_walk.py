"""Lyra's idle and walk animations, cut from the owner's four-direction sheet.

  art_src/characters/lyra_idle_walk_sheet.png   top row IDLE, bottom row WALK; the panels are DOWN, RIGHT, UP and LEFT,
                                                four frames each (the direction changes every 4)

These frames are Lyra's idle and walk for the rest of the game, so this step is part of the rebuild (the same as
king_idle_walk.py). Run it after eight_dir.py (which cuts her other animations and writes meta.json):

  python3 godot/tools/art/eight_dir.py && python3 godot/tools/art/lyra_idle_walk.py && python3 godot/tools/art/char_extras.py

What it does:
  - cuts each sprite out of its cell (magenta background and its tint removed), scales every frame by one shared
    factor so the figure matches her other animations (75 px tall on the shared 118x94 canvas), and puts the feet on
    the sheet's anchor so she stands centred on her tile;
  - writes assets/characters/mira/animations/{idle,walk}/<kind>_<s|e|n|w>_<0..3>.png (her sheet's folder is still `mira`);
  - points meta.json's mira idle_<dir> and walk_<dir> at them: s, e, n, w use their own panel; the diagonals use the
    front art (se, sw) or the back art (ne, nw), because the game draws four directions only.
Paths are relative to the godot/ folder.
"""
import json
import os

import numpy as np
from PIL import Image
from scipy import ndimage as nd

import idle_walk_sheet

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
SRC = os.path.join(ROOT, 'art_src', 'characters', 'lyra_idle_walk_sheet.png')
META = os.path.join(ROOT, 'assets', 'characters', 'meta.json')
OUT = os.path.join(ROOT, 'assets', 'characters', 'mira', 'animations')
KEY = 'mira'  # her sheet's id in meta.json and on disk (the unit is named Lyra)

CANVAS = (118, 94)   # her shared frame size (meta.json size)
FEET = (58, 91)      # the feet, as meta.json's anchor (58, 92) on her other frames
FIGURE_PX = 75.0     # her figure's height on the canvas, as on her other animations
PANELS = {'s': (5, 440), 'e': (448, 882), 'n': (890, 1325), 'w': (1333, 1768)}  # DOWN, RIGHT, UP, LEFT: x ranges
ROWS = {'idle': (88, 436), 'walk': (526, 881)}  # y ranges
FRAMES = 4
USES = {'s': 's', 'e': 'e', 'n': 'n', 'w': 'w', 'se': 's', 'sw': 's', 'ne': 'n', 'nw': 'n'}


def cut_sprite(sheet, magenta, kind, panel, k):
    y0, y1 = ROWS[kind]
    x0, x1 = PANELS[panel]
    px0, px1 = x0 + 2, x1 - 2
    whole = nd.binary_opening(~magenta[y0:y1, px0:px1], np.ones((3, 3)))
    lab, n = nd.label(whole)
    sizes = nd.sum(whole, lab, range(1, n + 1))
    comps = [i + 1 for i, sz in enumerate(sizes) if sz > 600]
    if len(comps) == FRAMES:
        # the four sprites are separate shapes (a wide ponytail or cloak may pass the cell's edge): cut each whole
        comps.sort(key=lambda i: np.nonzero(lab == i)[1].min())
        mask = nd.binary_fill_holes(lab == comps[k])
        mask = mask & ~magenta[y0:y1, px0:px1]
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


def to_frame(crop, scale):
    w, h = round(crop.width * scale), round(crop.height * scale)
    small = crop.resize((w, h), Image.LANCZOS)
    out = Image.new('RGBA', CANVAS, (0, 0, 0, 0))
    out.alpha_composite(small, (FEET[0] - w // 2, FEET[1] - h + 1))
    return out


def main():
    sheet = Image.open(SRC).convert('RGB')
    assert sheet.size == (1774, 887), 'unexpected sheet size %s: the panel boxes above are for 1774x887' % (sheet.size,)
    a = np.asarray(sheet).astype(np.float32)
    R, G, B = a[..., 0], a[..., 1], a[..., 2]
    magenta = (R > 150) & (B > 150) & (G < 0.5 * np.minimum(R, B))  # the background and its tint
    sheet = idle_walk_sheet.despill(a)  # the cut-out sprites carry no pink edge
    crops = {(kind, panel, k): cut_sprite(sheet, magenta, kind, panel, k) for kind in ROWS for panel in PANELS for k in range(FRAMES)}
    # one shared scale from the median idle figure, so her proportions stay the same across every frame
    # one pixel size for idle and walk (the idle sets it): the pose may change her height a little, her size does not
    idle_scale = FIGURE_PX / float(np.median([c.height for (kd, _p, _k), c in crops.items() if kd == 'idle']))
    scale = {kind: idle_scale for kind in ROWS}
    for (kind, panel, k), crop in crops.items():
        os.makedirs(os.path.join(OUT, kind), exist_ok=True)
        to_frame(crop, scale[kind]).save(os.path.join(OUT, kind, '%s_%s_%d.png' % (kind, panel, k)))
    text = open(META, encoding='utf-8').read()
    meta = json.loads(text)
    indent = 2 if '\n  "' in text else 1
    anims = meta[KEY]['anims']
    for kind in ROWS:
        for d, panel in USES.items():
            anims['%s_%s' % (kind, d)]['frames'] = ['animations/%s/%s_%s_%d.png' % (kind, kind, panel, k) for k in range(FRAMES)]
    with open(META, 'w', encoding='utf-8') as f:
        f.write(json.dumps(meta, indent=indent, ensure_ascii=False) + '\n')
    print('lyra idle and walk: %d frames cut from %s (scale idle %.4f, walk %.4f)' % (len(crops), os.path.relpath(SRC, ROOT), scale['idle'], scale['walk']))


if __name__ == '__main__':
    main()
