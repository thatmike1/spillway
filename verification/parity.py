"""Replay all original routes with the retained R21 executor and exact audit."""
import json
from pathlib import Path
import shutil
import sys
import time
import multiprocessing
from concurrent.futures import ProcessPoolExecutor

PROJECT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(PROJECT / "tools"), str(Path(__file__).resolve().parent / "lib")]
import engine
import parity_core as K
import audit
from fast_exact import install

install(K)
FIXTURES = PROJECT / "tests/fixtures/original-map-parity"


def fixtures():
    expected = K.load(FIXTURES / "SHA256.json")
    actual = {str(p.relative_to(FIXTURES)) for p in FIXTURES.rglob("*") if p.is_file()}
    K.exact(actual, set(expected) | {"SHA256.json"}, "fixture inventory")
    for name, digest in expected.items():
        K.need(engine.sha(FIXTURES / name) == digest, "frozen fixture changed: " + name)
    return K.load(FIXTURES / "routes.json"), K.load(FIXTURES / "contract.json")


def snapshot(target):
    # fixtures and evidence never enter an engine's resource tree.
    target.mkdir()
    names = ["project.godot", "export_presets.cfg", "scripts", "assets", "scenes", "shaders", "data"]
    for name in names:
        path = PROJECT / name
        if path.is_dir():
            shutil.copytree(path, target / name, ignore=shutil.ignore_patterns("*.import", "__pycache__"))
        elif path.is_file():
            shutil.copy2(path, target / name)
    for folder in ("tests", "tools", "verification/frozen"):
        for path in (PROJECT / folder).rglob("*"):
            if path.is_file() and (path.suffix == ".gd" or path.name.endswith(".gd.uid")):
                dest = target / path.relative_to(PROJECT)
                dest.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(path, dest)
    return {str(p.relative_to(target)): engine.sha(p) for p in target.rglob("*") if p.is_file()}


def audit_one(out, route, contract):
    target = out / route["name"] / "audit"
    target.mkdir()
    return audit.audit_route(out, route, {"helpers": {}, "contract": contract}, target)


def run(out):
    engine.check_pin()
    routes, contract = fixtures()
    K.need(len(routes) == 16 and len({r["map"] for r in routes}) == 8, "full original matrix required")
    K.need(not out.exists(), "choose a new --out directory")
    K.need(engine.temporary_headroom() >= 1_200_000_000, "need 1.2 GB temporary headroom")
    K.B.gate()
    out.mkdir(parents=True)
    source, profile, cache = out / "source", out / "profile", out / "cache"
    copied = snapshot(source)
    profile.mkdir()
    cache.mkdir()
    (source / ".godot").symlink_to(cache)
    K.B.GODOT = engine.GODOT
    K.FINAL = out
    report = {"ok": False, "project": str(PROJECT), "plays": 0, "comparisons": 0,
              "differences": 0, "routes": [], "started": time.time(), "source": copied,
              "fixture_manifest_sha256": engine.sha(FIXTURES / "SHA256.json")}

    def save():
        K.B.write(out / "RESULT.json", report)

    def launch(command, log):
        with engine.locked():
            return K.B.bounded(command, engine.environment(profile), source, log, out)

    pending = []
    pool = ProcessPoolExecutor(max_workers=2, mp_context=multiprocessing.get_context("fork"))

    def harvest(all_routes=False):
        for route, future in list(pending):
            if not all_routes and not future.done():
                continue
            comparisons = future.result()
            report["routes"].append({"name": route["name"], "comparisons": comparisons})
            report["comparisons"] += 18
            pending.remove((route, future))
            save()
            print(route["name"] + ": 18 exact comparisons, zero differences", flush=True)

    try:
        report["import"] = launch([str(engine.GODOT), "--headless", "--editor", "--path", str(source), "--import"], out / "import.log")
        K.need(report["import"]["exit"] == 0, "fresh import failed")
        K.need(not any(t in (out / "import.log").read_text() for t in ("ERROR:", "Parse Error")), "fresh import errors")
        for route in routes:
            print("replay " + route["name"], flush=True)
            directory = out / route["name"]
            directory.mkdir()
            plan, encoded = K.route_plan(route)
            (directory / "expanded.json").write_bytes(encoded)
            result = {"route": route, "runs": {}}
            for variant in K.VARIANTS:
                dest = directory / variant
                dest.mkdir()
                (dest / "runs").mkdir()
                golden = FIXTURES / route["name"] / "old/runs/golden.r16run"
                shutil.copy2(golden, dest / "runs/golden.r16run")
                command = K.route_command(route, variant, source, dest, golden, directory / "expanded.json")
                stopped, threads, paths, errors, receipts = K.B.start_trace_streams(dest)
                try:
                    observed = launch(command, dest / "engine.log")
                finally:
                    stopped.set()
                    for thread in threads:
                        thread.join(10)
                K.need(not errors and all(not t.is_alive() for t in threads), "trace compression failed")
                for path in paths:
                    path.unlink()
                observed["summary"] = K.load(dest / "summary.json")
                observed["helpers"] = {}
                observed["engine_errors"] = [line for line in (dest / "engine.log").read_text().splitlines()
                                              if any(t in line for t in ("ERROR", "Parse Error", "Assertion failed"))]
                observed["ok"] = observed["exit"] == 0 and not observed["engine_errors"]
                K.need(observed["ok"], "route failed; read " + str(dest / "engine.log"))
                observed["trace_compression"] = receipts
                result["runs"][variant] = observed
                report["plays"] += 1
                save()
            K.B.write(directory / "result.json", result)
            pending.append((route, pool.submit(audit_one, out, route, contract)))
            harvest()
            if len(pending) >= 2:
                pending[0][1].result()
                harvest()
        harvest(all_routes=True)
        report["negative_controls"] = audit.negative_seed(out / routes[0]["name"] / "old", out / "negative-controls", contract, "new")
        K.need(report["plays"] == 48 and report["comparisons"] == 288, "incomplete matrix")
        for name, digest in copied.items():
            K.need(engine.sha(source / name) == digest, "source changed during replay: " + name)
        report["ok"] = True
        report["finished"] = time.time()
        print("PASS: 48 plays, 16 routes, 288 exact comparisons, zero differences", flush=True)
        return report
    finally:
        pool.shutdown(wait=True, cancel_futures=True)
        save()
