"""Nine enemy characters from the owner's grid sheets (Nov 2026), all in the Boar's layout (see grid_sheet.py): six blocks IDLE, WALK, ATTACK (a row per
direction: DOWN, UP, LEFT, RIGHT) and HURT, MAGIC, DEATH (one row facing the viewer), four frames each, on magenta, with the painted portrait.

  python3 godot/tools/art/enemy_sheets.py [key ...]        (run after eight_dir.py; `build_characters.sh` does)

These sheets differ from the Boar's in two ways, both handled by grid_sheet's `segment` option: the sprites are not on four equal slots (wings run over
them; a row drawn with three frames), and a dark violet shadow is painted under every figure. Each character's size comes from
idle_walk_sheet.standard_scale with the tile rule: as tall as the King, but never wider than one tile, so the slime, wolf and wyvern come out smaller.
"""
import sys

import grid_sheet

STD = dict(  # sheets 1-7: the layout of the Stone Colossus sheet
    size=(1536, 1024),
    blocks={
        'idle': dict(box=(479, 65, 801, 585), dirs=grid_sheet.ROWS), 'walk': dict(box=(807, 65, 1139, 585), dirs=grid_sheet.ROWS),
        'attack': dict(box=(1144, 65, 1525, 585), dirs=grid_sheet.ROWS),
        'hurt': dict(box=(13, 675, 510, 924), dirs=['s']), 'magic': dict(box=(531, 675, 1017, 924), dirs=['s']),
        'death': dict(box=(1038, 675, 1524, 924), dirs=['s']),
    },
    illustration=(14, 86, 383, 580))
BRUTE = dict(
    size=(1536, 1024),
    blocks={
        'idle': dict(box=(483, 67, 819, 620), dirs=grid_sheet.ROWS), 'walk': dict(box=(826, 67, 1158, 620), dirs=grid_sheet.ROWS),
        'attack': dict(box=(1165, 67, 1530, 620), dirs=grid_sheet.ROWS),
        'hurt': dict(box=(12, 720, 506, 949), dirs=['s']), 'magic': dict(box=(519, 720, 1021, 949), dirs=['s']),
        'death': dict(box=(1034, 720, 1527, 949), dirs=['s']),
    },
    illustration=(13, 80, 388, 617))
CUTTHROAT = dict(  # the ninth sheet: the three big blocks on top, the portrait bottom left
    size=(1536, 1024),
    blocks={
        'idle': dict(box=(96, 54, 536, 592), dirs=grid_sheet.ROWS), 'walk': dict(box=(543, 54, 1016, 593), dirs=grid_sheet.ROWS),
        'attack': dict(box=(1025, 54, 1532, 593), dirs=grid_sheet.ROWS),
        'hurt': dict(box=(306, 690, 688, 902), dirs=['s']), 'magic': dict(box=(694, 690, 1113, 902), dirs=['s']),
        'death': dict(box=(1123, 690, 1532, 902), dirs=['s']),
    },
    illustration=(6, 622, 297, 1014))

SOUL_WARDEN = dict(  # the tenth sheet: labels on the left, the portrait bottom left
    size=(1536, 1024),
    blocks={
        'idle': dict(box=(100, 56, 535, 667), dirs=grid_sheet.ROWS), 'walk': dict(box=(543, 56, 1015, 667), dirs=grid_sheet.ROWS),
        'attack': dict(box=(1024, 56, 1532, 667), dirs=grid_sheet.ROWS),
        'hurt': dict(box=(309, 766, 686, 963), dirs=['s']), 'magic': dict(box=(694, 766, 1113, 963), dirs=['s']),
        'death': dict(box=(1123, 766, 1532, 963), dirs=['s']),
    },
    illustration=(6, 694, 296, 1010))

# key -> (layout, the enemy's display name in the game: UnitLook.ENEMY_CHARACTERS)
CHARACTERS = {
    'stone_colossus': (STD, 'Stone Colossus'), 'forest_wolf': (STD, 'Forest Wolf'), 'moss_slime': (STD, 'Moss Slime'),
    'goblin_scavenger': (STD, 'Goblin Scavenger'), 'ironhollow_sentinel': (STD, 'Ironhollow Sentinel'), 'ashen_wyvern': (STD, 'Ashen Wyvern'),
    'hollowmark_assassin': (STD, 'Hollowmark Assassin'), 'riverband_brute': (BRUTE, 'Riverband Brute'), 'hooded_cutthroat': (CUTTHROAT, 'Hooded Cutthroat'),
    'soul_warden': (SOUL_WARDEN, 'Soul Warden'),
    # four more enemies (the owner's, Nov 2026), the Soul Warden's layout (its SKILL panel is the 'magic' block): a white-coated duelist, a half-stone warrior, a stone golem, a crystal crawler
    'spectral_duelist': (SOUL_WARDEN, 'Spectral Duelist'), 'crystalbound_warrior': (SOUL_WARDEN, 'Crystalbound Warrior'),
    'stone_golem': (SOUL_WARDEN, 'Stone Golem'), 'crystal_crawler': (SOUL_WARDEN, 'Crystal Crawler'),
    # the story's own characters (the owner's, Nov 2026), the Soul Warden's layout: the Last King (crowned, a staff), Elowen (a bow), Reave (a curved blade)
    'last_king': (SOUL_WARDEN, 'The Last King'), 'elowen': (SOUL_WARDEN, 'Elowen'), 'reave': (SOUL_WARDEN, 'Reave'),
    'gideon': (SOUL_WARDEN, 'Gideon'), 'kaelen': (SOUL_WARDEN, 'Kaelen'),   # chapter four's bosses, then vessels (CharacterLook.BY_ID)
    'vaelor': (SOUL_WARDEN, 'Commander Vaelor'), 'aldren': (SOUL_WARDEN, 'Captain Aldren'), 'seraphine': (SOUL_WARDEN, 'Seraphine'), 'malrec': (SOUL_WARDEN, 'Malrec'),
    # two enemy types (the owner's, Nov 2026; working names, ask the owner): a priest in white and gold with a censer, a hooded zealot in flame-torn cloth
    'sunward_priest': (SOUL_WARDEN, 'Sunward Priest'), 'ember_zealot': (SOUL_WARDEN, 'Ember Zealot'),
    # two future vessels (the owner's, Nov 2026; working names, no unit uses them yet): a hooded forager with a basket of glowing mushrooms, a warrior in shell and scale armour
    'mushroom_forager': (SOUL_WARDEN, 'Mushroom Forager'), 'shell_warrior': (SOUL_WARDEN, 'Shell Warrior'),   # Seraphine is a vessel (CharacterLook.BY_ID)
}
PIXEL = 0.65


# rows drawn with only three frames (the idle and walk of the wyvern facing left or right), as (block, direction)
THREE = {'ashen_wyvern': [('idle', 'w'), ('idle', 'e'), ('walk', 'w'), ('walk', 'e')]}


# blocks whose glow is violet (the assassins' magic): the despill that takes the magenta fringe off would turn it grey-green
VIOLET = {'hollowmark_assassin': ['magic'], 'hooded_cutthroat': ['magic']}

# sheets with stray specks of the panel under the feet (grid_sheet.segment_row's despeck): the story's own characters
DESPECK = {'last_king', 'elowen', 'reave', 'gideon', 'kaelen', 'vaelor', 'aldren', 'seraphine', 'malrec', 'sunward_priest', 'ember_zealot', 'mushroom_forager', 'shell_warrior'}


def config(key):
    layout, _ = CHARACTERS[key]
    return dict(key=key, src='art_src/characters/%s_sheet.png' % key, pixel=PIXEL, segment=True, match_idle=True, three=THREE.get(key, ()),
                keep_violet=VIOLET.get(key, ()), despeck=key in DESPECK, **layout)


if __name__ == '__main__':
    for k in (sys.argv[1:] or CHARACTERS):
        grid_sheet.build(config(k))
