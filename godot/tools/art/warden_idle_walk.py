"""Bram's idle and walk animations (sheet id `warden`), from the owner's four-direction sheet (see idle_walk_sheet.py).

  art_src/characters/warden_idle_walk_sheet.png   top row IDLE, bottom row WALK; panels DOWN, RIGHT, UP, LEFT

These frames are Bram's idle and walk for the rest of the game, so this step is part of the rebuild. Run it after
eight_dir.py:

  python3 godot/tools/art/eight_dir.py && python3 godot/tools/art/warden_idle_walk.py
"""
import idle_walk_sheet

CONFIG = {
    'key': 'warden',  # Bram's sheet id (the vessel was called Warden)
    'src': 'art_src/characters/warden_idle_walk_sheet.png',
    'size': (1774, 887),
    'canvas': (190, 97),   # meta.json size
    'feet': (92, 90),      # meta.json anchor (92, 91), y minus 1
    'figure_px': 64.0,     # his figure's height on the canvas, as on his other animations
    'panels': {'s': (5, 449), 'e': (455, 885), 'n': (892, 1322), 'w': (1329, 1769)},
    'rows': {'idle': (85, 443), 'walk': (522, 881)},
    'split': 6,            # in case the sprites touch (shield edges)
    'attach': 4,
}

if __name__ == '__main__':
    idle_walk_sheet.build(CONFIG)
