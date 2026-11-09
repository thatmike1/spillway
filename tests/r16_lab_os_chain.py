#!/usr/bin/env python3
"""exercise the shipped lab via OS keys, with a read-only coordinate-aware observer."""
import argparse
from contextlib import contextmanager
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
import time

sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[1]
U = 0.0254


def load(name, file):
    spec = importlib.util.spec_from_file_location(name, file)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--candidate', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=False)
    m = load('r16_os_chain_package', PROJECT / 'tools/package-r16.py')
    build = json.loads((args.candidate / 'BUILD.json').read_text())
    m.verify_source_manifest(build)
    archive = next(args.candidate.glob('*-linux-*.zip'))
    stage = Path(tempfile.mkdtemp(prefix='r16-lab-os-', dir='/tmp'))
    run = stage / 'run'
    run.mkdir()
    process = gpu = None
    held, commands, phases, checks = set(), [], [], []
    error = None
    free_before = shutil.disk_usage(Path.home()).free
    ids = {'zip': m.digest(archive), 'pack': build['pack_sha256'], 'source': build['source_commit'],
           'driver': m.digest(Path(__file__)), 'observer': m.digest(PROJECT / 'tests/r16_lab_os_observer.gd')}
    try:
        m.require_space(stage, 'the OS lab-chain check')
        m.extract(archive, stage / 'extract')
        folder = stage / 'extract' / (m.NAME + '-linux-x86_64')
        assert m.digest(folder / (m.NAME + '.pck')) == ids['pack']
        assert m.digest(folder / (m.NAME + '.x86_64')) == m.TEMPLATE_MEMBERS['linux_release.x86_64']
        observer = stage / 'observer.gd'
        shutil.copy2(PROJECT / 'tests/r16_lab_os_observer.gd', observer)
        (folder / 'override.cfg').write_text('[autoload]\nOSObserver="*%s"\n' % observer)
        profile, cwd = stage / 'profile', stage / 'cwd'
        cwd.mkdir()
        m.seed_old_profiles(profile)
        before = m.profile_files(profile)
        @contextmanager
        def owned_display():
            with m.nd.NativeDisplay(args.out / 'display', displays=range(196, 200)) as current:
                try:
                    yield current
                finally:
                    m.stop_process(process)
        with owned_display() as display:
            env = display.child_env(m.engine_env(profile))
            def xdo(*values):
                command = ['xdotool', *map(str, values)]
                commands.append({'time': time.monotonic(), 'command': command})
                return subprocess.check_output(command, env=env, stderr=subprocess.STDOUT, text=True, timeout=5).strip()
            def state():
                if process.poll() is not None:
                    raise RuntimeError('game exited before the OS challenge ended')
                return json.loads((run / 'latest.json').read_text())
            def until(predicate, seconds=20):
                deadline = time.monotonic() + seconds
                while time.monotonic() < deadline:
                    if (run / 'latest.json').exists():
                        row = state()
                        if predicate(row):
                            return row
                    time.sleep(0.005)
                raise RuntimeError('OS challenge deadline: ' + repr(state() if (run / 'latest.json').exists() else None))
            def want(*keys):
                target = set(keys)
                up, down = held - target, target - held
                if up:
                    xdo('keyup', *sorted(up))
                if down:
                    xdo('keydown', *sorted(down))
                held.clear()
                held.update(target)
            def phase(name):
                phases.append({'name': name, 'state': state()})
            def shot(name):
                (run / 'capture.txt').write_text(name)
            def tap(key, delay=0.04):
                xdo('keydown', key)
                time.sleep(delay)
                xdo('keyup', key)
            def focus(name):
                target = next((item['name'] for item in state()['ui'] if item['name'] == name or item['text'] == name), name)
                for _ in range(45):
                    if state()['focus'] == target:
                        return
                    tap('Tab', 0.015)
                    time.sleep(0.025)
                raise RuntimeError('focus not reached: ' + name)
            with (args.out / 'engine.log').open('w') as log:
                process = subprocess.Popen([str(folder / (m.NAME + '.x86_64')), '--display-driver', 'x11', '--audio-driver', 'Dummy', '--resolution', '1280x720', '--windowed', '--', '--r16-map=experiment', '--r16-preset=server128', '--no-records', '--r16-recordings=' + str(run / 'recordings'), '--lab-os-out=' + str(run)], cwd=cwd, env=env, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
                gpu = display.gpu_watch().follow(process.pid)
                until(lambda s: s['tick'] >= 128)
                window = xdo('search', '--onlyvisible', '--pid', process.pid).splitlines()[-1]
                xdo('windowfocus', '--sync', window)
                phase('normal lab spawn')
                want('w')
                until(lambda s: math.hypot(s['v'][0], s['v'][2]) / U >= 249)
                want('w', 'space')
                until(lambda s: 'jump' in s['events'] or not s['g'])
                phase('first running bhop')
                until(lambda s: s['jumps'] >= 2)
                until(lambda s: s['v'][1] < 0 and s['p'][1] < 0.45)
                want('w', 'space', 'Shift_L')
                phase('descent Shift with Space held')
                sliding = until(lambda s: s['lab']['slide']['active'])
                phase('OS landing slide')
                shot('landing-slide')
                until(lambda s: s['frame'] >= sliding['frame'] + 24)
                want('w', 'Shift_L')
                time.sleep(0.04)
                want('w', 'Shift_L', 'space')
                until(lambda s: not s['g'] and s['v'][1] > 0)
                phase('fresh OS hop out')
                shot('slide-hop')
                want()
                tap('Escape')
                until(lambda s: s['paused'])
                focus('StagePicker')
                tap('Return')
                until(lambda s: any(n.get('popup') for n in s['ui'] if n['name'] == 'StagePicker'))
                for _ in range(12):
                    picker = next(n for n in state()['ui'] if n['name'] == 'StagePicker')
                    if picker['focused_item'] == 2:
                        break
                    tap('Up' if picker['focused_item'] > 2 else 'Down')
                    time.sleep(0.04)
                assert next(n for n in state()['ui'] if n['name'] == 'StagePicker')['focused_item'] == 2
                tap('Return')
                until(lambda s: any(n.get('selected') == 2 for n in s['ui'] if n['name'] == 'StagePicker'))
                focus('StagePractice')
                tap('Return')
                until(lambda s: not s['paused'] and s['practice'] == 2)
                phase('OS picker authored chamber practice')
                want('w')
                until(lambda s: s['p'][2] < -45)
                want('w', 'a')
                until(lambda s: s['p'][2] < -50.3)
                want('a', 'space')
                time.sleep(0.035)
                want('a')
                until(lambda s: not s['g'] and s['v'][1] / U < 30)
                want('a', 'space')
                first = until(lambda s: s['lab']['counts']['wall_jump'] >= 1, 3)
                phase('OS west kick with A held')
                shot('wall-kick-a')
                until(lambda s: s['frame'] >= first['frame'] + 7)
                want('d')
                until(lambda s: not s['g'] and s['p'][0] > 1.6 - 16 * U - 0.03, 4)
                want('d', 'space')
                second = until(lambda s: s['lab']['counts']['wall_jump'] >= 2, 3)
                phase('OS east kick with D held')
                shot('wall-kick-d')
                until(lambda s: s['frame'] >= second['frame'] + 7)
                want('w')
                landed = until(lambda s: s['g'], 5)
                phase('OS chamber landing')
                want()
                shot('chamber-landing')
                time.sleep(0.15)
                tap('Escape')
                until(lambda s: s['paused'])
                focus('Quit')
                tap('Return')
                code = process.wait(timeout=15)
                gpu.stop()
            checks.extend([{'name': 'OS Quit exits zero', 'ok': code == 0}, {'name': 'actual AMD rendering', 'ok': gpu.verdict()['ok']}, {'name': 'authored chamber reached by OS picker', 'ok': landed['practice'] == 2}, {'name': 'two kicks reach mezzanine and refill', 'ok': landed['p'][1] > 3.1 and landed['lab']['wall_jump']['budget'] == 2}])
            (args.out / 'gpu.json').write_text(json.dumps(gpu.verdict(), indent=2) + '\n')
        checks.append({'name': 'private display released', 'ok': display.released})
        text = (args.out / 'engine.log').read_text()
        checks.append({'name': 'engine log clean', 'ok': not m.ERRORS.search(text)})
        after = m.profile_files(profile)
        checks.append({'name': 'earlier profiles unchanged', 'ok': all(after.get(k) == v for k, v in before.items() if '/logs/' not in k)})
        raw = (run / 'observations.jsonl').read_bytes()
        observations = [json.loads(line) for line in raw.splitlines()]
        slides = [s for s in observations if 'slide_landing' in s['lab'].get('events', [])]
        jumps = [s for s in observations if 'wall_jump' in s['lab'].get('events', [])]
        checks.append({'name': 'landing slide starts with held Space and Shift', 'ok': bool(slides) and slides[0]['held']['jump'] and slides[0]['held']['r15_slide']})
        checks.append({'name': 'slide preserves entry speed except declared first-tick friction', 'ok': bool(slides) and abs(math.hypot(slides[0]['v'][0], slides[0]['v'][2]) / U - slides[0]['lab']['slide']['last_landing']['entry_ups'] * (1 - 0.25 / 128)) < 0.01})
        checks.append({'name': 'A and D remain held on their kicks without W', 'ok': len(jumps) == 2 and jumps[0]['held']['move_left'] and jumps[1]['held']['move_right'] and all(not s['held']['move_forward'] for s in jumps)})
        (args.out / 'observations.jsonl.gz').write_bytes(gzip.compress(raw, 9, mtime=0))
        assert all(c['ok'] for c in checks), checks
    except BaseException as failure:
        error = repr(failure)
    finally:
        if gpu:
            gpu.stop()
        m.stop_process(process)
        for f in run.glob('*'):
            if f.suffix in ('.jpg', '.jsonl'):
                if f.suffix == '.jsonl':
                    raw = f.read_bytes()
                    (args.out / (f.name + '.gz')).write_bytes(gzip.compress(raw, 9, mtime=0))
                else:
                    shutil.copy2(f, args.out / f.name)
        if (run / 'recordings').exists():
            shutil.copytree(run / 'recordings', args.out / 'recordings')
        shutil.rmtree(stage, ignore_errors=True)
        result = {'ok': error is None and bool(checks) and all(c['ok'] for c in checks), 'error': error, 'checks': checks, 'identities': ids, 'phases': phases, 'commands': commands, 'home_free_before': free_before, 'scratch_removed': not stage.exists(), 'scope': 'coordinate-aware synthetic OS keys on exact release pack; read-only observer; normal-spawn slide chain and labelled authored chamber practice, not physical latency/feel'}
        (args.out / 'RESULTS.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'ok': result['ok'], 'error': error, 'checks': checks}))
    return 0 if result['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
