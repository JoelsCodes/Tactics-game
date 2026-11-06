#!/usr/bin/env python3
"""Writes chapter eleven's maps: godot/samples/falcon_1..5.json (the battles) and the scene stage falcon_village.json (Greyhaven). Run from the repo root:
  python3 godot/tools/make_falcon_maps.py
  1 The Ashes Return       16x22  the fields and hedgerows at Greyhaven's edge, burned cottages, a lane
  2 The Broken Farmlands   16x24  furrowed fields, fences, a stream, a barn and a field shed
  3 The Last Falcon        16x22  an abandoned watchtower on a rise, its yard walled, a gate
  4 The Army Without Graves 16x24 an abandoned encampment: palisade, tent rows, a parade ground
  5 The Dead King's Army   16x24  the open ground outside Greyhaven: a ridge, a ford, the road in
"""
import random
src = open('godot/tools/make_riverford_maps.py').read()
exec(src[:src.index("rnd = random.Random")])   # Map, preview, check, finish
exec(open('godot/tools/life_kit.py').read())   # decorate()
MOVE.update({'fsword': 5, 'fspear': 4, 'farcher': 4, 'fshield': 3, 'fheavy': 3, 'fcav': 6, 'fmage': 4, 'fhonor': 4, 'fstd': 4, 'fofficer': 4, 'fcapt': 4, 'fcons': 3,
             'tboar': 5, 'twolf': 6, 'vaelor': 4, 'vaelor2': 4})
problems = []
OUT = 'godot/samples/falcon_%s.json'
SP = lambda en: {"king": [6, 2], "captain": [8, 2], "stones": [[4, 1], [10, 1], [7, 4]], "enemies": [{"kind": k, "at": list(a)} for k, a in en]}

# 1. The Ashes Return (16 x 22)
m = Map(16, 22, "Falcon 1: The Ashes Return. The fields at Greyhaven's edge: hedgerows, a lane, the blackened walls of two cottages, the Falcon Guard drawn up in the lane")
m.box(0, 15, 0, 21, 'g', 0)
m.box(5, 10, 0, 21, 'd', 0)
for (x0, x1, y0, y1) in [(0, 3, 3, 6), (12, 14, 4, 7), (13, 14, 11, 14), (0, 2, 10, 13), (12, 14, 17, 20)]:
    m.box(x0, x1, y0, y1, 't', 0)
m.box(0, 9, 9, 9, 'q', 2); m.box(6, 15, 13, 13, 'q', 2); m.box(0, 9, 17, 17, 'q', 2); m.box(1, 2, 19, 20, 'q', 1)
m.smooth()
sp = SP([('fsword', (4, 11)), ('fsword', (9, 11)), ('farcher', (12, 14)), ('fshield', (6, 15)), ('fshield', (9, 16)), ('farcher', (3, 18)), ('fofficer', (7, 20))])
decorate(m, sp, 'k1', random.Random(1901))
problems += finish(m, sp, 1, grade="dusk", haze="light")

# 2. The Broken Farmlands (16 x 24)
m = Map(16, 24, "Falcon 2: The Broken Farmlands. Furrowed fields cut by fences and a stream, a barn and a field shed; the Falcon Guard hold the far hedge")
m.box(0, 15, 0, 23, 'g', 0)
m.box(1, 13, 0, 23, 'd', 0)
m.box(0, 15, 8, 9, 'W', 0); m.box(10, 12, 8, 9, 'b', 0)
for (x0, x1, y0, y1) in [(0, 2, 3, 6), (13, 15, 12, 15), (0, 3, 17, 20)]:
    m.box(x0, x1, y0, y1, 't', 0)
m.box(0, 8, 13, 13, 'q', 2); m.box(7, 13, 16, 16, 'q', 2); m.box(2, 5, 19, 21, 'q', 3); m.box(10, 13, 20, 21, 'q', 2); m.box(4, 12, 11, 11, 'q', 1)
m.smooth()
sp = SP([('fspear', (3, 12)), ('fspear', (11, 14)), ('farcher', (6, 15)), ('tboar', (5, 17)), ('fcons', (9, 18)), ('twolf', (12, 18)), ('fcons', (7, 20)), ('fcapt', (8, 22))])
decorate(m, sp, 'm2', random.Random(1902))
problems += finish(m, sp, 2, grade="golden", haze="light")

# 3. The Last Falcon (16 x 22)
m = Map(16, 22, "Falcon 3: The Last Falcon. An abandoned watchtower on a rise, a walled yard before it and one gate, banners the dead have hung again")
m.box(0, 15, 0, 21, 'g', 0)
m.box(5, 10, 0, 21, 'd', 0)
m.box(2, 13, 12, 21, 's', 1); m.box(4, 11, 15, 21, 's', 2); m.box(6, 9, 18, 21, 's', 3)
m.box(4, 15, 10, 10, 'q', 3); m.box(0, 8, 13, 13, 'q', 3); m.box(7, 15, 16, 16, 'q', 3)   # the yard wall (the gate is at the left), then a second wall and a third
m.box(0, 3, 6, 7, 't', 0); m.box(12, 14, 4, 6, 't', 0)
m.box(7, 8, 6, 7, 'q', 1); m.smooth()
sp = SP([('fhonor', (4, 14)), ('fhonor', (11, 13)), ('farcher', (3, 17)), ('fshield', (8, 15)), ('farcher', (12, 17)), ('vaelor', (7, 19))])
decorate(m, sp, 'm4', random.Random(1903))
problems += finish(m, sp, 3, grade="dusk", haze="light")

# 4. The Army Without Graves (16 x 24)
m = Map(16, 24, "Falcon 4: The Army Without Graves. An abandoned encampment: a broken palisade, rows of collapsed tents, a parade ground where the dead drill without noise")
m.box(0, 15, 0, 23, 'd', 0)
m.box(0, 15, 0, 3, 'g', 0)
for y in range(24): m.set(15, y, 'q', 3)
m.box(2, 14, 8, 8, 'q', 3)                                                          # the palisade, the gap at the left
m.box(1, 4, 11, 12, 'q', 1); m.box(10, 13, 11, 12, 'q', 1); m.box(1, 3, 16, 17, 'q', 1); m.box(11, 13, 16, 17, 'q', 1)  # tent rows
m.box(0, 9, 14, 14, 'q', 2); m.box(0, 6, 19, 19, 'q', 2); m.box(9, 14, 20, 20, 'q', 2)
m.box(5, 10, 21, 23, 'm', 1); m.box(6, 9, 22, 23, 'm', 2)
m.smooth()
sp = SP([('fheavy', (4, 13)), ('fheavy', (11, 14)), ('fcav', (7, 13)), ('fmage', (9, 17)), ('farcher', (3, 15)), ('fcav', (12, 18)), ('fmage', (5, 20)), ('fstd', (7, 22))])
decorate(m, sp, 'm3', random.Random(1904))
problems += finish(m, sp, 4, grade="dusk", haze="light")

# 5. The Dead King's Army (16 x 24)
m = Map(16, 24, "Falcon 5: The Dead King's Army. The open ground outside Greyhaven: a ridge across the road, a ford, hedges, the village roofs behind the Falcon Guard's line")
m.box(0, 15, 0, 23, 'g', 0)
m.box(5, 10, 0, 23, 'd', 0)
m.box(0, 15, 6, 7, 'W', 0); m.box(6, 9, 6, 7, 'b', 0)
m.box(3, 12, 15, 23, 'g', 1); m.box(5, 10, 18, 23, 'g', 2); m.box(6, 9, 20, 23, 'g', 3)
for (x0, x1, y0, y1) in [(0, 2, 18, 21), (13, 15, 17, 21)]:
    m.box(x0, x1, y0, y1, 't', 0)
m.box(0, 9, 10, 10, 'q', 2); m.box(6, 14, 14, 14, 'q', 2); m.box(0, 9, 16, 16, 'q', 2); m.box(10, 14, 19, 19, 'q', 2)
m.smooth()
sp = SP([('fheavy', (4, 14)), ('fheavy', (11, 13)), ('fcav', (7, 13)), ('farcher', (3, 17)), ('farcher', (12, 17)), ('fmage', (9, 18)), ('fhonor', (5, 20)), ('fhonor', (10, 21)), ('vaelor2', (7, 22))])
decorate(m, sp, 'k1', random.Random(1905))
problems += finish(m, sp, 5, grade="dusk", haze="light")

OUT = 'godot/samples/%s.json'
t = Map(16, 24, "Falcon: Greyhaven, damaged but lived-in. Cottages with scorched walls and mended roofs, a well, a lane, fields beyond")
t.box(0, 15, 0, 23, 'g', 0); t.box(5, 10, 0, 23, 'd', 0); t.box(3, 12, 10, 13, 'd', 0)
for (x0, x1, y0, y1) in [(0, 3, 3, 7), (12, 14, 4, 8), (0, 3, 15, 20), (12, 14, 15, 20)]: t.box(x0, x1, y0, y1, 'q', 2)
for y in range(24): t.set(15, y, 'q', 3)
t.smooth()
ts = SP([('fsword', (8, 20))])
decorate(t, ts, 'kc', random.Random(1906)); t.extra['grade'] = 'golden'; t.extra['haze'] = 'light'
t.save('falcon_village', None)
print('\nTOTAL PROBLEMS:', len(problems))
