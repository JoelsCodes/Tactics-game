"""Alaric's portraits and full illustration (`alaric_v2`).

  art_src/characters/alaric_v2_portraits_sheet.png      the owner's 16 expressions (4 x 4, row by row: see EXPRESSIONS), transparent background
  art_src/characters/alaric_v2_front_reference.png      the front pose of the turnaround (background removed), for the full illustration

  python3 godot/tools/art/alaric_v2_portrait.py

Writes assets/characters/alaric_v2/portraits/portrait_01..16.png (head and shoulders: the dialogue box, the HUD cards, the barracks;
portrait_01 is the neutral one the game uses) and artwork/full_portrait.png. The sheet has a faint noise of nearly transparent pixels and a red
fringe around the figures: only the solid figure stays (alpha 128 and up) and each portrait is cut by its own bounds. There is no sword icon: the sheets show the sword only in the hand or the scabbard (CharacterLook.weapon is not used by the game).
"""
import os

import numpy as np
from PIL import Image
from scipy import ndimage as nd

EXPRESSIONS = ['neutral', 'calm', 'surprised', 'shout', 'eyes_closed', 'smile', 'laugh', 'cry_out',
               'startled', 'worried', 'angry', 'looking_up', 'sad', 'pained', 'head_down', 'faint']  # row by row, left to right

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT = os.path.join(ROOT, 'assets', 'characters', 'alaric_v2')


def build():
    a = np.array(Image.open(os.path.join(ROOT, 'art_src', 'characters', 'alaric_v2_front_reference.png')).convert('RGBA'))
    solid = a[..., 3] > 200
    edge = solid & ~nd.binary_erosion(solid, iterations=2)
    a[edge & (a[..., :3].min(2) > 225)] = 0  # the pale halo
    a[..., 3] = np.where(a[..., 3] > 128, 255, 0)
    ref = Image.fromarray(a, 'RGBA')
    os.makedirs(os.path.join(OUT, 'portraits'), exist_ok=True)
    os.makedirs(os.path.join(OUT, 'artwork'), exist_ok=True)
    ref.crop(ref.getbbox()).save(os.path.join(OUT, 'artwork', 'full_portrait.png'))
    sheet = np.array(Image.open(os.path.join(ROOT, 'art_src', 'characters', 'alaric_v2_portraits_sheet.png')).convert('RGBA'))
    solid = sheet[..., 3] >= 128
    sheet[..., 3] = np.where(solid, 255, 0)
    sheet[~solid] = 0
    def spans(v):
        out, start = [], None
        for i, x in enumerate(v):
            if x and start is None:
                start = i
            if not x and start is not None:
                out.append((start, i)) if i - start > 20 else None
                start = None
        if start is not None and len(v) - start > 20:
            out.append((start, len(v)))
        return out
    cols, rows = spans(solid.sum(0) > 20), spans(solid.sum(1) > 20)
    assert len(cols) == 4 and len(rows) == 4, (cols, rows)
    for i in range(16):
        (y0, y1), (x0, x1) = rows[i // 4], cols[i % 4]
        Image.fromarray(sheet[y0:y1, x0:x1], 'RGBA').save(os.path.join(OUT, 'portraits', 'portrait_%02d.png' % (i + 1)))
    print('alaric_v2: 16 portraits and the illustration written')


if __name__ == '__main__':
    build()
