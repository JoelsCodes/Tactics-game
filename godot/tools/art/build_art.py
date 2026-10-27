#!/usr/bin/env python3
"""Builds the game's art from the source sheets in godot/art_src/.

  python3 godot/tools/art/build_art.py      (needs Pillow and numpy)

Characters: cuts the six poses out of each sheet, removes the flat background
(soft edges for glows), scales them to one height, pads every pose to the same
canvas with the feet at the same anchor (so poses swap without jumping), and
crops a portrait. Writes assets/characters/<name>/<pose>.png and meta.json.

Terrain: unwarps the isometric faces of the tile sheet into flat textures
(top faces become squares, side faces become strips) and derives the other
terrains by recoloring. Also draws the few extras the sheets lack: a tree,
bridge planks, effect sprites and the UI window frames.
"""
import json
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), '..', '..'))
SRC = os.path.join(ROOT, 'art_src')
OUT = os.path.join(ROOT, 'assets')
POSES = ['idle', 'ready', 'attack', 'idle2', 'cast', 'victory']

# (sheet, rows [(y0, y1)], cells per row [(x0, x1)] in POSES order). Crops leave out the labels.
CHARACTERS = {
    'hero': ('hero_sheet.jpg', [(0, 349), (378, 733)],
             [[(0, 386), (386, 742), (742, 1168)], [(0, 336), (336, 752), (752, 1168)]]),
    'cardmage': ('cardmage_sheet.jpg', [(0, 672), (730, 1362)],
                 [[(0, 700), (700, 1560), (1560, 2576)], [(0, 640), (640, 1500), (1500, 2075)]]),
    'demon': ('demon_sheet.jpg', [(0, 672), (730, 1362)],
              [[(0, 700), (700, 1560), (1560, 2576)], [(0, 640), (640, 1525), (1470, 1985)]]),
}
BODY_H = 136  # idle pose height in output pixels (the game draws sprites at 0.5 scale)


def save(img, *parts):
    path = os.path.join(OUT, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, optimize=True)
    return path


# ---------- background removal ----------
def flood(mask_ok):
    """Pixels reachable from the border through mask_ok (4-connected)."""
    h, w = mask_ok.shape
    seen = np.zeros_like(mask_ok)
    stack = [(y, x) for x in range(w) for y in (0, h - 1) if mask_ok[y, x]]
    stack += [(y, x) for y in range(h) for x in (0, w - 1) if mask_ok[y, x]]
    for y, x in stack:
        seen[y, x] = True
    while stack:
        y, x = stack.pop()
        for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
            if 0 <= ny < h and 0 <= nx < w and mask_ok[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True
                stack.append((ny, nx))
    return seen


def matte(rgb, lo, hi):
    """RGBA from a crop on a flat background. Pixels joined to the border and
    close to the background color fade out; everything else stays opaque."""
    a = rgb.astype(np.float32)
    border = np.concatenate([a[:3].reshape(-1, 3), a[-3:].reshape(-1, 3), a[:, :3].reshape(-1, 3), a[:, -3:].reshape(-1, 3)])
    bg = np.median(border, axis=0)
    d = np.sqrt(((a - bg) ** 2).sum(-1))
    region = flood(d < hi)
    alpha = np.ones(d.shape, np.float32)
    soft = np.clip((d - lo) / (hi - lo), 0, 1)
    alpha[region] = soft[region]
    # un-mix the background from semi-transparent pixels (glows, motion trails)
    k = np.clip(alpha, 1e-3, 1)[..., None]
    col = np.clip((a - bg * (1 - k)) / k, 0, 255)
    out = np.dstack([col, alpha * 255]).astype(np.uint8)
    return Image.fromarray(out, 'RGBA'), bg


def drop_specks(img, min_area=40):
    """Removes tiny isolated blobs (JPEG noise) but keeps confetti-sized bits."""
    a = np.asarray(img).copy()
    solid = a[..., 3] > 100
    h, w = solid.shape
    label = np.zeros(solid.shape, np.int32)
    n = 0
    for y in range(h):
        for x in range(w):
            if solid[y, x] and not label[y, x]:
                n += 1
                stack = [(y, x)]
                label[y, x] = n
                pts = []
                while stack:
                    cy, cx = stack.pop()
                    pts.append((cy, cx))
                    for ny, nx in ((cy + 1, cx), (cy - 1, cx), (cy, cx + 1), (cy, cx - 1)):
                        if 0 <= ny < h and 0 <= nx < w and solid[ny, nx] and not label[ny, nx]:
                            label[ny, nx] = n
                            stack.append((ny, nx))
                if len(pts) < min_area:
                    ys, xs = zip(*pts)
                    ys, xs = np.array(ys), np.array(xs)
                    for dy in (-1, 0, 1):
                        for dx in (-1, 0, 1):
                            yy, xx = np.clip(ys + dy, 0, h - 1), np.clip(xs + dx, 0, w - 1)
                            a[yy, xx, 3] = 0
    return Image.fromarray(a, 'RGBA')


def resize_rgba(img, size):
    return img.convert('RGBa').resize(size, Image.LANCZOS).convert('RGBA')


def feet_anchor(img):
    """(x, y) of the feet: bottom of the opaque pixels, x from the lowest rows."""
    a = np.asarray(img)[..., 3] > 128
    ys, xs = np.nonzero(a)
    y1 = ys.max()
    y0 = ys.min()
    band = ys > y1 - max(4, (y1 - y0) * .05)
    return float(xs[band].mean()), float(y1)


def build_characters():
    meta = {}
    for name, (sheet, rows, cells) in CHARACTERS.items():
        src = np.asarray(Image.open(os.path.join(SRC, sheet)).convert('RGB'))
        dark = src[:4].mean() < 60
        lo, hi = (9, 30) if dark else (10, 34)
        poses = {}
        i = 0
        for (y0, y1), row in zip(rows, cells):
            for (x0, x1) in row:
                img, _ = matte(src[y0:y1, x0:x1], lo, hi)
                img = drop_specks(img)
                bb = img.getbbox()
                poses[POSES[i]] = img.crop(bb)
                i += 1
        # scale so the idle pose is BODY_H tall
        s = BODY_H / poses['idle'].height
        anchors = {}
        for k, img in poses.items():
            img = resize_rgba(img, (max(1, round(img.width * s)), max(1, round(img.height * s))))
            poses[k] = img
            anchors[k] = feet_anchor(img)
        left = max(anchors[k][0] for k in poses)
        right = max(poses[k].width - anchors[k][0] for k in poses)
        up = max(anchors[k][1] for k in poses)
        down = max(poses[k].height - anchors[k][1] for k in poses)
        half = math.ceil(max(left, right)) + 2
        W, H = half * 2, math.ceil(up + down) + 4
        ax, ay = half, math.ceil(up) + 2
        for k, img in poses.items():
            canvas = Image.new('RGBA', (W, H), (0, 0, 0, 0))
            canvas.alpha_composite(img, (round(ax - anchors[k][0]), round(ay - anchors[k][1])))
            save(canvas, 'characters', name, k + '.png')
        # portrait: the head of the idle pose, from the full-resolution cut
        full = Image.open(os.path.join(SRC, sheet)).convert('RGB')
        (y0, y1), (x0, x1) = rows[0], cells[0][0]
        img, _ = matte(np.asarray(full)[y0:y1, x0:x1], lo, hi)
        img = drop_specks(img)
        img = img.crop(img.getbbox())
        a = np.asarray(img)[..., 3] > 128
        h = img.height
        top = int(np.nonzero(a.any(1))[0].min())
        head_rows = a[top + int(h * .04): top + int(h * .30)]
        ys, xs = np.nonzero(head_rows)
        cx = float(np.median(xs))
        side = int(h * .40)
        cy = top + int(h * .04) + side * .5
        box = (int(cx - side / 2), int(cy - side / 2), int(cx + side / 2), int(cy + side / 2))
        port = Image.new('RGBA', (side, side), (0, 0, 0, 0))
        port.alpha_composite(img.crop(box))
        save(resize_rgba(port, (96, 96)), 'characters', name, 'portrait.png')
        meta[name] = {'size': [W, H], 'anchor': [ax, ay], 'poses': POSES}
        print(f'{name}: {W}x{H}, feet at {ax},{ay}')
    with open(os.path.join(OUT, 'characters', 'meta.json'), 'w') as f:
        json.dump(meta, f, indent=1)


# ---------- terrain ----------
def recolor(img, hue=None, sat=1.0, val=1.0, tint=None, tint_k=0.0):
    hsv = np.asarray(img.convert('RGB').convert('HSV')).astype(np.float32)
    if hue is not None:
        hsv[..., 0] = (hsv[..., 0] + hue * 255) % 256
    hsv[..., 1] = np.clip(hsv[..., 1] * sat, 0, 255)
    hsv[..., 2] = np.clip(hsv[..., 2] * val, 0, 255)
    out = Image.fromarray(hsv.astype(np.uint8), 'HSV').convert('RGB')
    if tint is not None:
        out = Image.blend(out, Image.new('RGB', out.size, tint), tint_k)
    return out


def build_terrain():
    im = Image.open(os.path.join(SRC, 'terrain_sheet.jpg')).convert('RGB')

    def unwarp(top, left, bottom, right, size):
        return im.transform(size, Image.QUAD, data=(*top, *left, *bottom, *right), resample=Image.BICUBIC)

    def strip(ul, ll, lr, ur, size):
        return im.transform(size, Image.QUAD, data=(*ul, *ll, *lr, *ur), resample=Image.BICUBIC)

    # Plain grass chunk: top face is a 4x4 grid of tiles.
    grass_top = unwarp((425, 202), (90, 387), (428, 572), (766, 387), (512, 512))
    cuts = [(4, 116), (126, 246), (256, 378), (388, 508)]
    grass = []
    for gy in range(4):
        for gx in range(4):
            c = grass_top.crop((cuts[gx][0], cuts[gy][0], cuts[gx][1], cuts[gy][1])).resize((96, 96), Image.LANCZOS)
            grass.append(c)
    variants = {
        'grass': lambda c: c,
        'swamp': lambda c: recolor(c, hue=.06, sat=.75, val=.62, tint=(40, 70, 60), tint_k=.25),
        'dirt': lambda c: recolor(c, hue=-.12, sat=.85, val=.82, tint=(140, 100, 60), tint_k=.35),
        'sand': lambda c: recolor(c, hue=-.06, sat=.45, val=1.12, tint=(222, 200, 140), tint_k=.45),
    }
    for kind, fn in variants.items():
        for i, c in enumerate(grass):
            save(fn(c), 'tiles', f'{kind}_{i:02d}.png')
    # Cobbles from the flowery chunk.
    flower_top = unwarp((1287, 925), (965, 1065), (1295, 1222), (1635, 1065), (512, 512))
    cob = [flower_top.crop((x, y, x + 150, y + 150)).resize((96, 96), Image.LANCZOS) for x, y in [(300, 330), (330, 300), (340, 362), (290, 350)]]
    variants = {
        'stone': lambda c: recolor(c, sat=.55, val=1.0),
        'crag': lambda c: recolor(c, hue=.02, sat=.8, val=.85, tint=(120, 100, 80), tint_k=.25),
        'cinder': lambda c: recolor(c, sat=.4, val=.55, tint=(70, 45, 40), tint_k=.3),
    }
    for kind, fn in variants.items():
        for i, c in enumerate(cob):
            save(fn(c), 'tiles', f'{kind}_{i:02d}.png')
    # Side faces of the plain chunk (left face is in shade, right face lit), 4 tiles wide.
    left = strip((96, 390), (96, 545), (428, 727), (428, 572), (384, 176))
    right = strip((428, 572), (428, 727), (760, 545), (760, 390), (384, 176))
    save(left, 'tiles', 'side_grass_l.png')
    save(right, 'tiles', 'side_grass_r.png')
    # Stone wall: right face of the stone pillar (right chunk).
    wall = strip((2312, 520), (2312, 700), (2494, 610), (2494, 430), (192, 176))
    stone_r = Image.new('RGB', (384, 176))
    stone_r.paste(wall, (0, 0))
    stone_r.paste(wall.transpose(Image.FLIP_LEFT_RIGHT), (192, 0))
    save(stone_r, 'tiles', 'side_stone_r.png')
    save(recolor(stone_r, val=.72), 'tiles', 'side_stone_l.png')
    save(recolor(stone_r, sat=.5, val=.5, tint=(60, 40, 35), tint_k=.25), 'tiles', 'side_cinder_r.png')
    save(recolor(stone_r, sat=.5, val=.38, tint=(60, 40, 35), tint_k=.25), 'tiles', 'side_cinder_l.png')
    save(recolor(stone_r, hue=.02, sat=.9, val=.85, tint=(120, 100, 80), tint_k=.2), 'tiles', 'side_crag_r.png')
    save(recolor(stone_r, hue=.02, sat=.9, val=.62, tint=(120, 100, 80), tint_k=.2), 'tiles', 'side_crag_l.png')
    print('terrain: grass/swamp/dirt/sand x16, stone/crag/cinder x4, side strips')


# ---------- generated extras ----------
def build_extras():
    rnd = random.Random(7)
    # Bridge planks, pixel style.
    img = Image.new('RGB', (96, 96), (120, 86, 52))
    d = ImageDraw.Draw(img)
    for i in range(6):
        y = i * 16
        base = (138 + rnd.randint(-12, 12), 98 + rnd.randint(-10, 10), 58 + rnd.randint(-8, 8))
        d.rectangle((0, y, 95, y + 14), fill=base)
        d.line((0, y + 15, 95, y + 15), fill=(52, 36, 24), width=2)
        d.line((0, y, 95, y), fill=tuple(min(255, c + 30) for c in base))
        for _ in range(5):
            x = rnd.randint(0, 90)
            d.line((x, y + 4, x + rnd.randint(6, 20), y + 4 + rnd.randint(-1, 1)), fill=tuple(c - 22 for c in base))
        for x in (6, 88):
            d.rectangle((x, y + 6, x + 2, y + 8), fill=(60, 60, 64))
    save(img, 'tiles', 'bridge.png')

    # Tree: trunk + three shaded canopy blobs, chunky pixels to match the tiles.
    S = 4
    w, h = 48, 64
    tree = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(tree)
    d.rectangle((21, 40, 26, 63), fill=(92, 62, 38, 255))
    d.rectangle((21, 40, 22, 63), fill=(70, 46, 28, 255))
    blobs = [(24, 30, 16), (15, 25, 11), (33, 24, 11), (24, 14, 12)]
    dark, mid, lite, hi = (34, 72, 38), (52, 104, 48), (86, 140, 56), (150, 186, 80)
    for cx, cy, r in blobs:
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=dark + (255,))
    for cx, cy, r in blobs:
        d.ellipse((cx - r + 1, cy - r + 1, cx + r - 3, cy + r - 3), fill=mid + (255,))
    for cx, cy, r in blobs:
        d.ellipse((cx - r + 3, cy - r + 2, cx + r * .3, cy + r * .1), fill=lite + (255,))
    for _ in range(26):
        x, y = rnd.randint(8, 40), rnd.randint(4, 36)
        if tree.getpixel((x, y))[3]:
            d.point((x, y), fill=(hi if rnd.random() < .4 else dark) + (255,))
    tree = tree.resize((w * S // 2, h * S // 2), Image.NEAREST)
    outline = tree.split()[3].filter(ImageFilter.MaxFilter(5))
    edge = Image.new('RGBA', tree.size, (20, 34, 22, 255))
    edge.putalpha(outline)
    edge.alpha_composite(tree)
    save(edge, 'props', 'tree.png')

    # Effect sprites: soft dot, ring, 4-point spark, shadow.
    def radial(size, f):
        a = np.zeros((size, size, 4), np.uint8)
        c = (size - 1) / 2
        for y in range(size):
            for x in range(size):
                r = math.hypot(x - c, y - c) / c
                a[y, x] = f(r, x - c, y - c)
        return Image.fromarray(a, 'RGBA')
    save(radial(64, lambda r, x, y: (255, 255, 255, int(255 * max(0, 1 - r) ** 2))), 'fx', 'soft_dot.png')
    save(radial(128, lambda r, x, y: (255, 255, 255, int(255 * max(0, 1 - abs(r - .82) / .14)))), 'fx', 'ring.png')
    save(radial(64, lambda r, x, y: (255, 255, 255, int(255 * min(1, max(0, 1 - r) * (max(0, 1 - min(abs(x), abs(y)) / 3.5)) * 2.2)))), 'fx', 'spark.png')
    save(radial(64, lambda r, x, y: (0, 0, 0, int(150 * max(0, 1 - r) ** 1.5))), 'fx', 'shadow.png')

    # UI window frame (9-slice): deep blue gradient, light inner bevel, gold rim.
    def window(w, h, top, bottom, rim, inner):
        img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        for y in range(h):
            t = y / (h - 1)
            col = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
            d.line((3, y, w - 4, y), fill=col + (238,))
        d.rounded_rectangle((0, 0, w - 1, h - 1), radius=6, outline=rim + (255,), width=2)
        d.rounded_rectangle((3, 3, w - 4, h - 4), radius=4, outline=inner + (255,), width=1)
        mask = Image.new('L', (w, h), 0)
        ImageDraw.Draw(mask).rounded_rectangle((0, 0, w - 1, h - 1), radius=6, fill=255)
        img.putalpha(Image.fromarray(np.minimum(np.asarray(img)[..., 3], np.asarray(mask))))
        return img
    save(window(48, 48, (38, 58, 120), (16, 24, 58), (214, 182, 104), (122, 150, 214)), 'ui', 'window.png')
    save(window(48, 48, (58, 84, 156), (30, 44, 98), (226, 200, 130), (150, 176, 232)), 'ui', 'button.png')
    save(window(48, 48, (92, 122, 200), (52, 72, 140), (255, 228, 150), (190, 210, 250)), 'ui', 'button_hover.png')
    save(window(48, 48, (180, 140, 60), (120, 86, 30), (255, 230, 160), (250, 214, 130)), 'ui', 'button_pressed.png')
    save(window(48, 48, (50, 56, 72), (30, 34, 46), (110, 110, 120), (80, 84, 100)), 'ui', 'button_disabled.png')
    # Pointing hand cursor for the active menu row.
    hand = Image.new('RGBA', (16, 12), (0, 0, 0, 0))
    hd = ImageDraw.Draw(hand)
    hd.polygon([(0, 3), (9, 3), (9, 1), (15, 6), (9, 11), (9, 9), (0, 9)], fill=(255, 246, 220, 255), outline=(40, 30, 20, 255))
    save(hand.resize((32, 24), Image.NEAREST), 'ui', 'pointer.png')
    # Title backdrop: a slice of the terrain sheet, softened and darkened toward the bottom.
    sheet = Image.open(os.path.join(SRC, 'terrain_sheet.jpg')).convert('RGB')
    bg = sheet.crop((620, 0, 1420, 1438)).resize((470, 845), Image.LANCZOS).filter(ImageFilter.GaussianBlur(1.2))
    shade = np.linspace(.85, .25, bg.height)[:, None, None]
    bg = Image.fromarray((np.asarray(bg).astype(np.float32) * shade).astype(np.uint8))
    bg.save(os.path.join(OUT, 'ui', 'title_bg.jpg'), quality=88)
    print('extras: bridge, tree, fx, ui frames, title backdrop')


if __name__ == '__main__':
    build_characters()
    build_terrain()
    build_extras()
