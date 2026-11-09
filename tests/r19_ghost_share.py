#!/usr/bin/env python3
"""bounded isolated R19 sharing checks; no desktop windows or file manager.

python3 -I tests/r19_ghost_share.py [--native]
"""
import argparse
import importlib.util
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[1]
SCRATCH = Path('/tmp/r19-ghost-share')
ENGINE = Path.home() / '.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64'
FLOOR = 15_000_000_000


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--native', action='store_true')
    args = parser.parse_args()
    if shutil.disk_usage('/home').free < FLOOR:
        raise SystemExit('HOME below 15,000,000,000 bytes; nothing launched')
    with ENGINE.open('rb') as stream:
        engine_hash = hashlib.file_digest(stream, 'sha256').hexdigest()
    if engine_hash != '8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e':
        raise SystemExit('pinned Godot 4.7.2 engine hash differs')
    SCRATCH.mkdir(exist_ok=True)
    stage = SCRATCH / 'source'
    stage.mkdir(exist_ok=True)
    names = subprocess.check_output(['git', 'ls-files', '-co', '--exclude-standard', '-z', '--', '.'], cwd=PROJECT).split(b'\0')
    source_hashes = {}
    for name in sorted(set(n.decode() for n in names if n)):
        src = PROJECT / name
        if src.is_symlink() or not src.is_file():
            raise SystemExit('not a regular source file: ' + name)
        source_hashes[name] = hashlib.sha256(src.read_bytes()).hexdigest()
        dst = stage / name
        dst.parent.mkdir(parents=True, exist_ok=True)
        if not dst.exists() or dst.read_bytes() != src.read_bytes():
            shutil.copy2(src, dst)
    source_bytes = sum((stage / n).stat().st_size for n in source_hashes)
    if source_bytes > 160 * 2**20:
        raise SystemExit('source exceeds initial RAM copy budget')
    env = os.environ.copy()
    env['PYTHONDONTWRITEBYTECODE'] = '1'
    for key in ['DATA', 'CONFIG', 'CACHE', 'STATE']:
        folder = SCRATCH / ('xdg-' + key.lower())
        folder.mkdir(exist_ok=True)
        env['XDG_' + key + '_HOME'] = str(folder)
    evidence = SCRATCH / ('native' if args.native else 'headless')
    if evidence.exists():
        shutil.rmtree(evidence)
    evidence.mkdir()
    commands = []

    def run(label, cmd, child_env=env):
        commands.append([str(v) for v in cmd])
        with (evidence / (label + '.log')).open('w') as stream:
            result = subprocess.run(cmd, env=child_env, stdout=stream, stderr=subprocess.STDOUT, timeout=180, cwd=SCRATCH)
        text = (evidence / (label + '.log')).read_text()
        if result.returncode or 'SCRIPT ERROR' in text:
            print('\n'.join(line for line in text.splitlines() if any(word in line for word in ['ERROR', 'at:', 'FAIL', 'failed'])))
            raise SystemExit(label + ' failed')
        print('PASS ' + label, flush=True)
        return text

    run('import', [ENGINE, '--headless', '--audio-driver', 'Dummy', '--path', stage, '--import'])
    cmd = [ENGINE, '--audio-driver', 'Dummy', '--path', stage, '--fixed-fps', '128', '--script', 'res://tests/r19_ghost_share.gd']
    user_args = ['--', '--out=' + str(evidence)]
    if args.native:
        nd = load('r19_nd', stage / 'tools/r14_native_display.py')
        nd.MIN_FREE_GIB = FLOOR / 2**30
        with nd.NativeDisplay(evidence / 'display', displays=range(190, 200), min_free_gib=FLOOR / 2**30) as display:
            child_env = display.child_env(env)
            watch = display.gpu_watch()
            try:
                run('suite', cmd + ['--display-driver', 'x11', '--rendering-driver', 'opengl3', '--windowed', '--resolution', '1280x720'] + user_args, child_env)
            finally:
                watch.stop()
            gpu = watch.verdict()
            (evidence / 'gpu.json').write_text(json.dumps(gpu, indent=2))
            if not gpu['ok']:
                raise SystemExit('native GPU work unproven')
    else:
        run('suite', cmd + ['--headless'] + user_args)
    changed = [n for n, h in source_hashes.items() if not (stage / n).is_file() or hashlib.sha256((stage / n).read_bytes()).hexdigest() != h]
    (evidence / 'SOURCE.json').write_text(json.dumps({'mode': 'worktree snapshot', 'engine_sha256': engine_hash, 'source': source_hashes, 'changed': changed}, indent=1))
    if changed:
        raise SystemExit('snapshot changed during execution: ' + repr(changed))
    reader = load('r19_reader', stage / 'tools/analyze-r16-runs.py')
    cross = []
    for path in sorted(evidence.glob('cross-*.r16run')):
        run_data = reader.read(path)
        cross.append({'file': path.name, 'ok': run_data.ok, 'status': run_data.status})
    if not cross or not all(r['ok'] for r in cross):
        raise SystemExit('Python cross-reader failed: ' + repr(cross))
    (evidence / 'python-reader.json').write_text(json.dumps(cross, indent=2))
    (evidence / 'commands.json').write_text(json.dumps(commands, indent=2))
    summary = json.loads((evidence / 'summary.json').read_text())
    size = sum(p.stat().st_size for p in SCRATCH.rglob('*') if p.is_file())
    if summary['failed'] or size >= 350 * 2**20:
        raise SystemExit('failed checks or scratch budget exceeded')
    print(json.dumps({'checks': summary['checks'], 'failed': summary['failed'], 'cross_reader': len(cross), 'scratch_bytes': size, 'evidence': str(evidence)}))


if __name__ == '__main__':
    main()
