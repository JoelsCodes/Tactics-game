#!/usr/bin/env python3
"""Cuts a character's sixteen expression portraits from the owner's 4 x 4 sheet on a white background (Bram's and Lyra's, Nov 2026).

    python3 godot/tools/art/portraits_set.py          # both
    python3 godot/tools/art/portraits_set.py bram

For each sheet: the white background is keyed out (only white connected to a cell's border, so a highlight inside the picture is kept), the alpha is made hard
and the pale halo on the edge is taken off (as alaric_v2_portrait.py does for Alaric's), each cell is cut by its own bounds, and the sixteen are written to
assets/characters/<key>/portraits/portrait_01..16.png. meta.json gets `portraits` (the sixteen), `portrait` (the neutral one) and `portrait_names` (the
same sixteen names as Alaric's, in the sheet's row-by-row order, which FacePicker's rules and a story step's `face` use) and `portrait_eye_y`.
Run it after char_extras.py (which still writes the older five small portraits; this replaces them): build_characters.sh does.
Faces by position: neutral, calm, surprised, shout / eyes_closed, smile, laugh, cry_out / startled, worried, angry, looking_up / sad, pained, head_down, faint.
"""
import json
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage as nd

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
META = os.path.join(ROOT, 'assets', 'characters', 'meta.json')
NAMES = ['neutral', 'calm', 'surprised', 'shout', 'eyes_closed', 'smile', 'laugh', 'cry_out',
         'startled', 'worried', 'angry', 'looking_up', 'sad', 'pained', 'head_down', 'faint']
SHEETS = {
    'bram': {'key': 'warden', 'src': 'art_src/characters/bram_portraits_sheet.png', 'eye_y': 0.5},   # Bram's sheet id is `warden`
    'lyra': {'key': 'mira', 'src': 'art_src/characters/lyra_portraits_sheet.png', 'eye_y': 0.44},    # Lyra's is `mira`
}


def spans(v, gap_min=20):
    out, start = [], None
    for i, x in enumerate(v):
        if x and start is None:
            start = i
        if not x and start is not None:
            if i - start > gap_min:
                out.append((start, i))
            start = None
    if start is not None and len(v) - start > gap_min:
        out.append((start, len(v)))
    return out


def cut_cell(rgb):
    h, w = rgb.shape[:2]
    near_white = rgb.min(2) >= 238
    lab, n = nd.label(near_white)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    sizes = nd.sum(near_white, lab, range(1, n + 1)) if n else []
    big = {i + 1 for i, sz in enumerate(sizes) if sz >= 25}  # a gap enclosed by hair is background too; a speck of highlight (smaller) stays
    bg = np.isin(lab, list(edge | big))
    solid = ~bg
    solid = nd.binary_opening(solid, np.ones((3, 3)))
    lab2, n2 = nd.label(solid)  # keep the picture: the biggest piece
    if n2 > 1:
        sizes = nd.sum(solid, lab2, range(1, n2 + 1))
        solid = lab2 == (int(np.argmax(sizes)) + 1)
    rim = solid & ~nd.binary_erosion(solid, iterations=2)
    solid &= ~(rim & (rgb.min(2) > 222))  # the pale halo
    out = np.dstack([rgb, np.where(solid, 255, 0).astype(np.uint8)])
    out[~solid] = 0
    ys, xs = np.nonzero(solid)
    return Image.fromarray(out[ys.min():ys.max() + 1, xs.min():xs.max() + 1], 'RGBA')


def build(name):
    cfg = SHEETS[name]
    rgb = np.array(Image.open(os.path.join(ROOT, cfg['src'])).convert('RGB'))
    nonwhite = rgb.min(2) < 235
    cols, rows = spans(nonwhite.sum(0) > 12), spans(nonwhite.sum(1) > 12)
    assert len(cols) == 4 and len(rows) == 4, '%s: expected 4 x 4 cells, found %d x %d: %s %s' % (name, len(cols), len(rows), cols, rows)
    out_dir = os.path.join(ROOT, 'assets', 'characters', cfg['key'], 'portraits')
    os.makedirs(out_dir, exist_ok=True)
    sizes = []
    for i in range(16):
        (y0, y1), (x0, x1) = rows[i // 4], cols[i % 4]
        pad = 4
        cell = rgb[max(y0 - pad, 0):y1 + pad, max(x0 - pad, 0):x1 + pad]
        im = cut_cell(cell)
        im.save(os.path.join(out_dir, 'portrait_%02d.png' % (i + 1)))
        sizes.append(im.size)
    for k in range(17, 100):  # the older sheets' extra portraits, if any
        stale = os.path.join(out_dir, 'portrait_%02d.png' % k)
        if os.path.exists(stale):
            os.remove(stale)
            if os.path.exists(stale + '.import'):
                os.remove(stale + '.import')
    text = open(META, encoding='utf-8').read()
    meta = json.loads(text)
    indent = 1 if '\n "' in text else 2
    e = meta[cfg['key']]
    e['portraits'] = ['portraits/portrait_%02d.png' % (i + 1) for i in range(16)]
    e['portrait'] = 'portraits/portrait_01.png'
    e['portrait_names'] = list(NAMES)
    e['portrait_eye_y'] = cfg['eye_y']
    with open(META, 'w', encoding='utf-8') as f:
        f.write(json.dumps(meta, indent=indent, ensure_ascii=False) + '\n')
    print('%s (%s): 16 portraits, sizes %d-%d x %d-%d' % (name, cfg['key'], min(s[0] for s in sizes), max(s[0] for s in sizes), min(s[1] for s in sizes), max(s[1] for s in sizes)))


if __name__ == '__main__':
    for n in (sys.argv[1:] or list(SHEETS)):
        build(n)
