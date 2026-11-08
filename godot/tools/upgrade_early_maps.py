"""Visual upgrade of the early maps to the newer maps' standard (owner, Nov 2026): `life` (decoration), `ambient` (weather particles) and `rough_walls`
(weathered wall and cliff faces, Board3D) on the Keep Hallway, the Altar Chamber, the opening forest, the Hollow Base and Riverford maps 1-5.
Visual only: the terrain rows, heights, spawns and every other key are left exactly as they are (life_kit's `weather`, which changes heights, is NOT used),
and no decoration lands on a start tile, a cutscene's walking lane or the base's road. Same output every run.
  python3 godot/tools/upgrade_early_maps.py
"""
import json, os, random

exec(open('godot/tools/life_kit.py').read())   # life, scatter, on_tops, keep_clear

SAMPLES = 'godot/samples/'


class JMap:
    """An existing map file seen through the interface life_kit expects (g[y][x] = [code, level], d columns, w rows, extra, inb, passable)."""

    def __init__(self, data):
        self.data = data
        self.g = []
        for row in data['rows']:
            cells = []
            for tok in row.split():
                code = ''.join(c for c in tok if not c.isdigit())
                num = ''.join(c for c in tok if c.isdigit())
                cells.append([code, int(num) if num else 0])
            self.g.append(cells)
        self.w = len(self.g)
        self.d = len(self.g[0])
        self.extra = {}
        self.solid = set()

    def inb(self, x, y): return 0 <= x < self.d and 0 <= y < self.w
    def passable(self, x, y): return self.inb(x, y) and self.g[y][x][0] not in 'Wtlvq' and (x, y) not in self.solid
    def code(self, x, y): return self.g[y][x][0]
    def lvl(self, x, y): return self.g[y][x][1]


def spawns_from(cells):
    """A spawns-shaped dict whose 'start tiles' are `cells` (keep_clear keeps decorations off them and their neighbours)."""
    return {'king': list(cells[0]), 'captain': list(cells[0]), 'stones': [list(c) for c in cells[1:]], 'enemies': []}


def wall_tops(m, codes='qr', min_h=2, avoid=()):
    """Wall or cliff tiles high enough to stand a torch or a lantern on."""
    return [(x, y) for y in range(m.w) for x in range(m.d) if m.code(x, y) in codes and m.lvl(x, y) >= min_h and (x, y) not in avoid]


def spread(rnd, cells, n, gap=3):
    """Up to n of `cells`, at least `gap` tiles apart."""
    cells = list(cells)
    rnd.shuffle(cells)
    out = []
    for c in cells:
        if all(abs(c[0] - o[0]) + abs(c[1] - o[1]) >= gap for o in out):
            out.append(c)
        if len(out) >= n:
            break
    return sorted(out)


def finish(m, path, ambient, keep):
    starts = set(map(tuple, keep))
    m.data['life'] = [d for d in m.extra.get('life', []) if (d['x'], d['y']) not in starts]
    m.data['ambient'] = ambient
    m.data['rough_walls'] = True
    with open(path, 'w') as f:
        json.dump(m.data, f, indent='\t')
    print('%-22s life %3d  ambient %-9s rough_walls' % (os.path.basename(path), len(m.data['life']), ambient))


def lanes(m, rows, cols=None):
    """Every cell in the given rows (and columns): a cutscene's walking lane."""
    cols = range(m.d) if cols is None else cols
    return [(x, y) for y in rows for x in cols]


def hallway():
    """The Keep Hallway (intro_ruins): torches on the walls, fallen stone and old bones along the sides; the corridor (rows 3-4) stays clear."""
    p = SAMPLES + 'intro_ruins.json'
    m = JMap(json.load(open(p)))
    rnd = random.Random(101)
    keep = lanes(m, (3, 4)) + [(1, 5), (1, 3), (1, 0), (0, 5)]
    sp = spawns_from(keep)
    on_tops(m, 'torch', [(2, 0), (5, 0), (8, 0), (2, 7), (5, 7), (8, 7)])
    on_tops(m, 'banner', [(4, 0), (7, 7)], color="#5a2a2a")
    scatter(m, sp, rnd, 'rubble', 5, (1, 8, 1, 6), s=1.0)
    scatter(m, sp, rnd, 'bones', 2, (1, 8, 1, 6))
    finish(m, p, 'motes', keep)


def chamber():
    """The Altar Chamber (ruins_chamber): braziers flank the altar, torches on the walls, spirit wisps near the altar, debris along the sides; the walk to
    the altar (rows 3-5) and the summon stones stay clear."""
    p = SAMPLES + 'ruins_chamber.json'
    m = JMap(json.load(open(p)))
    rnd = random.Random(102)
    keep = lanes(m, (3, 4, 5)) + [(10, 6), (10, 3), (10, 2), (6, 5), (9, 5), (7, 3), (7, 5)]
    sp = spawns_from(keep)
    on_tops(m, 'torch', [(3, 0), (6, 0), (9, 0), (3, 8), (6, 8), (9, 8)])
    on_tops(m, 'brazier', [(9, 1), (9, 7)], s=1.1)
    on_tops(m, 'banner', [(11, 2), (11, 6)], color="#2a3f7a")
    scatter(m, sp, rnd, 'rubble', 6, (1, 8, 1, 7), s=1.0)
    scatter(m, sp, rnd, 'bones', 2, (1, 8, 1, 7))
    scatter(m, sp, rnd, 'wisp', 3, (6, 10, 1, 7), color=SPIRIT)
    finish(m, p, 'spirit', keep)


def forest():
    """The opening forest (intro_forest): loose stone on the rocks, a few bones, falling leaves; the path (row 5) and the chase cells stay clear."""
    p = SAMPLES + 'intro_forest.json'
    m = JMap(json.load(open(p)))
    rnd = random.Random(103)
    keep = lanes(m, (4, 5, 6)) + lanes(m, range(m.w), (7,))
    sp = spawns_from(keep)
    rocks = [c for c in wall_tops(m, 'r', 3) if c not in keep]
    on_tops(m, 'rubble', spread(rnd, rocks, 5, 2), s=0.9)
    scatter(m, sp, rnd, 'rubble', 3, (0, 6, 0, 9), s=0.8)
    scatter(m, sp, rnd, 'bones', 2, (0, 6, 0, 9))
    finish(m, p, 'leaves', keep)


def base():
    """The Hollow Base: braziers by the altar, lanterns along the road's walls, banners on the ruins, the camp's crates, barrels and racks off the road;
    the road (rows 13-17), the start and the altar stay clear."""
    p = SAMPLES + 'base.json'
    m = JMap(json.load(open(p)))
    rnd = random.Random(104)
    keep = lanes(m, range(13, 18)) + [(28, 15), (5, 15)]
    sp = spawns_from(keep)
    on_tops(m, 'brazier', [(29, 13), (29, 17)], s=1.2)
    on_tops(m, 'lantern', [(12, 12), (15, 12), (18, 12), (12, 18), (15, 18), (18, 18)], color="#ffd88a")
    on_tops(m, 'banner', [(22, 8), (25, 8), (22, 22), (25, 22), (0, 10), (0, 20)], color="#6b2a2a")
    on_tops(m, 'torch', [(22, 12), (22, 18), (24, 10), (24, 20)])
    scatter(m, sp, rnd, 'crates', 5, (1, 8, 3, 11)); scatter(m, sp, rnd, 'barrel', 4, (1, 8, 19, 27)); scatter(m, sp, rnd, 'rack', 2, (23, 28, 9, 12))
    scatter(m, sp, rnd, 'rubble', 8, (11, 21, 19, 28), s=1.0); scatter(m, sp, rnd, 'rubble', 5, (22, 28, 18, 21), s=0.9)
    finish(m, p, 'motes', keep)


RIVERFORD = {   # map -> (seed, ambient, what lives there)
    1: (111, 'motes', [('crates', 6), ('barrel', 6), ('rubble', 6), ('bones', 2)], 'lantern'),
    2: (112, 'leaves', [('rubble', 8), ('crates', 3), ('barrel', 3), ('bones', 3)], 'torch'),
    3: (113, 'fireflies', [('crates', 5), ('barrel', 4), ('rack', 2), ('rubble', 6)], 'lantern'),
    4: (114, 'embers', [('crates', 5), ('barrel', 4), ('rack', 3), ('rubble', 6), ('bones', 2)], 'torch'),
    5: (115, 'embers', [('rubble', 9), ('bones', 4), ('crates', 3), ('barrel', 3)], 'brazier'),
}


def riverford(n):
    """Riverford battle n: the town's clutter scattered off the start tiles, lights on its walls, the battle's weather."""
    p = SAMPLES + 'riverford_%d.json' % n
    m = JMap(json.load(open(p)))
    seed, ambient, items, light = RIVERFORD[n]
    rnd = random.Random(seed)
    sp = m.data['spawns']
    keep = [tuple(sp['king']), tuple(sp['captain'])] + [tuple(c) for c in sp['stones']] + [tuple(e['at']) for e in sp['enemies']]
    for w in sp.get('waves', []):
        keep += [tuple(e['at']) for e in w.get('enemies', [])]
    avoid = keep_clear({'king': sp['king'], 'captain': sp['captain'], 'stones': sp['stones'], 'enemies': [{'at': list(c)} for c in keep]})
    lights = spread(rnd, wall_tops(m, 'qr', 3, avoid), 6, 4)
    on_tops(m, light, lights, **({'color': "#ffd88a"} if light == 'lantern' else {'s': 1.1} if light == 'brazier' else {}))
    full = (0, m.d - 1, 0, m.w - 1)
    spw = {'king': sp['king'], 'captain': sp['captain'], 'stones': sp['stones'], 'enemies': [{'at': list(c)} for c in keep]}
    for typ, k in items:
        scatter(m, spw, rnd, typ, k, full, **({'s': round(rnd.uniform(0.85, 1.3), 2)} if typ == 'rubble' else {}))
    finish(m, p, ambient, keep)


if __name__ == '__main__':
    hallway(); chamber(); forest(); base()
    for n in range(1, 6):
        riverford(n)
