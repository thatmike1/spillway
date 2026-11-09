#!/usr/bin/env python3
"""challenge frozen r15 release helpers without exports, native rendering or active run writes.

gap cases deliberately expect today's false acceptance; a green review run reproduces a
finding, not release acceptance. only the disposable probe is changed for repair controls.
"""
import argparse
import copy
import gzip
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tarfile
import tempfile
import time
from types import SimpleNamespace
from unittest.mock import patch

PROJECT = Path(__file__).resolve().parents[1]
COMMIT = "406640de38a041c86471ab69172e74f2b38f7e84"
FROZEN = ["tools/package-r15.py", "tools/r15-pack-probe.gd", "tools/momentum-tape.py", "tools/r14_native_display.py"]
OUTER = Path("/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r15")


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def load(path):
    spec = importlib.util.spec_from_file_location("release_review_owner", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def alive(pid):
    try:
        return Path(f"/proc/{pid}/stat").read_text().split(")", 1)[1].split()[0] != "Z"
    except FileNotFoundError:
        return False


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--retained", type=Path, default=OUTER / "observer-repair-final")
    args = parser.parse_args()
    args.out = args.out.resolve()
    args.out.mkdir(parents=True, exist_ok=False)
    checks = []
    commands = []
    process_controls = []

    def expect(name, actual, wanted=True, detail=None):
        checks.append(dict(name=name, ok=actual == wanted, actual=actual, expected=wanted, detail=detail))

    def command(argv, **kwargs):
        commands.append([str(a) for a in argv])
        return subprocess.run(argv, **kwargs)

    free = shutil.disk_usage("/tmp").free
    expect("scratch has at least 128 MiB before small helper copies", free >= 128 * 2**20, detail=free)
    if not checks[-1]["ok"]:
        raise RuntimeError("insufficient scratch")
    with tempfile.TemporaryDirectory(prefix="r15-release-review-") as temp:
        scratch = Path(temp)
        source = scratch / "frozen"
        hashes = {}
        for name in FROZEN:
            data = command(["git", "show", COMMIT + ":projects/foldrunner/" + name], cwd=PROJECT, capture_output=True, check=True).stdout
            target = source / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
            hashes[name] = sha(target)
            expect("checkout equals reviewed commit: " + name, sha(PROJECT / name) == hashes[name])
        owner = load(source / "tools/package-r15.py")
        expect("editor is the pinned executable", sha(owner.EDITOR) == owner.EDITOR_SHA256)
        (args.out / "EXECUTED-SOURCES.json").write_text(json.dumps({"commit": COMMIT, "frozen": hashes,
            "review": {str(p.relative_to(PROJECT)): sha(p) for p in [Path(__file__), Path(__file__).with_suffix(".gd.in")]},
            "editor": {"path": str(owner.EDITOR), "sha256": sha(owner.EDITOR)}}, indent=2) + "\n")

        # exercise the exact gd methods in a minimal headless project, with no game/assets.
        mini = scratch / "mini"
        mini.mkdir()
        (mini / "project.godot").write_text('[application]\nconfig/name="R15 release review"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        probe_bytes = (source / "tools/r15-pack-probe.gd").read_bytes()
        shutil.copy2(Path(__file__).with_suffix(".gd.in"), mini / "review.gd")
        repairs = probe_bytes.decode().replace("label.visible_characters == 0", "(label.visible_characters >= 0 and label.visible_characters < label.get_total_character_count())")
        repairs = repairs.replace("\t\tif node is CanvasItem:\n\t\t\talpha *= node.modulate.a",
            "\t\tif node is Control and node.clip_contents and not node.get_global_rect().intersects(rect):\n\t\t\treturn false\n\t\tif node is CanvasItem:\n\t\t\talpha *= node.modulate.a")
        anchor = "\t\t\t\t_materials(material, out)\n"
        assert repairs.count(anchor) == 1
        repairs = repairs.replace(anchor, anchor + "\t\t\t\tif material is BaseMaterial3D and material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED and material.albedo_color.a <= 0.05:\n\t\t\t\t\tcontinue\n")
        (args.out / "component-repair.patch").write_text("".join(__import__("difflib").unified_diff(probe_bytes.decode().splitlines(True), repairs.splitlines(True), "frozen-probe", "scratch-repair-control")))
        for variant, data in [("original", probe_bytes), ("repair-control", repairs.encode())]:
            (mini / "probe.gd").write_bytes(data)
            output = args.out / (variant + ".json")
            argv = [str(owner.EDITOR), "--headless", "--audio-driver", "Dummy", "--path", str(mini), "--script", "res://review.gd", "--", "--out=" + str(output)]
            commands.append(argv)
            code, text = owner.run_engine(argv, mini, owner.engine_env(scratch / (variant + "-profile")), args.out / (variant + ".log"), 30)
            expect(variant + " gd runner exits without errors", code == 0 and not owner.ERRORS.search(text), detail=text[-1800:])
            if not output.exists():
                continue
            obs = {row["name"]: row["value"] for row in json.loads(output.read_text())}
            for name in ["complete label admitted", "integer tick array admitted"]:
                expect(variant + ": " + name, obs[name])
            for name in ["zero character label admitted", "transparent label admitted", "hidden label admitted", "float tick array admitted", "bool tick admitted", "truncated tick array admitted", "changed tick array admitted"]:
                expect(variant + ": " + name, obs[name], False)
            expect(variant + ": partial label gap", obs["one character label admitted"], variant == "original")
            expect(variant + ": clipped label gap", obs["clipped label admitted"], variant == "original")
            expect(variant + ": label wholly outside clipping parent", obs["clipping parent intersects label"], False)
            expect(variant + ": opaque floor counted", "ReviewFloor" in obs["opaque floor scan"]["nodes"])
            expect(variant + ": transparent floor gap", "ReviewFloor" in obs["transparent floor scan"]["nodes"], variant == "original")
            expect(variant + ": transparent triangle gap", obs["transparent floor triangle"], "ReviewFloor" if variant == "original" else "")
            expect(variant + ": hidden floor refused", obs["hidden floor triangle"], "")
            (args.out / (variant + "-sha256.txt")).write_text(sha(mini / "probe.gd") + "  probe.gd\n")

        # retained real observer capture, relabelled only as an input-audit component fixture.
        retained = args.retained.resolve()
        rows = [json.loads(line) for line in gzip.open(retained / "air-f2/trace.jsonl.gz", "rt") if line.strip()]
        plan = json.loads((retained / "air-f2.tape.json").read_text())
        settings = next(r["input_settings"] for r in json.loads((retained / "runs.json").read_text()) if r["name"] == "air-f2")
        inputs = {str(p): sha(p) for p in [retained / "air-f2/trace.jsonl.gz", retained / "air-f2.tape.json", retained / "runs.json"]}
        (args.out / "RETAINED-INPUTS.json").write_text(json.dumps(inputs, indent=2) + "\n")
        def audit(values):
            return owner.packed_input_audit(values, plan, settings, observer_path=source / "tools/momentum-tape.py", expected_observer_sha256=hashes["tools/momentum-tape.py"])
        expect("retained real capture accepted by frozen helper", audit(rows)["ok"])
        mouse_tick = next(i for i, row in enumerate(rows) if row["audit"]["mouse"])
        findings = []
        for field in ["yaw_after", "pitch_after"]:
            for value, accepted in [(float("nan"), True), (float("inf"), False), (123.0, False)]:
                bad = copy.deepcopy(rows)
                bad[mouse_tick]["audit"]["mouse"][field] = value
                verdict = audit(bad)
                label = f"mouse {field} {value}"
                expect(label, verdict["ok"], accepted, verdict)
                findings.append({"name": label, "tick": mouse_tick, "verdict": verdict})
                if value != value:
                    raw_trace = scratch / (field + "-nan.jsonl")
                    raw_trace.write_text("".join(json.dumps(row, separators=(",", ":")) + "\n" for row in bad))
                    # the enclosing package also reads all json with a strict parser.
                    expect(label + " rejected by enclosing strict trace reader", owner.shipped_trace_match(raw_trace, "unused-reference")["ok"], False)
                    with gzip.open(args.out / (field + "-nan.jsonl.gz"), "wt", compresslevel=9) as stream:
                        for row in bad:
                            stream.write(json.dumps(row, separators=(",", ":")) + "\n")
        for name, mutate in [
            ("top-level velocity NaN", lambda r: r[10]["v"].__setitem__(0, float("nan"))),
            ("float tick", lambda r: r[10].__setitem__("tick", 10.0)),
            ("missing tick", lambda r: r.pop(10)),
            ("duplicate tick", lambda r: r[10].__setitem__("tick", 9)),
            ("short vector", lambda r: r[10].__setitem__("p", [1, 2])),
            ("wrong steady hull height", lambda r: r[50]["audit"]["hull_origin"]["after"]["box_size_m"].__setitem__(1, 72 * .0254)),
        ]:
            bad = copy.deepcopy(rows)
            mutate(bad)
            expect(name + " refused", audit(bad)["ok"], False)
        changed_observer = scratch / "changed-observer.py"
        changed_observer.write_text("def hull_origin_compensation(audit):\n    return None\n")
        expect("changed observer manifest refused", owner.packed_input_audit(rows, plan, settings,
            observer_path=changed_observer, expected_observer_sha256=hashes["tools/momentum-tape.py"])["ok"], False)
        (args.out / "INPUT-AUDIT.json").write_text(json.dumps(findings, indent=2) + "\n")

        # source-route caller fixtures: exact verdict flow and nested engine log admission.
        source_rows = [{"phase": "tape", "tick": i, "pre": {"tape_step_count": 8 + i, "p": [0., 0., 0.]},
            "post": {"p": [0., 0., float(i)], "v": [0., 0., 1.], "yaw": 0.},
            "game": {"checkpoint": i, "elapsed": i / 128, "finished": i == 2, "finish_kind": "clean" if i == 2 else "", "respawns": 0}} for i in range(3)]
        synthetic_plan = {"physics_hz": 128, "version": 2, "duration_ticks": 3}
        tape = scratch / "synthetic-tape.json"
        tape.write_text(json.dumps(synthetic_plan))
        for name in ["baseline", "nested-error", "missing-log", "reference-motion", "reference-velocity", "reference-finish", "order-false", "rate-false", "delivery-false", "cleanup-false", "integrity-flag"]:
            evidence = args.out / "source-caller" / name
            reference = scratch / (name + "-reference.jsonl")
            ref_rows = copy.deepcopy(source_rows)
            if name == "reference-motion": ref_rows[1]["post"]["p"][1] = 0.01
            if name == "reference-velocity": ref_rows[1]["post"]["v"][1] = 0.01
            if name == "reference-finish": ref_rows[-1]["game"]["finish_kind"] = "practice"
            reference.write_text("".join(json.dumps(r) + "\n" for r in ref_rows))
            route = dict(name=name, map="breakwater", preset="server128", tape=str(tape), reference=str(reference))
            def fake_engine(argv, cwd, env, log, deadline, **kwargs):
                log.parent.mkdir(parents=True, exist_ok=True)
                log.write_text("synthetic supervisor: no engine error\n")
                if "expand" in argv:
                    return 0, json.dumps(synthetic_plan)
                run = Path(argv[argv.index("--out") + 1]) / "evaluator"
                run.mkdir(parents=True)
                (run / "trace.jsonl").write_text("".join(json.dumps(r) + "\n" for r in source_rows))
                report = {"rate": {"ok": name != "rate-false"}, "delivery": {"ok": name != "delivery-false"},
                    "order": {"ok": name != "order-false"}, "cleanup": {"clean": name != "cleanup-false"},
                    "neutral": True, "end": "completed", "integrity_flags": ["broken"] if name == "integrity-flag" else []}
                (run / "report.json").write_text(json.dumps(report))
                (run / "engine.json").write_text(json.dumps({"settings": settings}))
                if name != "missing-log":
                    (run / "godot.log").write_text("SCRIPT ERROR: deliberate nested error\n" if name == "nested-error" else "Godot synthetic control\n")
                return 0, "supervisor returned zero"
            try:
                with patch.object(owner, "run_engine", fake_engine):
                    result = owner.source_route(route, source, evidence)
                accepted = True
                detail = result
            except owner.Rejected as error:
                accepted, detail = False, str(error)
            expect("source caller " + name, accepted, name == "baseline", detail)

        # release route completeness is enforced before preflight/export.
        all_routes = [dict(map=m, preset=owner.DEFAULT_PRESET, name=m) for m in owner.REQUIRED_COURSES]
        all_routes += [dict(map="breakwater", preset="server128_aa1000", name="f5")]
        for omit in range(len(all_routes) + 1):
            routes = [r for i, r in enumerate(all_routes) if i != omit]
            cfg = SimpleNamespace(output=scratch / "not-written", diagnostic=False, startup_only=False, route=routes)
            try:
                with patch.object(owner, "git", return_value=str(PROJECT.parents[1]) + "\n"), patch.object(owner, "preflight", side_effect=owner.Rejected("review preflight sentinel")):
                    owner.package(cfg)
            except owner.Rejected as error:
                detail = str(error)
            else:
                detail = "unexpected acceptance"
            expect("release route admission omit " + str(omit),
                detail == "review preflight sentinel" if omit == len(all_routes) else detail.startswith("release play proofs need F2"), True, detail)

        # recheck interruption controls use a tiny fake archive, never a candidate or engine.
        archive = io.BytesIO()
        with tarfile.open(fileobj=archive, mode="w") as stream:
            for name in ["tools/r15-pack-probe.gd", "tools/momentum-tape.py"]:
                data = (source / name).read_bytes()
                info = tarfile.TarInfo(name)
                info.size = len(data)
                stream.addfile(info, io.BytesIO(data))
        cleanup = []
        for kind in ["success", "refusal", "cancel"]:
            evidence = args.out / "recheck-cleanup" / kind
            evidence.mkdir(parents=True)
            cfg = SimpleNamespace(route=[])
            def fake_import(*_args):
                cache = evidence / "source-freeze/.godot/imported"
                cache.mkdir(parents=True)
                (cache / "review-owned-placeholder").write_text("synthetic import cache")
                if kind == "refusal": raise owner.Rejected("controlled import refusal")
                if kind == "cancel": raise KeyboardInterrupt("controlled import cancellation")
            outcome = "success"
            try:
                with patch.object(owner, "source_archive", return_value=archive.getvalue()), patch.object(owner, "git", return_value=str(PROJECT.parents[1])), patch.object(owner, "checked", fake_import):
                    owner.recheck_routes({"source_commit": COMMIT, "source_project_path": "projects/foldrunner", "identity": {}}, cfg, evidence)
            except owner.Rejected:
                outcome = "refusal"
            except KeyboardInterrupt:
                outcome = "cancel"
            stage = evidence / "source-freeze"
            observed = {"case": kind, "outcome": outcome, "frozen_stage_left": stage.exists(),
                "import_cache_left": (stage / ".godot/imported/review-owned-placeholder").exists()}
            cleanup.append(observed)
            expect("recheck cleanup outcome " + kind, outcome, kind)
            expect("recheck leaves transient source on " + kind, stage.exists(), kind != "success")
            # retain the observation, remove our deliberately leaked scratch and caches.
            shutil.rmtree(stage, ignore_errors=True)
            shutil.rmtree(evidence / "freeze-profile", ignore_errors=True)
        (args.out / "RECHECK-CLEANUP.json").write_text(json.dumps(cleanup, indent=2) + "\n")

        # run the exact owner against disposable success, deadline and wrapper-only signals.
        for kind in ["success", "deadline", "SIGINT", "SIGTERM"]:
            pidfile = scratch / (kind + "-pids.json")
            actor = ("import os,subprocess,sys,json,time;from pathlib import Path;"
                "child=subprocess.Popen([sys.executable,'-c','import time;time.sleep(30)']);"
                "Path(%r).write_text(json.dumps([os.getpid(),child.pid]));" % str(pidfile)
                + ("time.sleep(.1)" if kind == "success" else "time.sleep(30)"))
            argv = [sys.executable, "-I", "-c", actor]
            pids = []
            process = None
            try:
                if kind in ["success", "deadline"]:
                    commands.append(argv)
                    process_controls.append({"case": kind, "actor_argv": argv, "python_sha256": sha(sys.executable)})
                    code, _ = owner.run_engine(argv, scratch, os.environ.copy(), args.out / (kind + ".log"), .5 if kind == "deadline" else 5)
                    pids = json.loads(pidfile.read_text())
                    expect(kind + " correct exit", code, "timeout" if kind == "deadline" else 0)
                else:
                    wrapper = scratch / (kind + "-wrapper.py")
                    wrapper.write_text("import importlib.util,os\nfrom pathlib import Path\n"
                        + "s=importlib.util.spec_from_file_location('owner',%r)\nm=importlib.util.module_from_spec(s);s.loader.exec_module(m)\n" % str(source / "tools/package-r15.py")
                        + "m.run_engine(%r,Path(%r),os.environ.copy(),Path(%r),20)\n" % (argv, str(scratch), str(args.out / (kind + ".log"))))
                    argv_wrapper = [sys.executable, "-I", str(wrapper)]
                    commands.append(argv_wrapper)
                    process_controls.append({"case": kind, "actor_argv": argv, "wrapper_argv": argv_wrapper,
                        "wrapper_sha256": sha(wrapper), "wrapper_source": wrapper.read_text(), "python_sha256": sha(sys.executable)})
                    with (args.out / (kind + "-wrapper.log")).open("wb") as log:
                        process = subprocess.Popen(argv_wrapper, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
                        end = time.monotonic() + 8
                        while not pidfile.exists() and time.monotonic() < end and process.poll() is None:
                            time.sleep(.02)
                        assert pidfile.exists(), kind
                        pids = json.loads(pidfile.read_text())
                        os.kill(process.pid, getattr(signal, kind))
                        process.wait(10)
                end = time.monotonic() + 2
                while any(alive(pid) for pid in pids) and time.monotonic() < end:
                    time.sleep(.02)
                expect(kind + " releases engine and child", not any(alive(pid) for pid in pids), detail=pids)
            finally:
                if process is not None and process.poll() is None:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait(5)
                for pid in pids:
                    if alive(pid): os.kill(pid, signal.SIGKILL)
        expect("frozen source unchanged", all(sha(source / name) == digest for name, digest in hashes.items()))
        expect("retained source unchanged", all(sha(path) == digest for path, digest in inputs.items()))
        scratch_name = str(scratch)
    expect("scratch removed", not Path(scratch_name).exists(), detail=scratch_name)
    owner.compress_evidence(args.out)
    (args.out / "COMMANDS.json").write_text(json.dumps({"invocation": [sys.executable, "-I", str(Path(__file__).resolve()), *sys.argv[1:]], "commands": commands}, indent=2) + "\n")
    (args.out / "PROCESS-CONTROLS.json").write_text(json.dumps(process_controls, indent=2) + "\n")
    summary = {"ok": all(c["ok"] for c in checks), "checks": checks, "passed": sum(c["ok"] for c in checks),
        "failed": sum(not c["ok"] for c in checks), "scratch_removed": not Path(scratch_name).exists(),
        "scope": "frozen helper components, retained source capture and disposable processes; no source suite, native render, export or package acceptance"}
    (args.out / "RESULTS.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps({k: summary[k] for k in ["ok", "passed", "failed", "scratch_removed"]}))
    for row in checks:
        if not row["ok"]: print("UNMET", row["name"], row["actual"], row["expected"])
    raise SystemExit(0 if summary["ok"] else 1)


if __name__ == "__main__":
    main()
