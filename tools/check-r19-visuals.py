#!/usr/bin/env python3
"""run every inherited visual invariant against the real R19 host and explicit complete catalog."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

PROJECT = Path(__file__).resolve().parents[1]
ENGINE = Path.home() / '.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64'
MAPS = ['breakwater', 'whiteout-relay', 'sunken-court', 'rainline', 'night-shift', 'practice',
        'overflow', 'experiment', 'saltglass', 'tether-yard', 'fall-line', 'line-drive']


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    out = args.out.resolve()
    if not out.is_relative_to('/tmp') or out.exists():
        parser.error('use a fresh output directory under /tmp')
    if shutil.disk_usage('/home').free < 15_000_000_000:
        raise SystemExit('HOME free-space floor failed before launch')
    assert sha(ENGINE) == '8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e'
    original = PROJECT / 'tests/r17_visual_invariants.gd'
    source = original.read_text()
    before = 'const MAIN := preload("res://scripts/r17_main.gd")'
    after = 'const MAIN := preload("res://scripts/r19_main.gd")'
    assert source.count(before) == 1
    adapted = source.replace(before, after)
    assert adapted.replace(after, before) == source
    out.mkdir(parents=True)
    fixture = out / 'inherited-invariants-r19-host.gd'
    fixture.write_text(adapted)
    names = ['tests/r17_visual_invariants.gd', 'scripts/r19_main.gd', 'scripts/r19_hud.gd',
             'scripts/r19_map_catalog.gd', 'scripts/r17_look.gd', 'scripts/r17_contours.gd']
    hashes = {name: sha(PROJECT/name) for name in names}
    env = dict(os.environ)
    for key in ['DATA', 'CONFIG', 'CACHE']:
        env['XDG_'+key+'_HOME'] = str(out/key.lower())
    command = [str(ENGINE), '--headless', '--audio-driver', 'Dummy', '--path', str(PROJECT),
               '--script', str(fixture), '--', '--maps='+','.join(MAPS), '--out='+str(out)]
    with (out/'engine.log').open('w') as log:
        result = subprocess.run(command, env=env, cwd=out, stdout=log, stderr=subprocess.STDOUT, timeout=120)
    log = (out/'engine.log').read_text()
    summary = json.loads((out/'summary.json').read_text())
    assert result.returncode == 0 and not summary['failures'] and 'SCRIPT ERROR' not in log
    assert hashes == {name: sha(PROJECT/name) for name in names}
    (out/'SOURCE.json').write_text(json.dumps({'source': hashes, 'engine_sha256': sha(ENGINE),
        'derived_fixture_sha256': sha(fixture), 'only_change': [before, after], 'command': command,
        'maps': MAPS, 'scope': 'headless inherited invariant suite on actual R19 host; native route evidence is separate'}, indent=2)+'\n')
    print(json.dumps({'ok': True, 'checks': summary['checks'], 'maps': len(MAPS), 'evidence': str(out)}))


if __name__ == '__main__':
    main()
