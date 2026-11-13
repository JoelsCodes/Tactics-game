"""Checks the Last Benediction's navigation JSON (data/environment/last_benediction_nav.json, the owner's export) against the GLB.

  python3 godot/tools/environment/check_nav.py godot/art_src/environment/last_benediction/last_benediction.glb

Every one of the 121 tiles must sit at the GLB's `playable floor XX-YY` node position (x, and -z for y), and its elevation (0 or 1)
must match whether that floor node is raised. Prints the blocked tiles, the objective and the spawns. Exits 1 on any mismatch.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import extract_nav  # the GLB reader


def main(glb):
    nav = json.load(open(os.path.join(HERE, '..', '..', 'data', 'environment', 'last_benediction_nav.json'), encoding='utf-8'))
    g = extract_nav.main(glb, os.devnull)  # the GLB's tiles, read the same way as the extractor
    gt = {(t['col'], t['row']): t for t in g['tiles']}
    bad = []
    for t in nav['tiles']:
        k = (t['x'], t['y'])
        m = gt.get(k)
        if m is None or abs(t['world_center'][0] - m['x']) > 0.01 or abs(t['world_center'][1] + m['z']) > 0.01:
            bad.append(('position', k))
        if (t['elevation'] == 1) != m['raised']:
            bad.append(('elevation', k))
    blocked = sorted((t['x'], t['y']) for t in nav['tiles'] if t['blocked'])
    tiles = {(t['x'], t['y']): t for t in nav['tiles']}
    print('tiles %d, blocked %d %s' % (len(nav['tiles']), len(blocked), blocked))
    print('objective %s (blocked: %s), spawns %s (blocked: %s)' % (
        nav['objective'], tiles[tuple(nav['objective'])]['blocked'], nav['player_spawns'],
        [tiles[tuple(s)]['blocked'] for s in nav['player_spawns']]))
    print('mismatches with the GLB: %d %s' % (len(bad), bad[:6]))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1]))
