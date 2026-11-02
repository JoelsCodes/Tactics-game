#!/usr/bin/env python3
"""Writes godot/samples/base.json: the 30x30 base. Run: python3 godot/tools/make_base_map.py

Cells are (x, y): x is the depth (up the screen, 0 nearest the camera), y runs left to right. Zones, from the gate in:
  the gate court (x 0..7)        gate towers, a ruined plaza with a medallion, fallen walls, lawns
  the river (x 9..10)            with a lake in the far-left corner and one wide bridge
  the road (x 7..22, y 14..16)   a stone road lined with a broken colonnade
  the pond grove (left)          a pond, hills, a rocky outcrop in the corner
  the tower court (right)        moss-grown flagstones around a keep tower, broken walls, a garden of trees
  the altar hall (x 22..29)      pillars, a carved aisle, a dais and the altar block at the back wall
Trees are scattered with a fixed seed, then every pocket the walker could not reach from the gate is opened up
(trees removed), so nothing is walled off. The same file always comes out."""
import json, random
from collections import deque

N = 30
rnd = random.Random(7)
G = [[['g', 0] for _ in range(N)] for _ in range(N)]  # G[y][x] = [code, level]


def S(x, y, c, h=None):
    if 0 <= x < N and 0 <= y < N:
        G[y][x] = [c, G[y][x][1] if h is None else h]


def box(x0, x1, y0, y1, c, h=None):
    for x in range(x0, x1 + 1):
        for y in range(y0, y1 + 1):
            S(x, y, c, h)


def bump(cx, cy, r, amp):
    return lambda x, y: max(0.0, amp * (1 - ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5 / r))


# ---- hills: smooth grass height field (levels 0..3)
bumps = [bump(15, 4, 8, 2.4), bump(26, 3, 7, 3.2), bump(25, 27, 6, 2.0), bump(15, 26, 6, 1.6), bump(5, 3, 6, 1.4), bump(4, 26, 6, 1.4), bump(18, 11, 4, 1.0)]
for y in range(N):
    for x in range(N):
        G[y][x][1] = int(round(sum(b(x, y) for b in bumps)))
# ---- the river (x 9..10) and a lake in the left corner
for y in range(N):
    S(9, y, 'w', 0)
    S(10, y, 'W' if (y < 12 or y > 18) else 'w', 0)
for x in range(7, 15):
    for y in range(0, 7):
        if (x - 10.5) ** 2 / 14 + (y - 2.5) ** 2 / 10 < 1.0:
            S(x, y, 'W' if (x - 10.5) ** 2 / 9 + (y - 2.5) ** 2 / 5 < 1.0 else 'w', 0)
for y in range(13, 18):  # the bridge
    S(9, y, 'b', 0); S(10, y, 'b', 0)
# ---- rocky outcrop in the far-left corner, with a high peak
for x in range(22, 30):
    for y in range(0, 6):
        d = ((x - 27) ** 2 + (y - 1.5) ** 2) ** 0.5
        if d < 4.6:
            S(x, y, 'r', max(1, int(round(3.6 - d * 0.6))))
# ---- the pond grove
cx, cy = 17, 6
for dx in range(-3, 4):
    for dy in range(-3, 4):
        d = (dx * dx + dy * dy) ** 0.5
        if d <= 1.2:
            S(cx + dx, cy + dy, 'W', 0)
        elif d <= 2.3:
            S(cx + dx, cy + dy, 'w', 0)
# ---- the stone road from the plaza to the hall, bridge in the middle
for x in range(5, 22):
    if x in (9, 10):
        continue
    for y in range(14, 17):
        S(x, y, 's', 0)
# ---- the gate court
box(0, 4, 13, 17, 'f', 1)                # the gate floor
for (y0, y1) in ((9, 12), (18, 21)):      # the gate towers
    box(0, 2, y0, y1, 'q', 4)
    S(0, y0, 'q', 3); S(1, y0, 'q', 5); S(0, y1, 'q', 3); S(2, y1, 'q', 5)
    S(1, y0 if y0 == 18 else y1, 'q', 6) if False else None
S(0, 8, 'q', 2); S(1, 8, 'q', 1); S(0, 22, 'q', 1); S(1, 22, 'q', 2)   # fallen wall pieces
for y in list(range(2, 8)) + list(range(23, 28)):                       # a broken outer wall along the near edge
    if rnd.random() < 0.55:
        S(0, y, 'q', rnd.choice([1, 2, 3]))
box(5, 8, 12, 18, 'f', 1)                # the plaza
box(5, 8, 12, 18, 'f', 1)
S(6, 14, 'e', 1); S(6, 15, 'e', 1); S(6, 16, 'e', 1); S(7, 15, 'e', 1); S(5, 15, 'e', 1)
for p in [(5, 12), (8, 12), (5, 18), (8, 18), (7, 13), (6, 17)]:
    S(p[0], p[1], 'h', 1)
for p in [(5, 11), (8, 11), (5, 19), (8, 19)]:      # broken plaza pillars
    S(p[0], p[1], 'q', 3)
S(5, 13, 'q', 2); S(8, 17, 'q', 2)
# ---- the colonnade along the road
for x in (12, 15, 18):
    for y in (12, 18):
        S(x, y, 'q', 4)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if rnd.random() < 0.5:
                S(x + dx, y + dy, 'h', 1)
S(13, 12, 'q', 2); S(16, 18, 'q', 1); S(19, 12, 'q', 3)
# ---- the tower court (right)
box(12, 19, 21, 28, 'h', 1)
box(14, 15, 24, 25, 'q', 6); S(14, 24, 'q', 5); S(15, 25, 'q', 5)
for x in range(12, 20):
    S(x, 28, 'q', rnd.choice([2, 3, 4]))
for y in range(21, 28):
    S(12, y, 'q', rnd.choice([1, 2, 3])) if rnd.random() < 0.6 else None
S(12, 24, 'f', 1); S(12, 25, 'f', 1)   # a gap in the court wall
box(16, 18, 22, 23, 'f', 1); S(17, 22, 'e', 1); S(17, 23, 'e', 1)
# ---- the garden orchard (right, near the hall): low walls and a grove
box(22, 27, 24, 28, 'g', 1)
for x in range(22, 28):
    S(x, 23, 'q', rnd.choice([1, 2])) if x not in (24, 25) else None
for y in range(24, 29):
    S(21, y, 'q', rnd.choice([1, 2])) if y not in (26, 27) else None
# ---- the altar hall (x 22..29, y 8..22)
box(23, 28, 9, 21, 'f', 1)
for y in range(8, 23):
    S(29, y, 'q', rnd.choice([5, 6]))
for x in range(22, 29):                               # side walls, ruined
    S(x, 8, 'q', rnd.choice([3, 4, 5]) if x % 3 else rnd.choice([2, 3]))
    S(x, 22, 'q', rnd.choice([3, 4, 5]) if x % 3 else rnd.choice([2, 3]))
for y in (9, 13, 17, 21):                             # the front: pillars with wide openings
    S(22, y, 'q', 4)
for y in (10, 11, 12, 14, 15, 16, 18, 19, 20):
    S(22, y, 'f', 1)
for p in [(24, 10), (24, 20), (26, 10), (26, 20), (24, 12), (24, 18)]:
    S(p[0], p[1], 'q', 4)
box(23, 27, 14, 16, 'e', 1)                           # the carved aisle
for p in [(25, 12), (26, 18), (23, 19), (27, 11), (24, 15)]:
    S(p[0], p[1], 'h', 1)
S(25, 20, 'g', 1); S(27, 9, 'g', 1)                   # the wild pushing in
box(26, 28, 13, 17, 'o', 2); S(28, 15, 'e', 3)         # the dais and the altar block
# ---- a ruined chapel / lookout on the left hills
box(21, 24, 8, 8, 'q', 2)
# ---- flowery lawns are the grass; trees: scatter with a fixed seed, never on paths or structures
solid = set('qfhesobwWr')
tree_zones = []
for y in range(N):
    for x in range(N):
        c, h = G[y][x]
        if c != 'g':
            continue
        edge = min(x, y, N - 1 - x, N - 1 - y)
        near_road = 13 <= y <= 17 and x < 23
        p = 0.16 if edge <= 2 else 0.07
        if near_road:
            p = 0.0
        if rnd.random() < p:
            tree_zones.append((x, y))
for (x, y) in tree_zones:
    G[y][x][0] = 't'
# ---- smooth: no step of more than one level between open tiles (grass and rock heights adjust)
def adjust():
    changed = True
    while changed:
        changed = False
        for y in range(N):
            for x in range(N):
                c, h = G[y][x]
                if c in 'gtr':
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < N and 0 <= ny < N and G[ny][nx][0] not in 'q':
                            nh = G[ny][nx][1]
                            if h - nh > 1 and G[ny][nx][0] in 'gtr':
                                G[y][x][1] = nh + 1; changed = True
                            elif h - nh > 1:
                                G[y][x][1] = nh + 1; changed = True
adjust()
for y in range(N):                    # water and bridge stay level 0, roads level 0
    for x in range(N):
        if G[y][x][0] in 'wWbs':
            G[y][x][1] = 0
adjust()


def is_open(x, y):
    return G[y][x][0] not in 'qvWt' and (x, y) != (28, 15)


def reach(start):
    seen = {start}; q = deque([start])
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + dx, y + dy)
            if 0 <= n[0] < N and 0 <= n[1] < N and n not in seen and is_open(*n) and abs(G[n[1]][n[0]][1] - G[y][x][1]) <= 1:
                seen.add(n); q.append(n)
    return seen


START = (5, 15)
for _ in range(40):  # open any walled-off pocket: remove the trees (then low walls) next to it
    seen = reach(START)
    shut = [(x, y) for y in range(N) for x in range(N) if is_open(x, y) and (x, y) not in seen]
    if not shut:
        break
    for (x, y) in shut:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < N and 0 <= ny < N and G[ny][nx][0] == 't':
                G[ny][nx][0] = 'g'
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < N and 0 <= ny < N and G[ny][nx][0] == 'q' and G[ny][nx][1] <= 3:
                G[ny][nx][0] = 'h'; G[ny][nx][1] = 1
                break
    adjust()
seen = reach(START)
shut = [(x, y) for y in range(N) for x in range(N) if is_open(x, y) and (x, y) not in seen]
print('unreachable open tiles:', len(shut), shut[:20])
rows = [' '.join('%s%d' % (G[y][x][0], G[y][x][1]) for x in range(N)) for y in range(N)]
d = {"name": "The Hollow Base, 30x30: a gate court and plaza, a river and a lake, a stone road with a broken colonnade, a pond grove, a rocky corner, a moss-grown tower court, an orchard and the altar hall, the wild growing through the ruins (free-roam, not a battle map)",
     "tufts": True, "shadows": True, "grade": "golden", "god_rays": True, "backdrop": "sky", "rows": rows}
json.dump(d, open('godot/samples/base.json', 'w'), indent=1)
open('godot/samples/base.json', 'a').write("\n")
for y in range(N):
    print('%2d ' % y + ''.join(G[y][x][0] for x in range(N)))
