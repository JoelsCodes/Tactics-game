#!/usr/bin/env python3
"""Writes chapter nine's maps: godot/samples/palace_1..5.json (the battles) and the scene stages palace_throne.json (the empty throne room), palace_garden.json (the royal garden
and the grave) and palace_hill.json (the hill at night). The King's quiet chambers reuse palace.json (make_late_maps.py). Run from the repo root:
  python3 godot/tools/make_palace_maps.py
  1 The Royal Hall           16x26  columns, stairs and ceremonial furniture under tall windows
  2 The King's Shield        16x22  a fortified corridor with barricades, built for a shield wall
  3 The Hall of Ancestors    16x26  a long ceremonial hall of statues and ward-stones
  4 The Crown's Last Stand   16x24  the last chamber: raised platforms, banners, imposing walls
  5 The Last King            16x20  the inner throne chamber: a round dais, tall windows, little else
"""
import random
src = open('godot/tools/make_riverford_maps.py').read()
exec(src[:src.index("rnd = random.Random")])   # Map, preview, check, finish
exec(open('godot/tools/life_kit.py').read())   # decorate()
MOVE.update({'hinf': 4, 'hhalb': 3, 'hspell': 4, 'harcher': 4, 'hofficer': 4, 'sknight': 3, 'sguard': 5, 'smage': 4, 'shalb': 3, 'scmd': 4, 'statue': 3, 'ancarmor': 4,
             'sentinel': 3, 'gconstruct': 3, 'champion': 4, 'cspell': 4, 'cswords': 5, 'honor': 4, 'ccmd': 4, 'king': 5})
problems = []
OUT = 'godot/samples/palace_%s.json'

# 1. The Royal Hall (16 x 26)
m = Map(16, 26, "Palace 1: The Royal Hall. A long reception hall: columns down both sides, a stair to a gallery, long tables and a carpeted aisle under tall windows")
m.box(0, 15, 0, 25, 'M', 0)
for y in range(26): m.set(15, y, 'q', 6); m.set(14, y, 'q', 5)
m.box(5, 9, 0, 25, 'o', 0)                                                    # the carpet
for y in (5, 10, 15, 20): m.box(2, 2, y, y, 'q', 4); m.box(12, 12, y, y, 'q', 4)   # columns
m.box(10, 13, 4, 6, 'M', 1); m.box(11, 13, 5, 6, 'M', 2)                      # a stair to the gallery
m.box(0, 3, 13, 17, 'q', 2); m.box(11, 13, 17, 19, 'q', 2); m.box(6, 8, 9, 9, 'q', 1)       # long tables
m.box(0, 9, 8, 8, 'q', 2); m.box(6, 13, 13, 13, 'q', 2)                       # screens and furniture, gaps at the ends
m.box(4, 11, 21, 25, 'o', 1); m.box(6, 9, 22, 25, 'o', 2); m.box(6, 13, 18, 18, 'q', 2); m.box(0, 7, 16, 16, 'q', 2)
spawns = {"king": [6, 2], "captain": [8, 2], "stones": [[4, 1], [10, 1], [7, 4]],
          "enemies": [{"kind": "hinf", "at": [4, 11]}, {"kind": "hinf", "at": [10, 11]}, {"kind": "harcher", "at": [12, 14]}, {"kind": "hhalb", "at": [6, 15]},
                      {"kind": "hspell", "at": [9, 17]}, {"kind": "harcher", "at": [3, 18]}, {"kind": "hhalb", "at": [8, 20]}, {"kind": "hofficer", "at": [7, 23]}]}
decorate(m, spawns, 'f1', random.Random(1701))
problems += finish(m, spawns, 1, grade="golden", haze="light")

# 2. The King's Shield (16 x 22)
m = Map(16, 22, "Palace 2: The King's Shield. A fortified corridor to the royal chambers, barricaded for a shield wall with alcoves for archers and mages")
m.box(0, 15, 0, 21, 'M', 0)
for y in range(22): m.set(15, y, 'q', 6); m.set(14, y, 'q', 5)
m.box(0, 2, 0, 21, 'q', 4); m.box(3, 3, 0, 21, 'q', 1)
m.box(0, 8, 9, 10, 'q', 3); m.box(10, 13, 14, 15, 'q', 3); m.box(0, 5, 17, 17, 'q', 3); m.box(7, 13, 5, 5, 'q', 2)           # barricades with gaps at the far ends
m.box(10, 13, 6, 8, 'M', 1); m.box(11, 13, 7, 7, 'M', 2); m.box(1, 3, 12, 14, 'M', 1)          # alcoves
m.box(4, 11, 18, 21, 'o', 1); m.box(6, 9, 19, 21, 'o', 2)
spawns = {"king": [6, 2], "captain": [8, 2], "stones": [[4, 1], [10, 1], [7, 4]],
          "enemies": [{"kind": "sknight", "at": [9, 12]}, {"kind": "sknight", "at": [5, 13]}, {"kind": "smage", "at": [12, 12]}, {"kind": "sguard", "at": [8, 15]},
                      {"kind": "shalb", "at": [6, 19]}, {"kind": "smage", "at": [10, 18]}, {"kind": "sguard", "at": [4, 16]}, {"kind": "scmd", "at": [7, 20]}]}
decorate(m, spawns, 'f2', random.Random(1702))
problems += finish(m, spawns, 2, grade="golden", haze="light")

# 3. The Hall of Ancestors (16 x 26)
m = Map(16, 26, "Palace 3: The Hall of Ancestors. A long ceremonial hall: statues of kings on plinths, portraits and plaques, ward-stones set in the floor that begin to glow")
m.box(0, 15, 0, 25, 'M', 0)
for y in range(26): m.set(15, y, 'q', 6); m.set(14, y, 'q', 5)
for y in range(3, 25, 3): m.box(1, 1, y, y, 'q', 4); m.box(13, 13, y, y, 'q', 4)                    # statues
m.box(5, 9, 0, 25, 'k', 0)                                                                            # the old stone of the aisle
for (x, y) in [(3, 8), (12, 8), (3, 17), (12, 17)]: m.box(x, x, y, y, 'e', 1)                        # ward-stones
m.box(0, 7, 11, 11, 'q', 2); m.box(8, 13, 15, 15, 'q', 2); m.box(0, 5, 20, 20, 'q', 2); m.box(2, 9, 8, 8, 'q', 2); m.box(7, 13, 19, 19, 'q', 2)
m.box(4, 11, 21, 25, 'o', 1); m.box(6, 9, 22, 25, 'o', 2)
spawns = {"king": [6, 2], "captain": [8, 2], "stones": [[4, 1], [10, 1], [7, 4]],
          "enemies": [{"kind": "statue", "at": [4, 13]}, {"kind": "statue", "at": [10, 13]}, {"kind": "ancarmor", "at": [7, 14]}, {"kind": "sentinel", "at": [11, 18]},
                      {"kind": "ancarmor", "at": [4, 19]}, {"kind": "sentinel", "at": [7, 18]}, {"kind": "statue", "at": [9, 21]}, {"kind": "gconstruct", "at": [7, 24]}]}
decorate(m, spawns, 'f3', random.Random(1703))
problems += finish(m, spawns, 3, grade="slate", haze="light")

# 4. The Crown's Last Stand (16 x 24)
m = Map(16, 24, "Palace 4: The Crown's Last Stand. The last chamber before the King's: raised platforms for the champions, banners, heavy walls, a stair up to the inner doors")
m.box(0, 15, 0, 23, 'M', 0)
for y in range(24): m.set(15, y, 'q', 6); m.set(14, y, 'q', 5)
m.box(1, 4, 8, 12, 'M', 2); m.box(2, 3, 9, 11, 'M', 3); m.box(11, 14, 8, 12, 'M', 2); m.box(12, 13, 9, 11, 'M', 3)        # platforms
m.box(5, 10, 14, 17, 'o', 1); m.box(6, 9, 15, 17, 'o', 2)
m.box(4, 11, 19, 23, 'o', 2); m.box(6, 9, 20, 23, 'e', 3); m.box(5, 10, 18, 18, 'o', 1)
m.box(0, 7, 6, 6, 'q', 3); m.box(8, 13, 13, 13, 'q', 3); m.box(0, 4, 18, 18, 'q', 3)
for (x, y) in [(5, 9), (10, 9), (3, 14), (12, 15)]: m.box(x, x, y, y, 'q', 3)
spawns = {"king": [6, 2], "captain": [8, 2], "stones": [[4, 1], [10, 1], [7, 4]],
          "enemies": [{"kind": "champion", "at": [4, 12]}, {"kind": "champion", "at": [11, 12]}, {"kind": "cswords", "at": [6, 12]}, {"kind": "cspell", "at": [9, 15]},
                      {"kind": "honor", "at": [5, 16]}, {"kind": "cspell", "at": [11, 19]}, {"kind": "honor", "at": [8, 18]}, {"kind": "cswords", "at": [4, 21]}, {"kind": "ccmd", "at": [7, 22]}]}
decorate(m, spawns, 'f4', random.Random(1704))
problems += finish(m, spawns, 4, grade="golden", haze="light")

# 5. The Last King (16 x 20)
m = Map(16, 20, "Palace 5: The Last King. The inner throne chamber: a round dais of pale stone under tall windows, pillars along the walls and nothing between the two men but open floor")
m.box(0, 15, 0, 19, 'M', 0)
for y in range(20): m.set(15, y, 'q', 6); m.set(14, y, 'q', 5)
m.box(4, 11, 13, 19, 'o', 1); m.box(5, 10, 14, 19, 'o', 2); m.box(6, 9, 16, 19, 'e', 3)
for (x, y) in [(2, 6), (13, 6), (2, 11), (13, 11)]: m.box(x, x, y, y, 'q', 4)
m.box(0, 6, 8, 8, 'q', 2); m.box(8, 13, 9, 9, 'q', 2); m.box(4, 5, 5, 5, 'q', 1); m.box(10, 11, 4, 4, 'q', 1); m.box(0, 8, 12, 12, 'q', 2)
spawns = {"king": [6, 2], "captain": [8, 2], "stones": [[4, 1], [10, 1], [7, 4]],
          "enemies": [{"kind": "king", "at": [7, 16]}, {"kind": "honor", "at": [4, 13]}, {"kind": "honor", "at": [11, 13]}, {"kind": "gconstruct", "at": [11, 11]}]}
decorate(m, spawns, 'f5', random.Random(1705))
problems += finish(m, spawns, 5, grade="golden", haze="light")

# scene stage: the empty throne room
t = Map(16, 24, "Palace: the great throne room, empty. Tall windows, pale light on polished stone, royal banners, and at the far end the throne")
t.box(0, 15, 0, 23, 'M', 0)
for y in range(24): t.set(15, y, 'q', 6); t.set(14, y, 'q', 5)
t.box(5, 9, 0, 23, 'o', 0); t.box(3, 12, 18, 23, 'o', 2); t.box(5, 10, 19, 23, 'e', 3)
for y in (4, 9, 14): t.box(1, 1, y, y, 'q', 4); t.box(13, 13, y, y, 'q', 4)
t.smooth()
tspawns = {"king": [6, 2], "captain": [8, 2], "stones": [[4, 1], [10, 1], [7, 4]], "enemies": [{"kind": "hinf", "at": [8, 20]}]}
decorate(t, tspawns, 'ft', random.Random(1706)); t.extra['grade'] = 'golden'; t.extra['haze'] = 'light'
OUT = 'godot/samples/%s.json'; t.save('palace_throne', None)

# scene stage: the royal garden and the grave
t = Map(16, 24, "Palace: the royal garden behind the palace. Gravel paths, hedges and old trees; one simple stone with fresh flowers beside it")
t.box(0, 15, 0, 23, 'g', 0)
t.box(5, 9, 0, 23, 'd', 0); t.box(2, 12, 11, 12, 'd', 0)
for y in range(24): t.set(15, y, 'q', 4); t.set(14, y, 'q', 3)
for (x0, x1, y0, y1) in [(0, 2, 3, 6), (12, 14, 4, 8), (0, 3, 17, 21), (11, 13, 16, 20)]: t.box(x0, x1, y0, y1, 't', 0)
t.box(8, 11, 14, 14, 'q', 1)                                                    # the low wall by the plot
t.smooth()
tspawns = {"king": [6, 2], "captain": [8, 2], "stones": [[4, 1], [10, 1], [7, 4]], "enemies": [{"kind": "hinf", "at": [8, 20]}]}
decorate(t, tspawns, 'fg', random.Random(1707)); t.extra['grade'] = 'golden'; t.extra['haze'] = 'light'
t.save('palace_garden', None)

# scene stage: the hill at night
t = Map(16, 24, "Palace: a hill above the capital at night. Dark grass, a ring of old stones, and the lights of the palace far below")
t.box(0, 15, 0, 23, 'g', 0)
t.box(5, 9, 0, 23, 'd', 0)
for y in range(24): t.set(15, y, 'r', 4); t.set(14, y, 'r', 3)
t.box(9, 13, 14, 20, 'g', 1); t.box(10, 12, 15, 19, 'g', 2)
for (x, y) in [(9, 15), (9, 19), (13, 15), (13, 19), (11, 17)]: t.set(x, y, 'q', 3)
t.smooth()
tspawns = {"king": [6, 2], "captain": [8, 2], "stones": [[4, 1], [10, 1], [7, 4]], "enemies": [{"kind": "hinf", "at": [8, 20]}]}
decorate(t, tspawns, 'fh', random.Random(1708)); t.extra['grade'] = 'dusk'; t.extra['haze'] = 'heavy'
t.save('palace_hill', None)
print('\nTOTAL PROBLEMS:', len(problems))
