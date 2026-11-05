#!/usr/bin/env python3
"""Writes chapter three's maps: godot/samples/crucible_1.json .. crucible_3.json (the three battles) and crucible_bastion.json (the war table, a scene
stage). Run from the repo root: python3 godot/tools/make_crucible_maps.py

The same kit as make_riverford_maps.py (cells (x, y): x is the depth up the screen, y runs left to right) but BIG (16 deep, 32 to 40 wide: the battle
camera scrolls along them) and a tileset the game has not used before: marble M, snow n, sand a, isle k, lava l (rifts: no one can cross), with
flagstone and brick for ruins. Walls are 4 high, so they stop lines of attack.
  1 The Phalanx        16x32  a roofless arena of ancient stone: a sand floor, stepped marble stands, fallen columns, podiums, a closed gate behind the party
  2 The Pincer         16x36  a snowfield pass: scorched rune circles, marble towers on both flanks for the battle-mages, a ruined wall across the middle
  3 The Breaking Point 16x40  a marble terrace split by rifts of lava and floating isles; the Soul Warden on a dais at the far end
  4 The Price of a Soul 16x20 a round ritual chamber: the apparatus on its dais in the middle
  5 The Warden's Judgment 16x26 a courtyard with battlements, ether generators and the Warden's platform
"""
import random
src = open('godot/tools/make_riverford_maps.py').read()
exec(src[:src.index("rnd = random.Random")])   # Map, preview, check, finish
exec(open('godot/tools/life_kit.py').read())   # decorate(): braziers, banners, crystals, wisps and the weather (and their helpers)
OUT = 'godot/samples/crucible_%s.json'
MOVE.update({'phalanx': 3, 'executioner': 3, 'legionary': 4, 'runemage': 4, 'hexer': 4, 'wyvern': 6, 'vesper': 5, 'bearer': 3, 'binder': 0, 'apparatus': 0, 'soulwarden': 4, 'wardenboss': 4})
rnd = random.Random(1106)
problems = []

# ================================================================== 1. The Silent Village (was The Phalanx)  (16 x 32)  player left
m = Map(16, 32, "Crucible 1: The Phalanx. A roofless arena of ancient stone: a sand floor under stepped marble stands, fallen columns and podiums, the gate shut behind the party and arches in the east where the royal infantry pours out")
m.box(0, 15, 0, 31, 'M', 0)
m.box(2, 12, 2, 29, 'a', 0)                                     # the arena floor
for y in range(0, 32):                                          # the stands: stepped marble, three levels up at the back, one at the front kerb
    for x, lv in ((13, 1), (14, 2), (15, 3)):
        m.set(x, y, 'M', lv)
    m.set(1, y, 'M', 1); m.set(0, y, 'M', 1)
m.box(2, 12, 0, 1, 'M', 0)
for x in range(2, 13): m.set(x, 1, 'q', 5)                      # the west wall, with the gate (a closed portcullis) in its middle
m.box(6, 9, 1, 1, 'q', 4)
m.box(2, 12, 30, 31, 'q', 5); m.box(5, 6, 30, 31, 'M', 0); m.box(10, 11, 30, 31, 'M', 0)   # the east arches the infantry marches out of
# podiums with steps, fallen columns, plinths
m.box(5, 7, 11, 14, 'M', 2); m.box(4, 4, 12, 13, 'M', 1); m.box(8, 8, 12, 13, 'M', 1)
m.box(8, 10, 18, 21, 'M', 2); m.box(7, 7, 19, 20, 'M', 1); m.box(11, 11, 19, 20, 'M', 1)
for (x0, x1, y0, y1, h) in [(2, 9, 9, 9, 3), (6, 12, 24, 24, 3), (3, 5, 7, 7, 2), (10, 12, 8, 8, 2), (2, 3, 16, 16, 3), (11, 12, 15, 15, 3), (4, 4, 23, 25, 2), (9, 9, 25, 27, 2), (6, 6, 5, 5, 4), (9, 9, 5, 5, 4), (7, 7, 28, 28, 4), (12, 12, 22, 22, 4)]:
    m.box(x0, x1, y0, y1, 'q', h)
m.box(6, 9, 15, 16, 'k', 0)                                     # a carved isle-stone seal in the middle of the sand
for (x, y) in [(3, 20), (12, 11), (4, 28), (10, 3)]: m.set(x, y, 'M', 1)
spawns = {"king": [6, 4], "captain": [8, 4], "stones": [[4, 3], [10, 3], [6, 6]],
          "exit": [[5, 31], [6, 31], [10, 31], [11, 31]],   # the east arches: a lantern bearer that reaches one is carried off the map
          "enemies": [{"kind": "bearer", "at": [5, 15]}, {"kind": "bearer", "at": [9, 17]}, {"kind": "bearer", "at": [7, 20]},
                      {"kind": "phalanx", "at": [5, 18]}, {"kind": "legionary", "at": [9, 22]}, {"kind": "hexer", "at": [5, 24]}, {"kind": "executioner", "at": [8, 27]}],
          "waves": [{"round": 6, "banner": "Wardens march in through the east arches!", "line": [],
                     "enemies": [{"kind": "legionary", "at": [5, 29]}, {"kind": "legionary", "at": [10, 29]}]}]}
decorate(m, spawns, 'c1', random.Random(1200+1))
problems += finish(m, spawns, 1, grade="slate", haze="light")

# ================================================================== 2. The Lantern Convoy (was The Pincer)  (16 x 36)  player left
m = Map(16, 36, "Crucible 2: The Pincer. A snowfield pass: scorched rune circles in the snow, marble towers on both flanks where the battle-mages stand, a ruined wall across the middle with a gap at each end")
m.box(0, 15, 0, 35, 'n', 0)
for y in range(36):
    m.set(15, y, 'q', 5); m.set(14, y, 'q', 5)                    # the cliff wall behind
for x in range(16): m.set(x, 0, 'M', 1)                           # the pass's west threshold, one level up
m.box(0, 15, 1, 1, 'n', 1)
for (cx, cy, r) in [(7, 9, 3), (8, 18, 4), (7, 28, 3)]:         # the rune circles: scorched ground with a carved heart
    for x in range(16):
        for y in range(36):
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            if d <= r: m.set(x, y, 'c', 0)
    m.set(cx, cy, 'e', 1)
m.box(10, 13, 5, 12, 'M', 3); m.box(9, 9, 7, 10, 'M', 2); m.box(8, 8, 8, 9, 'M', 1)      # the north tower and its ramp
m.box(10, 13, 24, 32, 'M', 3); m.box(9, 9, 26, 29, 'M', 2); m.box(8, 8, 27, 28, 'M', 1)  # the south tower
m.box(2, 13, 15, 16, 'q', 4); m.box(5, 6, 15, 16, 'n', 0); m.box(11, 12, 15, 16, 'n', 0)   # the ruined wall across the middle: gaps at x 5-6 and x 11-12
m.box(2, 13, 20, 20, 'q', 2)
for (x0, x1, y0, y1, h) in [(3, 4, 4, 4, 2), (4, 5, 11, 11, 2), (2, 3, 25, 26, 2), (6, 7, 31, 31, 3), (12, 13, 17, 19, 2), (3, 3, 33, 34, 2)]:
    m.box(x0, x1, y0, y1, 'q', h)
for (x, y) in [(2, 8), (3, 14), (4, 22), (2, 30), (5, 34), (9, 1)]: m.set(x, y, 'M', 1)
spawns = {"king": [6, 3], "captain": [8, 3], "stones": [[4, 2], [9, 2], [7, 5]],
          "enemies": [{"kind": "binder", "at": [6, 19]}, {"kind": "binder", "at": [5, 27]}, {"kind": "binder", "at": [8, 31]},
                      {"kind": "runemage", "at": [12, 8]}, {"kind": "hexer", "at": [12, 10]}, {"kind": "runemage", "at": [12, 28]}, {"kind": "legionary", "at": [11, 30]},
                      {"kind": "phalanx", "at": [7, 22]}, {"kind": "phalanx", "at": [9, 24]}, {"kind": "wyvern", "at": [3, 32]}, {"kind": "legionary", "at": [9, 18]}],
          "waves": [{"round": 7, "banner": "The convoy's escort crests the pass.", "line": [],
                     "enemies": [{"kind": "legionary", "at": [4, 34]}, {"kind": "legionary", "at": [10, 34]}]}]}
decorate(m, spawns, 'c2', random.Random(1200+2))
problems += finish(m, spawns, 2, grade="slate", haze="heavy")

# ================================================================== 3. The Severing (was The Breaking Point)  (16 x 40)  player left
m = Map(16, 40, "Crucible 3: The Breaking Point. A marble terrace split by rifts of lava and floating isles of stone; Vesper waits on a dais at the far end, and the broken ground is the way across")
m.box(0, 15, 0, 39, 'M', 0)
for y in range(40):
    m.set(15, y, 'q', 5); m.set(14, y, 'M', 2); m.set(13, y, 'M', 1)
# two rifts of lava across the terrace, each crossed by a few narrow stone bridges; isles of stone float in the second
for (y0, y1, bridges) in [(11, 13, [(2, 3), (7, 8), (12, 13)]), (21, 24, [(4, 5), (10, 11)])]:
    for x in range(0, 15):
        for y in range(y0, y1 + 1):
            m.set(x, y, 'l', 0)
    for (xa, xb) in bridges:
        for x in range(xa, xb + 1):
            for y in range(y0, y1 + 1):
                m.set(x, y, 'k', 0)
for (x, y) in [(2, 22), (2, 23), (8, 22), (8, 23), (13, 22), (13, 23)]: m.set(x, y, 'k', 1)    # stepping stones in the second rift
# the near terrace (party): steps and ruined pillars; the middle field with broken walls; the far dais
m.box(0, 12, 2, 5, 'M', 1); m.box(3, 9, 6, 8, 'M', 1)
m.box(4, 11, 14, 19, 'M', 0)
for (x0, x1, y0, y1, h) in [(4, 4, 16, 18, 3), (9, 10, 16, 16, 3), (6, 7, 18, 18, 2), (2, 3, 6, 6, 3), (10, 11, 5, 5, 3), (3, 3, 27, 29, 3), (10, 12, 27, 27, 3), (7, 8, 29, 29, 4), (5, 6, 33, 33, 3), (11, 12, 33, 33, 3)]:
    m.box(x0, x1, y0, y1, 'q', h)
m.box(4, 11, 34, 39, 'M', 1); m.box(5, 10, 36, 39, 'o', 2); m.box(6, 9, 37, 39, 'e', 3)   # Vesper's dais
m.box(4, 4, 34, 35, 'M', 0); m.box(11, 11, 34, 35, 'M', 0)
for (x, y) in [(1, 15), (1, 28), (13, 8), (13, 30)]: m.set(x, y, 'M', 2)
spawns = {"king": [6, 3], "captain": [8, 3], "stones": [[3, 2], [10, 2], [6, 5]],
          "enemies": [{"kind": "soulwarden", "at": [8, 38]}, {"kind": "runemage", "at": [5, 31]}, {"kind": "runemage", "at": [11, 31]}, {"kind": "phalanx", "at": [7, 27]}, {"kind": "phalanx", "at": [9, 28]},
                      {"kind": "executioner", "at": [8, 33]}, {"kind": "hexer", "at": [7, 35]}],
          "waves": [{"round": 6, "banner": "The Warden's guard answers the anchors!", "line": [],
                     "enemies": [{"kind": "legionary", "at": [5, 25]}, {"kind": "legionary", "at": [11, 25]}]}]}
decorate(m, spawns, 'c3', random.Random(1200+3))
problems += finish(m, spawns, 3, grade="slate", haze="heavy")

# ================================================================== 4. The Price of a Soul  (16 x 20)  player left
m = Map(16, 20, "Crucible 4: The Price of a Soul. A round ritual chamber under the fortress: scorched floor, pillars, and in the middle the raised apparatus that holds Lyra and drinks Alaric's life")
m.box(0, 15, 0, 19, 'f', 0)
for y in range(20):
    m.set(15, y, 'q', 5); m.set(14, y, 'q', 5)
for x in range(16): m.set(x, 19, 'q', 4)
m.box(1, 13, 1, 18, 'f', 0)
for (cx, cy, r) in [(7, 10, 4)]:                                 # the ritual circle: scorched ground round the apparatus
    for x in range(16):
        for y in range(20):
            if ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5 <= r: m.set(x, y, 'c', 0)
m.box(5, 9, 8, 12, 'o', 1); m.box(6, 8, 9, 11, 'o', 2); m.set(7, 10, 'e', 3)   # the dais, stepped, and the apparatus' seat
for (x0, x1, y0, y1, h) in [(2, 3, 6, 6, 3), (2, 3, 14, 14, 3), (11, 12, 5, 5, 3), (11, 12, 15, 15, 3), (7, 7, 4, 4, 2), (7, 7, 16, 16, 2), (4, 4, 11, 11, 2), (10, 10, 9, 9, 2), (9, 10, 12, 12, 2)]:
    m.box(x0, x1, y0, y1, 'q', h)
m.box(0, 13, 0, 0, 'f', 1); m.box(3, 5, 2, 3, 'M', 1)
m.box(1, 12, 7, 7, 'q', 4); m.box(2, 3, 7, 7, 'f', 0); m.box(10, 11, 7, 7, 'f', 0)   # a chamber wall with two gaps, far from the straight line
for (x, y) in [(1, 9), (13, 4), (13, 16), (3, 18)]: m.set(x, y, 'M', 1)
spawns = {"king": [6, 2], "captain": [8, 2], "stones": [[4, 1], [10, 1], [8, 3]],
          "enemies": [{"kind": "apparatus", "at": [7, 10]}, {"kind": "phalanx", "at": [5, 14]}, {"kind": "phalanx", "at": [9, 14]},
                      {"kind": "runemage", "at": [11, 11]}, {"kind": "hexer", "at": [3, 12]}, {"kind": "legionary", "at": [8, 16]}, {"kind": "legionary", "at": [11, 17]}]}
decorate(m, spawns, 'c4', random.Random(1200+4))
problems += finish(m, spawns, 4, grade="slate", haze="heavy")

# ================================================================== 5. The Warden's Judgment  (16 x 26)  player left
m = Map(16, 26, "Crucible 5: The Warden's Judgment. A fortress courtyard: raised battlements along both walls, ether generators humming in the corners, and the Warden's command platform at the far end")
m.box(0, 15, 0, 25, 'M', 0)
for y in range(26):
    m.set(15, y, 'q', 5); m.set(14, y, 'M', 3); m.set(13, y, 'M', 2)   # the rear wall and its walkway
for x in (0, 1):                                                       # the near battlements (low, so they never hide the fight)
    for y in range(4, 22):
        m.set(x, y, 'M', 1)
for y in range(2, 25, 3): m.box(13, 13, y, y, 'q', 4)                  # crenellations on the walkway
m.box(11, 12, 3, 4, 'M', 1); m.box(11, 12, 21, 22, 'M', 1)           # the stairs up to the walkway
m.box(3, 12, 20, 25, 'o', 2); m.box(5, 10, 22, 25, 'o', 3); m.box(7, 8, 23, 25, 'e', 4)   # the Warden's command platform
m.box(4, 11, 19, 19, 'M', 1)                                          # its steps
for (x, y) in [(3, 7), (3, 15), (11, 8), (11, 16)]:                    # the ether generators: humming blocks of stone and light
    m.box(x, x + 1, y, y + 1, 'q', 3); m.set(x, y, 'e', 4)
for (x0, x1, y0, y1, h) in [(5, 6, 9, 9, 2), (9, 10, 12, 12, 2), (6, 7, 14, 14, 2), (4, 4, 11, 11, 2), (10, 10, 6, 6, 2), (8, 9, 17, 17, 2)]:
    m.box(x0, x1, y0, y1, 'q', h)
for (x, y) in [(2, 10), (12, 11), (8, 4)]: m.set(x, y, 'M', 1)
m.box(1, 12, 12, 12, 'q', 4); m.box(11, 12, 12, 12, 'M', 0)   # a broken rampart across the yard: one gap at the far side
spawns = {"king": [6, 2], "captain": [8, 2], "stones": [[4, 1], [10, 1], [7, 4]],
          "enemies": [{"kind": "wardenboss", "at": [8, 24]}, {"kind": "phalanx", "at": [6, 13]}, {"kind": "phalanx", "at": [10, 14]}, {"kind": "legionary", "at": [4, 17]},
                      {"kind": "runemage", "at": [12, 15]}, {"kind": "hexer", "at": [7, 21]}, {"kind": "legionary", "at": [10, 19]}]}
decorate(m, spawns, 'c5', random.Random(1200+5))
problems += finish(m, spawns, 5, grade="slate", haze="heavy")

# ================================================================== the Sunken Bastion's war room (16 x 16, a scene stage)
b = Map(16, 16, "Crucible: the Sunken Bastion's war room: a flagstone hall under the water line, the war table on a carved dais")
b.box(0, 15, 0, 15, 'f', 0)
for _ in range(40): b.set(rnd.randrange(16), rnd.randrange(16), 'h')
for i in range(16):
    b.set(15, i, 'q', 5); b.set(i, 0, 'q', 3); b.set(i, 15, 'q', 3)
b.box(5, 10, 4, 11, 'o', 1); b.box(6, 9, 5, 10, 'e', 2)
for (x, y) in [(3, 2), (12, 2), (3, 13), (12, 13), (14, 7), (14, 8)]: b.box(x, x, y, y, 'q', 3)
b.extra = {"grade": "slate", "haze": "heavy"}
b.save('bastion')
print('\nTOTAL PROBLEMS:', len(problems))
