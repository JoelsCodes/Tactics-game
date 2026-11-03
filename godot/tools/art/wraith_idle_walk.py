"""Lunar's (the Lantern Wraith's sheet id is still `wraith`) idle and walk animations, from the owner's four-direction sheet (see idle_walk_sheet.py).

  art_src/characters/wraith_idle_walk_sheet.png   a row per direction (DOWN, UP, LEFT, RIGHT); IDLE (4 frames) and WALK (4 frames) side by side

Same layout as Vesper's sheet (vesper_idle_walk.py). These frames are the wolf's idle and walk for the rest of the game, so this step is
part of the rebuild. Run it after eight_dir.py (which cuts his other animations from art_src/characters/wraith_sheet.webp):

  python3 godot/tools/art/eight_dir.py && python3 godot/tools/art/wraith_idle_walk.py
"""
import idle_walk_sheet

IDLE = (128, 822)   # x range of the four idle frames
WALK = (829, 1532)  # x range of the four walk frames
ROWS = {'s': (76, 293), 'n': (297, 518), 'w': (522, 733), 'e': (737, 950)}  # DOWN, UP, LEFT, RIGHT

CONFIG = {
    'key': 'wraith',
    'src': 'art_src/characters/wraith_idle_walk_sheet.png',
    'size': (1536, 1024),
    'canvas': (138, 70),   # meta.json size
    'feet': (65, 68),      # meta.json anchor (65, 69), y minus 1
    'figure_px': 50.0,     # his figure's height on the canvas (median of the four directions): low enough that his taller back view fits the 70 px canvas
    'boxes': {(kind, d): (xs[0], xs[1], ys[0], ys[1]) for kind, xs in (('idle', IDLE), ('walk', WALK)) for d, ys in ROWS.items()},
}

if __name__ == '__main__':
    idle_walk_sheet.build(CONFIG)
