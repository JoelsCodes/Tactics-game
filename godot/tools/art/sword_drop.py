"""Cuts the owner's sword sheet (eight identical frames of one sword on magenta, Nov 2026) into the sword that drops where an
enemy falls: assets/props/sword_drop.png (the first frame, keyed, trimmed to the sword).

  python3 godot/tools/art/sword_drop.py

Size (the tile rule, see CLAUDE.md): the game draws it SWORD_HEIGHT world units tall (`BattleStage.SWORD_HEIGHT`; the King is about
1.9, a tile is 1), so it is shorter than the King and its width (about 0.4 of its height) sits well inside one tile.
"""
import os

import numpy as np
from PIL import Image
from scipy import ndimage as nd

import magenta_key

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
SRC = os.path.join(ROOT, 'art_src', 'props', 'sword_drop_sheet.png')
OUT = os.path.join(ROOT, 'assets', 'props', 'sword_drop.png')
FRAMES = 8


def main():
    sheet = Image.open(SRC).convert('RGB')
    w = sheet.width // FRAMES
    frame = sheet.crop((4, 4, w - 4, sheet.height - 4))  # inside the thin frame lines
    rgba = magenta_key.key_magenta(frame)
    a = np.asarray(rgba)[..., 3] > 8
    lab, n = nd.label(a)
    if n > 1:  # keep the sword, drop specks
        sizes = nd.sum(a, lab, range(1, n + 1))
        keep = lab == (1 + int(np.argmax(sizes)))
        arr = np.asarray(rgba).copy()
        arr[~keep] = 0
        rgba = Image.fromarray(arr, 'RGBA')
    rgba = rgba.crop(rgba.getbbox())
    rgba.save(OUT)
    print('saved %s %s' % (OUT, rgba.size))


if __name__ == '__main__':
    main()
