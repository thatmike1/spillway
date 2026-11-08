#!/usr/bin/env python3
"""focused offline checks for the initial r15 release-tool port; no package or game acceptance."""
import argparse
import copy
import importlib.util
import json
from pathlib import Path
from types import SimpleNamespace
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    spec = importlib.util.spec_from_file_location("r15_release", Path(__file__).parents[1] / "tools/package-r15.py")
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    checks = []

    def check(name, value):
        assert value, name
        checks.append(name)

    files = ["assets/momentum/licences/CC0.txt", "assets/r15/library/licences/kenney-train-License.txt",
             "assets/r15/library/MANIFEST.json", "assets/r15/breakwater/licences/CC0.txt", "assets/r15/breakwater/MANIFEST.json",
             "assets/r15/library/BOUNDS.json", "assets/r15/breakwater/sky.hdr", "assets/r15/library/NOTICE.md"]
    licences = m.licence_files(files)
    for path in files[:5]:
        check("recursive unique licence " + path, "licenses/" + path in licences)
    check("top-level asset notice bundled", "licenses/assets/r15/library/NOTICE.md" in licences)
    check("raw bounds dependency covered", "res://assets/r15/library/BOUNDS.json" in m.resources(files))
    check("HDR resource covered", "res://assets/r15/breakwater/sky.hdr" in m.resources(files))
    check("R14 profiles preserved", m.OLD_PROFILES.get("spillway_r14.cfg") == "r14")
    check("exact eight-map requirement", len(m.REQUIRED_MAPS) == 8 and len(set(m.REQUIRED_MAPS)) == 8 and m.DEFAULT_MAP == "breakwater")
    check("vanilla rate excluded", m.RATES == (120, 128))
    log = "r15: build=%s; map=breakwater; preset=server128; physics_hz=128; course_key=0123456789abcdef; records=off; runner=res://scripts/r15_source_player.gd; standin=false; renderer=gl_compatibility" % m.BUILD
    check("real R15 startup shape", m.STARTUP.search(log) is not None)
    check("stand-in startup rejected", m.STARTUP.search(log.replace("standin=false", "standin=true")) is None)
    rows = [{"phase": "tape", "tick": i, "post": {"p": [0.0, 0.0, float(i)], "v": [0.0, 0.0, 1.0], "yaw": 0.0},
             "game": {"checkpoint": 0, "elapsed": i / 128, "finished": False, "finish_kind": "", "respawns": 0}} for i in range(2)]
    check("complete source traces accepted", m.compare_traces(rows, copy.deepcopy(rows))["ok"])
    mutations = {
        "velocity changes while positions match": lambda v: v[0]["post"].update(v=[0.0, 0.0, -1.0]),
        "duplicate tick": lambda v: v[1].update(tick=0),
        "truncated velocity": lambda v: v[0]["post"].update(v=[0.0, 0.0]),
        "nonfinite velocity": lambda v: v[0]["post"].update(v=[0.0, float("nan"), 0.0]),
        "missing tick": lambda v: v.pop(),
    }
    for name, mutate in mutations.items():
        bad = copy.deepcopy(rows)
        mutate(bad)
        check(name + " rejected", not m.compare_traces(rows, bad)["ok"])
    with tempfile.TemporaryDirectory(prefix="r15-release-units-") as t:
        t = Path(t)
        reference = t / "source.jsonl"
        reference.write_text("".join(json.dumps(r) + "\n" for r in rows))
        packed = [{"tick": r["tick"], **r["post"], **r["game"]} for r in rows]
        target = t / "packed.jsonl"
        target.write_text("".join(json.dumps(r) + "\n" for r in packed))
        check("complete packed trace accepted", m.shipped_trace_match(target, reference)["ok"])
        packed[0]["v"][2] = -1.0
        target.write_text("".join(json.dumps(r) + "\n" for r in packed))
        check("packed velocity lie rejected", not m.shipped_trace_match(target, reference)["ok"])
        for startup in (False, True):
            output = t / ("startup" if startup else "incomplete")
            config = SimpleNamespace(output=output, diagnostic=False, startup_only=startup, route=[])
            try:
                m.package(config)
            except m.Rejected:
                check("release without course proofs refused " + str(startup), not output.exists())
            else:
                raise AssertionError("incomplete release accepted")
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps({"passed": len(checks), "failed": 0, "checks": checks,
                                    "scope": "offline component checks; no exported pack, native runtime or final closure"}, indent=2) + "\n")
    print("%d offline R15 release checks pass" % len(checks))


if __name__ == "__main__":
    main()
