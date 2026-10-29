"""The Red Wolf's idle and walk animations, from the owner's four-direction sheet (see idle_walk_sheet.py).

  art_src/characters/redwolf_idle_walk_sheet.png   top row IDLE, bottom row WALK; panels DOWN, RIGHT, UP, LEFT

These frames are the Red Wolf's idle and walk for the rest of the game, so this step is part of the rebuild. Run it
after eight_dir.py (which cuts his other animations from art_src/characters/redwolf_sheet.webp):

  python3 godot/tools/art/eight_dir.py && python3 godot/tools/art/redwolf_idle_walk.py
"""
import idle_walk_sheet

CONFIG = {
    'key': 'redwolf',
    'src': 'art_src/characters/redwolf_idle_walk_sheet.png',
    'size': (1774, 887),
    'canvas': (128, 73),   # meta.json size
    'feet': (61, 70),      # meta.json anchor (61, 71), y minus 1
    'figure_px': 60.0,     # his figure's height on the canvas, as on his other animations
    'panels': {'s': (6, 448), 'e': (454, 883), 'n': (889, 1324), 'w': (1331, 1767)},
    'rows': {'idle': (84, 432), 'walk': (512, 857)},
    'split': 6,            # his walking side views touch each other: separate them so tails are kept whole
    'attach': 4,           # keep loose fur tufts and claws with him
}

if __name__ == '__main__':
    idle_walk_sheet.build(CONFIG)
