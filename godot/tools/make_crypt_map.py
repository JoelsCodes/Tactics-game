#!/usr/bin/env python3
"""The crypt hall (owner's reference image, Nov 2026): godot/samples/crypt_hall.json. A hall of cracked flagstones under tall carved pillars, a raised walk with steps on
one side, square plinths standing on the floor, clusters of tall candles in pools of wax and red stains on the stone, all in a violet light (grade "crypt").
Run from the repo root: python3 godot/tools/make_crypt_map.py        16 deep x 22 wide, the fight runs left to right (Alaric on the left).
Not wired into a chapter yet: it is a ready, checked battle map (spawns use the chapter eight kinds, see Crown.KINDS).
"""
import random
src = open('godot/tools/make_riverford_maps.py').read()
exec(src[:src.index("rnd = random.Random")])   # Map, preview, check, finish
exec(open('godot/tools/life_kit.py').read())   # life, on_tops, scatter
MOVE.update({'swords': 5, 'shield': 3, 'rarcher': 4, 'support': 4, 'heavy': 3, 'cmage': 4})
OUT = 'godot/samples/crypt_%s.json'

m = Map(16, 22, "Crypt Hall. Cracked flagstones under tall carved pillars, a raised walk with steps, square plinths, candles standing in pools of wax and red stains on the stone")
m.box(0, 15, 0, 21, 'f', 0)                                                    # the flagstone floor
for y in range(22): m.set(15, y, 'q', 5)                                       # the back wall
for y in (1, 5, 9, 13, 17, 20): m.set(14, y, 'q', 8)                           # the pillars of the colonnade, tall and apart
m.box(11, 13, 0, 7, 'o', 2)                                                    # the raised walk on the left...
m.box(10, 10, 2, 6, 'e', 1); m.box(12, 12, 8, 8, 'e', 1)                       # ...with steps up to it in front and at its end
m.box(11, 13, 17, 21, 'o', 2); m.box(10, 10, 18, 20, 'e', 1)                   # a smaller raised landing on the right
m.box(6, 8, 10, 12, 'o', 1); m.set(7, 11, 'e', 2)                              # a low carved dais in the middle of the hall
# two broken partition lines (sections of an old wall: never more than three together, the gaps staggered and the lines stepping a tile aside, so no way runs straight)
# (every piece its own height: broad standing sections of the wall tall, the rest broken down to a few feet)
for (xs, y, h) in [((1, 2, 3), 5, 4), ((5, 6, 7), 6, 6), ((9, 10), 5, 3), ((0, 1, 2), 8, 5), ((4, 5, 6), 9, 4), ((8, 9, 10), 8, 6), ((12, 13), 9, 3), ((1, 2, 3), 13, 5), ((6, 7, 8), 14, 6), ((10, 11, 12), 13, 4)]:
    for x in xs: m.set(x, y, 'q', h)
for (x, ys, h) in [(3, (10, 11, 12), 3), (9, (16, 17, 18), 3), (3, (16, 17), 4), (12, (15, 16), 3)]:    # fallen beams lying across the floor
    for y in ys: m.set(x, y, 'q', h)
for (x, y) in [(4, 3), (9, 3), (1, 11), (10, 11), (5, 20), (7, 18), (13, 11)]:
    m.set(x, y, 'q', 2)                                                       # square plinths: cover
spawns = {"king": [6, 2], "captain": [8, 2], "stones": [[4, 1], [10, 1], [7, 4]],
          "enemies": [{"kind": "swords", "at": [5, 11]}, {"kind": "swords", "at": [11, 11]}, {"kind": "shield", "at": [7, 16]}, {"kind": "rarcher", "at": [12, 19]},
                      {"kind": "support", "at": [4, 18]}, {"kind": "heavy", "at": [9, 20]}, {"kind": "cmage", "at": [11, 16]}]}
rnd = random.Random(2701)
# the candles: at the feet of the pillars, beside the plinths, at the head of the steps; the stains on the stone
for (x, y) in [(13, 1), (13, 5), (13, 9), (13, 13), (13, 17), (13, 20), (10, 3), (10, 6), (10, 19), (3, 5), (1, 8), (3, 19), (5, 12), (9, 12), (7, 21), (1, 15)]:
    life(m, 'candles', x, y, ox=round(rnd.uniform(-0.15, 0.15), 2), oy=round(rnd.uniform(-0.15, 0.15), 2), rot=rnd.randrange(0, 360, 15), n=rnd.choice((4, 5, 6)), s=round(rnd.uniform(1.15, 1.45), 2))
scatter(m, spawns, rnd, 'stain', 22, (0, 13, 0, 21))
m.extra.update({'ambient': 'embers', 'rough_walls': True})
starts = {tuple(c) for c in [spawns['king'], spawns['captain']] + spawns['stones'] + [e['at'] for e in spawns['enemies']]}
m.extra['life'] = [d for d in m.extra['life'] if (d['x'], d['y']) not in starts]   # never on a start tile
problems = finish(m, spawns, 'hall', grade="crypt", haze="light")
print('\n'.join(problems) if problems else 'no problems')
