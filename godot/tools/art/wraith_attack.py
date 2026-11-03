"""Lunar's (sheet id `wraith`) four-direction attack, from the owner's sheet (see attack_sheet.py).

  art_src/characters/wraith_attack_sheet.png   four rows (DOWN, UP, LEFT, RIGHT), four frames in each

Built on his own canvas and feet, at the pixel size of his idle (wraith_idle_walk.py), so he is the same size when he strikes. Part of the
rebuild: run it after eight_dir.py and wraith_idle_walk.py:

  python3 godot/tools/art/eight_dir.py && python3 godot/tools/art/wraith_idle_walk.py && python3 godot/tools/art/wraith_attack.py
"""
import attack_sheet

CONFIG = {
    'key': 'wraith',
    'src': 'art_src/characters/wraith_attack_sheet.png',
    'size': (1774, 887),
    'canvas': (138, 70),   # meta.json size
    'feet': (65, 68),      # meta.json anchor (65, 69), y minus 1
    'figure_px': 50.0,     # fallback for his figure's height (the real one is measured from his built idle)
    'cols': [(138, 531), (542, 943), (954, 1356), (1367, 1768)],
    'rows': {'s': (64, 255), 'n': (266, 460), 'w': (471, 657), 'e': (668, 857)},  # DOWN, UP, LEFT, RIGHT
    'fps': 10,
    'strike': 2,  # the slash frame
}

if __name__ == '__main__':
    attack_sheet.build(CONFIG)
