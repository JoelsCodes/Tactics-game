#!/usr/bin/env python3
"""The Last Benediction as a battle map: godot/samples/last_benediction.json, from the owner's navigation JSON (data/environment/last_benediction_nav.json).

Run from the repo root: python3 godot/tools/make_last_benediction_map.py

- Every tile is a castle flagstone ("f") at its elevation (0 or 1); a blocked tile gets the "!" flag (nobody walks or stands there, lines pass).
- The map's rows run the other way from the navigation JSON's: board row y = 10 - the JSON's y, so the GLB scenery is not mirrored (Board3D draws it
  with the GLB's own orientation; see Board3D._build_scenery). Spawns and the objective are converted the same way.
- `level_height` and `floor_base` set the board's heights to the GLB's floors: a floor slab's top is 0.2097 (elevation 0) and 0.8065 (elevation 1)
  in the scene's units, so one level is 0.5968 and level 0 sits at 0.2097.
- Enemies stand on the far side (the altar end), every one of them more than a Move + 1 away from the King and the Co-Captain (tests/spacing_check).
"""
import json
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
NAV = os.path.join(ROOT, 'data', 'environment', 'last_benediction_nav.json')
OUT = os.path.join(ROOT, 'samples', 'last_benediction.json')
GLB_TILE = 1.24
FLOOR_Y = {0: 0.18, 1: 0.92}   # the GLB's floor nodes' heights (see tools/environment/extract_nav.py)
SLAB_HALF = 0.08               # half a floor slab's thickness


def board(c):
    """The navigation JSON's (x, y) as the board's cell."""
    return [c[0], 10 - c[1]]


def main():
    nav = json.load(open(NAV, encoding='utf-8'))
    tiles = {(t['x'], t['y']): t for t in nav['tiles']}
    rows = []
    for yb in range(11):
        row = []
        for x in range(11):
            t = tiles[(x, 10 - yb)]
            row.append('f%d%s' % (t['elevation'], '!' if t['blocked'] else ''))
        rows.append(' '.join(row))
    top0 = (FLOOR_Y[0] + SLAB_HALF) / GLB_TILE
    top1 = (FLOOR_Y[1] + SLAB_HALF) / GLB_TILE
    sp = nav['player_spawns']
    spawns = {
        'king': board(sp[0]),
        'captain': board(sp[1]),
        'stones': [board([3, 2]), board([7, 2])],
        'enemies': [
            {'kind': 'scout', 'at': board([4, 8])},
            {'kind': 'watchman', 'at': board([6, 8])},
            {'kind': 'hound', 'at': board([7, 9])},
            {'kind': 'scout', 'at': board([2, 9])},
        ],
    }
    for c in [spawns['king'], spawns['captain']] + spawns['stones'] + [e['at'] for e in spawns['enemies']]:
        assert not tiles[(c[0], 10 - c[1])]['blocked'], 'a spawn is on a blocked tile: %s' % c
    m = {
        'name': 'Proving Grounds 4: The Last Benediction. The owner\'s ruined gothic cathedral, overtaken by violet crystal: a raised nave and a blocked altar.',
        'rows': rows,
        'spawns': spawns,
        'scenery': 'last_benediction',
        'level_height': round(top1 - top0, 4),
        'floor_base': round(top0, 4),
        'objective': board(nav['objective']),   # in front of the altar; data only so far (no rule uses it)
        'altar': board([5, 9]),
        'shadows': True,
        'haze': 'light',
        'grade': 'slate',   # cold, flat light, the colour drained: the art direction's cold limestone with restrained violet
    }
    json.dump(m, open(OUT, 'w', encoding='utf-8'), indent=1)
    open(OUT, 'a').write('\n')
    print('wrote', OUT, 'level_height', m['level_height'], 'floor_base', m['floor_base'], 'king', spawns['king'], 'objective', m['objective'])


if __name__ == '__main__':
    main()
