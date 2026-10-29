---
name: add-character-sheet
description: Add (or rebuild) a character from one of the owner's AI-generated sprite sheets (magenta background, direction blocks IDLE/WALK/RUN/DASH, action blocks, particle row, portraits, colour palettes, weapon and illustration). Use when the owner sends a new character sheet, a corrected sheet, or asks to recut one.
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
- **Four-direction sheet** (DOWN, UP, LEFT, RIGHT, like Mira): copy the `SHEETS['mira']` block.
- **Bottom layout like the King's** (hand-placed): copy `SHEETS['king']`.
- Options: `'drop': {'heavy': [i, ...]}` removes cells that are only an effect; action `native` is
  `'left'` if the action frames face left; `dir_use` maps missing/wrong directions (UP-RIGHT/UP-LEFT
  showing the face → `'n'`).
- Run `python3 godot/tools/art/eight_dir.py`, then check by eye:
  `python3 godot/tools/art/contact.py <name> /tmp/c0.png 0` (idle/walk/run) and `... 1` (dash/actions).
  Look for merged or split frames, missing frames, wrong facing.

## 3. Extras: `godot/tools/art/char_extras.py`
- Add a `LAYOUT['<name>']` entry. Sheets laid out like Vesper's: `dict(_STD, palette_x=(x0, x1),
  weapon=(box), weapon_name='sword'|'staff', illustration=(box), looks=[8 names, 'original' first],
  fx=[(folder, effect, count), ...])` with the particle-row cells left to right
  (effects the game uses: `slash`, `circle`, `eruption`, `burst`, `smoke`).
- Find coordinates by cropping the bottom of the sheet with a grid drawn on it (PIL) and reading them.
- Recolors: run as they come out. **Do not spend time tuning recolors** (the owner's rule): no GAMMA,
  tolerance or keying tweaks, no look-by-look comparisons.

## 4. Wire it in
- `godot/scripts/stage/character_look.gd` `BY_ID`: `&"<unit id>": "<name>"` (unit ids are the lowercased
  name with underscores, see `scripts/dev/sample_party.gd`). The King is always `king`.
- Rebuild: `bash godot/tools/art/build_characters.sh` (cuts, imports, SpriteFrames, checks).
- Add the name to the loops in `godot/tests/anim_check.gd` (`roster_sheets`) and expect its look count.

## 5. Check and ship
- All test scenes from `CLAUDE.md`, `python3 godot/tools/art/test_eight_dir.py`, `test_magenta_key.py`.
- Screenshots: `xvfb-run -a -s "-screen 0 1920x1080x24" godot --path godot --resolution 1920x1080
  res://tests/lineup_shot.tscn -- out=/tmp/l.png` (add the name to its list), and
  `res://tests/ui_shot.tscn -- out=/tmp/a.png look=<look> who=<unit id>` for the Appearance screen.
  Needs `apt-get install -y mesa-vulkan-drivers xvfb` in a container without a GPU.
- Update the README section, commit and push. Say it was not checked on a real display.
