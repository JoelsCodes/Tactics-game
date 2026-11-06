#!/usr/bin/env bash
# Cuts ONE enemy sheet and builds only its files (no full rebuild of every character):
#   bash godot/tools/art/add_enemy.sh <key>      key = an entry of enemy_sheets.CHARACTERS (its sheet is art_src/characters/<key>_sheet.png)
# Then add the unit's display name to UnitLook.ENEMY_CHARACTERS and the name lists in tests/anim_check.gd.
set -e
cd "$(dirname "$0")/../.."
python3 tools/art/enemy_sheets.py "$1"
godot --headless --path . --import > /dev/null 2>&1
godot --headless --path . --script res://tools/build_resources.gd -- only="$1" | grep -E "frames $1"
git status --short | grep -v "^??" | head -5 || true
