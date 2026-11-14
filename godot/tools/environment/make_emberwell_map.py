#!/usr/bin/env python3
"""Checks and finishes godot/samples/emberwell_village.json, the owner's terrace-test map for the Emberwell Village GLB (Nov 2026).

    python3 godot/tools/environment/make_emberwell_map.py

The owner's file is the source (20 x 20 rows, spawns, level_height 0.42); this adds only what the board needs to draw it from the GLB:
  "scenery": "emberwell"   Board3D shows the village (EmberwellScenery) instead of the procedural terrain
  "floor_base": 0          the village ground is at y = 0
  "grade", "haze"          the look (the village burns: warm)
and checks the rules every battle map keeps: every spawn is on ground that can be stood on, nobody starts within Move + 1 of anyone is left to
tests/spacing_check, and every enemy can be reached by walking from the King.
"""
import json
import os
import sys
from collections import deque

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
PATH = os.path.join(ROOT, 'samples', 'emberwell_village.json')


def parse(tok):
    import re
    m = re.match(r'^([A-Za-z])(-?[0-9]+(?:\.5)?)?([<>^v]?)([!~*]*)$', tok)
    return m.group(1), float(m.group(2) or 0), m.group(3), m.group(4)


def main():
    m = json.load(open(PATH, encoding='utf-8'))
    rows = [r.split() for r in m['rows']]
    assert len(rows) == 20 and all(len(r) == 20 for r in rows), 'the map must be 20 x 20'
    cells = {(x, y): parse(rows[y][x]) for y in range(20) for x in range(20)}
    blocked = {c for c, t in cells.items() if '!' in t[3]}
    sp = m['spawns']
    for name, c in [('king', sp['king']), ('captain', sp['captain'])] + [('stone', s) for s in sp['stones']] + [('enemy', e['at']) for e in sp['enemies']]:
        assert tuple(c) not in blocked, '%s %s is on a blocked cell' % (name, c)
    # a walk from the King over open cells, one level up at most (the board's rule)
    start = tuple(sp['king'])
    seen = {start}
    q = deque([start])
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + dx, y + dy)
            if n in cells and n not in blocked and n not in seen and cells[n][1] - cells[(x, y)][1] <= 1.0:
                seen.add(n)
                q.append(n)
    far = [e['at'] for e in sp['enemies'] if tuple(e['at']) not in seen]
    assert not far, 'enemies the King cannot walk to: %s' % far
    m['scenery'] = 'emberwell'
    m['floor_base'] = 0.0
    m.setdefault('grade', 'natural')
    m.setdefault('haze', 'light')
    m['name'] = 'Proving Grounds 5: Emberwell Village. A burning hill village: a stone-paved square round the well, a raised terrace, houses and farmsteads on fire.'
    json.dump(m, open(PATH, 'w', encoding='utf-8'), indent=1, ensure_ascii=False)
    open(PATH, 'a').write('\n')
    print('ok: %d blocked cells, %d open cells reachable from the King, level_height %s' % (len(blocked), len(seen), m['level_height']))


if __name__ == '__main__':
    sys.exit(main())
