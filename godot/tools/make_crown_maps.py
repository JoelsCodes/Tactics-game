#!/usr/bin/env python3
"""Writes chapter eight's maps: godot/samples/crown_1..5.json (the battles) and the scene stages crown_hill.json, crown_hall.json (the palace chamber is palace.json from
make_late_maps.py). Run from the repo root: python3 godot/tools/make_crown_maps.py
  1 The King's Highway   16x26  a royal road between hedges and trees, mile markers, a low rise
  2 The Outer Defenses   16x24  a moat, a curtain wall with its gate off the road, towers and a battlement
  3 The Captain's Oath   16x22  the gatehouse's barbican: pillared court, steps and a raised walk
  4 The City of Crowns   16x28  the central avenue: houses, fountains, statues and market stalls
  5 The Palace Gates     16x22  the great steps, pillars, gate towers and the palace doors
"""
import random
src = open('godot/tools/make_riverford_maps.py').read()
exec(src[:src.index("rnd = random.Random")])   # Map, preview, check, finish
exec(open('godot/tools/life_kit.py').read())   # decorate()
MOVE.update({'infantry': 4, 'rarcher': 4, 'mounted': 6, 'patrolcmd': 5, 'shield': 3, 'crossbow': 4, 'halberd': 3, 'bmage': 4, 'gateofficer': 4, 'aldren': 4,
             'swords': 5, 'support': 4, 'eliteinf': 4, 'cmage': 4, 'heavy': 3, 'vcross': 4, 'rknight': 4, 'pknight': 5, 'phalberd': 3, 'spell': 4, 'parcher': 4, 'pcmd': 4})
problems = []
OUT = 'godot/samples/crown_%s.json'

# 1. The King's Highway (16 x 26)
m = Map(16, 26, "Crown 1: The King's Highway. A royal road between hedgerows and old trees, mile markers every so often, a low rise to one side")
m.box(0, 15, 0, 25, 'g', 0)
m.box(5, 10, 0, 25, 's', 0)
for (x0, x1, y0, y1) in [(0, 3, 5, 8), (12, 14, 4, 7), (11, 14, 11, 14), (0, 2, 12, 16), (12, 14, 19, 23), (0, 3, 20, 24), (14, 15, 0, 25)]:
    m.box(x0, x1, y0, y1, 't', 0)
m.box(11, 13, 16, 18, 'g', 1); m.box(3, 4, 14, 16, 'g', 1)
m.box(0, 7, 9, 9, 'q', 2); m.box(8, 13, 15, 15, 'q', 2); m.box(3, 8, 20, 20, 'q', 1)
for (x, y) in [(5, 4), (10, 12), (5, 18), (10, 22)]: m.set(x, y, 'q', 1)       # mile markers
m.smooth()
spawns = {"king": [6, 2], "captain": [8, 2], "stones": [[4, 1], [10, 1], [7, 4]],
          "enemies": [{"kind": "infantry", "at": [5, 12]}, {"kind": "infantry", "at": [9, 13]}, {"kind": "rarcher", "at": [12, 16]}, {"kind": "mounted", "at": [6, 17]},
                      {"kind": "mounted", "at": [9, 18]}, {"kind": "rarcher", "at": [4, 19]}, {"kind": "patrolcmd", "at": [7, 22]}]}
decorate(m, spawns, 'k1', random.Random(1601))
problems += finish(m, spawns, 1, grade="golden", haze="light")

# 2. The Outer Defenses (16 x 24)
m = Map(16, 24, "Crown 2: The Outer Defenses. A moat and a curtain wall across the way in, towers at the corners, the gate set off to one side, a battlement behind it")
m.box(0, 15, 0, 23, 's', 0)
m.box(0, 15, 0, 4, 'g', 0)
m.box(0, 15, 7, 8, 'W', 0); m.box(11, 13, 7, 8, 'b', 0)                          # the moat, crossed by one bridge
m.box(0, 15, 11, 12, 'q', 5); m.box(11, 13, 11, 12, 's', 0)                      # the curtain wall, with the gate
m.box(0, 2, 10, 13, 'M', 4); m.box(14, 15, 10, 13, 'M', 4)                       # towers
m.box(2, 12, 15, 15, 'q', 2); m.box(4, 5, 16, 18, 'q', 2); m.box(9, 11, 18, 19, 'q', 2)
m.box(3, 8, 20, 22, 'M', 1); m.box(4, 7, 21, 22, 'M', 2)
for y in range(24): m.set(15, y, 'q', 5)
spawns = {"king": [6, 2], "captain": [8, 2], "stones": [[4, 1], [10, 1], [7, 4]],
          "enemies": [{"kind": "shield", "at": [11, 14]}, {"kind": "shield", "at": [8, 14]}, {"kind": "crossbow", "at": [13, 13]}, {"kind": "halberd", "at": [6, 17]},
                      {"kind": "bmage", "at": [9, 17]}, {"kind": "crossbow", "at": [3, 19]}, {"kind": "gateofficer", "at": [6, 21]}]}
decorate(m, spawns, 'k2', random.Random(1602))
problems += finish(m, spawns, 2, grade="slate", haze="light")

# 3. The Captain's Oath (16 x 22)
m = Map(16, 22, "Crown 3: The Captain's Oath. The gatehouse's barbican: a pillared court of cobbles, steps up to a raised walk, the portcullis behind")
m.box(0, 15, 0, 21, 's', 0)
for y in range(22): m.set(15, y, 'q', 5); m.set(14, y, 'q', 4)
m.box(0, 3, 6, 7, 'q', 3); m.box(12, 13, 6, 7, 'q', 3); m.box(4, 11, 9, 9, 'q', 2); m.box(0, 8, 13, 13, 'q', 2)
m.box(9, 13, 14, 20, 'M', 1); m.box(10, 13, 15, 19, 'M', 2); m.box(8, 8, 16, 17, 'M', 1)
m.box(2, 3, 17, 18, 'q', 3); m.box(5, 6, 16, 16, 'q', 2); m.box(6, 7, 19, 20, 'q', 2)
spawns = {"king": [6, 2], "captain": [8, 2], "stones": [[4, 1], [10, 1], [7, 4]],
          "enemies": [{"kind": "swords", "at": [5, 11]}, {"kind": "swords", "at": [10, 11]}, {"kind": "shield", "at": [8, 12]}, {"kind": "rarcher", "at": [11, 16]},
                      {"kind": "support", "at": [4, 15]}, {"kind": "shield", "at": [6, 18]}, {"kind": "aldren", "at": [8, 20]}]}
decorate(m, spawns, 'k3', random.Random(1603))
problems += finish(m, spawns, 3, grade="slate", haze="light")

# 4. The City of Crowns (16 x 28)
m = Map(16, 28, "Crown 4: The City of Crowns. The central avenue: tall houses to either side, a fountain in the middle of a square, statues of kings on plinths, market stalls left shut")
m.box(0, 15, 0, 27, 's', 0)
m.house(11, 15, 0, 6, 5, 'c', (11, 3)); m.house(11, 15, 9, 14, 6, 'd', (11, 11)); m.house(11, 15, 17, 22, 5, 'c', (11, 19)); m.house(11, 15, 24, 27, 5, 'd', (11, 25))
m.house(0, 3, 0, 5, 4, 'd', (3, 3)); m.house(0, 3, 9, 13, 4, 'c', (3, 11)); m.house(0, 3, 22, 27, 4, 'd', (3, 24))
m.box(5, 9, 15, 19, 'W', 0); m.box(6, 8, 16, 18, 'M', 1)                           # the fountain's pool and its basin
for (x, y) in [(4, 8), (10, 8), (4, 21), (10, 21)]: m.box(x, x, y, y, 'q', 3)       # statues on plinths
m.box(0, 3, 15, 18, 'q', 2); m.box(12, 13, 14, 15, 'q', 2); m.box(6, 9, 11, 11, 'q', 1); m.box(5, 9, 24, 24, 'q', 1)
spawns = {"king": [6, 2], "captain": [8, 2], "stones": [[4, 1], [10, 1], [7, 4]],
          "enemies": [{"kind": "eliteinf", "at": [4, 12]}, {"kind": "eliteinf", "at": [9, 13]}, {"kind": "cmage", "at": [7, 14]}, {"kind": "heavy", "at": [4, 20]},
                      {"kind": "vcross", "at": [9, 20]}, {"kind": "heavy", "at": [8, 22]}, {"kind": "cmage", "at": [5, 25]}, {"kind": "rknight", "at": [8, 26]}]}
decorate(m, spawns, 'k4', random.Random(1604))
problems += finish(m, spawns, 4, grade="golden", haze="light")

# 5. The Palace Gates (16 x 22)
m = Map(16, 22, "Crown 5: The Palace Gates. The great steps climbing to the palace doors, pillars either side, gate towers and the royal standards")
m.box(0, 15, 0, 21, 'M', 0)
for y in range(22): m.set(15, y, 'q', 6); m.set(14, y, 'q', 5)
m.box(1, 13, 8, 9, 'M', 1); m.box(2, 12, 10, 11, 'M', 2); m.box(3, 11, 12, 13, 'M', 3); m.box(4, 10, 14, 21, 'o', 3)       # the steps and the landing
m.box(0, 2, 15, 18, 'q', 4); m.box(12, 13, 15, 18, 'q', 4)                                                              # gate towers
for (x, y) in [(3, 5), (12, 5), (2, 12), (13, 12)]: m.box(x, x, y, y, 'q', 3)                                          # pillars
m.box(6, 9, 4, 4, 'q', 1); m.box(0, 4, 3, 3, 'q', 2); m.box(0, 7, 6, 6, 'q', 2); m.box(7, 13, 11, 11, 'q', 3)
spawns = {"king": [6, 2], "captain": [8, 2], "stones": [[4, 1], [10, 1], [7, 5]],
          "enemies": [{"kind": "pknight", "at": [4, 13]}, {"kind": "pknight", "at": [10, 13]}, {"kind": "phalberd", "at": [6, 14]}, {"kind": "phalberd", "at": [8, 14]},
                      {"kind": "spell", "at": [5, 17]}, {"kind": "spell", "at": [9, 17]}, {"kind": "parcher", "at": [4, 19]}, {"kind": "pcmd", "at": [7, 20]}]}
decorate(m, spawns, 'k5', random.Random(1605))
problems += finish(m, spawns, 5, grade="golden", haze="light")

# scene stage: the hill above the capital
t = Map(16, 24, "Crown: the hill above the capital. A grassy slope, a standing stone, and far across the plain the walls, the city and the palace")
t.box(0, 15, 0, 23, 'g', 0)
t.box(5, 10, 0, 23, 'd', 0)
for y in range(24): t.set(15, y, 'r', 4); t.set(14, y, 'r', 3)
t.box(9, 13, 18, 23, 'g', 1); t.box(10, 12, 20, 22, 'g', 2); t.set(11, 21, 'q', 3)
for (x0, x1, y0, y1) in [(0, 2, 5, 8), (11, 13, 3, 6), (0, 3, 14, 17)]: t.box(x0, x1, y0, y1, 't', 0)
t.smooth()
tspawns = {"king": [6, 2], "captain": [8, 2], "stones": [[4, 1], [10, 1], [7, 4]], "enemies": [{"kind": "infantry", "at": [8, 20]}]}
decorate(t, tspawns, 'kh', random.Random(1606)); t.extra['grade'] = 'golden'; t.extra['haze'] = 'light'
OUT = 'godot/samples/%s.json'; t.save('crown_hill', None)

# scene stage: a city street (crowds' quiet)
t = Map(16, 24, "Crown: a street in the capital, shut stalls and shuttered windows, a fountain at the corner")
t.box(0, 15, 0, 23, 's', 0)
t.house(11, 15, 0, 7, 5, 'c', (11, 4)); t.house(11, 15, 12, 19, 5, 'd', (11, 15)); t.house(0, 3, 4, 10, 4, 'd', (3, 7)); t.house(0, 3, 14, 21, 4, 'c', (3, 17))
t.box(6, 8, 10, 12, 'W', 0)
t.smooth()
tspawns = {"king": [6, 2], "captain": [8, 2], "stones": [[4, 1], [10, 1], [7, 4]], "enemies": [{"kind": "infantry", "at": [8, 20]}]}
decorate(t, tspawns, 'kc', random.Random(1607)); t.extra['grade'] = 'golden'; t.extra['haze'] = 'light'
t.save('crown_street', None)

# scene stage: the palace hall before the throne room
t = Map(16, 16, "Crown: the palace's grand hall. A long marble floor, pillars, and the tall doors of the throne room at the far end")
t.box(0, 15, 0, 15, 'M', 0)
for y in range(16): t.set(15, y, 'q', 6); t.set(14, y, 'q', 5)
t.box(0, 0, 0, 15, 'q', 3); t.box(5, 10, 13, 15, 'o', 2); t.box(6, 9, 14, 15, 'e', 3)
t.box(0, 3, 4, 4, 'q', 3); t.box(12, 13, 4, 4, 'q', 3); t.box(0, 3, 10, 10, 'q', 3); t.box(12, 13, 10, 10, 'q', 3)
t.smooth()
tspawns = {"king": [6, 2], "captain": [8, 2], "stones": [[4, 1], [10, 1], [7, 4]], "enemies": [{"kind": "infantry", "at": [8, 12]}]}
decorate(t, tspawns, 'kg', random.Random(1608)); t.extra['grade'] = 'golden'; t.extra['haze'] = 'light'
t.save('crown_hall', None)
print('\nTOTAL PROBLEMS:', len(problems))
