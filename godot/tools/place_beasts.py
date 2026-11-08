#!/usr/bin/env python3
"""Places the owner's new enemy types (Nov 2026) in their battles: one enemy of the same role swapped for each new kind, so the battle's difficulty stays about the same.
Edits the maps' `spawns.enemies` kinds in godot/samples/*.json; safe to run again (it sets the kind at the given place), and to run after a map generator rewrote the file.
Run from the repo root: python3 godot/tools/place_beasts.py
"""
import json

# map file -> [(position of the enemy to swap, the new kind)]; the position is the enemy's start cell, as in the map's spawns
SWAPS = {
    'riverford_1': [([3, 13], 'sporecap')],         # a Rot-Hound -> a Spore Cap (the back alleys)
    'riverford_2': [([7, 12], 'rustcrab')],         # the Town Watchman -> a Rustshell Crab (the canal district)
    'crucible_2': [([11, 30], 'frostwarrior')],     # a Royal Legionnaire -> a Frostborn Warrior (the snow pass)
    'crucible_3': [([11, 31], 'embermoth'), ([9, 28], 'magmaram')],   # a Rune Mage -> an Ember Moth, a Royal Phalanx -> a Magma Ram (the lava terrace)
    'bellwether_3': [([8, 12], 'gorgemaw')],        # a Cave Eater -> a Gorge Maw (the mine)
    'vespera_3': [([5, 20], 'skullspider')],        # a Spectral Guardian -> a Skull Spider (the catacombs)
    'falcon_2': [([12, 18], 'prismmantis')],        # a Disturbed Wolf -> a Prism Mantis (the wilds)
}

import re

for name, swaps in SWAPS.items():
    p = 'godot/samples/%s.json' % name
    text = open(p).read()
    for at, kind in swaps:
        # edit the kind's word in place (the files keep their own formatting); a file writes "kind" then "at", or "at" then "kind"
        cell = r'"at":\s*\[\s*%d\s*,\s*%d\s*\]' % (at[0], at[1])
        before = re.compile(r'("kind":\s*")([a-z0-9_]+)("\s*,\s*' + cell + ')')
        after = re.compile('(' + cell + r'\s*,\s*"kind":\s*")([a-z0-9_]+)(")')
        found = before.findall(text) + after.findall(text)
        assert len(found) == 1, (name, at, found)
        print('%-14s %s: %s -> %s' % (name, at, found[0][1], kind))
        text = before.sub(lambda m: m.group(1) + kind + m.group(3), text)
        text = after.sub(lambda m: m.group(1) + kind + m.group(3), text)
    open(p, 'w').write(text)
