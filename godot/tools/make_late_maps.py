#!/usr/bin/env python3
"""Writes chapter six's and seven's maps: godot/samples/expanse_1..5.json, expanse_academy.json (a scene stage), archive.json, palace.json (scene stages, shared),
vespera_1..5.json and vespera_city.json (a scene stage). Run from the repo root: python3 godot/tools/make_late_maps.py   (same kit as make_crucible_maps.py).
Chapter six, The Ashen Expanse:  1 the battlefield of old wars   2 the academy gates   3 the drill field   4 the academy's chambers   5 the duelling ground
Chapter seven, Vespera:          1 the streets without sound   2 the forgotten cemetery   3 the catacombs   4 the choir's chamber   5 the top of the bell tower
"""
import random
src = open('godot/tools/make_riverford_maps.py').read()
exec(src[:src.index("rnd = random.Random")])   # Map, preview, check, finish
exec(open('godot/tools/life_kit.py').read())   # decorate()
MOVE.update({'armor': 3, 'blade': 6, 'construct': 3, 'sentinel': 3, 'cadet': 4, 'trainer': 3, 'parcher': 4, 'instructor': 4, 'shieldwall': 3, 'swordsman': 5, 'tactician': 4,
             'corrupt': 4, 'cguardian': 3, 'cassian': 5, 'academyguard': 3, 'vparcher': 4, 'eliteswords': 5, 'wander': 5, 'lantern': 4, 'ceremonial': 3, 'gsentinel': 3,
             'gknight': 4, 'gargoyle': 6, 'mourner': 4, 'cguard': 3, 'cundead': 4, 'sguard': 4, 'rconstruct': 4, 'catsentinel': 3, 'captured': 4, 'crystalguard': 3,
             'choirsentinel': 4, 'malrec': 4, 'bellconstruct': 4, 'crystalspirit': 4, 'bellsentinel': 4})
problems = []
OUT = 'godot/samples/%s.json'


class M2(Map):
    pass


def save_battle(m, spawns, key, prefix, n, **extra):
    global OUT
    OUT = 'godot/samples/' + prefix + '_%s.json'
    return finish(m, spawns, n, **extra)


# ================================================================== CHAPTER SIX
# 1. The Ashen Expanse (16 x 26)
m = Map(16, 26, "Expanse 1: The Ashen Expanse. A plain of ash over old wars: swords standing in the ground, half-buried siege engines, rusted standards")
m.box(0, 15, 0, 25, 'c', 0)
for y in range(26): m.set(15, y, 'r', 4); m.set(14, y, 'r', 3)
m.box(3, 4, 7, 11, 'q', 2); m.box(10, 12, 12, 13, 'q', 2); m.box(2, 3, 16, 19, 'q', 2); m.box(9, 10, 20, 23, 'q', 2)       # collapsed siege engines
m.box(6, 8, 10, 10, 'q', 1); m.box(5, 6, 15, 15, 'q', 3); m.box(8, 12, 17, 17, 'q', 2)
m.box(0, 8, 9, 9, 'q', 2); m.box(8, 13, 15, 15, 'q', 2)           # lines of wrecked wagons: a gap at the end of each
for (x0, x1, y0, y1, h) in [(6, 7, 6, 7, 1), (11, 12, 4, 6, 1), (4, 6, 21, 23, 2), (8, 9, 13, 14, 1), (12, 13, 19, 21, 2), (1, 2, 12, 14, 1)]:
    m.box(x0, x1, y0, y1, 'r', h)                                            # old craters' lips and heaps
m.box(5, 9, 0, 4, 'd', 0)
spawns = {"king": [6, 2], "captain": [8, 2], "stones": [[4, 1], [10, 1], [7, 4]],
          "enemies": [{"kind": "armor", "at": [6, 13]}, {"kind": "blade", "at": [10, 16]}, {"kind": "blade", "at": [4, 14]}, {"kind": "construct", "at": [7, 19]},
                      {"kind": "armor", "at": [11, 21]}, {"kind": "blade", "at": [7, 22]}, {"kind": "sentinel", "at": [8, 24]}]}
decorate(m, spawns, 'x1', random.Random(1401))
problems += save_battle(m, spawns, 1, 'expanse', 1, grade="slate", haze="heavy")

# 2. The Academy Gates (16 x 24)
m = Map(16, 24, "Expanse 2: The Academy Gates. A gatehouse and its curtain wall across the road, towers on either side, and the drill courtyard behind")
m.box(0, 15, 0, 23, 'f', 0)
m.box(0, 15, 0, 4, 'c', 0)
m.box(0, 15, 9, 10, 'q', 4); m.box(10, 12, 9, 10, 'f', 0)                     # the curtain wall, its gate off to one side
m.box(0, 3, 8, 11, 'M', 3); m.box(12, 15, 8, 11, 'M', 3); m.box(1, 2, 9, 10, 'M', 4)    # the gate towers
for y in range(24): m.set(15, y, 'q', 5)
for (x0, x1, y0, y1, h) in [(3, 4, 14, 15, 2), (8, 9, 14, 15, 2), (12, 13, 16, 17, 2), (5, 6, 19, 20, 3), (10, 11, 20, 21, 2), (2, 3, 21, 22, 2)]:
    m.box(x0, x1, y0, y1, 'q', h)
m.box(6, 9, 16, 17, 'M', 1); m.box(13, 14, 13, 14, 'M', 2); m.box(1, 3, 17, 18, 'M', 2)
spawns = {"king": [6, 2], "captain": [8, 2], "stones": [[4, 1], [10, 1], [7, 4]],
          "enemies": [{"kind": "cadet", "at": [11, 13]}, {"kind": "trainer", "at": [5, 13]}, {"kind": "parcher", "at": [13, 14]}, {"kind": "cadet", "at": [8, 17]},
                      {"kind": "trainer", "at": [4, 19]}, {"kind": "parcher", "at": [12, 19]}, {"kind": "instructor", "at": [8, 21]}]}
decorate(m, spawns, 'x2', random.Random(1402))
problems += save_battle(m, spawns, 2, 'expanse', 2, grade="slate", haze="light")

# 3. The General's Lesson (16 x 24)
m = Map(16, 24, "Expanse 3: The General's Lesson. The drill field: sand ruled with old formation lines, low barricades for the exercises, the reviewing stand at the far end")
m.box(0, 15, 0, 23, 'a', 0)
for y in range(24): m.set(15, y, 'q', 4); m.set(14, y, 'q', 4)
m.box(0, 8, 9, 9, 'q', 2); m.box(7, 13, 12, 12, 'q', 2); m.box(0, 5, 15, 15, 'q', 2); m.box(10, 13, 17, 17, 'q', 2)   # drill barricades, a gap at the end of each
m.box(5, 10, 19, 22, 'M', 1); m.box(6, 9, 20, 22, 'M', 2)                                                         # the reviewing stand
for (x, y) in [(7, 6), (11, 8), (3, 12), (8, 16), (12, 14)]: m.box(x, x, y, y, 'q', 1)
m.smooth()
spawns = {"king": [6, 2], "captain": [8, 2], "stones": [[4, 1], [10, 1], [7, 4]],
          "enemies": [{"kind": "shieldwall", "at": [5, 13]}, {"kind": "shieldwall", "at": [7, 14]}, {"kind": "shieldwall", "at": [9, 13]}, {"kind": "parcher", "at": [6, 17]},
                      {"kind": "parcher", "at": [9, 17]}, {"kind": "swordsman", "at": [4, 18]}, {"kind": "swordsman", "at": [11, 19]}, {"kind": "tactician", "at": [8, 21]}]}
decorate(m, spawns, 'x3', random.Random(1403))
problems += save_battle(m, spawns, 3, 'expanse', 3, grade="golden", haze="light")

# 4. The Price of Victory (16 x 22)
m = Map(16, 22, "Expanse 4: The Price of Victory. The academy's lecture halls and sealed training chambers: marble floors, doors torn open, the spirit-light turned red")
m.box(0, 15, 0, 21, 'M', 0)
for y in range(22): m.set(15, y, 'q', 5); m.set(14, y, 'q', 4)
m.box(0, 9, 8, 8, 'q', 3); m.box(4, 13, 14, 14, 'q', 3)
m.box(1, 3, 9, 13, 'o', 1); m.box(11, 13, 9, 13, 'o', 1)                                   # raised dais rooms either side
m.box(5, 9, 16, 20, 'o', 1); m.box(6, 8, 17, 19, 'o', 2)
for (x, y) in [(5, 4), (10, 5), (6, 11), (9, 11), (3, 18), (12, 18)]: m.box(x, x, y, y, 'q', 2)
spawns = {"king": [6, 2], "captain": [8, 2], "stones": [[4, 1], [10, 1], [7, 4]],
          "enemies": [{"kind": "corrupt", "at": [3, 11]}, {"kind": "corrupt", "at": [12, 12]}, {"kind": "corrupt", "at": [6, 12]}, {"kind": "cguardian", "at": [8, 16]},
                      {"kind": "corrupt", "at": [4, 17]}, {"kind": "cguardian", "at": [12, 16]}]}
decorate(m, spawns, 'x4', random.Random(1404))
problems += save_battle(m, spawns, 4, 'expanse', 4, grade="slate", haze="heavy")

# 5. The Unbowed General (16 x 20)
m = Map(16, 20, "Expanse 5: The Unbowed General. The academy's duelling ground: a marble ring with a raised dais at the far side, pillars and the commanders' banners")
m.box(0, 15, 0, 19, 'M', 0)
for y in range(20): m.set(15, y, 'q', 5); m.set(14, y, 'q', 4)
m.box(4, 11, 13, 18, 'o', 1); m.box(5, 10, 14, 18, 'o', 2); m.box(6, 9, 16, 18, 'e', 3)   # the general's dais
m.box(2, 3, 7, 8, 'q', 3); m.box(12, 13, 7, 8, 'q', 3); m.box(5, 6, 9, 9, 'q', 2); m.box(9, 10, 9, 9, 'q', 2); m.box(1, 3, 12, 14, 'M', 1); m.box(12, 14, 12, 14, 'M', 1)
m.box(0, 3, 4, 5, 'q', 2); m.box(12, 13, 3, 4, 'q', 2); m.box(7, 8, 6, 6, 'q', 1)
m.box(0, 8, 10, 10, 'q', 2); m.box(10, 13, 11, 11, 'q', 1)
spawns = {"king": [6, 2], "captain": [8, 2], "stones": [[4, 1], [10, 1], [7, 4]],
          "enemies": [{"kind": "cassian", "at": [7, 16]}, {"kind": "eliteswords", "at": [5, 12]}, {"kind": "eliteswords", "at": [10, 12]}, {"kind": "academyguard", "at": [3, 15]},
                      {"kind": "academyguard", "at": [12, 15]}, {"kind": "vparcher", "at": [4, 17]}, {"kind": "vparcher", "at": [11, 17]}]}
decorate(m, spawns, 'x5', random.Random(1405))
problems += save_battle(m, spawns, 5, 'expanse', 5, grade="slate", haze="light")

# scene stage: the academy courtyard
t = Map(16, 24, "Expanse: the academy's courtyard. Crumbling walls round a training ground that stays whole, a reviewing balcony on the north side")
t.box(0, 15, 0, 23, 'f', 0)
t.box(2, 12, 2, 21, 'a', 0)
for y in range(24): t.set(15, y, 'q', 4); t.set(14, y, 'q', 3)
t.box(11, 13, 9, 14, 'M', 2); t.box(12, 12, 10, 13, 'M', 3)                  # the balcony Cassian watches from
t.box(0, 1, 0, 23, 'q', 2); t.box(0, 3, 0, 1, 'q', 3); t.box(0, 3, 22, 23, 'q', 3)
t.smooth()
tspawns = {"king": [6, 3], "captain": [8, 3], "stones": [[4, 2], [10, 2], [7, 5]], "enemies": [{"kind": "cadet", "at": [8, 20]}]}
decorate(t, tspawns, 'xa', random.Random(1406)); t.extra['grade'] = 'slate'; t.extra['haze'] = 'light'
OUT = 'godot/samples/%s.json'; t.save('expanse_academy', None)

# scene stage: an archive (shared by chapters six and seven)
t = Map(16, 14, "An archive: a long hall of shelves and a reading table under lamplight")
t.box(0, 15, 0, 13, 'f', 0)
for y in range(14): t.set(15, y, 'q', 4); t.set(14, y, 'q', 4)
t.box(0, 0, 0, 13, 'q', 2); t.box(1, 2, 0, 0, 'q', 2); t.box(1, 2, 13, 13, 'q', 2); t.box(12, 13, 4, 9, 'q', 2)
t.smooth()
tspawns = {"king": [6, 3], "captain": [8, 3], "stones": [[4, 2], [10, 2], [7, 5]], "enemies": [{"kind": "cadet", "at": [8, 12]}]}
decorate(t, tspawns, 'ar', random.Random(1407)); t.extra['grade'] = 'golden'; t.extra['haze'] = 'light'
t.save('archive', None)

# scene stage: the palace chamber (the King's private moments)
t = Map(16, 14, "The palace: a quiet chamber, a small portrait on the wall, one chair")
t.box(0, 15, 0, 13, 'M', 0)
for y in range(14): t.set(15, y, 'q', 5); t.set(14, y, 'q', 4)
t.box(0, 0, 0, 13, 'q', 2); t.box(4, 9, 5, 8, 'o', 1); t.box(6, 7, 6, 7, 'e', 2)
t.smooth()
tspawns = {"king": [6, 3], "captain": [8, 3], "stones": [[4, 2], [10, 2], [7, 5]], "enemies": [{"kind": "cadet", "at": [8, 12]}]}
decorate(t, tspawns, 'pl', random.Random(1408)); t.extra['grade'] = 'golden'; t.extra['haze'] = 'light'
t.save('palace', None)

# ================================================================== CHAPTER SEVEN: VESPERA
# 1. The Streets Without Sound (16 x 24)
m = Map(16, 24, "Vespera 1: The Streets Without Sound. Narrow stone streets between tall houses, bell towers dark above them, lanterns in the evening fog")
m.box(0, 15, 0, 23, 's', 0)
m.house(10, 15, 0, 5, 4, 'c', (10, 3)); m.house(10, 15, 8, 12, 4, 'd', (10, 10)); m.house(11, 15, 15, 20, 5, 'c', (11, 17)); m.house(0, 3, 6, 10, 4, 'd', (3, 8)); m.house(0, 3, 14, 18, 4, 'c', (3, 16))
m.box(5, 8, 0, 23, 's', 0)                                                  # the main street
m.box(4, 9, 11, 13, 'M', 0)                                                 # a small square
m.box(2, 3, 20, 22, 'q', 2); m.box(7, 8, 14, 15, 'q', 1); m.box(4, 5, 6, 6, 'q', 1); m.box(11, 12, 6, 7, 'q', 1)
m.box(0, 7, 9, 9, 'q', 2); m.box(6, 13, 16, 16, 'q', 2)
spawns = {"king": [6, 2], "captain": [8, 2], "stones": [[4, 1], [9, 1], [7, 4]],
          "enemies": [{"kind": "wander", "at": [6, 13]}, {"kind": "wander", "at": [6, 14]}, {"kind": "lantern", "at": [5, 16]}, {"kind": "ceremonial", "at": [7, 17]},
                      {"kind": "lantern", "at": [9, 19]}, {"kind": "wander", "at": [5, 21]}, {"kind": "gsentinel", "at": [7, 22]}]}
decorate(m, spawns, 'y1', random.Random(1501))
problems += save_battle(m, spawns, 1, 'vespera', 1, grade="slate", haze="heavy")

# 2. The Forgotten Cemetery (16 x 24)
m = Map(16, 24, "Vespera 2: The Forgotten Cemetery. Old graves under cypresses, mausoleums, iron fences and a cold mist; a stair down into the catacombs at the far end")
m.box(0, 15, 0, 23, 'h', 0)
m.box(0, 15, 0, 3, 'g', 0)
for y in range(24): m.set(15, y, 'q', 4); m.set(14, y, 'q', 3)
m.house(9, 13, 5, 8, 3, 'c', (9, 6)); m.house(2, 5, 11, 15, 3, 'c', (5, 13)); m.house(10, 13, 15, 19, 3, 'c', (10, 17))        # mausoleums
for (x0, x1, y0, y1) in [(0, 2, 6, 7), (7, 8, 9, 9), (6, 7, 13, 13), (12, 13, 10, 11), (1, 2, 17, 18), (7, 8, 20, 21), (13, 14, 0, 2)]:
    m.box(x0, x1, y0, y1, 't', 0)
m.box(0, 5, 9, 9, 'q', 1); m.box(8, 13, 12, 12, 'q', 1); m.box(0, 4, 19, 19, 'q', 1)      # iron fences, low, with gaps
m.box(4, 10, 21, 23, 'M', 1); m.box(6, 8, 22, 23, 'M', 2)                                   # the stair-house
spawns = {"king": [6, 2], "captain": [8, 2], "stones": [[4, 1], [10, 1], [7, 4]],
          "enemies": [{"kind": "gknight", "at": [4, 10]}, {"kind": "mourner", "at": [10, 11]}, {"kind": "gargoyle", "at": [6, 15]}, {"kind": "mourner", "at": [3, 16]},
                      {"kind": "gknight", "at": [9, 20]}, {"kind": "gargoyle", "at": [12, 21]}, {"kind": "cguard", "at": [7, 22]}]}
decorate(m, spawns, 'y2', random.Random(1502))
problems += save_battle(m, spawns, 2, 'vespera', 2, grade="slate", haze="heavy")

# 3. The Catacombs Below (16 x 24)
m = Map(16, 24, "Vespera 3: The Catacombs Below. Burial galleries cut in the rock, niches of old bones, resonance crystals set into the walls where the souls were meant to rest")
m.box(0, 15, 0, 23, 'r', 3)
def carve(x0, x1, y0, y1, c='c'): m.box(x0, x1, y0, y1, c, 0)
carve(3, 12, 0, 5); carve(2, 5, 6, 10); carve(2, 13, 11, 15); carve(9, 12, 16, 18); carve(3, 13, 19, 23)
for (x0, x1, y0, y1, h) in [(5, 6, 12, 13, 3), (9, 10, 13, 14, 3), (6, 7, 20, 21, 3), (10, 11, 21, 22, 3), (3, 3, 4, 4, 2), (12, 12, 3, 3, 2)]:
    m.box(x0, x1, y0, y1, 'r', h)
m.box(7, 8, 14, 15, 'q', 1); m.box(4, 5, 22, 23, 'q', 1); m.box(10, 12, 11, 12, 'r', 1); m.box(3, 4, 15, 15, 'r', 1)
spawns = {"king": [7, 2], "captain": [9, 2], "stones": [[4, 1], [11, 1], [7, 4]],
          "enemies": [{"kind": "cundead", "at": [4, 12]}, {"kind": "rconstruct", "at": [11, 14]}, {"kind": "sguard", "at": [8, 12]}, {"kind": "cundead", "at": [3, 14]},
                      {"kind": "rconstruct", "at": [11, 17]}, {"kind": "sguard", "at": [5, 20]}, {"kind": "catsentinel", "at": [8, 22]}]}
decorate(m, spawns, 'y3', random.Random(1503))
problems += save_battle(m, spawns, 3, 'vespera', 3, grade="slate", haze="heavy")

# 4. The Choir of the Lost (16 x 20)
m = Map(16, 20, "Vespera 4: The Choir of the Lost. A vaulted chamber under the tower, crystals ranked along both walls, captured lights drifting between them")
m.box(0, 15, 0, 19, 'M', 0)
for y in range(20): m.set(15, y, 'q', 5); m.set(14, y, 'q', 4)
m.box(0, 1, 0, 19, 'q', 3)
m.box(5, 10, 13, 18, 'o', 1); m.box(6, 9, 14, 18, 'o', 2); m.box(7, 8, 16, 18, 'e', 3)
m.box(3, 5, 7, 8, 'q', 3); m.box(10, 12, 7, 8, 'q', 3); m.box(6, 9, 9, 9, 'q', 2); m.box(2, 3, 12, 13, 'q', 2); m.box(12, 13, 12, 13, 'q', 2)
spawns = {"king": [6, 2], "captain": [8, 2], "stones": [[4, 1], [10, 1], [7, 4]],
          "enemies": [{"kind": "captured", "at": [5, 11]}, {"kind": "captured", "at": [10, 11]}, {"kind": "crystalguard", "at": [7, 12]}, {"kind": "captured", "at": [3, 15]},
                      {"kind": "choirsentinel", "at": [12, 15]}, {"kind": "crystalguard", "at": [4, 17]}, {"kind": "choirsentinel", "at": [11, 17]}]}
decorate(m, spawns, 'y4', random.Random(1504))
problems += save_battle(m, spawns, 4, 'vespera', 4, grade="slate", haze="heavy")

# 5. The Last Toll (16 x 18)
m = Map(16, 18, "Vespera 5: The Last Toll. The top of the great bell tower: a round stone floor under the open belfry, the bell on its frame at the far side, wind and torchlight")
m.box(0, 15, 0, 17, 'M', 0)
for y in range(18): m.set(15, y, 'q', 4); m.set(14, y, 'q', 3)
m.box(0, 1, 0, 17, 'q', 2); m.box(2, 13, 0, 0, 'q', 1)
m.box(5, 10, 12, 17, 'o', 1); m.box(6, 9, 13, 17, 'o', 2); m.box(7, 8, 15, 17, 'e', 3)          # the bell's frame and platform
m.box(3, 4, 6, 7, 'q', 3); m.box(11, 12, 6, 7, 'q', 3); m.box(0, 8, 9, 9, 'q', 2); m.box(1, 3, 10, 11, 'q', 2); m.box(12, 14, 10, 11, 'q', 2)
spawns = {"king": [6, 2], "captain": [8, 2], "stones": [[4, 1], [10, 1], [7, 4]],
          "enemies": [{"kind": "malrec", "at": [7, 16]}, {"kind": "bellconstruct", "at": [4, 11]}, {"kind": "bellconstruct", "at": [11, 11]}, {"kind": "crystalspirit", "at": [3, 14]},
                      {"kind": "crystalspirit", "at": [12, 14]}, {"kind": "bellsentinel", "at": [6, 11]}, {"kind": "bellsentinel", "at": [9, 11]}]}
decorate(m, spawns, 'y5', random.Random(1505))
problems += save_battle(m, spawns, 5, 'vespera', 5, grade="slate", haze="light")

# scene stage: the city square at dusk
t = Map(16, 24, "Vespera: the city square at dusk. Cobbled streets between tall houses, bell towers with their bells silent, lanterns coming on in the fog")
t.box(0, 15, 0, 23, 's', 0)
t.house(10, 15, 0, 5, 5, 'c', (10, 3)); t.house(11, 15, 9, 14, 6, 'd', (11, 11)); t.house(10, 15, 18, 23, 5, 'c', (10, 20)); t.house(0, 2, 3, 7, 4, 'd', (2, 5)); t.house(0, 2, 16, 20, 4, 'c', (2, 18))
t.box(4, 9, 8, 15, 'M', 0)
t.smooth()
tspawns = {"king": [6, 2], "captain": [8, 2], "stones": [[4, 1], [10, 1], [7, 4]], "enemies": [{"kind": "wander", "at": [7, 20]}]}
decorate(t, tspawns, 'yc', random.Random(1506)); t.extra['grade'] = 'slate'; t.extra['haze'] = 'heavy'
OUT = 'godot/samples/%s.json'; t.save('vespera_city', None)
print('\nTOTAL PROBLEMS:', len(problems))
