#!/usr/bin/env bash
# r14 source checks on a frozen snapshot outside the checkout, apart from r13's check-overflow.sh.
# active (decide the exit status): default-scene startup identity, the source oracle, the
# source motion, live collision and repair gates, the product loop, both maps' geometry, the
# frozen registry/map/key identity and every --route tape replayed through the r14 main.
# retained: the independent source review and the loop review must fail exactly their known,
# documented cases (docs/r14/DELIVERY.md); a new failure or a newly passing case both fail.
# controls (--controls): one labelled control per family in the frozen registry; a family with
# no known control is reported uncovered. --root-routes adds all five current overflow
# tapes, compared tick for tick with their actual-r14-main reference traces.
# source mode proves nothing about an exported pack: that is check-r14-pack.sh.
# tools/check-r14.sh [--out DIR] [--source head|worktree] [--route SPEC]... [--root-routes] [--controls]
set -euo pipefail
GODOT="${GODOT:-$HOME/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64}"
ROOT_EVIDENCE=/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r14
cd "$(dirname "$0")/.."
project="$(pwd)"
out=""
source_mode=head
routes=()
root_routes=false
controls=false
while (( $# )); do
	case "$1" in
		--out) out="$2"; shift 2 ;;
		--source) source_mode="$2"; shift 2 ;;
		--route) routes+=("$2"); shift 2 ;;
		--root-routes) root_routes=true; shift ;;
		--controls) controls=true; shift ;;
		*) echo "unknown argument $1" >&2; exit 2 ;;
	esac
done
out="${out:-$(mktemp -d /tmp/r14-check.XXXXXX)}"
mkdir -p "$out"
out="$(realpath "$out")"
top="$(git rev-parse --show-toplevel)"
case "$out/" in "$top"/*) echo "--out must be outside the Git checkout" >&2; exit 2 ;; esac
if [[ -n "$(ls -A "$out")" ]]; then echo "--out must be new or empty" >&2; exit 2; fi
# isolated user data: no suite reads or writes the player's real profiles.
export XDG_DATA_HOME="$out/profile/data" XDG_CONFIG_HOME="$out/profile/config" XDG_CACHE_HOME="$out/profile/cache"
src="$out/source"
mkdir -p "$src"
prefix="$(git rev-parse --show-prefix)"
case "$source_mode" in
	head)
		git -C "$top" archive --format=tar "HEAD:${prefix%/}" | tar -x -C "$src"
		label="HEAD $(git rev-parse HEAD) (tree $(git rev-parse HEAD:./))"
		dirty="$(git status --porcelain --untracked-files=all -- . | head -20)"
		[[ -n "$dirty" ]] && label="$label; the working tree differs and is NOT what was checked" ;;
	worktree)
		# p / a labelled diagnostic: tracked and untracked, not ignored, files as they stand now.
		git ls-files -co --exclude-standard -z -- . | tar --null -T - -c | tar -x -C "$src"
		label="working tree at HEAD $(git rev-parse HEAD) with uncommitted changes: diagnostic, not a committed source" ;;
	*) echo "--source is head or worktree" >&2; exit 2 ;;
esac
echo "source: $label" | tee "$out/SOURCE.txt"
(cd "$src" && find . -type f ! -path './.godot/*' -print0 | sort -z | xargs -0 sha256sum) > "$out/source-sha256.txt"
results=()
failed=0
control_failed=0

clean_log() {
	! rg -q 'SCRIPT ERROR:|(^|[[:space:]])ERROR:|Parse Error:|Failed to load script' "$1"
}

run_clean() {
	# label, log name, engine args...: an exit status or any engine error fails the step.
	local label="$1" log="$out/$2.log" status=0
	shift 2
	(cd "$src" && "$GODOT" "$@") >"$log" 2>&1 || status=$?
	if (( status == 0 )) && clean_log "$log"; then
		results+=("PASS  $label ($(tail -n 1 "$log" | cut -c1-160))")
		return 0
	fi
	results+=("FAIL  $label (exit $status, $log)")
	return 1
}

pack_traces() {
	# a suite's per-episode traces become one tarball beside its summary.
	local dir="$1"
	if [[ -d "$dir/traces" ]]; then
		tar -czf "$dir/traces.tar.gz" -C "$dir" traces && rm -rf "$dir/traces"
	fi
	find "$dir" -name '*.jsonl' -exec gzip -9 {} \; 2>/dev/null || true
}

step() {
	local kind="$1"
	shift
	if ! "$@"; then
		[[ "$kind" == active || "$kind" == retained ]] && failed=1
		[[ "$kind" == control ]] && control_failed=1
	fi
	return 0
}

startup() {
	run_clean "active: default scene starts r14" startup --headless --audio-driver Dummy --path . -- --verify-startup || return 1
	if ! rg -q '^r14: build=spillway-2026\.11\.08-r14; map=practice; preset=server128; physics_hz=128; course_key=[0-9a-f]{16}; records=off; runner=res://scripts/r14_source_player\.gd; renderer=gl_compatibility$' "$out/startup.log"; then
		results[-1]="FAIL  active: default scene starts r14 (no r14 practice/server128 startup line; project.godot runs another scene or preset)"
		return 1
	fi
}

oracle() {
	if (cd "$src" && python3 -I tests/r14_source_oracle.py --self-test) >"$out/oracle-self-test.log" 2>&1 \
		&& (cd "$src" && python3 -I tests/r14_source_oracle.py) >"$out/oracle-predictions.json" 2>"$out/oracle.log"; then
		results+=("PASS  active: independent oracle self-test and predictions ($(sha256sum "$out/oracle-predictions.json" | cut -c1-16))")
		return 0
	fi
	results+=("FAIL  active: independent oracle ($out/oracle-self-test.log)")
	return 1
}

retained() {
	# label, summary json, python expression for the failed names, known names...: exact match.
	local label="$1" summary="$2" names="$3"
	shift 3
	local verdict
	verdict="$(python3 -I - "$summary" "$names" "$@" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
failed = sorted(eval(sys.argv[2], {"d": data}))
known = sorted(sys.argv[3:])
total = len(data["checks"]) if isinstance(data, dict) and "checks" in data else len(data)
if failed == known:
    print("ok %d checks, exactly the %d retained failures" % (total, len(known)))
else:
    print("bad new failures %s; retained cases now passing %s" % (sorted(set(failed) - set(known)), sorted(set(known) - set(failed))))
PY
)" || verdict="bad unreadable $summary"
	if [[ "$verdict" == ok* ]]; then
		results+=("PASS  retained: $label (${verdict#ok })")
		return 0
	fi
	results+=("FAIL  retained: $label (${verdict#bad })")
	return 1
}

source_review() {
	local dir="$out/source-review" engine_status=0 status=0
	(cd "$src" && "$GODOT" --headless --audio-driver Dummy --fixed-fps 128 --path . --script res://tests/r14_source_review.gd -- "--out=$dir") >"$out/source-review.log" 2>&1 || engine_status=$?
	if (( engine_status != 1 )); then
		results+=("FAIL  retained: independent source review (expected its retained-case exit 1, got $engine_status)")
		return 1
	fi
	clean_log "$out/source-review.log" || { results+=("FAIL  retained: independent source review (engine error, $out/source-review.log)"); return 1; }
	retained "independent source review, earned two-plane approaches that never reach two planes" "$dir/summary.json" \
		'[c["name"] for c in d["checks"] if not c["pass"]]' \
		slope_flat_probe_contacts_earned_trial1 slope_flat_probe_contacts_earned_trial2 \
		slope_flat_probe_contacts_earned_phase_y138.5 slope_flat_probe_contacts_earned_phase_y139.0 \
		slope_flat_probe_contacts_earned_phase_y139.5 slope_flat_probe_contacts_earned_phase_y140.5 \
		slope_flat_probe_contacts_earned_phase_y141.0 slope_flat_probe_contacts_earned_phase_y142.0 \
		slope_flat_probe_contacts_earned_phase_y144.0 slope_flat_probe_contacts_earned_phase_y148.0 || status=1
	pack_traces "$dir"
	return "$status"
}

loop_review() {
	local dir="$out/loop-review" status=0 engine_status=0 analyze_status=0
	(cd "$src" && "$GODOT" --headless --audio-driver Dummy --fixed-fps 120 --path . --script res://tests/r14_loop_review.gd -- "--out=$dir") >"$out/loop-review.log" 2>&1 || engine_status=$?
	if (( engine_status != 1 )); then
		results+=("FAIL  retained: loop review (expected its retained-case exit 1, got $engine_status)")
		return 1
	fi
	clean_log "$out/loop-review.log" || { results+=("FAIL  retained: loop review (engine error, $out/loop-review.log)"); return 1; }
	retained "loop review, the deliberate manual-wheel negative" "$dir/checks.json" \
		'[c["name"] for c in (d["checks"] if isinstance(d, dict) else d) if not c["ok"]]' \
		"wheel released before a tick causes another real hop" || status=1
	(cd "$src" && python3 -I tests/r14_loop_review_analyze.py "$dir/trace.jsonl" "--out=$dir/reductions.json") >"$out/loop-review-reductions.log" 2>&1 || analyze_status=$?
	if (( analyze_status != 1 )); then
		results+=("FAIL  retained: loop review reductions (expected its retained-case exit 1, got $analyze_status)")
		status=1
	fi
	retained "loop review reductions, the post-switch hop of that negative" "$dir/reductions.json" \
		'[c["name"] for c in d["checks"] if not c["ok"]]' \
		"missed post-switch hop has actual height rise and descent" || status=1
	pack_traces "$dir"
	return $status
}

identity_routes() {
	local args=()
	for r in "${routes[@]}"; do args+=(--route "$r"); done
	if (cd "$src" && python3 -I tools/package-r14.py source --source "$src" --evidence "$out/identity-routes" "${args[@]}") >"$out/identity-routes.log" 2>&1; then
		while IFS= read -r line; do results+=("PASS  active: ${line#PASS }"); done < <(rg '^PASS ' "$out/identity-routes.log")
		return 0
	fi
	while IFS= read -r line; do results+=("${line%% *}  active: ${line#* }"); done < <(rg '^(PASS|FAIL) ' "$out/identity-routes.log")
	rg -q '^(PASS|FAIL) ' "$out/identity-routes.log" || results+=("FAIL  active: identity and routes ($out/identity-routes.log)")
	return 1
}

family_controls() {
	# one labelled control per family the frozen registry actually holds.
	local families
	families="$(python3 -I -c 'import gzip,json,sys; d=json.load(open(sys.argv[1])); print(" ".join(sorted({p["family"] for p in d["identity"]["registry"]["presets"].values() if p["available"]})))' "$out/identity-routes/summary.json" 2>/dev/null)" || families=""
	[[ -z "$families" ]] && { results+=("FAIL  control: no frozen registry to read families from"); return 1; }
	local status=0
	for family in $families; do
		case "$family" in
			source) results+=("PASS  control: source family is covered by the active source gates above") ;;
			r13)
				run_clean "control: r13 family, unchanged candidate air motor" carry --headless --fixed-fps 120 --path . --script res://tests/test_carry_air_candidate.gd -- "--out=$out/carry" || status=1
				pack_traces "$out/carry"
				run_clean "control: r13 family, unchanged r13 product lifecycle" r13-lifecycle --headless --audio-driver Dummy --fixed-fps 120 --path . --script res://tests/test_momentum_overflow_loop.gd -- "--out=$out/r13-lifecycle" || status=1 ;;
			*) results+=("FAIL  control: family $family has no known control suite (uncovered, not judged)"); status=1 ;;
		esac
	done
	return $status
}

if [[ "$root_routes" == true ]]; then
	s=5.729577951308232
	base="$ROOT_EVIDENCE/overflow-final-source"
	routes+=("map=overflow,preset=server128,name=current-overflow-server128,sensitivity=$s,tape=$base/record-server2/events.tape.json,reference=$base/replay-server2-normalized/evaluator/trace.jsonl.gz")
	for preset in vanilla64 server128_aa1000 quake3_inspired128; do
		routes+=("map=overflow,preset=$preset,name=current-overflow-$preset,sensitivity=$s,tape=$base/record-$preset/events.tape.json,reference=$base/replay-current-$preset/evaluator/trace.jsonl.gz")
	done
	# the control reference is now the r14 main too; its older r13-main comparison stays separate.
	routes+=("map=overflow,preset=r13_original120,name=current-overflow-r13,tape=$ROOT_EVIDENCE/r13-control/source-ordinary/evaluator/plan.json,reference=$base/replay-current-r13_original120/evaluator/trace.jsonl.gz")
fi

run_clean "setup: import" import --headless --path . --import || { printf '%s\n' "${results[@]}"; exit 1; }
step active startup
step active oracle
step active run_clean "active: source motion (pure, against the oracle)" math --headless --path . --script res://tests/test_r14_source_motion.gd -- "--out=$out/math" "--oracle=$out/oracle-predictions.json"
step active run_clean "active: source player (real collision, input events)" live --headless --fixed-fps 128 --path . --script res://tests/test_r14_source_player.gd -- "--out=$out/live"
step active run_clean "active: source collision repair gates" repair --headless --audio-driver Dummy --fixed-fps 128 --path . --script res://tests/r14_source_repair.gd -- "--out=$out/repair"
step active run_clean "active: conservative Source landing guard" guard --headless --audio-driver Dummy --fixed-fps 128 --path . --script res://tests/r14_contact_guard.gd -- "--out=$out/guard"
step active run_clean "active: r14 product loop" loop --headless --audio-driver Dummy --fixed-fps 120 --path . --script res://tests/test_r14_loop.gd -- "--out=$out/loop"
step active run_clean "active: live F4 comparison and independent vectors" quake --headless --audio-driver Dummy --fixed-fps 128 --path . --script res://tests/test_r14_quake.gd -- "--out=$out/quake" "--oracle=$ROOT_EVIDENCE/quake-prototype/oracle.json"
step active run_clean "active: stage practice through the menu" stage-practice --headless --audio-driver Dummy --fixed-fps 120 --path . --script res://tests/test_r14_stage_practice.gd -- "--out=$out/stage-practice"
step active run_clean "active: exact record ticks and fresh-process reload" record-precision --headless --audio-driver Dummy --fixed-fps 120 --path . --script res://tests/test_r14_record_precision.gd -- "--out=$out/record-precision"
step active run_clean "active: independent record ranking challenge" record-review --headless --audio-driver Dummy --fixed-fps 120 --path . --script res://tests/r14_record_display_review.gd -- "--out=$out/record-review"
step active run_clean "active: penstock yard geometry" practice --headless --path . --script res://tests/test_r14_practice_level.gd -- "--out=$out/practice"
step active run_clean "active: tapered tail return" tail-return --headless --audio-driver Dummy --fixed-fps 128 --path . --script res://tests/test_r14_tail_return.gd -- "--out=$out/tail-return"
step active run_clean "active: overflow geometry" geometry --headless --path . --script res://tests/test_momentum_overflow.gd -- "--out=$out/geometry"
for d in math live repair guard quake stage-practice record-precision record-review tail-return; do pack_traces "$out/$d"; done
step retained source_review
step retained loop_review
step active identity_routes
if "$controls"; then
	step control family_controls
fi
rm -rf "$out/profile/cache" "$src/.godot"
printf '%s\n' "${results[@]}" | tee "$out/RESULTS.txt"
echo "evidence: $out"
if (( failed )); then echo "active or retained r14 checks failed"; exit 1; fi
if (( control_failed )); then echo "active r14 checks passed; a control failed or a family is uncovered"; exit 3; fi
echo "active r14 checks passed"
