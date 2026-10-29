#!/usr/bin/env python3
"""Cuts the supplementary assets of the King's sheet (the bottom section of
art_src/characters/king_sheet.webp) into reusable game assets, and recolors the King's animation
frames into the sheet's colour variations.

  python3 godot/tools/art/eight_dir.py       (animations first)
  python3 godot/tools/art/king_extras.py     (then this; needs Pillow, numpy, scipy)
  godot --headless --path godot --import
  godot --headless --path godot --script res://tools/build_resources.gd

Writes under assets/characters/king/:
  effects/<group>/<name>_<n>.png   slashes, magic_circles, eruptions, bursts, smoke (one image per frame)
  portraits/portrait_01..05.png    the five painted portraits, cropped and unscaled
  palettes/<name>.json             swatches, tonal ramps, preview and portrait of each colour variation
  palettes/previews/<name>.png     the small preview sprites (references only, not animation frames)
  palettes/portraits/<name>.png    the portraits that match each variation
  equipment/sword.png              the sword (background removed) and sword_panel.png (as drawn)
  artwork/full_portrait.png        the large illustration
and the recolored animation sets assets/characters/king_<name>/ (+ entries in meta.json).

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
PALETTES = ['original', 'red', 'blue', 'white', 'purple', 'green', 'brown', 'gold', 'crimson']
PAL_X0, PAL_STEP = 686, 60
PREVIEW = (0, 851, 59, 927)  # relative x0..x1 inside a palette cell
SWATCH = (7, 930, 53, 941)
PAL_PORTRAIT = (1, 952, 59, 1011)

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


# ---------- colour classes and palettes ----------

def hsv(a):
    r, g, b = a[..., 0] / 255.0, a[..., 1] / 255.0, a[..., 2] / 255.0
    mx, mn = np.maximum(np.maximum(r, g), b), np.minimum(np.minimum(r, g), b)
    d = mx - mn
    h = np.zeros_like(mx)
    m = d > 1e-6
    rc = np.where(m & (mx == r), ((g - b) / np.where(m, d, 1)) % 6, 0)
    gc = np.where(m & (mx == g) & (mx != r), (b - r) / np.where(m, d, 1) + 2, 0)
    bc = np.where(m & (mx == b) & (mx != r) & (mx != g), (r - g) / np.where(m, d, 1) + 4, 0)
    h = (rc + gc + bc) * 60.0
    s = np.where(mx > 1e-6, d / np.where(mx > 1e-6, mx, 1), 0)
    return h, s, mx


def lum(a):
    return 0.299 * a[..., 0] + 0.587 * a[..., 1] + 0.114 * a[..., 2]


def classes(a):
    """Per pixel of an RGB array (0-255): 'skin' mask, 'hair' (light, low-saturation) and 'outfit' (the rest)."""
    h, s, v = hsv(a)
    L = lum(a)
    skin = (h > 8) & (h < 48) & (s > 0.22) & (s < 0.75) & (v > 0.45) & (a[..., 0] > a[..., 1]) & (a[..., 1] > a[..., 2])
    hair = ~skin & (L > 150) & (s < 0.28)
    outfit = ~skin & ~hair
    return skin, hair, outfit


N_STOPS = 17  ## stops of a ramp: the mean colour at evenly spaced percentiles of luminance


def ramp_of(pixels):
    """A ramp of N_STOPS colours: the mean colour of the pixels around each percentile of luminance
    (0 = darkest, 1 = lightest). Matching percentiles between two variations keeps the shading's
    distribution: the lightest 10% of the original's coat becomes the lightest 10% of the new coat."""
    order = np.argsort(lum(pixels))
    px = pixels[order]
    n = len(px)
    w = max(1, n // 40)
    out = []
    for k in range(N_STOPS):
        i = int(k / (N_STOPS - 1) * (n - 1))
        out.append(px[max(0, i - w):i + w + 1].mean(0))
    return np.array(out)


GAMMA = {'white': 0.45, 'gold': 0.55, 'brown': 0.8, 'green': 0.9}  ## tone lift of the light variations
TOLERANCE = {'crimson': 22.0, 'purple': 60.0, 'blue': 55.0}
NOT_BLUISH = ['brown']  ## the preview's panel is slate blue and the outfit warm: bluish pixels are panel, not outfit  ## background flood tolerance per preview (default 42): the dark red panel is close to the coat


def preview_fg(img_rgb, tol=42.0):
    """Foreground mask of a palette preview sprite: not the flat panel colour that reaches the border."""
    a = np.asarray(img_rgb).astype(np.float32)
    border = np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]])
    bgc = np.median(border, axis=0)
    dist = np.sqrt(((a - bgc) ** 2).sum(-1))
    lab, _ = nd.label(dist < tol)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bg = np.isin(lab, list(edge))
    fg = ~bg
    fg = nd.binary_opening(fg, np.ones((2, 2)))
    lab2, n = nd.label(nd.binary_closing(fg, np.ones((3, 3))))  # one figure even where its outline has gaps
    if n > 1:  # drop specks (panel noise); keep every piece of the figure
        sizes = nd.sum(fg, lab2, range(1, n + 1))
        keep = [i + 1 for i, sz in enumerate(sizes) if sz >= 0.04 * sizes.max()]
        fg = fg & np.isin(lab2, keep)
    fg = nd.binary_fill_holes(fg)
    return fg, a


def analyse_preview(img_rgb, tol=42.0, not_bluish=False):
    """Hair and outfit ramps of one colour variation, read from its preview sprite. The head is the top
    quarter of the figure: its non-skin pixels are the hair; below it everything but skin is the outfit."""
    fg, a = preview_fg(img_rgb, tol)
    if not_bluish:
        fg = fg & ~(a[..., 2] > a[..., 0] + 6)
    ys, xs = np.nonzero(fg)
    top, bot = ys.min(), ys.max()
    head_end = top + int((bot - top) * 0.26)
    rows = np.arange(a.shape[0])[:, None] * np.ones((1, a.shape[1]))
    skin = classes(a)[0]
    hair = fg & ~skin & (rows < head_end)
    outfit = fg & ~skin & (rows >= head_end)
    # the dark outline pixels are part of the outfit ramp's bottom, fine; tiny hair sets fall back to the outfit
    return ramp_of(a[hair] if hair.sum() > 25 else a[outfit]), ramp_of(a[outfit]), fg


def apply_ramp(a, mask, base_ramp, new_ramp, gamma=1.0):
    """Recolors the masked pixels by percentile: a pixel's luminance is placed on the base ramp (its
    percentile in the original's tonal range), and the colour at that percentile of the new ramp replaces it."""
    if not mask.any():
        return a
    bl = np.maximum.accumulate(lum(base_ramp) + np.arange(N_STOPS) * 0.02)
    t = np.interp(lum(a), bl, np.arange(N_STOPS) / (N_STOPS - 1.0))
    t = t ** gamma  # a light variation lifts the tones: a black coat has to become a white one
    ts = np.arange(N_STOPS) / (N_STOPS - 1.0)
    out = np.stack([np.interp(t, ts, new_ramp[:, c]) for c in range(3)], axis=-1)
    res = a.copy()
    res[mask] = out[mask]
    return res


def recolor(img, base, variant, gamma=1.0):
    """Recolors an RGBA frame from the base variation's ramps to the variant's; skin, eyes and the
    magic's violet are left alone, alpha is untouched."""
    arr = np.asarray(img).astype(np.float32)
    rgb = arr[..., :3]
    skin, hair, outfit = classes(rgb)
    # leave saturated violet/blue magic glows alone: they are strongly coloured and not part of the outfit
    h, s, v = hsv(rgb)
    magic = (s > 0.45) & (h > 230) & (h < 300) & (v > 0.35)
    keep = skin | magic | (arr[..., 3] < 8)
    res = apply_ramp(rgb, hair & ~keep, base['hair'], variant['hair'], min(1.0, gamma * 1.3))
    res = apply_ramp(res, outfit & ~keep, base['outfit'], variant['outfit'], gamma)
    out = np.dstack([np.clip(res, 0, 255), arr[..., 3]]).astype(np.uint8)
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


def extract_palettes(sheet):
    info = {}
    for i, name in enumerate(PALETTES):
        x0 = PAL_X0 + PAL_STEP * i
        prev = sheet.crop((x0 + PREVIEW[0], PREVIEW[1], x0 + PREVIEW[2], PREVIEW[3])).convert('RGB')
        hair, outfit, fg = analyse_preview(prev, TOLERANCE.get(name, 42.0), name in NOT_BLUISH)
        prev_rgba = np.dstack([np.asarray(prev), fg * 255]).astype(np.uint8)
        save(Image.fromarray(prev_rgba, 'RGBA'), 'palettes', 'previews', name + '.png')
        sw = sheet.crop((x0 + SWATCH[0], SWATCH[1], x0 + SWATCH[2], SWATCH[3])).convert('RGB')
        swa = np.asarray(sw).astype(float)
        w = swa.shape[1] / 4.0
        swatches = [tuple(int(v) for v in swa[2:-2, int(j * w + w * 0.3):int(j * w + w * 0.7)].reshape(-1, 3).mean(0)) for j in range(4)]
        por = save(sheet.crop((x0 + PAL_PORTRAIT[0], PAL_PORTRAIT[1], x0 + PAL_PORTRAIT[2], PAL_PORTRAIT[3])).convert('RGBA'), 'palettes', 'portraits', name + '.png')
        info[name] = {'hair': hair, 'outfit': outfit, 'swatches': swatches, 'preview': 'palettes/previews/%s.png' % name, 'portrait': por}
    return info


def hexc(c):
    return '#%02x%02x%02x' % tuple(int(round(v)) for v in c)


def write_palettes(info):
    for name, d in info.items():
        doc = {'name': name, 'label': name.capitalize(), 'swatches': [hexc(c) for c in d['swatches']],
               'hair_ramp': [hexc(c) for c in d['hair']], 'outfit_ramp': [hexc(c) for c in d['outfit']],
               'preview': d['preview'], 'portrait': d['portrait'],
               'note': 'The preview is a reference only. The in-game appearance is the original animation frames recolored by mapping '
                       'percentile-matching luminance through outfit_ramp and hair_ramp, lifted by tone_gamma (tools/art/king_extras.py); skin, eyes and magic are not recolored.',
               'tone_gamma': GAMMA.get(name, 1.0)}
        with open(os.path.join(OUT, 'palettes', name + '.json'), 'w') as f:
            json.dump(doc, f, indent=1)


def bake_variants(info, meta):
    base = info['original']
    king = meta['king']
    src_dir = os.path.join(ROOT, 'assets', 'characters', 'king')
    for name in PALETTES[1:]:
        key = 'king_' + name
        dst_dir = os.path.join(ROOT, 'assets', 'characters', key)
        # copy the animation tree recolored
        for dirpath, _dirs, files in os.walk(os.path.join(src_dir, 'animations')):
            for fn in files:
                if not fn.endswith('.png'):
                    continue
                rel = os.path.relpath(os.path.join(dirpath, fn), src_dir)
                img = Image.open(os.path.join(dirpath, fn)).convert('RGBA')
                p = os.path.join(dst_dir, rel)
                os.makedirs(os.path.dirname(p), exist_ok=True)
                recolor(img, base, info[name], GAMMA.get(name, 1.0)).save(p, optimize=True)
        por = Image.open(os.path.join(OUT, info[name]['portrait'])).convert('RGBA')
        por.save(os.path.join(dst_dir, 'portrait.png'), optimize=True)
        entry = json.loads(json.dumps(king))
        entry['palette'] = name
        entry['effects_from'] = 'king'
        entry['portrait'] = 'portrait.png'
        meta[key] = entry


def main():
    sheet = Image.open(SRC).convert('RGB')
    meta_path = os.path.join(ROOT, 'assets', 'characters', 'meta.json')
    meta = json.load(open(meta_path))
    effects, leaks = extract_effects(sheet)
    portraits = extract_portraits(sheet)
    extract_art(sheet)
    info = extract_palettes(sheet)
    write_palettes(info)
    meta['king']['effects'] = {n: {'frames': fr, 'fps': 14} for n, fr in effects.items()}
    meta['king']['portraits'] = portraits
    meta['king']['palettes'] = PALETTES
    bake_variants(info, meta)
    with open(meta_path, 'w') as f:
        json.dump(meta, f, indent=1)
    print('effects', {n: len(v) for n, v in effects.items()}, 'magenta-looking pixels inside:', {os.path.basename(k): v for k, v in leaks.items() if v})
    print('portraits', len(portraits), 'palettes', len(PALETTES))


if __name__ == '__main__':
    main()
