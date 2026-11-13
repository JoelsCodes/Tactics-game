"""Lyra's idle, walk, run, attack, hurt and knock-out animations (sheet id `mira`), from the owner's six sheets (Nov 2026).

  art_src/characters/lyra_idle_sheet.png     1086x1448  four rows (DOWN, RIGHT, UP, LEFT), 4 frames each
  art_src/characters/lyra_walk_sheet.png     1536x1024  four rows, 6 frames each
  art_src/characters/lyra_run_sheet.png      1536x1024  four rows, 6 frames each
  art_src/characters/lyra_attack_sheet.png   1086x1448  four rows, 6 frames each (draw, raise, the swing with its arc on frame 3, thrust, recover)
  art_src/characters/lyra_hit_sheet.png      1086x1448  four rows, 2 frames each (a wince, then the guard again)
  art_src/characters/lyra_ko_sheet.png       1086x1448  four rows, 4 frames each (kneels, sits, lies down)

Replaces lyra_idle_walk.py (her older idle/walk sheet, still in art_src and in git history). Part of the rebuild: run it after
eight_dir.py (which writes meta.json from scratch). The cutting is in sheet_set.py (shared with Bram's bram_anims.py).

The sheets were not drawn at one scale, and her hair makes head width unreliable, so each sheet is scaled so its resting frames are as tall
as her idle (the run by its two upright contact frames, the attack by its guard frames 0 and 5, the hurt by its calm frame 1); the knock-out
shares the idle's scale (the same sheet size). The attack's swing arc is translucent: that sheet is cut with soft edges, and
`slash_in_frames` is set so the game adds no slash on top. The canvas is her 118x94 one, shared with her other animations, so the far tip
of a thrust can be clipped a little (the script lists the frames it clips).

  python3 godot/tools/art/eight_dir.py && python3 godot/tools/art/lyra_anims.py
"""
import sheet_set

CONFIG = {
    'key': 'mira',        # her sheet's id in meta.json and on disk (the unit is named Lyra)
    'label': 'Lyra',
    'canvas': (118, 94),   # meta.json size
    'feet': (58, 91),      # meta.json anchor (58, 92), y minus 1
    'figure_px': 75.0,     # her figure's height on the canvas, as on her other animations
    'sheets': {
        'idle':   dict(src='art_src/characters/lyra_idle_sheet.png',   size=(1086, 1448), frames=4),
        'walk':   dict(src='art_src/characters/lyra_walk_sheet.png',   size=(1536, 1024), frames=6),
        'run':    dict(src='art_src/characters/lyra_run_sheet.png',    size=(1536, 1024), frames=6),
        'attack': dict(src='art_src/characters/lyra_attack_sheet.png', size=(1086, 1448), frames=6),
        'hit':    dict(src='art_src/characters/lyra_hit_sheet.png',    size=(1086, 1448), frames=2),
        'ko':     dict(src='art_src/characters/lyra_ko_sheet.png',     size=(1086, 1448), frames=4),
    },
    'norm': {
        'idle': ('height', None), 'walk': ('height', None),
        'run': ('height', [0, 3]),       # the upright contact frames; the others crouch or leave the ground
        'attack': ('height', [0, 5]),    # the guard frames
        'hit': ('height', [1]),          # the calm frame
        'ko': ('same', 'idle'),
    },
    'fps': {'idle': 4, 'walk': 8, 'run': 12, 'attack': 12, 'hit': 6, 'ko': 6},
    'strike': 3,           # the swing, with its arc
    'celled': {'attack': (0, 5), 'hit': (1,), 'ko': (0,)},  # placed by the boots of their resting frames
    'grounded': ('ko',),   # the sheet draws her lying frames higher than her standing ones: they would float
    'soft': ('attack',),   # the arc's glow is kept translucent
    'slash_in_frames': True,
}

if __name__ == '__main__':
    sheet_set.build(CONFIG)
