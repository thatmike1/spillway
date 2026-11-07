#!/usr/bin/env bash
# r13 overflow source checks, apart from the historical r12 suites in check-spillway.sh.
# active (decide the exit status): default-scene startup identity, the candidate motor, overflow
# geometry, the product lifecycle and any --route tape replayed through the product main.
# --controls adds the frozen CARRY profiles and the tape tool's own checks, reported as controls;
# --historical adds check-spillway.sh. source mode proves nothing about an exported pack: that
# is check-overflow-pack.sh. tools/check-overflow.sh [--out DIR] [--route TAPE]... [--controls] [--historical]
set -euo pipefail
GODOT="${GODOT:-$HOME/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64}"
cd "$(dirname "$0")/.."
out=""
routes=()
controls=false
historical=false
while (( $# )); do
	case "$1" in
		--out) out="$2"; shift 2 ;;
		--route) routes+=("$(realpath "$2")"); shift 2 ;;
		--controls) controls=true; shift ;;
		--historical) historical=true; shift ;;
		*) echo "unknown argument $1" >&2; exit 2 ;;
	esac
done
out="${out:-$(mktemp -d /tmp/overflow-check.XXXXXX)}"
mkdir -p "$out"
out="$(realpath "$out")"
case "$out/" in "$(git rev-parse --show-toplevel)"/*) echo "--out must be outside the Git checkout" >&2; exit 2 ;; esac
# isolated user data: no suite reads or writes the player's real profiles.
export XDG_DATA_HOME="$out/profile/data" XDG_CONFIG_HOME="$out/profile/config" XDG_CACHE_HOME="$out/profile/cache"
results=()
failed=0

run_clean() {
	# label, log name, engine args...: an exit status or any engine error fails the step.
	local label="$1" log="$out/$2.log" status=0
	shift 2
	"$GODOT" "$@" >"$log" 2>&1 || status=$?
	if (( status == 0 )) && ! rg -q 'SCRIPT ERROR:|(^|[[:space:]])ERROR:|Parse Error:|Failed to load script' "$log"; then
		results+=("PASS  $label")
		return 0
	fi
	results+=("FAIL  $label (exit $status, $log)")
	return 1
}

step() {
	local kind="$1"
	shift
	if ! "$@"; then
		[[ "$kind" == active ]] && failed=1
		[[ "$kind" == control ]] && control_failed=1
	fi
	return 0
}

startup() {
	run_clean "active: default scene starts r13" startup --headless --audio-driver Dummy --path . -- --verify-startup || return 1
	if ! rg -q '^r13 overflow: build=spillway-2026\.11\.07-r13-overflow; ' "$out/startup.log"; then
		results[-1]="FAIL  active: default scene starts r13 (no r13 startup line; project.godot runs another scene)"
		return 1
	fi
}

route() {
	# a recorded key/mouse tape through the product main, records off: clean, in order, no respawn.
	local tape="$1" name run
	name="$(basename "$(dirname "$tape")")-$(basename "$tape" .json)"
	run="$out/routes/$name"
	mkdir -p "$out/routes"
	if ! python3 tools/momentum-tape.py run "$tape" --out "$run" --headless --wall-budget 400 \
		--game-script res://scripts/momentum_overflow_main.gd --game-class '' >"$run.log" 2>&1; then
		results+=("FAIL  active: route $name (tape run failed, $run.log)")
		return 1
	fi
	local verdict
	verdict="$(python3 -I - "$run/evaluator/trace.jsonl" <<'PY'
import json, sys
rows = [json.loads(l) for l in open(sys.argv[1]) if '"phase":"tape"' in l]
game = rows[-1]["game"]
order = [r["game"]["checkpoint"] for r in rows]
ordered = all(b - a in (0, 1) for a, b in zip(order, order[1:]))
ok = game["finished"] and game["finish_kind"] == "clean" and game["respawns"] == 0 and ordered
print(("ok " if ok else "bad ") + "%s %.3f s, respawns %d, stages in order %s" % (game["finish_kind"], game["elapsed"], game["respawns"], ordered))
PY
)"
	if [[ "$verdict" == ok* ]] && ! rg -q 'SCRIPT ERROR:|(^|[[:space:]])ERROR:|Parse Error:' "$run/evaluator/godot.log"; then
		results+=("PASS  active: route $name (${verdict#ok })")
		return 0
	fi
	results+=("FAIL  active: route $name (${verdict#bad }, $run)")
	return 1
}

control_failed=0
run_clean "setup: import" import --headless --path . --import || { printf '%s\n' "${results[@]}"; exit 1; }
step active startup
step active run_clean "active: candidate air motor" motor --headless --fixed-fps 120 --path . --script res://tests/test_carry_air_candidate.gd -- "--out=$out/motor"
step active run_clean "active: overflow geometry" geometry --headless --path . --script res://tests/test_momentum_overflow.gd -- "--out=$out/geometry"
step active run_clean "active: product lifecycle and records" lifecycle --headless --audio-driver Dummy --fixed-fps 120 --path . --script res://tests/test_momentum_overflow_loop.gd -- "--out=$out/lifecycle"
for tape in "${routes[@]}"; do
	step active route "$tape"
done
if "$controls"; then
	step control run_clean "control: frozen CARRY broad/narrow profiles" carry --headless --fixed-fps 120 --path . --script res://tests/test_momentum_carry.gd -- "--out=$out/carry"
	if python3 tests/test_momentum_tape.py --only units audit --evidence "$out/tape-tool" >"$out/tape-tool.log" 2>&1; then
		results+=("PASS  control: tape tool units and audit")
	else
		results+=("FAIL  control: tape tool units and audit ($out/tape-tool.log)")
		control_failed=1
	fi
fi
if "$historical"; then
	if bash tools/check-spillway.sh >"$out/historical-r12.log" 2>&1; then
		results+=("PASS  historical: R12 check-spillway.sh")
	else
		results+=("FAIL  historical: R12 check-spillway.sh ($out/historical-r12.log)")
	fi
fi
printf '%s\n' "${results[@]}"
echo "evidence: $out"
if (( failed )); then echo "active r13 checks failed"; exit 1; fi
if (( control_failed )); then echo "active r13 checks passed; a control failed"; exit 3; fi
echo "active r13 checks passed"
