#!/usr/bin/env bash
# Screenshots in one command, at 1920x1080 on a virtual display (xvfb), sped up where the scene allows it.
#
#   bash godot/tools/shots.sh [what ...]
#
# what (default: intro):
#   intro            the King walking up the path and standing at the entrance (beats dialogue, stop)
#   intro:all        every beat of the intro (start, dialogue, stop, cave, knights, knight_line, fade)
#   intro:<b>,<b>    the named intro beats only
#   battle           the battle screen on the King's first turn
#   battle:<step>    a battle_shot step: move, aim, confirm, abilities, summonmenu, summon, enemy, result
#   hallway          every step of the hallway scene (hallway:<b>,<b> for some)
#   first            the first battle as the hallway scene leaves it
#   return           every step of the King's return to the hallway after it
#   second           the second battle as the return scene leaves it
#   nearfar          the King in battle on his tile farthest from the camera and nearest to it
#   all              intro, battle and nearfar
#
# Frames go to $SHOTS_OUT (default /tmp/hollowmark_shots), which is emptied first; the paths are printed at the end.
# Needs godot, xvfb-run and mesa-vulkan-drivers (see README). Not a real display.
set -u
cd "$(dirname "$0")/.."
OUT="${SHOTS_OUT:-/tmp/hollowmark_shots}"
SPEED="${SHOTS_SPEED:-4}"
rm -rf "$OUT" && mkdir -p "$OUT"
[ $# -eq 0 ] && set -- intro
[ "$*" = all ] && set -- intro battle nearfar

run() {  # run <scene> <args...>: one godot run on its own virtual display
	timeout 300 xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . "$1" -- "${@:2}" 2>&1 \
		| grep -E "^(saved|far|near|SCRIPT ERROR)" || true
}

# re-import changed art first: a run without the editor reads Godot's import cache, so frames re-cut since the last
# import would otherwise be shot as their old versions
timeout 300 godot --headless --path . --import >/dev/null 2>&1 || true

pids=()
for what in "$@"; do
	case "$what" in
		intro) run res://tests/intro_shot.tscn out="$OUT" beats=dialogue,stop speed="$SPEED" & ;;
		intro:all) run res://tests/intro_shot.tscn out="$OUT" speed="$SPEED" & ;;
		intro:*) run res://tests/intro_shot.tscn out="$OUT" beats="${what#intro:}" speed="$SPEED" & ;;
		hallway) run res://tests/intro_shot.tscn out="$OUT" scene=hallway delay=0.12 speed="$SPEED" & ;;
		hallway:*) run res://tests/intro_shot.tscn out="$OUT" scene=hallway beats="${what#hallway:}" delay=0.12 speed="$SPEED" & ;;
		return) run res://tests/intro_shot.tscn out="$OUT" scene=hallway_return delay=0.3 speed="$SPEED" & ;;
		second) run res://tests/battle_shot.tscn out="$OUT/battle_second.png" setup=second & ;;
		first) run res://tests/battle_shot.tscn out="$OUT/battle_first.png" setup=first & ;;
		battle) run res://tests/battle_shot.tscn out="$OUT/battle.png" & ;;
		battle:*) run res://tests/battle_shot.tscn out="$OUT/battle_${what#battle:}.png" step="${what#battle:}" & ;;
		nearfar) run res://tests/king_nearfar_shot.tscn out="$OUT" speed="$SPEED" & ;;
		*) echo "unknown shot: $what" >&2; continue ;;
	esac
	pids+=($!)
done
for p in "${pids[@]}"; do wait "$p"; done
ls -1 "$OUT"/*.png 2>/dev/null || echo "no frames saved" >&2
