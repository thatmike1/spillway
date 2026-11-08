#!/usr/bin/env python3
"""p / deliberate negatives for tests/test_r15_loop.gd. each mutation breaks one rule of the r15
shell in a scratch copy of the project (never the checkout), runs the test group that owns that
rule, and passes only if the group now fails. an unmutated control run of the same groups must
pass. evidence that the loop's checks can fail, not that the shell is right.

python3 tests/test_r15_loop_mutations.py --out DIR [--godot PATH] [--only NAME,...]
exit 0 every mutation caught and the control passed, 1 otherwise.
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent
GODOT = Path.home() / ".local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64"

# name: (file, old, new, groups)
MUTATIONS = {
    "duck lift counts as body travel": ("scripts/r15_main.gd",
        "\treturn player.global_position - hull_origin_offset()\n", "\treturn player.global_position\n", "offset"),
    "record identity not checked on load": ("scripts/r15_main.gd",
        '\tif str(config.get_value(section, "identity", "")) != record_identity_text():', "\tif false:", "persist"),
    "mid-run switch stays clean": ("scripts/r15_main.gd",
        "\tif not untouched and not finished and clean_eligible:", "\tif false and not untouched:", "purity"),
    "practice finishes are saved": ("scripts/r15_main.gd",
        '\tif finish_kind == "clean" or finish_kind == "open":', "\tif true:", "persist"),
    "fingerprint from the preset, not the running body": ("scripts/r15_main.gd",
        '\t\treturn PRESETS.physics_fingerprint(player.get("settings"))', "\t\treturn PRESETS.physics_fingerprint(_source_settings(preset_id))", "missing"),
    "a missing runner falls back to the r14 runner": ("scripts/r15_main.gd",
        "\tif named == STANDIN:\n", "\tif named == STANDIN or not ResourceLoader.exists(named):\n", "missing"),
    "map change keeps a pending switch": ("scripts/r15_main.gd",
        "\tvar cancelled := not pending_preset.is_empty()\n\tpending_preset = \"\"\n", "\tvar cancelled := not pending_preset.is_empty()\n", "hull"),
    "missing map modules are listed": ("scripts/r15_maps.gd",
        "\tfor id: String in maps.order:\n\t\tif available(maps, id):\n\t\t\tout.append(id)\n\treturn out\n\n## registered", "\tfor id: String in maps.order:\n\t\tout.append(id)\n\treturn out\n\n## registered", "registry"),
    "vanilla64 is an r15 preset": ("scripts/r15_presets.gd",
        "const ORDER := [\"server128\",", "const ORDER := [\"vanilla64\", \"server128\",", "hook"),
    "map cards in one fixed row": ("scripts/r15_hud.gd",
        "\tmap_grid.columns = map_columns(inner)", "\tmap_grid.columns = 99", "chooser"),
    "stand-up deferral ignored by the hud": ("scripts/r15_hud.gd",
        '"CROUCH  ·  no room to stand" if bool(game.call("stand_blocked")) else "CROUCH"', '"CROUCH"', "crouch"),
}


def run_group(project: Path, out: Path, groups: str, godot: str) -> dict:
    out.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, XDG_DATA_HOME=str(out / "xdg/data"), XDG_CONFIG_HOME=str(out / "xdg/config"), XDG_CACHE_HOME=str(out / "xdg/cache"))
    cmd = [godot, "--headless", "--audio-driver", "Dummy", "--fixed-fps", "128", "--path", str(project), "--script", "res://tests/test_r15_loop.gd", "--", f"--out={out}", f"--only={groups}"]
    began = time.time()
    proc = subprocess.run(cmd, env=env, capture_output=True, text=True, timeout=600)
    summary = json.loads((out / "summary.json").read_text()) if (out / "summary.json").exists() else {}
    failed = [f"{r['group']} / {r['name']}" for r in summary.get("results", []) if not r["ok"]]
    shutil.rmtree(out / "xdg", ignore_errors=True)
    shutil.rmtree(out / "profiles", ignore_errors=True)
    parse_error = "Parse Error" in proc.stdout + proc.stderr
    return {"exit": proc.returncode, "checks": summary.get("checks"), "failed": failed, "parse_error": parse_error, "seconds": round(time.time() - began, 1)}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--godot", default=str(GODOT))
    ap.add_argument("--only", default="")
    args = ap.parse_args()
    out = Path(args.out).resolve()
    out.mkdir(parents=True, exist_ok=True)
    wanted = [n for n in args.only.split(",") if n] or list(MUTATIONS)
    scratch = Path(tempfile.mkdtemp(prefix="r15-mutations-"))
    copy = scratch / "foldrunner"
    shutil.copytree(PROJECT, copy, ignore=shutil.ignore_patterns(".git", "builds", "__pycache__"))
    report = {"project": str(PROJECT), "scratch": str(scratch), "godot": args.godot, "mutations": {}}
    try:
        env = dict(os.environ, XDG_DATA_HOME=str(scratch / "import/data"), XDG_CONFIG_HOME=str(scratch / "import/config"), XDG_CACHE_HOME=str(scratch / "import/cache"))
        subprocess.run([args.godot, "--headless", "--audio-driver", "Dummy", "--path", str(copy), "--import"], env=env, capture_output=True, timeout=300)
        groups = sorted({MUTATIONS[n][3] for n in wanted})
        report["control"] = run_group(copy, out / "control", ",".join(groups), args.godot)
        ok = report["control"]["exit"] == 0 and not report["control"]["failed"]
        for name in wanted:
            rel, old, new, group = MUTATIONS[name]
            path = copy / rel
            original = path.read_text()
            if original.count(old) != 1:
                report["mutations"][name] = {"applied": False, "caught": False, "why": f"pattern found {original.count(old)} times"}
                ok = False
                continue
            path.write_text(original.replace(old, new))
            try:
                result = run_group(copy, out / ("m-" + "".join(c if c.isalnum() else "-" for c in name)), group, args.godot)
            finally:
                path.write_text(original)
            caught = result["exit"] != 0 and bool(result["failed"]) and not result["parse_error"]
            report["mutations"][name] = {"applied": True, "file": rel, "group": group, "caught": caught} | result
            ok = ok and caught
            print(f"{'caught' if caught else 'MISSED'}: {name} ({len(result['failed'])} failing checks in {group})")
    finally:
        shutil.rmtree(scratch, ignore_errors=True)
    report["scratch_removed"] = not scratch.exists()
    report["ok"] = ok
    (out / "mutations.json").write_text(json.dumps(report, indent=1))
    print(f"r15 loop mutations: control {'passed' if report['control']['exit'] == 0 else 'FAILED'}, {sum(m['caught'] for m in report['mutations'].values())}/{len(wanted)} caught")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
