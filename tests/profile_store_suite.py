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
    parser.add_argument("--only", choices=("failures", "legacy", "recovery", "replace", "unreadable"), help="run one focused case")
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
                if args.only and args.only != name:
                    continue
                extra = ["--", primary] if name == "replace" else []
                if name == "failures":
                    extra = ["--", "--r16-profile=" + str(out / "probe-seed.cfg"), "--no-run-recordings",
                             "--r22-package-check=" + str(out / "probe-seed.json")]
                result = engine.run(["--headless", "--audio-driver", "Dummy", "--path", source, "--script", "res://tests/profile_store_" + name + ".gd", *extra], cwd=source, profile=profile / name, log=out / (name + ".log"))
                results.append({"name": name, **result})
        finally:
            denied.chmod(0o755)
        if args.only in (None, "unreadable"):
            protected = out / "unreadable.cfg"
            backup = out / "unreadable.cfg.bak"
            original = b'[other-one]\nclean_best_ticks=1234\n[other-two]\nclean_best_ticks=5678\n'
            previous = b'[other-one]\nclean_best_ticks=2000\n[other-two]\nclean_best_ticks=6000\n'
            protected.write_bytes(original)
            backup.write_bytes(previous)
            protected.chmod(0)
            try:
                result = engine.run(["--headless", "--path", source, "--script", "res://tests/profile_store_unreadable.gd", "--", protected], cwd=source, profile=profile / "unreadable", log=out / "unreadable.log")
            finally:
                protected.chmod(0o600)
            if protected.read_bytes() != original or backup.read_bytes() != previous:
                raise RuntimeError("Unreadable profile or its backup lost bytes")
            results.append({"name": "unreadable", "primary_bytes_preserved": True, "backup_bytes_preserved": True, **result})
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
