"""The King's four-direction attack, from the owner's sheet (see attack_sheet.py).

  art_src/characters/king_attack_sheet.png   four rows (DOWN, UP, LEFT, RIGHT), four frames in each

Built on the same canvas, feet, figure height and 5% widening as his idle and walk (king_idle_walk.py), so he is the same
size in every animation. Part of the rebuild: run it after eight_dir.py and king_idle_walk.py:

  python3 godot/tools/art/eight_dir.py && python3 godot/tools/art/king_idle_walk.py && python3 godot/tools/art/king_attack.py
"""
import attack_sheet
import king_idle_walk

CONFIG = {
    'key': 'king',
    'src': 'art_src/characters/king_attack_sheet.png',
    'size': (1774, 887),
    'canvas': king_idle_walk.CANVAS,
    'feet': king_idle_walk.ANCHOR,
    'figure_px': king_idle_walk.SCALE * king_idle_walk.SHEET_FIGURE,  # 64 px
    'widen': king_idle_walk.WIDEN,
    'cols': [(3, 442), (446, 885), (889, 1329), (1333, 1771)],
    'rows': {'s': (59, 237), 'n': (296, 470), 'w': (531, 684), 'e': (736, 883)},  # DOWN, UP, LEFT, RIGHT
    'fps': 10,
    'strike': 2,  # the slash frame
}

if __name__ == '__main__':
    attack_sheet.build(CONFIG)
