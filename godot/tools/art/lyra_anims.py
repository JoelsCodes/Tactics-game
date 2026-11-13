"""Lyra's idle, walk, run, attack, cast, hurt and knock-out animations (sheet id `mira`), from the owner's sheets (Nov 2026).

Magenta sheets (cut by their drawing):
  art_src/characters/lyra_walk_sheet.png     1536x1024  four rows (DOWN, RIGHT, UP, LEFT), 6 frames each
  art_src/characters/lyra_run_sheet.png      1536x1024  four rows, 6 frames each
  art_src/characters/lyra_attack_sheet.png   1086x1448  four rows, 6 frames each (draw, raise, the swing with its arc on frame 3, thrust, recover)
Transparent sheets in Alaric's layout (1254x1254, 8 frames a row; cut by sheet_set.cut_grid through alaric_v2.row_cells):
  art_src/characters/lyra_v2_idle_sheet.png   four rows (DOWN, RIGHT, UP, LEFT), 8 frames
  art_src/characters/lyra_v2_cast_sheet.png   eight rows (S, SE, E, NE, N, NW, W, SW), 8 frames: she gathers, releases on frame 5 (strike 4), recovers;
                                              Lyra stays four-direction, so rows 0, 2, 4 and 6 are used
  art_src/characters/lyra_v2_hurt_sheet.png   four rows, 8 frames (impact, snap back, hold, recover)
  art_src/characters/lyra_v2_ko_sheet.png     four rows, 8 frames (the blow, stagger, the knees give, the fall onto her back, lying still)
The older idle, hurt and knock-out sheets (lyra_idle_sheet.png, lyra_hit_sheet.png, lyra_ko_sheet.png) are replaced by these; they stay in art_src.

Replaces lyra_idle_walk.py (her oldest idle/walk sheet). Part of the rebuild: run it after eight_dir.py (which writes meta.json from scratch).
The cutting is in sheet_set.py (shared with Bram's bram_anims.py).

The sheets were not drawn at one scale, and her hair makes head width unreliable, so the magenta sheets are scaled so their resting frames are as tall
as her idle (the run by its two upright contact frames, the attack by its guard frames 0 and 5). The idle, hurt and knock-out sheets share a scale
(the same sheet size); the cast sheet is drawn at half that size and is matched to the idle's standing figure. The attack's swing arc is translucent:
that sheet is cut with soft edges, and `slash_in_frames` is set so the game adds no slash on top. Her figure is 75 px tall on her 118x94 canvas
(`figure_px`), shared with her other animations; Alaric's is about 112, so her pixels are about 1.5x chunkier on screen than his. A thrust's far tip
could be clipped by the canvas (the script lists the frames it clips).

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
        'idle':   dict(src='art_src/characters/lyra_v2_idle_sheet.png',  size=(1254, 1254), frames=8, grid=dict(rows=4, pick=[0, 1, 2, 3])),
        'walk':   dict(src='art_src/characters/lyra_walk_sheet.png',     size=(1536, 1024), frames=6),
        'run':    dict(src='art_src/characters/lyra_run_sheet.png',      size=(1536, 1024), frames=6),
        'attack': dict(src='art_src/characters/lyra_attack_sheet.png',   size=(1086, 1448), frames=6),
        'cast':   dict(src='art_src/characters/lyra_v2_cast_sheet.png',  size=(1254, 1254), frames=8, grid=dict(rows=8, pick=[0, 2, 4, 6])),
        'hit':    dict(src='art_src/characters/lyra_v2_hurt_sheet.png',  size=(1254, 1254), frames=8, grid=dict(rows=4, pick=[0, 1, 2, 3])),
        'ko':     dict(src='art_src/characters/lyra_v2_ko_sheet.png',    size=(1254, 1254), frames=8, grid=dict(rows=4, pick=[0, 1, 2, 3])),
    },
    'norm': {
        'idle': ('height', None), 'walk': ('height', None),
        'run': ('height', [0, 3]),       # the upright contact frames; the others crouch or leave the ground
        'attack': ('height', [0, 5]),    # the guard frames
        'cast': ('match', 'idle', [0], [0]),   # drawn at half the idle's size: her standing figure matches the idle's
        'hit': ('same', 'idle'),         # the same size of sheet as the idle's
        'ko': ('same', 'idle'),
    },
    'fps': {'idle': 7, 'walk': 8, 'run': 12, 'attack': 12, 'cast': 11, 'hit': 12, 'ko': 8},
    'set_fps': ('idle',),  # eight frames now: Alaric's pace, not the old four-frame 4 fps
    'strike': 3,           # the attack's swing, with its arc
    'cast_strike': 4,      # the release: the frame the spell leaves her hand
    # placed by the boots of their resting frames (one shift per direction), so the sway, lunge, recoil and fall move as drawn
    'celled': {'attack': (0, 5), 'idle': tuple(range(8)), 'cast': tuple(range(8)), 'hit': tuple(range(8)), 'ko': (0,)},
    'grounded': ('ko',),   # lying frames sit on the ground row, wherever the sheet drew them
    'area_norm': ('ko',),  # the knock-out sheet squeezes the fall into 156 px cells: she is drawn about 40% smaller lying than standing
    'soft': ('attack',),   # the arc's glow is kept translucent
    'slash_in_frames': True,
}

if __name__ == '__main__':
    sheet_set.build(CONFIG)
