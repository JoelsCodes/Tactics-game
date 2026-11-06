#!/usr/bin/env bash
# Screenshots in one command, at 1920x1080 on a virtual display (xvfb), sped up where the scene allows it.
#
#   bash godot/tools/shots.sh [what ...]
#
# what (default: intro):
#   intro            Alaric running, stumbling and limping up the path (beats stumble, hunted)
#   intro:all        every beat of the intro (start, run, stumble, limp, hunted, cave, knights, fade)
#   intro:<b>,<b>    the named intro beats only
#   battle           the battle screen on the King's first turn
#   battle:<step>    a battle_shot step: move, aim, confirm, forecast (the damage prediction), forecast_heal, abilities, summonmenu, summon, enemy, result
#   hallway          every step of the hallway scene (hallway:<b>,<b> for some)
#   first            the first battle as the hallway scene leaves it
#   return           every step of Alaric's return to the hallway after it
#   chamber          every step of the altar scene (chamber:<b>,<b> for some)
#   story_base       every step of the base conversation (scene base)
#   riverford:1..5   a Riverford battle as it starts (riverford:1 The Back Alleys ... riverford:5 Vesper's Wrath)
#   mountain:1..5    a chapter four battle as it starts
#   bellwether:1..5  a chapter five battle as it starts
#   crown:1..5       a chapter eight battle
#   expanse:1..5     a chapter six battle; vespera:1..5   a chapter seven battle
#   crucible:1..5    a chapter three battle as it starts (big maps; Lyra is the Co-Captain)
#   second           the chamber battle (with the tutorial) as the altar scene leaves it
#   world            the world map (the places the story has opened so far)
#   base             the base, free-roam (base:x,y puts Alaric at tile x,y)
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
		intro) run res://tests/intro_shot.tscn out="$OUT" beats=stumble,hunted speed="$SPEED" & ;;
		intro:all) run res://tests/intro_shot.tscn out="$OUT" speed="$SPEED" & ;;
		intro:*) run res://tests/intro_shot.tscn out="$OUT" beats="${what#intro:}" speed="$SPEED" & ;;
		hallway) run res://tests/intro_shot.tscn out="$OUT" scene=hallway delay=0.12 speed="$SPEED" & ;;
		hallway:*) run res://tests/intro_shot.tscn out="$OUT" scene=hallway beats="${what#hallway:}" delay=0.12 speed="$SPEED" & ;;
		return) run res://tests/intro_shot.tscn out="$OUT" scene=hallway_return delay=0.3 speed="$SPEED" & ;;
		chamber) run res://tests/intro_shot.tscn out="$OUT" scene=chamber delay=0.3 speed="$SPEED" & ;;
		chamber:*) run res://tests/intro_shot.tscn out="$OUT" scene=chamber beats="${what#chamber:}" delay=0.3 speed="$SPEED" & ;;
		story_base) run res://tests/intro_shot.tscn out="$OUT" scene=base delay=0.3 speed="$SPEED" & ;;
		world) run res://tests/screen_shot.tscn out="$OUT" scene=world & ;;
		base) run res://tests/screen_shot.tscn out="$OUT" scene=base &  ;;
		base:*) run res://tests/screen_shot.tscn out="$OUT" scene=base at="${what#base:}" & ;;
		crown:*) run res://tests/battle_shot.tscn out="$OUT/crown_${what#crown:}.png" setup=crown${what#crown:} & ;;
		expanse:*) run res://tests/battle_shot.tscn out="$OUT/expanse_${what#expanse:}.png" setup=expanse${what#expanse:} & ;;
		vespera:*) run res://tests/battle_shot.tscn out="$OUT/vespera_${what#vespera:}.png" setup=vespera${what#vespera:} & ;;
		bellwether:*) run res://tests/battle_shot.tscn out="$OUT/bellwether_${what#bellwether:}.png" setup=bellwether${what#bellwether:} & ;;
		mountain:*) run res://tests/battle_shot.tscn out="$OUT/mountain_${what#mountain:}.png" setup=mountain${what#mountain:} & ;;
		crucible:*) run res://tests/battle_shot.tscn out="$OUT/crucible_${what#crucible:}.png" setup=crucible${what#crucible:} & ;;
		riverford:*) run res://tests/battle_shot.tscn out="$OUT/riverford_${what#riverford:}.png" setup=riverford${what#riverford:} & ;;
		second) run res://tests/battle_shot.tscn out="$OUT/battle_chamber.png" setup=chamber & ;;
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
