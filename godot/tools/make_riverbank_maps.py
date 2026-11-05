#!/usr/bin/env python3
"""Writes the four Riverbank battle maps: godot/samples/riverbank_1.json .. riverbank_4.json. Run: python3 godot/tools/make_riverbank_maps.py

One tileset for all four (grass g, dirt d, stone s, crag r, shallow water w, deep water W, bridge b, trees t) and each its own
shape. Cells are (x, y): x is the depth (up the screen, 0 nearest the camera, where Alaric starts), y runs left to right.
Sizes: the standard map is 16x16 and may grow by up to 3 on each side, kept even and never past 19; the depth (x) stays 16 because a deeper board runs
under the battle HUD, so the growth is in the width (y). Level 4 is the owner's 15x15.
  1 The Ford            16x18  a river with a bridge, a wading ford and a ridge in the way
  2 The Mill Race       16x18  a mill on an island in a deep moat, offset bridges, bluffs climbed only from the far side
  3 The Broken Bridge   16x18  a bridge with its middle gone: a wading ford west, a ridge path east, archers on the bluff
  4 The Warden's Hold   15x15  a fortress terrace on the enemy side: a moat, a gate, two posterns, a dais for the boss
Each file carries "spawns" (where everyone starts). The script checks that every spawn is open, that nobody can reach anybody on the
first turn (Manhattan distance above Move plus reach), that the way from Alaric to the foes is longer than a straight line (detours),
and prints the maps."""
import json, random
from collections import defaultdict
import heapq

OUT = 'godot/samples/riverbank_%d.json'
THREAT = {'squire': 6, 'archer': 8, 'wolf': 7, 'boss': 7, 'eater': 5, 'boar': 7}  # Move 4 plus the farthest reach of the style (rook 2, bishop 4, knight 3)
PLAYER_THREAT = 6


class Map:
    def __init__(self, w, d, name):
        self.w, self.d, self.name = w, d, name
        self.g = [[['g', 0] for _ in range(w)] for _ in range(d)]   # g[y][x] = [code, level]

    def set(self, x, y, c, h=None):
        if 0 <= x < self.w and 0 <= y < self.d:
            self.g[y][x] = [c, self.g[y][x][1] if h is None else h]

    def box(self, x0, x1, y0, y1, c, h=None):
        for x in range(x0, x1 + 1):
            for y in range(y0, y1 + 1):
                self.set(x, y, c, h)

    def code(self, x, y): return self.g[y][x][0]
    def lvl(self, x, y): return self.g[y][x][1]

    def hills(self, bumps):
        for y in range(self.d):
            for x in range(self.w):
                v = sum(a * max(0.0, 1 - ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5 / r) for cx, cy, r, a in bumps)
                self.g[y][x][1] = int(round(v))

    def settle(self):
        """Grass heights never step more than one level against a neighbour (cliffs are painted as crag)."""
        ch = True
        while ch:
            ch = False
            for y in range(self.d):
                for x in range(self.w):
                    if self.g[y][x][0] != 'g':
                        continue
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < self.w and 0 <= ny < self.d and self.g[ny][nx][0] not in 'r':
                            if self.g[y][x][1] - self.g[ny][nx][1] > 1:
                                self.g[y][x][1] = self.g[ny][nx][1] + 1; ch = True
                            elif self.g[ny][nx][1] - self.g[y][x][1] > 1 and self.g[ny][nx][0] == 'g':
                                self.g[y][x][1] = self.g[ny][nx][1] - 1; ch = True

    def passable(self, x, y): return 0 <= x < self.w and 0 <= y < self.d and self.code(x, y) not in 'Wtlv'

    def cost_map(self, start, jump=2):
        dist = {start: 0}; pq = [(0, start)]
        while pq:
            d0, c = heapq.heappop(pq)
            if d0 > dist[c]: continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (c[0] + dx, c[1] + dy)
                if not self.passable(*n): continue
                rise = self.lvl(*n) - self.lvl(*c)
                if rise > 1 or -rise > jump: continue
                nd = d0 + (2 if self.code(*n) == 'w' else 1)
                if nd < dist.get(n, 1 << 30):
                    dist[n] = nd; heapq.heappush(pq, (nd, n))
        return dist

    def trees(self, rnd, zone, p):
        for (x, y) in zone:
            if 0 <= x < self.w and 0 <= y < self.d and self.code(x, y) == 'g' and rnd.random() < p:
                self.g[y][x][0] = 't'


def finish(m, level, spawns, notes):
    for y in range(m.d):                    # the near rows sit under the HUD: no tall trees there, except in the corners
        for x in range(0, 3):
            if m.code(x, y) == 't' and 1 < y < m.d - 2:
                m.g[y][x][0] = 'g'
    for c in [spawns['king'], spawns['captain']] + spawns['stones'] + [e['at'] for e in spawns['enemies']]:
        if m.code(*c) == 't':
            m.g[c[1]][c[0]][0] = 'g'   # a tree never stands on a spawn
    errs = []
    cells = [('king', spawns['king'])] + [('captain', spawns['captain'])] + [('stone', s) for s in spawns['stones']]
    for who, c in cells + [(e['kind'], e['at']) for e in spawns['enemies']]:
        if not m.passable(*c): errs.append('%s at %s is not open ground' % (who, c))
    for who, c in cells:
        for e in spawns['enemies']:
            dist = abs(c[0] - e['at'][0]) + abs(c[1] - e['at'][1])
            if dist <= max(PLAYER_THREAT, THREAT[e['kind']]):
                errs.append('%s %s is within reach of %s %s (%d apart)' % (who, c, e['kind'], e['at'], dist))
    dist = m.cost_map(tuple(spawns['king']))
    worst = 99
    for e in spawns['enemies']:
        best = min((dist.get((e['at'][0] + dx, e['at'][1] + dy), 999) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))), default=999)
        man = abs(spawns['king'][0] - e['at'][0]) + abs(spawns['king'][1] - e['at'][1])
        if best >= 999: errs.append('Alaric cannot reach %s %s' % (e['kind'], e['at']))
        else:
            worst = min(worst, best - (man - 1))
            notes.append('  %s %s: straight %d, walk %d (+%d)' % (e['kind'], e['at'], man - 1, best, best - (man - 1)))
    gains = [int(n.split('(+')[1].rstrip(')')) for n in notes]
    if gains and (sum(gains) / len(gains) < 4 or sum(1 for g in gains if g >= 4) < 3):
        errs.append('the way to the foes is too straight (detours %s)' % gains)
    rows = [' '.join('%s%d' % (m.g[y][x][0], m.g[y][x][1]) for x in range(m.w)) for y in range(m.d)]
    d = {"name": m.name, "tufts": True, "shadows": True, "rows": rows, "spawns": spawns}
    json.dump(d, open(OUT % level, 'w'), indent=1); open(OUT % level, 'a').write("\n")
    print('\nLEVEL %d  %s  (%d x %d)' % (level, m.name, m.w, m.d))
    for y in range(m.d - 1, -1, -1):  # y runs left to right on screen; print the far end (x large) at the top
        pass
    # print with x up the screen: rows are x from far to near, columns are y
    for x in range(m.w - 1, -1, -1):
        line = ''
        for y in range(m.d):
            ch = m.code(x, y)
            for who, c in cells:
                if c == [x, y] or tuple(c) == (x, y): ch = {'king': 'K', 'captain': 'C', 'stone': '*'}[who]
            for e in spawns['enemies']:
                if tuple(e['at']) == (x, y): ch = {'squire': 'S', 'archer': 'A', 'wolf': 'w', 'boss': 'B', 'eater': 'E', 'boar': 'b'}[e['kind']]
            line += ch
        print('%2d %s' % (x, line))
    print('\n'.join(notes))
    if errs:
        print('PROBLEMS:'); print('\n'.join('  ' + e for e in errs))
    return errs


rnd = random.Random(2026)
problems = []

# ============================================================ 1. The Ford  (16 deep x 18 wide)
m = Map(16, 18, "Riverbank 1: The Ford. A river across the field with one plank bridge in the north, a wading ford in the south and a ridge that blocks the straight road; a ruined platform on the far bank")
m.hills([(3, 8, 6, 1.2), (12, 3, 5, 1.0), (13, 15, 5, 1.0)])
m.box(7, 8, 0, 17, 'W', 0)                            # the river
m.box(6, 6, 0, 17, 'w', 0); m.box(9, 9, 0, 17, 'w', 0) # shallow banks
m.box(6, 9, 2, 3, 'b', 0)                             # the plank bridge (2 wide), far to the north
m.box(6, 9, 13, 15, 'w', 0)                           # the ford, far to the south: wading, which slows
m.box(4, 5, 7, 10, 'r', 3); m.box(3, 3, 8, 9, 'r', 2); m.box(6, 6, 7, 9, 'r', 2) # the ridge, a bluff in the way
m.box(11, 14, 6, 11, 's', 2)                          # the ruined platform on the far bank
m.box(10, 10, 7, 10, 's', 1)
m.box(12, 13, 8, 9, 'r', 4)                           # a broken tower stump on it
m.set(13, 5, 'd', 1); m.set(12, 5, 'd', 1); m.box(10, 12, 12, 13, 'd', 0) # worn tracks
for (x, y) in [(2, 3), (2, 4), (1, 4), (5, 1), (4, 1), (5, 2), (4, 15), (5, 16), (5, 15), (2, 14), (1, 13), (10, 1), (11, 2), (10, 2), (10, 16), (11, 16), (14, 2), (14, 15), (13, 0), (13, 17), (11, 3), (14, 4)]:
    m.set(x, y, 't')
for _ in range(14):
    m.trees(rnd, [(x, y) for x in range(3, 16) for y in range(0, 18) if (x >= 14 or y <= 0 or y >= 17)], 0.10)
# Worn paths guide the eye toward the bridge and ford without altering movement rules.
for x, y in [(2, 4), (3, 4), (3, 5), (4, 4), (4, 5), (5, 4), (5, 5), (4, 12), (4, 13), (5, 12), (5, 13), (5, 14), (5, 15), (3, 12), (3, 13), (10, 3), (11, 3), (11, 4), (12, 4), (10, 14), (11, 14), (11, 13), (12, 14), (12, 15)]:
    if m.code(x, y) == 'g':
        m.set(x, y, 'd')
m.settle()
spawns = {"king": [3, 8], "captain": [3, 9], "stones": [[3, 6], [3, 11], [4, 5]],
          "enemies": [{"kind": "squire", "at": [12, 6]}, {"kind": "eater", "at": [12, 11]}, {"kind": "eater", "at": [10, 12]}, {"kind": "boar", "at": [11, 15]}]}
problems += finish(m, 1, spawns, [])

# ============================================================ 2. The Mill Race  (16 deep x 18 wide)
m = Map(16, 18, "Riverbank 2: The Mill Race. A stone mill on an island in a deep moat with two bridges that do not line up, and a high bluff on each flank that can only be climbed from the enemy's side")
m.hills([(2, 9, 7, 0.8)])
m.box(5, 11, 5, 12, 'W', 0)                           # the moat
m.box(6, 10, 6, 11, 's', 2)                           # the island, stone, two levels up
m.box(7, 9, 8, 9, 'r', 5)                             # the mill itself
m.set(8, 8, 's', 3); m.set(8, 9, 's', 3)
m.set(5, 7, 'b', 1); m.set(6, 7, 's', 2)              # the near bridge, a lane to the left of the middle ...
m.set(11, 10, 'b', 1); m.set(10, 10, 's', 2)          # ... and the far one on the right
for (x, y) in [(5, 5), (5, 12), (11, 5), (11, 12)]: m.set(x, y, 'W', 0)
m.box(5, 11, 4, 4, 'w', 0); m.box(5, 11, 13, 13, 'w', 0)  # shallow edges of the moat on the flanks, a wading way round it
for x in range(6, 12):                                 # the left bluff (low y) and the right bluff (high y), three levels up
    for y in range(0, 4): m.set(x, y, 'r', 3)
    for y in range(14, 18): m.set(x, y, 'r', 3)
for y in (3, 14):                                      # a ramp at the far end only of each bluff: the archers can only be reached from the enemy's side
    for x, h in ((12, 2), (13, 1)):
        m.set(x, y, 'd', h)
for x in (12, 13): m.set(x, 4, 'g', 0); m.set(x, 13, 'g', 0)
m.box(13, 15, 5, 12, 'g', 0)
for (x, y) in [(13, 6), (14, 7), (13, 12), (14, 11), (13, 5), (14, 13), (2, 14), (1, 15), (3, 16), (1, 3), (2, 1), (3, 0)]:
    m.set(x, y, 't')
for _ in range(10):
    m.trees(rnd, [(x, y) for x in range(3, 16) for y in range(0, 18) if (x >= 15 or y <= 0 or y >= 17)], 0.10)
m.settle()
spawns = {"king": [3, 9], "captain": [3, 8], "stones": [[3, 11], [3, 7], [4, 9]],
          "enemies": [{"kind": "squire", "at": [13, 7]}, {"kind": "squire", "at": [13, 10]}, {"kind": "archer", "at": [10, 2]}, {"kind": "archer", "at": [10, 15]}, {"kind": "wolf", "at": [14, 8]}]}
problems += finish(m, 2, spawns, [])

# ============================================================ 3. The Broken Bridge  (16 deep x 18 wide)
m = Map(16, 18, "Riverbank 3: The Broken Bridge. A stone bridge with its middle gone over a deep river; the ways round are a wading ford in the west and a narrow ridge in the east, and archers hold the bluff above")
m.hills([(2, 9, 6, 1.0), (13, 9, 5, 2.2)])
m.box(6, 9, 0, 17, 'W', 0)                            # the river
m.box(6, 6, 0, 17, 'w', 0); m.box(9, 9, 0, 17, 'w', 0)
m.box(4, 5, 8, 9, 's', 1); m.box(10, 11, 8, 9, 's', 1)  # the bridge's two stubs
m.box(6, 6, 8, 9, 'b', 1); m.box(9, 9, 8, 9, 'b', 1)    # ... reaching a little way in
m.box(6, 9, 1, 3, 'w', 0)                             # the west ford: wading all the way across
m.box(6, 9, 14, 14, 'r', 3); m.box(4, 5, 14, 14, 'g', 1); m.set(5, 14, 'g', 2); m.set(4, 14, 'g', 1)  # the east ridge, a narrow rock path
m.set(10, 14, 'g', 2); m.set(11, 14, 'g', 1)
m.box(6, 9, 13, 13, 'W', 0); m.box(6, 9, 15, 15, 'W', 0)
m.box(11, 15, 5, 12, 'r', 3); m.box(12, 14, 6, 11, 's', 3) # the bluff the archers hold (stone top)
m.box(11, 11, 6, 7, 'g', 2); m.box(11, 11, 10, 11, 'g', 2)
m.set(10, 12, 'g', 1); m.set(11, 12, 'g', 2); m.set(12, 12, 's', 3)  # a ramp up its south end
m.box(10, 12, 3, 4, 'd', 0); m.box(10, 11, 1, 2, 'g', 0)
for (x, y) in [(2, 3), (3, 3), (2, 14), (3, 15), (1, 5), (1, 12), (4, 1), (4, 16), (12, 2), (13, 1), (12, 15), (13, 16), (14, 3), (14, 14), (10, 0), (10, 17), (5, 11), (5, 6)]:
    m.set(x, y, 't')
for _ in range(10):
    m.trees(rnd, [(x, y) for x in range(3, 16) for y in range(0, 18) if (x >= 15 or y <= 0 or y >= 17)], 0.10)
m.settle()
spawns = {"king": [3, 8], "captain": [3, 9], "stones": [[3, 6], [3, 11], [4, 9]],
          "enemies": [{"kind": "archer", "at": [13, 7]}, {"kind": "archer", "at": [13, 10]}, {"kind": "squire", "at": [12, 3]}, {"kind": "squire", "at": [11, 14]}, {"kind": "wolf", "at": [14, 8]}]}
problems += finish(m, 3, spawns, [])

# ============================================================ 4. The Warden's Hold  (15 x 15)
m = Map(15, 15, "Riverbank 4: The Warden's Hold. The enemy's fortress terrace on the far side behind a moat: a gate far to the west across a bridge, a postern in the east along a hidden track, and the boss on a dais in the hall")
m.hills([(2, 7, 5, 0.9), (9, 11, 3, 0.9)])
m.box(6, 7, 0, 14, 'W', 0)                            # the moat across the whole front
m.box(5, 5, 0, 14, 'w', 0); m.box(8, 8, 0, 14, 'w', 0)  # its shallow banks
m.box(5, 8, 3, 4, 'b', 0)                             # the gate bridge, far to the west
m.box(5, 8, 12, 12, 'b', 0)                           # the hidden plank track, far to the east
m.box(9, 10, 1, 6, 's', 1)                            # the gate court
m.set(10, 3, 's', 2); m.set(10, 4, 's', 2)            # the ramp to the gate
m.box(11, 14, 1, 13, 'r', 6)                          # the fortress's walls ...
m.box(12, 13, 2, 12, 's', 3)                          # ... around the hall floor (three levels up)
m.set(11, 3, 's', 3); m.set(11, 4, 's', 3)            # the gate, open, front wall
m.set(11, 12, 's', 3)                                 # the east postern
m.box(9, 10, 12, 13, 'd', 0); m.set(10, 12, 'd', 1)    # the track up to the postern
m.set(10, 13, 'd', 1)
m.box(13, 13, 6, 8, 's', 4)                           # the dais
m.set(12, 5, 'r', 5); m.set(12, 9, 'r', 5); m.set(13, 3, 'r', 5); m.set(13, 11, 'r', 5)  # pillars: cover in the hall (never closing a lane)
m.box(9, 10, 7, 11, 'g', 0)                           # the lawn outside the front wall
for (x, y) in [(9, 8), (10, 9), (9, 10), (10, 7), (4, 11), (4, 12), (4, 13), (5, 10), (5, 11), (5, 13), (5, 14), (9, 14), (10, 14), (8, 10), (8, 13), (3, 1), (4, 1), (3, 13), (3, 14), (2, 2), (2, 12)]:
    m.set(x, y, 't')
for _ in range(8):
    m.trees(rnd, [(x, y) for x in range(3, 15) for y in range(0, 15) if (y <= 0 or y >= 14) and x < 6], 0.18)
m.settle()
spawns = {"king": [3, 7], "captain": [3, 6], "stones": [[3, 9], [4, 5], [2, 7]],
          "enemies": [{"kind": "boss", "at": [13, 7]}, {"kind": "squire", "at": [12, 6]}, {"kind": "squire", "at": [12, 8]}, {"kind": "archer", "at": [12, 3]}, {"kind": "archer", "at": [12, 11]}, {"kind": "squire", "at": [10, 4]}]}
problems += finish(m, 4, spawns, [])
print('\nTOTAL PROBLEMS:', len(problems))
