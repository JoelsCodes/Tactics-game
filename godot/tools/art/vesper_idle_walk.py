"""Vesper's idle and walk animations, from the owner's four-direction sheet (see idle_walk_sheet.py).

  art_src/characters/vesper_idle_walk_sheet.png   a row per direction (DOWN, UP, LEFT, RIGHT); IDLE (4 frames) and WALK (4 frames) side by side

These frames are Vesper's idle and walk for the rest of the game, so this step is part of the rebuild. Run it after eight_dir.py
(which cuts her other animations from art_src/characters/vesper_sheet.webp) and before her attack (vesper_attack.py, which measures
her built idle):

  python3 godot/tools/art/eight_dir.py && python3 godot/tools/art/vesper_idle_walk.py && python3 godot/tools/art/vesper_attack.py
"""
import idle_walk_sheet

IDLE = (128, 822)   # x range of the four idle frames
WALK = (829, 1531)  # x range of the four walk frames
ROWS = {'s': (76, 293), 'n': (298, 518), 'w': (522, 733), 'e': (738, 951)}  # DOWN, UP, LEFT, RIGHT

CONFIG = {
    'key': 'vesper',
    'src': 'art_src/characters/vesper_idle_walk_sheet.png',
    'size': (1536, 1024),
    'canvas': (141, 75),   # meta.json size
    'feet': (67, 71),      # meta.json anchor (67, 72), y minus 1
    'figure_px': 63.5,     # her figure's height on the canvas, as on her other animations (run, dash, ...)
    'boxes': {(kind, d): (xs[0], xs[1], ys[0], ys[1]) for kind, xs in (('idle', IDLE), ('walk', WALK)) for d, ys in ROWS.items()},
}

if __name__ == '__main__':
    idle_walk_sheet.build(CONFIG)
