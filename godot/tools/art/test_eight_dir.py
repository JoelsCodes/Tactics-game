#!/usr/bin/env python3
"""Checks the frames tools/art/eight_dir.py wrote: every frame on one canvas, the feet of every
standing frame on the shared anchor (no jitter), and no magenta left on the edges.
  python3 godot/tools/art/test_eight_dir.py
"""
import json
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from eight_dir import ROOT, SHEETS, feet  # noqa: E402

fails = 0


def ok(cond, what):
    global fails
    if not cond:
        fails += 1
        print('FAIL', what)


meta = json.load(open(os.path.join(ROOT, 'assets', 'characters', 'meta.json')))
for name in SHEETS:
    m = meta[name]
    W, H = m['size']
    ax, ay = m['anchor']
    worst = 0.0
    for anim, d in m['anims'].items():
        for f in d['frames']:
            img = Image.open(os.path.join(ROOT, 'assets', 'characters', name, f)).convert('RGBA')
            ok(img.size == (W, H), '%s %s canvas' % (anim, f))
            a = np.asarray(img).astype(int)
            r, g, b = a[..., 0], a[..., 1], a[..., 2]
            pink = ((np.minimum(r, b) - g > 60) & (np.abs(r - b) < 30) & (a[..., 3] > 128)).sum()
            ok(pink < 20, '%s %s: %d magenta-cast pixels left' % (anim, f, pink))
            if anim.startswith(('idle_', 'walk_', 'run_', 'attack', 'cast', 'hit')) and not anim.endswith(('_f', '_b')):
                fx, fy = feet(img)
                worst = max(worst, abs(fy - ay))
                ok(abs(fy - ay) <= 3.0, '%s %s: feet at y %.1f, anchor %d' % (anim, f, fy, ay))
    print(name, 'worst feet offset %.1f px' % worst)
print('eight_dir checks: %d failed' % fails)
sys.exit(1 if fails else 0)
