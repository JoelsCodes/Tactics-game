"""The Sorceress's idle and walk animations, from the owner's four-direction sheet (see idle_walk_sheet.py).

  art_src/characters/sorc_idle_walk_sheet.png   a row per direction (DOWN, UP, LEFT, RIGHT); IDLE (4 frames) and WALK (4 frames) side by side

(Nov 2026: replaces her first sheet, which was laid out in two rows; this one has Vesper's layout, so it is cut with `boxes`.)
These frames are the Sorceress's idle and walk for the rest of the game, so this step is part of the rebuild. Run it after
eight_dir.py and before her attack (sorc_attack.py, which measures her built idle):

  python3 godot/tools/art/eight_dir.py && python3 godot/tools/art/sorc_idle_walk.py && python3 godot/tools/art/sorc_attack.py
"""
import idle_walk_sheet

IDLE = (127, 823)   # x range of the four idle frames
WALK = (829, 1530)  # x range of the four walk frames
ROWS = {'s': (76, 293), 'n': (298, 516), 'w': (520, 732), 'e': (736, 948)}  # DOWN, UP, LEFT, RIGHT

CONFIG = {
    'key': 'sorc',
    'src': 'art_src/characters/sorc_idle_walk_sheet.png',
    'size': (1536, 1024),
    'canvas': (130, 72),   # meta.json size
    'feet': (59, 69),      # meta.json anchor (59, 70), y minus 1
    'figure_px': 63.0,     # her figure's height on the canvas, as on her other animations
    'boxes': {(kind, d): (xs[0], xs[1], ys[0], ys[1]) for kind, xs in (('idle', IDLE), ('walk', WALK)) for d, ys in ROWS.items()},
    'edge_key': True,      # her staff's orb is nearly the background's magenta: key from the box edges only
    'attach': 6,           # keep the staff's thin shaft and orb with her
}

if __name__ == '__main__':
    idle_walk_sheet.build(CONFIG)
