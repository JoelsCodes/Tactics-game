"""The Ashen Squire's idle and walk animations, from the owner's four-direction sheet (see idle_walk_sheet.py).

  art_src/characters/squire_idle_walk_sheet.png   top row IDLE, bottom row WALK; panels DOWN, RIGHT, UP, LEFT

These frames are the Squire's idle and walk for the rest of the game, so this step is part of the rebuild. Run it after
eight_dir.py:

  python3 godot/tools/art/eight_dir.py && python3 godot/tools/art/squire_idle_walk.py
"""
import idle_walk_sheet

CONFIG = {
    'key': 'squire',
    'src': 'art_src/characters/squire_idle_walk_sheet.png',
    'size': (1536, 1024),
    'canvas': (130, 73),   # meta.json size
    'feet': (57, 69),      # meta.json anchor (57, 70), y minus 1
    'figure_px': 66.0,     # his figure's height on the canvas, as on his other animations
    'panels': {'s': (5, 408), 'e': (415, 778), 'n': (784, 1151), 'w': (1157, 1531)},
    'rows': {'idle': (80, 388), 'walk': (468, 761)},
}

if __name__ == '__main__':
    idle_walk_sheet.build(CONFIG)
