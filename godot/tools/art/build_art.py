#!/usr/bin/env python3
"""Builds every game asset from the source sheets in godot/art_src/.

  python3 godot/tools/art/build_art.py      (needs Pillow, numpy and scipy)

  art_src/characters/<name>.jpg   seven character sheets      -> characters.py
  art_src/tiles/<biome>.jpg       fourteen terrain sheets     -> tiles.py
  props, effects, UI frames, title backdrop                   -> this file

Writes into godot/assets/ (characters, tiles, props, fx, ui). Run it after changing anything in
art_src/, then re-import in Godot and run tools/build_resources.gd.
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), '..', '..'))
SRC = os.path.join(ROOT, 'art_src')
OUT = os.path.join(ROOT, 'assets')
sys.path.insert(0, os.path.dirname(__file__))


def save(img, *parts):
    path = os.path.join(OUT, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, optimize=True)
    return path


def build_grass_blocks():
    """Grass from the isometric block sheet (art_src/tiles/grass_blocks.jpg, 8x8 blocks).
    Each block gives a flat top (its interior, so neighbours butt together without the uneven grass rim)
    -> tiles/blocktop_NN.png, and four plain blocks give the dirt side strips -> tiles/side_blockgrass_l/r.png."""
    from sheet_cut import trim
    im = Image.open(os.path.join(SRC, 'tiles', 'grass_blocks.jpg')).convert('RGBA')
    W, H = im.size
    cw, ch = W / 8, H / 8
    bg = np.asarray(im)[4, 4, :3].astype(int)
    blocks = []
    for r in range(8):
        for c in range(8):
            cell = im.crop((int(c * cw), int(r * ch), int((c + 1) * cw), int((r + 1) * ch)))
            a = np.asarray(cell).astype(np.int32)
            far = np.abs(a[..., :3] - bg).sum(-1) >= 40
            a[..., 3] = far * 255
            blk = trim(Image.fromarray(a.astype(np.uint8), 'RGBA'))
            blocks.append(blk if blk.width >= 100 else None)

    def quad(img, ul, ll, lr, ur, size):
        return img.transform(size, Image.QUAD, data=(*ul, *ll, *lr, *ur), resample=Image.BICUBIC)

    n = 0
    for k, blk in enumerate(blocks):
        if blk is None:
            continue
        w = blk.width
        hd = w / 2  # a 2:1 isometric top diamond
        cx, cy, hw, hh = w / 2, hd / 2 + 2, w / 2 * .72, hd / 2 * .72
        top = quad(blk, (cx, cy - hh), (cx - hw, cy), (cx, cy + hh), (cx + hw, cy), (96, 96))
        save(top.convert('RGB'), 'tiles', 'blocktop_%02d.png' % k)
        n += 1
    # side strips: the left and right faces of four plain blocks, side by side (4 tiles = 384 px wide)
    for kind in ('l', 'r'):
        faces = []
        for k in (0, 2, 4, 6):
            blk = blocks[k]
            w, h = blk.width, blk.height
            hd = w / 2
            D = h - hd - 12
            if kind == 'l':
                ul, ur = (6, hd / 2 + 4), (w / 2 - 4, hd - 2)
            else:
                ul, ur = (w / 2 + 4, hd - 2), (w - 6, hd / 2 + 4)
            ll, lr = (ul[0], ul[1] + D), (ur[0], ur[1] + D)
            fh = int(D * 96 / (w / 2 - 10))
            faces.append(quad(blk, ul, ll, lr, ur, (96, fh)))
        fh = min(f.height for f in faces)
        strip = Image.new('RGBA', (384, fh))
        for i, f in enumerate(faces):
            strip.paste(f.crop((0, 0, 96, fh)), (i * 96, 0))
        # extend downwards by mirroring the lower half, for tall columns
        tall = Image.new('RGBA', (384, 900))
        tall.paste(strip, (0, 0))
        y, flip = fh, True
        lower = strip.crop((0, int(fh * .45), 384, fh))
        while y < 900:
            tall.paste(lower.transpose(Image.FLIP_TOP_BOTTOM) if flip else lower, (0, y))
            y += lower.height
            flip = not flip
        save(tall.convert('RGB'), 'tiles', 'side_blockgrass_%s.png' % kind)
    bake_ground(blocks_tops_dir=os.path.join(OUT, 'tiles'))
    print('grass block tops:', n)


def bake_ground(blocks_tops_dir):
    """One seamless 1024px grass texture: 16x16 cells on a 64px stride, each a 96px block top with a
    cosine feather, blended by their weights, so there are no tile borders. Which top goes where follows
    smooth noise (families: lawn, tufted, mossy), with small flower and stone patches. Wraps on both axes."""
    import random
    S, STRIDE, WIN, N = 1024, 64, 96, 16
    fam = {'smooth': [0, 2, 4, 6, 7, 13, 27, 28, 35, 36], 'tufted': [1, 3, 5, 9, 11, 30, 31],
           'mossy': [8, 10, 12, 16, 17, 24, 25, 32, 33], 'flowers': [14, 15, 22, 45, 46, 47], 'stones': [23, 52, 53, 54]}
    tops = {k: np.asarray(Image.open(os.path.join(blocks_tops_dir, 'blocktop_%02d.png' % k)).convert('RGB')).astype(np.float32)
            for v in fam.values() for k in v}
    rng = random.Random(11)
    grid = lambda: [[rng.random() for _ in range(5)] for _ in range(5)]  # wrapping 5x5 value-noise lattices
    lat = [grid() for _ in range(3)]

    def noise(l, x, y):
        fx, fy = x / N * 5, y / N * 5
        x0, y0 = int(fx) % 5, int(fy) % 5
        tx, ty = fx - int(fx), fy - int(fy)
        tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
        a, b = l[y0][x0], l[y0][(x0 + 1) % 5]
        c, d = l[(y0 + 1) % 5][x0], l[(y0 + 1) % 5][(x0 + 1) % 5]
        return (a * (1 - tx) + b * tx) * (1 - ty) + (c * (1 - tx) + d * tx) * ty
    u = (np.arange(WIN) + .5) / WIN * 2 - 1
    win1 = np.cos(np.pi * u / 2) ** 2
    win = np.outer(win1, win1).astype(np.float32)
    acc = np.zeros((S, S, 3), np.float32)
    wsum = np.zeros((S, S, 1), np.float32)
    for j in range(N):
        for i in range(N):
            f = noise(lat[0], i, j)
            if noise(lat[1], i, j) > .78 and rng.random() < .8:
                pool = fam['flowers']
            elif noise(lat[2], i, j) > .82 and rng.random() < .8:
                pool = fam['stones']
            else:
                pool = fam['smooth'] if f < .45 else fam['mossy'] if f < .62 else fam['tufted']
            t = tops[rng.choice(pool)]
            ys = (np.arange(WIN) + j * STRIDE - (WIN - STRIDE) // 2) % S
            xs = (np.arange(WIN) + i * STRIDE - (WIN - STRIDE) // 2) % S
            acc[np.ix_(ys, xs)] += t * win[..., None]
            wsum[np.ix_(ys, xs)] += win[..., None]
    out = (acc / np.maximum(wsum, 1e-3)).clip(0, 255).astype(np.uint8)
    save(Image.fromarray(out, 'RGB'), 'tiles', 'ground_grass.png')


def build_tufts():
    """Four standing grass tufts from the alt grass sheet (green blades only, background dropped)."""
    from sheet_cut import trim
    im = Image.open(os.path.join(SRC, 'tiles', 'grass_alt.jpg')).convert('RGB')
    W, H = im.size
    cw, ch = W / 8, H / 8
    for i, (c, r) in enumerate([(1, 0), (2, 1), (1, 1), (0, 2)]):
        cell = im.crop((int(c * cw + 14), int(r * ch + 14), int((c + 1) * cw - 14), int((r + 1) * ch - 14))).resize((70, 70))
        a = np.asarray(cell).astype(np.int32)
        R, G, B = a[..., 0], a[..., 1], a[..., 2]
        keep = (G > R + 10) & (G > 60)
        arr = np.dstack([a.astype(np.uint8), (keep * 255).astype(np.uint8)])
        save(trim(Image.fromarray(arr, 'RGBA')), 'props', 'tuft_%d.png' % i)


def build_props():
    """Tree canopy from the village sheet (its own green pixels only) on a generated trunk, and the
    bridge deck from the bridges sheet."""
    import scipy.ndimage as nd
    from sheet_cut import load, matte, trim
    im, a = load(os.path.join(SRC, 'tiles', 'village.jpg'))
    x0, y0, x1, y1 = 1786, 636, 2006, 812
    crop = a[y0:y1, x0:x1]
    R, G, B = crop[..., 0], crop[..., 1], crop[..., 2]
    green = (G >= R - 6) & (G > B + 6) & (G > 55)
    green = nd.binary_closing(green, iterations=2)
    green = nd.binary_fill_holes(green)
    lab, n = nd.label(green)
    green = lab == (1 + int(np.argmax(nd.sum(green, lab, range(1, n + 1)))))
    # keep a dark outline ring around the leaves, but not the bluish shadow behind them
    ring = nd.binary_dilation(green, iterations=2) & ~green & ~(B > G + 2) & (crop.max(-1) < 90)
    keep = green | ring
    keep = nd.binary_fill_holes(keep)
    arr = np.dstack([crop, keep * 255.0]).astype(np.float32)
    canopy = trim(Image.fromarray(arr.astype(np.uint8), 'RGBA'))
    s = 76 / canopy.height
    canopy = canopy.resize((round(canopy.width * s), round(canopy.height * s)), Image.LANCZOS)
    tree = Image.new('RGBA', (canopy.width, canopy.height + 22), (0, 0, 0, 0))
    d = ImageDraw.Draw(tree)
    cx = canopy.width // 2
    d.polygon([(cx - 8, tree.height), (cx - 5, tree.height - 36), (cx + 5, tree.height - 36), (cx + 8, tree.height)], fill=(88, 58, 36, 255), outline=(30, 20, 14, 255))
    d.line([(cx - 2, tree.height - 34), (cx - 3, tree.height - 2)], fill=(120, 82, 50, 255), width=2)
    tree.alpha_composite(canopy, (0, 0))
    save(tree, 'props', 'tree.png')
    # Bridge deck: planks from the bridges sheet, flat patch along the bridge's own axis.
    bim = Image.open(os.path.join(SRC, 'tiles', 'bridges.jpg')).convert('RGB')
    cx, cy, hw = 365, 640, 46
    h = hw / 2
    deck = bim.transform((96, 96), Image.QUAD, data=(cx, cy - h, cx - hw, cy, cx, cy + h, cx + hw, cy), resample=Image.BICUBIC)
    save(deck, 'tiles', 'bridge_00.png')
    save(deck.transpose(Image.FLIP_LEFT_RIGHT), 'tiles', 'bridge_01.png')
    print('props: tree, bridge deck')


def build_fx_and_ui():
    def radial(size, f):
        a = np.zeros((size, size, 4), np.uint8)
        c = (size - 1) / 2
        for y in range(size):
            for x in range(size):
                a[y, x] = f(math.hypot(x - c, y - c) / c, x - c, y - c)
        return Image.fromarray(a, 'RGBA')
    save(radial(64, lambda r, x, y: (255, 255, 255, int(255 * max(0, 1 - r) ** 2))), 'fx', 'soft_dot.png')
    save(radial(128, lambda r, x, y: (255, 255, 255, int(255 * max(0, 1 - abs(r - .82) / .14)))), 'fx', 'ring.png')
    save(radial(64, lambda r, x, y: (255, 255, 255, int(255 * min(1, max(0, 1 - r) * (max(0, 1 - min(abs(x), abs(y)) / 3.5)) * 2.2)))), 'fx', 'spark.png')
    save(radial(64, lambda r, x, y: (0, 0, 0, int(150 * max(0, 1 - r) ** 1.5))), 'fx', 'shadow.png')

    # Cloud puffs for the hub's sky: overlapping soft ellipses, cream on top and blue-grey underneath.
    import random
    rng = random.Random(7)
    for n in range(3):
        img = Image.new('RGBA', (256, 128), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        for _ in range(9):
            cx, cy, r = rng.randint(50, 206), rng.randint(56, 84), rng.randint(22, 38)
            d.ellipse((cx - r * 1.3, cy - r * .8, cx + r * 1.3, cy + r * .8), fill=(168, 190, 222, 255))
        for _ in range(9):
            cx, cy, r = rng.randint(50, 206), rng.randint(44, 72), rng.randint(20, 34)
            d.ellipse((cx - r * 1.3, cy - r * .9, cx + r * 1.3, cy + r * .7), fill=(252, 248, 238, 255))
        a = np.asarray(img).astype(np.float32)
        al = Image.fromarray(a[..., 3].astype(np.uint8)).filter(ImageFilter.GaussianBlur(3))
        img.putalpha(al.point(lambda v: min(255, int(v * 1.0))))
        save(img.filter(ImageFilter.GaussianBlur(1)), 'fx', f'cloud_{n}.png')

    def window(w, h, top, bottom, rim, inner):
        img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        for y in range(h):
            t = y / (h - 1)
            col = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
            d.line((3, y, w - 4, y), fill=col + (238,))
        d.rounded_rectangle((0, 0, w - 1, h - 1), radius=6, outline=rim + (255,), width=2)
        d.rounded_rectangle((3, 3, w - 4, h - 4), radius=4, outline=inner + (255,), width=1)
        mask = Image.new('L', (w, h), 0)
        ImageDraw.Draw(mask).rounded_rectangle((0, 0, w - 1, h - 1), radius=6, fill=255)
        img.putalpha(Image.fromarray(np.minimum(np.asarray(img)[..., 3], np.asarray(mask))))
        return img
    save(window(48, 48, (38, 58, 120), (16, 24, 58), (214, 182, 104), (122, 150, 214)), 'ui', 'window.png')
    save(window(48, 48, (58, 84, 156), (30, 44, 98), (226, 200, 130), (150, 176, 232)), 'ui', 'button.png')
    save(window(48, 48, (92, 122, 200), (52, 72, 140), (255, 228, 150), (190, 210, 250)), 'ui', 'button_hover.png')
    save(window(48, 48, (180, 140, 60), (120, 86, 30), (255, 230, 160), (250, 214, 130)), 'ui', 'button_pressed.png')
    save(window(48, 48, (50, 56, 72), (30, 34, 46), (110, 110, 120), (80, 84, 100)), 'ui', 'button_disabled.png')
    hand = Image.new('RGBA', (16, 12), (0, 0, 0, 0))
    ImageDraw.Draw(hand).polygon([(0, 3), (9, 3), (9, 1), (15, 6), (9, 11), (9, 9), (0, 9)], fill=(255, 246, 220, 255), outline=(40, 30, 20, 255))
    save(hand.resize((32, 24), Image.NEAREST), 'ui', 'pointer.png')
    # Title backdrop: the grass-and-stone sheet, softened and darkened toward the bottom.
    sheet = Image.open(os.path.join(SRC, 'tiles', 'grass_stone.jpg')).convert('RGB')
    bg = sheet.crop((700, 0, 1700, 1438)).resize((470, 676), Image.LANCZOS).filter(ImageFilter.GaussianBlur(1.0))
    bg = bg.resize((470, 845), Image.LANCZOS)
    shade = np.linspace(.85, .25, bg.height)[:, None, None]
    bg = Image.fromarray((np.asarray(bg).astype(np.float32) * shade).astype(np.uint8))
    os.makedirs(os.path.join(OUT, 'ui'), exist_ok=True)
    bg.save(os.path.join(OUT, 'ui', 'title_bg.jpg'), quality=88)
    print('fx, ui frames, title backdrop')


if __name__ == '__main__':
    import characters
    import tiles
    characters.build_all(SRC, OUT)
    print('tiles:', tiles.build_tiles(SRC, OUT))
    build_props()
    build_tufts()
    build_grass_blocks()
    build_fx_and_ui()
