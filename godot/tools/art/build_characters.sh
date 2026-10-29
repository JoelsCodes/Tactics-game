#!/usr/bin/env bash
# Rebuilds every character from the owner's sheets in one go (see .claude/skills/add-character-sheet):
#   bash godot/tools/art/build_characters.sh            all characters
# Needs Python with Pillow, numpy, scipy, and godot on the PATH.
set -euo pipefail
cd "$(dirname "$0")/../.."                       # the godot/ folder
python3 tools/art/eight_dir.py                   # animations + manifest + meta.json
python3 tools/art/king_idle_walk.py               # the King's idle and walk from the owner's four-direction sheet (kept for the whole game)
python3 tools/art/lyra_idle_walk.py               # Lyra's idle and walk from the owner's four-direction sheet (kept for the whole game)
python3 tools/art/squire_idle_walk.py             # the Ashen Squire's idle and walk from the owner's four-direction sheet (kept for the whole game)
python3 tools/art/king_extras.py                 # the King's effects, portraits, looks, sword, illustration
python3 tools/art/char_extras.py                 # the same for the other full sheets
godot --headless --path . --import >/dev/null 2>&1 || true
godot --headless --path . --script res://tools/build_resources.gd | grep -c OK
# build_resources rewrites the older characters' .tres with new ids only: keep them unchanged
git checkout -- assets/characters/{brute,cardmage,dino,gunman,hero,knight,wolf}.tres 2>/dev/null || true
python3 tools/art/test_eight_dir.py | tail -1
godot --headless --path . res://tests/anim_check.tscn 2>&1 | grep -E "FAIL|anim checks"
