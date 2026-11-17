#!/usr/bin/env python3
"""Check Plan Yard contracts and real-input tapes through the pinned engine wrapper."""
import argparse
import importlib.util
from pathlib import Path
import shutil
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import engine


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--only-west", action="store_true")
    args = parser.parse_args()
    out = args.out.resolve()
    if out == ROOT or ROOT in out.parents:
        raise ValueError("evidence belongs outside the repository")
    out.mkdir(parents=True, exist_ok=False)
    spec = importlib.util.spec_from_file_location("plan_snapshot", ROOT / "verification/parity.py")
    verifier = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(verifier)
    source = out / "source"
    verifier.snapshot(source)
    profile = out / "profile"
    try:
        engine.run(["--headless", "--editor", "--path", source, "--import"], cwd=source,
                   profile=profile, log=out / "import.log")
        for name in ("plan_contract", "plan_routes"):
            engine.run(["--headless", "--audio-driver", "Dummy", "--path", source,
                        "--fixed-fps", "128", "--script", "res://tests/" + name + ".gd",
                        "--", "--out=" + str(out), *(["--only-west"] if args.only_west else [])],
                       cwd=source, profile=profile, log=out / (name + ".log"))
    finally:
        shutil.rmtree(source)
        shutil.rmtree(profile, ignore_errors=True)


if __name__ == "__main__":
    main()
