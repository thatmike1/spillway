#!/usr/bin/env bash
# imports once if needed, then starts the game
set -euo pipefail
GODOT="${GODOT:-$HOME/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64}"
cd "$(dirname "$0")/.."
[ -d .godot ] || "$GODOT" --headless --path . --import >/dev/null 2>&1
exec "$GODOT" --path . "$@"
