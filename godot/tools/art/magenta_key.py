#!/usr/bin/env python3
"""Turns a pure-magenta (#FF00FF) background into transparency, for sprite and tile sheets drawn on
magenta, and optionally cuts the sheet into equal frames.

  python3 godot/tools/art/magenta_key.py sheet.png out.png
  python3 godot/tools/art/magenta_key.py sheet.png out_dir --cols 8 --rows 6     (frames: out_dir/f_RR_CC.png)

Pixels close to magenta become transparent, a band around that becomes partly transparent (soft,
anti-aliased edges), and the magenta tint left on those edge pixels is removed ("despill"), so no pink
fringe shows against the game's ground. Exact frame layouts (which row is walk, idle, ...) are set per
sheet when the art arrives, the way tools/art/characters.py does for the current sheets.
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image

MAGENTA = np.array([255.0, 0.0, 255.0])


def key_magenta(img, inner=60.0, outer=140.0):
    """RGBA image with the magenta background removed. `inner`: colour distance (0-441) below which a
    pixel is fully transparent; `outer`: distance above which it is fully opaque."""
    a = np.asarray(img.convert('RGBA')).astype(np.float32)
    rgb = a[..., :3]
    dist = np.sqrt(((rgb - MAGENTA) ** 2).sum(-1))
    alpha = np.clip((dist - inner) / max(outer - inner, 1e-3), 0.0, 1.0)
    # despill the soft edge band only (fully opaque pixels keep their colours, purple included):
    # magenta is high red and blue with low green, so pull red and blue down to green
    spill = np.clip(np.minimum(rgb[..., 0], rgb[..., 2]) - rgb[..., 1], 0.0, None) * (alpha < 1.0)
    rgb[..., 0] -= spill
    rgb[..., 2] -= spill
    out = np.dstack([np.clip(rgb, 0, 255), a[..., 3] * alpha])
    out[out[..., 3] == 0, :3] = 0  # clean colour under fully transparent pixels (no halos when filtered)
    return Image.fromarray(out.astype(np.uint8), 'RGBA')


def slice_grid(img, cols, rows):
    """Equal frames, row by row: [[frame, ...], ...]."""
    w, h = img.size
    fw, fh = w // cols, h // rows
    return [[img.crop((c * fw, r * fh, (c + 1) * fw, (r + 1) * fh)) for c in range(cols)] for r in range(rows)]


def main(argv):
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('src')
    p.add_argument('dst', help='output PNG, or a folder when --cols/--rows are given')
    p.add_argument('--cols', type=int, default=0)
    p.add_argument('--rows', type=int, default=0)
    p.add_argument('--inner', type=float, default=60.0)
    p.add_argument('--outer', type=float, default=140.0)
    a = p.parse_args(argv)
    keyed = key_magenta(Image.open(a.src), a.inner, a.outer)
    if a.cols and a.rows:
        os.makedirs(a.dst, exist_ok=True)
        for r, row in enumerate(slice_grid(keyed, a.cols, a.rows)):
            for c, frame in enumerate(row):
                frame.save(os.path.join(a.dst, 'f_%02d_%02d.png' % (r, c)))
    else:
        keyed.save(a.dst)


if __name__ == '__main__':
    main(sys.argv[1:])
