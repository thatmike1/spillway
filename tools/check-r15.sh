#!/usr/bin/env bash
# r15 source gates on a frozen external snapshot; this is never exported-pack acceptance.
# default checks require all eight maps and source-mode route proofs supplied with --route.
# --core-only is an explicit development check of crouch, loop and currently built maps.
# it skips the complete-registry gate and cannot be called a release check.
# use --source worktree only for labelled uncommitted diagnostics; default is committed HEAD.
# tools/check-r15.sh --out DIR [--source head|worktree] [--core-only] [--controls] [--route SPEC]...
set -euo pipefail
export GODOT="${GODOT:-$HOME/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64}"
cd "$(dirname "$0")/.."
project="$(pwd)"
out=""
source_mode=head
routes=()
core_only=false
controls=false
while (( $# )); do
	case "$1" in
		--out) out="$2"; shift 2 ;;
		--source) source_mode="$2"; shift 2 ;;
		--route) routes+=("$2"); shift 2 ;;
		--core-only) core_only=true; shift ;;
		--controls) controls=true; shift ;;
		*) echo "unknown argument $1" >&2; exit 2 ;;
	esac
done
out="${out:-$(mktemp -d /tmp/r15-check.XXXXXX)}"
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
		dirty="$(git status --porcelain --untracked-files=all -- . | awk 'NR<=20 {print}')"
		[[ -n "$dirty" ]] && label="$label; the working tree differs and is NOT what was checked" ;;
	worktree)
		# p / a labelled diagnostic: tracked and untracked, not ignored, files as they stand now.
		git ls-files -co --exclude-standard -z -- . | tar --null -T - -c | tar -x -C "$src"
		label="working tree at HEAD $(git rev-parse HEAD) with uncommitted changes: diagnostic, not a committed source" ;;
	*) echo "--source is head or worktree" >&2; exit 2 ;;
esac
echo "source: $label" | tee "$out/SOURCE.txt"
printf 'core_only=%s\ncontrols=%s\n' "$core_only" "$controls" > "$out/SCOPE.txt"
command -v "$GODOT" > "$out/ENGINE.txt"
sha256sum "$(command -v "$GODOT")" >> "$out/ENGINE.txt"
(cd "$src" && find . -type f ! -path './.godot/*' -print0 | sort -z | xargs -0 sha256sum) > "$out/source-sha256.txt"
results=()
failed=0
r15_child=""
r15_cancelled=0

cancel_source() {
	r15_cancelled=1
	if [[ -n "$r15_child" ]]; then kill -TERM "$r15_child" 2>/dev/null || true; fi
}

cleanup_source() {
	if [[ -n "$r15_child" ]]; then
		kill -TERM "$r15_child" 2>/dev/null || true
		wait "$r15_child" 2>/dev/null || true
	fi
	# import and profile caches belong to this frozen run, including interrupted imports.
	rm -rf "$out/profile/cache" "$src/.godot"
}
trap cancel_source INT TERM
trap cleanup_source EXIT

owned_run() {
	# the python owner forwards cancellation through supervisors and releases engine groups.
	local log="$1" budget="$2" status=0
	shift 2
	python3 -I "$src/tools/package-r15.py" engine --cwd "$src" --log "$log" --deadline "$budget" -- "$@" &
	r15_child=$!
	if (( r15_cancelled )); then kill -TERM "$r15_child" 2>/dev/null || true; fi
	while true; do
		wait "$r15_child" && status=0 || status=$?
		kill -0 "$r15_child" 2>/dev/null || break
	done
	r15_child=""
	if (( r15_cancelled )); then exit 130; fi
	return "$status"
}

clean_log() {
	[[ -s "$1" ]] && ! rg -q 'SCRIPT ERROR:|ERROR:|Parse Error:|Failed to load script' "$1"
}

run_clean() {
	# label, log name, engine args...: an exit status or any engine error fails the step.
	local label="$1" log="$out/$2.log" status=0
	shift 2
	owned_run "$log" 600 "$GODOT" "$@" || status=$?
	if (( status == 0 )) && clean_log "$log"; then
		results+=("PASS  $label ($(tail -n 1 "$log" | cut -c1-160))")
		return 0
	fi
	results+=("FAIL  $label (exit $status, $log)")
	return 1
}

# all suites use isolated profiles under the evidence path, never the player's own saves.
if "$core_only" && (( ${#routes[@]} )); then
    echo "--route requires the complete-registry source check; omit --core-only" >&2
    exit 2
fi

step() {
    if ! "$@"; then failed=1; fi
    return 0
}

startup() {
    run_clean "default R15 scene" startup --headless --audio-driver Dummy --path . -- --verify-startup || return 1
    if ! rg -q '^r15: build=spillway-2026\.11\.08-r15; map=breakwater; preset=server128; physics_hz=128; course_key=[0-9a-f]{16}; records=off; runner=res://scripts/r15_source_player\.gd; standin=false; renderer=gl_compatibility$' "$out/startup.log"; then
        results[-1]="FAIL  default R15 scene (missing actual Breakwater/F2/crouch-runner startup identity)"
        return 1
    fi
}

oracle() {
    if owned_run "$out/oracle-self-test.log" 60 python3 -I tests/r14_source_oracle.py --self-test \
        && owned_run "$out/oracle-predictions.json" 60 python3 -I tests/r14_source_oracle.py; then
        results+=("PASS  independent Source oracle and predictions")
        return 0
    fi
    results+=("FAIL  independent Source oracle")
    return 1
}

loop() {
    local status=0
    owned_run "$out/loop.log" 600 "$GODOT" --headless --audio-driver Dummy --fixed-fps 128 --path . --script res://tests/test_r15_loop.gd -- "--out=$out/loop" || status=$?
    # these five exact refusals belong to deliberate fixture negatives. no wildcard permits
    # production failures, missing assets or an arbitrary error with the same prefix.
    if python3 -I - "$out/loop.log" "$out/loop/summary.json" "$status" >"$out/loop-log-audit.json" <<'PYCODE'
import collections,json,re,sys
from pathlib import Path
text=Path(sys.argv[1]).read_text()
expected=[
    "ERROR: r15: cannot start: the R15 runner res://scripts/no_such_runner.gd is missing, so crouch cannot run. This build is incomplete; nothing falls back to another runner.",
    "ERROR: r15: map 'unbuilt-fixture' is not playable here; using the default",
    "ERROR: r15: unknown or unavailable preset 'csgo_vanilla'; using server128",
    "ERROR: r15: unknown or unavailable preset 'vanilla64'; using server128",
    "ERROR: r15: unknown or unavailable preset 'f1'; using server128",
]
actual=[line for line in text.splitlines() if re.search(r'SCRIPT ERROR:|ERROR:|Parse Error:|Failed to load script',line)]
summary=json.loads(Path(sys.argv[2]).read_text())
ok=(int(sys.argv[3])==0 and collections.Counter(actual)==collections.Counter(expected)
    and summary['failed']==0 and summary['checks']>0 and len(summary['results'])==summary['checks']
    and all(row['ok'] is True for row in summary['results']))
print(json.dumps({'ok':ok,'exit':int(sys.argv[3]),'checks':summary['checks'],'expected_refusals':expected,'actual_errors':actual},indent=2))
raise SystemExit(0 if ok else 1)
PYCODE
    then
        results+=("PASS  actual R15 loop and exactly five fixture refusal errors")
        return 0
    fi
    results+=("FAIL  actual R15 loop ($out/loop-log-audit.json)")
    return 1
}

crouch_tape() {
    if owned_run "$out/air-crouch.log" 120 python3 -I tools/momentum-tape.py run tests/momentum_tapes/r15-air-crouch.json --out "$out/air-crouch" --headless --archive --game-script res://scripts/r15_main.gd --game-class '' --motor server128 --warmup 8 --render-fps 128 \
        && clean_log "$out/air-crouch.log" && clean_log "$out/air-crouch/evaluator/godot.log" \
        && owned_run "$out/air-crouch-controls.log" 60 python3 -I tests/test_r15_tape_crouch.py --run "$out/air-crouch" --out "$out/air-crouch-controls.json"; then
        results+=("PASS  actual-main airborne crouch replay and corrupt-capture controls")
        return 0
    fi
    results+=("FAIL  airborne crouch replay or controls ($out/air-crouch-controls.log)")
    return 1
}

identity_routes() {
    local args=()
    for route in "${routes[@]}"; do args+=(--route "$route"); done
    if owned_run "$out/identity-routes.log" 1800 python3 -I tools/package-r15.py source --source "$src" --evidence "$out/identity-routes" "${args[@]}"; then
        results+=("PASS  complete eight-map registry, identities and supplied routes")
        return 0
    fi
    results+=("FAIL  complete registry and routes ($out/identity-routes.log)")
    return 1
}

run_clean "setup: import" import --headless --audio-driver Dummy --path . --import || { printf '%s\n' "${results[@]}"; exit 1; }
step startup
step oracle
step run_clean "Source pure law against independent oracle" math --headless --path . --script res://tests/test_r14_source_motion.gd -- "--out=$out/math" "--oracle=$out/oracle-predictions.json"
step run_clean "R15 real crouch and uncrouched parity" crouch --headless --audio-driver Dummy --fixed-fps 128 --path . --script res://tests/test_r15_crouch.gd -- "--out=$out/crouch"
step run_clean "independent crouch clearance and live-setting challenge" crouch-review --headless --audio-driver Dummy --fixed-fps 128 --path . --script res://tests/test_r15_crouch_review.gd -- "--out=$out/crouch-review"
step loop
step crouch_tape
step run_clean "actual external asset placements" assets --headless --audio-driver Dummy --path . --script res://tests/test_r15_assets.gd
if owned_run "$out/release-units.log" 90 python3 -I tests/test_r15_release.py --out "$out/release-units.json" && clean_log "$out/release-units.log"; then
    results+=("PASS  offline release-component controls")
else
    results+=("FAIL  offline release-component controls")
    failed=1
fi

step run_clean "retained Penstock geometry" penstock --headless --audio-driver Dummy --path . --script res://tests/test_r14_practice_level.gd -- "--out=$out/penstock"
step run_clean "retained Overflow geometry" overflow --headless --audio-driver Dummy --path . --script res://tests/test_momentum_overflow.gd -- "--out=$out/overflow"

# the per-map suites validate authored geometry, not routes or human enjoyment. absent
# suites fail the full check; a core-only result reports them as pending explicitly.
for map in breakwater whiteout sunken rainline nightshift experiment; do
    test_script="tests/test_r15_${map}.gd"
    if [[ -f "$src/$test_script" ]]; then
        step run_clean "map geometry: $map" "map-$map" --headless --audio-driver Dummy --fixed-fps 128 --path . --script "res://$test_script" -- "--out=$out/map-$map"
    elif "$core_only"; then
        results+=("PENDING  $map map suite (development-only result)")
    else
        results+=("FAIL  required map suite is absent: $test_script")
        failed=1
    fi
done
if "$core_only"; then
    results+=("SKIP  complete registry and packed play; core-only development scope")
else
    step identity_routes
fi
if "$controls"; then
    step run_clean "unchanged R13 control air motor" r13-air --headless --audio-driver Dummy --fixed-fps 120 --path . --script res://tests/test_carry_air_candidate.gd -- "--out=$out/r13-air"
    step run_clean "unchanged R13 control lifecycle" r13-loop --headless --audio-driver Dummy --fixed-fps 120 --path . --script res://tests/test_momentum_overflow_loop.gd -- "--out=$out/r13-loop"
fi
# only owned import/profile caches are disposable. the source hash list remains the receipt.
rm -rf "$out/profile/cache" "$src/.godot"
find "$out" -name '*.jsonl' -exec gzip -9 {} \;
printf '%s\n' "${results[@]}" | tee "$out/RESULTS.txt"
echo "evidence: $out"
if (( failed )); then echo "R15 source checks failed"; exit 1; fi
if "$core_only"; then
    echo "R15 core checks passed; incomplete-map development result, not release acceptance"
else
    echo "R15 source gates passed; packed play remains separate"
fi
