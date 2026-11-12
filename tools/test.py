#!/usr/bin/env python3
"""Run current component checks, with optional complete original-map parity."""
import argparse
import importlib.util
import json
from pathlib import Path
import sys
import tempfile

sys.dont_write_bytecode = True
import engine

spec = importlib.util.spec_from_file_location("spillway_verification", engine.PROJECT / "verification/parity.py")
verification = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verification)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--slow", action="store_true", help="also run all 48 original-map plays and 288 exact comparisons")
    parser.add_argument("--out", type=Path, help="new external directory for logs and replay data")
    args = parser.parse_args()
    out = args.out.resolve() if args.out else Path(tempfile.mkdtemp(prefix="spillway-check-"))
    if args.out:
        out.mkdir(parents=True, exist_ok=False)
    engine.check_pin()
    routes, contract = verification.fixtures()
    pure = verification.audit.negative_seed(verification.FIXTURES / routes[0]["name"] / "old", out / "negative-controls", contract, "old")
    print(f"recording/metadata/coverage mutations rejected: {len(pure['checks'])}", flush=True)
    source = out / "source"
    verification.snapshot(source)
    profile = out / "profile"
    profile.mkdir()
    engine.run(["--headless", "--editor", "--path", source, "--import"], cwd=source,
               profile=profile, log=out / "import.log")
    components = ["r21_surf_integration", "r21_tether_geometry", "r21_tether_component"]
    if args.slow:
        components.extend(["r20_style_stack", "r20_through_ordinary"])
    report = {"ok": False, "mutations": pure, "components": []}
    try:
        for name in components:
            folder = out / name
            folder.mkdir()
            print("check " + name, flush=True)
            result = engine.run(["--headless", "--audio-driver", "Dummy", "--path", source,
                                 "--fixed-fps", "128", "--script", "res://tests/" + name + ".gd",
                                 "--", "--out=" + str(folder)], cwd=source, profile=profile,
                                log=folder / "engine.log", timeout=300)
            report["components"].append({"name": name, **result})
        if args.slow:
            report["parity"] = verification.run(out / "parity")
        report["ok"] = True
        print("PASS; results: " + str(out / "RESULT.json"), flush=True)
    finally:
        (out / "RESULT.json").write_text(json.dumps(report, indent=1) + "\n")


if __name__ == "__main__":
    main()
