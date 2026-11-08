#!/usr/bin/env python3
"""bounded observational review; a reproduced false acceptance is not a green gate."""
import argparse
import copy
import gzip
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import sys
import zipfile
from unittest.mock import patch

sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('closure_pack', PROJECT / 'tools/package-r14.py')
pr = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pr)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--candidate', type=Path, required=True)
    parser.add_argument('--source-final', type=Path, required=True)
    args = parser.parse_args()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    if any(out.iterdir()):
        raise SystemExit('use a fresh output directory')
    results = []

    def record(name, **detail):
        row = dict(name=name, **detail)
        results.append(row)
        print(json.dumps(row, allow_nan=False), flush=True)

    good = [dict(phase='tape', tick=i, pre=dict(p=[0., 0., 0.], tape_step_count=8+i),
                 post=dict(p=[float(i), 2., 3.], yaw=0.),
                 game=dict(checkpoint=i, elapsed=float(i), finished=i == 2,
                           finish_kind='clean' if i == 2 else '', respawns=0)) for i in range(3)]
    plan = dict(version=2, expanded=True, physics_hz=128, duration_ticks=3, events=[])
    tape = out / 'tape.json'
    tape.write_text(json.dumps(plan))
    report = dict(rate=dict(ok=True), delivery=dict(ok=True), order=dict(ok=True), cleanup=dict(clean=True),
                  integrity_flags=[], neutral=True, end='completed')
    for name in ['valid', 'evaluator-log-error', 'missing-evaluator-log', 'rate-false', 'neutral-false', 'end-failed']:
        altered = copy.deepcopy(report)
        if name == 'rate-false':
            altered['rate']['ok'] = False
        if name == 'neutral-false':
            altered['neutral'] = False
        if name == 'end-failed':
            altered['end'] = 'deadline'

        def child(cmd, cwd, env, logfile, deadline, **kwargs):
            if 'expand' in cmd:
                return 0, json.dumps(plan)
            run = Path(cmd[cmd.index('--out')+1]) / 'evaluator'
            run.mkdir(parents=True)
            (run / 'trace.jsonl').write_text(''.join(json.dumps(r)+'\n' for r in good))
            (run / 'report.json').write_text(json.dumps(altered))
            if name != 'missing-evaluator-log':
                (run / 'godot.log').write_text('SCRIPT ERROR: controlled evaluator error\n' if name == 'evaluator-log-error' else '')
            text = json.dumps(dict(end=altered['end'], delivery_ok=True, rate_ok=altered['rate']['ok']))
            Path(logfile).write_text(text)
            return 0, text

        route = dict(name=name, map='practice', preset='server128', tape=str(tape))
        accepted, error = True, None
        with patch.object(pr, 'run_engine', child):
            try:
                pr.source_route(route, PROJECT, out / name)
            except pr.Rejected as exc:
                accepted, error = False, str(exc)
        record('source boundary ' + name, accepted=accepted, error=error,
               scope='actual source_route; controlled tape supervisor boundary')

    # use the actual godot functions, with in-tree labels but no native renderer or game.
    gd = out / 'godot'
    gd.mkdir()
    (gd / 'project.godot').write_text('config_version=5\n[application]\nconfig/name="closure review"\n')
    (gd / 'probe-shim.gd').write_text('extends ' + json.dumps(str(PROJECT / 'tools/r14-pack-probe.gd')) + '\nfunc _ready() -> void:\n\tpass\n')
    script = '''extends SceneTree
class FakeHud:
    extends Node
    var identity: Label
    var speed_label: Label
    var speed_unit: Label
    var strafe_live: Label
    var strafe_last: Label
    var strafe_split: Label
    var strafe_chain: Label
class FakeGame:
    extends Node
    var hud: Node
    var preset := {"slot": 2, "label": "CS:GO bhop server", "air": "AA 100"}
    var physics_hz := 128
    func map_name() -> String:
        return "Penstock Yard"
func emit_result(name: String, accepted: bool) -> void:
    print("CLOSURE ", JSON.stringify({"name": name, "accepted": accepted}))
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    root.size = Vector2i(1280, 720)
    var probe: Node = load(@PROBE@).new()
    root.add_child(probe)
    # the shim disables normal startup and retains every tested production method.
    var hud := FakeHud.new()
    root.add_child(hud)
    var fake := FakeGame.new()
    fake.hud = hud
    root.add_child(fake)
    probe.set("game", fake)
    probe.set("expect", {"hud_forbidden": []})
    var fields := ["identity", "speed_label", "speed_unit", "strafe_live", "strafe_last", "strafe_split", "strafe_chain"]
    for field: String in fields:
        var label := Label.new()
        label.text = "PENSTOCK YARD · F2 CS:GO bhop server · 128 Hz · AA 100" if field == "identity" else "sample"
        label.size = Vector2(16, 16)
        hud.add_child(label)
        hud.set(field, label)
    await process_frame
    for mode: String in ["visible", "hidden", "zero-modulate", "zero-font-alpha", "zero-visible-characters", "offscreen"]:
        for field: String in fields:
            var label: Label = hud.get(field)
            label.visible = mode != "hidden"
            label.modulate.a = 0.0 if mode == "zero-modulate" else 1.0
            label.add_theme_color_override("font_color", Color(1, 1, 1, 0 if mode == "zero-font-alpha" else 1))
            label.visible_characters = 0 if mode == "zero-visible-characters" else -1
            label.position = Vector2(10000, 10000) if mode == "offscreen" else Vector2.ZERO
        probe.set("checks", [])
        probe.set("report", {})
        probe.call("_check_hud_words", mode)
        emit_result("HUD " + mode, (probe.get("checks") as Array).all(func(c: Dictionary) -> bool: return bool(c.ok)))
    for value: Variant in [12, 12.0, "12", true, null, [1, 2], [1.0, 2.0], [1, 3], {"0": 1}]:
        var wanted: Variant = [1, 2] if value is Array or value is Dictionary else 12
        emit_result("integer " + str(value) + " type " + str(typeof(value)), probe.call("_same_ticks", value, wanted))
    fake.free()
    hud.free()
    probe.free()
    quit(0)
'''.replace('@PROBE@', json.dumps(str(gd / 'probe-shim.gd')))
    (gd / 'test.gd').write_text(script)
    code, text = pr.run_engine([pr.EDITOR, '--headless', '--path', gd, '--script', gd / 'test.gd'], gd,
                               pr.engine_env(gd / 'profile'), gd / 'engine.log', 30)
    record('headless reduction executes', ok=code == 0 and not pr.ERRORS.search(text), exit=code)
    for line in text.splitlines():
        if line.startswith('CLOSURE '):
            row = json.loads(line[8:])
            record(row.pop('name'), **row)

    candidate = args.candidate.resolve()
    build = json.loads((candidate / 'BUILD.json').read_text())
    verification = json.loads((candidate / 'VERIFICATION.json').read_text())
    hashes = {p.name: pr.digest(p) for p in candidate.iterdir() if p.is_file()}
    inputs = {str(PROJECT / p): pr.digest(PROJECT / p) for p in
              ['tools/package-r14.py', 'tools/check-r14.sh', 'tools/r14-pack-probe.gd', 'tests/test_r14_verifier_hardening.py']}
    (out / 'candidate-hashes.json').write_text(json.dumps(hashes, indent=2)+'\n')
    files, archive = pr.verify_source_manifest(build)
    record('candidate source manifest', files=len(files), archive_sha256=hashlib.sha256(archive).hexdigest())
    record('candidate verification', ok=verification['ok'], checks=len(verification['checks']),
           passes=sum(c['ok'] is True for c in verification['checks']),
           summary_identical=(candidate/'VERIFICATION.json').read_bytes() == (candidate/'evidence/check/summary.json').read_bytes())
    sums = dict(reversed(line.split('  ', 1)) for line in (candidate / 'SHA256SUMS').read_text().splitlines())
    for path in sorted(candidate.glob('*.zip')):
        with zipfile.ZipFile(path) as package:
            bad_member = package.testzip()
            pck = next(n for n in package.namelist() if n.endswith('.pck'))
            embedded = json.loads(package.read(next(n for n in package.namelist() if n.endswith('/BUILD.json'))))
            runtimes = {Path(n).name: hashlib.sha256(package.read(n)).hexdigest() for n in package.namelist()
                        if n.endswith(('.x86_64', '.exe'))}
            record('zip ' + path.name, checksum_ok=hashes[path.name] == sums[path.name], bad_member=bad_member,
                   pack_ok=hashlib.sha256(package.read(pck)).hexdigest() == build['pack_sha256'], runtimes=runtimes,
                   embedded_matches=all(embedded.get(k) == v for k, v in build.items() if k != 'platforms'))
    for item in build['routes']:
        name = item['route']['name']
        folder = candidate / 'evidence/check/runs' / name
        source = candidate / 'evidence/source-routes' / ('route-' + name) / 'source-run/evaluator'
        trace = pr.read_rows(source / 'trace.jsonl.gz')
        source_report = json.loads((source / 'report.json').read_text())
        for path in [source / 'trace.jsonl.gz', source / 'report.json', source / 'godot.log']:
            inputs[str(path)] = pr.digest(path)
        packed_path = folder / 'play/trace.jsonl.gz'
        with gzip.open(packed_path, 'rt') as stream:
            packed = [json.loads(line) for line in stream if line.strip()]
        exact = pr.trace_error(packed, packed=True, expected=item['ticks']) is None and len(trace) == len(packed)
        exact = exact and all(a['tick'] == b['tick'] and a['p'] == b['post']['p'] and a['yaw'] == b['post']['yaw']
                              and all(a[k] == b['game'][k] for k in ['checkpoint', 'elapsed', 'finished', 'finish_kind', 'respawns'])
                              for a, b in zip(packed, trace))
        probes = {mode: json.loads((folder / mode / 'probe.json').read_text()) for mode in ['play', 'reload']}
        cfg_path = folder / 'profile/data/godot/app_userdata/Spillway/spillway_r14.cfg'
        cfg = cfg_path.read_text()
        for path in [packed_path, cfg_path, folder/'play/probe.json', folder/'reload/probe.json']:
            inputs[str(path)] = pr.digest(path)
        ticks = probes['play']['run']['record_ticks']
        expected = dict(clean_best_ticks=ticks['clean_best'], open_best_ticks=ticks['open_best'],
                        clean_split_ticks=ticks['splits'], clean_segment_ticks=ticks['segments'])
        exact_saved = True
        for key, value in expected.items():
            text_value = re.search(r'^' + key + r'=(.*)$', cfg, re.M).group(1)
            if isinstance(value, list):
                exact_saved &= text_value.startswith('Array[int](')
                text_value = text_value.removeprefix('Array[int](').removesuffix(')')
            decoded = json.loads(text_value)
            exact_saved &= decoded == value and (all(type(n) is int for n in decoded) if isinstance(value, list) else type(decoded) is int)
        record('candidate route ' + name, ticks=len(trace), trace_valid=pr.trace_error(trace, expected=item['ticks']) is None,
               packed_exact=exact, source_delivery=source_report['delivery']['ok'], source_order=source_report['order']['ok'],
               source_rate=source_report['rate']['ok'], source_cleanup=source_report['cleanup']['clean'],
               source_log_errors=bool(pr.ERRORS.search((source / 'godot.log').read_text())),
               play_failures=probes['play']['failures'], reload_failures=probes['reload']['failures'],
               probe_checks_all_true=all(c['ok'] is True for probe in probes.values() for c in probe['checks']),
               saved_integer_records_exact=bool(exact_saved),
               hud_checks=sum('visible on-screen HUD' in c['name'] for c in probes['play']['checks']))
    source_final = args.source_final.resolve()
    summary = json.loads((source_final / 'identity-routes/summary.json').read_text())
    for route in summary['routes']:
        # retained paths may have been compressed after the summary was written.
        path = source_final / 'identity-routes/routes' / ('route-' + route['route']['name']) / 'source-run/evaluator/trace.jsonl'
        path = path if path.exists() else path.with_suffix(path.suffix + '.gz')
        result = pr.compare_traces(pr.read_rows(path), pr.read_rows(route['route']['reference']), route['route'].get('game_diff', []))
        for item in [path, Path(route['route']['reference'])]:
            inputs[str(item)] = pr.digest(item)
        record('final source external ' + route['route']['name'], comparison=result)
    (out / 'input-hashes.json').write_text(json.dumps(inputs, indent=2)+'\n')
    pr.compress_evidence(out)
    (out / 'SUMMARY.json').write_text(json.dumps(results, indent=2, allow_nan=False)+'\n')


if __name__ == '__main__':
    main()
