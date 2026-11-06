#!/usr/bin/env bash
# p / actual-course water retention, separate from full-route completion.
set -euo pipefail
project_root=$(cd -- "$(dirname -- "$0")/.." && pwd)
godot_bin="${GODOT:-$HOME/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64}"
proof_dir=""
pack=""
for arg in "$@"; do
	case "$arg" in
		--evidence-dir=*) proof_dir=${arg#*=} ;;
		--main-pack=*) pack=${arg#*=} ;;
		*) printf 'unknown argument: %s\n' "$arg" >&2; exit 2 ;;
	esac
done
if [[ -z "$proof_dir" ]]; then proof_dir=$(mktemp -d /tmp/spillway-wet-proof.XXXXXX); fi
repo_root=$(git -C "$project_root" rev-parse --show-toplevel)
python3 - "$proof_dir" "$repo_root" <<'PY'
from pathlib import Path
import sys
proof, repo = map(Path, sys.argv[1:])
if not proof.is_absolute() or proof.resolve().is_relative_to(repo.resolve()):
    raise SystemExit('evidence must be an absolute directory outside Git')
PY
mkdir -p -- "$proof_dir"
context=(--path "$project_root")
if [[ -n "$pack" ]]; then context=(--main-pack "$pack"); fi
# packed checks run from the external evidence directory, without loose project files.
cd -- "$proof_dir"
for kind in wet dry; do
	dry=0
	if [[ "$kind" == dry ]]; then dry=1; fi
	mkdir -p -- "$proof_dir/$kind"
	WET_PROBE_DIR="$proof_dir/$kind" WET_PROBE_DRY="$dry" WET_PROBE_VERSION="${pack:-source}" \
		timeout 45 "$godot_bin" --headless --fixed-fps 120 "${context[@]}" \
		--script "$project_root/tests/test_spillway_wet_chute.gd" > "$proof_dir/$kind/run.log" 2>&1
	if rg -q 'SCRIPT ERROR:|(^|[[:space:]])ERROR:|Parse Error:' "$proof_dir/$kind/run.log"; then
		cat "$proof_dir/$kind/run.log"
		exit 1
	fi
done
python3 - "$proof_dir" <<'PY'
import json
from pathlib import Path
import sys
root = Path(sys.argv[1])
wet, dry = [json.loads((root/k/'summary.json').read_text()) for k in ['wet','dry']]
ratio = wet['end_speed'] / max(dry['end_speed'], .001)
result = {'wet_mps':wet['end_speed'],'dry_mps':dry['end_speed'],'ratio':ratio,
          'wet_mode':wet['end_mode'],'water_ticks':wet['water_ticks'],
          'passed':ratio >= .8 and wet['end_mode']=='slide' and wet['water_ticks']>60}
(root/'comparison.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result))
print('evidence:', root)
raise SystemExit(0 if result['passed'] else 1)
PY
