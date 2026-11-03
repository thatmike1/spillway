#!/usr/bin/env bash
# headless import plus every test suite; exits non-zero on the first failure
set -euo pipefail
GODOT="${GODOT:-$HOME/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64}"
cd "$(dirname "$0")/.."
"$GODOT" --headless --path . --import >/dev/null 2>&1
for suite in test_player test_integration test_traversal; do
	# --fixed-fps runs physics as fast as the CPU allows instead of in real time
	output=$("$GODOT" --headless --fixed-fps 120 --path . --script "res://tests/$suite.gd" 2>&1) || { echo "$output"; echo "$suite failed"; exit 1; }
	echo "$output" | grep -E "checks passed|traversal:|route \(" || true
done
