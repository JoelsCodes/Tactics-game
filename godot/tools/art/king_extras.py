#!/usr/bin/env python3
"""Cuts the supplementary assets of the King's sheet (the bottom section of
art_src/characters/king_sheet.webp) into reusable game assets. The sheet's colour variations are not
used (the owner removed them): this script does not cut or bake them.

  python3 godot/tools/art/eight_dir.py       (animations first)
  python3 godot/tools/art/king_extras.py     (then this; needs Pillow, numpy, scipy)
  godot --headless --path godot --import
  godot --headless --path godot --script res://tools/build_resources.gd

Writes under assets/characters/king/:
  effects/<group>/<name>_<n>.png   slashes, magic_circles, eruptions, bursts, smoke (one image per frame)
  portraits/portrait_01..05.png    the five painted portraits, cropped and unscaled
  equipment/sword.png              the sword (background removed) and sword_panel.png (as drawn)
  artwork/full_portrait.png        the large illustration
and the effects and portraits entries of meta.json.

Rules followed: the original sheet is never modified; no grid lines or titles are cropped in (every
rectangle sits inside its panel frame); nothing is stretched; the effects are keyed by flood-filling
magenta from the cell edges only, so violet glows inside an effect are kept, and a check counts
magenta-looking pixels left inside each effect.
"""
import json
import os
import sys

import numpy as np
import scipy.ndimage as nd
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from eight_dir import ROOT, SHEETS, masks, sprite_runs, trim  # noqa: E402

SRC = os.path.join(ROOT, 'art_src', 'characters', 'king_sheet.webp')
OUT = os.path.join(ROOT, 'assets', 'characters', 'king')

# --- where things are on the sheet (x0, y0, x1, y1), each inside its panel frame ---
PORTRAITS = [(12, 858, 149, 1009), (157, 858, 249, 1009), (257, 858, 358, 1009), (365, 858, 462, 1009), (469, 858, 673, 1009)]
SWORD = (1234, 748, 1299, 1014)
ILLUSTRATION = (1311, 750, 1526, 1012)

# effect groups: folder, file prefix, number of frames (cells of the particle row, left to right)
FX_GROUPS = [('slashes', 'swirl', 1), ('slashes', 'slash', 4), ('slashes', 'rend', 1), ('eruptions', 'eruption', 5),
             ('magic_circles', 'circle', 1), ('bursts', 'burst', 1), ('smoke', 'smoke', 4)]
FX_BOX = (6, 765, 1226, 825)


# ---------- keying ----------

def key_flood(img, inner=70.0, outer=150.0):
    """Transparent only where the magenta background touches the crop's border: the pixels within
    `inner` of magenta that are connected to the edge go fully transparent, and a soft band of
    `outer` around that region fades out (with the magenta tint removed). Magenta-like pixels that are
    enclosed by the artwork stay."""
    a = np.asarray(img.convert('RGB')).astype(np.float32)
    dist = np.sqrt(((a - np.array([255.0, 0.0, 255.0])) ** 2).sum(-1))
    near = dist < outer
    lab, n = nd.label(near)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bg = np.isin(lab, list(edge))
    # distance into the background region: soft alpha on the band next to the artwork
    alpha = np.where(bg, np.clip((dist - inner) / max(outer - inner, 1e-3), 0, 1), 1.0)
    # despill the soft band
    spill = np.clip(np.minimum(a[..., 0], a[..., 2]) - a[..., 1], 0, None) * (alpha < 1.0)
    a[..., 0] -= spill
    a[..., 2] -= spill
    out = np.dstack([np.clip(a, 0, 255), alpha * 255]).astype(np.uint8)
    out[out[..., 3] == 0, :3] = 0
    return Image.fromarray(out, 'RGBA'), int(bg.sum())


def magenta_inside(img):
    """How many opaque pixels still look like the magenta background (a leak) in an RGBA image."""
    a = np.asarray(img).astype(int)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    return int(((r > 215) & (b > 200) & (g < 70) & (a[..., 3] > 200)).sum())


def key_by_edge_color(img, tol=34.0):
    """For artwork on a flat dark panel (the sword): transparent where the panel colour reaches the border."""
    a = np.asarray(img.convert('RGB')).astype(np.float32)
    border = np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]])
    bgc = np.median(border, axis=0)
    dist = np.sqrt(((a - bgc) ** 2).sum(-1))
    lab, _ = nd.label(dist < tol)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bg = np.isin(lab, list(edge))
    alpha = np.where(bg, np.clip((dist - tol * 0.5) / (tol * 0.8), 0, 1), 1.0)
    alpha = nd.gaussian_filter(alpha, 0.6) if False else alpha
    out = np.dstack([a, alpha * 255]).astype(np.uint8)
    return Image.fromarray(out, 'RGBA')


# ---------- the extraction ----------

def save(img, *path):
    p = os.path.join(OUT, *path)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    img.save(p, optimize=True)
    return os.path.relpath(p, OUT).replace(os.sep, '/')


def extract_effects(sheet):
    a = np.asarray(sheet).astype(np.int32)
    _div, _loose, sprite = masks(a)
    runs = sprite_runs(sprite, FX_BOX[0] + 2, FX_BOX[1] + 2, FX_BOX[2] - 2, FX_BOX[3] - 2)
    effects = {}
    leaks = {}
    k = 0
    for folder, name, count in FX_GROUPS:
        for i in range(count):
            if k >= len(runs):
                break
            x0, x1 = runs[k]
            k += 1
            cell = sheet.crop((x0 - 2, FX_BOX[1] + 2, x1 + 2, FX_BOX[3] - 2))
            img, _ = key_flood(cell)
            img, _bb = trim(img)
            rel = save(img, 'effects', folder, '%s_%d.png' % (name, i))
            effects.setdefault(name if name in ('slash', 'eruption', 'smoke', 'circle', 'burst', 'swirl', 'rend') else name, []).append(rel)
            leaks[rel] = magenta_inside(img)
    return effects, leaks


def extract_portraits(sheet):
    out = []
    for i, r in enumerate(PORTRAITS, 1):
        out.append(save(sheet.crop(r).convert('RGBA'), 'portraits', 'portrait_%02d.png' % i))
    return out


def extract_art(sheet):
    save(sheet.crop(ILLUSTRATION).convert('RGBA'), 'artwork', 'full_portrait.png')
    save(sheet.crop(SWORD).convert('RGBA'), 'equipment', 'sword_panel.png')
    save(key_by_edge_color(sheet.crop(SWORD)), 'equipment', 'sword.png')


def main():
    sheet = Image.open(SRC).convert('RGB')
    meta_path = os.path.join(ROOT, 'assets', 'characters', 'meta.json')
    meta = json.load(open(meta_path))
    effects, leaks = extract_effects(sheet)
    portraits = extract_portraits(sheet)
    extract_art(sheet)
    meta['king']['effects'] = {n: {'frames': fr, 'fps': 14} for n, fr in effects.items()}
    meta['king']['portraits'] = portraits
    meta['king'].pop('palettes', None)
    with open(meta_path, 'w') as f:
        json.dump(meta, f, indent=1)
    print('effects', {n: len(v) for n, v in effects.items()}, 'magenta-looking pixels inside:', {os.path.basename(k): v for k, v in leaks.items() if v})
    print('portraits', len(portraits))


if __name__ == '__main__':
    main()
