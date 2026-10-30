"""Cuts the owner's prop sheets (sprites on a flat dark background) into single transparent images and writes the
prop catalogue.

  python3 godot/tools/art/props.py            cut every sheet in SHEETS, write assets/props/catalogue.json
  python3 godot/tools/art/props.py --boxes    also save art_src/props/<sheet>_boxes.png: every piece numbered on the
                                              sheet (to name new pieces in NAMES)

A piece is a group of pixels that differ from the background colour, with small gaps closed (a sword's debris, a
lantern's chain stay with it). Each piece is cut out with the background keyed from the crop's edge only (so dark
pixels inside the art stay) and saved as assets/props/<category>/<name>.png. NAMES gives each piece, by its number
in reading order (top to bottom, then left to right), a name and a category; pieces without a name are skipped.
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as nd

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT = os.path.join(ROOT, 'assets', 'props')
SHEETS = {'prop_sheet_01': 'art_src/props/prop_sheet_01.png'}
# piece number -> (name, category); numbers from `--boxes`. Pieces the auto-cut merges (glows and shadows touching
# their neighbours) are cut from hand-placed boxes in MANUAL instead.
NAMES = {'prop_sheet_01': {
    0: ('gate_demon', 'doors'), 1: ('door_vine_arch', 'doors'), 2: ('door_arched_wood', 'doors'), 3: ('door_arched_iron', 'doors'),
    4: ('door_arched_dark', 'doors'), 5: ('door_square_wood', 'doors'), 6: ('door_side_wood_a', 'doors'), 7: ('door_side_frame', 'doors'),
    8: ('door_side_wood_b', 'doors'), 9: ('door_side_stone', 'doors'),
    12: ('ruin_arches', 'ruins'), 13: ('portal_crystal', 'landmarks'), 14: ('fountain_angel', 'landmarks'), 15: ('sword_in_stone', 'landmarks'),
    16: ('shrine_gate', 'landmarks'),
    17: ('banner_red', 'banners'), 18: ('banner_blue', 'banners'), 19: ('banner_red_narrow', 'banners'),
    20: ('shield_crest', 'weapons'), 21: ('shield_kite_a', 'weapons'), 22: ('shield_kite_b', 'weapons'), 23: ('shield_round', 'weapons'),
    24: ('dagger', 'weapons'), 25: ('spear', 'weapons'), 26: ('staff_orb_blue', 'weapons'), 27: ('staff_wood', 'weapons'),
    28: ('staff_orb_purple', 'weapons'), 29: ('staff_crook', 'weapons'), 30: ('tome', 'furniture'), 31: ('quiver', 'weapons'),
    32: ('sword_long', 'weapons'), 33: ('sword_short', 'weapons'), 34: ('sword_cleaver', 'weapons'), 35: ('sword_fire', 'weapons'),
    36: ('sword_plain', 'weapons'), 37: ('sword_ice', 'weapons'), 38: ('sword_gold', 'weapons'), 39: ('sword_curved', 'weapons'),
    40: ('axe_double', 'weapons'), 41: ('axe_battle', 'weapons'),
    42: ('crate_a', 'containers'), 43: ('crate_b', 'containers'), 44: ('barrel_a', 'containers'), 45: ('barrel_open', 'containers'),
    46: ('chest_large', 'containers'), 47: ('chest_long', 'containers'), 48: ('bookshelf', 'furniture'), 49: ('throne', 'furniture'),
    50: ('rug_red_square', 'furniture'), 51: ('window_stained_glass', 'furniture'), 52: ('sacks', 'containers'), 53: ('table_small', 'furniture'),
    54: ('vase_silver', 'containers'), 55: ('vase_red', 'containers'), 56: ('chest_iron', 'containers'), 57: ('chest_gold_trim', 'containers'),
    58: ('chest_treasure_open', 'containers'), 59: ('rug_red_long', 'furniture'),
    60: ('lantern_hanging_post', 'lights'), 61: ('lantern_tall', 'lights'), 62: ('pedestal_stone', 'furniture'), 63: ('lantern_iron', 'lights'),
    64: ('lantern_brass', 'lights'), 65: ('campfire', 'lights'), 66: ('candle_stand', 'lights'), 67: ('brazier_small', 'lights'),
    68: ('lantern_large', 'lights'), 69: ('table_long_map', 'furniture'), 70: ('stool', 'furniture'), 71: ('bed', 'furniture'),
    72: ('drawers', 'furniture'), 73: ('well', 'landmarks'),
    74: ('ruin_pillar_rubble', 'ruins'), 75: ('ruin_wall_stub_a', 'ruins'), 76: ('ruin_pillar_thin', 'ruins'), 77: ('fence_iron', 'ruins'),
    78: ('ruin_pillar_a', 'ruins'), 79: ('ruin_pillar_vines', 'ruins'), 80: ('ruin_pillar_b', 'ruins'), 81: ('tree_fruit', 'plants'),
    82: ('ruin_wall_iron_fence', 'ruins'), 83: ('fence_wood_gate', 'ruins'), 84: ('ruin_wall_stub_b', 'ruins'), 85: ('ladder', 'furniture'),
    86: ('brazier_blue_flame', 'lights'), 87: ('ruin_wall_broken', 'ruins'), 88: ('dock', 'landmarks'), 90: ('boulder', 'ruins'),
    91: ('flower_red', 'plants'), 92: ('crystal_cluster', 'plants'), 93: ('flower_orange', 'plants'), 94: ('ruin_low_rubble', 'ruins'),
    95: ('tree_oak', 'plants'), 96: ('tree_pine', 'plants'), 97: ('tree_red', 'plants'), 98: ('bush_berry_a', 'plants'),
    99: ('bush_berry_b', 'plants'), 100: ('flower_yellow', 'plants'), 101: ('ruin_arch_small', 'ruins'), 103: ('signpost', 'landmarks'),
    104: ('sapling', 'plants'), 105: ('stall_green', 'landmarks'), 106: ('stall_cream', 'landmarks'), 107: ('ruin_rubble_small', 'ruins'),
}}
# hand-placed boxes (x0, y0, x1, y1) on the sheet for pieces the auto-cut merges with a neighbour
MANUAL = {'prop_sheet_01': [
    ('gate_gothic_banners', 'doors', (14, 5, 290, 218)), ('statue_angel_spear', 'landmarks', (15, 218, 205, 430)),
    ('ruin_arch_tall', 'ruins', (718, 5, 888, 218)), ('tree_great_crystal', 'plants', (683, 218, 945, 435)),
    ('stall_canopy', 'landmarks', (1398, 690, 1512, 805)), ('table_workbench', 'furniture', (1312, 795, 1418, 842)),
    ('fence_wood_post', 'ruins', (1350, 840, 1440, 950)), ('campfire_pot', 'lights', (1430, 900, 1528, 1012)),
    ('cart', 'containers', (595, 915, 718, 1012)), ('tent', 'landmarks', (718, 898, 842, 1012)),
    ('torch_post', 'lights', (842, 935, 882, 1012)),
]}
MIN_PIXELS = 150


def pieces(a, bg):
    fg = np.sqrt(((a - bg) ** 2).sum(-1)) > 28
    lab, n = nd.label(nd.binary_closing(fg, np.ones((7, 7))))
    sizes = nd.sum(fg, lab, range(1, n + 1))
    boxes = [(sl, i + 1) for i, sl in enumerate(nd.find_objects(lab)) if sizes[i] > MIN_PIXELS]
    # reading order: by row band (a row is about 60 px), then left to right
    boxes.sort(key=lambda b: (round(((b[0][0].start + b[0][0].stop) / 2) / 60), b[0][1].start))
    return lab, boxes


def cut(a, lab, sl, i, bg, pad=3):
    y0, y1 = max(sl[0].start - pad, 0), min(sl[0].stop + pad, a.shape[0])
    x0, x1 = max(sl[1].start - pad, 0), min(sl[1].stop + pad, a.shape[1])
    crop = a[y0:y1, x0:x1].astype(np.float32)
    d = np.sqrt(((crop - bg) ** 2).sum(-1))
    near = d < 40
    l2, _n = nd.label(near)
    edge = set(np.unique(np.concatenate([l2[0], l2[-1], l2[:, 0], l2[:, -1]]))) - {0}
    other = (lab[y0:y1, x0:x1] != 0) & (lab[y0:y1, x0:x1] != i)  # a neighbouring piece inside the crop
    alpha = np.where(np.isin(l2, list(edge)), np.clip((d - 12) / 28, 0, 1), 1.0) * ~other
    rgba = np.dstack([crop, alpha * 255]).astype(np.uint8)
    img = Image.fromarray(rgba, 'RGBA')
    return img.crop(img.getbbox()), (x0, y0, x1, y1)


def cut_box(a, box, bg):
    """Everything in a hand-placed box, the background keyed from the box's edge only."""
    x0, y0, x1, y1 = box
    crop = a[y0:y1, x0:x1]
    d = np.sqrt(((crop - bg) ** 2).sum(-1))
    l2, _n = nd.label(d < 40)
    edge = set(np.unique(np.concatenate([l2[0], l2[-1], l2[:, 0], l2[:, -1]]))) - {0}
    alpha = np.where(np.isin(l2, list(edge)), np.clip((d - 12) / 28, 0, 1), 1.0)
    img = Image.fromarray(np.dstack([crop, alpha * 255]).astype(np.uint8), 'RGBA')
    return img.crop(img.getbbox())


def main():
    boxes_png = '--boxes' in sys.argv
    catalogue = {}
    for sheet, src in SHEETS.items():
        im = Image.open(os.path.join(ROOT, src)).convert('RGB')
        a = np.asarray(im).astype(np.float32)
        bg = np.median(a[0:4].reshape(-1, 3), axis=0)
        lab, boxes = pieces(a, bg)
        if boxes_png:
            draw_im = im.copy()
            d = ImageDraw.Draw(draw_im)
            for k, (sl, _i) in enumerate(boxes):
                d.rectangle((sl[1].start, sl[0].start, sl[1].stop, sl[0].stop), outline=(0, 255, 255))
                d.text((sl[1].start + 2, sl[0].start + 1), str(k), fill=(255, 255, 0))
            draw_im.save(os.path.join(ROOT, 'art_src', 'props', sheet + '_boxes.png'))
        for k, (sl, i) in enumerate(boxes):
            if k not in NAMES[sheet]:
                continue
            name, cat = NAMES[sheet][k]
            img, box = cut(a, lab, sl, i, bg)
            os.makedirs(os.path.join(OUT, cat), exist_ok=True)
            img.save(os.path.join(OUT, cat, name + '.png'), optimize=True)
            catalogue[name] = {'file': '%s/%s.png' % (cat, name), 'category': cat, 'size': list(img.size),
                               'source': '%s #%d %s' % (os.path.basename(src), k, list(box))}
        for name, cat, box in MANUAL.get(sheet, []):
            img = cut_box(a, box, bg)
            os.makedirs(os.path.join(OUT, cat), exist_ok=True)
            img.save(os.path.join(OUT, cat, name + '.png'), optimize=True)
            catalogue[name] = {'file': '%s/%s.png' % (cat, name), 'category': cat, 'size': list(img.size),
                               'source': '%s box %s' % (os.path.basename(src), list(box))}
    with open(os.path.join(OUT, 'catalogue.json'), 'w') as f:
        json.dump(dict(sorted(catalogue.items(), key=lambda kv: (kv[1]['category'], kv[0]))), f, indent=1)
    print('%d props catalogued' % len(catalogue))


if __name__ == '__main__':
    main()
