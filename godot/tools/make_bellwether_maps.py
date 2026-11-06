#!/usr/bin/env python3
"""Writes chapter five's maps: godot/samples/bellwether_1.json .. bellwether_5.json (the battles) and bellwether_town.json (the festival square, a scene stage).
Run from the repo root: python3 godot/tools/make_bellwether_maps.py   Same kit as make_crucible_maps.py; the fight runs left to right.
  1 The Roadside Ambush     16x22  a caravan road through grass and trees: overturned wagons, a rise, boulders
  2 The Missing Children    16x24  the quarry's outer ledges: terraces of crag rock, a cart track, a watch hut at the far end
  3 The Old Mine            16x24  tunnels and caverns cut in rock, winding, with pillars and a guardian's cavern at the end
  4 The Empty Battlefield   16x18  a collapsed gallery: heaps of fallen rock, one gap through the cave-in
  5 The Choice to Stay      16x24  Bellwether's edge: houses, fences and stalls, and the broken ground where the tunnel breaks out
"""
import random
src = open('godot/tools/make_riverford_maps.py').read()
exec(src[:src.index("rnd = random.Random")])   # Map, preview, check, finish
exec(open('godot/tools/life_kit.py').read())   # decorate()
OUT = 'godot/samples/bellwether_%s.json'
MOVE.update({'wolf': 6, 'alpha': 6, 'slime': 3, 'raider': 5, 'raider_brute': 4, 'scavenger': 5, 'crawler': 4, 'eater': 3, 'cave_boar': 5, 'fused': 4, 'guardian': 3, 'titan': 3})
rnd = random.Random(1108)
problems = []

# ================================================================== 1. The Roadside Ambush (16 x 22)  player left
m = Map(16, 22, "Bellwether 1: The Roadside Ambush. A caravan road through grass and old trees: overturned wagons across the road, a low rise, boulders, and creatures and raiders closing on the caravan")
m.box(0, 15, 0, 21, 'g', 0)
m.box(5, 9, 0, 21, 'd', 0)                                                    # the road
for (x0, x1, y0, y1) in [(0, 3, 4, 7), (11, 14, 3, 8), (12, 14, 12, 20), (0, 2, 13, 17), (10, 13, 9, 10), (0, 3, 19, 21), (14, 15, 0, 21)]:
    m.box(x0, x1, y0, y1, 't', 0)                                             # trees close the road in
m.box(10, 13, 11, 14, 'g', 1); m.box(11, 12, 12, 13, 'g', 2)                  # a low rise beside the road
m.box(6, 8, 10, 11, 'q', 1); m.box(5, 6, 13, 13, 'q', 1); m.box(8, 9, 15, 16, 'q', 1)   # the caravan's overturned wagons
for (x, y) in [(3, 9), (4, 12), (10, 16), (3, 15), (11, 6), (2, 11)]: m.box(x, x, y, y, 'q', 2)   # boulders
m.box(0, 1, 9, 11, 'w', 0); m.box(2, 3, 9, 11, 'g', 0)                       # a trickle of stream
m.box(0, 7, 8, 8, 'q', 2); m.box(7, 13, 15, 15, 'q', 2)                       # old field walls, a gap at the end of each
m.smooth()
spawns = {"king": [6, 2], "captain": [8, 2], "stones": [[4, 1], [10, 1], [7, 4]],
          "enemies": [{"kind": "wolf", "at": [4, 13]}, {"kind": "wolf", "at": [9, 14]}, {"kind": "raider", "at": [6, 16]}, {"kind": "raider", "at": [8, 17]},
                      {"kind": "slime", "at": [11, 16]}, {"kind": "scavenger", "at": [5, 19]}, {"kind": "raider_brute", "at": [7, 19]}]}
decorate(m, spawns, 'b1', random.Random(1301))
problems += finish(m, spawns, 1, grade="forest", haze="light")

# ================================================================== 2. The Missing Children (16 x 24)  player left
m = Map(16, 24, "Bellwether 2: The Missing Children. The old quarry's outer ledges: terraces of crag rock, a cart track climbing between them, and a watch hut at the far end")
m.box(0, 15, 0, 23, 'd', 0)
m.box(0, 15, 0, 3, 'g', 0)
for y in range(24): m.set(15, y, 'r', 5); m.set(14, y, 'r', 4)                 # the quarry wall behind
m.box(8, 13, 6, 10, 'r', 1); m.box(9, 13, 7, 9, 'r', 2)                       # the first terrace
m.box(2, 6, 11, 15, 'r', 1); m.box(3, 5, 12, 14, 'r', 2)                      # the second, on the other side
m.box(7, 13, 16, 22, 'r', 2); m.box(9, 13, 17, 21, 'r', 3)                    # the high ledge under the quarry wall
m.box(6, 6, 17, 19, 'r', 1); m.box(7, 7, 12, 12, 'r', 1)                      # steps up
m.box(1, 4, 19, 22, 'q', 3); m.box(2, 3, 20, 21, 'f', 3)                      # the watch hut (a ruin: its roof gone)
for (x, y) in [(4, 7), (10, 12), (3, 17), (12, 5), (6, 9), (5, 21)]: m.box(x, x, y, y, 'r', 2)  # fallen blocks
m.box(0, 9, 11, 11, 'q', 3); m.box(6, 13, 17, 17, 'q', 3)                  # quarry fences and cut-stone walls, a gap at the end of each
spawns = {"king": [6, 2], "captain": [8, 2], "stones": [[4, 1], [10, 1], [7, 4]],
          "enemies": [{"kind": "crawler", "at": [9, 13]}, {"kind": "scavenger", "at": [4, 10]}, {"kind": "cave_boar", "at": [10, 15]}, {"kind": "eater", "at": [5, 16]},
                      {"kind": "wolf", "at": [11, 19]}, {"kind": "crawler", "at": [7, 20]}, {"kind": "alpha", "at": [8, 22]}]}
decorate(m, spawns, 'b2', random.Random(1302))
problems += finish(m, spawns, 2, grade="slate", haze="light")

# ================================================================== 3. The Old Mine (16 x 24)  player left
m = Map(16, 24, "Bellwether 3: The Old Mine. Tunnels and caverns cut in the rock, winding, held up by old timbers and stone pillars; a guardian waits in the last cavern")
m.box(0, 15, 0, 23, 'r', 3)                                                  # solid rock, kept low so a corridor behind it stays in view
def carve(x0, x1, y0, y1, c='c'): m.box(x0, x1, y0, y1, c, 0)
carve(3, 12, 0, 5)                                                           # the entrance gallery
carve(2, 5, 6, 10)                                                           # a tunnel off to the left
carve(2, 13, 11, 15)                                                         # the first cavern
carve(9, 12, 16, 18)                                                         # a passage on the right
carve(3, 13, 19, 23)                                                         # the guardian's cavern
for (x0, x1, y0, y1, h) in [(5, 6, 12, 13, 3), (9, 10, 13, 14, 3), (6, 7, 20, 21, 3), (10, 11, 21, 22, 3), (3, 3, 4, 4, 2), (12, 12, 3, 3, 2)]:
    m.box(x0, x1, y0, y1, 'r', h)                                            # pillars of the rock left standing
m.box(7, 8, 14, 15, 'q', 1); m.box(4, 5, 22, 23, 'q', 1)                     # old timber and a toppled cart
m.box(10, 12, 11, 12, 'r', 1); m.box(3, 4, 15, 15, 'r', 1)                   # spill
spawns = {"king": [7, 2], "captain": [9, 2], "stones": [[4, 1], [11, 1], [7, 4]],
          "enemies": [{"kind": "fused", "at": [4, 12]}, {"kind": "crawler", "at": [11, 14]}, {"kind": "eater", "at": [8, 12]}, {"kind": "cave_boar", "at": [3, 14]},
                      {"kind": "fused", "at": [11, 17]}, {"kind": "crawler", "at": [5, 20]}, {"kind": "guardian", "at": [8, 22]}]}
decorate(m, spawns, 'b3', random.Random(1303))
problems += finish(m, spawns, 3, grade="slate", haze="heavy")

# ================================================================== 4. The Empty Battlefield (16 x 18)  player left
m = Map(16, 18, "Bellwether 4: The Empty Battlefield. A gallery half-collapsed behind Alaric: heaps of fallen rock, a few timbers, one gap through the cave-in, and the way out beyond it")
m.box(0, 15, 0, 17, 'r', 3)
m.box(2, 13, 0, 17, 'c', 0)
m.box(2, 13, 6, 8, 'q', 3); m.box(10, 12, 6, 8, 'c', 1)                      # the cave-in, with a gap climbed over at the far side
m.box(9, 12, 9, 9, 'r', 2); m.box(3, 4, 11, 12, 'r', 2); m.box(7, 8, 12, 13, 'r', 2); m.box(11, 12, 14, 15, 'r', 2)
m.box(3, 4, 2, 3, 'r', 1); m.box(11, 12, 3, 4, 'r', 1); m.box(8, 8, 15, 15, 'q', 1)
spawns = {"king": [6, 1], "captain": [8, 1], "stones": [[4, 1], [10, 1], [7, 3]],
          "enemies": [{"kind": "crawler", "at": [10, 11]}, {"kind": "crawler", "at": [5, 13]}, {"kind": "fused", "at": [9, 15]}, {"kind": "wolf", "at": [11, 16]}]}
decorate(m, spawns, 'b4', random.Random(1304))
problems += finish(m, spawns, 4, grade="slate", haze="heavy")

# ================================================================== 5. The Choice to Stay (16 x 24)  player left
m = Map(16, 24, "Bellwether 5: The Choice to Stay. The edge of the town: houses, fences and festival stalls, and the broken ground where the tunnel has burst open")
m.box(0, 15, 0, 23, 'g', 0)
m.box(5, 9, 0, 23, 's', 0)                                                  # the street
m.house(11, 15, 1, 5, 4, 'c', (11, 3)); m.house(11, 15, 8, 12, 4, 'd', (11, 10)); m.house(0, 3, 6, 9, 4, 'c', (3, 7))
m.box(0, 3, 13, 13, 'q', 1); m.box(0, 3, 17, 17, 'q', 1); m.box(12, 14, 16, 16, 'q', 1)       # fences
m.box(4, 11, 17, 23, 'c', 0); m.box(5, 10, 18, 22, 'c', 0)                  # the broken ground
for (x0, x1, y0, y1, h) in [(3, 4, 18, 19, 2), (11, 12, 19, 20, 2), (3, 3, 22, 22, 2), (12, 12, 22, 23, 1), (7, 8, 16, 16, 1)]:
    m.box(x0, x1, y0, y1, 'r', h)                                           # rock thrown up
m.box(7, 8, 21, 22, 'r', 0)
for (x, y) in [(3, 11), (13, 15), (2, 20)]: m.set(x, y, 't', 0)
m.box(3, 9, 11, 11, 'q', 2)                                                  # a barricade of festival tables across the street
m.smooth()
spawns = {"king": [6, 2], "captain": [8, 2], "stones": [[4, 1], [10, 1], [7, 4]],
          "enemies": [{"kind": "titan", "at": [7, 21]}, {"kind": "crawler", "at": [5, 16]}, {"kind": "crawler", "at": [10, 16]}, {"kind": "fused", "at": [6, 13]},
                      {"kind": "fused", "at": [9, 13]}, {"kind": "guardian", "at": [11, 18]}, {"kind": "cave_boar", "at": [4, 20]}]}
decorate(m, spawns, 'b5', random.Random(1305))
problems += finish(m, spawns, 5, grade="golden", haze="light")

# ================================================================== the festival square (16 x 24, a scene stage)
t = Map(16, 24, "Bellwether: the harvest festival's square. Houses around a cobbled square, the inn at the back with a bench outside, stalls and lanterns for the evening")
t.box(0, 15, 0, 23, 'g', 0)
t.box(3, 12, 2, 21, 's', 0)                                                 # the square
t.house(12, 15, 3, 8, 4, 'c', (12, 5)); t.house(12, 15, 15, 21, 4, 'd', (12, 18)); t.house(0, 2, 2, 7, 3, 'c', (2, 4)); t.house(0, 2, 16, 21, 3, 'd', (2, 18))
t.box(0, 2, 11, 12, 'g', 0)
for (x, y) in [(2, 12), (13, 12), (6, 22), (9, 1)]: t.set(x, y, 't', 0)
t.smooth()
tspawns = {"king": [6, 4], "captain": [8, 4], "stones": [[4, 3], [10, 3], [7, 6]], "enemies": [{"kind": "wolf", "at": [8, 21]}]}
decorate(t, tspawns, 'bt', random.Random(1306))
t.extra['grade'] = 'golden'; t.extra['haze'] = 'light'
t.save('town', None)
print('\nTOTAL PROBLEMS:', len(problems))
