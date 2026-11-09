#!/usr/bin/env python3
"""player-view-only source discovery: private native display, OS input, pause-only observer."""
import ctypes
import hashlib
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

sys.path.insert(0, str(Path(__file__).resolve().parent))
import r14_native_display as nd

ROOT = Path(__file__).resolve().parents[3]
COMMIT = '406640de38a041c86471ab69172e74f2b38f7e84'
OUT = Path('/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r15/discovery/attempt-03')
ENGINE = Path.home() / '.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64'
OBSERVER = '''extends Node
var last_id := -1
var frames := 0
func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    get_tree().paused = true
func _process(_delta: float) -> void:
    var path := OS.get_environment("R15_DISCOVERY_CONTROL")
    if not FileAccess.file_exists(path):
        return
    var request = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not request is Dictionary:
        return
    if int(request.id) != last_id:
        last_id = int(request.id)
        frames = 0
        get_tree().paused = bool(request.paused)
    frames += 1
    if frames == 3:
        var file := FileAccess.open(path + ".ack", FileAccess.WRITE)
        file.store_string(str(last_id))
'''

def dump(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n')

def floor():
    free = shutil.disk_usage(Path.home()).free
    if free < 15 * 2**30:
        raise RuntimeError('HOME below 15 GiB: %.6f GiB' % (free / 2**30))
    return free

def size(path):
    return sum(p.stat().st_size for p in path.rglob('*') if p.is_file())

def run():
    OUT.mkdir(parents=True, exist_ok=False)
    reused = os.environ.get('R15_DISCOVERY_REUSE')
    scratch = Path(reused) if reused else Path(tempfile.mkdtemp(prefix='r15-discovery-', dir='/tmp'))
    source = scratch / 'source'
    source.mkdir(exist_ok=bool(reused))
    receipt = {'commit': COMMIT, 'mode': 'source, actual project main, not packed acceptance',
               'scratch': str(scratch), 'engine': str(ENGINE), 'engine_sha256': nd.digest(ENGINE),
               'helper_sha256': nd.digest(Path(__file__)), 'pause_observer_sha256': hashlib.sha256(OBSERVER.encode()).hexdigest(),
               'started': time.time(), 'decisions': 0, 'launch_free_home_bytes': []}
    process = watch = display = None
    try:
        if reused:
            previous = OUT.parent / 'attempt-02'
            before = json.loads((previous / 'run.json').read_text())
            for key in ('archive_sha256', 'source_tree', 'source_manifest_sha256', 'import_exit'):
                receipt[key] = before[key]
            receipt['reuse_of_imported_snapshot'] = str(previous)
            receipt['decisions'] = 2
            shutil.copyfile(previous / 'source-manifest.json', OUT / 'source-manifest.json')
        else:
            archive = scratch / 'source.tar'
            with archive.open('wb') as output:
                subprocess.run(['git', 'archive', '--format=tar', COMMIT + ':projects/foldrunner'], cwd=ROOT, stdout=output, check=True)
            receipt['archive_sha256'] = nd.digest(archive)
            receipt['source_tree'] = subprocess.check_output(['git', 'rev-parse', COMMIT + ':projects/foldrunner'], cwd=ROOT, text=True).strip()
            with tarfile.open(archive) as stream:
                stream.extractall(source, filter='data')
            manifest = [{'path': str(p.relative_to(source)), 'sha256': nd.digest(p), 'bytes': p.stat().st_size}
                        for p in sorted(source.rglob('*')) if p.is_file()]
            dump(OUT / 'source-manifest.json', manifest)
            receipt['source_manifest_sha256'] = nd.digest(OUT / 'source-manifest.json')
            archive.unlink()
        profile = scratch / 'profile'
        env = dict(os.environ)
        for part in ('data', 'config', 'cache', 'state', 'runtime'):
            path = profile / part
            path.mkdir(parents=True, mode=0o700, exist_ok=bool(reused))
            env['XDG_' + part.upper() + ('_DIR' if part == 'runtime' else '_HOME')] = str(path)
        env.update(MESA_SHADER_CACHE_DISABLE='true')
        receipt['launch_free_home_bytes'].append({'launch': 'import', 'free': floor()})
        cmd = [str(ENGINE), '--headless', '--audio-driver', 'Dummy', '--editor', '--import', '--quit', '--path', str(source)]
        with (OUT / 'import.log').open('w') as log:
            result = subprocess.run(cmd, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=150)
        receipt['import_exit'] = result.returncode
        if result.returncode:
            raise RuntimeError('source import failed, see import.log; not gameplay failure')
        receipt['scratch_bytes_after_import'] = size(scratch)
        if receipt['scratch_bytes_after_import'] > 350 * 2**20:
            raise RuntimeError('scratch budget exceeded')
        (source / 'r15_discovery_observer.gd').write_text(OBSERVER)
        (source / 'override.cfg').write_text('[autoload]\nDiscoveryObserver="*res://r15_discovery_observer.gd"\n')
        control = scratch / 'control.json'
        env['R15_DISCOVERY_CONTROL'] = str(control)
        request_id = 0
        dump(control, {'id': 0, 'paused': True})
        receipt['launch_free_home_bytes'].append({'launch': 'native display', 'free': floor()})
        with nd.NativeDisplay(OUT / 'native', displays=tuple(range(190, 200)), weston_root=nd.WESTON_ROOT) as display:
            env = display.child_env(env)
            receipt['display'] = display.display
            receipt['launch_free_home_bytes'].append({'launch': 'game', 'free': floor()})
            cmd = [str(ENGINE), '--path', str(source), '--audio-driver', 'Dummy', '--display-driver', 'x11',
                   '--rendering-driver', 'opengl3', '--windowed', '--resolution', '1280x720', '--', '--no-records']
            receipt['game_command'] = cmd
            with (OUT / 'engine.log').open('w') as log:
                process = subprocess.Popen(cmd, env=env, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
                receipt['game_pid'] = process.pid
                watch = display.gpu_watch().follow(process.pid)
                try:
                    def ack(number):
                        end = time.monotonic() + 25
                        while time.monotonic() < end:
                            if process.poll() is not None:
                                raise RuntimeError('engine exited %s, see engine.log' % process.returncode)
                            p = Path(str(control) + '.ack')
                            if p.exists() and p.read_text().strip() == str(number):
                                return
                            time.sleep(0.03)
                        raise RuntimeError('pause-only observer acknowledgement timeout')
                    def pause(value):
                        nonlocal request_id
                        if not value:
                            os.kill(process.pid, signal.SIGCONT)
                        request_id += 1
                        temp = control.with_suffix('.next')
                        dump(temp, {'id': request_id, 'paused': value})
                        temp.replace(control)
                        ack(request_id)
                    def xdo(*args):
                        subprocess.run(['xdotool', *map(str, args)], env=env, check=True, timeout=5, stdout=subprocess.DEVNULL)
                    ack(0)
                    windows = subprocess.check_output(['xdotool', 'search', '--onlyvisible', '--pid', str(process.pid)], env=env, text=True).split()
                    window = windows[-1]
                    xdo('windowfocus', window)
                    x11 = ctypes.CDLL('libX11.so.6')
                    xtst = ctypes.CDLL('libXtst.so.6')
                    x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
                    x11.XOpenDisplay.restype = ctypes.c_void_p
                    x11.XFlush.argtypes = [ctypes.c_void_p]
                    x11.XCloseDisplay.argtypes = [ctypes.c_void_p]
                    xtst.XTestFakeRelativeMotionEvent.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_ulong]
                    connection = x11.XOpenDisplay(display.display.encode())
                    def capture(number):
                        os.kill(process.pid, signal.SIGSTOP)
                        path = OUT / ('%02d.jpg' % number)
                        subprocess.run(['import', '-display', display.display, '-window', 'root', '-resize', '1080x613', '-quality', '65', str(path)], env=env, check=True, timeout=10)
                        return str(path)
                    print(json.dumps({'ready': True, 'image': capture(0), 'display': display.display}), flush=True)
                    with (OUT / 'decisions.jsonl').open('a', buffering=1) as journal:
                        for line in sys.stdin:
                            action = json.loads(line)
                            if action.get('quit'):
                                receipt['stop_reason'] = action.get('reason', 'requested stop')
                                break
                            if receipt['decisions'] >= 60:
                                raise RuntimeError('60 decision limit reached')
                            number = receipt['decisions'] + 1
                            seconds = float(action.get('seconds', 0))
                            if not 0 <= seconds <= 5:
                                raise ValueError('one batch must last 0 to 5 seconds')
                            row = {'decision': number, 'action': action, 'started': time.time()}
                            pause(False)
                            for key in action.get('tap', []):
                                xdo('key', '--clearmodifiers', key)
                            if 'click' in action:
                                x, y = action['click']
                                xdo('mousemove', '--window', window, x, y, 'click', 1)
                            for key in action.get('keys', []):
                                xdo('keydown', key)
                            dx, dy = action.get('mouse', [0, 0])
                            if dx or dy:
                                xtst.XTestFakeRelativeMotionEvent(connection, int(dx), int(dy), 0)
                                x11.XFlush(connection)
                            time.sleep(seconds)
                            for key in action.get('keys', []):
                                xdo('keyup', key)
                            pause(True)
                            row['ended'] = time.time()
                            receipt['decisions'] = number
                            row['image'] = capture(number)
                            journal.write(json.dumps(row) + '\n')
                            print(json.dumps(row), flush=True)
                            if size(OUT) > 12 * 2**20:
                                raise RuntimeError('evidence budget exceeded')
                    x11.XCloseDisplay(connection)
                finally:
                    try:
                        subprocess.run(['xdotool', 'keyup', 'w', 'a', 's', 'd', 'space', 'Control_L'], env=env, timeout=3, capture_output=True)
                    except Exception:
                        pass
                    if process.poll() is None:
                        os.kill(process.pid, signal.SIGCONT)
                        os.killpg(process.pid, signal.SIGTERM)
                        try:
                            process.wait(timeout=8)
                        except subprocess.TimeoutExpired:
                            os.killpg(process.pid, signal.SIGKILL)
                            process.wait(timeout=3)
                    watch.stop()
                    receipt['engine_exit'] = process.returncode
                    receipt['gpu'] = watch.require()
                    receipt['godot_device'] = nd.require_amd_log((OUT / 'engine.log').read_text())
                    receipt['profile_files'] = [str(p.relative_to(profile)) for p in profile.rglob('*') if p.is_file()]
    except BaseException as error:
        receipt['error'] = repr(error)
        raise
    finally:
        receipt['scratch_bytes_before_cleanup'] = size(scratch)
        shutil.rmtree(scratch)
        receipt['scratch_removed'] = not scratch.exists()
        receipt['engine_remaining'] = bool(process and Path('/proc/%d' % process.pid).exists())
        receipt['native_released'] = display.released if display else None
        receipt['ended'] = time.time()
        dump(OUT / 'run.json', receipt)
        print(json.dumps({'cleanup': receipt['scratch_removed'], 'native_released': receipt['native_released'], 'decisions': receipt['decisions']}), flush=True)

if __name__ == '__main__':
    run()
