#!/usr/bin/env python3
"""Writes the Riverford maps (chapter two, "The Price of Embers"): godot/samples/riverford_1.json .. riverford_5.json (the five battles)
and riverford_market.json (the market square of the opening scene, not a battle map). Run from the repo root:
    python3 godot/tools/make_riverford_maps.py

Cells are (x, y): x is the depth (up the screen, 0 nearest the camera), y runs left to right and is the long side. The fight runs LEFT TO
RIGHT (owner, Nov 2026). Every map is built here in its final orientation. Depth stays 16 (the HUD covers anything deeper); widths grow to 24
(16 x 24 fits the screen at the fixed camera). Each map has its own tiles, its own levels of height and its own feel:
  1 The Back Alleys     16x22  mud lanes between tall houses, a market cross in the middle, a raised fish market at the far end, a canal in front
  2 The Tangled Paths   16x24  a canal district: stone walkways on two levels, small bridges, a garden terrace, enemies from three sides
  3 The Interception    16x20  a street corner stepping down in terraces to a walled yard; a wooden fence and a service stair
  4 The Final Stand     16x20  a lane of dusk-lit flagstones opening into the courtyard's mouth: broken walls, cover
  5 Vesper's Wrath      16x24  the courtyard: a high stone barrier, the drain mouth in the east, a dais, pillars, reinforcements from the drain
Walls are 4 high and roofs 5 (a wall of 4 stops lines of attack: only 3 levels above a unit are reachable); the rows nearest the camera stay low
so they never hide the fight. Each file carries "spawns". Everyone starts out of reach of everyone (distance above Move + 2), and the checks
below make sure the road to the foes is a detour. Same output every run."""
import json, random, heapq

OUT = 'godot/samples/riverford_%s.json'
MOVE = {'aide': 4, 'alpha': 5, 'priest': 4, 'hound': 6, 'watchman': 4, 'scout': 5, 'squire': 4, 'guard': 3, 'mage': 4, 'vesper': 5, 'slime': 3, 'brute': 4, 'player': 5}
PLAYER = 5


class Map:
    def __init__(self, d, w, name):
        self.d, self.w, self.name = d, w, name     # d: depth (x), w: width (y)
        self.g = [[['s', 0] for _ in range(d)] for _ in range(w)]   # g[y][x] = [code, level]
        self.extra = {}
        self.solid = set()

    def inb(self, x, y): return 0 <= x < self.d and 0 <= y < self.w

    def set(self, x, y, c, h=None):
        if self.inb(x, y):
            self.g[y][x] = [c, self.g[y][x][1] if h is None else h]

    def box(self, x0, x1, y0, y1, c, h=None):
        for x in range(x0, x1 + 1):
            for y in range(y0, y1 + 1):
                self.set(x, y, c, h)

    def code(self, x, y): return self.g[y][x][0]
    def lvl(self, x, y): return self.g[y][x][1]

    def house(self, x0, x1, y0, y1, wall=4, roof='c', door=None):
        """Brick walls with a tiled roof raised on top; a doorway tile on one wall."""
        self.box(x0, x1, y0, y1, 'q', wall)
        if x1 - x0 >= 2 and y1 - y0 >= 2:
            self.box(x0 + 1, x1 - 1, y0 + 1, y1 - 1, roof, wall + 1)
        for x in range(x0, x1 + 1):
            for y in range(y0, y1 + 1):
                self.solid.add((x, y))
        if door:
            self.solid.discard(tuple(door))
            self.set(door[0], door[1], 'f', 1)

    def passable(self, x, y): return self.inb(x, y) and self.code(x, y) not in 'Wtlvq' and (x, y) not in self.solid

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

    def smooth(self, codes='gdm'):
        """Soft ground (grass, dirt, mud) never steps more than one level against a neighbour."""
        ch = True
        while ch:
            ch = False
            for y in range(self.w):
                for x in range(self.d):
                    if self.g[y][x][0] not in codes: continue
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = x + dx, y + dy
                        if self.inb(nx, ny) and self.g[ny][nx][0] in codes and abs(self.g[y][x][1] - self.g[ny][nx][1]) > 1:
                            if self.g[y][x][1] > self.g[ny][nx][1]: self.g[y][x][1] -= 1
                            else: self.g[ny][nx][1] -= 1
                            ch = True

    def rows(self):
        return [' '.join('%s%d' % (self.g[y][x][0], self.g[y][x][1]) for x in range(self.d)) for y in range(self.w)]

    def save(self, key, spawns=None, **extra):
        d = {"name": self.name, "tufts": True, "shadows": True, "rows": self.rows()}
        d.update(self.extra); d.update(extra)
        if spawns: d["spawns"] = spawns
        json.dump(d, open(OUT % key, 'w'), indent=1); open(OUT % key, 'a').write("\n")


def preview(m, spawns, key):
    marks = {}
    if spawns:
        marks[tuple(spawns['king'])] = 'K'; marks[tuple(spawns['captain'])] = 'C'
        for s in spawns['stones']: marks[tuple(s)] = '*'
        for e in spawns['enemies']: marks[tuple(e['at'])] = e['kind'][0].upper()
    print('\n== %s  %s  (%d deep x %d wide)' % (key, m.name[:48], m.d, m.w))
    for x in range(m.d - 1, -1, -1):
        line = ''
        for y in range(m.w):
            ch = marks.get((x, y)) or {'q': '#', 's': ':', 'm': '.', 'd': ',', 'W': '~', 'w': '-', 'b': '=', 't': 'T', 'g': '"', 'c': 'c', 'r': 'r', 'f': 'f', 'h': 'h', 'e': 'e', 'o': 'o', 'M': 'M', 'a': 'a'}.get(m.code(x, y), m.code(x, y))
            line += ch
        print('%2d %s' % (x, line))
    print('   ' + ''.join(str(m.lvl(x, y)) if False else ' ' for y in range(0)))


def check(m, spawns, key):
    errs = []
    notes = []
    mine = [('king', spawns['king'], MOVE['player']), ('captain', spawns['captain'], MOVE['player'])] + [('stone', s, MOVE['player']) for s in spawns['stones']]
    for who, c, mv in mine + [(e['kind'], e['at'], MOVE[e['kind']]) for e in spawns['enemies']]:
        if not m.passable(*c): errs.append('%s at %s is not open ground' % (who, c))
    for who, c, mv in mine:
        for e in spawns['enemies']:
            dist = abs(c[0] - e['at'][0]) + abs(c[1] - e['at'][1])
            if dist <= max(mv, MOVE[e['kind']]) + 2:
                errs.append('%s %s is within reach of %s %s (%d apart)' % (who, c, e['kind'], e['at'], dist))
    dist = m.cost_map(tuple(spawns['king']))
    gains = []
    for e in spawns['enemies']:
        best = min((dist.get((e['at'][0] + dx, e['at'][1] + dy), 999) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))), default=999)
        man = abs(spawns['king'][0] - e['at'][0]) + abs(spawns['king'][1] - e['at'][1])
        if best >= 999: errs.append('Alaric cannot reach %s %s' % (e['kind'], e['at']))
        else: gains.append(best - (man - 1))
    if gains and sum(gains) / len(gains) < 2.5:
        errs.append('the way to the foes is too straight (detours %s)' % gains)
    notes.append('detours: %s' % gains)
    heights = sorted({m.lvl(x, y) for x in range(m.d) for y in range(m.w)})
    codes = sorted({m.code(x, y) for x in range(m.d) for y in range(m.w)})
    notes.append('heights %s  tiles %s' % (heights, ''.join(codes)))
    print('\n'.join(notes))
    if errs: print('PROBLEMS:\n' + '\n'.join('  ' + e for e in errs))
    return errs


def finish(m, spawns, key, **extra):
    for c in [spawns['king'], spawns['captain']] + spawns['stones'] + [e['at'] for e in spawns['enemies']]:
        if m.code(*c) == 't':
            m.set(c[0], c[1], 'g')
    m.save(key, spawns, **extra)
    preview(m, spawns, key)
    return check(m, spawns, key)


rnd = random.Random(1105)
problems = []

# ================================================================== 1. The Back Alleys  (16 x 22)  player left
m = Map(16, 22, "Riverford 1: The Back Alleys. Mud lanes between tall houses behind the market, a crossing in the middle where the rot-hounds pour in, a raised fish market at the far end and a canal along the front")
m.box(0, 15, 0, 21, 'm', 0)
# the canal along the front, three plank bridges, and a dirt towpath behind it
m.box(0, 0, 0, 21, 'w', 0); m.box(1, 1, 0, 21, 'd', 0)
for y in (3, 11, 19): m.set(0, y, 'b', 0)
# the central alley (x 4..8) runs the whole way; the cross lane (y 9..12) joins it to the back streets
m.box(4, 8, 0, 21, 'm', 0)
m.box(2, 3, 0, 21, 's', 0)                       # a cobbled strip along the front houses' doors
m.box(9, 14, 9, 12, 'd', 0)                     # the cross lane north
m.box(1, 3, 9, 12, 'd', 0)                      # ... and south, to the towpath
# houses: tall blocks at the back, low stalls along the front
m.house(10, 15, 0, 7, 4, 'c', (10, 4)); m.house(10, 15, 14, 21, 4, 'd', (10, 17))
m.house(9, 9, 0, 3, 4); m.house(9, 9, 5, 6, 4)
m.house(2, 3, 1, 4, 2, 'd'); m.house(2, 3, 14, 17, 2, 'c'); m.house(2, 3, 19, 21, 2, 'd')   # low stalls in front, never hiding the lane
for (x, y) in [(6, 5), (7, 6), (5, 15), (6, 15), (7, 17), (8, 17), (4, 14), (8, 14), (5, 6)]: m.set(x, y, 'q', 2)           # crates, barrels and a handcart as cover and to zig-zag the lane
for (x, y) in [(4, 15), (4, 16), (8, 15), (8, 16), (6, 14), (7, 10)]: m.set(x, y, 'q', 2)
m.box(4, 7, 6, 6, 'q', 2); m.box(4, 7, 8, 8, 'q', 2); m.set(5, 7, 'q', 2); m.set(4, 7, 'q', 2)   # a cart barricade across the alley with a gap at its far side
m.box(5, 6, 9, 12, 's', 0)                      # the cobbled crossing
# the raised fish market at the east end: a platform two levels up, steps in the middle
m.box(4, 9, 17, 21, 's', 2); m.box(5, 8, 16, 16, 's', 1); m.box(5, 8, 15, 15, 's', 1)
m.box(4, 4, 17, 21, 'q', 3)
for (x, y) in [(2, 8), (3, 8), (12, 0), (13, 8)]: m.set(x, y, 't', 0)
m.smooth()
spawns = {"king": [6, 1], "captain": [7, 1], "stones": [[5, 0], [8, 2], [4, 3]],
          "enemies": [{"kind": "hound", "at": [5, 13]}, {"kind": "hound", "at": [7, 14]}, {"kind": "hound", "at": [3, 13]}, {"kind": "alpha", "at": [6, 19]}, {"kind": "slime", "at": [7, 19]}]}
problems += finish(m, spawns, 1, haze="heavy")

# ================================================================== 2. The Tangled Paths  (16 x 24)  player left
m = Map(16, 24, "Riverford 2: The Tangled Paths. A canal district: cobbled walkways on two levels, plank bridges over narrow canals, a walled garden terrace, and watchmen closing in from three sides")
m.box(0, 15, 0, 23, 's', 0)
# two canals run front to back, the main one across the middle: shallow banks, deep middle
m.box(0, 15, 8, 9, 'W', 0); m.box(0, 15, 7, 7, 'w', 0); m.box(0, 15, 10, 10, 'w', 0)
m.box(0, 15, 16, 16, 'w', 0); m.box(0, 15, 17, 17, 'W', 0); m.box(0, 15, 18, 18, 'w', 0)
for x0 in (3, 11): m.box(x0, x0 + 1, 7, 10, 'b', 0)             # two bridges over the main canal
m.box(7, 8, 16, 18, 'b', 0)                                         # one over the east canal, in the middle
# an upper walkway on the north (back) side, two levels up, with steps at both ends
m.box(12, 15, 0, 23, 's', 2); m.box(11, 11, 3, 5, 's', 1); m.box(11, 11, 19, 21, 's', 1)
m.box(12, 15, 7, 10, 'W', 0); m.box(12, 15, 16, 18, 'W', 0)       # the canals cut through it: bridges at the top
m.box(12, 13, 7, 10, 'b', 2); m.box(12, 13, 16, 18, 'b', 2)
# a walled garden terrace in the west, a level up
m.box(2, 6, 1, 5, 'h', 1); m.box(2, 2, 1, 5, 'q', 2); m.box(2, 6, 5, 5, 'q', 2); m.set(4, 5, 'h', 1)
m.box(3, 5, 2, 4, 'g', 1); m.set(4, 3, 't', 1)
# houses and a mill house on the island between the canals
m.house(3, 6, 11, 14, 4, 'c', (6, 12)); m.house(8, 11, 11, 15, 4, 'd', (8, 13))
m.house(1, 3, 19, 22, 3, 'c'); m.house(5, 8, 20, 23, 4, 'd', (5, 21))
for (x, y) in [(8, 4), (9, 5), (6, 7), (10, 13), (4, 15), (9, 20), (10, 3), (6, 19)]: m.set(x, y, 'q', 2)   # cover
for (x, y) in [(10, 1), (9, 2), (13, 22), (12, 21)]: m.set(x, y, 't')
m.smooth('gdhm')
spawns = {"king": [5, 1], "captain": [6, 2], "stones": [[8, 1], [3, 0], [7, 3]],
          "enemies": [{"kind": "watchman", "at": [7, 12]}, {"kind": "watchman", "at": [7, 15]}, {"kind": "scout", "at": [13, 6]}, {"kind": "scout", "at": [13, 20]},
                      {"kind": "brute", "at": [9, 21]}, {"kind": "watchman", "at": [4, 20]}]}
problems += finish(m, spawns, 2, haze="light")

# ================================================================== 3. The Interception  (16 x 20)  player left, high ground
m = Map(16, 20, "Riverford 3: The Interception. A street corner on high ground steps down in terraces to a walled yard; a wooden fence, a service stair and a dead-end brick wall where Merc was cornered")
m.box(0, 15, 0, 19, 's', 0)
for y in range(0, 10):                                  # the terraces: street (4), then 3, 2, 1, and the yard (0), one step each
    lv = max(0, 4 - max(0, (y - 1)) // 2)
    for x in range(16):
        m.g[y][x] = ['d' if y <= 3 else 's', lv]
m.house(11, 15, 0, 4, 7, 'c', (11, 2))                  # the corner house at the back of the street
# the stair is wide in the middle (x 3..9); on both flanks a parapet blocks the terraces
for y in range(4, 10):
    for x in list(range(0, 3)) + list(range(10, 11)):
        m.set(x, y, 'q', m.lvl(x, y) + 2)
for y in range(0, 4): m.set(0, y, 'q', 6); m.set(1, y, 'q', 5)
m.box(11, 15, 5, 9, 's', 0); m.box(11, 15, 5, 9, 'q', 3)       # a stone block (a store) behind the yard's west end
m.box(12, 14, 6, 8, 'c', 4)
for x in range(16): m.set(x, 19, 'q', 4)                # the dead-end brick wall
m.box(3, 9, 14, 14, 'b', 0)                                # the fence: a gap at its east end, none in the middle
m.box(3, 9, 11, 11, 'q', 2); m.box(9, 9, 11, 13, 'q', 2)  # a stack of crates in front of it, so the yard is entered round one end
m.box(0, 2, 10, 18, 's', 0)
m.house(0, 2, 15, 18, 3, 'd', (2, 16))                    # a low outbuilding in front (west end): its doorway is the service stair Merc escapes by
m.house(13, 15, 13, 18, 5, 'd', (13, 15))    # Vesper steps out of its door
for (x, y) in [(11, 14), (12, 14), (4, 16), (10, 17), (3, 17), (11, 12)]: m.set(x, y, 'q', 2)      # barrels and crates
for (x, y) in [(13, 10), (14, 11), (1, 11), (12, 11)]: m.set(x, y, 't', 0)
spawns = {"king": [7, 1], "captain": [8, 2], "stones": [[5, 0], [9, 3], [10, 1]],
          "enemies": [{"kind": "squire", "at": [6, 16]}, {"kind": "squire", "at": [8, 16]}, {"kind": "squire", "at": [5, 18]}, {"kind": "squire", "at": [9, 18]}, {"kind": "aide", "at": [7, 14]}]}
problems += finish(m, spawns, 3, haze="light")

# ================================================================== 4. The Final Stand  (16 x 20)  player right, dusk
m = Map(16, 20, "Riverford 4: The Final Stand. Dusk in a flagstone lane that opens into the courtyard's mouth: staggered broken walls to fight round, a ruined arch and a carved dais, the high barrier waiting at the far end")
m.box(0, 15, 0, 19, 'f', 0)
for _ in range(80):
    m.set(rnd.randrange(16), rnd.randrange(20), 'h')
for x in range(16): m.set(x, 0, 'q', 5)                  # the high barrier at the west end
m.box(15, 15, 0, 19, 'q', 5); m.box(0, 0, 1, 19, 'q', 2)  # the back wall and a low front kerb
# the lane (y 12..19): walls above and below it, a broken wall across it each side of the middle, so the way winds
m.box(11, 14, 12, 19, 'q', 5); m.box(1, 4, 12, 19, 'q', 3)
m.box(5, 8, 16, 16, 'q', 3); m.box(7, 10, 13, 13, 'q', 3)
m.set(6, 16, 'f', 1); m.set(9, 13, 'h', 1)                # a step in each, so the walls look broken
for (x, y) in [(10, 18), (5, 14), (8, 14)]: m.set(x, y, 'q', 1)   # rubble in the lane
# the yard (y 1..11): a carved dais, a ruined arch, fallen masonry and broken wall stubs that cut lines
m.box(5, 10, 2, 5, 'o', 1); m.box(6, 9, 3, 4, 'e', 2)
for (x0, x1, y0, y1, hh) in [(1, 8, 10, 10, 3), (5, 14, 7, 7, 3), (12, 14, 4, 4, 3), (2, 3, 2, 2, 2), (7, 8, 9, 9, 4), (10, 11, 9, 9, 2)]:
    m.box(x0, x1, y0, y1, 'q', hh)
for (x, y) in [(2, 5), (11, 3), (4, 9), (9, 11), (13, 11), (6, 7), (12, 6)]: m.set(x, y, 'q', 1)
for (x, y) in [(13, 2), (14, 10), (2, 11)]: m.set(x, y, 't')
spawns = {"king": [7, 18], "captain": [9, 18], "stones": [[6, 19], [9, 19], [5, 17]],
          "enemies": [{"kind": "squire", "at": [4, 4]}, {"kind": "squire", "at": [10, 5]}, {"kind": "scout", "at": [8, 2]}, {"kind": "squire", "at": [12, 9]}, {"kind": "squire", "at": [3, 5]}, {"kind": "aide", "at": [7, 5]}]}
problems += finish(m, spawns, 4, grade="dusk", haze="heavy")

# ================================================================== 5. Vesper's Wrath  (16 x 24)  player left, dusk
m = Map(16, 24, "Riverford 5: Vesper's Wrath. The courtyard at dusk: a high stone barrier across the middle with a gate each side, a raised dais where Vesper stands, pillars for cover, and the drain mouth in the east where reinforcements come from")
m.box(0, 15, 0, 23, 'f', 0)
for _ in range(110):
    m.set(rnd.randrange(16), rnd.randrange(24), 'h')
# the outer walls (north and the east end), the low front kerb
m.box(15, 15, 0, 23, 'q', 5); m.box(0, 15, 23, 23, 'q', 5); m.box(0, 0, 0, 23, 'f', 0)
# the west half: where the party arrives, a stepped approach
m.box(2, 13, 0, 2, 'f', 0); m.box(3, 12, 3, 4, 'f', 1)
# the high barrier across the middle (y 10..11), a gate each side (x 3..4 and x 11..12), a low wall piece in front
m.box(0, 15, 10, 11, 'q', 4)
m.box(3, 4, 10, 11, 'f', 0); m.box(11, 12, 10, 11, 'f', 0)
m.box(7, 8, 8, 8, 'q', 2)
# the east half: dais with the carved medallion, pillars, the drain
m.box(5, 10, 15, 19, 'o', 1); m.box(6, 9, 16, 18, 'e', 2); m.box(7, 8, 17, 17, 'e', 3)
for (x, y) in [(3, 14), (12, 14), (3, 20), (12, 20), (2, 17), (13, 17)]: m.box(x, x, y, y, 'q', 4)   # pillars
m.box(14, 14, 20, 22, 'q', 3)
# the drain: a sunken channel with grates (cinder) leading to a dark mouth in the east wall, deep water at the bottom
m.box(0, 15, 21, 22, 'c', 0); m.box(6, 9, 21, 22, 'w', 0); m.box(7, 8, 22, 22, 'W', 0)
m.box(0, 15, 12, 13, 'h', 0)
for (x, y) in [(5, 6), (10, 6), (13, 5), (2, 7), (9, 13), (5, 13), (12, 8), (11, 4)]: m.set(x, y, 'q', 1)
for (x, y) in [(1, 21), (14, 12)]: m.set(x, y, 't')
spawns = {"king": [6, 1], "captain": [7, 1], "stones": [[5, 0], [8, 0], [4, 2]],
          "enemies": [{"kind": "guard", "at": [4, 14]}, {"kind": "guard", "at": [10, 14]}, {"kind": "mage", "at": [7, 13]}, {"kind": "priest", "at": [8, 13]},
                      {"kind": "guard", "at": [9, 15]}, {"kind": "vesper", "at": [7, 18]}],
          "waves": [{"round": 3, "banner": "Reinforcements pour out of the drain!", "line": ["vesper", "Vesper", "Again! Everything we have, from the drain, now!"],
                     "enemies": [{"kind": "guard", "at": [6, 21]}, {"kind": "mage", "at": [9, 22]}]},
                    {"round": 6, "banner": "A last wave: the drain mouth rumbles.", "line": [],
                     "enemies": [{"kind": "guard", "at": [8, 21]}, {"kind": "mage", "at": [7, 22]}, {"kind": "slime", "at": [10, 21]}]}]}
problems += finish(m, spawns, 5, grade="dusk", haze="heavy")

# ================================================================== the market square (the opening scene's stage, 19 x 19, not a battle map)
N = 19
mk = Map(N, N, "Riverford market square at dawn: a paved square with a weathered fountain and stalls, frost on the cobbles")
mk.box(0, N - 1, 0, N - 1, 's', 0)
mk.box(0, N - 1, 0, N - 1, 'g', 0)
mk.box(0, N - 1, 7, 11, 'd', 0); mk.box(7, 11, 0, N - 1, 'd', 0)                # the crossing streets, beaten earth
mk.box(4, 14, 4, 14, 's', 0)                                                   # the square
mk.box(8, 10, 8, 10, 'M', 1); mk.set(9, 9, 'w', 0)                             # the fountain
mk.box(4, 14, 4, 4, 'd', 0); mk.box(4, 14, 14, 14, 'd', 0)
for (x0, x1, y0, y1) in [(1, 3, 1, 5), (1, 3, 13, 17), (15, 17, 1, 5), (15, 17, 13, 17), (13, 15, 0, 2), (13, 15, 16, 18)]:
    mk.house(x0, x1, y0, y1, 3, 'c' if (x0 + y0) % 2 else 'd', (x1 if x0 < 8 else x0, (y0 + y1) // 2))
for (x, y) in [(5, 3), (6, 3), (12, 3), (11, 3), (5, 15), (6, 15), (12, 15), (13, 15)]:   # stalls: plank tops on low walls
    mk.set(x, y, 'b', 1)
for (x, y) in [(0, 8), (0, 10), (18, 8), (18, 10), (8, 0), (10, 0), (8, 18), (10, 18), (4, 6), (14, 12)]: mk.set(x, y, 't')
mk.extra = {"grade": "natural", "haze": "light"}
mk.save('market')
preview(mk, None, 'market')
print('\nTOTAL PROBLEMS:', len(problems))
