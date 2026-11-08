#!/usr/bin/env python3
"""The crypt hall (owner's reference image, Nov 2026): godot/samples/crypt_hall.json. An open hall of cracked flagstones framed by tall carved pillars and walls, a raised walk with steps on
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
m.box(0, 15, 0, 21, 'f', 0)                                                    # the flagstone floor: an open stage
# the height is at the edges, framing the floor (the owner's reference): the back wall with its tall pillars, a huge pillar block at the left end, a wall of columns at the right end
for y in range(22): m.set(15, y, 'q', 5)                                       # the back wall
for y in (1, 4, 7, 10, 13, 16, 19): m.set(14, y, 'q', 8)                       # tall pillars in front of it, apart
m.box(9, 13, 0, 1, 'q', 7); m.set(8, 0, 'q', 4)                                # the great pillar at the left end
for x in (4, 7, 10, 13): m.box(x, x, 21, 21, 'q', 6)                           # columns along the right end
m.box(12, 13, 17, 20, 'o', 2); m.box(11, 11, 18, 19, 'e', 1)                   # a raised landing at the back right, with steps
m.box(12, 13, 3, 8, 'o', 2); m.box(11, 11, 4, 7, 'e', 1)                       # the raised walk at the back left, with steps up to it
m.box(6, 8, 10, 12, 'o', 1); m.set(7, 11, 'e', 2)                              # a low carved dais in the middle of the hall
# cover in the open floor: just a few plinths and broken sections (never more than three together). The owner (Nov 2026): a straight route is fine now and then, so this hall stays open
for (x, y, h) in [(6, 8, 4), (7, 8, 4), (3, 12, 3), (4, 12, 3), (10, 13, 4), (10, 14, 4), (4, 17, 5), (4, 18, 5), (8, 17, 3), (9, 17, 3), (11, 15, 2), (2, 5, 2), (1, 9, 2), (9, 5, 2), (2, 19, 2)]:
    m.set(x, y, 'q', h)
spawns = {"king": [6, 2], "captain": [8, 2], "stones": [[4, 1], [10, 3], [7, 4]],
          "enemies": [{"kind": "swords", "at": [5, 10]}, {"kind": "swords", "at": [3, 14]}, {"kind": "shield", "at": [10, 15]}, {"kind": "rarcher", "at": [12, 19]},
                      {"kind": "support", "at": [3, 19]}, {"kind": "heavy", "at": [8, 18]}, {"kind": "cmage", "at": [9, 19]}]}
rnd = random.Random(2701)
# the candles: at the feet of the pillars, beside the plinths, at the head of the steps; the stains on the stone
for (x, y) in [(13, 2), (13, 5), (13, 9), (13, 12), (13, 15), (13, 21), (11, 3), (11, 8), (11, 17), (3, 4), (1, 7), (2, 18), (6, 10), (9, 11), (6, 20), (1, 14)]:
    life(m, 'candles', x, y, ox=round(rnd.uniform(-0.15, 0.15), 2), oy=round(rnd.uniform(-0.15, 0.15), 2), rot=rnd.randrange(0, 360, 15), n=rnd.choice((4, 5, 6)), s=round(rnd.uniform(1.15, 1.45), 2))
scatter(m, spawns, rnd, 'stain', 22, (0, 13, 0, 21))
m.extra.update({'ambient': 'embers', 'rough_walls': True})
starts = {tuple(c) for c in [spawns['king'], spawns['captain']] + spawns['stones'] + [e['at'] for e in spawns['enemies']]}
m.extra['life'] = [d for d in m.extra['life'] if (d['x'], d['y']) not in starts]   # never on a start tile
problems = [p for p in finish(m, spawns, 'hall', grade="crypt", haze="light") if 'too straight' not in p]   # a straight route is allowed here
print('\n'.join(problems) if problems else 'no problems')
