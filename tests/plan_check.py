#!/usr/bin/env python3
"""Check Plan Yard contracts and real-input tapes through the pinned engine wrapper."""
import argparse
import importlib.util
import json
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
    parser.add_argument("--safe", action="store_true", help="check the safe-quay baseline")
    parser.add_argument("--trial", type=int, choices=range(3))
    parser.add_argument("--delay", type=float, default=0.0)
    parser.add_argument("--aim-ceiling", type=float, default=90.0)
    args = parser.parse_args()
    out = args.out.resolve()
    if any((parent / ".git").exists() for parent in (out, *out.parents)):
        raise ValueError("evidence belongs outside the repository")
    if not 0 <= args.delay <= 0.5:
        raise ValueError("release delay must be between zero and half a second")
    if engine.temporary_headroom() < 1_200_000_000:
        raise RuntimeError("need 1.2 GB temporary headroom")
    engine.check_pin()
    if not 0 < args.aim_ceiling <= 90:
        raise ValueError("aim ceiling must be above zero and at most 90 degrees")
    out.mkdir(parents=True, exist_ok=False)
    spec = importlib.util.spec_from_file_location("plan_snapshot", ROOT / "verification/parity.py")
    verifier = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(verifier)
    source = out / "source"
    profile = out / "profile"
    report = {"ok": False, "checks": []}
    try:
        hashes = verifier.snapshot(source)
        own_hashes = {name: digest for name, digest in hashes.items()
                      if name.startswith(("scripts/plan/", "scripts/maps/plan_yard", "scripts/movement/plan_runner", "tests/plan_"))}
        (out / "source-sha256.json").write_text(json.dumps(own_hashes, indent=2) + "\n")
        imported = engine.run(["--headless", "--editor", "--path", source, "--import"], cwd=source,
                   profile=profile, log=out / "import.log")
        report["checks"].append({"name": "import", **imported})
        route_args = (["--only-west"] if args.only_west or args.safe else [])
        route_args += ([] if args.safe else ["--arc"])
        route_args += ["--delay=" + str(args.delay), "--aim-ceiling=" + str(args.aim_ceiling)]
        if args.trial is not None:
            route_args += ["--trial=" + str(args.trial)]
        for name in ("plan_contract", "plan_routes"):
            result = engine.run(["--headless", "--audio-driver", "Dummy", "--path", source,
                        "--fixed-fps", "128", "--script", "res://tests/" + name + ".gd",
                        "--", "--out=" + str(out), *(route_args if name == "plan_routes" else [])],
                       cwd=source, profile=profile, log=out / (name + ".log"))
            report["checks"].append({"name": name, **result})
        report["ok"] = True
    except Exception as error:
        report["error"] = str(error)
        raise
    finally:
        (out / "RESULT.json").write_text(json.dumps(report, indent=2) + "\n")
        shutil.rmtree(source, ignore_errors=True)
        shutil.rmtree(profile, ignore_errors=True)


if __name__ == "__main__":
    main()
