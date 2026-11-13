"""Builds the Last Benediction's 11x11 navigation data from its GLB (the playable floor nodes), since the separate navigation JSON was not
among the exports supplied (see godot/docs/HOLLOWMARK_V4_ASH_AND_AMETHYST.md, step 6).

  python3 godot/tools/environment/extract_nav.py <glb> <out.json>

Each `playable floor XX-YY` node is one tile: XX is the column (x, left to right: -6.2 .. 6.2 at 1.24 units a tile), YY the row (z, from
+6.2 at row 00 down to -6.2 at row 10). The floor's height (its translation y) is kept raw; a higher floor is a raised tile. The file has
no blocked-tile data and no objective markers, so `blocked` is left empty (to be confirmed) and only the altar and spawns the docs name
are listed, checked against the GLB's altar glyph nodes. Writes the JSON only: nothing in the game reads it yet.
"""
import json
import re
import struct
import sys

TILE = 1.24          # world units between two floor centres in the GLB
ORIGIN = -6.2        # the centre of tile (0, 0) on x and z


def load_nodes(path):
    with open(path, 'rb') as f:
        _magic, _ver, _len = struct.unpack('<4sII', f.read(12))
        cl, _ct = struct.unpack('<I4s', f.read(8))
        return json.loads(f.read(cl))


def main(glb, out):
    j = load_nodes(glb)
    tiles = {}
    for n in j['nodes']:
        m = re.match(r'playable floor (\d\d)-(\d\d)$', n.get('name', ''))
        if not m:
            continue
        c, r = int(m.group(1)), int(m.group(2))
        x, y, z = n['translation']
        tiles[(c, r)] = {'col': c, 'row': r, 'x': round(x, 4), 'y': round(y, 4), 'z': round(z, 4), 'raised': y > 0.5}
    assert len(tiles) == 121, 'expected 121 playable floors, found %d' % len(tiles)
    # the grid check: every centre sits on TILE spacing from ORIGIN
    for (c, r), t in tiles.items():
        assert abs(t['x'] - (ORIGIN + c * TILE)) < 0.01 and abs(t['z'] - (-ORIGIN - r * TILE)) < 0.01, (c, r)
    altar_glyphs = [n['translation'] for n in j['nodes'] if n.get('name', '').startswith('altar engraved glyph')]
    alt_x = sum(p[0] for p in altar_glyphs) / len(altar_glyphs)
    alt_z = sum(p[2] for p in altar_glyphs) / len(altar_glyphs)
    altar = (round((alt_x - ORIGIN) / TILE), round((-alt_z - ORIGIN) / TILE))
    data = {
        'source': 'last_benediction.glb (playable floor nodes)',
        'grid': [11, 11],
        'tile_size': TILE,
        'origin': [ORIGIN, -ORIGIN],
        'rows_top_to_bottom': 'row 00 is +z (the far edge in the GLB); column 00 is -x',
        'altar': list(altar),
        'altar_source': 'centre of the eight altar engraved glyph nodes',
        'spawns': [[4, 1], [6, 1]],
        'spawns_source': 'godot/docs/HOLLOWMARK_V4_ASH_AND_AMETHYST.md (not in the GLB)',
        'blocked': [],
        'blocked_source': 'not in the GLB: to be confirmed from the navigation JSON',
        'raised_tiles': sorted([[c, r] for (c, r), t in tiles.items() if t['raised']]),
        'tiles': [tiles[(c, r)] for r in range(11) for c in range(11)],
    }
    with open(out, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=1)
        f.write('\n')
    return data


if __name__ == '__main__':
    d = main(sys.argv[1], sys.argv[2])
    print('altar', d['altar'], 'raised tiles', len(d['raised_tiles']), 'tiles', len(d['tiles']))
