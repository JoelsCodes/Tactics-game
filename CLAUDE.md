# Hollowmark Tactics: notes for Claude

**Fresh start (Oct 2026).** The owner had everything from the first build deleted: battle system, rules, classes, maps, menus, campaign and the web version. Only the art and how it is placed are kept. The old code is in git history (`202b479` and before); do not restore any of it unless the owner asks.

Work is in `godot/` (Godot 4.3+), branch `claude/godot-port`. **Read `godot/HANDOFF.md` (where the last session left off) and `godot/README.md` first.**

## Starting a session (setup and pitfalls)
- **Repo:** `JoelsCodes/tactics-game`, branch `claude/godot-port`. To edit it, the session needs the repo attached with push access (`add_repo` with `access: push`). With read access only, a clone works but nothing can be pushed.
- **Clone:** `git clone --branch claude/godot-port https://github.com/JoelsCodes/tactics-game`. If an anonymous clone fails on Git LFS, prefix it with `GIT_LFS_SKIP_SMUDGE=1`.
- **Godot 4.3:** the binary is not kept between sessions, so install it at the start of each one (about 50 MB download, under a minute):
  ```
  mkdir -p /tmp/godot-install && cd /tmp/godot-install && \
  curl -sSL -o godot.zip https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_linux.x86_64.zip && \
  unzip -q -o godot.zip && install -m 755 Godot_v4.3-stable_linux.x86_64 /usr/local/bin/godot && godot --version
  ```
  Expected output: `4.3.stable.official.77dcf97d8`. Downloading a binary can be blocked by the session's permission check; if it is, ask the owner rather than working around it.
- **Screenshots and the 3D board:** `apt-get update && apt-get install -y mesa-vulkan-drivers xvfb`. Headless tests need neither. Python needs Pillow, numpy and scipy for the art tools.
- **First run in a fresh clone:** `godot --headless --path godot --import` before any screenshot or test. Without it a screenshot can show old art from the import cache.
- **Commits:** the owner dropped the old "push only when I say push" rule (Nov 2026): commit and push finished work to `claude/godot-port`, and say what changed.
- **Art rebuilds:** `bash godot/tools/art/build_characters.sh` rewrites every `assets/characters/*.tres`. Afterwards, restore the characters you did not change with `git checkout -- assets/characters/<name>.tres` so the diff stays small.
- **Attacks and hits:** the King and the Ashen Squire have four-direction attacks from `art_src/characters/{king,squire}_attack_sheet.png`, cut by `tools/art/attack_sheet.py` through `king_attack.py` and `squire_attack.py`. Their `meta.json` entries set `slash_in_frames`, so battles add no second slash. A hit flashes the unit white and knocks it back a little (`UnitView3D.hit_react`); the hurt pose is not played on a hit (its frames are kept in the sheets). Hit frames for review: `tests/hit_shot.tscn`.
- **Hallway scene only:** the floor and walls outside the 8x10 come from `scripts/stage/outside_castle.gd` and are blurred by `scripts/stage/outside_blur.gd`. The battles in that hallway do not use them yet.

## Where the game stands
- Story (reworked Nov 2026): intro (forest chase, Alaric hurt) → hallway (squire catches him, slash) → first battle (Alaric, Rook style, one squire) → `hallway_return` (boots, he limps on) → `chamber` (altar, Bram and Lyra, the owner's dialogue) → chamber battle (two squires, summon tutorial) → `base` (the base conversation) → barracks. The King unit is called **Alaric**. The narration, the base dialogue, the tutorial texts and Bram's and Lyra's numbers are Claude's first drafts: see `godot/HANDOFF.md`.
- Open questions for the owner: what comes after the base conversation; what `samples/abandoned_hallway.json` is for; whether the castle and blur around the hallway stay; whether Lyra, a Co-Captain in `SampleParty`, stays one now that she is a vessel.
- Known limits: the squire's and King's shared canvases clip the far tips of their widest arcs (the King's down attack most); story and battle pushes still move a unit to its new tile.

## Before you start
- Ask the owner what to build next. There is no game design in the repo now; do not assume the old one.
- Do not build visuals before the owner has supplied art or a reference.
- Keep the session to one milestone. Use small edits, not whole-file rewrites, and look at few, small screenshots.

## Design rules the owner has set (do not undo)
- Loadout slots are exactly: Main Weapon, Weapon Style, Relic Slot 1, Relic Slot 2, plus the vessels-only Temp-Relic. Everything is set in the out-of-battle menus; nothing changes in battle.
- No pre-battle screen. The King is fixed on every mission; the player picks the Co-Captain in the barracks.
- A physical skill's footprint (shape) comes only from the weapon stance (Impact, Pierce, Axe). Skills have no shape of their own.
- Vessels are not pre-selected: the King summons any vessel he owns during battle, up to the map's summon limit (default 6, every summon counts).

## Working rules
- Commit and push finished work (see "Starting a session"). Commit messages end with the attribution trailers given in the session reminder.
- New terrain or biomes follow the terrain standard in `godot/README.md` (seamless baked tops, wrapping side strips, smooth hills by default).
- The battle screen is a 3D board (`Board3D`, Forward+ renderer). Screenshots need Vulkan (`mesa-vulkan-drivers` in a container without a GPU). For the screenshots the owner asks for, use `bash godot/tools/shots.sh` (see `godot/README.md`). The 2D `Terrain` is only the viewer now.
- Run `godot --headless --path godot res://tests/check.tscn`, `res://tests/core_check.tscn`, `res://tests/board_check.tscn` , `res://tests/units_check.tscn` , `res://tests/mentorship_check.tscn` , `res://tests/battle_check.tscn` , `res://tests/save_check.tscn` , `res://tests/exp_check.tscn` , `res://tests/stage_check.tscn`, `res://tests/ai_check.tscn`, `res://tests/anim_check.tscn`, `res://tests/intro_check.tscn`, `res://tests/hallway_check.tscn`, `res://tests/chamber_check.tscn` and `res://tests/hit_check.tscn` (and `python3 godot/tools/art/test_magenta_key.py` and `test_eight_dir.py` after art tool changes) before pushing. Test headless, check layout changes with a 1920x1080 screenshot, and say that it was not checked on a real display. The game targets a 16:9 desktop screen, not phones.
- The camera is static (the owner's rule): one lens, angle and distance everywhere (`Board3D.CAMERA_FOV`, `CAMERA_DISTANCE`), never pans, follows a unit, zooms or turns (no Rotate view). Story scenes and battles share one framing (`BattleStage.lock_camera`), so a scene turning into a battle does not shift. Maps must fit in that view.
- Every character is drawn as tall as the King (the owner's size standard, `idle_walk_sheet.STANDARD_FIGURE`); see the skill below.
- New character sheets from the owner: follow `.claude/skills/add-character-sheet/SKILL.md`; `bash godot/tools/art/build_characters.sh` rebuilds all characters. Do not spend time tuning the colour-look recolors.
- Never use `pkill -f`.
