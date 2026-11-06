#!/usr/bin/env bash
# preflight from an isolated directory, without source-tree resource fallback.
set -euo pipefail
pack_path="${1:?pass an absolute exported PCK path}"
[[ "$pack_path" == /* && -f "$pack_path" ]]
pack_project="$(cd "$(dirname "$0")/.." && pwd)"
pack_engine="${GODOT:-$HOME/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64}"
pack_fixture="$(mktemp -d /tmp/spillway-pack-check.XXXXXX)"
trap 'rm -f "$pack_fixture/engine.log"; rmdir "$pack_fixture"' EXIT
cd "$pack_fixture"
pack_status=0
"$pack_engine" --headless --main-pack "$pack_path" --script "$pack_project/tools/check-pack.gd" > engine.log 2>&1 || pack_status=$?
cat engine.log
if (( pack_status != 0 )); then exit "$pack_status"; fi
if rg -q 'SCRIPT ERROR:|(^|[[:space:]])ERROR:|Parse Error:' engine.log; then exit 1; fi
