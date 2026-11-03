"""The Boar's (an enemy) whole character, from the owner's one four-direction sheet (see grid_sheet.py).

  python3 godot/tools/art/boar_sheet.py        (run after eight_dir.py)

Six blocks (IDLE, WALK, ATTACK, HURT, MAGIC, DEATH), each with a row per direction: DOWN, UP, LEFT, RIGHT.
"""
import grid_sheet

CONFIG = {
    'key': 'boar', 'src': 'art_src/characters/boar_sheet.png', 'size': (1536, 1024), 'pixel': 0.9,
    'illustration': (14, 772, 300, 1008),
    'blocks': {
        'idle': dict(box=(94, 48, 532, 366), dirs=grid_sheet.ROWS), 'walk': dict(box=(541, 48, 1016, 366), dirs=grid_sheet.ROWS),
        'attack': dict(box=(1026, 48, 1532, 366), dirs=grid_sheet.ROWS), 'hurt': dict(box=(95, 423, 532, 736), dirs=grid_sheet.ROWS),
        'magic': dict(box=(541, 424, 1020, 736), dirs=grid_sheet.ROWS), 'death': dict(box=(1030, 424, 1532, 736), dirs=grid_sheet.ROWS),
    },
}

if __name__ == '__main__':
    grid_sheet.build(CONFIG)
