#!/usr/bin/env python3
"""run the profile regressions with a private profile and the shared pinned engine lock."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import engine
sys.path.insert(0, str(engine.PROJECT / "verification"))
import parity


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True, help="new external evidence directory")
    parser.add_argument("--probe", action="store_true", help="also exercise the source-side package probe twice")
    args = parser.parse_args()
    out = args.out.resolve()
    if out.is_relative_to(engine.PROJECT):
        raise ValueError("Use an external output directory")
    out.mkdir(parents=True, exist_ok=False)
    engine.check_pin()
    source = out / "source"
    parity.snapshot(source)
    profile = out / "private"
    results = []
    try:
        engine.run(["--headless", "--editor", "--path", source, "--import"], cwd=source, profile=profile, log=out / "import.log")
        denied = out / "denied"
        denied.mkdir()
        primary = denied / "profile.cfg"
        primary.write_text('[other-map]\nclean_best_ticks=1234567890123\n')
        (denied / "profile.cfg.tmp").touch()
        denied.chmod(0o555)
        try:
            for name in ("failures", "legacy", "recovery", "replace"):
                extra = ["--", primary] if name == "replace" else []
                result = engine.run(["--headless", "--audio-driver", "Dummy", "--path", source, "--script", "res://tests/profile_store_" + name + ".gd", *extra], cwd=source, profile=profile / name, log=out / (name + ".log"))
                results.append({"name": name, **result})
        finally:
            denied.chmod(0o755)
        if args.probe:
            for phase in ("first", "reload"):
                arguments = ["--headless", "--audio-driver", "Dummy", "--path", source, "--script", "res://tests/profile_store_package_probe.gd", "--", "--r16-profile=" + str(out / "spillway_r16.cfg"), "--no-run-recordings", "--r22-package-check=" + str(out / (phase + ".json"))]
                if phase == "reload":
                    arguments.append("--package-reload")
                result = engine.run(arguments, cwd=source, profile=profile / "probe", log=out / ("probe-" + phase + ".log"))
                receipt = json.loads((out / (phase + ".json")).read_text())
                if not receipt.get("ok"):
                    raise RuntimeError("Probe failed: " + str(receipt))
                results.append({"name": "probe-" + phase, **result, **receipt})
        (out / "RESULT.json").write_text(json.dumps({"ok": True, "checks": results}, indent=2) + "\n")
        print("PASS " + str(out / "RESULT.json"))
    finally:
        shutil.rmtree(source, ignore_errors=True)
        shutil.rmtree(profile, ignore_errors=True)


if __name__ == "__main__":
    main()
