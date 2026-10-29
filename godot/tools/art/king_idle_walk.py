"""The King's idle and walk animations, cut from the owner's four-direction sheet.

  art_src/characters/king_idle_walk_sheet.png   top row IDLE, bottom row WALK; the panels are DOWN (front), RIGHT,
                                                UP (back) and LEFT, four frames each (the direction changes every 4)

The owner's decision: these frames are the King's idle and walk for the rest of the game, so this step is part of
the rebuild. Run it after eight_dir.py (which cuts the King's other animations and writes meta.json):

  python3 godot/tools/art/eight_dir.py && python3 godot/tools/art/king_idle_walk.py && python3 godot/tools/art/king_extras.py

What it does:
  - cuts each sprite as a whole shape (a swinging arm or coat tail may cross its cell's edge; magenta background and
    its tint removed), scales the walk so its figure is about 61 px tall on the shared 133x74 canvas and the idle to
    the walk's height, makes him WIDEN (5%) wider, and puts the feet on the sheet's anchor so he stands centred on
    his tile;
  - writes assets/characters/king/animations/{idle,walk}/<kind>_<s|e|n|w>_<0..3>.png;
  - points meta.json's king idle_<dir> and walk_<dir> at them: s, e, n, w use their own panel; the diagonals use the
    front art (se, sw) or the back art (ne, nw), so a unit never shows a diagonal or a side-on pose by accident.
Run from anywhere; paths are relative to the godot/ folder.
"""
import json
import os

import numpy as np
from PIL import Image
from scipy import ndimage as nd

import idle_walk_sheet

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
SRC = os.path.join(ROOT, 'art_src', 'characters', 'king_idle_walk_sheet.png')
META = os.path.join(ROOT, 'assets', 'characters', 'meta.json')
OUT = os.path.join(ROOT, 'assets', 'characters', 'king', 'animations')

CANVAS = (133, 74)   # the King's shared frame size (meta.json size)
ANCHOR = (60, 68)    # the feet, as meta.json's anchor (60, 69) on the other frames
SHEET_FIGURE = 183.0  # the idle figure's height on the sheet, in px
SCALE = 64.0 / SHEET_FIGURE  # the King's figure is 64 px tall on the canvas
WIDEN = 1.05  # the owner wants him 5% wider (height unchanged)
PANELS = {'s': (92, 457), 'e': (462, 803), 'n': (808, 1168), 'w': (1175, 1530)}  # DOWN, RIGHT, UP, LEFT: x ranges
ROWS = {'idle': (84, 406), 'walk': (418, 688)}  # y ranges
FRAMES = 4
MARGIN = 16  # px the cut window reaches past each side of a frame's cell
# the other four directions use the nearest drawn view that faces the camera or away from it
USES = {'s': 's', 'e': 'e', 'n': 'n', 'w': 'w', 'se': 's', 'sw': 's', 'ne': 'n', 'nw': 'n'}


def cut_sprite(rgb, dist, magenta, kind, panel, k):
    y0, y1 = ROWS[kind]
    x0, x1 = PANELS[panel]
    w = (x1 - x0) / float(FRAMES)
    # the sprite is cut as a whole shape from a window wider than its cell: a swinging arm, hand or coat tail may
    # cross the cell's edge, and a cut at the edge would clip it. The shape kept is the one covering most of the cell
    c0, c1 = int(x0 + k * w) + 3, int(x0 + (k + 1) * w) - 3
    cx0, cx1 = max(c0 - MARGIN, x0), min(c1 + MARGIN, x1)  # within the panel: its border line is not the sprite
    sub = (dist[y0:y1, cx0:cx1] > 90) & ~magenta[y0:y1, cx0:cx1]
    sub = nd.binary_opening(sub, np.ones((3, 3)))
    lab, n = nd.label(sub)
    inside = lab[:, c0 - cx0:c1 - cx0]
    sizes = nd.sum(np.ones_like(inside), inside, range(1, n + 1))
    i = int(np.argmax(sizes)) + 1
    mask = nd.binary_fill_holes(lab == i) & ~magenta[y0:y1, cx0:cx1]
    ys, xs = np.nonzero(mask)
    box = (cx0 + xs.min(), y0 + ys.min(), cx0 + xs.max() + 1, y0 + ys.max() + 1)
    crop = rgb.crop(box).convert('RGBA')
    m = mask[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    crop.putalpha(Image.fromarray((m * 255).astype(np.uint8)))
    return crop


def to_frame(crop, scale):
    w, h = round(crop.width * scale * WIDEN), round(crop.height * scale)
    small = crop.resize((w, h), Image.LANCZOS)
    out = Image.new('RGBA', CANVAS, (0, 0, 0, 0))
    out.alpha_composite(small, (ANCHOR[0] - w // 2, ANCHOR[1] - h + 1))
    return out


def main():
    sheet = Image.open(SRC).convert('RGB')
    assert sheet.size == (1536, 1024), 'unexpected sheet size %s: the panel boxes above are for 1536x1024' % (sheet.size,)
    a = np.asarray(sheet).astype(np.float32)
    dist = np.sqrt(((a - np.array([255, 0, 255])) ** 2).sum(-1))
    R, G, B = a[..., 0], a[..., 1], a[..., 2]
    magenta = (R > 110) & (B > 110) & (G < 0.62 * np.minimum(R, B))  # the background and its tint
    sheet = idle_walk_sheet.despill(a)  # the cut-out sprites carry no pink edge
    crops = {(kind, panel, k): cut_sprite(sheet, dist, magenta, kind, panel, k) for kind in ROWS for panel in PANELS for k in range(FRAMES)}
    # the idle is drawn at the walk's height: the owner wants his standing figure to be the size of his walk frames.
    # The walk keeps its scale; the idle is scaled so its median figure height equals the walk's
    med = {kind: float(np.median([c.height for (kd, _p, _k), c in crops.items() if kd == kind])) for kind in ROWS}
    scale = {'walk': SCALE, 'idle': SCALE * med['walk'] / med['idle']}
    for (kind, panel, k), crop in crops.items():
        os.makedirs(os.path.join(OUT, kind), exist_ok=True)
        to_frame(crop, scale[kind]).save(os.path.join(OUT, kind, '%s_%s_%d.png' % (kind, panel, k)))
    text = open(META, encoding='utf-8').read()
    meta = json.loads(text)
    indent = 1 if '\n "' in text else 2  # keep the file's own indent (a top-level key sits one indent in)
    anims = meta['king']['anims']
    meta['king']['scale'] = idle_walk_sheet.standard_scale(OUT)  # he sets the size standard: 2.0 for his 60 px idle
    for kind in ROWS:
        for d, panel in USES.items():
            anims['%s_%s' % (kind, d)]['frames'] = ['animations/%s/%s_%s_%d.png' % (kind, kind, panel, k) for k in range(FRAMES)]
    with open(META, 'w', encoding='utf-8') as f:
        f.write(json.dumps(meta, indent=indent, ensure_ascii=False) + '\n')
    print('king idle and walk: %d frames cut from %s (scale idle %.4f, walk %.4f; meta scale %.4f)' % (len(crops), os.path.relpath(SRC, ROOT), scale['idle'], scale['walk'], meta['king']['scale']))


if __name__ == '__main__':
    main()
