"""The Ashen Squire's four-direction attack, from the owner's sheet (see attack_sheet.py).

  art_src/characters/squire_attack_sheet.png   four rows (DOWN, UP, LEFT, RIGHT), four frames in each

His idle and walk set his size, so this is built on the same canvas, feet and figure height. Part of the rebuild: run it
after eight_dir.py and squire_idle_walk.py:

  python3 godot/tools/art/eight_dir.py && python3 godot/tools/art/squire_idle_walk.py && python3 godot/tools/art/squire_attack.py
"""
import attack_sheet
import squire_idle_walk

IDLE = squire_idle_walk.CONFIG
CONFIG = {
    'key': 'squire',
    'src': 'art_src/characters/squire_attack_sheet.png',
    'size': (1774, 887),
    'canvas': IDLE['canvas'],
    'feet': IDLE['feet'],
    'figure_px': IDLE['figure_px'],
    'cols': [(3, 443), (447, 885), (890, 1328), (1333, 1771)],
    'rows': {'s': (69, 232), 'n': (296, 463), 'w': (528, 680), 'e': (740, 883)},  # DOWN, UP, LEFT, RIGHT
    'fps': 10,
    'strike': 2,  # the slash frame
}

if __name__ == '__main__':
    attack_sheet.build(CONFIG)
