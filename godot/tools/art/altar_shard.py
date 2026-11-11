#!/usr/bin/env python3
"""Cuts the Altar Shard sheet (art_src/altar_shard/altar_shard_sheet.png: 2172 x 724, transparent; a label column on the left, then four rows
idle / activate / summon / depleted of eight frames each) into aligned sheets in assets/sprites/altar_shard/altar_shard_<name>.png:
eight frames of 250 x 182 each.

How the sheet is laid out (measured, not assumed): the stone's base is on the same 249.4 px pitch in every row, its first centre at x = 341.5, and the rows are
181.5 px apart (the base's lowest row is 164 in the first). Each frame is cut around that. Then, per frame:
  - the base is aligned: the lowest solid row of the stone goes to BASE_ROW and the base's centre to BASE_COL (the sheet drifts by a pixel or two);
  - the glow of the big frames runs into the neighbouring cells (and above the row's top) where the sheet has no room, so a cut would leave a hard edge:
    the soft pixels (alpha under SOLID) are faded to nothing over FEATHER px at each side and at the top of the cell. The solid stone is never touched.
Usage: python3 godot/tools/art/altar_shard.py   (needs Pillow and numpy)."""
import os
import numpy as np
from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
SRC = os.path.join(ROOT, 'art_src', 'altar_shard', 'altar_shard_sheet.png')
OUT = os.path.join(ROOT, 'assets', 'sprites', 'altar_shard')
NAMES = ['idle', 'activate', 'summon', 'depleted']
N = 8
CX0 = 341.5  # centre of the first frame's base
PITCH_X = 249.4
PITCH_Y = 181.5
FW, FH = 250, 182  # the output frame
BASE_ROW = 164  # where the stone's lowest solid row lands (the sheet has it there in the first row)
BASE_COL = 125
SOLID = 250
FEATHER = 24


def base_of(c):
    """(lowest solid row, centre column) of the stone's foot in a cell."""
    al = c[..., 3]
    mid = al[:, BASE_COL - 70:BASE_COL + 70]
    rows = np.nonzero((mid > 128).any(1))[0]
    low = int(rows.max())
    cols = np.nonzero((mid[low - 14:low + 1] > 128).any(0))[0]
    return low, (int(cols.min()) + int(cols.max())) / 2.0 + BASE_COL - 70


def feather(c):
    al = c[..., 3].astype(np.float32)
    h, w = al.shape
    k = np.arange(FEATHER, dtype=np.float32) / FEATHER
    ramp_x = np.ones(w, np.float32)
    ramp_x[:FEATHER] = k
    ramp_x[w - FEATHER:] = k[::-1]
    ramp_y = np.ones(h, np.float32)
    ramp_y[:FEATHER] = k
    ramp = ramp_y[:, None] * ramp_x[None, :]
    c[..., 3] = np.where(al < SOLID, al * ramp, al).astype(np.uint8)
    return c


def build():
    os.makedirs(OUT, exist_ok=True)
    im = Image.open(SRC).convert('RGBA')
    assert im.size == (2172, 724), im.size
    a = np.pad(np.asarray(im), ((0, 8), (0, 80), (0, 0)))  # room for the last frame's glow past the sheet's edge
    shifts = []
    for r, name in enumerate(NAMES):
        sheet = Image.new('RGBA', (FW * N, FH), (0, 0, 0, 0))
        y0 = round(r * PITCH_Y)
        cells = []
        for i in range(N):
            x0 = round(CX0 + i * PITCH_X) - BASE_COL
            c = a[y0:y0 + FH, x0:x0 + FW].copy()
            assert c.shape[:2] == (FH, FW), (name, i, c.shape)
            cells.append(c)
        found = [base_of(c) for c in cells]
        mlow = float(np.median([f[0] for f in found]))
        mcx = float(np.median([f[1] for f in found]))
        for i, c in enumerate(cells):
            low, cx = found[i]
            if abs(low - mlow) > 3:
                low = mlow  # a bright ring or burst under the stone fooled the search for its foot: use the row's own value
            if abs(cx - mcx) > 3:
                cx = mcx
            dx, dy = BASE_COL - round(cx), BASE_ROW - round(low)
            c = feather(c)
            fr = Image.new('RGBA', (FW, FH), (0, 0, 0, 0))
            piece = Image.fromarray(c)
            sx, sy = max(-dx, 0), max(-dy, 0)
            fr.alpha_composite(piece.crop((sx, sy, FW, FH)), (max(dx, 0), max(dy, 0)))
            sheet.alpha_composite(fr, (i * FW, 0))
            shifts.append((dx, dy))
        sheet.save(os.path.join(OUT, 'altar_shard_%s.png' % name))
    return shifts


if __name__ == '__main__':
    s = build()
    print('shifts (dx, dy) range: x %d..%d  y %d..%d' % (min(v[0] for v in s), max(v[0] for v in s), min(v[1] for v in s), max(v[1] for v in s)))
