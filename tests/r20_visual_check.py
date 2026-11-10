#!/usr/bin/env python3
"""run the unchanged R17 visual invariants against a committed R20 host."""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tarfile
import time

PROJECT = Path(__file__).resolve().parents[1]
REPO = PROJECT.parents[1]
ENGINE = Path('/home/thatmike1/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64')
ENGINE_SHA = '8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e'
BASE = '065f7b27993df7ae2511eb34eb665d271dded13c'
MAPS = ['breakwater', 'whiteout-relay', 'sunken-court', 'rainline', 'night-shift', 'practice', 'overflow', 'experiment', 'saltglass', 'tether-yard', 'through-line']
PREFIX = 'projects/foldrunner/'
FLOOR = 15_000_000_000
CAP = 350 * 2**20


def sha(path):
    with Path(path).open('rb') as incoming:
        return hashlib.file_digest(incoming, 'sha256').hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--commit', required=True)
    parser.add_argument('--out', required=True, type=Path)
    args = parser.parse_args()
    assert re.fullmatch('[0-9a-f]{40}', args.commit), 'explicit full committed source required'
    assert sha(ENGINE) == ENGINE_SHA
    out = args.out.resolve()
    assert out.is_relative_to(Path('/tmp')) and not out.exists(), 'new RAM evidence directory required'
    assert shutil.disk_usage('/home').free >= FLOOR
    assert shutil.disk_usage('/tmp').free >= CAP + 100 * 2**20
    assert not subprocess.check_output(['git', 'status', '--porcelain', '--untracked-files=all', '--', '.'], cwd=PROJECT).strip(), 'commit all project work first'
    out.mkdir()
    source = out / 'source'
    source.mkdir()
    original = {}
    blob = subprocess.check_output(['git', 'archive', args.commit, PREFIX], cwd=REPO)
    assert len(blob) < 180 * 2**20
    with tarfile.open(fileobj=io.BytesIO(blob)) as archive:
        for entry in archive:
            assert entry.isdir() or entry.isfile(), 'unsupported source link'
            if not entry.isfile():
                continue
            assert entry.name.startswith(PREFIX)
            relative = entry.name[len(PREFIX):]
            assert '..' not in Path(relative).parts and not Path(relative).is_absolute()
            target = source / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            with archive.extractfile(entry) as incoming, target.open('wb') as outgoing:
                shutil.copyfileobj(incoming, outgoing)
            original[relative] = sha(target)
    del blob
    inherited = (source / 'tests/r17_visual_invariants.gd').read_bytes()
    assert inherited == subprocess.check_output(['git', 'show', BASE + ':' + PREFIX + 'tests/r17_visual_invariants.gd'], cwd=REPO), 'inherited visual checks changed'
    marker = b'const MAIN := preload("res://scripts/r17_main.gd")'
    assert inherited.count(marker) == 1
    adapted = inherited.replace(marker, b'const MAIN := preload("res://scripts/r20_main.gd")')
    adapter = source / 'tests/r20_visual_adapter.gd'
    adapter.write_bytes(adapted)
    (out / 'adapter.gd').write_bytes(adapted)
    (out / 'SOURCE.json').write_text(json.dumps({'commit': args.commit, 'files': original,
        'adapter_sha256': sha(adapter), 'only_fixture_change': 'R17 host preload replaced with R20 host preload'}, indent=2) + '\n')
    shutil.copytree(PROJECT / '.godot', source / '.godot')
    env = dict(os.environ)
    for kind in ['DATA', 'CONFIG', 'CACHE']:
        env['XDG_' + kind + '_HOME'] = str(out / 'profile' / kind.lower())
    stages, peak, minimum = [], 0, shutil.disk_usage('/home').free
    def run(label, command):
        nonlocal peak, minimum
        started = time.monotonic()
        with (out / (label + '.log')).open('w') as log:
            proc = subprocess.Popen(list(map(str, command)), cwd=source, env=env, stdout=log, stderr=subprocess.STDOUT)
            try:
                while proc.poll() is None:
                    minimum = min(minimum, shutil.disk_usage('/home').free)
                    peak = max(peak, sum(p.stat().st_size for p in out.rglob('*') if p.is_file()))
                    assert minimum >= FLOOR and peak <= CAP and time.monotonic() - started <= 180, 'resource bound exceeded'
                    time.sleep(.25)
            finally:
                if proc.poll() is None:
                    proc.terminate()
                    try:
                        proc.wait(5)
                    except subprocess.TimeoutExpired:
                        proc.kill()
                        proc.wait()
        text = (out / (label + '.log')).read_text()
        stages.append({'name': label, 'command': list(map(str, command)), 'exit': proc.returncode})
        assert proc.returncode == 0 and not re.search(r'SCRIPT ERROR:|ERROR:|Parse Error:', text), label + ': ' + text[-4000:]
    try:
        run('import', [ENGINE, '--headless', '--path', source, '--editor', '--import', '--quit'])
        run('visual', [ENGINE, '--headless', '--audio-driver', 'Dummy', '--path', source, '--script', 'res://tests/r20_visual_adapter.gd', '--', '--maps=' + ','.join(MAPS), '--out=' + str(out / 'checks')])
        result = json.loads((out / 'checks/summary.json').read_text())
        assert not result['failures'] and [row['map'] for row in result['maps']] == MAPS
        assert all(sha(source / name) == digest for name, digest in original.items())
        receipt = {'ok': True, 'commit': args.commit, 'engine_sha256': ENGINE_SHA, 'checks': result['checks'], 'maps': MAPS,
                   'source_sha256': original, 'inherited_fixture_sha256': hashlib.sha256(inherited).hexdigest(),
                   'adapter_sha256': sha(adapter), 'only_fixture_change': 'preload scripts/r20_main.gd instead of scripts/r17_main.gd',
                   'stages': stages, 'peak_scratch_bytes': peak, 'minimum_home_free_bytes': minimum,
                   'scope': 'headless inherited visual/state invariants on the R20 host; no native visual-quality claim'}
        (out / 'RESULT.json').write_text(json.dumps(receipt, indent=2) + '\n')
        print(json.dumps({'ok': True, 'checks': result['checks'], 'maps': len(MAPS)}))
    finally:
        shutil.rmtree(source)
        shutil.rmtree(out / 'profile', ignore_errors=True)


if __name__ == '__main__':
    main()
