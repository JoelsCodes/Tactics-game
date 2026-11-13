"""Lyra's idle, walk, run, attack, cast, hurt and knock-out animations (sheet id `mira`), from the owner's sheets (Nov 2026).

All transparent sheets in Alaric's layout (1254x1254; cut by sheet_set.cut_grid through alaric_v2.row_cells):
  art_src/characters/lyra_v2_walk_sheet.png   eight rows (S, SE, E, NE, N, NW, W, SW), 6 frames in columns 2 to 7 of an eight-column grid
  art_src/characters/lyra_v2_idle_sheet.png   four rows (DOWN, RIGHT, UP, LEFT), 8 frames
  art_src/characters/lyra_v2_run_sheet.png    four rows, 6 frames
  art_src/characters/lyra_v2_attack_sheet.png eight rows (S, SE, E, NE, N, NW, W, SW), 8 frames: two ready, two raised, two slash (strike 4), two recovery
  art_src/characters/lyra_v2_cast_sheet.png   eight rows (S, SE, E, NE, N, NW, W, SW), 8 frames: she gathers, releases on frame 5 (strike 4), recovers;
                                              Lyra stays four-direction, so rows 0, 2, 4 and 6 are used
  art_src/characters/lyra_v2_hurt_sheet.png   four rows, 8 frames (impact, snap back, hold, recover)
  art_src/characters/lyra_v2_ko_sheet.png     four rows, 8 frames (the blow, stagger, the knees give, the fall onto her back, lying still)
The older magenta sheets (lyra_walk_sheet.png, lyra_idle_sheet.png, lyra_run_sheet.png, lyra_attack_sheet.png, lyra_hit_sheet.png, lyra_ko_sheet.png) are replaced by these; they stay in art_src.

Replaces lyra_idle_walk.py (her oldest idle/walk sheet). Part of the rebuild: run it after eight_dir.py (which writes meta.json from scratch).
The cutting is in sheet_set.py (shared with Bram's bram_anims.py).

The sheets were not drawn at one scale, and her hair makes head width unreliable. The idle, run, hurt and knock-out sheets share a scale (the same
cell height); the cast sheet is drawn at half that size and is matched to the idle's standing figure, and the walk and attack take the cast's scale (her
guard stance is a crouch, so it stands about 10% shorter than her idle). The new
attack draws the sword but no arc, so `slash_in_frames` is off and the game adds its own slash. Her figure is 112 px tall on Alaric's 240x172 canvas
(`figure_px`), his pixel density (she was 75 px on a 118x94 canvas, so her pixels were 1.5x chunkier than his). Every frame gets his finish (`rim`:
hard alpha, the outermost pixels in his outline colour). Her older one-direction frames are rescaled onto the new canvas (`legacy`) and dash plays the
run (`dash_is_run`). The script lists any frame the canvas clips.

  python3 godot/tools/art/eight_dir.py && python3 godot/tools/art/lyra_anims.py
"""
import sheet_set

CONFIG = {
    'key': 'mira',        # her sheet's id in meta.json and on disk (the unit is named Lyra)
    'label': 'Lyra',
    'canvas': (240, 172),  # meta.json size: Alaric's canvas (a bigger one than her old 118x94, for the finer pixels and the long sword reach)
    'feet': (120, 160),    # meta.json anchor (120, 161), y minus 1: Alaric's
    'figure_px': 112.0,    # her figure's height on the canvas: Alaric's pixel density (she was 75, so her pixels were 1.5x chunkier)
    'rim': (19, 13, 13),   # Alaric's outline colour, measured from his walk frames
    'dash_is_run': True,
    'legacy': {'canvas': (118, 94), 'feet': (58, 91), 'figure_px': 75.0},  # her older frames (one-direction attack, heavy, cast, hit, ko) are on this
    'sheets': {
        'idle':   dict(src='art_src/characters/lyra_v2_idle_sheet.png',  size=(1254, 1254), frames=8, grid=dict(rows=4, pick=[0, 1, 2, 3])),
        'walk':   dict(src='art_src/characters/lyra_v2_walk_sheet.png',  size=(1254, 1254), frames=6, grid=dict(rows=8, pick=[0, 2, 4, 6], cols=8, first_col=1)),
        'run':    dict(src='art_src/characters/lyra_v2_run_sheet.png',   size=(1254, 1254), frames=6, grid=dict(rows=4, pick=[0, 1, 2, 3])),
        'attack': dict(src='art_src/characters/lyra_v2_attack_sheet.png', size=(1254, 1254), frames=8, grid=dict(rows=8, pick=[0, 2, 4, 6])),
        'cast':   dict(src='art_src/characters/lyra_v2_cast_sheet.png',  size=(1254, 1254), frames=8, grid=dict(rows=8, pick=[0, 2, 4, 6])),
        'hit':    dict(src='art_src/characters/lyra_v2_hurt_sheet.png',  size=(1254, 1254), frames=8, grid=dict(rows=4, pick=[0, 1, 2, 3])),
        'ko':     dict(src='art_src/characters/lyra_v2_ko_sheet.png',    size=(1254, 1254), frames=8, grid=dict(rows=4, pick=[0, 1, 2, 3])),
    },
    'norm': {
        'idle': ('height', None),
        'walk': ('same', 'cast'),        # the same size of cell as the cast's
        'run': ('same', 'idle'),         # the same cell height as the idle's (her contact frames stand as tall)
        'attack': ('same', 'cast'),      # the same size of cell as the cast's (her guard stance is a crouch, so it is shorter than her idle)
        'cast': ('match', 'idle', [0], [0]),   # drawn at half the idle's size: her standing figure matches the idle's
        'hit': ('same', 'idle'),         # the same size of sheet as the idle's
        'ko': ('same', 'idle'),
    },
    'fps': {'idle': 7, 'walk': 8, 'run': 12, 'attack': 14, 'cast': 11, 'hit': 12, 'ko': 8},
    'set_fps': ('idle',),  # eight frames now: Alaric's pace, not the old four-frame 4 fps
    'strike': 4,           # the first slash frame (two ready, two raised, two slash, two recovery)
    'cast_strike': 4,      # the release: the frame the spell leaves her hand
    # placed by the boots of their resting frames (one shift per direction), so the sway, lunge, recoil and fall move as drawn
    'celled': {'attack': (0, 7), 'idle': tuple(range(8)), 'cast': tuple(range(8)), 'hit': tuple(range(8)), 'ko': (0,)},
    'grounded': ('ko',),   # lying frames sit on the ground row, wherever the sheet drew them
    'area_norm': ('ko',),  # the knock-out sheet squeezes the fall into 156 px cells: she is drawn about 40% smaller lying than standing
    'slash_in_frames': False,   # the new attack draws the sword but no arc: the game adds its own slash
}

if __name__ == '__main__':
    sheet_set.build(CONFIG)
