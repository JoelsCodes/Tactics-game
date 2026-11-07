#!/usr/bin/env python3
"""Writes the final arc's maps (chapters twelve to fifteen): godot/samples/arc12_1 .. arc15_5.json (twenty battles) and the scene stages arc_courtyard
(Silvermere's hidden fountain courtyard), arc_estate (the estate's rooms and archives), arc_chapel (the abandoned royal chapel) and arc_ruins (the ruins of
Alaric's village). Run from the repo root:  python3 godot/tools/make_final_maps.py
Every battle is built from one of a few themes (road, garden, interior, street, camp, fortress, chamber) with its own width, heights and walls; the walls
stagger across the way so the road to the foes is always a detour. Everyone starts out of reach (the shared checks in make_riverford_maps.py)."""
import random
src = open('godot/tools/make_riverford_maps.py').read()
exec(src[:src.index("rnd = random.Random")])   # Map, preview, check, finish
exec(open('godot/tools/life_kit.py').read())   # decorate()
MOVE.update({k: 5 for k in ['rsword', 'rarcher', 'rduel', 'rmage', 'rheavy', 'rchamp', 'rcmd', 'rext', 'rraid', 'rsab', 'rcapt', 'rvan', 'rspell', 'rofficer',
                            'fsword', 'fspear', 'farcher', 'fshield', 'fheavy', 'fcav', 'fmage', 'fhonor', 'fstd', 'fofficer', 'fcapt', 'felite', 'fcmd',
                            'gsent', 'gcons', 'gguard', 'vaelor', 'vaelor2', 'vaelor3', 'reave', 'elowen']})
MOVE.update({'fcav': 6})
problems = []
OUT = 'godot/samples/%s.json'
SP = lambda en: {"king": [6, 2], "captain": [8, 2], "stones": [[4, 1], [10, 1], [7, 4]], "enemies": [{"kind": k, "at": list(a)} for k, a in en]}
THEME = {  # base, lane, wall code, walls inside the rim, decoration, grade
    'road': ('g', 'd', 'q', False, 'k1', 'dusk'), 'garden': ('g', 'd', 'q', False, 'm2', 'golden'), 'interior': ('M', 'k', 'q', True, 'f3', 'slate'),
    'street': ('s', 'd', 'q', False, 'k4', 'golden'), 'camp': ('d', 'g', 'q', False, 'm3', 'dusk'), 'fortress': ('k', 's', 'q', True, 'k5', 'slate'),
    'chamber': ('M', 'o', 'q', True, 'f5', 'dusk'), 'chapel': ('M', 'o', 'q', True, 'f1', 'golden')}
BOSSES = ('vaelor', 'vaelor2', 'vaelor3', 'reave', 'elowen')


def build(key, title, theme, w, kinds, seed):
    base, lane, wall, rim, deco, grade = THEME[theme]
    r = random.Random(seed)
    m = Map(16, w, title)
    m.box(0, 15, 0, w - 1, base, 0)
    m.box(5, 10, 0, w - 1, lane, 0)
    hi = 13 if rim else 15
    if rim:
        for y in range(w): m.set(15, y, 'q', 6); m.set(14, y, 'q', 5)
    else:
        for (x0, x1, y0, y1) in [(0, 2, 3, 6), (12, 14, 4, 7)]:
            m.box(x0, x1, y0, y1, 't' if theme in ('road', 'garden', 'camp') else 'q', 0 if theme in ('road', 'garden', 'camp') else 2)
    rows = list(range(9, w - 2, 4))
    for i, y in enumerate(rows):                                   # staggered walls: the gap swaps sides every row
        gap = r.randint(2, 4)
        if i % 2 == 0: m.box(0, hi - gap, y, y, wall, 3)
        else: m.box(gap, hi, y, y, wall, 3)
    for _ in range(4):                                              # a few raised spots for height
        x, y = r.randint(1, hi - 3), r.randint(5, w - 4)
        if y not in rows and y - 1 not in rows and y + 1 not in rows:
            m.box(x, x + 1, y, y + 1, base if base != 'M' else 'M', 1)
    m.box(4, 11, w - 3, w - 1, 'o' if rim else base, 1); m.box(6, 9, w - 2, w - 1, 'o' if rim else base, 2)   # a rise at the far end
    if not rim: m.smooth()
    slots, used = [], set()
    free_rows = [y for y in range(12, w - 3) if y not in rows]
    xs = [4, 10, 7, 3, 12, 6, 9, 5, 11, 8]
    en = []
    bosses = [k for k in kinds if k in BOSSES]
    rest = [k for k in kinds if k not in BOSSES]
    for i, k in enumerate(rest):
        y = free_rows[(i * 2) % len(free_rows)] if len(free_rows) > 0 else 12
        x = xs[i % len(xs)]
        while (x, y) in used: x = (x + 3) % (hi - 1) + 1
        used.add((x, y)); en.append((k, (x, y)))
    for j, k in enumerate(bosses):
        c = (7 + j, w - 2)
        en.append((k, c))
    sp = SP(en)
    decorate(m, sp, deco, random.Random(seed + 1))
    m_key = key
    global OUT
    OUT = 'godot/samples/%s.json'
    return finish(m, sp, m_key, grade=grade, haze="light")


MAPS = [
    # chapter twelve: The Woman Who Returned
    ('arc12_1', "Arc 12-1: The Silvermere Road. A lane through neglected parkland to the summer estate, old walls across it", 'road', 22, ['fsword', 'fsword', 'farcher', 'fshield', 'farcher', 'fshield', 'fofficer']),
    ('arc12_2', "Arc 12-2: The Forgotten Gardens. Overgrown terraces, clipped hedges gone wild, garden sentinels on their plinths", 'garden', 24, ['gsent', 'gsent', 'fspear', 'fspear', 'fmage', 'gsent', 'gcons']),
    ('arc12_3', "Arc 12-3: The Royal Training Grounds. The estate's old drill yard, sand and stone, rails and targets", 'camp', 24, ['fheavy', 'fheavy', 'farcher', 'fcav', 'farcher', 'fcav', 'fcapt']),
    ('arc12_4', "Arc 12-4: The Hidden Chambers. A sealed undercroft of the estate: vaulted rooms, archive shelves, an old guardian", 'interior', 22, ['fhonor', 'fmage', 'fshield', 'fhonor', 'fmage', 'fshield', 'gguard']),
    ('arc12_5', "Arc 12-5: The Princess's Guardian. The estate's inner lawn before the hidden passage, and the commander who holds it", 'garden', 22, ['fhonor', 'fhonor', 'farcher', 'fmage', 'farcher', 'vaelor']),
    # chapter thirteen: A Kingdom Divided
    ('arc13_1', "Arc 13-1: The Princess's Guard. The fountain court and its colonnades, Falcon Guard on every side", 'chapel', 22, ['fhonor', 'farcher', 'fmage', 'fhonor', 'farcher', 'fmage', 'fcapt']),
    ('arc13_2', "Arc 13-2: The Divided Streets. A residential quarter of the capital, barricades and doorways", 'street', 24, ['rsword', 'rsword', 'rarcher', 'rext', 'rarcher', 'rext', 'rext', 'rcapt']),
    ('arc13_3', "Arc 13-3: The Revolutionary Vanguard. A warehouse yard behind the meeting hall, crates and loading ramps", 'street', 22, ['rduel', 'rduel', 'rsword', 'rmage', 'rsword', 'rmage', 'rvan']),
    ('arc13_4', "Arc 13-4: The Burning Standard. A strategic district by the river gate, a burning banner on the bridgehead", 'road', 24, ['fheavy', 'fcav', 'rarcher', 'rmage', 'fheavy', 'rarcher', 'fcav', 'fstd']),
    ('arc13_5', "Arc 13-5: The First Uprising. The capital's outer defenses under assault, the royal line holding", 'fortress', 24, ['rheavy', 'rheavy', 'fhonor', 'rspell', 'farcher', 'rspell', 'farcher', 'rcmd']),
    # chapter fourteen: The Lovers' War
    ('arc14_1', "Arc 14-1: The Shattered Crossing. A broken bridge town on the road to the meeting place, raiders in the ruins", 'road', 22, ['rext', 'rext', 'fspear', 'rraid', 'fspear', 'rraid', 'rsab']),
    ('arc14_2', "Arc 14-2: The Chapel's Last Guard. The abandoned royal chapel's nave and yard, the Falcon Guard left to stop pursuit", 'chapel', 22, ['fhonor', 'fmage', 'farcher', 'fhonor', 'fmage', 'farcher', 'fofficer']),
    ('arc14_3', "Arc 14-3: The General's Return. An open ridge and a ruined watch line, a Falcon Guard formation coming up the road", 'camp', 24, ['fheavy', 'fheavy', 'fcav', 'farcher', 'fcav', 'farcher', 'fcmd']),
    ('arc14_4', "Arc 14-4: The Fallen Banner. A Falcon Guard staging position in an old earthwork, banners and tents", 'camp', 24, ['fheavy', 'fhonor', 'fmage', 'fcav', 'fhonor', 'fmage', 'fcav', 'fstd']),
    ('arc14_5', "Arc 14-5: The March to Hollowmark. The last pass before the fortress, a walled road and its gatehouse", 'fortress', 24, ['felite', 'felite', 'rsword', 'fmage', 'rarcher', 'rsword', 'rarcher', 'rofficer']),
    # chapter fifteen: Hollowmark
    ('arc15_1', "Arc 15-1: The Hollowmark Approach. The fortress's outer works: ditches, a broken barbican, the thin air of the Vessel World's edge", 'fortress', 24, ['fsword', 'fsword', 'farcher', 'rheavy', 'farcher', 'rheavy', 'rofficer']),
    ('arc15_2', "Arc 15-2: The Army of Yesterday. The old military hall of Hollowmark, filled with the Falcon Guard", 'interior', 24, ['fhonor', 'fhonor', 'fmage', 'fcav', 'fshield', 'fmage', 'fshield', 'vaelor3']),
    ('arc15_3', "Arc 15-3: The Revolutionary Heart. Barracks and armories turned into Reave's last stronghold", 'interior', 22, ['rduel', 'rduel', 'rsword', 'rmage', 'rchamp', 'rmage', 'rchamp', 'rcmd']),
    ('arc15_4', "Arc 15-4: The Princess's Last Army. The ceremonial halls before the central chamber, Elowen's strongest vessels", 'interior', 24, ['felite', 'felite', 'fmage', 'fheavy', 'farcher', 'fmage', 'fheavy', 'fcmd']),
    ('arc15_5', "Arc 15-5: The Last Summoners. The central chamber of Hollowmark: a great round floor, a raised dais, the air thin and bright", 'chamber', 20, ['felite', 'felite', 'reave', 'elowen']),
]
for i, spec in enumerate(MAPS):
    problems += build(*spec, seed=2000 + i * 13)


def stage(name, text, theme, w, extra, seed):
    base, lane, wall, rim, deco, grade = THEME[theme]
    t = Map(16, w, text); t.box(0, 15, 0, w - 1, base, 0); t.box(5, 10, 0, w - 1, lane, 0)
    if rim:
        for y in range(w): t.set(15, y, 'q', 6); t.set(14, y, 'q', 5)
    extra(t)
    t.smooth()
    decorate(t, SP([('fsword', (8, w - 4))]), deco, random.Random(seed)); t.extra['grade'] = grade; t.extra['haze'] = 'light'
    t.save(name, None)


stage('arc_courtyard', "Silvermere: a hidden courtyard, a fountain in the middle, colonnades", 'chapel', 22,
      lambda t: (t.box(6, 9, 10, 12, 'e', 1), [t.box(x, x, y, y, 'q', 4) for x in (2, 12) for y in (4, 9, 14, 19)]), 2501)
stage('arc_estate', "Silvermere: the estate's rooms and archives, shelves, a chapel door, neglected furniture", 'interior', 22,
      lambda t: [t.box(1, 3, y, y + 1, 'q', 3) for y in (4, 10, 16)], 2502)
stage('arc_chapel', "An abandoned royal chapel: a nave of broken pews, an altar at the far end", 'chapel', 22,
      lambda t: (t.box(4, 11, 18, 21, 'o', 1), [t.box(x, x, y, y, 'q', 4) for x in (3, 11) for y in (5, 10, 15)]), 2503)
stage('arc_ruins', "The ruins of Alaric's village: old foundations in the grass, a burned beam, the road out", 'road', 22,
      lambda t: [t.box(x, x + 2, y, y, 'q', 1) for (x, y) in [(2, 6), (11, 8), (3, 14), (10, 16), (6, 19)]], 2504)
print('\nTOTAL PROBLEMS:', len(problems))
