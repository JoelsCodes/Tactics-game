#!/usr/bin/env python3
"""FFT-style ground for the battle maps (owner, Nov 2026, after REFERENCE_FFT_MAPS.md): every story battle map gets
  1. an irregular footprint: stepped notches cut into its rim (FFT maps fill a median 96% of their box, ours filled 100%),
  2. rolling ground: some one-level steps become ramps ("g1.5>") and some inside corners half steps ("g1.5") (53% of FFT's neighbouring tiles are
     level, 75% of ours were),
  3. scenery flags: walls and roofs ("q") nobody can walk to are marked "!" (no one stands there, not even by a Knight's leap or a Hop).
Nothing that matters to a battle moves: every spawn, stone, wave, exit and decoration tile and a margin round it is protected, and each change is undone
if it would change which tiles Alaric or any enemy can walk to. The same map always gets the same changes (seeded by its name), and a map that was
already upgraded is skipped ("terrain_upgrade" in the file), so run it after any make_*_maps.py:
    python3 godot/tools/upgrade_terrain.py            # every battle map
    python3 godot/tools/upgrade_terrain.py riverford_1 # one map
"""
import glob, json, os, random, re, sys
from collections import deque

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
SAMPLES = os.path.join(ROOT, 'samples')
FAMILIES = ('riverford_', 'crucible_', 'mountain_', 'bellwether_', 'expanse_', 'vespera_', 'crown_', 'palace_', 'ashes_', 'falcon_',
            'arc12_', 'arc13_', 'arc14_', 'arc15_', 'skirmish_')
VERSION = 1
IMPASSABLE = set('Wltv')
NATURAL = set('gdmanckrh')     # rolling ground: half steps and ramps
PAVED = set('sMf')             # paved ground: ramps only (they read as stairs)
TOK = re.compile(r'^([A-Za-z])(-?\d+(?:\.5)?)?([<>^v]?)([!~*]*)$')
PROTECT = 2                    # tiles round anything protected that stay untouched
CLIMB, DROP = 1.0, 3.0         # walking: up one level, down three (the check only compares before and after, so the exact jump does not matter)
RAMP_SHARE, HALF_SHARE = 0.4, 0.3
MOUND_SHARE = 0.18             # about this share of wide flat natural ground is raised into mounds
DIRS = {(1, 0): '>', (-1, 0): '<', (0, 1): 'v', (0, -1): '^'}


class Grid:
    def __init__(self, rows):
        self.t = []
        for row in rows:
            r = []
            for tok in row.split():
                m = TOK.match(tok) if '=' not in tok else None
                if m is None:
                    r.append({'raw': tok, 't': tok[0], 'h': 0.0, 's': '', 'f': ''})
                else:
                    r.append({'t': m.group(1), 'h': float(m.group(2)) if m.group(2) else 0.0, 's': m.group(3), 'f': m.group(4)})
            self.t.append(r)
        self.H = len(self.t)
        self.W = len(self.t[0])

    def cell(self, x, y):
        return self.t[y][x] if 0 <= x < self.W and 0 <= y < self.H else None

    def walk(self, x, y):
        c = self.cell(x, y)
        return c is not None and 'raw' not in c and c['t'] not in IMPASSABLE and '!' not in c['f'] and '*' not in c['f']

    def reach(self, starts):
        seen = set()
        q = deque(s for s in starts if self.walk(*s))
        seen.update(q)
        while q:
            x, y = q.popleft()
            for dx, dy in DIRS:
                n = (x + dx, y + dy)
                if n in seen or not self.walk(*n):
                    continue
                rise = self.cell(*n)['h'] - self.cell(x, y)['h']
                if rise > CLIMB or -rise > DROP:
                    continue
                seen.add(n)
                q.append(n)
        return seen

    def rows(self):
        out = []
        for r in self.t:
            toks = []
            for c in r:
                if 'raw' in c:
                    toks.append(c['raw'])
                    continue
                if c['t'] == 'v':
                    toks.append('v')
                    continue
                h = c['h']
                hs = str(int(h)) if h == int(h) else '%.1f' % h
                toks.append(c['t'] + hs + c['s'] + c['f'])
            out.append(' '.join(toks))
        return out


DECOR_KEYS = ('life', 'props')  # decoration lists: their tiles are kept flat, an item on a carved tile is dropped


def coords(obj, out):
    """Every [x, y] pair and every {x, y} in a map's extra data that matters to a battle (spawns, waves, exits; not the decoration lists)."""
    if isinstance(obj, dict):
        if isinstance(obj.get('x'), (int, float)) and isinstance(obj.get('y'), (int, float)):
            out.add((int(obj['x']), int(obj['y'])))
        for k, v in obj.items():
            if k not in ('rows', 'name') + DECOR_KEYS:
                coords(v, out)
    elif isinstance(obj, list):
        if len(obj) == 2 and all(isinstance(v, int) for v in obj):
            out.add((obj[0], obj[1]))
        else:
            for v in obj:
                coords(v, out)


def upgrade(data, seed):
    g = Grid(data['rows'])
    rnd = random.Random(seed)
    sp = data.get('spawns', {})
    starts = [tuple(sp['king'])] if 'king' in sp else []
    enemy_starts = [tuple(e['at']) for e in sp.get('enemies', []) if 'at' in e]
    keep = set()
    coords(data, keep)
    near = {(x + dx, y + dy) for (x, y) in keep for dx in range(-PROTECT, PROTECT + 1) for dy in range(-PROTECT, PROTECT + 1)}
    decor = set()
    for k in DECOR_KEYS:
        for it in data.get(k, []) or []:
            if isinstance(it, dict) and 'x' in it and 'y' in it:
                decor.add((int(it['x']), int(it['y'])))
    every = starts + enemy_starts
    before = [g.reach([s]) for s in every]
    stats = {'carved': 0, 'ramps': 0, 'half': 0, 'scenery': 0}

    def same(changed):
        after = [g.reach([s]) for s in every]
        return all(a == b - changed for a, b in zip(after, before))

    # 1. the footprint: stepped notches in the rim (corners and edges), each undone if it cuts anybody off
    W, H = g.W, g.H
    corner_shapes = [[(0, 0)], [(0, 0), (1, 0)], [(0, 0), (0, 1)], [(0, 0), (1, 0), (0, 1)], [(0, 0), (1, 0), (2, 0), (0, 1)], [(0, 0), (0, 1), (0, 2), (1, 0)]]
    notches = []
    for cx, cy, sx, sy in [(0, 0, 1, 1), (W - 1, 0, -1, 1), (0, H - 1, 1, -1), (W - 1, H - 1, -1, -1)]:
        if rnd.random() < 0.75:
            notches.append([(cx + sx * a, cy + sy * b) for a, b in rnd.choice(corner_shapes)])
    for _ in range(max(2, (W + H) // 8)):
        side = rnd.randrange(4)
        length = rnd.randint(2, 4)
        if side in (0, 1):  # the two long edges (rows 0 and H-1)
            y = 0 if side == 0 else H - 1
            x0 = rnd.randrange(1, max(2, W - length))
            cells = [(x, y) for x in range(x0, min(W - 1, x0 + length))]
            if length >= 3 and rnd.random() < 0.5:
                cells.append((x0 + length // 2, y + (1 if side == 0 else -1)))
        else:
            x = 0 if side == 2 else W - 1
            y0 = rnd.randrange(1, max(2, H - length))
            cells = [(x, y) for y in range(y0, min(H - 1, y0 + length))]
            if length >= 3 and rnd.random() < 0.5:
                cells.append((x + (1 if side == 2 else -1), y0 + length // 2))
        notches.append(cells)
    carved_all = set()
    for cells in notches:
        cells = [c for c in cells if g.cell(*c) is not None and c not in near and g.cell(*c)['t'] != 'v' and 'raw' not in g.cell(*c)]
        if not cells:
            continue
        saved = {c: dict(g.cell(*c)) for c in cells}
        for (x, y) in cells:
            g.t[y][x] = {'t': 'v', 'h': 0.0, 's': '', 'f': ''}
        if same(carved_all | set(cells)):
            carved_all |= set(cells)
        else:
            for (x, y), v in saved.items():
                g.t[y][x] = v
    stats['carved'] = len(carved_all)
    for k in DECOR_KEYS:  # decoration over a carved tile would float in the air
        if isinstance(data.get(k), list):
            data[k] = [it for it in data[k] if not (isinstance(it, dict) and (int(it.get('x', -1)), int(it.get('y', -1))) in carved_all)]
    before = [b - carved_all for b in before]

    # 2. rolling ground: ramps on one-level steps, half steps in inside corners
    for y in range(H):
        for x in range(W):
            c = g.cell(x, y)
            if (x, y) in near or (x, y) in decor or 'raw' in c or c['t'] in IMPASSABLE or c['s'] or c['f'] or c['h'] != int(c['h']):
                continue
            if c['t'] not in NATURAL and c['t'] not in PAVED:
                continue
            L = c['h']
            nb = {}
            ok = True
            for d in DIRS:
                n = g.cell(x + d[0], y + d[1])
                if n is None or n['t'] == 'v':
                    ok = False  # keep ramps off the rim
                    break
                if 'raw' in n or n['s'] or (n['h'] != int(n['h'])):
                    ok = False  # one shaped tile at a time
                    break
                if g.walk(x + d[0], y + d[1]):
                    nb[d] = n
                elif n['t'] not in IMPASSABLE and n['h'] < L:
                    ok = False
            if not ok or any(n['h'] not in (L, L + 1) for n in nb.values()):
                continue
            ups = [d for d, n in nb.items() if n['h'] == L + 1 and n['t'] in NATURAL | PAVED]
            if len(ups) == 1 and nb.get((-ups[0][0], -ups[0][1]), {}).get('h') == L:
                if rnd.random() < RAMP_SHARE:
                    c['h'] = L + 0.5
                    c['s'] = DIRS[ups[0]]
                    if same(carved_all):
                        stats['ramps'] += 1
                    else:
                        c['h'], c['s'] = L, ''
            elif len(ups) >= 2 and c['t'] in NATURAL and rnd.random() < HALF_SHARE:
                c['h'] = L + 0.5
                if same(carved_all):
                    stats['half'] += 1
                else:
                    c['h'] = L

    # 2b. mounds: low rises in wide flat natural ground (a half step, sometimes a whole level at the crown), so open ground rolls the way FFT's does.
    # Every step stays at a level or less, so nobody's walking changes (checked like everything else).
    def flat_natural(x, y):
        c = g.cell(x, y)
        if c is None or (x, y) in near or (x, y) in decor or 'raw' in c or c['t'] not in NATURAL or c['s'] or c['f'] or c['h'] != int(c['h']):
            return False
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                n = g.cell(x + dx, y + dy)
                if n is None or n['t'] == 'v' or 'raw' in n or n['t'] not in NATURAL or n['h'] != c['h'] or n['s']:
                    return False
        return True
    open_ground = [(x, y) for y in range(H) for x in range(W) if flat_natural(x, y)]
    rnd.shuffle(open_ground)
    target = int(len(open_ground) * MOUND_SHARE)
    raised = 0
    for (x, y) in open_ground:
        if raised >= target:
            break
        if not flat_natural(x, y):
            continue
        blob = [(x, y)]
        for _ in range(rnd.randint(2, 6)):
            bx, by = rnd.choice(blob)
            d = rnd.choice(list(DIRS))
            n = (bx + d[0], by + d[1])
            if n not in blob and flat_natural(*n):
                blob.append(n)
        crown = (x, y) if len(blob) >= 5 and rnd.random() < 0.4 else None
        saved = {c: (g.cell(*c)['h']) for c in blob}
        for c in blob:
            g.cell(*c)['h'] += 1.0 if c == crown else 0.5
        if crown is not None:  # the crown is a whole level up: every neighbour of it must be on the mound (half a level) so no step is 1.5
            if any(g.cell(crown[0] + d[0], crown[1] + d[1])['h'] < saved[crown] + 0.5 for d in DIRS):
                g.cell(*crown)['h'] = saved[crown] + 0.5
        if same(carved_all):
            raised += len(blob)
            stats['half'] += len(blob)
        else:
            for c, h in saved.items():
                g.cell(*c)['h'] = h

    # 3. scenery: walls and roofs nobody can walk to
    walkable_from_anyone = set().union(*before) if before else set()
    for y in range(H):
        for x in range(W):
            c = g.cell(x, y)
            if c['t'] == 'q' and g.walk(x, y) and (x, y) not in walkable_from_anyone and (x, y) not in keep:
                c['f'] += '!'
                stats['scenery'] += 1
    data['rows'] = g.rows()
    data['terrain_upgrade'] = VERSION
    return stats


def main(names):
    files = sorted(glob.glob(os.path.join(SAMPLES, '*.json')))
    total = {'carved': 0, 'ramps': 0, 'half': 0, 'scenery': 0, 'maps': 0}
    for f in files:
        key = os.path.basename(f)[:-5]
        if names and key not in names:
            continue
        if not key.startswith(FAMILIES) or not key.split('_')[-1].isdigit():
            continue
        data = json.load(open(f))
        if 'rows' not in data or 'spawns' not in data or data.get('terrain_upgrade') == VERSION:
            continue
        st = upgrade(data, key)
        with open(f, 'w') as fh:
            json.dump(data, fh, indent=1)
            fh.write('\n')
        total['maps'] += 1
        for k in st:
            total[k] += st[k]
        print('%-14s carved %3d  ramps %3d  half steps %3d  scenery %3d' % (key, st['carved'], st['ramps'], st['half'], st['scenery']))
    print('total', total)


if __name__ == '__main__':
    main(sys.argv[1:])
