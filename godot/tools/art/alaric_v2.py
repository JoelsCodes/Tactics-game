"""Alaric's new hand-drawn sheets (the owner's, Nov 2026), as the character `alaric_v2` (a candidate to replace the King's sheet; not wired to a unit).

  art_src/characters/alaric_v2_walk_sheet.png     640x1024: 5 frames x 8 rows of 128x128 cells, transparent background
  art_src/characters/alaric_v2_run_sheet.png      768x1024: 6 frames x 8 rows
  art_src/characters/alaric_v2_attack_sheet.png   1024x1024: 8 frames x 8 rows (two ready, two raised, two slash, two recovery)

The eight rows run S, SE, E, NE, N, NW, W, SW (clockwise from the front) and all eight are used (the owner lifted the four-direction
rule for this character: `meta.json` `dirs8`, see SpriteAnimator). The sheets are transparent already, so there is no keying and
no resampling: the 128 px cells are placed on one canvas by the figure's feet (one shift per direction, from the walk's boots, so the
walk's bounce and the attack's crouch keep the way they were drawn), and `meta.json`'s scale is set from the idle figure (as tall as the
King, STANDARD_FIGURE). The idle is the owner's own idle sheet (8 frames, drawn larger: cleaned, brought down to the walk's figure height and given its edge colour). No hurt, heavy, cast or
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
ROWS = {'s': 0, 'se': 1, 'e': 2, 'ne': 3, 'n': 4, 'nw': 5, 'w': 6, 'sw': 7}  # all eight (owner, Nov 2026: use all directions)
PAD = 32  # px either side of a cell: a blade that crosses into the next cell is given back to its own frame
CANVAS = (240, 172)
FEET = (120, 160)  # meta.json anchor is this plus one row
SHEETS = {'walk': ('art_src/characters/alaric_v2_walk_sheet.png', 5), 'run': ('art_src/characters/alaric_v2_run_sheet.png', 6),
          'attack': ('art_src/characters/alaric_v2_attack_sheet.png', 8)}
IDLE_SHEET = 'art_src/characters/alaric_v2_idle_sheet.png'  # 1254x1254: 8 frames x 8 rows of 156.75 px cells, drawn larger than the others
IDLE_FRAMES = 8
FPS = {'idle': 7, 'walk': 8, 'run': 10, 'attack': 14}
STRIKE = 4  # the first slash frame


def row_cells(sheet, row, n):
    """The n frames of one row as RGBA images (CELL + 2 PAD wide). The cells are packed edge to edge and a drawn blade or cape
    crosses a cell's border, so each cell is first cut by position; then a small piece touching a cell's border that continues into the
    neighbour's figure (its pixels across the border belong to the neighbour's main piece) is given to that neighbour, whole. Frames that
    touch one another cannot be told apart by connection alone, which is why this works cell by cell and not on the whole row."""
    strip = np.asarray(sheet.crop((0, row * CELL, n * CELL, (row + 1) * CELL)))
    solid = strip[..., 3] > 0
    owner = np.full(solid.shape, -1, dtype=int)  # which frame each drawn pixel belongs to
    mains = []
    pieces = []  # (cell, mask of the piece in the strip)
    for k in range(n):
        region = np.zeros_like(solid)
        region[:, k * CELL:(k + 1) * CELL] = solid[:, k * CELL:(k + 1) * CELL]
        lab, count = nd.label(region, structure=np.ones((3, 3)))
        sizes = nd.sum(region, lab, range(1, count + 1)) if count else []
        main = int(np.argmax(sizes)) + 1 if count else 0
        mains.append(main)
        for i in range(1, count + 1):
            m = lab == i
            owner[m] = k
            pieces.append([k, m, i == main])
    for _ in range(3):  # a piece that continues across a border goes to the cell on the other side
        for piece in pieces:
            k, m, is_main = piece
            if is_main:
                continue
            for step, edge in ((-1, k * CELL), (1, (k + 1) * CELL - 1)):
                nb = k + step
                if nb < 0 or nb >= n:
                    continue
                col = edge
                rows = np.nonzero(m[:, col])[0]
                if len(rows) == 0:
                    continue
                across = col + step
                if solid[rows, across].any() and (owner[rows, across][solid[rows, across]] == nb).any():
                    owner[m] = nb
                    piece[0] = nb
                    break
    out = []
    for k in range(n):
        frame = np.zeros((CELL, CELL + 2 * PAD, 4), dtype=np.uint8)
        x0, x1 = k * CELL - PAD, (k + 1) * CELL + PAD
        sx0, sx1 = max(x0, 0), min(x1, strip.shape[1])
        keep = solid & (owner == k)
        frame[:, sx0 - x0:sx1 - x0] = np.where(keep[:, sx0:sx1, None], strip[:, sx0:sx1], 0)
        speck, cnt = nd.label(frame[..., 3] > 0, structure=np.ones((3, 3)))  # floating bits that belong to no figure
        for i in range(1, cnt + 1):
            if (speck == i).sum() < 40:
                frame[speck == i] = 0
        out.append(Image.fromarray(frame, 'RGBA'))
    return out


def edge_colour(frames):
    """The outline colour of the walk sheet (the sheet that has one): the median of its outermost pixels."""
    px = []
    for f in frames:
        a = np.asarray(f)
        solid = a[..., 3] > 127
        edge = solid & ~nd.binary_erosion(solid)
        px.append(a[edge][:, :3])
    return tuple(int(v) for v in np.median(np.concatenate(px), axis=0))


def crisp(img, colour, cut=90):
    """The run and attack sheets are drawn with soft, outline-less edges, unlike the walk's crisp dark ones. Make them match: the soft alpha
    becomes pixel art (on or off), and a one-pixel outline in the walk sheet's colour goes round the figure."""
    a = np.array(img)
    solid = a[..., 3] >= cut
    ring = nd.binary_dilation(solid, structure=np.array([[0, 1, 0], [1, 1, 1], [0, 1, 0]])) & ~solid
    a[..., 3] = np.where(solid, 255, 0)
    a[ring] = (*colour, 255)
    a[~solid & ~ring] = 0
    return Image.fromarray(a, 'RGBA')


def rim(img, colour, cut=128):
    """Hard alpha, and the figure's own outermost pixels painted in the outline colour (no ring is added: the silhouette keeps its size)."""
    a = np.array(img)
    solid = a[..., 3] >= cut
    a[..., 3] = np.where(solid, 255, 0)
    a[~solid] = 0
    edge = solid & ~nd.binary_erosion(solid)
    a[edge] = (*colour, 255)
    return Image.fromarray(a, 'RGBA')


def idle_frames(walk_height, outline):
    """The idle sheet: 8 frames x 8 rows, drawn at a larger size and with a faint noise of nearly transparent pixels (and a red fringe) around
    the figure. Each cell is cleaned (only the solid figure stays), brought down to the walk's figure height, and given the walk's edge colour,
    so the idle matches the other animations. Returns {(dir, k): image the size of a scaled cell}."""
    sheet = Image.open(os.path.join(ROOT, IDLE_SHEET)).convert('RGBA')
    n = sheet.width / 8.0
    cells = {}
    heights = []
    for d, row in ROWS.items():
        for k in range(IDLE_FRAMES):
            c = np.array(sheet.crop((round(k * n), round(row * n), round((k + 1) * n), round((row + 1) * n))))
            solid = c[..., 3] >= 128
            lab, cnt = nd.label(solid, structure=np.ones((3, 3)))
            for i in range(1, cnt + 1):
                if (lab == i).sum() < 40:
                    solid[lab == i] = False
            c[..., 3] = np.where(solid, 255, 0)
            c[~solid] = 0
            ys = np.nonzero(solid.any(1))[0]
            heights.append(ys[-1] - ys[0] + 1)
            cells[(d, k)] = Image.fromarray(c, 'RGBA')
    f = walk_height / float(np.median(heights))
    out = {}
    for key, img in cells.items():
        small = img.convert('RGBa').resize((round(img.width * f), round(img.height * f)), Image.LANCZOS).convert('RGBA')
        out[key] = rim(small, outline)
    return out, f


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
    for d, row in ROWS.items():
        fs = [feet_of(c) for c in cells[('walk', d)]]
        shift[d] = (round(FEET[0] - float(np.median([f[0] for f in fs]))), round(FEET[1] - float(np.median([f[1] for f in fs]))))
    outline = edge_colour([f for d in ROWS for f in cells[('walk', d)]])
    walk_height = float(np.median([np.ptp(np.nonzero((np.asarray(c)[..., 3] > 127).any(1))[0]) + 1 for d in ROWS for c in cells[('walk', d)]]))
    idle, idle_scale = idle_frames(walk_height, outline)
    ishift = {}
    for d in ROWS:
        fs = [feet_of(idle[(d, k)]) for k in range(IDLE_FRAMES)]
        ishift[d] = (round(FEET[0] - float(np.median([f[0] for f in fs]))), round(FEET[1] - float(np.median([f[1] for f in fs]))))
    anims = {}
    for kind in list(sheets) + ['idle']:
        n = IDLE_FRAMES if kind == 'idle' else SHEETS[kind][1]
        os.makedirs(os.path.join(out_dir, kind), exist_ok=True)
        for d, row in ROWS.items():
            files = []
            for k in range(n):
                c = idle[(d, k)] if kind == 'idle' else cells[(kind, d)][k]
                if kind in ('run', 'attack'):
                    c = crisp(c, outline)
                canvas = Image.new('RGBA', CANVAS, (0, 0, 0, 0))
                canvas.alpha_composite(c, ishift[d] if kind == 'idle' else shift[d])  # the cell as it is
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
    entry = {'size': list(CANVAS), 'anchor': [FEET[0], FEET[1] + 1], 'scale': 1.0, 'eight_dir': True, 'dirs8': True, 'anims': anims}
    entry['scale'] = idle_walk_sheet.standard_scale(out_dir)
    king = meta['king']
    if 'effects' in king:  # the King's slash and eruption play for the blow
        entry['effects'] = king['effects']
        entry['effects_from'] = 'king'
    meta[KEY] = entry
    with open(META, 'w', encoding='utf-8') as f:
        f.write(json.dumps(meta, indent=indent, ensure_ascii=False) + '\n')
    print('%s: feet shift %s, scale %s, outline colour %s' % (KEY, shift, entry['scale'], outline))


if __name__ == '__main__':
    build()
