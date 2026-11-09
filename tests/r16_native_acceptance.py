#!/usr/bin/env python3
"""bounded actual-R16 native acceptance; frozen committed source, private AMD/X11, no desktop changes."""
import argparse
import gzip
import hashlib
import importlib.util
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

sys.dont_write_bytecode = True

REPO = Path(__file__).resolve().parents[3]
PROJECT = REPO / 'projects/foldrunner'
OUTER = REPO.parent
GODOT = Path.home() / '.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64'
FLOOR = 15 * 2**30
SOURCE_CAP = 300 * 2**20
AVI_CAP = 2**30
EVIDENCE_CAP = 55 * 2**20
SPEC = importlib.util.spec_from_file_location('native_display', PROJECT / 'tools/r14_native_display.py')
ND = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ND)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def size(path):
    return sum(p.stat().st_size for p in path.rglob('*') if p.is_file())


def write(path, obj):
    path.write_text(json.dumps(obj, indent=1) + '\n')


def gate():
    free = shutil.disk_usage('/home').free
    if free < FLOOR:
        raise RuntimeError('HOME gate: %.4f GiB free, requires 15 GiB; no launch' % (free / 2**30))
    return free


def isolated(scratch):
    env = {'PATH': os.environ.get('PATH', '/usr/bin:/bin'), 'LANG': 'C.UTF-8'}
    for name in ['HOME', 'XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME', 'XDG_STATE_HOME', 'XDG_RUNTIME_DIR']:
        path = scratch / name.lower()
        path.mkdir(mode=0o700)
        env[name] = str(path)
    return env


def freeze(commit, dest):
    prefix = 'projects/foldrunner/'
    process = subprocess.Popen(['git', 'archive', commit, 'projects/foldrunner'], cwd=REPO, stdout=subprocess.PIPE)
    try:
        with tarfile.open(fileobj=process.stdout, mode='r|') as archive:
            for member in archive:
                name = member.name
                if not member.isfile() or not name.startswith(prefix):
                    continue
                target = dest / name[len(prefix):]
                target.parent.mkdir(parents=True, exist_ok=True)
                with archive.extractfile(member) as stream, target.open('wb') as output:
                    shutil.copyfileobj(stream, output)
        if process.wait() != 0:
            raise RuntimeError('git archive failed')
    finally:
        process.stdout.close()
        if process.poll() is None:
            process.terminate()
            process.wait()
    for path in (PROJECT / 'tests').glob('r16_native_acceptance*'):
        if path.suffix in ['.gd', '.py', '.uid']:
            shutil.copy2(path, dest / 'tests' / path.name)
    return {str(p.relative_to(dest)): sha(p) for p in sorted(dest.rglob('*')) if p.is_file()}


def run(command, env, cwd, logfile, project, avi=None, timeout=900, watch=None, os_out=None):
    with logfile.open('w') as log:
        process = subprocess.Popen(command, env=env, cwd=cwd, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
        if watch:
            watch.follow(process.pid)
        started = time.monotonic()
        peak = 0
        error = None
        os_done = False
        try:
            while process.poll() is None:
                footprint = size(project)
                peak = max(peak, footprint)
                if footprint > SOURCE_CAP:
                    error = 'source/import exceeds 300 MiB'
                if avi and avi.exists() and avi.stat().st_size > AVI_CAP:
                    error = 'AVI exceeds 1 GiB'
                if os_out and not os_done and (os_out / 'observer.json').exists():
                    os_done = True
                    try:
                        os_tour(process, env, os_out)
                    except BaseException as failure:
                        error = 'OS tour failed: ' + repr(failure)
                if time.monotonic() - started > timeout:
                    error = 'engine timeout'
                if error:
                    os.killpg(process.pid, signal.SIGTERM)
                    try:
                        process.wait(5)
                    except subprocess.TimeoutExpired:
                        os.killpg(process.pid, signal.SIGKILL)
                    break
                time.sleep(0.25)
            code = process.wait()
        finally:
            if process.poll() is None:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
            if watch:
                watch.stop()
        return {'exit': code, 'error': error, 'source_import_peak_bytes': peak, 'seconds': round(time.monotonic() - started, 2)}


def compress_outputs(directory):
    for path in directory.rglob('*.jsonl'):
        with path.open('rb') as src, gzip.open(str(path) + '.gz', 'wb', compresslevel=6) as dst:
            shutil.copyfileobj(src, dst)
        path.unlink()


def movie_check(avi, mp4):
    encoding_home_free = gate()
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(avi), '-an', '-c:v', 'libx264', '-preset', 'fast', '-crf', '29',
                    '-pix_fmt', 'yuv420p', '-movflags', '+faststart', str(mp4)], check=True, timeout=180)
    probe = subprocess.run(['ffprobe', '-v', 'error', '-count_frames', '-show_entries',
                            'stream=width,height,nb_frames,nb_read_frames,r_frame_rate,duration:format=duration', '-of', 'json', str(mp4)],
                           capture_output=True, text=True, check=True, timeout=120)
    data = json.loads(probe.stdout)
    stream = data['streams'][0]
    assert stream['width'] == 1280 and stream['height'] == 720
    assert int(stream['nb_frames']) == int(stream['nb_read_frames']) > 0
    assert float(data['format']['duration']) > 0
    subprocess.run(['ffmpeg', '-v', 'error', '-i', str(mp4), '-f', 'null', '-'], check=True, timeout=120)
    avi_probe = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-count_frames', '-show_entries', 'stream=width,height,nb_read_frames,r_frame_rate,duration', '-of', 'json', str(avi)], text=True))
    assert int(avi_probe['streams'][0]['nb_read_frames']) == int(stream['nb_read_frames'])
    assert avi_probe['streams'][0]['width'] == stream['width'] and avi_probe['streams'][0]['height'] == stream['height']
    info = {'probe': data, 'avi_probe': avi_probe, 'home_free_before_encode': encoding_home_free, 'full_decode': True, 'avi_bytes_deleted': avi.stat().st_size, 'mp4_sha256': sha(mp4), 'mp4_bytes': mp4.stat().st_size}
    avi.unlink()
    return info


def os_tour(process, env, out):
    steps = []
    def state():
        return json.loads((out / 'observer.json').read_text())
    def xdo(*args):
        done = subprocess.run(['xdotool', *map(str, args)], env=env, capture_output=True, text=True, timeout=5)
        steps.append({'command': ['xdotool', *map(str, args)], 'exit': done.returncode, 'stderr': done.stderr})
        if done.returncode:
            raise RuntimeError(done.stderr)
        return done.stdout.strip()
    def snap(tag):
        (out / 'capture.txt').write_text(tag)
        deadline = time.monotonic() + 5
        while not (out / (tag + '.jpg')).exists() and time.monotonic() < deadline:
            time.sleep(0.05)
        steps.append({'capture': tag, 'state': state(), 'image_exists': (out / (tag + '.jpg')).exists()})
    def key(name):
        xdo('key', '--clearmodifiers', name)
        time.sleep(0.25)
    def click(name=None, text=None):
        found = next(n for n in state()['ui'] if (n['name'] == name if name else n['text'] == text))
        target_name = found['name']
        for _ in range(40):
            if state().get('focus') == target_name:
                break
            key('Tab')
        assert state().get('focus') == target_name, 'keyboard focus did not reach ' + target_name
        key('Return')
        time.sleep(0.4)
    try:
        window = xdo('search', '--onlyvisible', '--pid', process.pid).splitlines()[-1]
        xdo('windowfocus', '--sync', window)
        snap('os-course-start')
        key('Escape')
        snap('os-escape-menu')
        assert state()['paused'] is True, 'Esc did not pause'
        click(name='Map_experiment')
        deadline = time.monotonic() + 20
        while state()['map'] != 'experiment' and time.monotonic() < deadline:
            time.sleep(0.1)
        if state()['paused']:
            key('Escape')
        assert state()['map'] == 'experiment', 'OS map selection did not reach lab'
        snap('os-lab-from-map-picker')
        xdo('keydown', 'w')
        xdo('keydown', 'space')
        time.sleep(0.35)
        xdo('keydown', 'Shift_L')
        time.sleep(0.2)
        snap('os-held-space-shift')
        xdo('keyup', 'space')
        key('space')
        xdo('keyup', 'Shift_L')
        xdo('keyup', 'w')
        xdo('keydown', 'a')
        key('space')
        time.sleep(0.2)
        xdo('keyup', 'a')
        xdo('keydown', 'd')
        key('space')
        time.sleep(0.2)
        xdo('keyup', 'd')
        key('g')
        snap('os-G-toggled')
        key('g')
        key('Escape')
        snap('os-lab-menu-controls')
        click(text='Quit')
        process.wait(timeout=15)
        steps.append({'quit_exit': process.returncode})
    finally:
        write(out / 'OS-TOUR.json', {'label': 'synthetic OS XTest controls with read-only observer, no physical-device latency/feel claim', 'steps': steps})


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--commit', default='c071480d')
    parser.add_argument('--mode', choices=['course', 'opportunities', 'lab', 'os', 'ui'], default='course')
    parser.add_argument('--native', action='store_true')
    parser.add_argument('--movie', action='store_true')
    parser.add_argument('--verbose', action='store_true')
    parser.add_argument('--fps', type=int, default=32)
    parser.add_argument('--case', default='breakwater-crouch')
    parser.add_argument('--route-tape', type=Path)
    parser.add_argument('--map', default='breakwater')
    args = parser.parse_args()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=False)
    commit = subprocess.check_output(['git', 'rev-parse', args.commit], cwd=REPO, text=True).strip()
    report = {'commit': commit, 'mode': args.mode, 'native': args.native, 'movie_requested': args.movie, 'godot_sha256': sha(GODOT),
              'live_runtime_hashes_before': {p.name: sha(p) for p in (PROJECT / 'scripts').glob('r16*.gd')}}
    scratch = Path(tempfile.mkdtemp(prefix='r16-native-acceptance-', dir='/dev/shm'))
    report['scratch'] = str(scratch)
    try:
        project = scratch / 'project'
        project.mkdir()
        hashes = freeze(commit, project)
        write(out / 'SOURCE-HASHES.json', hashes)
        env = isolated(scratch)
        base = [str(GODOT), '--audio-driver', 'Dummy', '--path', str(project)]
        command = base + ['--headless', '--editor', '--import']
        report['import_command'] = command
        report['import'] = run(command, env, scratch, out / 'import.log', project, timeout=180)
        if report['import']['exit']:
            raise RuntimeError('import failed')
        for path in (project / 'tests').glob('r16_native_acceptance*.gd.uid'):
            shutil.copy2(path, PROJECT / 'tests' / path.name)
        run_out = scratch / 'run'
        avi = scratch / 'movie.avi'
        if args.mode == 'course':
            route = json.loads((OUTER / 'checkpoints/spillway/r15/release-plan/ROUTES.json').read_text())[0]
            spec = dict(item.split('=', 1) for item in route['spec'].split(','))
            command = base + ['--script', 'res://tests/r16_native_acceptance.gd', '--', '--out=' + str(run_out), '--tape=' + spec['tape'],
                               '--physics-hz=128', '--warmup=33', '--frames=none', '--wall-budget-s=800', '--r16-profile=' + str(scratch / 'profile.cfg')]
            if args.route_tape:
                command = [('--tape=' + str(args.route_tape)) if x.startswith('--tape=') else x for x in command]
                command += ['--map=' + args.map, '--tape-only=yes']
                report['supplied_route'] = {'path': str(args.route_tape), 'sha256': sha(args.route_tape), 'map': args.map}
            else:
                report['accepted_route'] = route
        elif args.mode == 'opportunities':
            command = base + ['--script', 'res://tests/r16_native_acceptance_opportunities.gd', '--', '--out=' + str(run_out),
                               '--case=' + args.case, '--preset=server128', '--capture=yes' if args.native else '--no-capture=yes']
        elif args.mode == 'lab':
            command = base + ['--script', 'res://tests/r16_native_acceptance_lab.gd', '--', '--out=' + str(run_out)]
        elif args.mode == 'ui':
            command = base + ['--script', 'res://tests/r16_native_acceptance_ui.gd', '--', '--out=' + str(run_out)]
        else:
            command = base + ['--script', 'res://tests/r16_native_acceptance_os.gd', '--', '--out=' + str(run_out)]
        flags = ['--fixed-fps', str(args.fps)] + (['--verbose'] if args.verbose else [])
        if args.native:
            report['home_free_before_launch'] = gate()
            with ND.NativeDisplay(out / 'display', displays=range(196, 200)) as display:
                watch = display.gpu_watch()
                flags += ['--display-driver', 'x11', '--rendering-driver', 'opengl3', '--windowed', '--resolution', '1280x720']
                if args.movie:
                    flags += ['--write-movie', str(avi)]
                command = command[:1] + flags + command[1:]
                report['command'] = command
                report['display'] = display.display
                report['run'] = run(command, display.child_env(env), scratch, out / 'engine.log', project, avi, watch=watch, os_out=run_out if args.mode == 'os' else None)
                report['gpu'] = watch.verdict()
                report['device'] = ND.require_amd_log((out / 'engine.log').read_text())
                watch.require()
        else:
            command = command[:1] + flags + ['--headless'] + command[1:]
            report['command'] = command
            report['run'] = run(command, env, scratch, out / 'engine.log', project)
        if avi.exists() and report['run']['exit'] == 0:
            report['movie'] = movie_check(avi, scratch / 'movie.mp4')
            shutil.copy2(scratch / 'movie.mp4', out / 'movie.mp4')
        if run_out.exists():
            compress_outputs(run_out)
            # retain compact run files, compressed traces and selected JPEGs; no raw frame dump.
            shutil.copytree(run_out, out / 'run')
        if (scratch / 'profile.cfg').exists():
            shutil.copy2(scratch / 'profile.cfg', out / 'profile.cfg')
        report['evidence_bytes'] = size(out)
        report['aggregate_evidence_bytes'] = size(out.parent)
        if report['aggregate_evidence_bytes'] > EVIDENCE_CAP:
            raise RuntimeError('evidence exceeds 55 MiB cap')
        report['engine_messages'] = [line for line in (out / 'engine.log').read_text().splitlines() if 'WARNING:' in line or 'ERROR:' in line]
        if report['run']['exit'] != 0 or report['run']['error']:
            raise RuntimeError('engine/control run failed: ' + str(report['run']))
    except BaseException as error:
        report['failure'] = repr(error)
        raise
    finally:
        shutil.rmtree(scratch)
        report['scratch_removed'] = not scratch.exists()
        report['home_free_after'] = shutil.disk_usage('/home').free
        report['desktop_after'] = ND.x_answers(':0')
        write(out / 'run.json', report)
        print(json.dumps({k: report.get(k) for k in ['mode', 'native', 'run', 'gpu', 'failure', 'scratch_removed']}), flush=True)


if __name__ == '__main__':
    main()
