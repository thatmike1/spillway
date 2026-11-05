#!/usr/bin/env bash
# native decision views from a frozen pack, with isolated records and real input pauses.
set -euo pipefail
play_pack="${1:?pass an absolute frozen PCK path}"
play_inbox="${2:?pass a fresh absolute evidence directory}"
play_project="$(cd "$(dirname "$0")/.." && pwd)"
play_engine="${GODOT:-$HOME/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64}"
[[ "$play_pack" == /* && -f "$play_pack" && "$play_inbox" == /* ]]
[[ ! -e "$play_inbox/input-and-state.jsonl" ]]
mkdir -p "$play_inbox/profile"
export XDG_DATA_HOME="$play_inbox/profile"
exec xvfb-run -a -s '-screen 0 1280x720x24' "$play_engine" --main-pack "$play_pack" --windowed --resolution 1280x720 --audio-driver Dummy --rendering-driver opengl3 --fixed-fps 30 --script "$play_project/tools/visual-play.gd" -- "--inbox=$play_inbox"
