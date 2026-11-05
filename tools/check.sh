#!/usr/bin/env bash
# headless import plus every physics/flow suite; interface rendering is separate
set -euo pipefail
GODOT="${GODOT:-$HOME/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64}"
cd "$(dirname "$0")/.."
trace_dir=$(mktemp -d /tmp/foldrunner-traces.XXXXXX)
trap 'rm -rf "$trace_dir"' EXIT
output=$("$GODOT" --headless --path . --import 2>&1) || { echo "$output"; exit 1; }
if [[ "$output" =~ SCRIPT\ ERROR:|ERROR: ]]; then echo "$output"; exit 1; fi
for suite in test_spec_ground test_spec_moves test_spec_camera test_runner_vision test_player test_integration test_traversal; do
	output=$("$GODOT" --headless --fixed-fps 120 --path . --script "res://tests/$suite.gd" -- --traces="$trace_dir" 2>&1) || { echo "$output"; echo "$suite failed"; exit 1; }
	if [[ "$output" =~ SCRIPT\ ERROR:|ERROR: ]]; then echo "$output"; exit 1; fi
	echo "$output" | grep -E "checks passed|traversal:|route \(" || true
done
