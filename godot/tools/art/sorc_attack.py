"""The Sorceress's four-direction attack, from the owner's sheet (see attack_sheet.py).

  art_src/characters/sorc_attack_sheet.png   four rows (DOWN, UP, LEFT, RIGHT), four frames in each: she raises her staff and a magic
                                             circle opens on the strike frame (the glow is drawn in the frames)

Built on her own canvas and feet, at the pixel size of her idle (sorc_idle_walk.py), so she is the same size when she casts. Part of the
rebuild: run it after eight_dir.py and sorc_idle_walk.py:

  python3 godot/tools/art/eight_dir.py && python3 godot/tools/art/sorc_idle_walk.py && python3 godot/tools/art/sorc_attack.py
"""
import attack_sheet

CONFIG = {
    'key': 'sorc',
    'src': 'art_src/characters/sorc_attack_sheet.png',
    'size': (1774, 887),
    'canvas': (130, 72),   # meta.json size
    'feet': (59, 69),      # meta.json anchor (59, 70), y minus 1
    'figure_px': 63.0,     # fallback for her figure's height (the real one is measured from her built idle)
    'cols': [(142, 552), (562, 967), (977, 1388), (1397, 1768)],
    'rows': {'s': (71, 261), 'n': (271, 464), 'w': (474, 653), 'e': (663, 857)},  # DOWN, UP, LEFT, RIGHT
    'fps': 10,
    'strike': 2,  # the strike frame (the circle opens)
}

if __name__ == '__main__':
    attack_sheet.build(CONFIG)
