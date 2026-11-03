"""Merc's (a vessel) whole character, from the owner's four-direction sheet (see grid_sheet.py).

  python3 godot/tools/art/merc_sheet.py        (run after eight_dir.py)

IDLE, WALK and ATTACK have a row per direction (DOWN, UP, LEFT, RIGHT); HURT, MAGIC and DEATH are one row facing the viewer
(the game mirrors them for the other side). The attack's arc and the magic glow are in the frames.
"""
import grid_sheet

ROWS4 = [(57, 208), (209, 356), (358, 505), (507, 667)]
CONFIG = {
    'key': 'merc', 'src': 'art_src/characters/merc_sheet.png', 'size': (1536, 1024), 'pixel': 0.8,
    'illustration': (6, 696, 296, 1004),
    'blocks': {
        'idle': dict(box=(100, 57, 535, 667), rows=ROWS4, dirs=grid_sheet.ROWS),
        'walk': dict(box=(543, 57, 1016, 667), rows=ROWS4, dirs=grid_sheet.ROWS),
        'attack': dict(box=(1024, 57, 1533, 667), rows=ROWS4, dirs=grid_sheet.ROWS),
        'hurt': dict(box=(309, 768, 686, 963), dirs=['s']),
        'magic': dict(box=(694, 768, 1114, 963), dirs=['s']),
        'death': dict(box=(1122, 768, 1532, 963), dirs=['s']),
    },
}

if __name__ == '__main__':
    grid_sheet.build(CONFIG)
