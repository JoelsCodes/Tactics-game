"""The Sorceress's idle and walk animations, from the owner's four-direction sheet (see idle_walk_sheet.py).

  art_src/characters/sorc_idle_walk_sheet.png   top row IDLE, bottom row WALK; panels DOWN, RIGHT, UP, LEFT

These frames are the Sorceress's idle and walk for the rest of the game, so this step is part of the rebuild. Run it
after eight_dir.py:

  python3 godot/tools/art/eight_dir.py && python3 godot/tools/art/sorc_idle_walk.py
"""
import idle_walk_sheet

CONFIG = {
    'key': 'sorc',
    'src': 'art_src/characters/sorc_idle_walk_sheet.png',
    'size': (1774, 887),
    'canvas': (130, 72),   # meta.json size
    'feet': (59, 69),      # meta.json anchor (59, 70), y minus 1
    'figure_px': 63.0,     # her figure's height on the canvas, as on her other animations
    'panels': {'s': (7, 453), 'e': (461, 883), 'n': (889, 1317), 'w': (1324, 1768)},
    'rows': {'idle': (84, 437), 'walk': (513, 865)},
    'edge_key': True,      # her staff's orb is nearly the background's magenta: key from the panel edges only
    'attach': 6,           # keep the staff's thin shaft and orb with her
}

if __name__ == '__main__':
    idle_walk_sheet.build(CONFIG)
