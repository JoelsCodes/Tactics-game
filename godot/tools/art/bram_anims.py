"""Bram's idle, walk, run, attack, hurt and knock-out animations (sheet id `warden`), from the owner's six new sheets.

  art_src/characters/bram_idle_sheet.png     1254x1254  four rows (DOWN, RIGHT, UP, LEFT), 4 frames each
  art_src/characters/bram_walk_sheet.png     1536x1024  four rows (same order), 6 frames each
  art_src/characters/bram_run_sheet.png      1536x1024  four rows, 6 frames each
  art_src/characters/bram_attack_sheet.png   1536x1024  four rows, 6 frames each (sword thrust on frame 3; no drawn slash arc)
  art_src/characters/bram_hit_sheet.png       887x1774  four rows, 2 frames each (a wince, then the guard again)
  art_src/characters/bram_ko_sheet.png       1254x1254  four rows, 4 frames each (staggers, kneels, falls, lies still)

Replaces warden_idle_walk.py (his older idle/walk sheet, still in art_src and in git history). Part of the rebuild: run it after
eight_dir.py (which writes meta.json from scratch). Each row holds exactly its frames as separate sprites, so each one is cut whole
(thin parts such as the blade are kept: every drawn pixel within 4 px of a sprite is its own).

Size: the owner's standard (the idle figure drawn STANDARD_FIGURE tall, `idle_walk_sheet.standard_scale`). The sheets were not drawn at
one scale (the idle's figure is about 8% stockier than the other three), so each is scaled on its own: idle and walk by figure height
(`FIGURE_PX` on the canvas), run and attack by head width against the walk's, so the character does not change size when he
runs or swings. Idle, walk and run are placed by the bottom and centre of each frame; the attack by the boots of its resting frames
(0 and 5), so the lunge and the thrust move as drawn.

Output: assets/characters/warden/animations/{idle,walk,run,attack}/<kind>_<s|e|n|w>_<k>.png and meta.json's idle_*, walk_*, run_* and
attack_<dir>, hit_<dir> and ko_<dir> (the animator picks `<action>_<dir>` for an eight_dir sheet; the older one-direction `attack`, `hit` and
`ko` stay as the fallback). Hurt frames go to animations/hurt, knock-out frames to animations/death. The hurt is placed by its calm frame
(1), the knock-out by its standing frame (0), and the hurt is scaled by head width against the idle's and the knock-out by head width against the hurt's (its first frame is the same wince).

  python3 godot/tools/art/eight_dir.py && python3 godot/tools/art/bram_anims.py
"""
import json
import os

import numpy as np
from PIL import Image
from scipy import ndimage as nd

import idle_walk_sheet as iws

ROOT, META = iws.ROOT, iws.META
KEY = 'warden'            # Bram's sheet id (the vessel was called Warden)
CANVAS = (190, 97)         # meta.json size
FEET = (92, 90)            # meta.json anchor (92, 91), y minus 1
FIGURE_PX = 64.0           # his figure's height on the canvas, as on his other animations
DIRS = ['s', 'e', 'n', 'w']  # row order of every sheet: DOWN, RIGHT, UP, LEFT
SHEETS = {
    'idle':   dict(src='art_src/characters/bram_idle_sheet.png',   size=(1254, 1254), frames=4),
    'walk':   dict(src='art_src/characters/bram_walk_sheet.png',   size=(1536, 1024), frames=6),
    'run':    dict(src='art_src/characters/bram_run_sheet.png',    size=(1536, 1024), frames=6),
    'attack': dict(src='art_src/characters/bram_attack_sheet.png', size=(1536, 1024), frames=6),
    'hit':    dict(src='art_src/characters/bram_hit_sheet.png',    size=(887, 1774),  frames=2),
    'ko':     dict(src='art_src/characters/bram_ko_sheet.png',     size=(1254, 1254), frames=4),
}
FOLDER = {'hit': 'hurt', 'ko': 'death'}  # the animation folders the older single-direction frames already use
FPS = {'idle': 4, 'walk': 8, 'run': 12, 'attack': 12, 'hit': 6, 'ko': 6}
# Frames drawn in cells, placed by the boots of their resting frame(s) so the lunge, wince or fall moves as drawn:
# the attack's guard frames (0 and 5), the hurt's calm frame (1), the knock-out's standing frame (0)
CELLED = {'attack': (0, 5), 'hit': (1,), 'ko': (0,)}
STRIKE = 3                 # the attack frame that lands the blow (the sword at full reach)
GRAB = 4                   # px: drawn pixels this close to a sprite belong to it


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


def load(kind):
    cfg = SHEETS[kind]
    img = Image.open(os.path.join(ROOT, cfg['src'])).convert('RGB')
    assert img.size == cfg['size'], '%s: unexpected size %s, expected %s' % (kind, img.size, cfg['size'])
    a = np.asarray(img).astype(np.float32)
    magenta = (a[..., 0] > 150) & (a[..., 2] > 150) & (a[..., 1] < 0.5 * np.minimum(a[..., 0], a[..., 2]))
    rgb = np.asarray(iws.despill(a))
    rb = bands(nd.binary_opening(~magenta, np.ones((3, 3))))
    assert len(rb) == 4, '%s: found %d rows, expected 4 (DOWN, RIGHT, UP, LEFT)' % (kind, len(rb))
    return magenta, rgb, rb


def cut_row(magenta, rgb, y0, y1, frames):
    """[(RGBA crop, x0, y0 in sheet coords, boolean mask)] of the row's sprites, left to right."""
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
    claim = fg & (dist <= GRAB)
    out = []
    for c in comps:
        m = nd.binary_fill_holes(claim & (owner == c)) & fg
        ys, xs = np.nonzero(m)
        x0, x1, ty, by = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
        crop = Image.fromarray(rgb[y0 + ty:y0 + by, x0:x1]).convert('RGBA')
        crop.putalpha(Image.fromarray((m[ty:by, x0:x1] * 255).astype(np.uint8)))
        out.append((crop, int(x0), int(y0 + ty), m[ty:by, x0:x1]))
    return out


def head_width(crop):
    a = np.asarray(crop)[..., 3] > 0
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
    canvas.alpha_composite(img.crop((sx0, sy0, sx1, sy1)), (ox + sx0, oy + sy0))


def boots(mask):
    """(x, row) of the boots in a frame's mask: the lowest wide row (not a blade tip below it) and the mean x of its bottom band."""
    counts = mask.sum(1)
    row = int(np.nonzero(counts >= max(6, 0.15 * counts.max()))[0].max())
    band = mask[max(row - 3, 0):row + 1]
    return float(np.nonzero(band.any(0))[0].mean()), row


def build():
    cuts, loaded = {}, {k: load(k) for k in SHEETS}
    for kind, (magenta, rgb, rb) in loaded.items():
        for d, (y0, y1) in zip(DIRS, rb):
            cuts[(kind, d)] = cut_row(magenta, rgb, y0, y1, SHEETS[kind]['frames'])
    med = lambda kind, f: float(np.median([f(c[0]) for d in DIRS for c in cuts[(kind, d)]]))
    s_idle = FIGURE_PX / med('idle', lambda im: im.height)
    s_walk = FIGURE_PX / med('walk', lambda im: im.height)
    walk_head = np.median([head_width(c[0]) for c in cuts[('walk', 's')]])
    scale = {'idle': s_idle, 'walk': s_walk}
    idle_head = np.median([head_width(c[0]) for c in cuts[('idle', 's')]])
    scale['hit'] = s_idle * idle_head / head_width(cuts[('hit', 's')][1][0])  # the calm frame against the idle's head
    scale['ko'] = scale['hit'] * head_width(cuts[('hit', 's')][0][0]) / head_width(cuts[('ko', 's')][0][0])  # its first frame is the hurt's wince: the same head
    for kind in ('run', 'attack'):
        scale[kind] = s_walk * walk_head / np.median([head_width(c[0]) for c in cuts[(kind, 's')]])
    out_root = os.path.join(ROOT, 'assets', 'characters', KEY, 'animations')
    names = {}
    for (kind, d), frames in cuts.items():
        folder = FOLDER.get(kind, kind)
        os.makedirs(os.path.join(out_root, folder), exist_ok=True)
        s = scale[kind]
        if kind in CELLED:
            cell = SHEETS[kind]['size'][0] / float(len(frames))  # a frame's place in its cell is what the motion is drawn in
            rest = [(k, boots(frames[k][3])) for k in CELLED[kind]]
            rx = np.median([frames[k][1] - k * cell + b[0] for k, b in rest])
            ry = np.median([frames[k][2] + b[1] for k, b in rest])
        names[(kind, d)] = []
        for k, (crop, x0, y0, _m) in enumerate(frames):
            img = scaled(crop, s)
            canvas = Image.new('RGBA', CANVAS, (0, 0, 0, 0))
            if kind in CELLED:
                paste(canvas, img, round(FEET[0] + (x0 - k * cell - rx) * s), round(FEET[1] + (y0 - ry) * s))
            else:
                paste(canvas, img, FEET[0] - img.width // 2, FEET[1] - img.height + 1)
            fn = '%s_%s_%d.png' % (kind, d, k)
            canvas.save(os.path.join(out_root, folder, fn))
            names[(kind, d)].append('animations/%s/%s' % (folder, fn))
    # frames of an older, longer cut that are no longer used
    for kind in ('idle', 'walk', 'run'):
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
    entry = meta[KEY]
    anims = entry['anims']
    entry['scale'] = iws.standard_scale(out_root)
    for (kind, d), files in names.items():
        if kind == 'attack':
            anims['attack_' + d] = {'fps': FPS['attack'], 'loop': False, 'native': 'right', 'strike': STRIKE, 'frames': files}
        elif kind in ('hit', 'ko'):  # one-shots; the knock-out holds its last frame (the animator's DEAD state)
            anims['%s_%s' % (kind, d)] = {'fps': FPS[kind], 'loop': False, 'native': 'right', 'strike': -1, 'frames': files}
        else:
            anims['%s_%s' % (kind, d)] = {'fps': anims.get('%s_%s' % (kind, d), {}).get('fps', FPS[kind]), 'loop': True,
                                          'native': 'none', 'dir': d, 'frames': files}
    with open(META, 'w', encoding='utf-8') as f:
        f.write(json.dumps(meta, indent=indent, ensure_ascii=False) + '\n')
    print('Bram idle/walk/run/attack: %d frames from the four sheets (pixel scale idle %.4f walk %.4f run %.4f attack %.4f; meta scale %.4f)' % (
        sum(len(v) for v in names.values()), scale['idle'], scale['walk'], scale['run'], scale['attack'], entry['scale']))


if __name__ == '__main__':
    build()
