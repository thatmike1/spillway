#!/usr/bin/env python3
"""isolated headless input-only R16 whole-run bots and standard executor replays."""
import argparse
import gzip
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[1]
ENGINE = Path.home() / '.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64'
ENGINE_SHA = '8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e'
CAP = 300 * 2**20


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def size(path):
    return sum(p.stat().st_size for p in path.rglob('*') if p.is_file())


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', required=True, type=Path)
    parser.add_argument('--route', choices=['whiteout-apron', 'lab-flow'], required=True)
    parser.add_argument('--replay', action='store_true')
    parser.add_argument('--expect-head', help='refuse a final freeze from another commit')
    parser.add_argument('--max-ticks', type=int, default=24000)
    args = parser.parse_args()
    out = args.out.resolve()
    assert not out.is_relative_to(PROJECT)
    out.mkdir(parents=True, exist_ok=False)
    assert sha(ENGINE) == ENGINE_SHA
    head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=PROJECT, text=True).strip()
    if args.expect_head:
        assert head.startswith(args.expect_head), (head, args.expect_head)
    work = Path(tempfile.mkdtemp(prefix='r16-player-routes-', dir='/dev/shm'))
    source = work / 'source'
    source.mkdir()
    tracked = [Path(os.fsdecode(p)) for p in subprocess.check_output(['git', 'ls-files', '-z', '--', '.'], cwd=PROJECT).split(b'\0') if p]
    extras = [p.relative_to(PROJECT) for p in (PROJECT / 'tests').glob('r16_player_routes*') if p.is_file()]
    files = sorted(set(tracked + extras))
    hashes = {str(rel): sha(PROJECT / rel) for rel in files}
    receipt = {'head': head,
               'engine_sha256': ENGINE_SHA, 'source_sha256': hashes, 'commands': [], 'scratch_cap_bytes': CAP,
               'label': 'coordinate-aware bots; production R16 normal spawns; headless only'}
    try:
        for rel in files:
            dst = source / rel
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(PROJECT / rel, dst)
        assert all(sha(source / rel) == digest for rel, digest in hashes.items()), 'source changed during freeze'
        package = load(source / 'tools/package-r16.py', 'player_routes_package')
        env = package.engine_env(work / 'profile')

        def run(name, argv, budget=180):
            receipt['commands'].append(argv)
            code, text = package.run_engine(argv, source, env, out / (name + '.log'), budget)
            receipt['peak_checked_scratch_bytes'] = max(receipt.get('peak_checked_scratch_bytes', 0), size(work))
            assert size(work) <= CAP, ('RAM cap', size(work))
            if code or package.ERRORS.search(text):
                raise RuntimeError((name, code, text[-5000:]))
            print(text[-1800:], flush=True)

        run('import', [str(ENGINE), '--headless', '--audio-driver', 'Dummy', '--path', str(source), '--editor', '--import', '--quit'])
        for rel in extras:
            uid = source / (str(rel) + '.uid')
            if rel.suffix == '.gd' and uid.exists() and not (PROJECT / (str(rel) + '.uid')).exists():
                shutil.copy2(uid, PROJECT / (str(rel) + '.uid'))
        base = [str(ENGINE), '--headless', '--audio-driver', 'Dummy', '--fixed-fps', '128', '--path', str(source)]
        driver = out / 'driver'
        run('driver', base + ['--script', 'res://tests/r16_player_routes.gd', '--', '--out=' + str(driver),
                            '--route=' + args.route, '--max-ticks=' + str(args.max_ticks)])
        summary = json.loads((driver / 'summary.json').read_text())
        receipt['driver'] = {k: summary[k] for k in ['finished', 'finish_kind', 'elapsed', 'respawns', 'phase', 'style_summary', 'style_best', 'checkpoints']}
        tape = json.loads((driver / 'events.tape.json').read_text())
        tape_tool = load(source / 'tools/momentum-tape.py', 'player_routes_tape')
        expanded = tape_tool.expand(tape)
        receipt['strict_tape'] = {'ok': True, 'ticks': tape['duration_ticks'], 'events': len(tape['events']),
                                  'integer_counts': all(all(float(v).is_integer() for v in e['mouse']) for e in tape['events'] if 'mouse' in e)}
        if args.replay and summary['finished']:
            runtime = work / 'executor'
            map_id = 'experiment' if args.route == 'lab-flow' else 'whiteout-relay'
            adapter = out / 'replay-game.gd'
            adapter.write_text('\n'.join([
                'extends "res://scripts/r16_main.gd"',
                '## setup only, actual r16 host and automatic runner selection; no gameplay override.',
                'func _init() -> void:',
                '\tmap_id = ' + json.dumps(map_id),
                '\tseed_from_r15 = false',
                '\tsource_sensitivity_override = 2.5',
                '\trecordings_dir = ' + json.dumps(str(out / 'executor-recordings')),
                '\trecord_runs = true',
                '\tpersist = true',
                '\tprofile_path = ' + json.dumps(str(out / 'executor-profile.cfg')),
                '']))
            receipt['replay_adapter_sha256'] = sha(adapter)
            command = [sys.executable, '-I', str(source / 'tools/momentum-tape.py'), 'run', str(driver / 'events.tape.json'),
                       '--out', str(runtime), '--headless', '--render-fps', '128', '--warmup', '33', '--wall-budget', '160',
                       '--game-script', str(adapter), '--game-class', '', '--motor', 'server128']
            run('executor', command, budget=220)
            report = json.loads((runtime / 'evaluator/report.json').read_text())
            assert not package.ERRORS.search((runtime / 'evaluator/godot.log').read_text())
            receipt['executor_report'] = report
            (out / 'executor-report.json').write_text(json.dumps(report, indent=1))
            expected = [json.loads(line) for line in gzip.open(driver / 'trace.jsonl.gz', 'rt')]
            actual = [json.loads(line) for line in (runtime / 'evaluator/trace.jsonl').open() if line.strip()]
            actual_tape = [r for r in actual if r['phase'] == 'tape']
            fields = ['p', 'v', 'yaw', 'pitch', 'grounded']
            differences = []
            for a, b in zip(actual_tape, expected):
                mismatch = [key for key in fields if a['post'][key] != b[key]]
                if a['post']['motion_state'] != b['motion']:
                    mismatch.append('motion')
                for key, name in [('checkpoint', 'checkpoint'), ('elapsed', 'elapsed'), ('finished', 'finished'), ('respawns', 'respawns')]:
                    if a['game'][key] != b[name]:
                        mismatch.append(key)
                if mismatch:
                    differences.append({'tick': b['tick'], 'fields': mismatch})
            loop_checks = load(source / 'tests/test_r16_loop_tapes.py', 'player_routes_loop')
            receipt['recording_alignment'] = loop_checks.check_recordings(out / 'executor-recordings', actual_tape, source)
            receipt['parity'] = {'driver_ticks': len(expected), 'executor_ticks': len(actual_tape), 'compared_ticks': min(len(expected), len(actual_tape)),
                                 'differences': differences[:20], 'difference_count': len(differences), 'last_game': actual_tape[-1]['game']}
            dest = out / 'executor'
            dest.mkdir()
            with gzip.open(dest / 'trace.jsonl.gz', 'wb') as zipped:
                zipped.write((runtime / 'evaluator/trace.jsonl').read_bytes())
            for rel in ['end.json', 'evaluator/engine.json', 'evaluator/plan.json', 'evaluator/report.json', 'evaluator/godot.log']:
                if (runtime / rel).exists():
                    shutil.copy2(runtime / rel, dest / Path(rel).name)
            shutil.rmtree(runtime)
        analyzer = load(source / 'tools/analyze-r16-runs.py', 'player_routes_analyzer')
        receipt['cross_readers'] = []
        for directory in [driver / 'recordings', out / 'executor-recordings']:
            if not directory.exists():
                continue
            decoded_path = out / (directory.parent.name + '-godot-decode.json.gz')
            run(directory.parent.name + '-reader', base + ['--script', 'res://tests/r16_player_routes_read.gd', '--',
                                                           '--directory=' + str(directory), '--out=' + str(decoded_path)])
            decoded = json.loads(gzip.decompress(decoded_path.read_bytes()))
            for report in decoded:
                rec = analyzer.read(Path(report['path']))
                columns = {}
                for key, value in report['columns'].items():
                    if key in analyzer.VECTORS:
                        for axis, suffix in enumerate('xyz'):
                            columns[key + '_' + suffix] = [row[axis] for row in value]
                    else:
                        columns[key] = value
                cross = {'path': report['path'], 'python_ok': rec.ok, 'godot_ok': report['ok'],
                         'columns_equal': columns == rec.columns, 'inputs_equal': report['inputs'] == rec.inputs,
                         'events_json': json_agreement(report['events'], rec.events), 'seal_json': json_agreement(report['seal'], rec.seal),
                         'clean_finish': report['clean_finish'], 'ghost_load': report['ghost_load'],
                         'ghost_pose_checks': report['ghost_pose_checks'], 'ghost_pose_failures': report['ghost_pose_failures'],
                         'fastest': report['fastest']}
                receipt['cross_readers'].append(cross)
        reports = []
        for path in sorted(out.rglob('*.r16run')):
            rec = analyzer.read(path)
            reports.append(analyzer.analyse(rec, 0.75))
        (out / 'analysis.json').write_text(json.dumps(reports, indent=1))
        subprocess.run([sys.executable, '-I', str(source / 'tools/analyze-r16-runs.py'), str(out),
                        '--json', str(out / 'folder-analysis.json'), '--strict', '--quiet'], check=True, env=env)
        checks = {'driver_clean': summary['finished'] and summary['finish_kind'] == 'clean' and summary['respawns'] == 0,
                  'ordered_checkpoints': [row['checkpoint'] for row in summary['checkpoints']] == list(range(len(summary['stage_times']))),
                  'style_best': summary['style_best'] == summary['style_summary']['score'] == summary['finish_style'].get('score'),
                  'fastest_ghost': summary['fastest']['ok'] and summary['ghost_pointer']['path'] == summary['fastest']['path'] and
                                   summary['ghost_ticks'] == summary['ghost_pointer']['ticks'] == round(summary['elapsed'] * 128),
                  'saved_bests': summary['saved_profile']['load_error'] == 0 and summary['saved_profile']['style_best'] == summary['style_best'] and
                                 summary['saved_profile']['time_ticks'] == round(summary['best_time'] * 128) == round(summary['elapsed'] * 128) and
                                 summary['saved_profile']['ghost_ticks'] == summary['ghost_ticks'] and
                                 summary['saved_profile']['ghost_path'] == summary['ghost_pointer']['path'] and
                                 json.loads(summary['saved_profile']['style_identity']) == summary['style_summary']['identity'],
                  'actual_travel': summary['actual_v_mismatches'] == 0,
                  'integer_tape': receipt['strict_tape']['integer_counts'],
                  'cross_readers': all(r['python_ok'] and r['godot_ok'] and r['columns_equal'] and r['inputs_equal'] and
                                       r['events_json']['ok'] and r['seal_json']['ok'] and r['clean_finish']['ok'] and r['ghost_load']['ok'] and
                                       not r['ghost_pose_failures'] and r['ghost_pose_checks'] > 0 for r in receipt['cross_readers'])}
        if args.replay and summary['finished']:
            checks.update({'tick_parity': receipt['parity']['difference_count'] == 0 and
                                          receipt['parity']['driver_ticks'] == receipt['parity']['executor_ticks'] == tape['duration_ticks'],
                           'recorded_alignment': receipt['recording_alignment']['ok'],
                           'executor_clean': report_clean(receipt['executor_report'])})
        driver_rows = [json.loads(line) for line in gzip.open(driver / 'trace.jsonl.gz', 'rt')]
        semantics = whole_run_checks(args.route, summary, driver_rows, tape)
        receipt['whole_run'] = semantics
        checks.update(semantics['checks'])
        receipt['checks'] = checks
        receipt['ok'] = all(checks.values())
        receipt['analysis_files'] = len(reports)
        receipt['source_unchanged_at_end'] = {rel: (PROJECT / rel).exists() and sha(PROJECT / rel) == digest for rel, digest in hashes.items()}
    except Exception as error:
        receipt['error'] = repr(error)
        raise
    finally:
        receipt['scratch_removed'] = True
        shutil.rmtree(work)
        (out / 'RESULTS.json').write_text(json.dumps(receipt, indent=1))
    print(json.dumps({'checks': receipt.get('checks'), 'parity': receipt.get('parity'), 'driver': receipt.get('driver')}, indent=1))
    return 0 if receipt.get('ok') else 1


def json_agreement(left, right):
    """binary columns stay exact; Godot's JSON number parse/print can differ by one ulp."""
    worst = 0.0
    failures = []

    def visit(a, b, path=''):
        nonlocal worst
        if isinstance(a, dict) and isinstance(b, dict) and a.keys() == b.keys():
            for key in a:
                visit(a[key], b[key], path + '/' + str(key))
        elif isinstance(a, list) and isinstance(b, list) and len(a) == len(b):
            for index, (x, y) in enumerate(zip(a, b)):
                visit(x, y, path + '/' + str(index))
        elif type(a) in (int, float) and type(b) in (int, float):
            delta = abs(a - b)
            worst = max(worst, delta)
            if not math.isfinite(delta) or delta > 1e-12:
                failures.append(path)
        elif a != b:
            failures.append(path)
    visit(left, right)
    return {'ok': not failures, 'absolute_tolerance': 1e-12, 'worst_absolute_difference': worst, 'failures': failures[:10]}


def whole_run_checks(route, summary, rows, tape):
    recordings = summary['recordings']
    style = [e['d'] for rec in recordings for e in rec['events'] if e['k'] == 'style']
    checks = {'production_host': not summary['standin'] and summary['runner'] ==
              ('res://scripts/r16_experiment_player.gd' if route == 'lab-flow' else 'res://scripts/r15_source_player.gd'),
              'valid_driver_record': len(recordings) == 1 and recordings[0]['ok'] and recordings[0]['clean_finish']['ok'],
              'source_style_sum': sum(e['points'] for e in style) == summary['style_summary']['score'] ==
                                  recordings[0]['seal']['outcome']['style']['score']}
    if route == 'whiteout-apron':
        saves = [e for e in style if e['kind'] == 'crouch_save' and e['m']['airborne'] and e['points'] >= 900 and
                 'R16Opportunities/ApronCrouch/' in e['geo']['obstacle']['path'] and not e['m']['duck_contact']]
        checks['airborne_apron_save'] = len(saves) == 1
        return {'checks': checks, 'crouch_save_events': saves}
    slide = [r for r in rows if 'slide_landing' in r['motion']['experiment']['events']]
    kicks = [r for r in rows if 'wall_jump' in r['motion']['experiment']['events']]
    grapple = [r for r in rows if 'grapple' in r['motion']['experiment']['events']]
    phases = {p['phase']: p['tick'] for p in summary['phases']}
    fresh = phases.get('fresh hop', -1)
    release = phases.get('space released', -1)
    checks['bhop_landing_slide'] = (len(slide) == 1 and slide[0]['stats']['hops'] >= 2 and
                                   slide[0]['motion']['experiment']['slide']['kind'] == 'landing' and
                                   slide[0]['motion']['experiment']['slide']['last_landing']['space_held'] and
                                   slide[0]['motion']['experiment']['slide']['held_space_ignored'] and
                                   {'space', 'shift'} <= set(slide[0]['held']))
    checks['fresh_space_hop'] = (release >= 0 and fresh == release + 1 and 'space' not in rows[release]['held'] and
                                 'space' in rows[fresh]['held'] and 'jump' in rows[fresh]['motion']['events'])
    air_start = phases.get('strafe hop to west face', -1)
    air_end = phases.get('west kick A held', -1)
    air_rows = rows[air_start + 1:air_end]
    earned = sum(r['motion']['air_gain_u'] for r in air_rows)
    checks['earned_ad_flight'] = (air_start >= 0 and air_end > air_start and earned > 8.0 and
                                  all('a' in r['held'] and 'w' not in r['held'] and not r['grounded'] for r in air_rows))
    checks['held_ad_kicks'] = (len(kicks) == 2 and 'a' in kicks[0]['held'] and 'd' in kicks[1]['held'] and
                              all('w' not in r['held'] for r in kicks) and
                              all(-56.5 < r['p'][2] < -45 for r in kicks))
    in_flight = 0
    peak_kicks = 0
    for row in rows:
        if row['grounded']:
            in_flight = 0
        if 'wall_jump' in row['motion']['experiment']['events']:
            in_flight += 1
            peak_kicks = max(peak_kicks, in_flight)
    checks['wall_budget'] = peak_kicks <= 2
    checks['grapple_e'] = len(grapple) == 1 and 'e' in grapple[0]['held'] and grapple[0]['motion']['experiment']['grapple']['anchor'] == 'A1'
    return {'checks': checks, 'slide_tick': slide[0]['tick'] if slide else None,
            'slide_entry_ups': slide[0]['motion']['experiment']['slide']['last_landing']['entry_ups'] if slide else None,
            'space_release_tick': release, 'fresh_hop_tick': fresh, 'earned_ad_air_gain_u': earned,
            'kicks': [{'tick': r['tick'], 'p': r['p'], 'held': r['held'], 'kick': r['motion']['experiment']['wall_jump']['last']} for r in kicks],
            'max_kicks_per_landing': peak_kicks, 'grapple_tick': grapple[0]['tick'] if grapple else None}


def report_clean(report):
    return (report['end'] == 'completed' and report['delivery']['ok'] and report['rate']['ok'] and report['order']['ok']
            and report['neutral'] and not report['movement_flags'] and not report['integrity_flags'])


if __name__ == '__main__':
    raise SystemExit(main())
