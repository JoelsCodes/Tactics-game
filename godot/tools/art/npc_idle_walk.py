"""The four villagers' idle and walk animations, from the owner's four-direction sheets (see idle_walk_sheet.py).

  art_src/characters/villager_man_idle_walk_sheet.png     the man villager     (5 frames per panel)
  art_src/characters/villager_girl_idle_walk_sheet.png    the girl villager    (5 frames per panel)
  art_src/characters/villager_kid_idle_walk_sheet.png     the kid villager     (5 frames per panel)
  art_src/characters/mechanic_idle_walk_sheet.png         the mechanic         (4 frames per panel)

Top row IDLE, bottom row WALK; panels DOWN, RIGHT, UP, LEFT. These are not battle units: they only fill the cutscenes, the base and
towns (NpcLook lists them). They have just idle and walk (running plays the walk), so each character's meta.json entry is made here
from scratch (`new`). Run it after eight_dir.py (which writes meta.json from scratch):

  python3 godot/tools/art/eight_dir.py && python3 godot/tools/art/npc_idle_walk.py

Like every character they are drawn as tall as the King (STANDARD_FIGURE), the kid too: the owner's size standard.
"""
import idle_walk_sheet

PANELS = {'s': (5, 382), 'e': (389, 764), 'n': (771, 1144), 'w': (1152, 1530)}
ROWS = {'idle': (173, 505), 'walk': (571, 911)}


def config(key, frames):
    return {
        'key': key,
        'src': 'art_src/characters/%s_idle_walk_sheet.png' % key,
        'size': (1536, 1024),
        'canvas': (96, 72),   # meta.json size
        'feet': (48, 69),     # meta.json anchor (48, 70), y minus 1
        'figure_px': 60.0,    # the figure's height on the canvas, like the other characters' (their size in game comes from STANDARD_FIGURE)
        'panels': PANELS,
        'rows': ROWS,
        'frames': frames,
        'new': True,
    }


CONFIGS = [config('villager_man', 5), config('villager_girl', 5), config('villager_kid', 5), config('mechanic', 4)]

if __name__ == '__main__':
    for cfg in CONFIGS:
        idle_walk_sheet.build(cfg)
