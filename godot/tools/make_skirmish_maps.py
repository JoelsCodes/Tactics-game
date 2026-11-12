#!/usr/bin/env python3
"""Writes the Proving Grounds' compact maps (owner, Nov 2026: "a smaller map class", after REFERENCE_FFT_MAPS.md: FFT's maps are a median 108 tiles,
ours 384): godot/samples/skirmish_1.json .. skirmish_3.json, 12 deep and 12 to 14 wide. Each shows the newer ground:
  1 Thistle Rise     a rolling moor: a knoll of half steps, a shallow stream with sand banks (water slows, sand grounds lightning), a few thorn trees
  2 The Sunken Span  two snowy cliffs and a river canyon: a two-wide plank bridge and a narrow stone walkway over deep water (decks; the walkway is
                     pass-only, nobody stops on it), and ramps down to a ford
  3 Cinder Shrine    a ruined shrine on a terraced hill: stone stairs (ramps), cinder slopes (fire +25%), broken pillars (scenery, "!"), a holy dais
Run from the repo root, then the terrain upgrade (footprint notches and mounds):
    python3 godot/tools/make_skirmish_maps.py && python3 godot/tools/upgrade_terrain.py
The battle runs left to right: the player starts on the low rows (y), the enemy on the high ones.
"""
import json, os
from collections import deque

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
OUT = os.path.join(ROOT, 'samples', 'skirmish_%d.json')
MOVE = {'player': 4, 'scout': 5, 'watchman': 4, 'hound': 5, 'brute': 3}  # the Riverford kinds (Riverford.KINDS) the skirmishes use


class M:
    def __init__(self, d, w, code='g', h=0):
        self.d, self.w = d, w
        self.g = [[[code, float(h), '', '', None] for _x in range(d)] for _y in range(w)]  # [code, height, slope, flags, under-token]

    def set(self, x, y, code=None, h=None, slope='', flags='', under=None):
        c = self.g[y][x]
        if code is not None: c[0] = code
        if h is not None: c[1] = float(h)
        c[2], c[3], c[4] = slope, flags, under

    def tok(self, x, y):
        code, h, s, f, u = self.g[y][x]
        if code == 'v': return 'v'
        hs = str(int(h)) if h == int(h) else '%.1f' % h
        t = code + hs + s + f
        return t + ('=' + u if u else '')

    def walk(self, x, y):
        if not (0 <= x < self.d and 0 <= y < self.w): return False
        code, h, s, f, u = self.g[y][x]
        return code not in 'Wltv' and '!' not in f and '*' not in f

    def reach(self, start):
        seen = {start}; q = deque([start])
        while q:
            x, y = q.popleft()
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (x + dx, y + dy)
                if n in seen or not self.walk(*n): continue
                if self.g[n[1]][n[0]][1] - self.g[y][x][1] > 1: continue
                seen.add(n); q.append(n)
        return seen

    def save(self, n, name, spawns, **extra):
        d = {'name': name, 'rows': [' '.join(self.tok(x, y) for x in range(self.d)) for y in range(self.w)], 'spawns': spawns,
             'shadows': True, 'tufts': True, 'rough_walls': True}
        d.update(extra)
        with open(OUT % n, 'w') as f:
            json.dump(d, f, indent=1); f.write('\n')


def check(m, sp, key):
    errs = []
    mine = [tuple(sp['king']), tuple(sp['captain'])]
    for c in mine + [tuple(e['at']) for e in sp['enemies']]:
        if not m.walk(*c) or '~' in m.g[c[1]][c[0]][3]: errs.append('%s is not ground one can stand on' % (c,))
    for c in mine:
        for e in sp['enemies']:
            dist = abs(c[0] - e['at'][0]) + abs(c[1] - e['at'][1])
            if dist <= max(MOVE['player'], MOVE[e['kind']]) + 1: errs.append('%s is within reach of %s %s' % (c, e['kind'], e['at']))
    r = m.reach(tuple(sp['king']))
    for e in sp['enemies']:
        if not any((e['at'][0] + dx, e['at'][1] + dy) in r for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
            errs.append('Alaric cannot walk to %s %s' % (e['kind'], e['at']))
    tiles = sum(1 for y in range(m.w) for x in range(m.d) if m.g[y][x][0] != 'v')
    print('%s: %d tiles, %d deep x %d wide%s' % (key, tiles, m.d, m.w, '' if not errs else '\n  PROBLEMS: ' + '; '.join(errs)))
    return errs


problems = []


def clump(x, y, seeds, r=1.6):
    """True near one of a few seed points: patches, not a checkerboard."""
    return any(((x - a) ** 2 + (y - b) ** 2) ** 0.5 <= r for a, b in seeds)


# ================================================================ 1. Thistle Rise (12 deep x 13 wide)
m = M(12, 13, 'g', 0)
for y in range(13):
    for x in range(12):
        dist = ((x - 7) ** 2 + (y - 7) ** 2) ** 0.5
        h = max(0.0, round((3.4 - 0.62 * dist) * 2) / 2)  # a knoll in half and whole steps (never more than one between neighbours)
        m.set(x, y, 'g', h)
for x in range(12):                                     # a shallow stream across the moor, sand banks beside it
    m.set(x, 3, 'w', 0)
    if m.g[2][x][1] <= 0.5: m.set(x, 2, 'a', 0)
    if m.g[4][x][1] <= 0.5: m.set(x, 4, 'a', m.g[4][x][1])
for x, y in [(2, 6), (10, 4), (3, 10), (10, 10), (5, 11)]:
    m.set(x, y, 't', m.g[y][x][1])                      # thorn trees
for x, y in [(6, 7), (7, 7), (7, 6), (8, 7)]:
    m.set(x, y, 'd', m.g[y][x][1])                      # a worn path over the crown
sp1 = {'king': [5, 0], 'captain': [7, 0], 'stones': [[3, 1], [9, 1]],
       'enemies': [{'at': [4, 11], 'kind': 'scout'}, {'at': [8, 12], 'kind': 'watchman'}, {'at': [7, 9], 'kind': 'hound'}, {'at': [10, 12], 'kind': 'scout'}]}
problems += check(m, sp1, 'skirmish_1')
m.save(1, 'Proving Grounds 1: Thistle Rise. A rolling moor: a knoll in half steps, a shallow stream with sand banks, thorn trees', sp1, haze='light', ambient='motes')

# ================================================================ 2. The Sunken Span (11 deep x 14 wide)
m = M(11, 14, 's', 3)
for y in range(0, 5):
    for x in range(11):
        m.set(x, y, 's' if clump(x, y, [(2, 1), (8, 3), (5, 0)]) else 'n', 3)   # the west cliff: snow, the stone showing through in a few places
for y in range(9, 14):
    for x in range(11):
        m.set(x, y, 's' if clump(x, y, [(3, 10), (9, 12), (6, 13)]) else 'g', 3)   # the east cliff: grass with a few flagged clearings
for y in range(5, 9):
    for x in range(11):
        m.set(x, y, 'W', 0)                             # the river canyon
for y in range(5, 9):                                   # a two-wide plank bridge and a narrow stone walkway (nobody stops on it)
    for x in (1, 2):
        m.set(x, y, 'b', 3, under='W0')
    m.set(8, y, 's', 3, flags='~', under='W0')
for x in (4, 5, 6):                                     # the ford: ramps down to a shallow crossing at level 1
    m.set(x, 5, 'a', 2, slope='^')
    m.set(x, 6, 'w', 1)
    m.set(x, 7, 'w', 1)
    m.set(x, 8, 'a', 2, slope='v')
sp2 = {'king': [5, 1], 'captain': [3, 1], 'stones': [[1, 3], [9, 2]],
       'enemies': [{'at': [2, 11], 'kind': 'scout'}, {'at': [5, 12], 'kind': 'watchman'}, {'at': [8, 11], 'kind': 'brute'}, {'at': [6, 13], 'kind': 'hound'}]}
problems += check(m, sp2, 'skirmish_2')
m.save(2, 'Proving Grounds 2: The Sunken Span. Two snowy cliffs over a river canyon: a plank bridge, a narrow stone walkway, a ford below', sp2, haze='light', ambient='snow')

# ================================================================ 3. Cinder Shrine (12 deep x 12 wide)
m = M(12, 12, 'g', 0)
for y in range(12):
    for x in range(12):
        ring = max(abs(x - 6), abs(y - 8))              # terraces stepping up to the shrine at (6, 8)
        h = 3 if ring <= 1 else 2 if ring <= 3 else 1 if ring <= 5 else 0
        code = 'e' if ring == 0 else 's' if ring <= 1 else 'c' if ring <= 3 else 'd' if ring <= 5 else 'g'
        m.set(x, y, code, h)
# stairs: put a ramp tile in each terrace's first row where it meets the one below
for x, y, code, h, s in [(6, 2, 's', 0.5, 'v'), (6, 4, 's', 1.5, 'v'), (6, 6, 's', 2.5, 'v'), (2, 8, 's', 1.5, '>'), (4, 8, 's', 2.5, '>')]:
    m.set(x, y, code, h, slope=s)
m.set(7, 8, 'e', 3); m.set(6, 9, 'e', 3)                # the holy dais
for x, y in [(5, 7), (7, 9), (5, 9), (7, 7)]:
    m.set(x, y, 'q', 5, flags='!')                      # broken pillars round the dais: scenery
for x, y in [(1, 4), (10, 3), (11, 10)]:
    m.set(x, y, 't', m.g[y][x][1])
sp3 = {'king': [6, 0], 'captain': [4, 0], 'stones': [[2, 1], [9, 1]],
       'enemies': [{'at': [6, 8], 'kind': 'brute'}, {'at': [3, 10], 'kind': 'watchman'}, {'at': [9, 9], 'kind': 'scout'}, {'at': [8, 11], 'kind': 'scout'}]}
problems += check(m, sp3, 'skirmish_3')
m.save(3, 'Proving Grounds 3: Cinder Shrine. A ruined shrine on a terraced hill: stone stairs, cinder slopes, broken pillars, a holy dais', sp3, haze='light', ambient='embers')

if problems:
    raise SystemExit('problems: %d' % len(problems))
