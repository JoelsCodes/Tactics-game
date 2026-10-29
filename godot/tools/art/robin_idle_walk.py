"""Robin's idle and walk animations, from the owner's four-direction sheet (see idle_walk_sheet.py).

  art_src/characters/robin_idle_walk_sheet.png   top row IDLE, bottom row WALK; panels DOWN, RIGHT, UP, LEFT

These frames are Robin's idle and walk for the rest of the game, so this step is part of the rebuild. Run it after
eight_dir.py (which cuts his other animations from art_src/characters/robin_sheet.webp):

  python3 godot/tools/art/eight_dir.py && python3 godot/tools/art/robin_idle_walk.py
"""
import idle_walk_sheet

CONFIG = {
    'key': 'robin',
    'src': 'art_src/characters/robin_idle_walk_sheet.png',
    'size': (1774, 887),
    'canvas': (136, 72),   # meta.json size
    'feet': (65, 69),      # meta.json anchor (65, 70), y minus 1
    'figure_px': 61.0,     # his figure's height on the canvas, as on his other animations
    'panels': {'s': (7, 457), 'e': (464, 895), 'n': (902, 1326), 'w': (1334, 1768)},
    'rows': {'idle': (86, 444), 'walk': (522, 858)},
    'attach': 6,           # keep his thin swords with him
}

if __name__ == '__main__':
    idle_walk_sheet.build(CONFIG)
