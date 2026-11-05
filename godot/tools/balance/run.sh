#!/usr/bin/env bash
# The difficulty and balance simulator, one godot process per map in parallel, then one merged table.
#
#   bash godot/tools/balance/run.sh [runs=20] [maps=t,r1,r2,r3,r4,r5,c1,c2,c3] [party=0] [hp=1.0] [atk=0] [drop=0] [nerve=0.25] [seed=1000]
#
# The simulator (tests/balance_sim.gd) plays each story battle many times with the AI on both sides and reports win rate, length, what is left of the
# party, who falls and which enemies do the damage. Read it as a RAMP, not an absolute: the AI party plays worse than a person. The tutorial fight (t) is
# the yardstick. Results are also written to /tmp/balance/<map>.json. Needs godot only (no display).
set -u
cd "$(dirname "$0")/../../.."
MAPS="t,r1,r2,r3,r4,r5,c1,c2,c3"
ARGS=()
for a in "$@"; do
	case "$a" in
		maps=*) MAPS="${a#maps=}" ;;
		*) ARGS+=("$a") ;;
	esac
done
rm -rf /tmp/balance && mkdir -p /tmp/balance
for m in ${MAPS//,/ }; do
	godot --headless --path godot res://tests/balance_sim.tscn -- maps="$m" quiet=1 out="/tmp/balance/$m.json" "${ARGS[@]}" > "/tmp/balance/$m.log" 2>&1 &
done
wait
echo "| map | runs | win rate | verdict | rounds | party HP left (wins) | party KOs | King KO'd | stalled | s/fight |"
echo "|---|---|---|---|---|---|---|---|---|---|"
for m in ${MAPS//,/ }; do grep -E "^\| $m " "/tmp/balance/$m.log"; done
echo
for m in ${MAPS//,/ }; do grep -E "damage dealt" "/tmp/balance/$m.log"; done
