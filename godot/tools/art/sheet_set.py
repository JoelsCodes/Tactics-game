"""Cuts a character's idle, walk, run, attack, hurt and knock-out animations from the owner's separate four-direction sheets.

Used by bram_anims.py and lyra_anims.py (each is a config). Every sheet has four rows (DOWN, RIGHT, UP, LEFT) with one animation's
frames in a row, each frame a separate sprite on magenta. The rows and sprites are found by the drawing, so any sheet size works; each
sprite is cut whole (thin parts such as a blade are kept: every drawn pixel within GRAB px of a sprite is its own).

config keys:
  key          the character's sheet id (meta.json key and folder under assets/characters)
  label        a name for the log line
  canvas       the character's shared frame size (meta.json size)
  feet         where the feet go on the canvas (meta.json anchor, y minus 1)
  figure_px    the idle figure's height on the canvas, as on the character's other animations
  sheets       {kind: {'src': path under godot/, 'size': (w, h), 'frames': n}} for the kinds idle, walk, run, attack, cast, hit, ko. A transparent
               sheet in Alaric's layout adds 'grid': {'rows': n, 'pick': [rows for DOWN, RIGHT, UP, LEFT]} (see cut_grid)
  norm         {kind: rule}: how each sheet is scaled (the sheets are not drawn at one scale). A rule is
                 ('height', frames)            the median height of those frames (None: all) is figure_px
                 ('head', ref, frames, ref_frames)   the head's width (top 20% of the sprite, DOWN row) against the reference kind's
                 ('same', ref)                 the reference kind's scale
                 ('match', ref, frames, ref_frames)   the figure height of those frames equals the reference's (a sheet at another scale)
  fps          {kind: frames per second}
  strike       the attack frame that lands the blow; cast_strike: the cast's release frame
  set_fps      optional: kinds whose fps always comes from `fps` (the others keep the one already in meta.json)
  celled       {kind: frames that rest}: kinds drawn in cells, placed by the boots of those frames (so the lunge, wince or fall moves as
               drawn); the others are placed by each frame's bottom and centre
  area_norm    optional: kinds whose frames are scaled by their figure's area against the resting frames' (a knock-out sheet that draws her smaller as
               she falls); area_max caps the enlargement (default 1.6)
  grounded     optional: celled kinds whose every frame is snapped to the feet row (a knock-out the sheet draws floating above it)
  soft         optional: kinds whose soft edges (a translucent slash arc) are kept by unmixing the magenta, as attack_sheet.py does
  slash_in_frames  optional, True: the arc is drawn in the attack frames, so the game adds no slash of its own
  folder       optional {kind: folder under animations}: hit goes to hurt and ko to death by default

Output: assets/characters/<key>/animations/<folder>/<kind>_<s|e|n|w>_<k>.png and meta.json's idle_*, walk_*, run_*, attack_<dir>,
hit_<dir> and ko_<dir> (the animator picks `<action>_<dir>` for an eight_dir sheet; the older one-direction `attack`, `hit` and `ko` stay
as the fallback). Run it after eight_dir.py (which writes meta.json from scratch).
"""
import json
import os

import numpy as np
from PIL import Image
from scipy import ndimage as nd

import alaric_v2   # row_cells: cuts a row of packed cells, giving a hair tip or cape that crosses a border back to its own frame
import attack_sheet
import idle_walk_sheet as iws

ROOT, META = iws.ROOT, iws.META
DIRS = ['s', 'e', 'n', 'w']  # row order of every sheet: DOWN, RIGHT, UP, LEFT
GRAB = 4                     # px: drawn pixels this close to a sprite belong to it
SOFT_GRAB = 7                # px: the faint edge of an arc this close to a sprite is its own
FOLDER = {'hit': 'hurt', 'ko': 'death'}


def bands(fg):
    rows = fg.sum(1) > 0
    out, start = [], None
    for y, v in enumerate(rows):
        if v and start is None:
            start = y
        if not v and start is not None:
            if y - start > 30:
                out.append((start, y))
            start = None
    if start is not None:
        out.append((start, len(rows)))
    return out


def load(cfg, kind):
    sc = cfg['sheets'][kind]
    img = Image.open(os.path.join(ROOT, sc['src'])).convert('RGB')
    assert img.size == tuple(sc['size']), '%s: unexpected size %s, expected %s' % (kind, img.size, sc['size'])
    a = np.asarray(img).astype(np.float32)
    magenta = (a[..., 0] > 150) & (a[..., 2] > 150) & (a[..., 1] < 0.5 * np.minimum(a[..., 0], a[..., 2]))
    rgb = np.asarray(iws.despill(a))
    rb = bands(nd.binary_opening(~magenta, np.ones((3, 3))))
    assert len(rb) == 4, '%s: found %d rows, expected 4 (DOWN, RIGHT, UP, LEFT)' % (kind, len(rb))
    return magenta, rgb, rb, a


def cut_row(magenta, rgb, a, y0, y1, frames, soft):
    """[(RGBA crop, x0, y0 in sheet coords, boolean solid mask)] of the row's sprites, left to right."""
    fg = ~magenta[y0:y1]
    core = nd.binary_opening(fg, np.ones((3, 3)))
    lab, n = nd.label(core)
    sizes = nd.sum(core, lab, range(1, n + 1))
    comps = [i + 1 for i, s in enumerate(sizes) if s > 600]
    assert len(comps) == frames, 'row has %d sprites, expected %d' % (len(comps), frames)
    comps.sort(key=lambda i: np.nonzero(lab == i)[1].min())
    seeds = np.where(np.isin(lab, comps), lab, 0)
    dist, (iy, ix) = nd.distance_transform_edt(seeds == 0, return_indices=True)
    owner = seeds[iy, ix]
    if soft:
        bg = np.median(a[y0:y1][magenta[y0:y1]], axis=0)  # the sheet's own magenta, to unmix the arc's glow from
        keep = attack_sheet.BG.copy()
        attack_sheet.BG[:] = bg
        rgba = attack_sheet.cut_cell(a[y0:y1], despill=True)
        attack_sheet.BG[:] = keep
        alpha = rgba[..., 3] / 255.0
    claim = fg & (dist <= GRAB)
    out = []
    for c in comps:
        if soft:
            region = (owner == c) & (dist <= SOFT_GRAB) & (alpha > 0.04)
            al = np.where(region, alpha, 0.0)
            ys, xs = np.nonzero(al > 0.04)
            x0, x1, ty, by = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
            crop = Image.fromarray(np.clip(rgba[y0 * 0 + ty:by, x0:x1, :3], 0, 255).astype(np.uint8)).convert('RGBA')
            crop.putalpha(Image.fromarray(np.clip(al[ty:by, x0:x1] * 255, 0, 255).astype(np.uint8)))
            out.append((crop, int(x0), int(y0 + ty), al[ty:by, x0:x1] > 0.5))
            continue
        m = nd.binary_fill_holes(claim & (owner == c)) & fg
        ys, xs = np.nonzero(m)
        x0, x1, ty, by = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
        crop = Image.fromarray(rgb[y0 + ty:y0 + by, x0:x1]).convert('RGBA')
        crop.putalpha(Image.fromarray((m[ty:by, x0:x1] * 255).astype(np.uint8)))
        out.append((crop, int(x0), int(y0 + ty), m[ty:by, x0:x1]))
    return out


def cut_grid(cfg, kind):
    """A transparent sheet in Alaric's layout (idle, cast, hurt, knock-out: 1254x1254, 8 frames a row): `grid` is {'rows': rows in the sheet,
    'pick': [the rows for DOWN, RIGHT, UP, LEFT]} (the cast sheet has all eight directions in 8 rows: pick 0, 2, 4, 6). Only the solid figure
    stays (alpha 128 and up: the sheets carry a halo of nearly transparent red noise), and alaric_v2.row_cells cuts each row cell by cell.
    Returns the same {(dir): [(crop, x0, y0, solid mask)]} as cut_row, in sheet coordinates."""
    sc = cfg['sheets'][kind]
    sheet = Image.open(os.path.join(ROOT, sc['src'])).convert('RGBA')
    assert sheet.size == tuple(sc['size']), '%s: unexpected size %s, expected %s' % (kind, sheet.size, sc['size'])
    arr = np.array(sheet)
    solid = arr[..., 3] >= 128
    arr[..., 3] = np.where(solid, 255, 0)
    arr[~solid] = 0
    sheet = Image.fromarray(arr, 'RGBA')
    n, g = sc['frames'], sc['grid']
    cw, ch = sheet.width / float(n), sheet.height / float(g['rows'])
    out = {}
    for d, row in zip(DIRS, g['pick']):
        res = []
        for k, fr in enumerate(alaric_v2.row_cells(sheet, row, n, cw, ch)):
            m = np.asarray(fr)[..., 3] > 127
            ys, xs = np.nonzero(m)
            bx0, bx1, by0, by1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
            res.append((fr.crop((bx0, by0, bx1, by1)), int(round(k * cw) - alaric_v2.PAD + bx0), int(round(row * ch) + by0), m[by0:by1, bx0:bx1]))
        out[d] = res
    return out


def head_width(crop):
    a = np.asarray(crop)[..., 3] > 127
    rows = np.nonzero(a.any(1))[0]
    top, h = rows[0], rows[-1] - rows[0] + 1
    cols = np.nonzero(a[top:top + int(0.2 * h)].any(0))[0]
    return cols[-1] - cols[0] + 1


def scaled(crop, s):
    w, h = max(1, round(crop.width * s)), max(1, round(crop.height * s))
    return crop.convert('RGBa').resize((w, h), Image.LANCZOS).convert('RGBA')


def paste(canvas, img, ox, oy):
    cw, ch = canvas.size
    sx0, sy0 = max(-ox, 0), max(-oy, 0)
    sx1, sy1 = min(img.width, cw - ox), min(img.height, ch - oy)
    if sx1 > sx0 and sy1 > sy0:
        canvas.alpha_composite(img.crop((sx0, sy0, sx1, sy1)), (ox + sx0, oy + sy0))


def boots(mask):
    """(x, row) of the boots in a frame's mask: the lowest wide row (not a blade tip below it) and the mean x of its bottom band."""
    counts = mask.sum(1)
    row = int(np.nonzero(counts >= max(6, 0.15 * counts.max()))[0].max())
    band = mask[max(row - 3, 0):row + 1]
    return float(np.nonzero(band.any(0))[0].mean()), row


def scales(cfg, cuts):
    fig = cfg['figure_px']
    sc = {}
    pick = lambda kind, d, fr: [c for k, c in enumerate(cuts[(kind, d)]) if fr is None or k in fr]
    for kind in cfg['sheets']:  # rules may refer to an earlier kind: resolve in dependency order
        pass
    pending = dict(cfg['norm'])
    while pending:
        for kind, rule in list(pending.items()):
            ref = rule[1] if rule[0] in ('head', 'same', 'match') else None
            if ref is not None and ref not in sc:
                continue
            if rule[0] == 'height':
                hs = [c[0].height for d in DIRS for c in pick(kind, d, rule[1])]
                sc[kind] = fig / float(np.median(hs))
            elif rule[0] == 'head':
                _t, ref, frames, ref_frames = rule
                mine = np.median([head_width(c[0]) for c in pick(kind, 's', frames)])
                theirs = np.median([head_width(c[0]) for c in pick(ref, 's', ref_frames)])
                sc[kind] = sc[ref] * theirs / mine
            elif rule[0] == 'same':
                sc[kind] = sc[ref]
            elif rule[0] == 'match':   # the same figure height as the reference's frames (a sheet drawn at another scale)
                _t, ref, frames, ref_frames = rule
                mine = np.median([c[0].height for d in DIRS for c in pick(kind, d, frames)])
                theirs = np.median([c[0].height for d in DIRS for c in pick(ref, d, ref_frames)])
                sc[kind] = sc[ref] * theirs / mine
            del pending[kind]
    return sc


def build(cfg):
    key, canvas_size, feet = cfg['key'], tuple(cfg['canvas']), tuple(cfg['feet'])
    soft_kinds, celled = set(cfg.get('soft', ())), cfg['celled']
    folder_of = dict(FOLDER, **cfg.get('folder', {}))
    cuts = {}
    for kind in cfg['sheets']:
        if 'grid' in cfg['sheets'][kind]:
            for d, res in cut_grid(cfg, kind).items():
                cuts[(kind, d)] = res
            continue
        magenta, rgb, rb, a = load(cfg, kind)
        for d, (y0, y1) in zip(DIRS, rb):
            cuts[(kind, d)] = cut_row(magenta, rgb, a, y0, y1, cfg['sheets'][kind]['frames'], kind in soft_kinds)
    scale = scales(cfg, cuts)
    out_root = os.path.join(ROOT, 'assets', 'characters', key, 'animations')
    names, clipped = {}, []
    for (kind, d), frames in cuts.items():
        folder = folder_of.get(kind, kind)
        os.makedirs(os.path.join(out_root, folder), exist_ok=True)
        s = scale[kind]
        if kind in celled:
            cell = cfg['sheets'][kind]['size'][0] / float(len(frames))  # a frame's place in its cell is what the motion is drawn in
            rest = [(k, boots(frames[k][3])) for k in celled[kind]]
            rx = np.median([frames[k][1] - k * cell + b[0] for k, b in rest])
            ry = np.median([frames[k][2] + b[1] for k, b in rest])
        names[(kind, d)] = []
        if kind in cfg.get('area_norm', ()):  # the figure's own area at each frame, against the resting frames'
            area_ref = np.median([frames[k][3].sum() for k in celled[kind]])
        for k, (crop, x0, y0, _m) in enumerate(frames):
            img = scaled(crop, s)
            canvas = Image.new('RGBA', canvas_size, (0, 0, 0, 0))
            if kind in celled:
                ox, oy = round(feet[0] + (x0 - k * cell - rx) * s), round(feet[1] + (y0 - ry) * s)
                if kind in cfg.get('area_norm', ()):
                    # a sheet that squeezes falling and lying poses into small cells draws her smaller as she falls: each frame is scaled by
                    # its figure's area against the standing frame's (a pose's area is about the same whichever way the body lies), about the
                    # centre where the sheet put it, so she does not shrink on the floor
                    fix = min(cfg.get('area_max', 1.6), float(np.sqrt(area_ref / float(max(1, _m.sum())))))
                    cx = ox + img.width / 2.0
                    img = scaled(crop, s * fix)
                    ox = int(round(cx - img.width / 2.0))
                if kind in cfg.get('grounded', ()):
                    oy = feet[1] - img.height + 1  # lying or kneeling frames sit on the ground row, wherever the sheet drew them
            else:
                ox, oy = feet[0] - img.width // 2, feet[1] - img.height + 1
            paste(canvas, img, ox, oy)
            if ox < 0 or oy < 0 or ox + img.width > canvas_size[0] or oy + img.height > canvas_size[1]:
                clipped.append('%s_%s_%d' % (kind, d, k))
            fn = '%s_%s_%d.png' % (kind, d, k)
            canvas.save(os.path.join(out_root, folder, fn))
            names[(kind, d)].append('animations/%s/%s' % (folder, fn))
    for kind in ('idle', 'walk', 'run'):  # frames of an older, longer cut that are no longer used
        for d in DIRS:
            k = len(names[(kind, d)])
            while True:
                stale = os.path.join(out_root, kind, '%s_%s_%d.png' % (kind, d, k))
                if not os.path.exists(stale):
                    break
                os.remove(stale)
                if os.path.exists(stale + '.import'):
                    os.remove(stale + '.import')
                k += 1
    text = open(META, encoding='utf-8').read()
    meta = json.loads(text)
    indent = 1 if '\n "' in text else 2
    entry = meta[key]
    anims = entry['anims']
    entry['scale'] = iws.standard_scale(out_root)
    if 'slash_in_frames' in cfg:  # True: the arc is drawn in the attack frames, so the game adds no slash effect of its own
        entry['slash_in_frames'] = bool(cfg['slash_in_frames'])
    fps = cfg['fps']
    for (kind, d), files in names.items():
        name = '%s_%s' % (kind, d)
        if kind == 'attack':
            anims[name] = {'fps': fps['attack'], 'loop': False, 'native': 'right', 'strike': cfg['strike'], 'frames': files}
        elif kind == 'cast':  # the spell leaves her hand on the release frame; the game adds the circle and the burst
            anims[name] = {'fps': fps['cast'], 'loop': False, 'native': 'right', 'strike': cfg['cast_strike'], 'frames': files}
        elif kind in ('hit', 'ko'):  # one-shots; the knock-out holds its last frame (the animator's DEAD state)
            anims[name] = {'fps': fps[kind], 'loop': False, 'native': 'right', 'strike': -1, 'frames': files}
        else:
            anims[name] = {'fps': fps[kind] if kind in cfg.get('set_fps', ()) else anims.get(name, {}).get('fps', fps[kind]), 'loop': True, 'native': 'none', 'dir': d, 'frames': files}
    with open(META, 'w', encoding='utf-8') as f:
        f.write(json.dumps(meta, indent=indent, ensure_ascii=False) + '\n')
    print('%s: %d frames from the sheets (pixel scale %s; meta scale %.4f)%s' % (
        cfg.get('label', key), sum(len(v) for v in names.values()), {k: round(float(v), 4) for k, v in scale.items()}, entry['scale'],
        '; clipped by the canvas: %s' % ', '.join(clipped) if clipped else ''))
