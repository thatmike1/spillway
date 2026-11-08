#!/usr/bin/env python3
"""own a private native display and expose only screenshots to the player actor."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

sys.dont_write_bytecode = True
from r14_native_display import NativeDisplay, GpuWatch, require_amd_log

ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = Path('/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r14/discovery-readability')
ENGINE = Path.home() / '.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64'

def wait_view(inbox, ident, game):
    deadline = time.monotonic() + 30
    while time.monotonic() < deadline:
        response = inbox / 'response.json'
        if response.exists():
            result = json.loads(response.read_text())
            if result.get('id') == ident:
                print(json.dumps(result), flush=True)
                return
        if game.poll() is not None:
            raise RuntimeError('game exited: see engine.log')
        time.sleep(.05)
    raise TimeoutError('no screenshot response in 30 seconds')

EVIDENCE.mkdir(parents=True, exist_ok=True)
inbox = EVIDENCE / 'views2'
inbox.mkdir()
profile = EVIDENCE / 'profile2'
profile.mkdir()
count = 6
with NativeDisplay(EVIDENCE / 'native2', displays=(191, 192, 193, 194, 195, 196, 197, 198, 199)) as display:
    env = display.child_env(dict(os.environ, XDG_DATA_HOME=str(profile), XDG_CONFIG_HOME=str(profile / 'config'), XDG_CACHE_HOME=str(profile / 'cache')))
    cmd = [str(ENGINE), '--path', str(ROOT), '--windowed', '--resolution', '1280x720', '--audio-driver', 'Dummy', '--rendering-driver', 'opengl3', '--fixed-fps', '30', '--script', str(ROOT / 'tools/r14_discovery_readability.gd'), '--', '--no-records', '--inbox=' + str(inbox)]
    with (EVIDENCE / 'engine2.log').open('w') as log:
        game = subprocess.Popen(cmd, env=env, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
        watch = GpuWatch().follow(game.pid)
        try:
            print(json.dumps({'display': display.display, 'pid': game.pid, 'source': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(), 'free_home_bytes': shutil.disk_usage(Path.home()).free}), flush=True)
            wait_view(inbox, 'initial', game)
            for line in sys.stdin:
                request = json.loads(line)
                if request.get('quit'):
                    (inbox / 'request.json').write_text(json.dumps({'quit': True}))
                    game.wait(10)
                    break
                count += 1
                if count > 60:
                    raise RuntimeError('60-decision bound exceeded')
                request['id'] = '%02d' % count
                assert set(request.get('keys', [])) <= {'w', 'a', 's', 'd', 'space', 'ctrl'}
                assert set(request.get('tap', [])) <= {'r', 'f', 'esc', 'f1', 'f2', 'f3', 'f4', 'f5', 'space'}
                assert 1 <= request.get('frames', 1) <= 90
                temp = inbox / 'request.json.tmp'
                temp.write_text(json.dumps(request))
                temp.replace(inbox / 'request.json')
                wait_view(inbox, request['id'], game)
        finally:
            if game.poll() is None:
                game.terminate()
                game.wait(10)
            watch.stop()
            (EVIDENCE / 'gpu2.json').write_text(json.dumps(watch.require(), indent=2))
            (EVIDENCE / 'renderer2.json').write_text(json.dumps(require_amd_log((EVIDENCE / 'engine2.log').read_text()), indent=2))
            shutil.rmtree(profile)
print(json.dumps({'stopped': True, 'decisions': count, 'desktop_ok': display.record.get('desktop_after', {}).get('ok'), 'clean': display.released}), flush=True)
