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
    build_fx_and_ui()
