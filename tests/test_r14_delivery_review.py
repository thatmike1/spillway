#!/usr/bin/env python3
"""bounded verifier challenges; malformed acceptance is a finding, not a delivery pass."""
import argparse
import copy
import gzip
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import time
from unittest.mock import patch

sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[1]
module = importlib.util.spec_from_file_location('review_package', PROJECT / 'tools/package-r14.py')
pr = importlib.util.module_from_spec(module)
module.loader.exec_module(pr)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--evidence', type=Path, required=True)
    out = parser.parse_args().evidence.resolve()
    out.mkdir(parents=True, exist_ok=True)
    if any(out.iterdir()):
        raise SystemExit('use new evidence')
    results = []
    def record(name, accepted, detail):
        value = dict(name=name, accepted=bool(accepted), detail=detail)
        results.append(value)
        print(json.dumps(value), flush=True)
    good = [dict(phase='tape', tick=i, pre=dict(p=[0., 0., 0.], tape_step_count=8+i),
                 post=dict(p=[float(i), 2., 3.], yaw=0.),
                 game=dict(checkpoint=i, elapsed=float(i), finished=i == 2,
                           finish_kind='clean' if i == 2 else '', respawns=0)) for i in range(3)]
    ref = out / 'reference.jsonl.gz'
    with gzip.open(ref, 'wt') as stream:
        stream.write(''.join(json.dumps(r, separators=(',', ':'))+'\n' for r in good))
    variants = {'valid': copy.deepcopy(good), 'duplicate ticks': [good[0]]*3,
                'disjoint ticks': [{**copy.deepcopy(r), 'tick': r['tick']+100} for r in good],
                'reversed chronology': list(reversed(good)), 'short coordinates': copy.deepcopy(good),
                'nan position and yaw': copy.deepcopy(good), 'wrong finite position': copy.deepcopy(good)}
    for r in variants['short coordinates']:
        r['post']['p'] = [r['post']['p'][0]]
    for r in variants['nan position and yaw']:
        r['post'].update(p=[float('nan')]*3, yaw=float('nan'))
    variants['wrong finite position'][1]['post']['p'][1] += 1.
    for name, rows in variants.items():
        value = pr.compare_traces(rows, good)
        record('executor '+name, value['ok'], value)
        path = out / ('packed-'+name.replace(' ', '-')+'.jsonl')
        path.write_text(''.join(json.dumps(dict(tick=r['tick'], p=r['post']['p'], yaw=r['post']['yaw'], **r['game']))+'\n' for r in rows))
        value = pr.shipped_trace_match(path, ref)
        record('shipped '+name, value['ok'], value)
    value = pr.compare_traces([], [])
    record('executor empty pair', value['ok'], value)
    tape = out / 'tiny.tape.json'
    plan = dict(version=2, expanded=True, physics_hz=128, duration_ticks=3, events=[])
    tape.write_text(json.dumps(plan))
    route = dict(name='controlled', map='practice', preset='server128', tape=str(tape))
    for name, delivery, log_error in [('valid', True, ''), ('undelivered input', False, ''),
                                      ('engine error', True, 'SCRIPT ERROR: controlled challenge')]:
        def child(cmd, cwd, env, log, deadline, **kwargs):
            if 'expand' in cmd:
                return 0, json.dumps(plan)
            run = Path(cmd[cmd.index('--out')+1]) / 'evaluator'
            run.mkdir(parents=True)
            (run/'trace.jsonl').write_text(''.join(json.dumps(r, separators=(',', ':'))+'\n' for r in good))
            (run/'report.json').write_text(json.dumps(dict(rate=dict(ok=True), delivery=dict(ok=delivery))))
            Path(log).write_text(log_error)
            return 0, log_error
        with patch.object(pr, 'run_engine', child):
            value = pr.source_route(route, PROJECT, out/('source-'+name.replace(' ', '-')))
        record('source_route '+name, True, dict(delivery_ok=value['delivery_ok'], exit=value['exit']))
    # a requested external reference is attached as a failing result, not rejected here.
    wrong_ref = out/'wrong-reference.jsonl.gz'
    wrong = copy.deepcopy(good)
    wrong[1]['post']['p'][1] += 1.
    with gzip.open(wrong_ref, 'wt') as stream:
        stream.write(''.join(json.dumps(r, separators=(',', ':'))+'\n' for r in wrong))
    delivery, log_error = True, ''
    with patch.object(pr, 'run_engine', child):
        value = pr.source_route(dict(route, reference=str(wrong_ref)), PROJECT, out/'source-external-mismatch')
    record('source_route external mismatch returned', True, value['external_reference'])
    source_stub = out/'source-stub'
    source_stub.mkdir()
    frozen = {'start': {'map': 'practice'}, 'registry': {}, 'keys': {'practice': {'server128':
              {'physics_hz': 128, 'course_key': '0123456789abcdef', 'runner_chain': ['res://scripts/r14_source_player.gd']}}}}
    for name, delivery, log_error in [('undelivered input', False, ''), ('engine error', True, 'SCRIPT ERROR: controlled challenge')]:
        settings = argparse.Namespace(source=source_stub, evidence=out/('source-mode-'+name.replace(' ', '-')), route=[route])
        with patch.object(pr, 'run_engine', child), patch.object(pr, 'source_identity', return_value=frozen):
            accepted = pr.source_mode(settings)
        record('source_mode '+name, accepted, 'actual source_mode and source_route; identity and child boundary controlled')
    # the actual probe comparator and integer validator run without a game or renderer.
    gd = out/'godot'
    gd.mkdir()
    (gd/'project.godot').write_text('config_version=5\n[application]\nconfig/name="isolated delivery review"\n')
    (gd/'reference.jsonl').write_text(''.join(json.dumps(r, separators=(',', ':'))+'\n' for r in good))
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
    var source: Script = load(PROBE)
    var probe: Node = source.new()
    var rows: Array = []
    for i: int in 3:
        rows.append({"tick": i, "p": [float(i), 2.0, 3.0], "yaw": 0.0, "pre_p": [0.0, 0.0, 0.0],
            "checkpoint": i, "elapsed": float(i), "finished": i == 2, "respawns": 0})
    for name: String in ["valid", "duplicate ticks"]:
        probe.set("checks", [])
        probe.set("report", {})
        probe.set("trace", rows if name == "valid" else [rows[0], rows[0], rows[0]])
        probe.call("_compare_reference", REFERENCE)
        print("REVIEW ", JSON.stringify({"name": name, "checks": probe.get("checks")}))
    for value: Variant in [12, 12.0, "12", -1, null, [1, 2], [1.0, 2.0], {"0": 1}]:
        var wanted: Variant = [1, 2] if value is Array or value is Dictionary else 12
        print("TICKS ", JSON.stringify({"value": value, "type": typeof(value), "accepted": probe.call("_same_ticks", value, wanted)}))
    var hud_source: Script = load(HUD)
    var hud: Node = hud_source.new()
    var fake := FakeGame.new()
    fake.hud = hud
    hud.set("game", fake)
    var identity := Label.new()
    identity.text = hud.call("identity_text")
    identity.visible = false
    hud.add_child(identity)
    hud.set("identity", identity)
    probe.set("game", fake)
    probe.set("expect", {"hud_forbidden": ["R12", "debug", "surf"]})
    probe.set("checks", [])
    probe.call("_check_hud_words", "hidden identity and absent jump/sync labels")
    print("REVIEW ", JSON.stringify({"name": "hidden identity and absent jump/sync labels", "checks": probe.get("checks")}))
    hud.free()
    fake.free()
    probe.free()
    quit(0)
'''.replace('PROBE', json.dumps(str(PROJECT/'tools/r14-pack-probe.gd'))).replace('REFERENCE', json.dumps(str(gd/'reference.jsonl'))).replace('HUD', json.dumps(str(PROJECT/'scripts/r14_hud.gd')))
    (gd/'review.gd').write_text(script)
    code, text = pr.run_engine([pr.EDITOR, '--headless', '--path', gd, '--script', gd/'review.gd'], gd,
                               pr.engine_env(gd/'isolated-profile'), gd/'engine.log', 30)
    record('headless probe executes', code == 0 and not pr.ERRORS.search(text), dict(exit=code))
    for line in text.splitlines():
        if line.startswith('REVIEW '):
            value = json.loads(line[7:])
            record('gdscript '+value['name'], all(c['ok'] for c in value['checks']), value)
        elif line.startswith('TICKS '):
            value = json.loads(line[6:])
            record('gdscript integer payload', value['accepted'], value)
    # interrupt only our reduced production function, in an owned process session.
    body = re.search(r'^run_clean\(\) \{\n.*?^\}', (PROJECT/'tools/check-r14.sh').read_text(), re.M|re.S).group()
    sleeper = out/'owned-sleeper.py'
    pid_file = out/'owned-sleeper.pid'
    sleeper.write_text('#!/usr/bin/env python3\nimport os,pathlib,time\npathlib.Path('+repr(str(pid_file))+').write_text(str(os.getpid()))\ntime.sleep(60)\n')
    sleeper.chmod(0o700)
    shell = 'set -euo pipefail\n'+body+'\nout="$1"; src="$1"; GODOT="$2"; results=(); run_clean owned owned\n'
    parent = subprocess.Popen(['bash', '-c', shell, 'review', str(out), str(sleeper)], start_new_session=True,
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    survivor = None
    try:
        deadline = time.monotonic()+3
        while not pid_file.exists() and time.monotonic() < deadline:
            time.sleep(0.02)
        if not pid_file.exists():
            raise RuntimeError('sleeper never started')
        pid = int(pid_file.read_text())
        os.kill(parent.pid, signal.SIGTERM)
        status = parent.wait(3)
        try:
            os.kill(pid, 0)
            survivor = pid
        except ProcessLookupError:
            pass
        record('source shell child survives SIGTERM', survivor is not None, dict(parent_exit=status, child_pid=pid))
    finally:
        try:
            os.killpg(parent.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        parent.wait(3)
        if survivor is not None:
            for _ in range(50):
                stat = Path('/proc/%d/stat'%survivor)
                if not stat.exists() or stat.read_text().split()[2] == 'Z':
                    break
                time.sleep(0.02)
            stat = Path('/proc/%d/stat'%survivor)
            record('sleeper cleaned', not stat.exists() or stat.read_text().split()[2] == 'Z', dict(pid=survivor))
    pr.compress_evidence(out)
    sources = {str(p.relative_to(PROJECT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in
               [PROJECT/'tools/package-r14.py', PROJECT/'tools/r14-pack-probe.gd', PROJECT/'tools/check-r14.sh',
                PROJECT/'docs/r14/DELIVERY.md', Path(__file__)]}
    (out/'review-summary.json').write_text(json.dumps(dict(commit=pr.git('rev-parse', 'HEAD').strip(), sources=sources, results=results), indent=2, allow_nan=False)+'\n')


if __name__ == '__main__':
    main()
