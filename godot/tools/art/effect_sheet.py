#!/usr/bin/env python3
"""Cuts the owner's effect sheet (art_src/effects/effect_sheet.png: 800 x 2000, transparent) into one strip per look and piece,
assets/sprites/effects/fx_<look>_<piece>.png: six frames of 134 x 100 side by side.

The sheet is four looks (fire, ice, spark, holy) one under the other; each look is five rows (projectile, burst, ring, aura, beam) of six frames.
Measured: rows are 100 px apart, frames 133.33 px apart (800 / 6); the frames have empty gaps between them, so cutting 134 px at round(i * 133.33) never
touches a neighbour. The art is drawn for the game's camera already (rings and auras are flattened ellipses), so nothing is resampled or recoloured.
The projectile and the beam point to the right (the head and the target side), the beam's source flare is at its left.
Usage: python3 godot/tools/art/effect_sheet.py (needs Pillow)."""
import os
import numpy as np
from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
SRC = os.path.join(ROOT, 'art_src', 'effects', 'effect_sheet.png')
OUT = os.path.join(ROOT, 'assets', 'sprites', 'effects')
LOOKS = ['fire', 'ice', 'spark', 'holy']
PIECES = ['projectile', 'burst', 'ring', 'aura', 'beam']
FRAMES = 6
FW, FH = 134, 100
PITCH_X = 800 / FRAMES


def build():
    os.makedirs(OUT, exist_ok=True)
    im = Image.open(SRC).convert('RGBA')
    assert im.size == (800, 2000), im.size
    padded = Image.new('RGBA', (800 + FW, 2000), (0, 0, 0, 0))
    padded.alpha_composite(im)
    n = 0
    for li, look in enumerate(LOOKS):
        for pi, piece in enumerate(PIECES):
            y0 = (li * len(PIECES) + pi) * FH
            strip = Image.new('RGBA', (FW * FRAMES, FH), (0, 0, 0, 0))
            for i in range(FRAMES):
                x0 = round(i * PITCH_X)
                strip.alpha_composite(padded.crop((x0, y0, x0 + FW, y0 + FH)), (i * FW, 0))
            a = np.asarray(strip)[..., 3]
            assert a.max() > 200, (look, piece)  # not an empty strip
            strip.save(os.path.join(OUT, 'fx_%s_%s.png' % (look, piece)))
            n += 1
    return n


if __name__ == '__main__':
    print('wrote', build(), 'strips')
