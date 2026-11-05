#!/usr/bin/env python3
"""Writes chapter four's maps: godot/samples/mountain_1.json .. mountain_5.json. Run from the repo root: python3 godot/tools/make_mountain_maps.py

Same kit as make_crucible_maps.py (cells (x, y): x is the depth up the screen, y runs left to right; the fight runs left to right).
  1 The Forgotten Pass            16x30  a narrow mountain road between cliffs: ruined barricades make choke points, raised platforms hold the archers, the gate at the east end
  2 The Scout Who Never Returned  16x24  forest ruins: trees close the paths, a ruined arch (Kaelen's perch) and lookout platforms
  3 The Endless Siege             16x32  a fortress courtyard in three sections divided by walls, a war standard in each, the keep at the far end
  4 The Last Commander            16x24  the command courtyard: the memorial on its dais in the middle, structures and a defended far side
  5 The Mountain's Heart          16x22  a chamber under the fortress: broken monuments, platforms, the Heart on its dais
"""
import random
src = open('godot/tools/make_riverford_maps.py').read()
exec(src[:src.index("rnd = random.Random")])   # Map, preview, check, finish
exec(open('godot/tools/life_kit.py').read())   # decorate(): braziers, banners, crystals, wisps and the weather
OUT = 'godot/samples/mountain_%s.json'
MOVE.update({'infantry': 4, 'archer': 4, 'captain': 4, 'shield': 3, 'elite': 4, 'knight': 4, 'scout': 6, 'swordsman': 5, 'kaelen': 6, 'gideon': 3,
             'standard': 0, 'memorial': 0, 'echo': 4, 'grief': 4, 'heart': 0})
rnd = random.Random(1107)
problems = []

# ================================================================== 1. The Forgotten Pass (16 x 30)  player left
m = Map(16, 30, "Mountain 1: The Forgotten Pass. A narrow road between enormous cliffs: abandoned weapons, rusted shields on broken barricades, platforms for archers, and the fortress gate at the far end")
m.box(0, 15, 0, 29, 'M', 0)
for y in range(30):
    for x in (0, 1): m.set(x, y, 'q', 5)                              # the southern cliff, high and close to the camera's side of the road
    for x in (13, 14, 15): m.set(x, y, 'q', 5)                        # the northern cliff
m.box(2, 12, 0, 29, 'd', 0)                                           # the road: packed earth
m.box(2, 12, 26, 29, 'M', 1); m.box(5, 9, 28, 29, 'o', 2)             # the gate's apron and its threshold
for (xa, xb, y0, y1) in [(2, 8, 12, 12), (2, 8, 13, 13), (6, 12, 20, 20), (6, 12, 21, 21)]:   # ruined barricades: a gap in the middle of each, or at one end
    m.box(xa, xb, y0, y1, 'q', 3)
m.box(11, 12, 8, 10, 'M', 2); m.box(11, 12, 15, 17, 'M', 2); m.box(11, 12, 22, 24, 'M', 2)    # platforms along the north cliff for archers
m.box(10, 10, 9, 9, 'M', 1); m.box(10, 10, 16, 16, 'M', 1); m.box(10, 10, 23, 23, 'M', 1)   # ramps up to them
for (x, y) in [(3, 7), (8, 15), (4, 17), (10, 19), (6, 24), (3, 25), (9, 5)]: m.set(x, y, 'q', 2)   # fallen shields and carts
spawns = {"king": [6, 2], "captain": [8, 2], "stones": [[4, 1], [10, 1], [7, 4]],
          "enemies": [{"kind": "infantry", "at": [5, 14]}, {"kind": "infantry", "at": [8, 14]}, {"kind": "archer", "at": [12, 16]}, {"kind": "archer", "at": [12, 9]},
                      {"kind": "shield", "at": [6, 22]}, {"kind": "shield", "at": [10, 22]}, {"kind": "archer", "at": [12, 23]}, {"kind": "infantry", "at": [5, 24]}, {"kind": "captain", "at": [7, 27]}]}
decorate(m, spawns, 'm1', random.Random(1200+1))
problems += finish(m, spawns, 1, grade="slate", haze="heavy")

# ================================================================== 2. The Scout Who Never Returned (16 x 24)  player left
m = Map(16, 24, "Mountain 2: The Scout Who Never Returned. Forest ruins behind the gate: branching paths between old trees, a ruined arch and lookout platforms")
m.box(0, 15, 0, 23, 'g', 0)
for y in range(24): m.set(15, y, 'q', 5); m.set(14, y, 'q', 4)
m.box(1, 12, 0, 3, 'd', 0)                                            # the gate's clearing
for (x0, x1, y0, y1) in [(1, 3, 6, 8), (1, 2, 13, 15), (4, 6, 10, 11), (9, 12, 5, 7), (10, 12, 11, 13), (4, 5, 16, 18), (1, 3, 20, 22), (9, 11, 16, 17), (6, 7, 6, 6), (8, 9, 12, 12)]:
    m.box(x0, x1, y0, y1, 't', 0)                                     # dense trees: the paths wind between them
m.box(2, 12, 9, 9, 'd', 0); m.box(3, 11, 14, 14, 'd', 0)             # two winding trails
m.box(6, 9, 19, 23, 'M', 1); m.box(5, 10, 21, 22, 'q', 3); m.box(7, 8, 21, 22, 'M', 3); m.box(7, 8, 20, 20, 'M', 2)   # the ruined arch and the step up to it
m.box(11, 12, 14, 15, 'M', 2); m.box(3, 4, 12, 12, 'M', 1); m.box(12, 12, 20, 21, 'M', 2)          # lookout platforms
for (x, y) in [(5, 4), (9, 3), (7, 12), (11, 9), (2, 11), (6, 15)]: m.set(x, y, 'q', 1)
spawns = {"king": [6, 1], "captain": [8, 1], "stones": [[4, 0], [10, 1], [7, 3]],
          "enemies": [{"kind": "scout", "at": [4, 12]}, {"kind": "scout", "at": [9, 10]}, {"kind": "swordsman", "at": [8, 14]}, {"kind": "scout", "at": [6, 17]},
                      {"kind": "swordsman", "at": [3, 18]}, {"kind": "scout", "at": [11, 18]}, {"kind": "kaelen", "at": [7, 21]}]}
decorate(m, spawns, 'm2', random.Random(1200+2))
problems += finish(m, spawns, 2, grade="forest", haze="light")

# ================================================================== 3. The Endless Siege (16 x 32)  player left
m = Map(16, 32, "Mountain 3: The Endless Siege. The fortress courtyard in three sections divided by walls, a war standard in each, battlements along the north, the keep at the far end")
m.box(0, 15, 0, 31, 'M', 0)
for y in range(32):
    m.set(15, y, 'q', 5); m.set(14, y, 'M', 3); m.set(13, y, 'M', 2)   # the north battlements
for y in range(1, 32, 4): m.box(14, 14, y, y, 'q', 5)
m.box(2, 12, 28, 31, 'q', 5); m.box(5, 9, 28, 31, 'M', 1)           # the keep at the far end
m.box(1, 12, 10, 11, 'q', 4); m.box(9, 11, 10, 11, 'f', 0)           # the first wall: one gate at the north end
m.box(1, 12, 21, 22, 'q', 4); m.box(1, 3, 21, 22, 'f', 0)           # the second: a gate at the south end
for (x, y) in [(11, 5), (3, 6), (6, 15), (10, 16), (4, 26), (9, 25)]: m.box(x, x + 1, y, y + 1, 'q', 2)   # rubble and siege engines
m.box(11, 12, 12, 13, 'M', 1); m.box(3, 4, 17, 18, 'M', 1); m.box(7, 8, 24, 25, 'M', 1)           # a plinth for each standard
for (x, y) in [(11, 12), (3, 17), (7, 24)]: m.set(x, y, 'e', 2)
m.box(0, 12, 0, 0, 'f', 1)
spawns = {"king": [6, 2], "captain": [8, 2], "stones": [[4, 1], [10, 1], [7, 4]],
          "enemies": [{"kind": "standard", "at": [11, 12]}, {"kind": "standard", "at": [3, 17]}, {"kind": "standard", "at": [7, 24]},
                      {"kind": "shield", "at": [8, 14]}, {"kind": "infantry", "at": [10, 14]}, {"kind": "archer", "at": [12, 15]}, {"kind": "shield", "at": [5, 19]},
                      {"kind": "elite", "at": [8, 18]}, {"kind": "archer", "at": [12, 20]}, {"kind": "infantry", "at": [6, 26]}, {"kind": "elite", "at": [8, 27]}]}
decorate(m, spawns, 'm3', random.Random(1200+3))
problems += finish(m, spawns, 3, grade="slate", haze="heavy")

# ================================================================== 4. The Last Commander (16 x 24)  player left
m = Map(16, 24, "Mountain 4: The Last Commander. The fortress command courtyard: a memorial on its dais at the heart of it, defensive structures, and the commander's honor guard on the far side")
m.box(0, 15, 0, 23, 'M', 0)
for y in range(24): m.set(15, y, 'q', 5); m.set(14, y, 'q', 5)
m.box(5, 9, 9, 13, 'o', 1); m.box(6, 8, 10, 12, 'o', 2); m.set(7, 11, 'e', 3)    # the memorial's dais, and its plinth
m.box(3, 13, 6, 6, 'q', 3); m.box(3, 13, 7, 7, 'q', 3); m.box(1, 9, 15, 15, 'q', 3); m.box(1, 9, 16, 16, 'q', 3)   # defensive walls: gaps at opposite ends
m.box(3, 4, 18, 19, 'q', 3); m.box(10, 11, 18, 19, 'q', 3); m.box(7, 7, 21, 22, 'q', 2)
m.box(4, 10, 17, 17, 'M', 1); m.box(5, 9, 18, 21, 'o', 1)                         # the commander's step
for (x, y) in [(2, 11), (12, 11), (5, 4), (9, 4), (2, 20), (12, 21)]: m.set(x, y, 'q', 2)
m.box(4, 4, 6, 7, 'M', 0); m.box(3, 3, 6, 7, 'M', 0)
spawns = {"king": [6, 2], "captain": [8, 2], "stones": [[4, 1], [10, 1], [7, 3]],
          "enemies": [{"kind": "memorial", "at": [7, 11]}, {"kind": "gideon", "at": [7, 19]}, {"kind": "knight", "at": [5, 17]}, {"kind": "knight", "at": [9, 17]},
                      {"kind": "shield", "at": [3, 14]}, {"kind": "shield", "at": [11, 14]}, {"kind": "elite", "at": [6, 21]}, {"kind": "elite", "at": [9, 21]}]}
decorate(m, spawns, 'm4', random.Random(1200+4))
problems += finish(m, spawns, 4, grade="slate", haze="light")

# ================================================================== 5. The Mountain's Heart (16 x 22)  player left
m = Map(16, 22, "Mountain 5: The Mountain's Heart. An ancient chamber under the fortress: broken monuments, ruined platforms and the Heart on its dais, wreathed in spectral energy")
m.box(0, 15, 0, 21, 'c', 0)
for y in range(22): m.set(15, y, 'q', 5); m.set(14, y, 'q', 5)
for x in range(16): m.set(x, 21, 'q', 4)
m.box(1, 13, 1, 20, 'f', 0)
m.box(5, 10, 15, 20, 'o', 1); m.box(6, 9, 16, 20, 'o', 2); m.box(7, 8, 18, 20, 'e', 3)     # the Heart's dais
for (x0, x1, y0, y1, h) in [(2, 3, 6, 7, 3), (11, 12, 6, 7, 3), (4, 4, 10, 10, 2), (10, 10, 11, 11, 2), (2, 2, 13, 14, 2), (12, 12, 14, 15, 2), (7, 7, 8, 8, 2), (3, 3, 17, 17, 3), (12, 12, 18, 18, 3)]:
    m.box(x0, x1, y0, y1, 'q', h)
m.box(1, 9, 9, 9, 'q', 3); m.box(1, 9, 10, 10, 'q', 3)
m.box(1, 3, 3, 4, 'M', 1); m.box(11, 13, 3, 4, 'M', 1); m.box(2, 4, 10, 11, 'M', 1); m.box(11, 12, 9, 10, 'M', 1)   # ruined platforms
for (x, y) in [(6, 12), (9, 13), (5, 5), (10, 5)]: m.set(x, y, 'M', 1)
spawns = {"king": [6, 2], "captain": [8, 2], "stones": [[4, 1], [10, 1], [7, 4]],
          "enemies": [{"kind": "heart", "at": [7, 18]}, {"kind": "echo", "at": [5, 13]}, {"kind": "echo", "at": [10, 13]}, {"kind": "grief", "at": [3, 16]}, {"kind": "grief", "at": [12, 16]},
                      {"kind": "echo", "at": [8, 14]}]}
decorate(m, spawns, 'm5', random.Random(1200+5))
problems += finish(m, spawns, 5, grade="slate", haze="heavy")
print('\nTOTAL PROBLEMS:', len(problems))
