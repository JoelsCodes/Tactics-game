#!/usr/bin/env python3
"""A contact sheet of a character's animation frames (feet line in red), for checking a cut by eye:
  python3 godot/tools/art/contact.py <character> out.png [half]      half = 0 (idle..run, 8 dirs) or 1 (dash, actions)
"""
import json
import os
import sys

from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
name, out = sys.argv[1], sys.argv[2]
half = int(sys.argv[3]) if len(sys.argv) > 3 else 0
m = json.load(open(os.path.join(ROOT, 'assets', 'characters', 'meta.json')))[name]
W, H = m['size']
ax, ay = m['anchor']
dirs = ['s', 'se', 'e', 'ne', 'n', 'nw', 'w', 'sw']
if half == 0:
    order = ['%s_%s' % (mv, d) for mv in ('idle', 'walk', 'run') for d in dirs if '%s_%s' % (mv, d) in m['anims']]
else:
    order = ['dash_%s' % d for d in dirs if 'dash_%s' % d in m['anims']] + [a for a in ('attack', 'heavy', 'cast', 'hit', 'ko') if a in m['anims']]
cols = 11
sc = 1 if W < 150 else 0.5
img = Image.new('RGB', (int(cols * W * sc) + 70, int(len(order) * H * sc)), (40, 44, 52))
d = ImageDraw.Draw(img)
for r, a in enumerate(order):
    d.text((2, int(r * H * sc) + 20), a, fill=(255, 255, 255))
    for c, f in enumerate(m['anims'][a]['frames'][:cols]):
        fr = Image.open(os.path.join(ROOT, 'assets', 'characters', name, f)).convert('RGBA')
        if sc != 1:
            fr = fr.resize((int(W * sc), int(H * sc)))
        img.paste(fr, (70 + int(c * W * sc), int(r * H * sc)), fr)
        d.text((72 + int(c * W * sc), int(r * H * sc)), str(c), fill=(255, 255, 0))
    d.line((70, int((r * H + ay) * sc), 70 + int(cols * W * sc), int((r * H + ay) * sc)), fill=(255, 60, 60))
img.save(out)
