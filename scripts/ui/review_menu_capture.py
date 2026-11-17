"""Capture the actual menu practice callback through the approved shot wrapper."""
from pathlib import Path
import argparse
import json
import sys
sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
import engine
import shot

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--out", type=Path, required=True)
args = parser.parse_args()
out = shot.external(args.out)
pose = out.parent / (out.name + "-placeholder-pose.json")
pose.parent.mkdir(parents=True, exist_ok=True)
pose.write_text('[{"position":[0,0,0]}]\n')
# preserve shot.main's pin, snapshot, locks, display, receipts and cleanup.
shot.HARNESS = (engine.PROJECT / "scripts/ui/review_menu_capture.gd").read_text().replace(
    "res://tests/fixtures/", str(engine.PROJECT / "tests/fixtures") + "/")
sys.argv = ["shot.py", "--checkout", str(engine.PROJECT), "--map", "breakwater",
            "--poses", str(pose), "--size", "1280x720", "--seconds", ".1",
            "--every", ".1", "--out", str(out)]
try:
    shot.main()
    data = json.loads((out / "capture.json").read_text())
    data["evidence"] = "native mouse activation of populated run-review practice; sealed fixture setup, not traversal"
    (out / "capture.json").write_text(json.dumps(data, indent=2) + "\n")
finally:
    pose.unlink(missing_ok=True)
