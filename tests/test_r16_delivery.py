#!/usr/bin/env python3
"""focused R16 delivery component negatives; no exported-runtime or release acceptance."""
import argparse
import copy
import importlib.util
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
from types import SimpleNamespace
from unittest.mock import patch

PROJECT = Path(__file__).resolve().parents[1]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', required=True, type=Path)
    parser.add_argument('--feature-run', type=Path, help='executed source features folder, for focused evidence mutations')
    args = parser.parse_args()
    m = load('package_r16', PROJECT / 'tools/package-r16.py')
    checks = []

    def check(name, ok):
        checks.append({'name': name, 'ok': bool(ok)})
        assert ok, name

    def refuse(name, callback, contains):
        try:
            callback()
        except (m.Rejected, argparse.ArgumentTypeError) as error:
            check(name, contains in str(error))
        else:
            check(name, False)

    log = 'r16: build=%s; map=breakwater; preset=server128; physics_hz=128; course_key=0123456789abcdef; records=off; recordings=off; runner=res://scripts/r15_source_player.gd; standin=false; renderer=gl_compatibility' % m.BUILD
    check('actual R16 startup format accepted', m.STARTUP.fullmatch(log) is not None)
    check('isolated recording path accepted', m.STARTUP.fullmatch(log.replace('recordings=off', 'recordings=/isolated/r16_runs')) is not None)
    for name, changed in [('R15 line', log.replace('r16:', 'r15:')), ('missing recording state', log.replace(' recordings=off;', '')),
                          ('stand-in', log.replace('standin=false', 'standin=true')), ('short identity', log.replace('0123456789abcdef', '0123'))]:
        check(name + ' refused', m.STARTUP.fullmatch(changed) is None)
    check('R15 and every prior config protected', set(m.OLD_PROFILES) == {'spillway_v1.cfg', 'spillway_r12.cfg', 'spillway_r13.cfg', 'spillway_r14.cfg', 'spillway_r15.cfg'})
    check('independent reader and preservation hashes mandatory', {'tools/analyze-r16-runs.py', 'scripts/r16_run_reader.gd', 'tools/check-r16-preservation.py'} <= set(m.HELPERS))
    check('official runtime member digests equal frozen R15 pins', m.TEMPLATE_MEMBERS == load('package_r15', PROJECT / 'tools/package-r15.py').TEMPLATE_MEMBERS)
    check('all eight maps required', len(set(m.REQUIRED_MAPS)) == 8)
    rows = [{'phase': 'tape', 'tick': i, 'post': {'p': [0., 0., float(i)], 'v': [0., 0., 1.], 'yaw': 0.},
             'game': {'checkpoint': 0, 'elapsed': i / 128, 'finished': False, 'finish_kind': '', 'respawns': 0}} for i in range(2)]
    check('identical source traces admitted', m.compare_traces(rows, copy.deepcopy(rows))['ok'])
    for name, mutate in [('velocity lie', lambda r: r[0]['post'].update(v=[0., 0., -1.])), ('duplicate tick', lambda r: r[1].update(tick=0)),
                         ('missing tick', lambda r: r.pop()), ('NaN', lambda r: r[0]['post'].update(v=[0., float('nan'), 0.]))]:
        bad = copy.deepcopy(rows); mutate(bad)
        check(name + ' refused', not m.compare_traces(rows, bad)['ok'])
    with tempfile.TemporaryDirectory(prefix='r16-delivery-components-') as directory:
        temp = Path(directory)
        for startup in (False, True):
            a = SimpleNamespace(output=temp / ('startup' if startup else 'incomplete'), diagnostic=False, startup_only=startup, route=[])
            refuse('release without course proofs refused ' + str(startup), lambda: m.package(a), 'route' if not startup else 'diagnostic')
        original = subprocess.Popen
        for sig in (signal.SIGINT, signal.SIGTERM):
            children = []
            def acquire(*a, **kw):
                child = original([sys.executable, '-c', 'import time; time.sleep(60)'], start_new_session=True,
                                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                children.append(child)
                os.kill(os.getpid(), sig)
                return child
            old = signal.getsignal(sig)
            cancelled = False
            try:
                with patch.object(m.subprocess, 'Popen', acquire):
                    m.run_engine(['stub'], temp, os.environ.copy(), temp / 'cancel.log', 1, cleanup_grace=1)
            except KeyboardInterrupt:
                cancelled = True
            finally:
                gone = bool(children) and all(c.poll() is not None for c in children)
                for child in children:
                    m.stop_process(child)
            check(sig.name + ' acquisition releases child and restores handler', cancelled and gone and signal.getsignal(sig) == old)
        with patch.object(m.nd, 'display_busy', return_value=True), patch.object(m.subprocess, 'Popen') as launch:
            refuse('busy display refused without spawning', lambda: m.Display(199, temp / 'busy.log').__enter__(), 'in use')
            check('busy display did not launch', not launch.called)
        for sig in (signal.SIGINT, signal.SIGTERM):
            children = []
            cancelled = False
            try:
                with patch.object(m.subprocess, 'Popen', acquire), patch.object(m.nd, 'display_busy', return_value=False):
                    with m.Display(199, temp / 'display-cancel.log'):
                        raise AssertionError('cancelled display acquisition entered its body')
            except KeyboardInterrupt:
                cancelled = True
            finally:
                gone = bool(children) and all(c.poll() is not None for c in children)
                for child in children:
                    m.stop_process(child)
            check(sig.name + ' display acquisition cancellation releases its child', cancelled and gone)
        pidfile = temp / 'descendants.pid'
        script = ('import os,subprocess,sys,time;from pathlib import Path;'
                  'child=subprocess.Popen([sys.executable,"-c","import time;time.sleep(30)"]);'
                  'Path(%r).write_text("%%d %%d"%%(os.getpid(),child.pid));time.sleep(30)' % str(pidfile))
        code, _ = m.run_engine([sys.executable, '-c', script], temp, os.environ.copy(), temp / 'deadline.log', 0.5, cleanup_grace=0.5)
        pids = [int(v) for v in pidfile.read_text().split()] if pidfile.exists() else []
        def alive(pid):
            try:
                return Path('/proc/%d/stat' % pid).read_text().rsplit(')', 1)[1].split()[0] != 'Z'
            except (FileNotFoundError, ProcessLookupError):
                return False
        time.sleep(0.1)
        check('deadline releases owned engine and its descendant', code == 'timeout' and len(pids) == 2 and not any(alive(pid) for pid in pids))
        with patch.object(m, 'MIN_FREE_GIB', 10**6):
            refuse('storage floor enforced before native/export', lambda: m.require_space(temp, 'test'), 'below the')
        for missing in ({}, {'recordings': {'attempts': [], 'observed': []}}):
            check('missing attempt receipt fails closed', not m.audit_profile(temp, {}, {}, missing, m.helper_hashes())['ok'])
        # an internally consistent forged cache manifest still cannot replace independent pins.
        fake = temp / 'templates'; fake.mkdir()
        manifest = {'official_digest': 'sha256:' + m.TEMPLATES_SHA256, 'members': {}}
        for member in m.TEMPLATE_MEMBERS:
            (fake / member).write_bytes(b'forged runtime')
            manifest['members']['templates/' + member] = m.digest(fake / member)
        (fake / 'PROVENANCE.json').write_text(json.dumps(manifest)); (fake / 'version.txt').write_text('4.7.2.stable')
        with patch.object(m, 'TEMPLATES', fake):
            refuse('forged cache manifest cannot repin runtime bytes', m.templates, 'differs')
    if args.feature_run:
        feature = args.feature_run.resolve()
        report = json.loads((feature / 'result.json').read_text())
        profile = feature / 'profile'
        after = m.profile_files(profile)
        before = {k: v for k, v in after.items() if not k.endswith('.r16run')}
        helpers = m.helper_hashes()
        check('actual source feature recordings pass both readers and all observations', m.audit_profile(profile, before, after, report, helpers)['ok'])
        # labelled predicate fixture: expected tape edges reconstructed from one verified stream.
        # this tests comparator refusals; the live source feature run supplies the observations.
        analyzer = load('r16_delivery_test_analyzer', PROJECT / 'tools/analyze-r16-runs.py')
        first = report['recordings']['attempts'][0]
        rec = analyzer.read(Path(first['path']))
        codes = {87: 'w', 65: 'a', 83: 's', 68: 'd', 32: 'space', 4194326: 'ctrl', 4194325: 'shift', 69: 'e'}
        by_tick = {}
        for j, tick in enumerate(rec.inputs['tick']):
            row = by_tick.setdefault(tick, {'run_id': first['run_id'], 'recording_tick': tick, 'keys': [], 'mouse': {}})
            if rec.inputs['kind'][j] == 1:
                code = rec.inputs['aux'][j] or rec.inputs['code'][j]
                row['keys'].append({'key': codes[code], 'edge': 'press' if rec.inputs['flags'][j] & 1 else 'release'})
            elif rec.inputs['kind'][j] == 3:
                row['mouse'] = {'screen_relative': [rec.inputs['x2'][j], rec.inputs['y2'][j]]}
        planned = copy.deepcopy(report)
        planned['recorded_tape_inputs'] = list(by_tick.values())
        check('labelled tape predicate fixture accepted', m.audit_profile(profile, before, after, planned, helpers)['ok'])
        edge_row = next(i for i, row in enumerate(planned['recorded_tape_inputs']) if row['keys'])
        mouse_row = next(i for i, row in enumerate(planned['recorded_tape_inputs']) if row['mouse'])
        for name, mutate in [
            ('edge moved to next tick', lambda r: r['recorded_tape_inputs'][edge_row].update(recording_tick=by_tick[next(iter(by_tick))]['recording_tick'] + 1)),
            ('wrong edge order', lambda r: r['recorded_tape_inputs'][edge_row]['keys'].reverse()),
            ('mouse count lie', lambda r: r['recorded_tape_inputs'][mouse_row]['mouse']['screen_relative'].__setitem__(0, 123.)),
        ]:
            bad = copy.deepcopy(planned); mutate(bad)
            check(name + ' refused', not m.audit_profile(profile, before, after, bad, helpers)['ok'])
        for name, mutate in [
            ('missing observation', lambda r: r['recordings']['observed'].pop()),
            ('duplicate observation tick', lambda r: r['recordings']['observed'][1].update(tick=0)),
            ('observed position lie', lambda r: r['recordings']['observed'][0]['p'].__setitem__(0, 123.)),
            ('observed velocity lie', lambda r: r['recordings']['observed'][0]['v'].__setitem__(0, 123.)),
            ('held key lie', lambda r: r['recordings']['observed'][0]['held'].update(jump=True)),
            ('scalar byte lie', lambda r: r['recordings']['observed'][0]['scalar_hex'].update(yaw='000000000000f03f')),
            ('wrong boundary', lambda r: r['recordings']['attempts'][0].update(kind='finish')),
            ('unobserved file', lambda r: r['recordings']['attempts'].pop()),
            ('missing current reader', lambda r: r.pop('reader_runs')),
            ('duplicate attempt', lambda r: r['recordings']['attempts'].append(r['recordings']['attempts'][0])),
        ]:
            bad = copy.deepcopy(report); mutate(bad)
            check(name + ' refused', not m.audit_profile(profile, before, after, bad, helpers)['ok'])
        for name in ('Spillway/rogue.cfg', 'Spillway/r16_runs/unobserved.r16run', 'OtherApp/test.cfg'):
            forged = dict(after); forged[name] = '0' * 64
            check('arbitrary new profile path refused: ' + name, not m.audit_profile(profile, before, forged, report, helpers)['ok'])
        modified = dict(after); modified['Spillway/spillway_r15.cfg'] = '0' * 64
        check('R15 config overwrite refused', not m.audit_profile(profile, before, modified, report, helpers)['ok'])
        deleted = dict(after); deleted.pop('Spillway/spillway_r15.cfg')
        check('R15 config deletion refused', not m.audit_profile(profile, before, deleted, report, helpers)['ok'])
        wrong = dict(helpers); wrong['tools/analyze-r16-runs.py'] = '0' * 64
        check('stale independent reader hash refused', not m.audit_profile(profile, before, after, report, wrong)['ok'])
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps({'checks': checks, 'passed': len(checks), 'failed': 0,
        'scope': 'R16 components only; no packed runtime acceptance'}, indent=2) + '\n')
    print('%d R16 delivery component checks passed' % len(checks))


if __name__ == '__main__':
    main()
