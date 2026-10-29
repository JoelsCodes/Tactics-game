#!/usr/bin/env python3
"""The supplementary assets of the other character sheets (Vesper, Mira, Ashen Squire, Hollow Choir,
Lantern Wraith): effects, portraits, colour looks with recolored animation sets, weapon and illustration.
Same rules and output layout as tools/art/king_extras.py (the King's sheet keeps its own script because
its bottom section is laid out differently), driven by the LAYOUT table below.

  python3 godot/tools/art/eight_dir.py && python3 godot/tools/art/king_extras.py && python3 godot/tools/art/char_extras.py
  godot --headless --path godot --import
  godot --headless --path godot --script res://tools/build_resources.gd
"""
import json
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from eight_dir import ROOT, SHEETS, trim  # noqa: E402
from king_extras import analyse_preview, hexc, key_by_edge_color, key_flood, magenta_inside, recolor  # noqa: E402

_STD = {  # the four sheets that share one bottom layout
    'portraits': [(9, 853, 141, 1008), (147, 853, 271, 1008), (278, 853, 402, 1008), (410, 853, 537, 1008), (545, 853, 679, 1008)],
    'preview_y': (856, 926), 'swatch_y': (929, 940), 'pal_portrait_y': (950, 1009),
}
LAYOUT = {
    'vesper': dict(_STD, palette_x=(690, 1195), weapon=(1208, 842, 1262, 1014), weapon_name='sword', illustration=(1265, 842, 1531, 1014),
                   looks=['original', 'red', 'blue', 'white', 'purple', 'green', 'gold', 'crimson'],
                   fx=[('slashes', 'slash', 5), ('slashes', 'streak', 3), ('eruptions', 'eruption', 3), ('bursts', 'burst', 3), ('smoke', 'smoke', 3)]),
    'squire': dict(_STD, palette_x=(694, 1210), weapon=(1240, 842, 1268, 1014), weapon_name='sword', illustration=(1288, 842, 1530, 1014),
                   looks=['original', 'red', 'green', 'tan', 'purple', 'steel', 'ivory', 'crimson'],
                   fx=[('slashes', 'slash', 4), ('magic_circles', 'circle', 1), ('slashes', 'streak', 3), ('eruptions', 'eruption', 3),
                       ('bursts', 'burst', 3), ('smoke', 'smoke', 3)]),
    'choir': dict(_STD, palette_x=(696, 1204), weapon=(1236, 842, 1264, 1014), weapon_name='staff', illustration=(1284, 842, 1528, 1014),
                  looks=['original', 'red', 'teal', 'white', 'purple', 'olive', 'amber', 'crimson'],
                  fx=[('slashes', 'slash', 4), ('magic_circles', 'circle', 1), ('slashes', 'streak', 3), ('eruptions', 'eruption', 3),
                      ('bursts', 'burst', 3), ('smoke', 'smoke', 3)]),
    'wraith': dict(_STD, palette_x=(695, 1196), weapon=(1208, 842, 1258, 1014), weapon_name='sword', illustration=(1262, 842, 1533, 1016),
                   looks=['original', 'red', 'blue', 'brown', 'slate', 'tan', 'white', 'crimson'],
                   fx=[('slashes', 'slash', 4), ('magic_circles', 'circle', 1), ('slashes', 'streak', 3), ('eruptions', 'eruption', 3),
                       ('bursts', 'burst', 3), ('smoke', 'smoke', 3)]),
    'mira': dict(portraits=[(10, 765, 141, 991), (147, 765, 278, 991), (285, 765, 413, 991), (419, 765, 553, 991), (560, 765, 692, 991)],
                 preview_y=(765, 847), swatch_y=(850, 863), pal_portrait_y=(873, 988), palette_x=(707, 1213),
                 weapon=(1228, 738, 1292, 996), weapon_name='sword', illustration=(1304, 738, 1532, 1011),
                 looks=['original', 'red', 'blue', 'white', 'purple', 'green', 'gold', 'black'],
                 fx=[('slashes', 'slash', 5), ('slashes', 'streak', 3), ('eruptions', 'eruption', 3), ('bursts', 'burst', 3), ('smoke', 'smoke', 2)]),
}
# tone of the light (and dark) looks: below 1 lifts the shading toward the light end, above 1 darkens
GAMMA = {'white': 0.55, 'ivory': 0.5, 'gold': 0.6, 'amber': 0.7, 'tan': 0.75, 'brown': 0.85, 'green': 0.9, 'olive': 0.9, 'black': 1.5}


def build(name):
    L = LAYOUT[name]
    sheet = Image.open(os.path.join(ROOT, SHEETS[name]['src'])).convert('RGB')
    out = os.path.join(ROOT, 'assets', 'characters', name)

    def save(img, *path):
        p = os.path.join(out, *path)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        img.save(p, optimize=True)
        return '/'.join(path)

    # effects: the particle row in equal cells, keyed from each cell's edge only
    x0, y0, x1, y1 = SHEETS[name]['fx_box']
    total = sum(c for _f, _n, c in L['fx'])
    w = (x1 - x0) / total
    effects, leaks, k = {}, {}, 0
    for folder, fx, count in L['fx']:
        for i in range(count):
            cell = sheet.crop((int(x0 + k * w) + 2, y0 + 2, int(x0 + (k + 1) * w) - 2, y1 - 2))
            k += 1
            img, _ = key_flood(cell)
            img, _bb = trim(img)
            rel = save(img, 'effects', folder, '%s_%d.png' % (fx, i))
            effects.setdefault(fx, []).append(rel)
            leaks[rel] = magenta_inside(img)
    portraits = [save(sheet.crop(r).convert('RGBA'), 'portraits', 'portrait_%02d.png' % (i + 1)) for i, r in enumerate(L['portraits'])]
    save(sheet.crop(L['illustration']).convert('RGBA'), 'artwork', 'full_portrait.png')
    save(sheet.crop(L['weapon']).convert('RGBA'), 'equipment', L['weapon_name'] + '_panel.png')
    save(key_by_edge_color(sheet.crop(L['weapon'])), 'equipment', L['weapon_name'] + '.png')
    # looks
    px0, px1 = L['palette_x']
    cw = (px1 - px0) / len(L['looks'])
    info = {}
    for i, look in enumerate(L['looks']):
        cx0, cx1 = int(px0 + i * cw) + 3, int(px0 + (i + 1) * cw) - 4
        prev = sheet.crop((cx0 + 5, L['preview_y'][0] + 3, cx1 - 5, L['preview_y'][1] - 2)).convert('RGB')
        # a panel with a gradient or noise keys poorly at the default tolerance: widen it until the figure
        # is figure-sized (it never fills more than about half the cell)
        for tol in (42.0, 58.0, 74.0, 90.0, 30.0, 22.0):
            hair, outfit, fg = analyse_preview(prev, tol)
            if 0.12 < fg.mean() < 0.55:
                break
        save(Image.fromarray(np.dstack([np.asarray(prev), fg * 255]).astype(np.uint8), 'RGBA'), 'palettes', 'previews', look + '.png')
        sw = np.asarray(sheet.crop((cx0, L['swatch_y'][0], cx1, L['swatch_y'][1])).convert('RGB')).astype(float)
        q = sw.shape[1] / 4.0
        swatches = [sw[2:-2, int(j * q + q * 0.3):int(j * q + q * 0.7)].reshape(-1, 3).mean(0) for j in range(4)]
        por = save(sheet.crop((cx0, L['pal_portrait_y'][0], cx1, L['pal_portrait_y'][1])).convert('RGBA'), 'palettes', 'portraits', look + '.png')
        info[look] = {'hair': hair, 'outfit': outfit, 'portrait': por}
        doc = {'name': look, 'label': look.capitalize(), 'swatches': [hexc(c) for c in swatches],
               'hair_ramp': [hexc(c) for c in hair], 'outfit_ramp': [hexc(c) for c in outfit],
               'preview': 'palettes/previews/%s.png' % look, 'portrait': por, 'tone_gamma': GAMMA.get(look, 1.0),
               'note': 'The preview is a reference only; the in-game look is the original frames recolored (tools/art/char_extras.py).'}
        with open(os.path.join(out, 'palettes', look + '.json'), 'w') as f:
            json.dump(doc, f, indent=1)
    return effects, portraits, info, leaks


def bake(name, info, meta):
    base = info['original']
    src = os.path.join(ROOT, 'assets', 'characters', name)
    for look in LAYOUT[name]['looks'][1:]:
        key = '%s_%s' % (name, look)
        dst = os.path.join(ROOT, 'assets', 'characters', key)
        for dirpath, _dirs, files in os.walk(os.path.join(src, 'animations')):
            for fn in files:
                if fn.endswith('.png'):
                    rel = os.path.relpath(os.path.join(dirpath, fn), src)
                    p = os.path.join(dst, rel)
                    os.makedirs(os.path.dirname(p), exist_ok=True)
                    recolor(Image.open(os.path.join(dirpath, fn)).convert('RGBA'), base, info[look], GAMMA.get(look, 1.0)).save(p, optimize=True)
        Image.open(os.path.join(src, info[look]['portrait'])).convert('RGBA').save(os.path.join(dst, 'portrait.png'), optimize=True)
        entry = json.loads(json.dumps(meta[name]))
        entry.update({'palette': look, 'effects_from': name, 'portrait': 'portrait.png'})
        entry.pop('palettes', None)
        meta[key] = entry


def main(names):
    path = os.path.join(ROOT, 'assets', 'characters', 'meta.json')
    meta = json.load(open(path))
    for name in names:
        effects, portraits, info, leaks = build(name)
        meta[name]['effects'] = {n: {'frames': fr, 'fps': 14} for n, fr in effects.items()}
        meta[name]['portraits'] = portraits
        meta[name]['palettes'] = LAYOUT[name]['looks']
        bake(name, info, meta)
        print(name, {n: len(v) for n, v in effects.items()}, 'magenta inside:', {k: v for k, v in leaks.items() if v})
    with open(path, 'w') as f:
        json.dump(meta, f, indent=1)


if __name__ == '__main__':
    main(sys.argv[1:] or list(LAYOUT))
