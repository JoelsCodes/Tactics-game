"""The abandoned castle tile set, cut from the owner's three cube sheets:

  art_src/tiles/abandoned_castle_walls.jpg   floor slabs, brick wall cubes and corners, arches, doors, pillars
  art_src/tiles/abandoned_castle_ruins.jpg   tower, carved slabs, mossy slabs, the sword dais, statues, pillars
  art_src/tiles/abandoned_castle_props.jpg   fountain, throne dais, chests, gates, racks, gargoyles, slabs

Every piece is an isometric cube on a flat dark background. CUBES gives each cube used a hand-placed box on its
sheet; inside the box the cube is keyed from the box's edge, its top diamond is found from its outline (top, left
and right corners; the bottom corner follows), and the top face is un-skewed into a square, and its left and right
side faces into rectangles. Writes into assets/tiles/:

  castle_NN, castlemoss_NN, castlecarved_NN, castleframed_NN.png   tile tops (one cube's top per tile, not blended)
  side_castlesoil_l/r.png                                  the slabs' stone lip over the dirt cliff, a strip that
                                                           wraps every 4 tiles, for raised floor
  side_castlewall_l/r.png                                  sandstone brick, for walls and the throne dais

  python3 godot/tools/art/castle_tiles.py [--debug]        (--debug saves the found faces drawn on the sheets)
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as nd

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
SRC = os.path.join(ROOT, 'art_src', 'tiles')
OUT = os.path.join(ROOT, 'assets', 'tiles')
TOP_PX = 256  # tile tops are saved at this size (the slabs carry far more detail than the old 96 px tops)

# Each cube is given by its sheet, its top corner (x, y) and its half width; the top face is a 2:1 diamond, so its
# left and right corners are half a width out and a quarter width down, and its bottom corner half a width down.
# (Found from the outlines, then placed by hand where cubes touch and the outline runs into a neighbour.)
CUBES = {
    # one clean flagstone slab for the whole floor (the owner's choice: the same piece throughout); the slabs with moss
    # or dirt patches are the overgrown floor
    'castle': [('walls', 280, 77, 184)],
    'castlemoss': [('walls', 918, 66, 186), ('walls', 1051, 955, 200), ('ruins', 295, 1100, 204), ('ruins', 1300, 1104, 200),
                   ('props', 292, 1100, 204), ('walls', 1300, 814, 163), ('ruins', 799, 1105, 200), ('props', 801, 1104, 200),
                   ('props', 1296, 1104, 200)],
    'castlecarved': [('ruins', 556, 944, 200)],  # the medallion slab
    'castleframed': [('ruins', 1051, 954, 200)],  # the slab with a carved border
}
# the thick bottom-row slabs: (sheet, top corner, half width, depth of the stone lip and soil under the top face)
SOIL_SIDES = [('walls', 294, 1100, 205, 70), ('ruins', 295, 1100, 204, 70), ('ruins', 799, 1105, 200, 70),
              ('props', 292, 1100, 204, 70), ('props', 801, 1104, 200, 70), ('props', 1296, 1104, 200, 70)]
# a sandstone brick face, between the wall's cap and its mossy foundation: upper-left, upper-right corners, height
BRICK_FACE = ('walls', (292, 463), (466, 378), 100)  # the lit (right) face of the corner wall
ASPECT = .515  # the diamond's height over its width
SIDE_TEXELS = 135.75  # wall-strip pixels per world unit of height (Board3D.SIDE_TEXELS); 96 px per tile across


def corners(tx, ty, hw):
    T = np.array([tx, ty], float)
    hh = hw * ASPECT
    return T, T + (-hw, hh), T + (hw, hh), T + (0, 2 * hh)  # top, left, right, bottom


_sheets = {}


def sheet(name):
    if name not in _sheets:
        _sheets[name] = np.asarray(Image.open(os.path.join(SRC, 'abandoned_castle_%s.jpg' % name)).convert('RGB')).astype(np.float32)
    return _sheets[name]


def _unused_cube(name, x0, y0, x1, y1):
    """The cube in a box: its mask (background keyed from the box edge, largest piece) and its corners."""
    a = sheet(name)
    crop = a[y0:y1, x0:x1]
    bg = np.median(np.concatenate([crop[0], crop[-1], crop[:, 0], crop[:, -1]]), axis=0)
    near = np.sqrt(((crop - bg) ** 2).sum(-1)) < 38
    lab, _n = nd.label(near)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    fg = nd.binary_opening(~np.isin(lab, list(edge)), np.ones((3, 3)))
    lab2, n2 = nd.label(fg)
    # the piece under the box's centre (a neighbouring cube may reach into the box)
    cy, cx = fg.shape[0] // 2, fg.shape[1] // 2
    near_c = lab2[max(cy - 20, 0):cy + 20, max(cx - 20, 0):cx + 20]
    ids, counts = np.unique(near_c[near_c > 0], return_counts=True)
    mask = lab2 == (ids[np.argmax(counts)] if len(ids) else int(np.argmax(nd.sum(fg, lab2, range(1, n2 + 1)))) + 1)
    ys, xs = np.nonzero(mask)
    top_y = ys.min()
    T = np.array([xs[ys <= top_y + 2].mean(), top_y])
    lx, rx = xs.min(), xs.max()
    L = np.array([lx, ys[xs <= lx + 2].min()])
    R = np.array([rx, ys[xs >= rx - 2].min()])
    B = L + R - T
    depth = ys[xs <= lx + 2].max() - L[1]  # the cube's height under its left corner
    return crop, mask, T, L, R, B, depth, (x0, y0)


def quad(img, pts, size):
    """`pts` = (ul, ll, lr, ur) on `img` (an RGB array) mapped to a `size` rectangle."""
    data = tuple(float(v) for p in pts for v in p)
    return Image.fromarray(img.astype(np.uint8)).transform(size, Image.QUAD, data=data, resample=Image.BICUBIC)


def shrink(pts, c, k):
    return [c + (p - c) * k for p in pts]


def top_face(name, tx, ty, hw, k=.9):
    T, L, R, B = corners(tx, ty, hw)
    c = (L + R) / 2
    return quad(sheet(name), shrink([T, L, B, R], c, k), (TOP_PX, TOP_PX))


def side_face(name, tx, ty, hw, depth, kind):
    """A cube's left ('l') or right ('r') side face, rectified to 96 px a tile wide, the height at the same scale."""
    T, L, R, B = corners(tx, ty, hw)
    a, b = (L, B) if kind == 'l' else (B, R)
    inset = (b - a) * .04
    a, b = a + inset, b - inset
    down = np.array([0, depth])
    h = int(round(SIDE_TEXELS * depth / np.linalg.norm(b - a)))  # a tile's edge on the sheet is one world unit
    return quad(sheet(name), [a, a + down, b + down, b], (96, h))


def wrap(img):
    """Seamless in both directions: cross-faded with a copy rolled by half its size, the copy showing at the edges."""
    a = np.asarray(img.convert('RGB')).astype(np.float32)
    for axis in (1, 0):
        n = a.shape[axis]
        rolled = np.roll(a, n // 2, axis=axis)
        u = (np.arange(n) + .5) / n * 2 - 1
        w = np.cos(np.pi * u / 2) ** 2
        w = w[None, :, None] if axis == 1 else w[:, None, None]
        a = a * w + rolled * (1 - w)
    return Image.fromarray(a.clip(0, 255).astype(np.uint8))


def brick_strip(height=900):
    name, ul, ur, h = BRICK_FACE
    ul, ur = np.array(ul, float), np.array(ur, float)
    down = np.array([0, h])
    w = 96
    face = quad(sheet(name), [ul, ul + down, ur + down, ur], (w, int(round(SIDE_TEXELS * h / np.linalg.norm(ur - ul)))))
    tile = wrap(face)
    out = Image.new('RGB', (384, height))
    for y in range(0, height, tile.height):
        for x in range(0, 384, w):
            out.paste(tile, (x, y))
    return out


def strip(faces, height=900, mirror=True):
    """Faces feathered side by side into a strip that wraps every 384 px (4 tiles), extended down to `height`."""
    while len(faces) < 8:
        faces = faces + faces
    faces = faces[:8]
    fh = min(f.height for f in faces)
    acc = np.zeros((fh, 384, 3), np.float32)
    wsum = np.zeros((fh, 384, 1), np.float32)
    u = (np.arange(96) + .5) / 96 * 2 - 1
    win = (np.cos(np.pi * u / 2) ** 2).astype(np.float32)[None, :, None]
    for i, f in enumerate(faces):
        a = np.asarray(f.convert('RGB').crop((0, 0, 96, fh))).astype(np.float32)
        xs = (np.arange(96) + i * 48 - 24) % 384
        acc[:, xs] += a * win
        wsum[:, xs] += win
    s = Image.fromarray((acc / np.maximum(wsum, 1e-3)).clip(0, 255).astype(np.uint8), 'RGB')
    tall = Image.new('RGB', (384, height))
    tall.paste(s, (0, 0))
    y, flip = fh, True
    lower = s.crop((0, int(fh * .45), 384, fh))
    while y < height:
        tall.paste(lower.transpose(Image.FLIP_TOP_BOTTOM) if (flip and mirror) else lower, (0, y))
        y += lower.height
        flip = not flip
    return tall


def soil_strip(faces, height=900, lip_frac=.3):
    """The slabs' stone lip on top; under it the dirt cliff the other terrains use (side_dirtblk_l.png, from
    castle_ruins.jpg): the slabs' own soil band is too thin to repeat down a tall side without stripes."""
    s = strip(faces, mirror=False)
    lip = int(min(f.height for f in faces) * lip_frac)
    dirt = Image.open(os.path.join(OUT, 'side_dirtblk_l.png')).convert('RGB')
    out = Image.new('RGB', (384, height))
    out.paste(dirt.crop((0, 0, 384, height - lip)), (0, lip))
    lip_img = s.crop((0, 0, 384, lip + 6))
    m = Image.linear_gradient('L').resize((384, lip + 6)).point(lambda v: 255 if v < 200 else int((255 - v) * 255 / 55))
    out.paste(lip_img, (0, 0), m)  # the lip's lower edge fades into the dirt
    return out


def debug():
    for name in ('walls', 'ruins', 'props'):
        im = Image.open(os.path.join(SRC, 'abandoned_castle_%s.jpg' % name)).convert('RGB')
        d = ImageDraw.Draw(im)
        for sh, tx, ty, hw in [c for cs in CUBES.values() for c in cs]:
            if sh == name:
                T, L, R, B = corners(tx, ty, hw)
                d.polygon([tuple(T), tuple(R), tuple(B), tuple(L)], outline=(0, 255, 0), width=3)
        for sh, tx, ty, hw, depth in SOIL_SIDES:
            if sh == name:
                T, L, R, B = corners(tx, ty, hw)
                d.polygon([tuple(L), tuple(B), tuple(B + (0, depth)), tuple(L + (0, depth))], outline=(255, 0, 0), width=3)
        if BRICK_FACE[0] == name:
            ul, ur, h = BRICK_FACE[1:]
            d.polygon([ul, (ul[0], ul[1] + h), (ur[0], ur[1] + h), ur], outline=(255, 160, 0), width=3)
        im.save('/tmp/castle_debug_%s.png' % name)


def main():
    if '--debug' in sys.argv:
        debug()
    import glob
    for use, cubes in CUBES.items():
        for f in glob.glob(os.path.join(OUT, use + '_[0-9][0-9].png')):
            os.remove(f)
        for k, (sh, tx, ty, hw) in enumerate(cubes):
            top_face(sh, tx, ty, hw).save(os.path.join(OUT, '%s_%02d.png' % (use, k)))
    for kind in ('l', 'r'):
        s = soil_strip([side_face(sh, tx, ty, hw, depth, kind) for sh, tx, ty, hw, depth in SOIL_SIDES])
        s.save(os.path.join(OUT, 'side_castlesoil_%s.png' % kind))
    brick = brick_strip()
    brick.save(os.path.join(OUT, 'side_castlewall_l.png'))
    brick.point(lambda v: int(v * .8)).save(os.path.join(OUT, 'side_castlewall_r.png'))
    print('castle tiles:', {u: len(c) for u, c in CUBES.items()})


if __name__ == '__main__':
    main()
