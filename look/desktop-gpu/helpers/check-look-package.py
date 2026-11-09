#!/usr/bin/env python3
"""check the extracted ZIP on a private AMD display, using only OS keys and screenshots."""
import argparse
import json
import os
import subprocess
import sys
import tempfile
import time
import zipfile
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import r14_native_display as nd

p = argparse.ArgumentParser()
p.add_argument('--zip', type=Path, required=True)
p.add_argument('--out', type=Path, required=True)
a = p.parse_args()
a.out.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix='spillway-look-exact-zip-') as scratch:
    root = Path(scratch)
    with zipfile.ZipFile(a.zip) as archive:
        archive.extractall(root)
    folder = root / 'SpillwayLookC-linux-x86_64'
    runtime = folder / 'SpillwayLookC.x86_64'
    runtime.chmod(0o755)
    manifest = json.loads((folder/'BUILD.json').read_text())
    assert nd.digest(runtime) == manifest['runtime_sha256']
    assert nd.digest(folder/'SpillwayLookC.pck') == manifest['pack_sha256']
    empty = root/'empty'
    empty.mkdir()
    with nd.NativeDisplay(a.out, min_free_gib=15_000_000_000/2**30) as display:
        env = display.child_env(dict(os.environ))
        for name in ('data', 'cache', 'config', 'state', 'runtime'):
            path = root/name
            path.mkdir(mode=0o700)
            env['XDG_'+name.upper()+('_DIR' if name=='runtime' else '_HOME')] = str(path)
        def control(*args):
            return subprocess.check_output([str(x) for x in args], env=env, text=True, stderr=subprocess.STDOUT, timeout=10)
        watch = nd.GpuWatch()
        with (a.out/'engine.log').open('w') as log:
            process = subprocess.Popen(['stdbuf', '-oL', str(runtime), '--verbose', '--display-driver', 'x11', '--audio-driver', 'Dummy', '--windowed', '--resolution', '1280x720', '--position', '0,0'], cwd=empty, env=env, stdout=log, stderr=subprocess.STDOUT)
            watch.follow(process.pid)
            try:
                window = None
                for _ in range(200):
                    result = subprocess.run(['xdotool', 'search', '--onlyvisible', '--pid', str(process.pid)], env=env, capture_output=True, text=True, timeout=5)
                    for candidate in result.stdout.splitlines():
                        if 'look c experiment' in control('xdotool','getwindowname',candidate).lower():
                            window = candidate
                            break
                    if window:
                        break
                    time.sleep(.1)
                if window is None:
                    raise RuntimeError('no experimental release window')
                control('xdotool','windowfocus','--sync',window)
                time.sleep(4)
                control('xdotool','mousemove','--window',window,'640','360','click','1')
                time.sleep(.5)
                for name in ('new','old','restored'):
                    if name != 'new':
                        control('xdotool','keydown','l')
                        time.sleep(.25)
                        control('xdotool','keyup','l')
                        time.sleep(.6)
                    control('ffmpeg','-y','-f','x11grab','-framerate','30','-video_size','1280x720','-draw_mouse','0','-i',env['DISPLAY']+'+0,0','-frames:v','4','-update','1',a.out/(name+'.png'))
                # the normal headless startup separately proves the app's clean quit path.
                process.terminate()
                process.wait(timeout=10)
            finally:
                if process.poll() is None:
                    process.kill()
                    process.wait()
                watch.stop()
        text = (a.out/'engine.log').read_text()
        nd.require_amd_log(text)
        gpu = watch.require()
        if 'ERROR' in text or 'look-c: spillway-look-c-1' not in text:
            raise RuntimeError(text)
        (a.out/'check.json').write_text(json.dumps({'zip_sha256':nd.digest(a.zip),'source_commit':manifest['source_commit'],'runtime_sha256':nd.digest(runtime),'pack_sha256':manifest['pack_sha256'],'gpu':gpu,'method':'exact ZIP extracted into RAM, executable launched from an empty directory, no source path or pack override; OS L twice, inspect new/old/restored.png; process terminated by harness after capture','frames':{p.name:nd.digest(p) for p in a.out.glob('*.png')}},indent=2)+'\n')
