#!/usr/bin/env python3
"""screenshot-only input runner against the promoted packed delivery."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import zipfile
sys.dont_write_bytecode = True
from r14_native_display import NativeDisplay, GpuWatch, require_amd_log
ROOT = Path(__file__).resolve().parents[1]
OUTER = Path('/home/thatmike1/foldrunner-build-2026-11-05')
EVIDENCE = OUTER / 'checkpoints/spillway/r14/discovery-delivered'
ENGINE = Path.home() / '.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64'
ARCHIVE = OUTER / 'delivery/spillway-r14/spillway-2026.11.08-r14-linux-x86_64-65d205be.zip'
EXPECTED = 'fc77461baa5387549ce7ec2b5c2796d656b83aaf2a8fd1e8674d614a7b0b0067'

def wait_view(inbox, ident, game):
    deadline = time.monotonic() + 30
    while time.monotonic() < deadline:
        response = inbox / 'response.json'
        if response.exists():
            result = json.loads(response.read_text())
            if result.get('id') == ident:
                assert set(result) == {'id', 'image'}
                print(json.dumps(result), flush=True)
                return
        if game.poll() is not None:
            raise RuntimeError('game exited; see engine.log')
        time.sleep(.05)
    raise TimeoutError('no screenshot response in 30 seconds')

EVIDENCE.mkdir(parents=True, exist_ok=True)
count = 0
with tempfile.TemporaryDirectory(prefix='r14-delivered-', dir='/tmp') as temp:
    scratch = Path(temp)
    inbox = scratch / 'views'
    inbox.mkdir()
    profile = scratch / 'profile'
    profile.mkdir()
    with zipfile.ZipFile(ARCHIVE) as archive:
        pack = scratch / 'SpillwayR14.pck'
        pack.write_bytes(archive.read('SpillwayR14-linux-x86_64/SpillwayR14.pck'))
    assert hashlib.sha256(pack.read_bytes()).hexdigest() == EXPECTED
    shutil.copy(ROOT / 'tools/r14_discovery_delivered.gd', scratch / 'adapter.gd')
    identity = {'archive': str(ARCHIVE), 'archive_sha256': hashlib.sha256(ARCHIVE.read_bytes()).hexdigest(), 'pack_sha256': EXPECTED, 'source': '65d205be', 'engine': str(ENGINE), 'engine_sha256': hashlib.sha256(ENGINE.read_bytes()).hexdigest(), 'mode': 'editor-hosted packed play', 'free_home_bytes_before': shutil.disk_usage(Path.home()).free, 'scratch': str(scratch)}
    (EVIDENCE / 'identity.json').write_text(json.dumps(identity, indent=2))
    with NativeDisplay(scratch / 'native', displays=tuple(range(190, 200))) as display:
        env = display.child_env(dict(os.environ, XDG_DATA_HOME=str(profile), XDG_CONFIG_HOME=str(profile / 'config'), XDG_CACHE_HOME=str(profile / 'cache'), TMPDIR=str(scratch)))
        cmd = [str(ENGINE), '--main-pack', str(pack), '--windowed', '--resolution', '1280x720', '--audio-driver', 'Dummy', '--rendering-driver', 'opengl3', '--fixed-fps', '30', '--script', str(scratch / 'adapter.gd'), '--', '--no-records', '--inbox=' + str(inbox)]
        identity['command'] = cmd
        identity['display'] = display.display
        (EVIDENCE / 'identity.json').write_text(json.dumps(identity, indent=2))
        with (scratch / 'engine.log').open('w') as log:
            game = subprocess.Popen(cmd, cwd=scratch, env=env, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
            watch = GpuWatch().follow(game.pid)
            try:
                wait_view(inbox, 'initial', game)
                for line in sys.stdin:
                    request = json.loads(line)
                    if request.get('quit'):
                        (inbox / 'request.json').write_text(json.dumps({'quit': True}))
                        game.wait(10)
                        break
                    count += 1
                    if count > 80:
                        raise RuntimeError('80-decision bound exceeded')
                    request['id'] = '%02d' % count
                    assert set(request.get('keys', [])) <= {'w', 'a', 's', 'd', 'space', 'ctrl'}
                    assert set(request.get('tap', [])) <= {'r', 'f', 'esc', 'f1', 'f2', 'f3', 'f4', 'f5', 'space'}
                    assert 1 <= request.get('frames', 1) <= 90
                    temp_request = inbox / 'request.json.tmp'
                    temp_request.write_text(json.dumps(request))
                    temp_request.replace(inbox / 'request.json')
                    wait_view(inbox, request['id'], game)
            finally:
                if game.poll() is None:
                    game.terminate()
                    game.wait(10)
                watch.stop()
                (EVIDENCE / 'gpu.json').write_text(json.dumps(watch.require(), indent=2))
                (EVIDENCE / 'renderer.json').write_text(json.dumps(require_amd_log((scratch / 'engine.log').read_text()), indent=2))
                shutil.copy(inbox / 'inputs.jsonl', EVIDENCE / 'inputs.jsonl')
                shutil.copy(scratch / 'engine.log', EVIDENCE / 'engine.log')
                for selected in json.loads((EVIDENCE / 'selected.json').read_text()) if (EVIDENCE / 'selected.json').exists() else ['initial']:
                    shutil.copy(inbox / (selected + '.jpg'), EVIDENCE / (selected + '.jpg'))
    shutil.copy(scratch / 'native/native-display.json', EVIDENCE / 'native-display.json')
    print(json.dumps({'stopped': True, 'decisions': count, 'desktop_ok': display.record.get('desktop_after', {}).get('ok'), 'clean': display.released, 'scratch_removed_after_exit': str(scratch)}), flush=True)
