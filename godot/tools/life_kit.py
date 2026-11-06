"""Decoration for the chapter three and four maps (see scripts/stage/board_life.gd): writes `life` (braziers, torches, banners, crates, crystals, wisps...) and `ambient`
(the weather) into a Map's extra data. Used by make_crucible_maps.py and make_mountain_maps.py through `decorate(m, spawns, key, rnd)`; same output every run.
Everything is decoration: it is placed away from every start tile and never blocks one.
  c1..c5   chapter three maps 1-5       m1..m5   chapter four maps 1-5
"""
import random

SPIRIT = "#8fd0ff"
VIOLET = "#b48cff"
ETHER = "#7fc8ff"


def life(m, typ, x, y, **kw):
    if not m.inb(x, y):
        return
    d = {"type": typ, "x": x, "y": y}
    d.update(kw)
    m.extra.setdefault("life", []).append(d)


def keep_clear(spawns):
    """Cells decorations stay off: every start tile and the ring around it."""
    pts = [spawns['king'], spawns['captain']] + spawns['stones'] + [e['at'] for e in spawns['enemies']]
    out = set()
    for (x, y) in pts:
        for dx in range(-1, 2):
            for dy in range(-1, 2):
                out.add((x + dx, y + dy))
    return out


def scatter(m, spawns, rnd, typ, n, region, **kw):
    """n decorations at random open tiles inside region (x0, x1, y0, y1), each nudged a little off the tile's centre."""
    x0, x1, y0, y1 = region
    avoid = keep_clear(spawns)
    taken = {(d['x'], d['y']) for d in m.extra.get('life', [])}
    cells = [(x, y) for x in range(x0, x1 + 1) for y in range(y0, y1 + 1)
             if m.inb(x, y) and m.passable(x, y) and (x, y) not in avoid and (x, y) not in taken]
    rnd.shuffle(cells)
    for (x, y) in cells[:n]:
        life(m, typ, x, y, ox=round(rnd.uniform(-0.22, 0.22), 2), oy=round(rnd.uniform(-0.22, 0.22), 2), rot=rnd.randrange(0, 360, 15), **kw)


def on_tops(m, typ, cells, **kw):
    """Decorations on wall tops or high ground: the tile's top is where they stand (no passability needed)."""
    for (x, y) in cells:
        life(m, typ, x, y, **kw)


def weather(m, spawns, rnd):
    """Weathered walls (Board3D rough walls): natural cliffs become crag rock, walls crumble at their ends and rise and fall along their length, and loose stone
    lies at their feet. Heights never drop below 3 (4 where they block a line of attack), so the fighting is unchanged."""
    m.extra['rough_walls'] = True
    for x in range(m.d):
        for y in range(m.w):
            c, h = m.g[y][x]
            if c == 'q' and h >= 4 and (x <= 1 or x >= m.d - 3):
                m.g[y][x][0] = 'r'                                   # the mountain itself, not a wall somebody built
    avoid0 = keep_clear(spawns)
    # the cliffs along the edges rise and fall like a real ridge: a random walk along the edge, stepping down toward the inside of the map
    edge_x = [x for x in range(m.d) if x <= 1 or x >= m.d - 3]
    for far in (False, True):
        cols = sorted([x for x in edge_x if (x >= m.d - 3) == far], reverse=far)   # outermost first
        if not cols or not any(m.g[y][cols[0]][0] == 'r' for y in range(m.w)):
            continue
        lo, hi = (4, 7) if far else (3, 5)
        w = rnd.randint(lo + 1, hi) if far else rnd.randint(lo, hi)
        for y in range(m.w):
            w = max(lo, min(hi, w + rnd.choice((-1, 0, 0, 1))))
            for k, x in enumerate(cols):
                if m.g[y][x][0] == 'r':
                    m.g[y][x][1] = max(3, w - k) if far else max(3, w - (1 if x == 1 else 0))
    # walls inside the map: every stretch a different height, crumbled ends, and broken stone spilling out beside them (never into a gap or a start tile)
    walls = [(x, y) for x in range(m.d) for y in range(m.w) if m.g[y][x][0] == 'q' and m.g[y][x][1] >= 3]
    for (x, y) in walls:
        h = m.g[y][x][1]
        nb = sum(1 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)) if m.inb(x + dx, y + dy) and m.g[y + dy][x + dx][0] == 'q')
        if nb <= 1 and h >= 4:
            m.g[y][x][1] = 3                                              # a crumbled end
        else:
            lo2 = 4 if h >= 4 else 3                                      # a wall that stopped attacks still does
            m.g[y][x][1] = max(lo2, min(6, h + rnd.choice((-1, 0, 0, 1, 2))))
    for (x, y) in walls:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if not (m.inb(nx, ny) and m.passable(nx, ny)) or (nx, ny) in avoid0 or m.g[ny][nx][1] != 0 or m.g[ny][nx][0] in 'rq':
                continue
            if m.g[ny][nx][0] in 'Wtlv':
                continue
            opposite = (m.inb(nx + dx, ny + dy) and m.g[ny + dy][nx + dx][0] in 'qr' and m.g[ny + dy][nx + dx][1] >= 3)
            if opposite or rnd.random() > 0.3:                            # a gap between two walls stays a gap
                continue
            m.g[ny][nx][0] = 'r'
            m.g[ny][nx][1] = 1 if rnd.random() < 0.75 else 2             # a heap of fallen stone
    foot = []
    for x in range(m.d):
        for y in range(m.w):
            if m.passable(x, y) and any(m.inb(x + dx, y + dy) and m.g[y + dy][x + dx][0] in 'qr' and m.g[y + dy][x + dx][1] >= 3
                                         for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                foot.append((x, y))
    avoid = keep_clear(spawns)
    taken = {(d['x'], d['y']) for d in m.extra.get('life', [])}
    rnd.shuffle(foot)
    n = 0
    for (x, y) in foot:
        if (x, y) in avoid or (x, y) in taken or n >= 34 or rnd.random() > 0.45:
            continue
        life(m, 'rubble', x, y, ox=round(rnd.uniform(-0.25, 0.25), 2), oy=round(rnd.uniform(-0.25, 0.25), 2), rot=rnd.randrange(0, 360, 15), s=round(rnd.uniform(0.8, 1.5), 2))
        n += 1


def decorate(m, spawns, key, rnd):
    if key not in ('b5', 'bt', 'y1', 'y5', 'yc', 'pl', 'ar', 'k3', 'k4', 'k5', 'kc', 'kg', 'f1', 'f2', 'f3', 'f4', 'f5', 'ft', 'fg', 'fh'):   # towns, towers and rooms are built, not weathered
        weather(m, spawns, rnd)
    _decorate(m, spawns, key, rnd)
    starts = {tuple(c) for c in [spawns['king'], spawns['captain']] + spawns['stones'] + [e['at'] for e in spawns['enemies']]}
    m.extra['life'] = [d for d in m.extra.get('life', []) if (d['x'], d['y']) not in starts]   # never on a start tile


def _decorate(m, spawns, key, rnd):
    sc = lambda typ, n, region, **kw: scatter(m, spawns, rnd, typ, n, region, **kw)
    if key == 'c1':    # the silent village (arena): braziers on the stands, banners on the west wall, graves, lanterns on posts, wisps
        on_tops(m, 'brazier', [(15, y) for y in (4, 10, 16, 22, 28)], s=1.2)
        on_tops(m, 'banner', [(1, y) for y in (4, 9, 14, 19, 24)] + [(14, y) for y in (7, 19, 25)], color="#6b2a2a")
        sc('grave', 7, (2, 12, 3, 28)); sc('bones', 5, (2, 12, 3, 29)); sc('crates', 4, (2, 12, 6, 28)); sc('rack', 2, (2, 12, 4, 26)); sc('barrel', 3, (2, 12, 4, 28))
        on_tops(m, 'lantern', [(12, y) for y in (6, 13, 20, 27)], color=SPIRIT)
        sc('wisp', 6, (2, 12, 3, 29), color=SPIRIT)
        m.extra['ambient'] = 'spirit'
    elif key == 'c2':  # the lantern convoy (snow pass): wagons' cargo, crystals on the rune circles, torches on the towers
        for (cx, cy) in [(7, 9), (8, 18), (7, 28)]:
            life(m, 'crystal', cx, cy, color=ETHER, s=1.1)
        on_tops(m, 'torch', [(13, y) for y in (5, 8, 12, 24, 28, 32)])
        on_tops(m, 'banner', [(14, y) for y in (3, 10, 17, 24, 31)], color="#2a3f7a")
        sc('crates', 7, (1, 12, 3, 33)); sc('barrel', 5, (1, 12, 3, 33)); sc('bones', 3, (1, 12, 3, 33)); sc('rack', 2, (1, 12, 3, 33)); sc('wisp', 4, (1, 12, 3, 33), color=SPIRIT)
        on_tops(m, 'lantern', [(1, y) for y in (6, 13, 22, 30)], color=SPIRIT)
        m.extra['ambient'] = 'snow'
    elif key == 'c3':  # the severing (lava terrace): braziers and torches, crystals on the dais, embers from the rifts
        on_tops(m, 'torch', [(4, 16), (10, 16), (3, 28), (12, 27), (5, 33), (12, 33)])
        on_tops(m, 'brazier', [(1, 5), (13, 5), (4, 34), (11, 34), (4, 38), (11, 38)], s=1.2)
        for (x, y) in [(5, 37), (10, 37), (5, 39), (10, 39)]:
            life(m, 'crystal', x, y, color="#ff9a5a", s=1.2)
        on_tops(m, 'banner', [(14, y) for y in (4, 12, 20, 28, 36)], color="#5a1f1f")
        sc('rubble', 8, (1, 13, 3, 38)); sc('bones', 4, (1, 13, 3, 38)); sc('crates', 3, (1, 13, 3, 38)); sc('wisp', 4, (1, 13, 3, 38), color="#ffb27a")
        m.extra['ambient'] = 'embers'
    elif key == 'c4':  # the ritual chamber: crystals ringing the dais, torches on the pillars, wisps
        for (x, y) in [(3, 10), (11, 10), (7, 6), (7, 14), (4, 7), (10, 13)]:
            if m.passable(x, y) or m.code(x, y) in 'q':
                life(m, 'crystal', x, y, color=ETHER, s=1.0)
        on_tops(m, 'torch', [(2, 6), (3, 6), (2, 14), (3, 14), (11, 5), (12, 5), (11, 15), (12, 15)])
        on_tops(m, 'banner', [(14, y) for y in (3, 8, 13, 18)], color="#3a2a5a")
        sc('bones', 4, (1, 12, 2, 18)); sc('rubble', 5, (1, 12, 2, 18)); sc('wisp', 6, (1, 12, 2, 18), color=ETHER)
        m.extra['ambient'] = 'spirit'
    elif key == 'c5':  # the courtyard: generators pulsing in the corners, torches on the crenellations, banners on the wall
        for (x, y) in [(3, 7), (3, 15), (11, 8), (11, 16)]:
            life(m, 'crystal', x, y, color=ETHER, s=1.3)
        on_tops(m, 'torch', [(13, y) for y in (2, 5, 8, 11, 14, 17, 20, 23)])
        on_tops(m, 'banner', [(14, y) for y in (4, 9, 14, 19, 24)], color="#2a3f7a")
        on_tops(m, 'brazier', [(3, 20), (3, 25), (11, 20), (11, 25)], s=1.2)
        sc('crates', 5, (1, 12, 3, 19)); sc('barrel', 4, (1, 12, 3, 19)); sc('rack', 2, (1, 12, 3, 19)); sc('rubble', 4, (1, 12, 3, 19)); sc('wisp', 4, (1, 12, 3, 19), color=ETHER)
        m.extra['ambient'] = 'embers'
    elif key == 'b1':  # the roadside ambush: the caravan's spilled cargo, lanterns on the wagons, leaves on the wind
        for (x, y) in [(7, 10), (6, 11), (5, 13), (8, 15), (9, 16)]:
            life(m, 'crates', x, y, ox=0.0, oy=0.0, rot=rnd.randrange(0, 90, 15))
        sc('barrel', 4, (4, 10, 9, 17)); sc('hay', 3, (4, 10, 9, 17)); sc('bones', 2, (3, 12, 8, 20)); sc('rubble', 4, (2, 13, 3, 20))
        on_tops(m, 'lantern', [(4, 3), (10, 3)], color="#ffd88a")
        m.extra['ambient'] = 'leaves'
    elif key == 'b2':  # the quarry's ledges: cut stone, mining gear, raw crystal, the watch hut's lantern
        sc('crates', 5, (1, 12, 3, 21)); sc('barrel', 3, (1, 12, 3, 21)); sc('rack', 3, (1, 12, 3, 21)); sc('rubble', 7, (1, 12, 4, 22)); sc('bones', 2, (1, 12, 6, 22))
        on_tops(m, 'crystal', [(14, 6), (14, 15), (14, 21)], color="#ffb060", s=0.8)
        on_tops(m, 'lantern', [(2, 19), (4, 21)], color="#ffd88a")
        on_tops(m, 'torch', [(1, 20), (4, 20)])
        m.extra['ambient'] = 'motes'
    elif key == 'b3':  # the old mine: torches on the pillars, ore glowing in the walls, a toppled cart, old bones
        on_tops(m, 'torch', [(3, 4), (12, 3), (5, 12), (10, 13), (6, 20), (11, 21)])
        on_tops(m, 'crystal', [(1, 8), (14, 12), (1, 15), (14, 20), (2, 22), (13, 9)], color="#ffb060", s=1.0)
        on_tops(m, 'lantern', [(3, 1), (12, 1)], color="#ffd88a")
        sc('rubble', 9, (3, 12, 1, 22)); sc('bones', 5, (3, 12, 6, 22)); sc('crates', 3, (3, 12, 1, 22)); sc('rack', 2, (3, 12, 1, 22)); sc('barrel', 2, (3, 12, 1, 22))
        m.extra['ambient'] = 'motes'
    elif key == 'b4':  # the collapsed gallery: dust, a single failing torch, ore glints
        on_tops(m, 'torch', [(3, 2)])
        on_tops(m, 'crystal', [(1, 10), (14, 7), (14, 14)], color="#ffb060", s=0.9)
        sc('rubble', 11, (3, 12, 1, 16)); sc('bones', 2, (3, 12, 1, 16)); sc('crates', 2, (3, 12, 1, 16))
        m.extra['ambient'] = 'motes'
    elif key == 'b5':  # the town's edge, still hung for the festival: stalls, bunting-coloured banners, lanterns, hay
        for i, (x, y) in enumerate([(4, 4), (10, 6), (4, 9), (10, 11), (4, 14)]):
            life(m, 'stall', x, y, color=["#b0402a", "#2a6a8a", "#c9a24a", "#6a8a2a", "#8a3a6a"][i], rot=0)
        sc('hay', 4, (1, 12, 1, 15)); sc('crates', 3, (1, 12, 1, 15)); sc('barrel', 3, (1, 12, 1, 15))
        on_tops(m, 'lantern', [(5, 1), (9, 1), (5, 7), (9, 8)], color="#ffd88a")
        on_tops(m, 'banner', [(15, 3), (15, 10), (13, 6), (13, 11)], color="#b0402a")
        sc('rubble', 6, (2, 12, 17, 22))
        m.extra['ambient'] = 'motes'
    elif key == 'bt':  # the festival square in the evening
        for i, (x, y) in enumerate([(4, 5), (8, 5), (4, 10), (4, 14), (8, 14)]):
            life(m, 'stall', x, y, color=["#b0402a", "#2a6a8a", "#c9a24a", "#6a8a2a", "#8a3a6a"][i], rot=0)
        on_tops(m, 'lantern', [(3, 3), (11, 3), (3, 12), (11, 12), (3, 20), (11, 20)], color="#ffd88a")
        on_tops(m, 'banner', [(13, 4), (13, 7), (13, 16), (13, 19), (14, 11)], color="#b0402a")
        on_tops(m, 'brazier', [(6, 8), (6, 17)], s=0.9)
        life(m, 'bench', 11, 17, rot=90); life(m, 'bench', 9, 4, rot=0); life(m, 'bench', 3, 8, rot=0)
        sc('hay', 5, (3, 11, 3, 20)); sc('crates', 4, (3, 11, 3, 20)); sc('barrel', 4, (3, 11, 3, 20))
        m.extra['ambient'] = 'fireflies'
    elif key == 'x1':  # the Ashen Expanse: swords in the ash, half-buried engines, old standards, drifting ash
        sc('rack', 8, (1, 13, 2, 24)); sc('rubble', 9, (1, 13, 2, 24)); sc('bones', 5, (1, 13, 3, 24)); sc('crates', 3, (1, 13, 3, 24)); sc('wisp', 6, (1, 13, 2, 24), color="#c8d0e0")
        on_tops(m, 'standard', [(3, 9), (11, 16), (5, 21)], color="#4a4a58")
        m.extra['ambient'] = 'embers'
    elif key == 'xa':  # the academy's courtyard: drill dummies, standards, torches on the walls, silent formations of light
        sc('rack', 6, (2, 12, 3, 20)); sc('hay', 3, (2, 12, 3, 20)); sc('rubble', 7, (1, 13, 2, 22)); sc('wisp', 6, (2, 12, 3, 20), color=SPIRIT)
        on_tops(m, 'standard', [(14, y) for y in (4, 10, 16, 21)], color="#2a3f7a"); on_tops(m, 'torch', [(13, y) for y in (3, 7, 13, 18)])
        m.extra['ambient'] = 'motes'
    elif key == 'x2':  # the academy gates: braziers at the gate, banners on the towers, drill equipment
        on_tops(m, 'brazier', [(3, 9), (12, 9), (3, 13), (12, 13)], s=1.1); on_tops(m, 'banner', [(14, y) for y in (4, 8, 14, 19)], color="#2a3f7a")
        sc('rack', 5, (1, 13, 12, 22)); sc('rubble', 7, (1, 13, 2, 22)); sc('crates', 3, (1, 13, 12, 22)); sc('wisp', 5, (1, 13, 12, 22), color=SPIRIT)
        m.extra['ambient'] = 'motes'
    elif key == 'x3':  # the drill field: markers, standards, dummies, even rows of light
        on_tops(m, 'standard', [(14, y) for y in (3, 8, 13, 18)], color="#7a2a2a"); sc('rack', 7, (1, 13, 3, 21)); sc('hay', 4, (1, 13, 3, 21)); sc('rubble', 5, (1, 13, 3, 21))
        on_tops(m, 'torch', [(1, y) for y in (4, 10, 16, 21)]); sc('wisp', 6, (1, 13, 3, 21), color=SPIRIT)
        m.extra['ambient'] = 'motes'
    elif key == 'x4':  # the academy's chambers failing: the spirit-light turns red
        on_tops(m, 'crystal', [(1, 5), (14, 5), (1, 11), (14, 11), (1, 17), (14, 17)], color="#ff6a5a", s=1.1); on_tops(m, 'torch', [(3, 3), (12, 3), (3, 19), (12, 19)])
        sc('rubble', 8, (1, 13, 2, 19)); sc('bones', 3, (1, 13, 2, 19)); sc('wisp', 6, (1, 13, 2, 19), color="#ff8a7a")
        m.extra['ambient'] = 'embers'
    elif key == 'x5':  # the duelling ground: braziers round the ring, the academy's banners
        on_tops(m, 'brazier', [(3, 5), (12, 5), (3, 15), (12, 15)], s=1.2); on_tops(m, 'banner', [(14, y) for y in (3, 7, 12, 16)], color="#2a3f7a")
        sc('rack', 3, (1, 13, 2, 17)); sc('wisp', 5, (1, 13, 2, 17), color=SPIRIT)
        m.extra['ambient'] = 'motes'
    elif key == 'ar':  # an archive: shelves of records, a reading table, lamplight
        on_tops(m, 'torch', [(1, 3), (1, 10), (14, 3), (14, 10)]); sc('crates', 8, (2, 13, 1, 12)); sc('rack', 4, (2, 13, 1, 12)); sc('barrel', 2, (2, 13, 1, 12)); life(m, 'bench', 7, 6, rot=0)
        m.extra['ambient'] = 'motes'
    elif key == 'pl':  # the palace chamber: candles, banners, a quiet room
        on_tops(m, 'brazier', [(3, 3), (12, 3), (3, 11), (12, 11)], s=0.9); on_tops(m, 'banner', [(14, y) for y in (3, 7, 11)], color="#2a3f7a"); life(m, 'bench', 6, 6, rot=90)
        m.extra['ambient'] = 'motes'
    elif key == 'y1':  # Vespera's streets: lanterns in the fog, bell towers, flowers left at doors
        on_tops(m, 'lantern', [(5, y) for y in (3, 9, 15, 21)] + [(9, y) for y in (6, 12, 18)], color="#ffd88a"); sc('grave', 3, (4, 10, 3, 21)); sc('crates', 4, (4, 10, 3, 21))
        sc('barrel', 3, (4, 10, 3, 21)); sc('wisp', 7, (4, 10, 3, 21), color=SPIRIT); on_tops(m, 'torch', [(13, y) for y in (4, 12, 20)])
        m.extra['ambient'] = 'spirit'
    elif key == 'y2':  # the cemetery: graves, mausoleum lanterns, mourners' flowers, mist
        sc('grave', 16, (1, 13, 3, 22)); sc('bones', 3, (1, 13, 3, 22)); sc('rubble', 4, (1, 13, 3, 22)); sc('wisp', 8, (1, 13, 3, 22), color=SPIRIT)
        on_tops(m, 'lantern', [(5, 6), (10, 6), (5, 14), (10, 14), (7, 20)], color="#8fd0ff"); on_tops(m, 'torch', [(14, 4), (14, 12), (14, 20)])
        m.extra['ambient'] = 'spirit'
    elif key == 'y3':  # the catacombs: resonance crystals in the walls, torches, burial niches
        on_tops(m, 'crystal', [(1, 8), (14, 11), (1, 16), (14, 20), (2, 22), (13, 4)], color="#7fc8ff", s=1.1); on_tops(m, 'torch', [(3, 4), (12, 4), (5, 12), (10, 13), (6, 20), (11, 21)])
        sc('bones', 7, (3, 12, 1, 22)); sc('rubble', 7, (3, 12, 1, 22)); sc('grave', 4, (3, 12, 1, 22)); sc('wisp', 6, (3, 12, 1, 22), color=SPIRIT)
        m.extra['ambient'] = 'spirit'
    elif key == 'y4':  # the choir chamber: crystals ranked like organ pipes, captured lights
        for (x, y) in [(2, 4), (13, 4), (2, 8), (13, 8), (2, 12), (13, 12), (2, 16), (13, 16)]:
            life(m, 'crystal', x, y, color="#7fc8ff", s=1.3)
        sc('wisp', 10, (1, 13, 2, 17), color="#c8e8ff"); on_tops(m, 'torch', [(3, 1), (12, 1), (3, 18), (12, 18)]); sc('rubble', 4, (1, 13, 2, 17))
        m.extra['ambient'] = 'spirit'
    elif key == 'y5':  # the top of the bell tower: the great bell's rim of light, torches, banners
        on_tops(m, 'crystal', [(7, 13), (8, 13), (6, 14), (9, 14)], color="#c8e8ff", s=1.4); on_tops(m, 'torch', [(1, 3), (1, 14), (14, 3), (14, 14)]); on_tops(m, 'brazier', [(3, 8), (12, 8)], s=1.1)
        sc('wisp', 8, (1, 13, 2, 15), color="#c8e8ff"); on_tops(m, 'banner', [(14, y) for y in (5, 9, 12)], color="#3a2a5a")
        m.extra['ambient'] = 'spirit'
    elif key == 'yc':  # the city square at dusk: bell towers, lanterns, flowers on the graves, travellers' stalls
        on_tops(m, 'lantern', [(3, y) for y in (4, 10, 16, 21)] + [(12, y) for y in (4, 10, 16, 21)], color="#ffd88a"); sc('grave', 5, (4, 11, 3, 20)); sc('crates', 3, (4, 11, 3, 20))
        sc('barrel', 2, (4, 11, 3, 20)); sc('wisp', 5, (4, 11, 3, 20), color=SPIRIT); life(m, 'bench', 9, 8, rot=0); life(m, 'bench', 6, 15, rot=0)
        m.extra['ambient'] = 'spirit'
    elif key == 'k1':  # the King's Highway: milestones, the royal banners of a patrol, hedges and leaves
        on_tops(m, 'standard', [(14, y) for y in (4, 10, 17, 23)], color="#2a3f7a"); sc('crates', 3, (2, 12, 3, 24)); sc('barrel', 2, (2, 12, 3, 24)); sc('rack', 2, (2, 12, 3, 24)); sc('rubble', 4, (2, 12, 3, 24))
        on_tops(m, 'lantern', [(4, 3), (10, 3)], color="#ffd88a")
        m.extra['ambient'] = 'leaves'
    elif key == 'k2':  # the outer defenses: braziers on the walls, royal banners, siege stores
        on_tops(m, 'brazier', [(13, y) for y in (6, 11, 14, 19)], s=1.2); on_tops(m, 'standard', [(14, y) for y in (3, 8, 12, 17, 21)], color="#2a3f7a"); on_tops(m, 'torch', [(2, 9), (2, 13)])
        sc('crates', 4, (1, 12, 14, 22)); sc('barrel', 3, (1, 12, 14, 22)); sc('rack', 3, (1, 12, 14, 22)); sc('rubble', 4, (1, 12, 3, 22))
        m.extra['ambient'] = 'motes'
    elif key == 'k3':  # the barbican: royal banners, braziers, an officer's table
        on_tops(m, 'standard', [(14, y) for y in (3, 8, 13, 18)], color="#2a3f7a"); on_tops(m, 'brazier', [(3, 5), (12, 5), (3, 15), (12, 15)], s=1.1)
        sc('rack', 3, (1, 13, 2, 19)); sc('crates', 3, (1, 13, 2, 19)); sc('barrel', 2, (1, 13, 2, 19))
        m.extra['ambient'] = 'motes'
    elif key == 'k4':  # the city of crowns: closed stalls, lanterns, fountains' stonework, royal banners, frightened quiet
        for i, (x, y) in enumerate([(3, 5), (12, 8), (3, 12), (12, 16), (3, 20)]):
            life(m, 'stall', x, y, color=["#b0402a", "#2a6a8a", "#c9a24a", "#6a8a2a", "#8a3a6a"][i], rot=0)
        on_tops(m, 'lantern', [(1, y) for y in (4, 10, 16, 22)] + [(14, y) for y in (5, 11, 17, 23)], color="#ffd88a"); on_tops(m, 'banner', [(14, y) for y in (3, 9, 15, 21, 26)], color="#2a3f7a")
        sc('crates', 4, (2, 13, 2, 26)); sc('barrel', 3, (2, 13, 2, 26)); sc('hay', 2, (2, 13, 2, 26)); sc('rubble', 3, (2, 13, 2, 26))
        m.extra['ambient'] = 'motes'
    elif key == 'k5':  # the palace gates: braziers up the steps, the royal standards, statues' plinths
        on_tops(m, 'brazier', [(3, 7), (12, 7), (3, 13), (12, 13), (5, 18), (10, 18)], s=1.3); on_tops(m, 'standard', [(14, y) for y in (4, 9, 14, 19)], color="#2a3f7a")
        on_tops(m, 'torch', [(1, 3), (14, 3), (1, 20), (14, 20)]); sc('rubble', 3, (1, 13, 2, 20))
        m.extra['ambient'] = 'motes'
    elif key == 'kh':  # the hill above the capital: wind, banners on the far walls, a standing stone
        sc('rubble', 4, (2, 12, 3, 20)); sc('bones', 1, (2, 12, 3, 20)); on_tops(m, 'standard', [(14, y) for y in (4, 12, 20)], color="#2a3f7a")
        m.extra['ambient'] = 'leaves'
    elif key == 'kc':  # the city street for scenes: lanterns, closed stalls, bunting-less banners
        for i, (x, y) in enumerate([(3, 5), (12, 9), (3, 14), (12, 18)]):
            life(m, 'stall', x, y, color=["#b0402a", "#2a6a8a", "#c9a24a", "#6a8a2a"][i], rot=0)
        on_tops(m, 'lantern', [(1, y) for y in (4, 10, 16, 22)], color="#ffd88a"); on_tops(m, 'banner', [(14, y) for y in (3, 9, 15, 21)], color="#2a3f7a"); sc('crates', 3, (2, 13, 2, 22))
        m.extra['ambient'] = 'motes'
    elif key == 'kg':  # the palace hall before the throne room: braziers, banners, the great doors' light
        on_tops(m, 'brazier', [(3, 3), (12, 3), (3, 10), (12, 10)], s=1.1); on_tops(m, 'standard', [(14, y) for y in (3, 6, 9, 12)], color="#2a3f7a"); on_tops(m, 'torch', [(1, 2), (1, 13)])
        m.extra['ambient'] = 'motes'
    elif key == 'f1':  # the royal hall: braziers between the columns, banners, ceremonial tables and benches
        on_tops(m, 'brazier', [(3, 6), (12, 6), (3, 12), (12, 12), (3, 18), (12, 18)], s=1.1); on_tops(m, 'standard', [(14, y) for y in (3, 8, 13, 18, 22)], color="#2a3f7a")
        life(m, 'bench', 2, 9, rot=90); life(m, 'bench', 13, 15, rot=90); life(m, 'stall', 3, 21, color="#8a3a3a", rot=0); sc('crates', 2, (1, 13, 2, 23))
        m.extra['ambient'] = 'motes'
    elif key == 'f2':  # the corridor of the King's Shield: wall torches, standards
        on_tops(m, 'torch', [(1, y) for y in (3, 8, 13, 18)] + [(14, y) for y in (4, 9, 14, 19)]); on_tops(m, 'standard', [(14, y) for y in (2, 7, 12, 17)], color="#2a3f7a"); sc('rack', 3, (1, 13, 3, 19))
        m.extra['ambient'] = 'motes'
    elif key == 'f3':  # the hall of ancestors: wards glowing in the floor, royal banners, old plaques
        for (x, y) in [(3, 8), (12, 8), (3, 17), (12, 17), (7, 12)]:
            life(m, 'crystal', x, y, color="#c8d8ff", s=0.9)
        on_tops(m, 'standard', [(14, y) for y in (3, 7, 11, 15, 19, 23)], color="#4a3a7a"); on_tops(m, 'torch', [(1, y) for y in (2, 9, 16, 23)]); sc('rubble', 3, (1, 13, 2, 24))
        m.extra['ambient'] = 'spirit'
    elif key == 'f4':  # the crown's last chamber: banners, braziers on the platforms
        on_tops(m, 'brazier', [(2, 7), (13, 7), (2, 16), (13, 16), (6, 20), (9, 20)], s=1.2); on_tops(m, 'standard', [(14, y) for y in (3, 8, 13, 18, 22)], color="#2a3f7a"); on_tops(m, 'torch', [(1, 3), (1, 21)])
        m.extra['ambient'] = 'motes'
    elif key == 'f5':  # the inner throne chamber: the King's banners, tall windows' light
        on_tops(m, 'brazier', [(3, 4), (12, 4), (3, 15), (12, 15)], s=1.2); on_tops(m, 'standard', [(14, y) for y in (3, 6, 9, 12, 15)], color="#2a3f7a"); on_tops(m, 'torch', [(1, 2), (1, 17)])
        m.extra['ambient'] = 'motes'
    elif key == 'ft':  # the great throne room, empty: banners, pale light, a long carpet
        on_tops(m, 'standard', [(14, y) for y in (3, 7, 11, 15, 19)], color="#2a3f7a"); on_tops(m, 'brazier', [(2, 5), (13, 5), (2, 17), (13, 17)], s=1.0)
        m.extra['ambient'] = 'motes'
    elif key == 'fg':  # the royal garden: a quiet cemetery, benches, a few lanterns, fallen leaves
        sc('grave', 4, (2, 5, 4, 10)); life(m, 'grave', 9, 17); life(m, 'lantern', 10, 16, color="#ffd88a"); life(m, 'lantern', 10, 18, color="#ffd88a"); on_tops(m, 'lantern', [(3, 3), (3, 20), (12, 3), (12, 20)], color="#ffd88a"); life(m, 'bench', 11, 5, rot=90); life(m, 'bench', 11, 18, rot=90)
        m.extra['ambient'] = 'leaves'
    elif key == 'fh':  # the hill at night: the city's lights far below
        sc('rubble', 3, (2, 12, 4, 20)); on_tops(m, 'torch', [(12, 12)])
        m.extra['ambient'] = 'fireflies'
    elif key == 'm1':  # the forgotten pass: torches on the barricades, banners left on the cliff, rusted weapons and bones along the road
        on_tops(m, 'torch', [(2, 12), (8, 12), (6, 20), (12, 20), (2, 13), (12, 21)])
        on_tops(m, 'banner', [(13, y) for y in (4, 9, 15, 21, 27)], color="#4a4a58")
        sc('rack', 4, (2, 12, 3, 27)); sc('bones', 8, (2, 12, 3, 27)); sc('rubble', 8, (2, 12, 3, 27)); sc('barrel', 3, (2, 12, 3, 27)); sc('crates', 3, (2, 12, 3, 27)); sc('wisp', 5, (2, 12, 3, 27), color=SPIRIT)
        on_tops(m, 'brazier', [(3, 28), (11, 28)], s=1.3)
        m.extra['ambient'] = 'leaves'
    elif key == 'm2':  # the forest watchpost: lanterns by the arch, fireflies, bones and rubble in the clearings
        on_tops(m, 'lantern', [(5, 19), (10, 19), (4, 4), (12, 8)], color="#ffd88a")
        on_tops(m, 'torch', [(11, 14), (3, 12), (12, 20), (5, 21), (10, 21)])
        sc('bones', 5, (1, 12, 1, 22)); sc('rubble', 6, (1, 12, 1, 22)); sc('crates', 3, (1, 12, 1, 22)); sc('rack', 2, (1, 12, 4, 20)); sc('wisp', 5, (1, 12, 1, 22), color="#c8ff9a")
        m.extra['ambient'] = 'fireflies'
    elif key == 'm3':  # the endless siege: war banners on the battlements, braziers by each wall, siege crates, embers
        on_tops(m, 'standard', [(14, y) for y in (3, 7, 11, 15, 19, 23, 27)], color="#7a2a2a")
        on_tops(m, 'brazier', [(1, 9), (12, 9), (1, 20), (12, 20), (3, 27), (11, 27)], s=1.2)
        on_tops(m, 'torch', [(13, y) for y in range(2, 30, 4)])
        sc('crates', 7, (1, 12, 3, 27)); sc('barrel', 5, (1, 12, 3, 27)); sc('rack', 3, (1, 12, 3, 27)); sc('rubble', 7, (1, 12, 3, 27)); sc('bones', 4, (1, 12, 3, 27)); sc('wisp', 6, (1, 12, 3, 27), color=SPIRIT)
        m.extra['ambient'] = 'embers'
    elif key == 'm4':  # the command courtyard: candles round the memorial, fallen graves, banners on the walls
        on_tops(m, 'brazier', [(5, 9), (9, 9), (5, 13), (9, 13)], s=0.9)
        on_tops(m, 'banner', [(14, y) for y in (3, 8, 13, 18, 22)], color="#2a3f7a")
        sc('grave', 10, (1, 12, 7, 16)); sc('bones', 3, (1, 12, 2, 22)); sc('rubble', 5, (1, 12, 2, 22)); sc('rack', 2, (1, 12, 2, 22)); sc('wisp', 7, (1, 12, 2, 22), color=SPIRIT)
        on_tops(m, 'torch', [(3, 18), (4, 19), (10, 18), (11, 19)])
        m.extra['ambient'] = 'spirit'
    elif key == 'm5':  # the Heart's chamber: crystals on the dais, wisps everywhere, broken monuments' rubble
        for (x, y) in [(5, 15), (10, 15), (5, 20), (10, 20), (7, 18), (8, 18)]:
            life(m, 'crystal', x, y, color=VIOLET, s=1.2)
        on_tops(m, 'torch', [(2, 6), (3, 6), (11, 6), (12, 6), (2, 13), (12, 14)])
        sc('wisp', 9, (1, 12, 2, 20), color=VIOLET); sc('bones', 5, (1, 12, 2, 20)); sc('rubble', 8, (1, 12, 2, 20)); sc('grave', 4, (1, 12, 2, 14))
        m.extra['ambient'] = 'spirit'
