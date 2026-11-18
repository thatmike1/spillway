#!/usr/bin/env python3
"""check Plan Yard contracts and real-input tapes through the pinned engine wrapper."""
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
    parser.add_argument("--persistence", action="store_true")
    parser.add_argument("--envelope", action="store_true", help="check the opt-in one-handoff practice prototype after normal routes")
    parser.add_argument("--pause-only", action="store_true", help="only check pause routing, without placement/route proof")
    parser.add_argument("--safe", action="store_true", help="check the safe-quay baseline")
    parser.add_argument("--trial", type=int, choices=range(3))
    parser.add_argument("--loadout", choices=["anchors", "one", "block", "pad", "pieces"], default="anchors")
    parser.add_argument("--delay", type=float, default=0.0)
    parser.add_argument("--aim-ceiling", type=float, default=90.0)
    args = parser.parse_args()
    out = args.out.resolve()
    if any((parent / ".git").exists() for parent in (out, *out.parents)):
        raise ValueError("evidence belongs outside Git")
    if not 0 <= args.delay <= 0.5 or not 0 < args.aim_ceiling <= 90:
        raise ValueError("invalid release delay or aim ceiling")
    if args.persistence and (args.loadout != "anchors" or args.trial not in (None,0) or args.safe):
        parser.error("--persistence needs the normal west tape")
    if args.envelope and (args.loadout != "anchors" or args.trial is not None or args.only_west or args.safe or args.pause_only):
        parser.error("--envelope needs all three normal anchor tapes")
    if args.safe and args.loadout != "anchors":
        parser.error("--safe is only the anchor baseline")
    if engine.temporary_headroom() < 1_200_000_000:
        raise RuntimeError("need 1.2 GB temporary headroom")
    engine.check_pin()
    out.mkdir(parents=True, exist_ok=False)
    spec = importlib.util.spec_from_file_location("plan_snapshot", ROOT / "verification/parity.py")
    verifier = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(verifier)
    source = out / "source"
    profile = out / "profile"
    report = {"ok": False, "checks": []}
    failures = []
    try:
        hashes = verifier.snapshot(source)
        own_hashes = {name: digest for name, digest in hashes.items()
                      if name.startswith(("scripts/plan/", "scripts/maps/plan_yard", "scripts/movement/plan_runner", "scripts/art/plan_", "tests/plan_"))}
        (out / "source-sha256.json").write_text(json.dumps(own_hashes, indent=2) + "\n")
        with engine.locked():
            imported = engine.run(["--headless", "--editor", "--path", source, "--import"],
                                  cwd=source, profile=profile, log=out / "import.log")
            report["checks"].append({"name": "import", **imported})
            for name in (["plan_pause"] if args.pause_only else ["plan_contract", "plan_pause"]):
                checked = engine.run(["--headless", "--audio-driver", "Dummy", "--path", source,
                                      "--fixed-fps", "128", "--script", "res://tests/" + name + ".gd",
                                      "--", "--out=" + str(out / name)],
                                     cwd=source, profile=profile, log=out / (name + ".log"))
                report["checks"].append({"name": name, **checked})
            if args.pause_only:
                report["ok"] = True
                print("PASS pause routing: " + str(out / "RESULT.json"))
                return
            cases = ["one", "block", "pad"] if args.loadout == "pieces" else [args.loadout]
            for case in cases:
                folder = out / case if args.loadout == "pieces" else out
                folder.mkdir(exist_ok=True)
                route_args = ["--loadout=" + case, "--delay=" + str(args.delay),
                              "--aim-ceiling=" + str(args.aim_ceiling)]
                route_args += ["--only-west"] if args.only_west or args.safe else []
                route_args += [] if args.safe else ["--arc"]
                if args.trial is not None:
                    route_args += ["--trial=" + str(args.trial)]
                elif case != "anchors":
                    route_args += ["--trial=0"]
                try:
                    result = engine.run(["--headless", "--audio-driver", "Dummy", "--path", source,
                                         "--fixed-fps", "128", "--script", "res://tests/plan_routes.gd",
                                         "--", "--out=" + str(folder), *route_args],
                                        cwd=source, profile=profile, log=folder / "plan_routes.log")
                    report["checks"].append({"name": case, "ok": True, **result})
                except Exception as error:
                    failures.append(case)
                    report["checks"].append({"name": case, "ok": False, "error": str(error)})
            if args.persistence and not failures:
                persisted = out / "persistence"
                persisted.mkdir()
                shutil.copy2(out / "west-tape.json", persisted / "tape.json")
                for mode in ("write", "readback"):
                    result = engine.run(["--headless", "--audio-driver", "Dummy", "--path", source,
                                         "--fixed-fps", "128", "--script", "res://tests/plan_persistence.gd",
                                         "--", "--out=" + str(persisted), *(["--readback"] if mode == "readback" else [])],
                                        cwd=source, profile=profile, log=persisted / (mode + ".log"))
                    report["checks"].append({"name": "persistence-" + mode, "ok": True, **result})
            if args.envelope and not failures:
                centre = out / "centre-tape.json"
                if not centre.is_file():
                    raise ValueError("--envelope needs all three normal anchor tapes")
                result = engine.run(["--headless", "--audio-driver", "Dummy", "--path", source,
                                     "--fixed-fps", "128", "--script", "res://tests/plan_envelope.gd",
                                     "--", "--out=" + str(out / "envelope"), "--centre=" + str(centre)],
                                    cwd=source, profile=profile, log=out / "plan_envelope.log", timeout=60)
                report["checks"].append({"name": "envelope", "ok": True, **result})
                block = out / "envelope-block-route"
                result = engine.run(["--headless", "--audio-driver", "Dummy", "--path", source,
                                     "--fixed-fps", "128", "--script", "res://tests/plan_routes.gd",
                                     "--", "--out=" + str(block), "--arc", "--trial=0", "--loadout=block"],
                                    cwd=source, profile=profile, log=out / "envelope-block-route.log")
                report["checks"].append({"name": "envelope-block-baseline", "ok": True, **result})
                result = engine.run(["--headless", "--audio-driver", "Dummy", "--path", source,
                                     "--fixed-fps", "128", "--script", "res://tests/plan_envelope.gd",
                                     "--", "--out=" + str(out / "envelope-block"), "--centre=" + str(block / "block-tape.json"), "--loadout=block"],
                                    cwd=source, profile=profile, log=out / "plan_envelope_block.log", timeout=60)
                report["checks"].append({"name": "envelope-block", "ok": True, **result})
            report["ok"] = not failures
    except Exception as error:
        report["error"] = str(error)
        raise
    finally:
        (out / "RESULT.json").write_text(json.dumps(report, indent=2) + "\n")
        shutil.rmtree(source, ignore_errors=True)
        shutil.rmtree(profile, ignore_errors=True)
    if failures:
        raise RuntimeError("plan cases failed: " + ", ".join(failures) + "; read " + str(out / "RESULT.json"))
    print("PASS: " + str(out / "RESULT.json"))


if __name__ == "__main__":
    main()
