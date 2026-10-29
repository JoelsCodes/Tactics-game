---
name: add-character-sheet
description: Add (or rebuild) a character from one of the owner's AI-generated sprite sheets (magenta background, direction blocks IDLE/WALK/RUN/DASH, action blocks, particle row, portraits, colour palettes (not used), weapon and illustration). Use when the owner sends a new character sheet, a corrected sheet, or asks to recut one.
---

# Adding a character sheet

Everything is scripted; a new sheet needs only a few table entries. Read `godot/README.md` sections
"The King (eight-direction sheet)" and "The other full sheets" for the details and known limits.

## 1. Save the source
- Copy the image to `godot/art_src/characters/<name>_sheet.webp` (never edit it).
- Ask the owner who the character is (which unit) if they did not say.

## 2. Animations: `godot/tools/art/eight_dir.py`
- **Same layout as Vesper/Squire/Choir/Wraith** (8 direction blocks in 2 rows of 4: DOWN, DOWN-RIGHT, RIGHT,
  UP-RIGHT / UP, UP-LEFT, LEFT, DOWN-LEFT; 4 action blocks; particle row): add one line to the dict in the
  `for _n, _cols in {...}` loop: `'<name>': dict(attack=4, heavy=4, cast=4, hurt_death=4)` = frames per row
  of each action block (a list like `[5, 4]` when the two rows differ).
- **Four-direction sheet** (DOWN, UP, LEFT, RIGHT, like Lyra): copy the `SHEETS['mira']` block.
- **Bottom layout like the King's** (hand-placed): copy `SHEETS['king']`.
- Options: `'drop': {'heavy': [i, ...]}` removes cells that are only an effect; action `native` is
  `'left'` if the action frames face left; `dir_use` maps missing/wrong directions (UP-RIGHT/UP-LEFT
  showing the face → `'n'`).
- Run `python3 godot/tools/art/eight_dir.py`, then check by eye:
  `python3 godot/tools/art/contact.py <name> /tmp/c0.png 0` (idle/walk/run) and `... 1` (dash/actions).
  Look for merged or split frames, missing frames, wrong facing.

## 3. Extras: `godot/tools/art/char_extras.py`
- Add a `LAYOUT['<name>']` entry. Sheets laid out like Vesper's: `dict(_STD,
  weapon=(box), weapon_name='sword'|'staff', illustration=(box), fx=[(folder, effect, count), ...])` with the particle-row cells left to right
  (effects the game uses: `slash`, `circle`, `eruption`, `burst`, `smoke`).
- Find coordinates by cropping the bottom of the sheet with a grid drawn on it (PIL) and reading them.
- The sheet's colour palettes are not used (the owner removed colour variations): do not cut or bake them.

## 4. Wire it in
- `godot/scripts/stage/character_look.gd` `BY_ID`: `&"<unit id>": "<name>"` (unit ids are the lowercased
  name with underscores, see `scripts/dev/sample_party.gd`). The King is always `king`.
- Rebuild: `bash godot/tools/art/build_characters.sh` (cuts, imports, SpriteFrames, checks).
- Add the name to the loops in `godot/tests/anim_check.gd` (`roster_sheets`).

## 5. Check and ship
- All test scenes from `CLAUDE.md`, `python3 godot/tools/art/test_eight_dir.py`, `test_magenta_key.py`.
- Screenshots: `xvfb-run -a -s "-screen 0 1920x1080x24" godot --path godot --resolution 1920x1080
  res://tests/lineup_shot.tscn -- out=/tmp/l.png` (add the name to its list).
  Needs `apt-get install -y mesa-vulkan-drivers xvfb` in a container without a GPU.
- Update the README section, commit and push. Say it was not checked on a real display.

## Size standard

Every new or rebuilt full sheet is scaled to `BODY_TARGET` (123 px) in `godot/tools/art/eight_dir.py`: the owner's standard, taken from the King's size. Do not give a character its own size; the pipeline sets `meta.json` `scale` from it. The 3D board centres each unit on its tile from `meta.anchor` (both x and y), so keep the feet at the anchor.

## Lyra's idle and walk

Lyra's idle and walk come from the owner's four-direction sheet too, `art_src/characters/lyra_idle_walk_sheet.png`, cut by `godot/tools/art/lyra_idle_walk.py` (her sheet folder is still `mira`). `build_characters.sh` runs it right after `eight_dir.py` and before `char_extras.py`, like the King's. Do not remove that step.

## The Ashen Squire's idle and walk

The Ashen Squire's idle and walk come from the owner's four-direction sheet too, `art_src/characters/squire_idle_walk_sheet.png`, cut by `godot/tools/art/squire_idle_walk.py` (a thin wrapper over the shared `idle_walk_sheet.py`: give it the sheet's boxes and the character's canvas, feet and figure height). `build_characters.sh` runs it right after `eight_dir.py`. Do not remove that step.

## The King's idle and walk

The King's idle and walk come from the owner's own four-direction sheet, `art_src/characters/king_idle_walk_sheet.png`, and stay for the rest of the game. `godot/tools/art/king_idle_walk.py` cuts them and `build_characters.sh` runs it right after `eight_dir.py` (which would otherwise put back the old one-frame idle). Do not remove that step.

## Four directions only

The owner's rule: the game uses four directions only. `SpriteAnimator.dir_of` snaps every facing to e, s, w or n (the larger screen axis; a diagonal reads as the front or back view). New sheets need just four directions, down, right, up and left (the King's idle and walk sheet is the model). The eight-direction names in the data (`idle_se` and so on) stay valid, but they are never chosen, so a sheet's diagonal frames are unused.
