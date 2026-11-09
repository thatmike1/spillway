#!/usr/bin/env python3
"""challenge the frozen-r15 boundary using mutations of an isolated source snapshot."""
import argparse
import importlib.util
import json
from pathlib import Path
import tempfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("r16_preservation", ROOT / "tools/check-r16-preservation.py")
P = importlib.util.module_from_spec(spec)
spec.loader.exec_module(P)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    old = P.baseline(ROOT)
    results = []

    def check(name, ok, detail=""):
        results.append({"name": name, "ok": bool(ok), "detail": detail})

    with tempfile.TemporaryDirectory(prefix="r16-preservation-") as directory:
        project = Path(directory)
        for name, content in old.items():
            path = project / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(content)
        config = old["project.godot"].decode().replace('run/main_scene="res://scenes/r15.tscn"', 'run/main_scene="res://scenes/r16.tscn"')
        config = config.replace('config/version="2026.11.08-r14"', 'config/version="2026.11.09-r16"')
        (project / "project.godot").write_text(config)
        positive = P.verify(project, old)
        check("R16 namespace changes preserve the frozen source", positive["failed"] == 0, positive["failed"])
        for name in ["scripts/r15_source_player.gd", "scripts/r15_experiment_player.gd", "scripts/r15_breakwater_level.gd",
                     "scripts/r15_whiteout_level.gd", "scripts/r15_sunken_level.gd", "scripts/r15_rainline_level.gd",
                     "scripts/r15_nightshift_level.gd", "shaders/momentum_surface.gdshader", "scenes/r15.tscn",
                     next(n for n in old if n.startswith("assets/") and n.endswith(".png"))]:
            path = project / name
            path.write_bytes(old[name] + b"modified")
            report = P.verify(project, old)
            failed = [r["name"] for r in report["results"] if not r["ok"]]
            check("reject changed " + name, failed == [name], failed)
            path.write_bytes(old[name])
        name = "scripts/r15_source_player.gd"
        path = project / name
        path.unlink()
        report = P.verify(project, old)
        check("reject a missing approved runner", report["failed"] == 1)
        replacement = project / "unchanged-content.gd"
        replacement.write_bytes(old[name])
        path.symlink_to(replacement)
        report = P.verify(project, old)
        check("a symlink with equal bytes cannot redirect the frozen runner", report["failed"] == 1)
        path.unlink()
        path.write_bytes(old[name])
        (project / "project.godot").write_text(config.replace("common/physics_ticks_per_second=120", "common/physics_ticks_per_second=64"))
        check("reject global tick-rate changes", P.verify(project, old)["failed"] == 1)
        (project / "project.godot").write_text(config + '\n[rendering]\nrenderer/rendering_method="mobile"\n')
        check("duplicate renderer declarations are refused", P.verify(project, old)["failed"] == 1)
        (project / "project.godot").write_text(old["project.godot"].decode())
        check("release refuses the R15 default and stale metadata", P.verify(project, old)["failed"] == 2)
        check("explicit development mode labels the old default", P.verify(project, old, allow_r15_default=True)["development_only"]
              and P.verify(project, old, allow_r15_default=True)["failed"] == 0)
        (project / "project.godot").write_text(config)
        exports = old["export_presets.cfg"].decode()
        (project / "export_presets.cfg").write_text(exports + '\n[preset.5]\nname="R16 Pack"\n')
        check("new export preset may be appended", P.verify(project, old)["failed"] == 0)
        (project / "export_presets.cfg").write_text(exports.replace('name="R15 Pack"', 'name="changed old preset"'))
        check("old export definitions cannot be rewritten", P.verify(project, old)["failed"] == 1)
    report = {"checks": len(results), "failed": sum(not r["ok"] for r in results), "results": results}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=2) + "\n")
    print("R16 preservation controls: %d checks, %d failed" % (report["checks"], report["failed"]))
    return int(report["failed"] != 0)


if __name__ == "__main__":
    raise SystemExit(main())
