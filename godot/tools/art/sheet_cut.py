"""Cutting sprites out of generated sprite sheets: finding rows and frames on a flat
background, removing the background with soft edges, and trimming. Pure Pillow/numpy/scipy.
"""
import numpy as np
from PIL import Image, ImageDraw
import scipy.ndimage as nd

def load(path):
    im = Image.open(path).convert('RGB')
    return im, np.asarray(im).astype(np.float32)

def bg_of(a):
    b = np.concatenate([a[:6].reshape(-1,3), a[-6:].reshape(-1,3), a[:,:6].reshape(-1,3), a[:,-6:].reshape(-1,3)])
    return np.median(b, axis=0)

def dist(a, bg):
    return np.sqrt(((a - bg) ** 2).sum(-1))

def runs(v, gap=6, minlen=3):
    """[(start, end)] of True runs in v, merging runs separated by < gap."""
    idx = np.nonzero(v)[0]
    out = []
    if len(idx) == 0:
        return out
    s = p = idx[0]
    for i in idx[1:]:
        if i - p > gap:
            if p - s + 1 >= minlen:
                out.append((int(s), int(p) + 1))
            s = i
        p = i
    if p - s + 1 >= minlen:
        out.append((int(s), int(p) + 1))
    return out

def section_frames(a, bg, rect, thr=58, row_gap=10, col_gap=10, min_h=40):
    """Rows of frame boxes inside rect=(x0,y0,x1,y1): [[(x0,y0,x1,y1),...],...]"""
    x0, y0, x1, y1 = rect
    sub = dist(a[y0:y1, x0:x1], bg) > thr
    sub = nd.binary_opening(sub, structure=np.ones((2, 2)))
    rows = runs(sub.sum(1) > 2, gap=row_gap, minlen=min_h)
    out = []
    for (ry0, ry1) in rows:
        band = sub[ry0:ry1]
        cols = runs(band.sum(0) > 1, gap=col_gap, minlen=14)
        row = []
        for (cx0, cx1) in cols:
            blk = band[:, cx0:cx1]
            ys = np.nonzero(blk.any(1))[0]
            row.append((x0 + cx0, y0 + ry0 + int(ys.min()), x0 + cx1, y0 + ry0 + int(ys.max()) + 1))
        out.append(row)
    return out

def matte(a, box, pad=10, lo=6, hi=20, seal=2):
    """RGBA crop of box (+pad) with the sheet background removed (soft edges).
    The background is the part of the crop connected to its border that stays within
    `hi` of the border color, after closing small gaps in the sprite outline."""
    H, W = a.shape[:2]
    x0, y0, x1, y1 = box
    x0, y0, x1, y1 = max(0, x0 - pad), max(0, y0 - pad), min(W, x1 + pad), min(H, y1 + pad)
    c = a[y0:y1, x0:x1]
    bg = bg_of(c)
    d = dist(c, bg)
    sprite = nd.binary_closing(d > hi, structure=np.ones((3, 3)), iterations=seal)
    lab, n = nd.label(~sprite)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    region = np.isin(lab, list(border))
    alpha = np.ones(d.shape, np.float32)
    soft = np.clip((d - lo) / (hi - lo), 0, 1)
    alpha[region] = soft[region]
    k = np.clip(alpha, 1e-3, 1)[..., None]
    col = np.clip((c - bg * (1 - k)) / k, 0, 255)
    out = np.dstack([col, alpha * 255]).astype(np.uint8)
    return Image.fromarray(out, 'RGBA')

def trim(img, thr=8):
    bb = img.getchannel('A').point(lambda v: 255 if v > thr else 0).getbbox()
    return img.crop(bb) if bb else img

def checker(w, h, s=10):
    c = Image.new('RGBA', (w, h))
    d = ImageDraw.Draw(c)
    for y in range(0, h, s):
        for x in range(0, w, s):
            d.rectangle((x, y, x + s, y + s), fill=(190, 190, 190, 255) if (x // s + y // s) % 2 else (120, 140, 120, 255))
    return c

def sheet_of(frames, labels=None, cell=(150, 190), cols=12, scale=1.0):
    """Contact sheet of RGBA frames with labels."""
    rows = (len(frames) + cols - 1) // cols
    W, H = cell
    out = checker(W * cols, H * rows)
    d = ImageDraw.Draw(out)
    for i, f in enumerate(frames):
        if f is None:
            continue
        g = f
        s = min(scale, (W - 6) / g.width, (H - 18) / g.height)
        if s != 1:
            g = g.resize((max(1, int(g.width * s)), max(1, int(g.height * s))), Image.LANCZOS)
        x, y = (i % cols) * W, (i // cols) * H
        out.alpha_composite(g, (x + (W - g.width) // 2, y + H - g.height - 2))
        d.text((x + 3, y + 2), str(labels[i] if labels else i), fill=(255, 255, 0, 255))
    return out
