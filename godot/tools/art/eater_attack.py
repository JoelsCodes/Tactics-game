"""The Eater's (an enemy slime) four-direction attack, from the owner's sheet (see attack_sheet.py).

  art_src/characters/eater_attack_sheet.png   four rows (DOWN, UP, LEFT, RIGHT), four frames in each

Built on its own canvas and feet, at the pixel size of its idle (cut by eight_dir.py), so it is the same size when it strikes.
Run it after eight_dir.py:

  python3 godot/tools/art/eight_dir.py && python3 godot/tools/art/eater_attack.py
"""
import attack_sheet

CONFIG = {
    'key': 'eater',
    'src': 'art_src/characters/eater_attack_sheet.png',
    'size': (1536, 1024),
    'canvas': (148, 74),   # meta.json size
    'feet': (65, 66),      # meta.json anchor (65, 67), y minus 1
    'figure_px': 38.0,     # fallback for the slime's height (the real one is measured from its built idle)
    'cols': [(145, 493), (503, 855), (865, 1218), (1227, 1530)],
    'rows': {'s': (78, 309), 'n': (315, 537), 'w': (542, 757), 'e': (764, 983)},  # DOWN, UP, LEFT, RIGHT
    'fps': 10,
    'strike': 2,  # the splash frame
}

if __name__ == '__main__':
    attack_sheet.build(CONFIG)
