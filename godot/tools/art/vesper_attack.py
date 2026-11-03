"""Vesper's four-direction attack, from the owner's sheet (see attack_sheet.py).

  art_src/characters/vesper_attack_sheet.png   four rows (DOWN, UP, LEFT, RIGHT), four frames in each

Built on her own canvas and feet (her sheet from eight_dir.py), at the pixel size of her idle, so she is the same size when she
swings. Part of the rebuild: run it after eight_dir.py:

  python3 godot/tools/art/eight_dir.py && python3 godot/tools/art/vesper_attack.py
"""
import attack_sheet

CONFIG = {
    'key': 'vesper',
    'src': 'art_src/characters/vesper_attack_sheet.png',
    'size': (1774, 887),
    'canvas': (141, 75),   # meta.json size
    'feet': (67, 71),      # meta.json anchor (67, 72), y minus 1
    'figure_px': 62.0,     # fallback for her figure's height (the real one is measured from her built idle)
    'cols': [(142, 552), (562, 967), (977, 1388), (1397, 1767)],
    'rows': {'s': (70, 262), 'n': (272, 464), 'w': (475, 655), 'e': (665, 859)},  # DOWN, UP, LEFT, RIGHT
    'fps': 10,
    'strike': 2,  # the slash frame
}

if __name__ == '__main__':
    attack_sheet.build(CONFIG)
