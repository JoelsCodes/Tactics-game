#!/usr/bin/env python3
"""The supplementary assets of the other character sheets (Vesper, Lyra, Ashen Squire, Hollow Choir,
Lantern Wraith): effects, portraits, weapon and illustration. The sheets' colour looks are not used (the
owner removed them): this script does not cut or bake them.
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
from king_extras import key_by_edge_color, key_flood, magenta_inside  # noqa: E402

_STD = {  # the four sheets that share one bottom layout
    'portraits': [(9, 853, 141, 1008), (147, 853, 271, 1008), (278, 853, 402, 1008), (410, 853, 537, 1008), (545, 853, 679, 1008)],
}
LAYOUT = {
    'vesper': dict(_STD, weapon=(1208, 842, 1262, 1014), weapon_name='sword', illustration=(1265, 842, 1531, 1014),
                   fx=[('slashes', 'slash', 5), ('slashes', 'streak', 3), ('eruptions', 'eruption', 3), ('bursts', 'burst', 3), ('smoke', 'smoke', 3)]),
    'squire': dict(_STD, weapon=(1240, 842, 1268, 1014), weapon_name='sword', illustration=(1288, 842, 1530, 1014),
                   fx=[('slashes', 'slash', 4), ('magic_circles', 'circle', 1), ('slashes', 'streak', 3), ('eruptions', 'eruption', 3),
                       ('bursts', 'burst', 3), ('smoke', 'smoke', 3)]),
    'choir': dict(_STD, weapon=(1236, 842, 1264, 1014), weapon_name='staff', illustration=(1284, 842, 1528, 1014),
                  fx=[('slashes', 'slash', 4), ('magic_circles', 'circle', 1), ('slashes', 'streak', 3), ('eruptions', 'eruption', 3),
                      ('bursts', 'burst', 3), ('smoke', 'smoke', 3)]),
    'wraith': dict(_STD, weapon=(1208, 842, 1258, 1014), weapon_name='sword', illustration=(1262, 842, 1533, 1016),
                   fx=[('slashes', 'slash', 4), ('magic_circles', 'circle', 1), ('slashes', 'streak', 3), ('eruptions', 'eruption', 3),
                       ('bursts', 'burst', 3), ('smoke', 'smoke', 3)]),
    'mira': dict(portraits=[(10, 765, 141, 991), (147, 765, 278, 991), (285, 765, 413, 991), (419, 765, 553, 991), (560, 765, 692, 991)],
                 weapon=(1228, 738, 1292, 996), weapon_name='sword', illustration=(1304, 738, 1532, 1011),
                 fx=[('slashes', 'slash', 5), ('slashes', 'streak', 3), ('eruptions', 'eruption', 3), ('bursts', 'burst', 3), ('smoke', 'smoke', 2)]),
}
# placeholder vessels: effects and portraits only (no weapon or illustration yet)
LAYOUT.update({
    'sorc': dict(portraits=[(10, 855, 144, 1005), (150, 855, 277, 1005), (284, 855, 410, 1005), (416, 855, 551, 1005), (557, 855, 699, 1005)],
                 fx=[('slashes', 'slash', 4), ('magic_circles', 'circle', 2), ('slashes', 'streak', 2), ('eruptions', 'eruption', 3), ('bursts', 'burst', 3), ('smoke', 'smoke', 3)]),
    'warden': dict(portraits=[(9, 741, 142, 980), (148, 741, 270, 980), (277, 741, 404, 980), (411, 741, 546, 980), (553, 741, 695, 980)],
                   fx=[('slashes', 'slash', 5), ('slashes', 'streak', 3), ('eruptions', 'eruption', 3), ('bursts', 'burst', 3), ('smoke', 'smoke', 2)]),
    'shade': dict(portraits=[(9, 876, 145, 1015), (152, 876, 260, 1015), (266, 876, 365, 1015), (371, 876, 475, 1015), (481, 876, 693, 1015)],
                  fx=[('slashes', 'slash', 5), ('magic_circles', 'circle', 1), ('slashes', 'streak', 2), ('eruptions', 'eruption', 3), ('bursts', 'burst', 2), ('slashes', 'shard', 2), ('smoke', 'smoke', 2)]),
    'lancer': dict(portraits=[(13, 765, 144, 995), (150, 765, 268, 995), (274, 765, 394, 995), (400, 765, 518, 995), (525, 765, 660, 995)],
                   fx=[('slashes', 'slash', 5), ('slashes', 'streak', 3), ('eruptions', 'eruption', 3), ('bursts', 'burst', 3), ('smoke', 'smoke', 2)]),
    'blade': dict(portraits=[(6, 777, 147, 995), (153, 777, 295, 995), (302, 777, 442, 995), (448, 777, 682, 995)],
                  fx=[('slashes', 'slash', 5), ('slashes', 'streak', 3), ('eruptions', 'eruption', 4), ('bursts', 'burst', 3), ('smoke', 'smoke', 2)]),
})


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
    if 'weapon' not in L:
        return effects, portraits, leaks
    save(sheet.crop(L['illustration']).convert('RGBA'), 'artwork', 'full_portrait.png')
    save(sheet.crop(L['weapon']).convert('RGBA'), 'equipment', L['weapon_name'] + '_panel.png')
    save(key_by_edge_color(sheet.crop(L['weapon'])), 'equipment', L['weapon_name'] + '.png')
    return effects, portraits, leaks


def main(names):
    path = os.path.join(ROOT, 'assets', 'characters', 'meta.json')
    meta = json.load(open(path))
    for name in names:
        effects, portraits, leaks = build(name)
        meta[name]['effects'] = {n: {'frames': fr, 'fps': 14} for n, fr in effects.items()}
        meta[name]['portraits'] = portraits
        meta[name]['portrait'] = portraits[0]
        meta[name].pop('palettes', None)
        print(name, {n: len(v) for n, v in effects.items()}, 'magenta inside:', {k: v for k, v in leaks.items() if v})
    with open(path, 'w') as f:
        json.dump(meta, f, indent=1)


if __name__ == '__main__':
    main(sys.argv[1:] or list(LAYOUT))
