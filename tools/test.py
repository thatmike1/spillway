#!/usr/bin/env python3
"""Run current component checks, with optional complete original-map parity."""
import argparse
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import subprocess

sys.dont_write_bytecode = True
import engine

spec = importlib.util.spec_from_file_location("spillway_verification", engine.PROJECT / "verification/parity.py")
verification = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = verification
spec.loader.exec_module(verification)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--slow", action="store_true", help="also run all 48 original-map plays and 288 exact comparisons")
    parser.add_argument("--out", type=Path, help="new external directory for logs and replay data")
    args = parser.parse_args()
    out = args.out.resolve() if args.out else Path(tempfile.mkdtemp(prefix="spillway-check-"))
    if args.out:
        out.mkdir(parents=True, exist_ok=False)
    if engine.temporary_headroom() < 1_200_000_000:
        raise RuntimeError("Need 1.2 GB temporary/quota headroom.")
    engine.check_pin()
    subprocess.run([sys.executable, "-B", str(engine.PROJECT/"tests/movement_oracle.py"), "--self-test"], check=True)
    subprocess.run([sys.executable, "-B", str(engine.PROJECT/"tests/test_engine_lock.py")], check=True)
    subprocess.run([sys.executable, "-B", str(engine.PROJECT/"tests/test_run_bundle.py")], check=True)
    subprocess.run([sys.executable, "-B", str(engine.PROJECT/"tests/test_shortcut.py")], check=True)
    subprocess.run([sys.executable, "-B", str(engine.PROJECT/"tests/test_shot.py")], check=True)
    subprocess.run([sys.executable, "-B", str(engine.PROJECT/"tests/test_check_package.py")], check=True)
    routes, contract = verification.fixtures()
    pure = verification.audit.negative_seed(verification.FIXTURES / routes[0]["name"] / "old", out / "negative-controls", contract, "old")
    print(f"recording/metadata/coverage mutations rejected: {len(pure['checks'])}", flush=True)
    source = out / "source"
    verification.snapshot(source)
    profile = out / "profile"
    profile.mkdir()
    engine.run(["--headless", "--editor", "--path", source, "--import"], cwd=source,
               profile=profile, log=out / "import.log")
    components = ["saltglass_registration", "tether_geometry", "tether_coefficients", "grapple_capability", "r22_registration", "host_capabilities", "tether_feedback_identity", "tether_feedback_audio", "registry_injection"]
    if args.slow:
        components.extend(["direction_stack", "through_line_original_maps"])
    report = {"ok": False, "mutations": pure, "components": []}
    try:
        with engine.locked():
            for name in components:
                folder = out / name
                folder.mkdir()
                print("check " + name, flush=True)
                result = engine.run(["--headless", "--audio-driver", "Dummy", "--path", source,
                                     "--fixed-fps", "128", "--script", "res://tests/" + name + ".gd",
                                     "--", "--out=" + str(folder), "--menu-contract=" + str(verification.FIXTURES / "contract.json")], cwd=source, profile=profile,
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
