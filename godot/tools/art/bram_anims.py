"""Bram's idle, walk, run, attack, hurt and knock-out animations (sheet id `warden`), from the owner's six new sheets.

  art_src/characters/bram_idle_sheet.png     1254x1254  four rows (DOWN, RIGHT, UP, LEFT), 4 frames each
  art_src/characters/bram_walk_sheet.png     1536x1024  four rows (same order), 6 frames each
  art_src/characters/bram_run_sheet.png      1536x1024  four rows, 6 frames each
  art_src/characters/bram_attack_sheet.png   1536x1024  four rows, 6 frames each (sword thrust on frame 3; no drawn slash arc)
  art_src/characters/bram_hit_sheet.png       887x1774  four rows, 2 frames each (a wince, then the guard again)
  art_src/characters/bram_ko_sheet.png       1254x1254  four rows, 4 frames each (staggers, kneels, falls, lies still)

Replaces warden_idle_walk.py (his older idle/walk sheet, still in art_src and in git history). Part of the rebuild: run it after
eight_dir.py (which writes meta.json from scratch). The cutting is in sheet_set.py (shared with Lyra's lyra_anims.py).

Size: the owner's standard (the idle figure drawn STANDARD_FIGURE tall, `idle_walk_sheet.standard_scale`). The sheets were not drawn at
one scale (the idle's figure is about 8% stockier than the other three), so each is scaled on its own: idle and walk by figure height
(`FIGURE_PX` on the canvas), run and attack by head width against the walk's, so the character does not change size when he
runs or swings. Idle, walk and run are placed by the bottom and centre of each frame; the attack by the boots of its resting frames
(0 and 5), so the lunge and the thrust move as drawn.

Output: assets/characters/warden/animations/{idle,walk,run,attack}/<kind>_<s|e|n|w>_<k>.png and meta.json's idle_*, walk_*, run_* and
attack_<dir>, hit_<dir> and ko_<dir> (the animator picks `<action>_<dir>` for an eight_dir sheet; the older one-direction `attack`, `hit` and
`ko` stay as the fallback). Hurt frames go to animations/hurt, knock-out frames to animations/death. The hurt is placed by its calm frame
(1), the knock-out by its standing frame (0), and the hurt is scaled by head width against the idle's and the knock-out by head width against the hurt's (its first frame is the same wince).

  python3 godot/tools/art/eight_dir.py && python3 godot/tools/art/bram_anims.py
"""
import sheet_set

CONFIG = {
    'key': 'warden',   # Bram's sheet id (the vessel was called Warden)
    'label': 'Bram',
    'canvas': (240, 172),  # meta.json size: Alaric's canvas (he was on 190x97)
    'feet': (120, 160),    # meta.json anchor (120, 161), y minus 1: Alaric's
    'figure_px': 112.0,    # his figure's height on the canvas: Alaric's pixel density (he was 64, so his pixels were 1.75x chunkier)
    'rim': (19, 13, 13),   # Alaric's outline colour, measured from his walk frames
    'dash_is_run': True,
    'legacy': {'canvas': (190, 97), 'feet': (92, 90), 'figure_px': 64.0},  # his older frames (cast, heavy and the one-direction fallbacks) are on this
    'sheets': {
        'idle':   dict(src='art_src/characters/bram_idle_sheet.png',   size=(1254, 1254), frames=4),
        'walk':   dict(src='art_src/characters/bram_walk_sheet.png',   size=(1536, 1024), frames=6),
        'run':    dict(src='art_src/characters/bram_run_sheet.png',    size=(1536, 1024), frames=6),
        'attack': dict(src='art_src/characters/bram_attack_sheet.png', size=(1536, 1024), frames=6),
        'hit':    dict(src='art_src/characters/bram_hit_sheet.png',    size=(887, 1774),  frames=2),
        'ko':     dict(src='art_src/characters/bram_ko_sheet.png',     size=(1254, 1254), frames=4),
    },
    # the idle's figure is stockier than the others': idle and walk by height, the rest by head width against their neighbour
    'norm': {
        'idle': ('height', None), 'walk': ('height', None),
        'run': ('head', 'walk', None, None), 'attack': ('head', 'walk', None, None),
        'hit': ('head', 'idle', [1], None),    # the calm frame against the idle's head
        'ko': ('head', 'hit', [0], [0]),       # its first frame is the hurt's wince: the same head
    },
    'fps': {'idle': 4, 'walk': 8, 'run': 12, 'attack': 12, 'hit': 6, 'ko': 6},
    'strike': 3,           # the attack frame that lands the blow (the sword at full reach)
    'celled': {'attack': (0, 5), 'hit': (1,), 'ko': (0,)},  # placed by the boots of their resting frames
}

if __name__ == '__main__':
    sheet_set.build(CONFIG)
