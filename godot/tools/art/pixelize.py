"""EXPERIMENTAL, not run by any build step yet. Post-processing that turns a soft, AI-looking sprite into a clean pixel-art one (Nov 2026).

AI sheets come with soft anti-aliased edges, gradients and speckle, and the cutter's LANCZOS downscale softens them more. This module
works on frames already scaled to the size the game uses (RGBA PIL images):

  shared_palette(imgs, colors)   one palette for all of a character's frames (so colours do not drift between animations), by median cut
                                 over the opaque pixels only
  pixelize(img, palette, ...)    1. alpha is made hard (a pixel is in or out, no semi-transparent edge)
                                 2. every colour snaps to the palette, with no dithering
                                 3. speckle is removed: a pixel whose colour no neighbour shares takes its neighbours' majority colour
                                    (isolated opaque pixels are dropped, one-pixel holes are filled)
                                 4. selective outline: the silhouette's edge pixels are darkened (a shade of their own colour, not black)
                                    so the outline is one crisp pixel wide

It never changes the frame's size or where the figure stands. sheet_set.py calls it when a config has a 'pixelize' entry.
"""
import numpy as np
from PIL import Image

SPECK_DISTANCE = 70  # summed RGB difference under which a one-pixel colour speckle is smoothed away


def _opaque_pixels(imgs):
    px = [np.asarray(im.convert('RGBA'))[..., :3][np.asarray(im.convert('RGBA'))[..., 3] > 127] for im in imgs]
    return np.concatenate(px, axis=0)


def shared_palette(imgs, colors=32):
    """A PIL 'P' image holding the palette: `colors` colours chosen over every opaque pixel of every frame."""
    px = _opaque_pixels(imgs)
    # median cut follows pixel counts, which starves the small things that matter (eyes, outlines, highlights): count each distinct
    # colour (rounded to 5 bits) by count ** 0.4 instead of its full count
    q = (px >> 3).astype(np.int32)
    key = q[:, 0] * 1024 + q[:, 1] * 32 + q[:, 2]
    uniq, inv, cnt = np.unique(key, return_inverse=True, return_counts=True)
    mean = np.zeros((len(uniq), 3))
    np.add.at(mean, inv, px.astype(np.float64))
    mean = (mean / cnt[:, None]).astype(np.uint8)
    px = np.repeat(mean, np.maximum(1, np.round(cnt ** 0.4)).astype(int), axis=0)
    n = len(px)
    w = 1024
    h = -(-n // w)
    flat = np.zeros((h * w, 3), np.uint8)
    flat[:n] = px
    flat[n:] = px[: h * w - n] if n >= h * w - n else px[0]
    strip = Image.fromarray(flat.reshape(h, w, 3), 'RGB')
    return strip.quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)


def _neighbours(a):
    """The eight shifted copies of a 2-D (or 3-D) array, padded with the edge value."""
    p = np.pad(a, [(1, 1), (1, 1)] + [(0, 0)] * (a.ndim - 2), mode='edge')
    h, w = a.shape[:2]
    return [p[1 + dy:1 + dy + h, 1 + dx:1 + dx + w] for dy in (-1, 0, 1) for dx in (-1, 0, 1) if (dy, dx) != (0, 0)]


def pixelize(img, palette, outline=0.6, despeckle=True):
    img = img.convert('RGBA')
    arr = np.asarray(img).copy()
    alpha = arr[..., 3] >= 128
    rgb = Image.fromarray(arr[..., :3], 'RGB').quantize(palette=palette, dither=Image.Dither.NONE)
    idx = np.asarray(rgb).astype(np.int32)
    idx = np.where(alpha, idx, -1)
    if despeckle:
        for _ in range(2):
            nb = _neighbours(idx)
            same = sum((n == idx).astype(np.int32) for n in nb)
            opaque_nb = sum((n >= 0).astype(np.int32) for n in nb)
            # a lone opaque pixel (no opaque 4-neighbour of its own) is dropped
            four = [nb[1], nb[3], nb[4], nb[6]]
            lone = alpha & (sum((n >= 0).astype(np.int32) for n in four) == 0)
            # a hole: transparent, with opaque pixels on at least 3 of 4 sides, is filled by the most common neighbour
            hole = (~alpha) & (sum((n >= 0).astype(np.int32) for n in four) >= 3)
            # a colour speckle: opaque, no neighbour shares its colour
            speck = alpha & (same == 0) & (opaque_nb >= 5)
            stack = np.stack(nb, axis=0)
            maj = np.zeros(idx.shape, np.int32)
            best = np.zeros(idx.shape, np.int32)
            for c in np.unique(stack[stack >= 0]):
                cnt = (stack == c).sum(0)
                better = cnt > best
                maj = np.where(better, c, maj)
                best = np.where(better, cnt, best)
            pal_rgb = np.asarray(palette.getpalette()[:768], np.int32).reshape(-1, 3)
            d = np.abs(pal_rgb[np.clip(idx, 0, len(pal_rgb) - 1)] - pal_rgb[np.clip(maj, 0, len(pal_rgb) - 1)]).sum(-1)
            close = d <= SPECK_DISTANCE  # a speckle is close to its surroundings; an eye or a highlight is not
            fix = ((speck & close) | hole) & (best >= 3)
            idx = np.where(fix, maj, idx)
            idx = np.where(lone, -1, idx)
            alpha = idx >= 0
    pal = np.asarray(palette.getpalette()[:768], np.uint8).reshape(-1, 3)
    out = np.zeros(idx.shape + (4,), np.uint8)
    out[alpha, :3] = pal[np.clip(idx[alpha], 0, len(pal) - 1)]
    out[alpha, 3] = 255
    if outline:
        edge = alpha & ~np.all([n >= 0 for n in (_neighbours(idx)[1], _neighbours(idx)[3], _neighbours(idx)[4], _neighbours(idx)[6])], axis=0)
        rgbf = out[..., :3].astype(np.float32)
        lum = rgbf @ np.array([0.299, 0.587, 0.114], np.float32)
        dark = (rgbf * outline).astype(np.uint8)
        use = edge & (lum > 45)   # the figure's own dark outline stays as it is
        out[..., :3] = np.where(use[..., None], dark, out[..., :3])
    return Image.fromarray(out, 'RGBA')
