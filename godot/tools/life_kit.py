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
