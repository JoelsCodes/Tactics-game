"""Alaric's rigged knight (owner's Skeleton2D rig, tools/rig/knight_8d) as a sheet character, `alaric_rig`.

The rig is baked by tools/rig/knight_8d/bake.gd into two magenta sheets in the layouts the other art tools cut:

  art_src/characters/alaric_rig_idle_walk_sheet.png   3320x640: IDLE row, WALK row; panels DOWN, RIGHT, UP, LEFT; 4 frames
  art_src/characters/alaric_rig_attack_sheet.png      800x1200: rows DOWN, UP, LEFT, RIGHT; 4 frames; the blow on the third

  xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot res://tools/rig/knight_8d/bake.tscn
  python3 godot/tools/art/alaric_rig.py        # only this character: meta.json gets the `alaric_rig` entry, nothing else changes
  bash godot/tools/art/add_enemy.sh alaric_rig # not needed: build its .tres with the line below
  godot --headless --path godot --import && godot --headless --path godot --script res://tools/build_resources.gd -- only=alaric_rig

Four directions: W is the rig's own mirrored view of E. Size comes from idle_walk_sheet.standard_scale (as tall as the King).
"""
import attack_sheet
import idle_walk_sheet

PANEL_W = 800
GAP = 40
CANVAS = (96, 72)
FEET = (48, 69)
FIGURE = 60.0

IDLE_WALK = {
    'key': 'alaric_rig',
    'src': 'art_src/characters/alaric_rig_idle_walk_sheet.png',
    'size': (3320, 640),
    'canvas': CANVAS,
    'feet': FEET,
    'figure_px': FIGURE,
    'panels': {d: (i * (PANEL_W + GAP), i * (PANEL_W + GAP) + PANEL_W) for i, d in enumerate('senw')},
    'rows': {'idle': (0, 300), 'walk': (340, 640)},
    'frames': 4,
    'new': True,
}

ATTACK = {
    'key': 'alaric_rig',
    'src': 'art_src/characters/alaric_rig_attack_sheet.png',
    'size': (800, 1200),
    'canvas': CANVAS,
    'feet': FEET,
    'figure_px': FIGURE,
    'cols': [(0, 200), (200, 400), (400, 600), (600, 800)],
    'rows': {'s': (0, 300), 'n': (300, 600), 'w': (600, 900), 'e': (900, 1200)},  # DOWN, UP, LEFT, RIGHT
    'fps': 10,
    'strike': 2,
}

if __name__ == '__main__':
    idle_walk_sheet.build(IDLE_WALK)
    attack_sheet.build(ATTACK)
