"""Use shot.main's full capture wrapper with a static review-screen test harness."""
import argparse
import json
from pathlib import Path
import sys
import subprocess

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import engine


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--matrix", action="store_true", help="capture analysis, both targets, unavailable-map and incomplete states")
    args = parser.parse_args()
    import shot
    if args.matrix and subprocess.check_output(["git", "status", "--porcelain"], cwd=engine.PROJECT).strip():
        raise RuntimeError("Matrix captures require a clean source commit")
    out = shot.external(args.out)
    out.mkdir(parents=True, exist_ok=False)
    poses = out / "static-ui.json"
    poses.write_text('[{"position":[0,0,0]}]\n')
    # retain shot.main's pin, snapshot, lock, display, receipts and cleanup unchanged.
    shot.HARNESS = (engine.PROJECT / "tests/run_review_capture.gd").read_text()
    variants = [("matrix-1280", "1280x720", False), ("matrix-960", "960x640", False)] if args.matrix else [
        ("splits-1280", "1280x720", False), ("splits-960", "960x640", False), ("follow-1280", "1280x720", True)]
    for name, size, follow in variants:
        sys.argv = ["shot.py", "--checkout", str(engine.PROJECT), "--map", "breakwater",
                    "--poses", str(poses), "--size", size, "--seconds", ".1", "--every", ".1",
                    "--setting", "run_review_follow=" + json.dumps(follow),
                    "--setting", "run_review_matrix=" + json.dumps(args.matrix),
                    "--out", str(out / name)]
        shot.main()
        receipt = out / name / "capture.json"
        data = json.loads(receipt.read_text())
        data["evidence"] = "static run-review UI; not traversal evidence"
        receipt.write_text(json.dumps(data, indent=2) + "\n")
        print("capture complete: " + name, flush=True)


if __name__ == "__main__":
    main()
