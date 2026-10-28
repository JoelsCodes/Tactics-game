#!/usr/bin/env python3
"""Checks for magenta_key.py on a made-up 1024x768 sheet: python3 godot/tools/art/test_magenta_key.py"""
import os
import sys
import tempfile

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from magenta_key import key_magenta, slice_grid, main  # noqa: E402

fails = 0


def ok(cond, what):
    global fails
    if not cond:
        fails += 1
        print('FAIL', what)


sheet = Image.new('RGB', (1024, 768), (255, 0, 255))
d = ImageDraw.Draw(sheet)
d.ellipse((40, 40, 88, 88), fill=(40, 160, 60))        # a green blob in frame (0, 0)
d.rectangle((300, 300, 340, 360), fill=(250, 250, 250))  # a white block in frame (2, 2)
d.rectangle((600, 600, 640, 640), fill=(120, 40, 140))   # a purple robe: opaque, must keep its colour
sheet.putpixel((89, 64), (190, 60, 190))                 # an anti-aliased pinkish edge pixel

k = np.asarray(key_magenta(sheet))
ok(k.shape == (768, 1024, 4), 'keeps the size, adds alpha')
ok(k[0, 0, 3] == 0 and tuple(k[0, 0, :3]) == (0, 0, 0), 'pure magenta becomes clear (and black under)')
ok(k[64, 64, 3] == 255 and tuple(k[64, 64, :3]) == (40, 160, 60), 'the sprite is untouched')
ok(k[330, 320, 3] == 255 and tuple(k[330, 320, :3]) == (250, 250, 250), 'white is untouched')
edge = k[64, 89]
ok(0 < edge[3] < 255, 'an edge pixel is partly transparent (%d)' % edge[3])
ok(edge[0] <= edge[1] + 1 and edge[2] <= edge[1] + 1, 'and loses its magenta tint %s' % (tuple(edge[:3]),))
ok(k[620, 620, 3] == 255 and tuple(k[620, 620, :3]) == (120, 40, 140), 'opaque purple keeps its colour')
ok(not ((k[..., 3] > 0) & (k[..., 3] < 255) & (k[..., 0] > 200) & (k[..., 1] < 60) & (k[..., 2] > 200)).any(), 'no visible magenta left')

frames = slice_grid(key_magenta(sheet), 8, 6)
ok(len(frames) == 6 and len(frames[0]) == 8 and frames[0][0].size == (128, 128), '8 x 6 frames of 128 px')

with tempfile.TemporaryDirectory() as t:
    src = os.path.join(t, 'sheet.png')
    sheet.save(src)
    main([src, os.path.join(t, 'out.png')])
    ok(Image.open(os.path.join(t, 'out.png')).mode == 'RGBA', 'command line: one file')
    main([src, os.path.join(t, 'frames'), '--cols', '8', '--rows', '6'])
    ok(len(os.listdir(os.path.join(t, 'frames'))) == 48, 'command line: 48 frames')

print('magenta checks: %d failed' % fails)
sys.exit(1 if fails else 0)
