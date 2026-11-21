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
    source_files = verification.snapshot(source)
    profile = out / "profile"
    profile.mkdir()
    engine.run(["--headless", "--editor", "--path", source, "--import"], cwd=source,
               profile=profile, log=out / "import.log")
    components = [
        "saltglass_registration", "tether_geometry", "tether_coefficients",
        "grapple_capability", "r22_registration", "host_capabilities", "profile_store_failures", "teaching_cap", "plan_contract", "plan_pause", "plan_review_guard",
        "tether_feedback_identity", "tether_feedback_audio", "registry_injection",
        "style_suspension", "tether_feedback_lens", "saltglass_art", "seaward_registration", "gantry_runner", "gantry_rope", "gantry_chain", "gantry_coast",
        "mail_flight", "mail_motor", "mail_courts", "mail_tape", "sluice_six_style", "outer_reach_tape",
        "viaduct_presentation", "foundry_routes", "foundry_fork", "foundry_scenery", "foundry_cable", "foundry_advanced",
        "scripts/ui/pause_menu_checks.gd", "scripts/ui/hud_hooks_checks.gd", "scripts/ui/review_menu_checks.gd", "scripts/ui/planner_menu_checks.gd",
        "scripts/fx/motion_fx_checks.gd",
    ]
    if args.slow:
        components.extend(["direction_stack", "through_line_original_maps"])
    report = {"ok": False, "mutations": pure, "source": source_files, "components": []}
    try:
        with engine.locked():
            for name in components:
                folder = out / Path(name).stem
                folder.mkdir()
                print("check " + name, flush=True)
                script = "res://" + name if "/" in name else "res://tests/" + name + ".gd"
                extra = []
                if name == "profile_store_failures":
                    extra = ["--r16-profile=" + str(folder / "probe-seed.cfg"), "--no-run-recordings",
                             "--r22-package-check=" + str(folder / "probe-seed.json")]
                result = engine.run(["--headless", "--audio-driver", "Dummy", "--path", source,
                                     "--fixed-fps", "128", "--script", script,
                                     "--", "--out=" + str(folder), "--menu-contract=" + str(verification.FIXTURES / "contract.json"), *extra], cwd=source, profile=profile,
                                    log=folder / "engine.log", timeout=300)
                report["components"].append({"name": name, **result})
        (out / "COMPONENTS.json").write_text(json.dumps({**report, "ok": True}, indent=1) + "\n")
        if args.slow:
            # one lease for the whole matrix: per-play leases let every queued check cut in between plays.
            with engine.locked():
                report["parity"] = verification.run(out / "parity")
            runtime_roots = {"scripts", "assets", "scenes", "shaders", "data"}
            def runtime_files(files):
                return {name: digest for name, digest in files.items()
                        if Path(name).parts[0] in runtime_roots
                        or name in {"project.godot", "export_presets.cfg"}}
            if runtime_files(source_files) != runtime_files(report["parity"]["source"]):
                raise RuntimeError("Component and parity snapshots used different authored runtime bytes.")
        report["ok"] = True
        print("PASS; results: " + str(out / "RESULT.json"), flush=True)
    finally:
        (out / "RESULT.json").write_text(json.dumps(report, indent=1) + "\n")


if __name__ == "__main__":
    main()
