#!/usr/bin/env python3
"""regressions for the independently reproduced r14 verifier gaps; no real game is modified."""
import argparse
import copy
import gzip
import importlib.util
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import time
from unittest.mock import patch

PROJECT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('r14_pack', PROJECT / 'tools/package-r14.py')
pr = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pr)
checks = []


def check(name, ok, detail=None):
    checks.append(dict(name=name, ok=bool(ok), detail=detail))
    print(('PASS ' if ok else 'FAIL ') + name, flush=True)


def write_trace(path, rows):
    opener = gzip.open if path.suffix == '.gz' else open
    with opener(path, 'wt') as stream:
        stream.write(''.join(json.dumps(r, separators=(',', ':')) + '\n' for r in rows))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--only', nargs='+', choices=['data', 'source', 'godot', 'cancel'])
    args = parser.parse_args()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    if any(out.iterdir()):
        raise SystemExit('use a fresh output')
    good = [dict(phase='tape', tick=i, pre=dict(p=[0., 0., 0.], tape_step_count=8+i),
                 post=dict(p=[float(i), 2., 3.], yaw=0.),
                 game=dict(checkpoint=i, elapsed=float(i), finished=i == 2,
                           finish_kind='clean' if i == 2 else '', respawns=0)) for i in range(3)]
    reference = out / 'reference.jsonl.gz'
    write_trace(reference, good)
    if not args.only or 'data' in args.only:
        variants = {'valid': copy.deepcopy(good), 'duplicate': [good[0]]*3, 'reverse': list(reversed(good)),
                    'short': copy.deepcopy(good), 'nan': copy.deepcopy(good), 'missing game': copy.deepcopy(good),
                    'disjoint': [{**r, 'tick': r['tick']+100} for r in good], 'empty': [], 'short duration': good[:-1],
                    'wrong position': copy.deepcopy(good), 'boolean tick': copy.deepcopy(good)}
        for row in variants['short']: row['post']['p'] = row['post']['p'][:1]
        for row in variants['nan']: row['post'].update(p=[float('nan')]*3, yaw=float('nan'))
        for row in variants['missing game']: row['game'].pop('respawns')
        variants['wrong position'][1]['post']['p'][1] += 1
        variants['boolean tick'][0]['tick'] = False
        for name, rows in variants.items():
            result = pr.compare_traces(rows, good)
            check('executor comparison ' + name, result['ok'] == (name == 'valid'), result)
            path = out / (name.replace(' ', '-') + '.jsonl')
            write_trace(path, [dict(tick=r['tick'], p=r['post']['p'], yaw=r['post']['yaw'], **r['game']) for r in rows])
            result = pr.shipped_trace_match(path, reference)
            check('shipped comparison ' + name, result['ok'] == (name == 'valid'), result)
    if not args.only or 'source' in args.only:
        plan = dict(version=2, expanded=True, physics_hz=128, duration_ticks=3, events=[])
        tape = out / 'tape.json'
        tape.write_text(json.dumps(plan))
        route = dict(name='boundary', map='practice', preset='server128', tape=str(tape))
        report = dict(rate=dict(ok=True), delivery=dict(ok=True), order=dict(ok=True), cleanup=dict(clean=True),
                      integrity_flags=[], neutral=True, end='completed')
        for name in ['valid', 'delivery', 'script error', 'order', 'cleanup', 'integrity', 'external']:
            altered = copy.deepcopy(report)
            log = 'SCRIPT ERROR: controlled negative' if name == 'script error' else ''
            if name in ('delivery', 'order'): altered[name]['ok'] = False
            if name == 'cleanup': altered['cleanup']['clean'] = False
            if name == 'integrity': altered['integrity_flags'] = ['controlled false velocity']
            requested = dict(route)
            if name == 'external':
                wrong = copy.deepcopy(good); wrong[1]['post']['p'][0] += 1
                target = out / 'wrong-reference.jsonl.gz'; write_trace(target, wrong)
                requested['reference'] = str(target)
            def child(cmd, cwd, env, logfile, deadline, **kwargs):
                if 'expand' in cmd: return 0, json.dumps(plan)
                run = Path(cmd[cmd.index('--out')+1]) / 'evaluator'; run.mkdir(parents=True)
                write_trace(run / 'trace.jsonl', good)
                (run / 'report.json').write_text(json.dumps(altered))
                Path(logfile).write_text(log)
                return 0, log
            accepted = True
            with patch.object(pr, 'run_engine', child):
                try: pr.source_route(requested, PROJECT, out / ('source-' + name.replace(' ', '-')))
                except pr.Rejected: accepted = False
            check('source boundary ' + name, accepted == (name == 'valid'))
    if not args.only or 'godot' in args.only:
        gd = out / 'godot'; gd.mkdir()
        (gd / 'project.godot').write_text('config_version=5\n[application]\nconfig/name="r14 verifier regression"\n')
        write_trace(gd / 'reference.jsonl', good)
        script = '''extends SceneTree
class FakeGame:
    extends Node
    var hud: Node
    var preset := {"slot": 2, "label": "CS:GO bhop server", "air": "AA 100"}
    var physics_hz := 128
    var rate_ok := true
    func map_name() -> String:
        return "Penstock Yard"
func _initialize() -> void:
    var probe: Node = load(PROBE).new()
    var rows: Array = []
    for i: int in 3:
        rows.append({"tick": i, "p": [float(i), 2.0, 3.0], "yaw": 0.0, "pre_p": [0.0, 0.0, 0.0],
            "checkpoint": i, "elapsed": float(i), "finished": i == 2, "finish_kind": "clean" if i == 2 else "", "respawns": 0})
    for bad: bool in [false, true]:
        probe.set("checks", []); probe.set("report", {})
        probe.set("trace", [rows[0], rows[0], rows[0]] if bad else rows)
        probe.call("_compare_reference", REFERENCE)
        var accepted: bool = (probe.get("checks") as Array).all(func(c: Dictionary) -> bool: return bool(c.ok))
        print("REGRESSION ", JSON.stringify({"name": "gdscript duplicate" if bad else "gdscript valid", "ok": accepted != bad}))
    var broken := rows.duplicate(true)
    broken[0].p = [0.0]
    print("REGRESSION ", JSON.stringify({"name": "gdscript truncated vector", "ok": not probe.call("_trace_valid", broken, true)}))
    broken = rows.duplicate(true); broken[0].yaw = NAN
    print("REGRESSION ", JSON.stringify({"name": "gdscript nonfinite yaw", "ok": not probe.call("_trace_valid", broken, true)}))
    var hud: Node = load(HUD_PATH).new()
    var fake := FakeGame.new(); fake.hud = hud; hud.set("game", fake)
    var identity := Label.new(); identity.text = hud.call("identity_text"); identity.hide()
    hud.add_child(identity); hud.set("identity", identity)
    probe.set("game", fake); probe.set("expect", {"hud_forbidden": []}); probe.set("checks", [])
    probe.call("_check_hud_words", "hidden or absent")
    var hidden_ok: bool = (probe.get("checks") as Array).any(func(c: Dictionary) -> bool: return str(c.name).ends_with("HUD identity") and not c.ok)
    var absent_ok: bool = (probe.get("checks") as Array).any(func(c: Dictionary) -> bool: return str(c.name).ends_with("HUD strafe_last") and not c.ok)
    print("REGRESSION ", JSON.stringify({"name": "hidden identity rejected", "ok": hidden_ok}))
    print("REGRESSION ", JSON.stringify({"name": "absent jump label rejected", "ok": absent_ok}))
    hud.free(); fake.free()
    probe.free(); quit(0)
'''.replace('PROBE', json.dumps(str(PROJECT/'tools/r14-pack-probe.gd'))).replace('REFERENCE', json.dumps(str(gd/'reference.jsonl'))).replace('HUD_PATH', json.dumps(str(PROJECT/'scripts/r14_hud.gd')))
        (gd / 'test.gd').write_text(script)
        code, text = pr.run_engine([pr.EDITOR, '--headless', '--path', gd, '--script', gd/'test.gd'], gd,
                                   pr.engine_env(gd/'profile'), gd/'engine.log', 30)
        check('actual GDScript controls execute without errors', code == 0 and not pr.ERRORS.search(text))
        records = [json.loads(line[11:]) for line in text.splitlines() if line.startswith('REGRESSION ')]
        check('all GDScript controls reported', len(records) == 6)
        for row in records: check(row['name'], row['ok'])
    if not args.only or 'cancel' in args.only:
        for sig in (signal.SIGTERM, signal.SIGINT):
            folder = out / sig.name; folder.mkdir()
            pidfile = folder / 'sleeper.pid'
            sleeper = folder / 'godot-sleeper.py'
            sleeper.write_text('#!/usr/bin/env python3\nimport os,pathlib,time\npathlib.Path('+repr(str(pidfile))+').write_text(str(os.getpid()))\ntime.sleep(60)\n')
            sleeper.chmod(0o700)
            env = dict(os.environ, GODOT=str(sleeper))
            child = None
            with open(folder/'wrapper.log', 'wb') as log:
                wrapper = subprocess.Popen(['bash', str(PROJECT/'tools/check-r14.sh'), '--source', 'worktree', '--out', str(folder/'run')],
                                           cwd=PROJECT, env=env, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
                try:
                    deadline = time.monotonic()+10
                    while not pidfile.exists() and wrapper.poll() is None and time.monotonic() < deadline: time.sleep(.02)
                    check(sig.name + ': actual wrapper reached owned child', pidfile.exists())
                    if pidfile.exists():
                        child = int(pidfile.read_text()); os.kill(wrapper.pid, sig)
                        status = wrapper.wait(15)
                        check(sig.name + ': wrapper exits cancellation status', status == 130, status)
                        check(sig.name + ': no child remains', not Path('/proc/%d'%child).exists())
                finally:
                    for pid in (wrapper.pid, child):
                        if pid:
                            try: os.killpg(pid, signal.SIGKILL)
                            except ProcessLookupError: pass
                    wrapper.wait(5)
            shutil.rmtree(folder/'run/source', ignore_errors=True)
    pr.compress_evidence(out)
    (out/'SUMMARY.json').write_text(json.dumps(checks, indent=2, allow_nan=False)+'\n')
    raise SystemExit(1 if any(not c['ok'] for c in checks) else 0)


if __name__ == '__main__':
    main()
