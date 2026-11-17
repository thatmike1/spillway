"""Run review checks with the pinned engine, shared lock and isolated user data."""
import argparse
import json
from pathlib import Path
import sys
import tempfile

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import engine


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path)
    parser.add_argument("--checks", nargs="+", choices=["model", "screen", "3d", "performance", "practice"],
                        default=["model", "screen", "3d", "performance", "practice"])
    args = parser.parse_args()
    out = args.out.resolve() if args.out else Path(tempfile.mkdtemp(prefix="r22-run-review-"))
    out.mkdir(parents=True, exist_ok=True)
    fixtures = engine.PROJECT / "tests/fixtures/original-map-parity/breakwater-basic/old/runs"
    before = {p.name: engine.sha(p) for p in fixtures.iterdir() if p.is_file()}
    checks = []
    for name in args.checks:
        result = engine.run(["--headless", "--audio-driver", "Dummy", "--path", engine.PROJECT,
                             "--script", "res://tests/run_review_" + name + ".gd"],
                            cwd=engine.PROJECT, profile=out / "profile", log=out / (name + ".log"))
        checks.append({"name": name, **result})
    after = {p.name: engine.sha(p) for p in fixtures.iterdir() if p.is_file()}
    if before != after:
        raise RuntimeError("Review changed the recordings folder")
    report = {"ok": True, "checks": checks, "recording_files_unchanged": len(before)}
    (out / "RESULT.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report))


if __name__ == "__main__":
    main()
