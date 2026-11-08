#!/usr/bin/env python3
"""freeze the reviewed parent, run bounded headless challenges and retain small receipts."""
import argparse
import gzip
import hashlib
import io
import json
import os
import re
from pathlib import Path
import shutil
import signal
import subprocess
import tarfile
import tempfile
import time

PARENT = 'f3f234525ea01d53c3cedf818530621d24dc0bd1'
ENGINE = Path.home() / '.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def hashes(project):
    return {str(p.relative_to(project)): digest(p) for folder in ('scripts', 'tools', 'tests')
            for p in sorted((project / folder).rglob('*')) if p.is_file() and p.suffix != '.pyc'
            and not p.name.startswith('r15_experiment_review')}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=False)
    project = Path(__file__).resolve().parents[1]
    top = Path(subprocess.check_output(['git', 'rev-parse', '--show-toplevel'], cwd=project, text=True).strip())
    prefix = project.relative_to(top).as_posix()
    before = hashes(project)
    # the frozen parent, rather than a concurrently edited checkout, is the review subject.
    scratch = Path(tempfile.mkdtemp(prefix='r15-experiment-review-', dir='/tmp'))
    profile = scratch / 'profile'
    source = scratch / 'source'
    source.mkdir()
    results = scratch / 'results'
    results.mkdir()
    receipts = {'parent': PARENT, 'engine_sha256': digest(ENGINE), 'before': before, 'commands': [], 'runs': [], 'scratch': str(scratch), 'home_free_bytes_before': shutil.disk_usage(Path.home()).free}
    try:
        archive = subprocess.check_output(['git', 'archive', PARENT + ':' + prefix], cwd=top)
        with tarfile.open(fileobj=io.BytesIO(archive)) as tar:
            tar.extractall(source, filter='data')
        del archive
        for p in sorted((project / 'tests').glob('r15_experiment_review*')):
            if p.is_file():
                shutil.copy2(p, source / 'tests' / p.name)
        receipts['frozen'] = hashes(source)
        receipts['owned'] = {p.name: digest(p) for p in sorted((project / 'tests').glob('r15_experiment_review*')) if p.is_file()}
        env = os.environ | {'XDG_DATA_HOME': str(profile / 'data'), 'XDG_CONFIG_HOME': str(profile / 'config'),
                            'XDG_CACHE_HOME': str(profile / 'cache')}
        env.pop('DISPLAY', None)
        env.pop('WAYLAND_DISPLAY', None)
        for label, budget, extra in [('import', 90, ['--import']), ('review', 90,
                ['--fixed-fps', '128', '--script', 'res://tests/r15_experiment_review.gd', '--', '--out=' + str(results)])]:
            command = [str(ENGINE), '--headless', '--audio-driver', 'Dummy', '--path', str(source)] + extra
            receipts['commands'].append(command)
            start = time.monotonic()
            with (out / (label + '.log')).open('wb') as log:
                child = subprocess.Popen(command, cwd=source, env=env, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
                try:
                    code = child.wait(timeout=budget)
                except subprocess.TimeoutExpired:
                    os.killpg(child.pid, signal.SIGTERM)
                    try:
                        child.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        os.killpg(child.pid, signal.SIGKILL)
                        child.wait(timeout=5)
                    code = 124
            errors = re.findall(r'^.*(?:SCRIPT ERROR:|ERROR:|Parse Error:|Failed to load script).*$', (out / (label + '.log')).read_text(), flags=re.M)
            receipts['runs'].append({'engine_errors': errors, 'label': label, 'returncode': code, 'seconds': time.monotonic() - start, 'pid': child.pid})
            if code and label == 'import':
                break
        uid = source / 'tests/r15_experiment_review.gd.uid'
        if uid.exists() and not (project / 'tests' / uid.name).exists():
            shutil.copy2(uid, project / 'tests' / uid.name)
    finally:
        receipts['frozen_after'] = hashes(source)
        receipts['after'] = hashes(project)
        receipts['actors_helpers_unchanged'] = receipts['before'] == receipts['after']
        receipts['generated_uids'] = sorted(receipts['frozen_after'].keys() - receipts.get('frozen', {}).keys())
        receipts['frozen_unchanged'] = all(receipts['frozen_after'].get(k) == v for k, v in receipts.get('frozen', {}).items())
        for path in results.iterdir():
            if path.suffix == '.cfg':
                receipts.setdefault('record_payloads', {})[path.name] = {'sha256': digest(path), 'content': path.read_text()}
            elif path.suffix == '.jsonl':
                with path.open('rb') as src, gzip.open(out / (path.name + '.gz'), 'wb', compresslevel=9) as dest:
                    shutil.copyfileobj(src, dest)
            else:
                shutil.copy2(path, out / path.name)
        shutil.rmtree(scratch)
        receipts['scratch_removed'] = not scratch.exists()
        retained_harness = out / 'harness'
        retained_harness.mkdir()
        for p in sorted((project / 'tests').glob('r15_experiment_review*')):
            if p.is_file():
                shutil.copy2(p, retained_harness / p.name)
        receipts['owned_after'] = {p.name: digest(p) for p in sorted((project / 'tests').glob('r15_experiment_review*')) if p.is_file()}
        receipts['home_free_bytes_after'] = shutil.disk_usage(Path.home()).free
        receipts['child_pids_absent'] = all(not Path('/proc/' + str(r['pid'])).exists() for r in receipts['runs'])
        for path in out.glob('*.jsonl'):
            with path.open('rb') as src, gzip.open(str(path) + '.gz', 'wb', compresslevel=9) as dest:
                shutil.copyfileobj(src, dest)
            path.unlink()
        (out / 'receipt.json').write_text(json.dumps(receipts, indent=2) + '\n')
    print(json.dumps({k: receipts[k] for k in ['runs', 'actors_helpers_unchanged', 'frozen_unchanged', 'scratch_removed']}, indent=2))
    return 1 if any(r['returncode'] or r['engine_errors'] for r in receipts['runs']) else 0


if __name__ == '__main__':
    raise SystemExit(main())
