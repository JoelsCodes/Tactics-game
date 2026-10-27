"""Terrain textures cut from the isometric tile sheets in art_src/tiles/.

Sheet files are named for their biome, see TILESHEETS. Every texture comes from a "block", an
isometric slab whose top face is a 2:1 diamond:

    Block(sheet, cx, cy, hw, depth, n)
        (cx, cy)  center of the top face        hw     half width of the top face
        depth     height of the side faces      n      tiles along each edge of the top face

From a block we unwarp
    top tiles   one 96x96 square per interior tile of the top face (flat patches, no seams)
    side faces  the lit right face and the shaded left face as strips, 4 tiles wide, so the
                world can slice one tile's worth for each cell

Output (assets/tiles/):  <name>_NN.png           96x96 tops
                         side_<name>_l.png/_r.png  384 wide faces
"""
import os

import numpy as np
from PIL import Image

TILE = 96
SIDE_W = 384

TILESHEETS = {
    'grassland': 'Grass chunk, stone pillar, flower tiles',
    'grass_stone': 'Grass blocks with dirt strata, stone paths, stairs and stone walls',
    'village': 'Cobbles, dirt, grass tiles, cliffs with stairs, houses, market, well, fences',
    'ruins': 'Mossy ruin floors, columns, arches, altar, vine walls',
    'bridges': 'Rope, plank and stone arch bridges over chasms',
    'castle': 'Marble halls, red carpet, battlements, gates, gargoyles, pillars',
    'cave': 'Dark cave floor, crystals, stalagmites, underground stream, strata cliffs',
    'swamp': 'Mud, murky water, roots, logs, mangrove trees',
    'ice': 'Snow, ice cliffs, frozen lakes, ice crystals',
    'desert': 'Dunes, cracked earth, sandstone ruins, oasis water',
    'interactive': 'Pressure plates, levers, chests, warp pads, dungeon floor',
    'water': 'Deep and shallow water blocks, waterfalls, stone bridges, riverbanks',
    'volcanic': 'Ash ground, lava cracks, basalt cliffs and stairs, embers',
    'sky': 'Floating marble and rock islands, crystals, wind vortex, sky pools',
}

# name: (sheet, cx, cy, hw, depth, n)
BLOCKS = {
    'grass': ('grass_stone', 426, 380, 338, 166, 4),
    'ash': ('volcanic', 346, 236, 292, 132, 4),
    'ash2': ('volcanic', 346, 680, 292, 132, 4),
    'lava': ('volcanic', 974, 236, 295, 127, 1),
    'deepwater': ('water', 426, 380, 338, 180, 1),
    'shallows': ('water', 425, 1100, 345, 165, 1),
    'marble': ('sky', 470, 320, 416, 150, 8),
}
# top texture name -> [(block, i, j)] interior tiles (n > 1) or the whole face (n == 1, sub-patch fraction)
TOPS = {
    'grass': [('grass', 1, 1), ('grass', 2, 1), ('grass', 1, 2), ('grass', 2, 2)],
    'cinder': [('ash', 1, 1), ('ash', 2, 1), ('ash', 1, 2), ('ash', 2, 2)],
    'stone': [('ash2', 1, 1), ('ash2', 2, 1), ('ash2', 1, 2), ('ash2', 2, 2)],
    'lava': [('lava', 0, 0, .5)],
    'deep': [('deepwater', 0, 0, .45)],
    'shallow': [('shallows', 0, 0, .45)],
    'marble': [('marble', 1, 5), ('marble', 6, 2), ('marble', 2, 6), ('marble', 5, 1)],
}
# side name -> (block, u0, u1): the part of the face edge to use (0 = left corner .. 1 = right corner of that face)
SIDES = {
    'grass': ('grass', 0.0, 1.0),
    'ash': ('ash', 0.0, 1.0),
    'ash2': ('ash2', 0.0, 1.0),
    'lava': ('lava', 0.0, 1.0),
    'marble': ('marble', 0.0, 1.0),
}


# Flat patches measured directly on a sheet: name -> [(sheet, cx, cy, half_width)]. These feed the
# extra biomes (swamp, ice, desert, castle, cave, village) that the story maps do not use yet.
FLAT_TOPS = {
    'cobble': [('village', 220, 262, 88), ('village', 420, 190, 80)],
    'mud': [('swamp', 640, 640, 150), ('swamp', 700, 760, 120)],
    'swampwater': [('swamp', 670, 290, 130), ('swamp', 720, 1180, 130)],
    'cracked': [('desert', 900, 800, 60), ('desert', 1000, 1010, 60)],
    'oasis': [('desert', 1700, 700, 60), ('desert', 1650, 1100, 60)],
    'cavefloor': [('cave', 700, 964, 110), ('cave', 840, 760, 90)],
    'snow': [('ice', 1330, 140, 100), ('ice', 1300, 470, 90)],
    'ice': [('ice', 1200, 700, 140), ('ice', 400, 1090, 130)],
}
# Recolors of a source top, for terrains the sheets do not show on their own.
DERIVED = {
    'dirt': ('grass', dict(hue=-.12, sat=.85, val=.82, tint=(140, 100, 60), k=.35)),
    'sand': ('grass', dict(hue=-.06, sat=.45, val=1.12, tint=(222, 200, 140), k=.45)),
    'crag': ('stone', dict(hue=.02, sat=1.4, val=1.6, tint=(150, 120, 90), k=.3)),
}


def recolor(img, hue, sat, val, tint, k):
    hsv = np.asarray(img.convert('RGB').convert('HSV')).astype(np.float32)
    hsv[..., 0] = (hsv[..., 0] + hue * 255) % 256
    hsv[..., 1] = np.clip(hsv[..., 1] * sat, 0, 255)
    hsv[..., 2] = np.clip(hsv[..., 2] * val, 0, 255)
    out = Image.fromarray(hsv.astype(np.uint8), 'HSV').convert('RGB')
    return Image.blend(out, Image.new('RGB', out.size, tint), k)


def flat_top(im, cx, cy, hw):
    h = hw / 2
    return quad(im, (cx, cy - h), (cx - hw, cy), (cx, cy + h), (cx + hw, cy), (TILE, TILE))


def open_sheet(root, name):
    return Image.open(os.path.join(root, 'tiles', name + '.jpg')).convert('RGB')


def quad(im, ul, ll, lr, ur, size):
    return im.transform(size, Image.QUAD, data=(*ul, *ll, *lr, *ur), resample=Image.BICUBIC)


def top_tile(im, b, i, j, frac=None):
    """96x96 flat patch of tile (i, j) of block b's top face."""
    _, cx, cy, hw, depth, n = b
    if n == 1:  # one big slab: take a sub-patch around its middle
        hh = hw * (frac or .5)
        ccx, ccy = cx, cy
    else:
        hh = hw / n * (.7 if n >= 8 else .86)
        ccx = cx + (i - j) * hw / n
        ccy = cy - hw / 2 + hw / (2 * n) + (i + j) * hw / (2 * n)
    h = hh / 2
    return quad(im, (ccx, ccy - h), (ccx - hh, ccy), (ccx, ccy + h), (ccx + hh, ccy), (TILE, TILE))


def side_face(im, b, kind):
    """Strip of the left or right face, SIDE_W wide and as tall as the block."""
    _, cx, cy, hw, depth, n = b
    d0, d1 = 6, depth - 8
    h = int(round((d1 - d0) * SIDE_W / hw))
    if kind == 'l':  # left face: top edge from (cx - hw, cy) to (cx, cy + hw / 2)
        ul, ur = (cx - hw + 4, cy + 2 + d0), (cx - 4, cy + hw / 2 - 2 + d0)
        ll, lr = (ul[0], ul[1] + d1 - d0), (ur[0], ur[1] + d1 - d0)
    else:  # right face: top edge from (cx, cy + hw / 2) to (cx + hw, cy)
        ul, ur = (cx + 4, cy + hw / 2 - 2 + d0), (cx + hw - 4, cy + 2 + d0)
        ll, lr = (ul[0], ul[1] + d1 - d0), (ur[0], ur[1] + d1 - d0)
    return quad(im, ul, ll, lr, ur, (SIDE_W, h))


SKY_ROCK = (1075, 300, 1250, 375)  # strata face of the big rock island on sky.jpg
SKY_STRIP = 1100  # px tall: enough for the tallest hub column


def sky_sides(im, d):
    """Floating-island cliffs. 'skyrock' is rock strata all the way down; 'skymarble' puts the marble
    rim of the island block on top of the same rock. The strata are mirrored down the strip."""
    rock = im.crop(SKY_ROCK).resize((SIDE_W, int((SKY_ROCK[3] - SKY_ROCK[1]) * SIDE_W / (SKY_ROCK[2] - SKY_ROCK[0]))), Image.NEAREST)
    fill = Image.new('RGB', (SIDE_W, SKY_STRIP))
    y, flip = 0, False
    while y < SKY_STRIP:
        fill.paste(rock.transpose(Image.FLIP_TOP_BOTTOM) if flip else rock, (0, y))
        y += rock.height
        flip = not flip
    band = Image.open(os.path.join(d, 'side_marble_l.png')).convert('RGB').crop((0, 0, SIDE_W, 48))
    for kind in ('l', 'r'):
        shade = 1.0 if kind == 'l' else .78
        f = fill.point(lambda v: int(v * shade))
        f.save(os.path.join(d, f'side_skyrock_{kind}.png'))
        b = Image.open(os.path.join(d, f'side_marble_{kind}.png')).convert('RGB').crop((0, 0, SIDE_W, 48))
        m = f.copy()
        m.paste(b, (0, 0))
        m.save(os.path.join(d, f'side_skymarble_{kind}.png'))


def orientations(t):
    return [t, t.transpose(Image.FLIP_LEFT_RIGHT)]


def build_tiles(src_root, out_root):
    d = os.path.join(out_root, 'tiles')
    os.makedirs(d, exist_ok=True)
    for old in os.listdir(d):
        os.remove(os.path.join(d, old))
    sheets = {}
    made = {}

    def sheet(n):
        return sheets.setdefault(n, open_sheet(src_root, n))
    for name, items in TOPS.items():
        out = []
        for it in items:
            b = BLOCKS[it[0]]
            t = top_tile(sheet(b[0]), b, it[1], it[2], it[3] if len(it) > 3 else None)
            out += orientations(t)
        for k, t in enumerate(out):
            t.save(os.path.join(d, f'{name}_{k:02d}.png'))
        made[name] = len(out)
    for name, (bn, u0, u1) in SIDES.items():
        b = BLOCKS[bn]
        for kind in ('l', 'r'):
            side_face(sheet(b[0]), b, kind).save(os.path.join(d, f'side_{name}_{kind}.png'))
        made['side_' + name] = 2
    sky_sides(sheet('sky'), d)
    made['side_skyrock'] = made['side_skymarble'] = 2
    for name, items in FLAT_TOPS.items():
        out = []
        for (sh, cx, cy, hw) in items:
            out += orientations(flat_top(sheet(sh), cx, cy, hw))
        for k, t in enumerate(out):
            t.save(os.path.join(d, f'{name}_{k:02d}.png'))
        made[name] = len(out)
    for name, (src, kw) in DERIVED.items():
        for k in range(8 if src == 'grass' else 8):
            t = Image.open(os.path.join(d, f'{src}_{k:02d}.png'))
            recolor(t, **kw).save(os.path.join(d, f'{name}_{k:02d}.png'))
        made[name] = 8
    return made
