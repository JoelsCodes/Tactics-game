"""Alaric's new hand-drawn sheets (the owner's, Nov 2026), as the character `alaric_v2` (a candidate to replace the King's sheet; not wired to a unit).

  art_src/characters/alaric_v2_walk_sheet.png     640x1024: 5 frames x 8 rows of 128x128 cells, transparent background
  art_src/characters/alaric_v2_run_sheet.png      768x1024: 6 frames x 8 rows
  art_src/characters/alaric_v2_attack_sheet.png   1024x1024: 8 frames x 8 rows (two ready, two raised, two slash, two recovery)

The eight rows run S, SE, E, NE, N, NW, W, SW (clockwise from the front); the game draws four directions only, so the rows
S, E, N and W are used (rows 0, 2, 4, 6) and the diagonals are ignored. The sheets are transparent already, so there is no keying and
no resampling: the 128 px cells are placed on one canvas by the figure's feet (one shift per direction, from the walk's boots, so the
walk's bounce and the attack's crouch keep the way they were drawn), and `meta.json`'s scale is set from the idle figure (as tall as the
King, STANDARD_FIGURE). There is no idle sheet: the idle is the walk's first frame (the unit breathes in the game). No hurt, heavy, cast or
ko animation exists yet. The King's slash and eruption effects are borrowed for the blow (`effects_from`).

  python3 godot/tools/art/alaric_v2.py && godot --headless --path godot --import && godot --headless --path godot --script res://tools/build_resources.gd -- only=alaric_v2
"""
import json
import os

import numpy as np
from PIL import Image
from scipy import ndimage as nd

import idle_walk_sheet

ROOT = idle_walk_sheet.ROOT
META = idle_walk_sheet.META
KEY = 'alaric_v2'
CELL = 128
ROWS = {'s': 0, 'e': 2, 'n': 4, 'w': 6}
PAD = 32  # px either side of a cell: a blade that crosses into the next cell is given back to its own frame
CANVAS = (240, 172)
FEET = (120, 160)  # meta.json anchor is this plus one row
SHEETS = {'walk': ('art_src/characters/alaric_v2_walk_sheet.png', 5), 'run': ('art_src/characters/alaric_v2_run_sheet.png', 6),
          'attack': ('art_src/characters/alaric_v2_attack_sheet.png', 8)}
FPS = {'idle': 4, 'walk': 8, 'run': 10, 'attack': 14}
STRIKE = 4  # the first slash frame


def row_cells(sheet, row, n):
    """The n frames of one row as RGBA images (CELL + 2 PAD wide). The cells are packed edge to edge and a drawn blade or cape
    crosses a cell's border, so the row is labelled as one picture: every connected piece goes to the cell holding most of it, whole."""
    strip = np.asarray(sheet.crop((0, row * CELL, n * CELL, (row + 1) * CELL)))
    lab, count = nd.label(nd.binary_dilation(strip[..., 3] > 8, iterations=2), structure=np.ones((3, 3)))
    solid = strip[..., 3] > 0
    owner = np.zeros(count + 1, dtype=int)
    for i in range(1, count + 1):
        xs = np.nonzero(((lab == i) & solid).any(0))[0]
        owner[i] = int(np.bincount(np.clip(xs // CELL, 0, n - 1), minlength=n).argmax()) if len(xs) else 0
    out = []
    for k in range(n):
        keep = solid & (owner[lab] == k)
        frame = np.zeros((CELL, CELL + 2 * PAD, 4), dtype=np.uint8)
        x0, x1 = k * CELL - PAD, (k + 1) * CELL + PAD
        sx0, sx1 = max(x0, 0), min(x1, strip.shape[1])
        frame[:, sx0 - x0:sx1 - x0] = np.where(keep[:, sx0:sx1, None], strip[:, sx0:sx1], 0)
        speck, n = nd.label(frame[..., 3] > 0, structure=np.ones((3, 3)))  # stray bits of a neighbour's blade
        for i in range(1, n + 1):
            if (speck == i).sum() < 40:
                frame[speck == i] = 0
        out.append(Image.fromarray(frame, 'RGBA'))
    return out


def feet_of(img):
    """(x, y) of the boots in a cell: the lowest opaque row and the middle of the lowest four rows."""
    a = np.asarray(img)[..., 3] > 127
    rows = np.nonzero(a.any(1))[0]
    y = rows[-1]
    cols = np.nonzero(a[max(y - 3, 0):y + 1].any(0))[0]
    return (cols.min() + cols.max()) / 2.0, float(y)


def build():
    sheets = {}
    for kind, (path, n) in SHEETS.items():
        im = Image.open(os.path.join(ROOT, path)).convert('RGBA')
        assert im.size == (n * CELL, 8 * CELL), (kind, im.size)
        sheets[kind] = im
    out_dir = os.path.join(ROOT, 'assets', 'characters', KEY, 'animations')
    # one shift per direction, from the walk's boots: the median of its five frames
    cells = {(kind, d): row_cells(sheet, row, SHEETS[kind][1]) for kind, sheet in sheets.items() for d, row in ROWS.items()}
    shift = {}
    idle_frame = {}
    for d, row in ROWS.items():
        fs = [feet_of(c) for c in cells[('walk', d)]]
        # the idle: the walk frame with the feet closest together (a standing pose, not mid-stride)
        spread = [(np.asarray(c)[-14:, :, 3] > 127).any(0).nonzero()[0] for c in cells[('walk', d)]]
        idle_frame[d] = int(np.argmin([(sp.max() - sp.min()) if len(sp) else 999 for sp in spread]))
        shift[d] = (round(FEET[0] - float(np.median([f[0] for f in fs]))), round(FEET[1] - float(np.median([f[1] for f in fs]))))
    anims = {}
    for kind in list(sheets) + ['idle']:
        n = 1 if kind == 'idle' else SHEETS[kind][1]
        os.makedirs(os.path.join(out_dir, kind), exist_ok=True)
        for d, row in ROWS.items():
            files = []
            for k in range(n):
                c = cells[('walk', d)][idle_frame[d]] if kind == 'idle' else cells[(kind, d)][k]
                canvas = Image.new('RGBA', CANVAS, (0, 0, 0, 0))
                canvas.alpha_composite(c, shift[d])  # the cell as it is, soft edges included
                fn = '%s_%s_%d.png' % (kind, d, k)
                canvas.save(os.path.join(out_dir, kind, fn))
                files.append('animations/%s/%s' % (kind, fn))
            if kind == 'attack':
                anims['attack_' + d] = {'fps': FPS[kind], 'loop': False, 'native': 'right', 'strike': STRIKE, 'frames': files}
            else:
                anims['%s_%s' % (kind, d)] = {'fps': FPS[kind], 'loop': True, 'native': 'none', 'dir': d, 'frames': files}
    for kind in ('idle', 'walk'):  # the older front and back names (the portrait crop of UnitLook reads idle_f)
        for alias, d in (('f', 's'), ('b', 'n')):
            anims['%s_%s' % (kind, alias)] = {'fps': FPS[kind], 'loop': True, 'native': 'left', 'dir': d, 'frames': list(anims['%s_%s' % (kind, d)]['frames'])}
    text = open(META, encoding='utf-8').read()
    meta = json.loads(text)
    indent = 1 if '\n "' in text else 2
    entry = {'size': list(CANVAS), 'anchor': [FEET[0], FEET[1] + 1], 'scale': 1.0, 'eight_dir': True, 'anims': anims}
    entry['scale'] = idle_walk_sheet.standard_scale(out_dir)
    king = meta['king']
    if 'effects' in king:  # the King's slash and eruption play for the blow
        entry['effects'] = king['effects']
        entry['effects_from'] = 'king'
    meta[KEY] = entry
    with open(META, 'w', encoding='utf-8') as f:
        f.write(json.dumps(meta, indent=indent, ensure_ascii=False) + '\n')
    print('%s: feet shift %s, scale %s, the canvas holds every cell' % (KEY, shift, entry['scale']))


if __name__ == '__main__':
    build()
