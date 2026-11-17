"""check that an earned finish also coasts onto a stable receiving court."""
import argparse
import json
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("capture", type=Path)
parser.add_argument("--out", type=Path, required=True)
args = parser.parse_args()
rows = [json.loads(line) for line in (args.capture / "frames.jsonl").read_text().splitlines()]
after = [row for row in rows if row["finished"]]
failures = []
if len(after) < 2:
    failures.append("need at least two post-finish observations")
for row in rows:
    if row["respawns"] != 0:
        failures.append(f"frame {row['frame']}: respawn")
for row in after:
    if row["position"][1] < 3.8:
        failures.append(f"frame {row['frame']}: finished runner fell below court: {row['position']}")
result = {"ok": not failures, "capture": str(args.capture), "frames": len(rows),
          "post_finish_frames": len(after), "lowest_post_finish_feet_m": min((r["position"][1] for r in after), default=None),
          "failures": failures, "scope": "earned finish and post-finish support; a zero respawn counter alone does not prove no finish rescue"}
args.out.parent.mkdir(parents=True, exist_ok=True)
args.out.write_text(json.dumps(result, indent=2) + "\n")
print(json.dumps(result))
raise SystemExit(0 if result["ok"] else 1)
