#!/usr/bin/env python3
"""Writes chapter ten's maps: godot/samples/ashes_1..5.json (the battles) and the scene stages ashes_town.json (a town square), ashes_memorial.json (the Falcon Guard memorial
chamber) and ashes_night.json (a dark room above the city, for Reave's private scene). Run from the repo root:
  python3 godot/tools/make_ashes_maps.py
  1 The Broken Road        16x24  a ruined road: a washed-out bridge, fallen walls, trees, a deserters' roadblock
  2 The Memorial Approach  16x24  a paved avenue of broken monuments to the fortress gate, rock on both sides
  3 The Forgotten Sentinels 16x24 the fortress's inner hall: pillars, alcoves, sealed doors
  4 The Stolen Dead        16x22  the memorial courtyard: monuments of the fallen, a stair, graves
  5 The Last Sentinel      16x22  the central vault: a dais, cracked floor, pillars about to fall
"""
import random
src = open('godot/tools/make_riverford_maps.py').read()
exec(src[:src.index("rnd = random.Random")])   # Map, preview, check, finish
exec(open('godot/tools/life_kit.py').read())   # decorate()
MOVE.update({'dsword': 4, 'dscav': 3, 'wolf': 6, 'dxbow': 4, 'dcap': 4, 'rustc': 3, 'sbeast': 4, 'aweapon': 5, 'mguard': 3, 'asent': 3, 'rstat': 3, 'tcons': 4, 'fsword': 5, 'farcher': 4,
             'fshield': 3, 'fofficer': 4, 'lsent': 3, 'rconst': 3, 'eguard': 4, 'arcsent': 4})
problems = []
OUT = 'godot/samples/ashes_%s.json'
SP = lambda en: {"king": [6, 2], "captain": [8, 2], "stones": [[4, 1], [10, 1], [7, 4]], "enemies": [{"kind": k, "at": list(a)} for k, a in en]}

# 1. The Broken Road (16 x 24)
m = Map(16, 24, "Ashes 1: The Broken Road. A royal road gone to ruin: a washed-out bridge, fallen wall sections, dead trees, and a deserters' roadblock across the way")
m.box(0, 15, 0, 23, 'g', 0)
m.box(5, 10, 0, 23, 'd', 0)
for (x0, x1, y0, y1) in [(0, 3, 4, 8), (12, 14, 3, 6), (13, 14, 10, 13), (0, 2, 12, 16), (12, 14, 18, 22), (0, 3, 19, 23), (14, 15, 0, 23)]:
    m.box(x0, x1, y0, y1, 't', 0)
m.box(0, 15, 9, 10, 'W', 0); m.box(3, 4, 9, 10, 'b', 0)                         # a stream; the one bridge is off to the left
m.box(0, 5, 14, 14, 'q', 2); m.box(6, 13, 16, 16, 'q', 2); m.box(7, 12, 12, 12, 'q', 2); m.box(0, 4, 19, 19, 'q', 1)  # fallen walls
m.box(11, 13, 20, 21, 'g', 1); m.box(2, 4, 16, 17, 'g', 1)
m.smooth()
sp = SP([('dsword', (4, 13)), ('dsword', (9, 13)), ('dxbow', (12, 15)), ('wolf', (3, 17)), ('dscav', (8, 18)), ('wolf', (11, 19)), ('dscav', (5, 21)), ('dcap', (8, 22))])
decorate(m, sp, 'm1', random.Random(1801))
problems += finish(m, sp, 1, grade="dusk", haze="light")

# 2. The Memorial Approach (16 x 24)
m = Map(16, 24, "Ashes 2: The Memorial Approach. A paved avenue of toppled monuments climbing to the fortress gate, rock walls either side, rusted weapons in the grass")
m.box(0, 15, 0, 23, 'r', 1)
m.box(2, 13, 0, 23, 's', 0)
m.box(5, 10, 0, 23, 's', 0)
for y in range(3, 22, 4): m.box(3, 3, y, y, 'q', 3); m.box(12, 12, y, y, 'q', 3)                  # monuments
m.box(2, 8, 8, 8, 'q', 2); m.box(7, 13, 12, 12, 'q', 2); m.box(2, 9, 16, 16, 'q', 2); m.box(8, 13, 19, 19, 'q', 2)
m.box(4, 11, 20, 23, 's', 1); m.box(6, 9, 21, 23, 's', 2)
m.smooth()
sp = SP([('rustc', (5, 12)), ('rustc', (10, 13)), ('aweapon', (7, 14)), ('sbeast', (4, 17)), ('sbeast', (11, 17)), ('aweapon', (9, 18)), ('rustc', (6, 20)), ('mguard', (8, 22))])
decorate(m, sp, 'm4', random.Random(1802))
problems += finish(m, sp, 2, grade="dusk", haze="light")

# 3. The Forgotten Sentinels (16 x 24)
m = Map(16, 24, "Ashes 3: The Forgotten Sentinels. The fortress's inner hall: pillars, alcoves with sealed doors, an aisle of old flagstones and the archive gate at the far end")
m.box(0, 15, 0, 23, 'M', 0)
for y in range(24): m.set(15, y, 'q', 6); m.set(14, y, 'q', 5)
m.box(5, 9, 0, 23, 'k', 0)
for y in (4, 9, 14, 19): m.box(2, 2, y, y, 'q', 4); m.box(12, 12, y, y, 'q', 4)
m.box(0, 7, 7, 7, 'q', 2); m.box(8, 13, 11, 11, 'q', 2); m.box(0, 6, 15, 15, 'q', 2); m.box(8, 13, 17, 17, 'q', 2)
m.box(0, 3, 21, 22, 'q', 2); m.box(11, 13, 21, 22, 'q', 2)
m.box(4, 11, 20, 23, 'o', 1); m.box(6, 9, 21, 23, 'o', 2)
sp = SP([('asent', (4, 11)), ('tcons', (10, 12)), ('rstat', (7, 13)), ('tcons', (3, 17)), ('asent', (11, 16)), ('rstat', (7, 18)), ('tcons', (10, 19)), ('mguard', (7, 22))])
decorate(m, sp, 'f3', random.Random(1803))
problems += finish(m, sp, 3, grade="slate", haze="light")

# 4. The Stolen Dead (16 x 22)
m = Map(16, 22, "Ashes 4: The Stolen Dead. The memorial courtyard: monuments to the fallen, a stair up to the names wall, graves in rows, the Falcon Guard's banners")
m.box(0, 15, 0, 21, 's', 0)
for y in range(22): m.set(15, y, 'q', 5); m.set(14, y, 'q', 4)
m.box(5, 10, 0, 21, 'k', 0)
for (x, y) in [(2, 5), (2, 10), (2, 15), (12, 5), (12, 10), (12, 15)]: m.box(x, x, y, y, 'q', 3)
m.box(0, 7, 8, 8, 'q', 2); m.box(8, 13, 12, 12, 'q', 2); m.box(0, 5, 15, 15, 'q', 2)
m.box(3, 12, 17, 21, 'M', 1); m.box(5, 10, 18, 21, 'M', 2)
m.box(8, 13, 18, 18, 'q', 2); m.box(4, 13, 6, 6, 'q', 2); m.box(0, 6, 19, 19, 'q', 2)
sp = SP([('fsword', (4, 11)), ('fshield', (9, 11)), ('farcher', (12, 14)), ('fsword', (7, 14)), ('fshield', (3, 18)), ('farcher', (10, 17)), ('fofficer', (7, 20))])
decorate(m, sp, 'm4', random.Random(1804))
problems += finish(m, sp, 4, grade="dusk", haze="light")

# 5. The Last Sentinel (16 x 22)
m = Map(16, 22, "Ashes 5: The Last Sentinel. The memorial's central vault: a round dais, a cracked floor, pillars carved with the regiment's falcon, ancient guardians along the walls")
m.box(0, 15, 0, 21, 'M', 0)
for y in range(22): m.set(15, y, 'q', 6); m.set(14, y, 'q', 5)
m.box(4, 11, 12, 21, 'o', 1); m.box(5, 10, 13, 21, 'o', 2); m.box(6, 9, 15, 21, 'e', 3)
for (x, y) in [(2, 6), (13, 6), (2, 10), (13, 10)]: m.box(x, x, y, y, 'q', 4)
m.box(0, 7, 8, 8, 'q', 2); m.box(9, 13, 9, 9, 'q', 2); m.box(0, 4, 12, 12, 'q', 2); m.box(11, 13, 12, 12, 'q', 2); m.box(4, 5, 4, 5, 'q', 1); m.box(10, 11, 5, 6, 'q', 1); m.box(0, 6, 10, 10, 'q', 2); m.box(5, 13, 15, 15, 'q', 2)
sp = SP([('lsent', (7, 17)), ('rconst', (4, 13)), ('eguard', (11, 13)), ('arcsent', (3, 11)), ('arcsent', (12, 17))])
decorate(m, sp, 'f5', random.Random(1805))
problems += finish(m, sp, 5, grade="dusk", haze="light")

OUT = 'godot/samples/%s.json'
def stage(name, w, d, text, build, key, grade, haze):
    t = Map(w, d, text); build(t); t.smooth()
    ts = SP([('dsword', (8, d - 4))])
    decorate(t, ts, key, random.Random(hash(name) % 9999)); t.extra['grade'] = grade; t.extra['haze'] = haze
    t.save(name, None)

def town(t):
    t.box(0, 15, 0, 23, 'g', 0); t.box(5, 10, 0, 23, 'd', 0); t.box(3, 12, 10, 14, 'd', 0)
    for (x0, x1, y0, y1) in [(0, 3, 3, 8), (12, 14, 4, 9), (0, 3, 16, 21), (12, 14, 16, 21)]: t.box(x0, x1, y0, y1, 'q', 2)
    for y in range(24): t.set(15, y, 'q', 3)
stage('ashes_town', 16, 24, "Ashes: a town square near the memorial fortress. Low houses, a well, a dirt square where a speaker can stand", town, 'kc', 'golden', 'light')

def memorial(t):
    t.box(0, 15, 0, 23, 'M', 0); t.box(5, 9, 0, 23, 'k', 0)
    for y in range(24): t.set(15, y, 'q', 6); t.set(14, y, 'q', 5)
    for y in range(3, 22, 3): t.box(1, 1, y, y, 'q', 4); t.box(13, 13, y, y, 'q', 4)
    t.box(4, 11, 19, 23, 'o', 1)
stage('ashes_memorial', 16, 24, "Ashes: the Falcon Guard memorial chamber. Names cut into the walls, a long aisle, silent braziers", memorial, 'm4', 'slate', 'light')

def night(t):
    t.box(0, 15, 0, 23, 'M', 0); t.box(5, 9, 0, 23, 'o', 0)
    for y in range(24): t.set(15, y, 'q', 6); t.set(14, y, 'q', 5)
    t.box(0, 2, 6, 17, 'q', 3); t.box(13, 13, 6, 17, 'q', 3)
stage('ashes_night', 16, 24, "Ashes: a dark room in a house above the city, one table, one window toward the distant palace", night, 'fh', 'dusk', 'heavy')
print('\nTOTAL PROBLEMS:', len(problems))
