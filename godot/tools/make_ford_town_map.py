#!/usr/bin/env python3
"""Writes godot/samples/ford_town.json: the 19x19 town centre of FordCutscene (a story scene, not a battle map). Run from the
repo root: python3 godot/tools/make_ford_town_map.py

Cells are (x, y): x is the depth (up the screen, 0 nearest the camera), y runs left to right. The stage is the paved plaza in the
middle (a carved medallion at (9, 9)); streets of beaten earth leave it west, east, north and south; a fountain stands behind it
and the houses (brick walls with a roof on top and a doorway) line the streets. Trees ring the edge. The same file always comes out."""
import json, random
from collections import deque

N = 19
rnd = random.Random(11)
G = [[['g', 0] for _ in range(N)] for _ in range(N)]  # G[y][x] = [code, level]


def S(x, y, c, h=0):
    if 0 <= x < N and 0 <= y < N:
        G[y][x] = [c, h]


def box(x0, x1, y0, y1, c, h=0):
    for x in range(x0, x1 + 1):
        for y in range(y0, y1 + 1):
            S(x, y, c, h)


# ---- streets (beaten earth) and the plaza (cobbles)
box(8, 10, 0, 18, 'd')            # the east-west street
box(0, 18, 8, 10, 'd')            # the north-south street
box(5, 13, 4, 14, 's')            # the plaza
for (x, y) in [(5, 4), (5, 14), (13, 4), (13, 14)]:   # worn corners of the plaza
    S(x, y, 'd')
box(9, 9, 9, 9, 'e', 0)           # the medallion between Merc and Vesper

# ---- the fountain behind the plaza's centre, where the north street meets it: a marble ring around still water
box(11, 13, 8, 10, 'M', 1)
S(12, 9, 'w', 0)

# ---- houses: brick walls, a roof on top, a doorway on the wall that faces the plaza or a street
def house(x0, x1, y0, y1, wall, roof, door):
    box(x0, x1, y0, y1, 'q', wall)
    box(x0 + 1, x1 - 1, y0 + 1, y1 - 1, roof, wall + 1)
    S(door[0], door[1], 'f', 1)


house(14, 17, 2, 6, 3, 'c', (14, 4))      # back left
house(14, 17, 12, 16, 3, 'd', (14, 14))   # back right
house(11, 13, 0, 2, 3, 'd', (11, 1))      # left of the west street
house(11, 13, 16, 18, 3, 'c', (11, 17))   # right of the east street
house(4, 6, 0, 2, 2, 'c', (4, 1))         # front left, low so the stage stays in view
house(4, 6, 16, 18, 2, 'd', (4, 17))
house(1, 3, 1, 5, 2, 'd', (1, 3))
house(1, 3, 13, 17, 2, 'c', (1, 15))

# ---- trees: a ring round the edge, never on a street, the plaza or a house
solid = set('qMWcdfes')
for y in range(N):
    for x in range(N):
        if G[y][x][0] != 'g':
            continue
        edge = min(x, y, N - 1 - x, N - 1 - y)
        p = 0.5 if edge == 0 else 0.2 if edge == 1 else 0.06
        if x <= 3 or (4 <= x <= 12 and 3 <= y <= 15) or (8 <= y <= 10) or (8 <= x <= 10):
            p = 0.0                              # the front rows sit under the dialogue box; streets and the plaza stay clear
        if rnd.random() < p:
            G[y][x][0] = 't'


def walkable(x, y):
    return G[y][x][0] in 'gdsef' and G[y][x][1] <= 1


def reach(start):
    seen = {start}; q = deque([start])
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + dx, y + dy)
            if 0 <= n[0] < N and 0 <= n[1] < N and n not in seen and walkable(*n) and abs(G[n[1]][n[0]][1] - G[y][x][1]) <= 1:
                seen.add(n); q.append(n)
    return seen


seen = reach((9, 9))
shut = [(x, y) for y in range(N) for x in range(N) if walkable(x, y) and (x, y) not in seen and G[y][x][0] != 'f']
print('unreachable open tiles:', len(shut), shut[:12])
rows = [' '.join('%s%d' % (G[y][x][0], G[y][x][1]) for x in range(N)) for y in range(N)]
d = {"name": "The Ford's town centre, 19x19: a cobbled plaza with a carved medallion, a fountain, houses with roofs and doorways along four earth streets, trees round the edge (a story scene, not a battle map)",
     "tufts": True, "shadows": True, "grade": "golden", "backdrop": "sky", "rows": rows}
json.dump(d, open('godot/samples/ford_town.json', 'w'), indent=1)
open('godot/samples/ford_town.json', 'a').write("\n")
for x in range(N - 1, -1, -1):          # x up the screen, y left to right
    print('%2d ' % x + ''.join(G[y][x][0] for y in range(N)))
