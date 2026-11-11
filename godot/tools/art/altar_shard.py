#!/usr/bin/env python3
"""Cuts the four Altar Shard sheets (art_src/altar_shard/<name>_src.png: 2172 x 724, eight frames side by side, transparent) into aligned sheets in
assets/sprites/altar_shard/altar_shard_<name>.png: eight frames of 290 x 570 each.

The source frames sit on a pitch of 2172 / 8 = 271.5 px (not a whole number), so each is cut at round(i * 271.5). Then, per frame:
  - the base is aligned: the lowest solid row of the stone goes to one fixed row (the sheets drift by two pixels) and the base's centre to one fixed column;
  - the glow of the big frames spills into the neighbouring cells (the sources overlap there), so a cut would leave a hard vertical edge: the soft pixels
    (alpha under SOLID) are faded to nothing over FEATHER px at each side of the cell; the solid stone is never touched.
Usage: python3 godot/tools/art/altar_shard.py   (run from anywhere; needs Pillow and numpy)."""
import os
import numpy as np
from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
SRC = os.path.join(ROOT, 'art_src', 'altar_shard')
OUT = os.path.join(ROOT, 'assets', 'sprites', 'altar_shard')
NAMES = ['idle', 'activate', 'summon', 'depleted']
N = 8
PITCH = 2172 / 8
FW, FH = 290, 570  # the output frame
BASE_ROW = 540  # where the stone's lowest solid row lands in the frame (about where the sources have it)
BASE_COL = 145  # where the base's centre lands
SOLID = 250
FEATHER = 30


def cell(a, i):
    x0 = round(i * PITCH)
    x1 = round((i + 1) * PITCH)
    return a[:, x0:x1].copy()


def base_of(c):
    """(lowest solid row, centre column of the stone's foot) of a cell."""
    al = c[..., 3]
    rows = np.nonzero((al > 128).any(1))[0]
    low = int(rows.max())
    cols = np.nonzero((al[low - 24:low + 1] > 128).any(0))[0]
    return low, (int(cols.min()) + int(cols.max())) / 2.0


def feather(c):
    al = c[..., 3].astype(np.float32)
    w = c.shape[1]
    ramp = np.ones(w, np.float32)
    k = np.arange(FEATHER, dtype=np.float32) / FEATHER
    ramp[:FEATHER] = k
    ramp[w - FEATHER:] = k[::-1]
    soft = al < SOLID
    al = np.where(soft, al * ramp[None, :], al)
    c[..., 3] = al.astype(np.uint8)
    return c


def build():
    os.makedirs(OUT, exist_ok=True)
    report = {}
    for name in NAMES:
        im = Image.open(os.path.join(SRC, name + '_src.png')).convert('RGBA')
        assert im.size == (2172, 724), (name, im.size)
        a = np.asarray(im)
        sheet = Image.new('RGBA', (FW * N, FH), (0, 0, 0, 0))
        for i in range(N):
            c = feather(cell(a, i))
            low, cx = base_of(c)
            dx = BASE_COL - round(cx)
            dy = BASE_ROW - low
            fr = Image.new('RGBA', (FW, FH), (0, 0, 0, 0))
            fr.alpha_composite(Image.fromarray(c), (dx, dy)) if dx >= 0 and dy >= 0 else _paste(fr, c, dx, dy)
            sheet.alpha_composite(fr, (i * FW, 0))
            report[(name, i)] = (dx, dy)
        sheet.save(os.path.join(OUT, 'altar_shard_%s.png' % name))
    return report


def _paste(fr, c, dx, dy):
    """alpha_composite with an offset that may be negative (the cell is cropped to the frame)."""
    im = Image.fromarray(c)
    sx, sy = max(-dx, 0), max(-dy, 0)
    im = im.crop((sx, sy, im.width, im.height))
    fr.alpha_composite(im, (max(dx, 0), max(dy, 0)))


if __name__ == '__main__':
    r = build()
    print('shifts (dx, dy) range:', min(v[0] for v in r.values()), max(v[0] for v in r.values()), min(v[1] for v in r.values()), max(v[1] for v in r.values()))
