#!/usr/bin/env bash
# spillway acceptance is separate from the historical reconstruction suites.
set -euo pipefail
GODOT="${GODOT:-$HOME/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64}"
cd "$(dirname "$0")/.."
# --play-routes also runs the authored safe, fast and recovery lines with error scanning.
play_routes=false
suite_args=()
for arg in "$@"; do
	if [[ "$arg" == --play-routes ]]; then play_routes=true; else suite_args+=("$arg"); fi
done
output_file=$(mktemp /tmp/spillway-check.XXXXXX)
trap 'rm -f "$output_file"' EXIT
run_clean() {
	local status=0
	"$GODOT" "$@" >"$output_file" 2>&1 || status=$?
	cat "$output_file"
	if (( status != 0 )); then return "$status"; fi
	if rg -q 'SCRIPT ERROR:|(^|[[:space:]])ERROR:|Parse Error:|Failed to load script' "$output_file"; then
		return 1
	fi
}
run_clean --headless --path . --import
run_clean --headless --path . --check-only --script res://scripts/spillway_driver.gd
run_clean --headless --fixed-fps 120 --path . --script res://tests/test_spillway.gd -- "${suite_args[@]}"
run_clean --headless --fixed-fps 120 --path . --script res://tests/test_spillway_flow.gd
if "$play_routes"; then
	for route in safe fast recovery; do
		run_clean --headless --fixed-fps 120 --path . -- --bot --bot-quit "--route=$route" "${suite_args[@]}"
	done
fi
