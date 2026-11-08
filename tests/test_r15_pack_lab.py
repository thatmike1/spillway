#!/usr/bin/env python3
"""exercise the production lab-control coroutine on a frozen source copy, then break it.

this is headless source evidence. real exported drawing and package admission remain separate.
"""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

PROJECT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    args.out = args.out.resolve()
    args.out.mkdir(parents=True, exist_ok=False)
    spec = importlib.util.spec_from_file_location("owner", PROJECT / "tools/package-r15.py")
    owner = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(owner)
    results = []
    with tempfile.TemporaryDirectory(prefix="r15-lab-controls-") as temp:
        source = Path(temp) / "source"
        source.mkdir()
        for raw in subprocess.check_output(["git", "ls-files", "-co", "--exclude-standard", "-z", "--", "."], cwd=PROJECT).split(b"\0"):
            if raw:
                rel = Path(os.fsdecode(raw))
                target = source / rel
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(PROJECT / rel, target)
        files = {str(f.relative_to(source)): hashlib.sha256(f.read_bytes()).hexdigest() for f in source.rglob("*") if f.is_file()}
        (args.out / "SOURCES.json").write_text(json.dumps(files, indent=1) + "\n")
        env = owner.engine_env(Path(temp) / "profile")
        code, text = owner.run_engine([owner.EDITOR, "--headless", "--audio-driver", "Dummy", "--path", source, "--import"], source, env, args.out / "import.log", 180)
        assert code == 0 and not owner.ERRORS.search(text), text[-2000:]
        generated = source / "tests/test_r15_pack_lab.gd.uid"
        if generated.is_file() and not (PROJECT / generated.relative_to(source)).exists():
            shutil.copy2(generated, PROJECT / generated.relative_to(source))
        changed = source / "scripts/r15_main.gd"
        hud = source / "scripts/r15_hud.gd"
        originals = {changed: changed.read_text(), hud: hud.read_text()}
        cases = [("baseline", None, None, None),
                 ("toggle-key-does-nothing", changed, "\t\t\ttoggle_mechanic(id)", "\t\t\tpass"),
                 ("lab-body-sticks-on-course", changed,
                  '\tif player != null and current == runner_path():',
                  '\tif player != null and (current == runner_path() or current == EXPERIMENT_RUNNER):'),
                 ("experimental-tag-hidden", hud, "\tlab_tag.visible = lab", "\tlab_tag.visible = false")]
        for name, path, before, after in cases:
            for f, content in originals.items():
                f.write_text(content)
            if path:
                assert before in path.read_text(), (name, before)
                path.write_text(path.read_text().replace(before, after, 1))
            out = args.out / name
            code, text = owner.run_engine([owner.EDITOR, "--headless", "--audio-driver", "Dummy", "--fixed-fps", "128", "--path", source,
                                           "--script", "res://tests/test_r15_pack_lab.gd", "--", "--out=" + str(out)],
                                          source, env, args.out / (name + ".log"), 180)
            report = json.loads((out / "RESULTS.json").read_text())
            failures = [c["name"] for c in report["checks"] if not c["ok"]]
            ok = code == (0 if name == "baseline" else 1) and not owner.ERRORS.search(text)
            ok = ok and (not failures if name == "baseline" else bool(failures))
            results.append({"name": name, "ok": bool(ok), "exit": code, "checks": len(report["checks"]), "failures": failures})
            print(name, "PASS" if ok else "FAIL", len(report["checks"]), failures[:4], flush=True)
        for f, content in originals.items():
            f.write_text(content)
        assert all(hashlib.sha256((source / rel).read_bytes()).hexdigest() == digest for rel, digest in files.items()), "frozen source was not restored"
    summary = {"ok": all(r["ok"] for r in results), "cases": results, "scratch_removed": not Path(temp).exists(),
               "scope": "actual source-mode lab coroutine and three deliberate runtime mutations; no render, export or feel verdict"}
    (args.out / "RESULTS.json").write_text(json.dumps(summary, indent=1) + "\n")
    raise SystemExit(0 if summary["ok"] else 1)


if __name__ == "__main__":
    main()
