#!/usr/bin/env python3
"""exercise an unmodified r16 release launch through private XTest input and its default recordings."""
import argparse
from contextlib import contextmanager
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

PROJECT = Path(__file__).resolve().parents[1]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--candidate', required=True, type=Path)
    parser.add_argument('--out', required=True, type=Path)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=False)
    m = load('release_os_package', PROJECT / 'tools/package-r16.py')
    analyzer = load('release_os_analyzer', PROJECT / 'tools/analyze-r16-runs.py')
    build = json.loads((args.candidate / 'BUILD.json').read_text())
    m.verify_source_manifest(build)
    archive = next(args.candidate.glob('*-linux-*.zip'))
    hashes = {'zip': m.digest(archive), 'pack': build['pack_sha256'], 'source': build['source_commit'], 'tool': m.digest(Path(__file__))}
    steps, checks, error = [], [], None
    process = gpu = None
    stage = Path(tempfile.mkdtemp(prefix='r16-release-os-', dir='/tmp'))
    before_free = shutil.disk_usage(Path.home()).free
    try:
        m.require_space(stage, 'normal shipped OS-input launch')
        m.extract(archive, stage / 'extract')
        folder = stage / 'extract' / (m.NAME + '-linux-x86_64')
        assert m.digest(folder / (m.NAME + '.pck')) == hashes['pack']
        assert m.digest(folder / (m.NAME + '.x86_64')) == m.TEMPLATE_MEMBERS['linux_release.x86_64']
        assert not (folder / 'override.cfg').exists()
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
                steps.append({'monotonic': time.monotonic(), 'command': command})
                return subprocess.check_output(command, env=env, text=True, stderr=subprocess.STDOUT, timeout=5).strip()
            with (args.out / 'engine.log').open('w') as log:
                process = subprocess.Popen([str(folder / (m.NAME + '.x86_64')), '--display-driver', 'x11', '--audio-driver', 'Dummy', '--resolution', '1280x720', '--windowed'], cwd=cwd, env=env, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
                gpu = display.gpu_watch().follow(process.pid)
                window = ''
                for _ in range(160):
                    if process.poll() is not None:
                        raise RuntimeError('game exited before its window was ready')
                    try:
                        windows = xdo('search', '--onlyvisible', '--pid', process.pid).splitlines()
                        for candidate in windows:
                            if 'Spillway R16' in xdo('getwindowname', candidate):
                                window = candidate
                                break
                        if window:
                            break
                    except (subprocess.CalledProcessError, IndexError):
                        pass
                    time.sleep(0.1)
                assert window, 'no native player window'
                xdo('windowfocus', '--sync', window)
                # a title can appear before the first draw finishes; wait for real recorded ticks.
                observed_ticks = 0
                until = time.monotonic() + 60.0
                while time.monotonic() < until and process.poll() is None:
                    for pending in m.profile_root(profile).glob('r16_runs/*.r16run.part'):
                        partial = analyzer.read(pending)
                        observed_ticks = max(observed_ticks, len(partial.columns.get('tick', [])))
                    if observed_ticks >= 128:
                        break
                    time.sleep(0.1)
                checks.append({'name': 'normal launch advances physics before OS controls', 'ok': observed_ticks >= 128})
                assert observed_ticks >= 128, 'normal launch did not advance enough physics ticks'
                time.sleep(0.2)
                title = xdo('getwindowname', window)
                checks.append({'name': 'normal release title names R16, Breakwater and F2', 'ok': 'Spillway R16' in title and 'Breakwater' in title and 'CS:GO bhop server' in title})
                xdo('keydown', 'w'); time.sleep(0.4)
                xdo('keydown', 'space'); time.sleep(0.13)
                xdo('keyup', 'w'); xdo('keydown', 'a')
                xdo('mousemove_relative', '--', -100, 0); time.sleep(0.18)
                xdo('keydown', 'c'); time.sleep(0.14)
                xdo('keyup', 'c', 'a'); time.sleep(0.4)
                xdo('keyup', 'space'); xdo('key', 'r'); time.sleep(0.2)
                xdo('keydown', 'w', 'space'); time.sleep(0.9)
                xdo('keyup', 'w', 'space'); xdo('key', 'g'); time.sleep(0.2)
                xdo('key', 'Escape'); time.sleep(0.3)
                subprocess.run(['import', '-display', display.display, '-window', window, str(args.out / 'pause.jpg')], env=env, check=True, timeout=10)
                # the pause handler focuses Resume; three tabs select its adjacent Quit button.
                xdo('key', 'Tab', 'Tab', 'Tab', 'Return')
                code = process.wait(timeout=15)
                gpu.stop()
            checks.append({'name': 'OS pause-menu Quit exits zero', 'ok': code == 0})
            device = m.nd.godot_device((args.out / 'engine.log').read_text())
            checks.append({'name': 'AMD drew the actual release process', 'ok': gpu.verdict()['ok'] and bool(device) and 'AMD' in device['device']})
        checks.append({'name': 'private display released', 'ok': display.released})
        text = (args.out / 'engine.log').read_text()
        checks.append({'name': 'release log error-free', 'ok': not m.ERRORS.search(text)})
        checks.append({'name': 'no-probe launch enables default recording directory', 'ok': 'recordings=' in text and '/r16_runs' in text and '--pack-probe' not in text})
        after = m.profile_files(profile)
        old_names = [n for n in before if not '/logs/' in n]
        checks.append({'name': 'earlier profiles untouched', 'ok': all(before[n] == after.get(n) for n in old_names)})
        records = list(m.profile_root(profile).glob('r16_runs/*.r16run'))
        kept = args.out / 'recordings'; kept.mkdir()
        reads = []
        for file in records:
            read = analyzer.read(file)
            reads.append(read)
            shutil.copy2(file, kept / file.name)
        checks.append({'name': 'restart and Quit each seal their own default attempt', 'ok': len(reads) == 2 and all(r.ok for r in reads) and {r.seal['outcome']['kind'] for r in reads} == {'restart', 'quit'}})
        inputs = [(r.inputs['kind'][i], r.inputs['aux'][i] or r.inputs['code'][i]) for r in reads for i in range(len(r.inputs['tick']))]
        checks.append({'name': 'OS W A Space and C edges were recorded', 'ok': all((1, key) in inputs for key in [87, 65, 32, 67])})
        checks.append({'name': 'OS mouse and view change were recorded', 'ok': any(kind == 3 for kind, _ in inputs) and any(max(r.columns['yaw']) - min(r.columns['yaw']) > 0.01 for r in reads)})
        checks.append({'name': 'OS air crouch and real flight were recorded', 'ok': any(any((f & 16) and not (f & 8) for f in r.columns['flags']) for r in reads)})
        (args.out / 'gpu.json').write_text(json.dumps(gpu.verdict(), indent=2) + '\n')
        assert all(c['ok'] for c in checks), [c['name'] for c in checks if not c['ok']]
    except BaseException as failure:
        error = repr(failure)
    finally:
        if gpu:
            gpu.stop()
        m.stop_process(process)
        shutil.rmtree(stage, ignore_errors=True)
        result = {'ok': error is None and bool(checks) and all(c['ok'] for c in checks), 'checks': checks, 'error': error, 'identities': hashes, 'steps': steps, 'scratch_removed': not stage.exists(), 'home_free_before': before_free, 'scope': 'unmodified Linux release runtime and pack; synthetic XTest OS input, no game probe, Windows/physical latency/feel unverified'}
        (args.out / 'RESULTS.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'ok': result['ok'], 'checks': len(checks), 'error': error}))
    return 0 if result['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
