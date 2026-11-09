#!/usr/bin/env bash
# r16 source checks on an external RAM snapshot; exported acceptance is check-r16-pack.sh.
set -euo pipefail
project="$(cd "$(dirname "$0")/.." && pwd)"
exec python3 -I - "$project" "$@" <<'PY'
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tempfile

project = Path(sys.argv[1])
spec = importlib.util.spec_from_file_location('r16_delivery', project / 'tools/package-r16.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
p = argparse.ArgumentParser(description='freeze source in RAM and run R16 component, host and identity gates; no pack acceptance')
p.add_argument('--out', required=True, type=Path)
p.add_argument('--source', choices=('head', 'worktree'), default='head')
p.add_argument('--route', action='append', default=[], type=m.parse_route)
p.add_argument('--allow-r15-default', action='store_true', help='labelled development only; explicitly launch R16 without editing the snapshot')
p.add_argument('--components-only', action='store_true', help='development only; omits full course route coverage')
p.add_argument('--scratch', type=Path, default=Path('/dev/shm'))
a = p.parse_args(sys.argv[2:])
out = a.out.resolve()
top = Path(m.git('rev-parse', '--show-toplevel').strip())
if out == top or top in out.parents or (out.exists() and any(out.iterdir())):
    p.error('--out must be new or empty, outside the checkout')
if not a.components_only:
    pairs = {(r['map'], r['preset']) for r in a.route}
    if any((course, 'server128') not in pairs for course in m.REQUIRED_COURSES) or not any(preset == 'server128_aa1000' for _, preset in pairs):
        p.error('full source check requires F2 on every course and an F5 comparison; use --components-only for development')
if not m.EDITOR.is_file() or m.digest(m.EDITOR) != m.EDITOR_SHA256:
    p.error('pinned Godot editor is absent or differs')
out.mkdir(parents=True, exist_ok=True)
stage = None
checks = []
cancelled = False
source_hashes = {}

def run(name, command, deadline=240, errors=True):
    log = out / (name + '.log')
    code, text = m.run_engine(command, stage, m.engine_env(stage / '_profiles' / name), log, deadline, cleanup_grace=35)
    ok = code == 0 and (not errors or not m.ERRORS.search(text))
    checks.append({'name': name, 'ok': ok, 'exit': code, 'log': str(log)})
    print(('PASS ' if ok else 'FAIL ') + name, flush=True)
    if not ok:
        raise m.Rejected(name + ': see ' + str(log))

try:
    with m.cancellation_signals():
        stage = Path(tempfile.mkdtemp(prefix='r16-source-', dir=a.scratch))
        if a.source == 'head':
            data = m.source_archive(m.git('rev-parse', 'HEAD').strip(), str(project.relative_to(top)), top)
            import io
            with tarfile.open(fileobj=io.BytesIO(data)) as archive:
                archive.extractall(stage, filter='data')
        else:
            names = m.git('ls-files', '-co', '--exclude-standard', '-z', '--', '.', binary=True).split(b'\0')
            names = sorted(set(os.fsdecode(n) for n in names if n))
            size = sum((project / n).stat().st_size for n in names)
            if size > 160 * 2**20:
                raise m.Rejected('source exceeds 160 MiB; 400 MiB RAM scratch budget would need review')
            for name in names:
                src, dst = project / name, stage / name
                if src.is_symlink() or not src.is_file():
                    raise m.Rejected('source entry is not a regular file: ' + name)
                dst.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(src, dst)
        source_hashes = {str(f.relative_to(stage)): m.digest(f) for f in stage.rglob('*') if f.is_file()}
        (out / 'SOURCE.json').write_text(json.dumps({'mode': a.source, 'head': m.git('rev-parse', 'HEAD').strip(),
            'development_only': a.source == 'worktree' or a.allow_r15_default or a.components_only,
            'helpers_sha256': m.helper_hashes(), 'source_sha256': source_hashes}, indent=1) + '\n')
        run('import', [m.EDITOR, '--headless', '--audio-driver', 'Dummy', '--path', stage, '--import'])
        # the source command owns preservation, all eight identities and the actual-host feature probe.
        command = [sys.executable, '-I', project / 'tools/package-r16.py', 'source', '--source', stage,
                   '--evidence', out / 'source', '--git-project', project]
        if a.allow_r15_default:
            command.append('--allow-r15-default')
        for route in a.route:
            fields = dict(route)
            if 'game_diff' in fields:
                fields['game_diff'] = '+'.join(str(tick) for tick in fields['game_diff'])
            value = ','.join(str(k) + '=' + str(v) for k, v in fields.items())
            command += ['--route', value]
        run('source', command, 1800)
        for name, script in [('style', 'test_r16_style.gd'), ('lab-host', 'r16_delivery_lab.gd'), ('visibility', 'r16_delivery_visibility_run.gd')]:
            run(name, [m.EDITOR, '--headless', '--audio-driver', 'Dummy', '--fixed-fps', '128', '--path', stage,
                       '--script', 'res://tests/' + script, '--', '--out=' + str(out / name)], 300)
            summary = json.loads((out / name / 'summary.json').read_text())
            if summary.get('failed') != 0 or (len(summary['checks']) if isinstance(summary.get('checks'), list) else summary.get('checks', 0)) < 1:
                raise m.Rejected(name + ': missing or failed assertion summary')
        run('loop', [sys.executable, '-I', stage / 'tests/test_r16_loop.py', '--project', stage, '--out', out / 'loop'], 300)
        run('record', [m.EDITOR, '--headless', '--audio-driver', 'Dummy', '--fixed-fps', '128', '--path', stage,
                      '--script', 'res://tests/test_r16_record.gd', '--', '--out=' + str(out / 'record')], errors=False)
        run('record-format', [sys.executable, '-I', stage / 'tests/test_r16_record_format.py', '--run', out / 'record',
                             '--out', out / 'record-format.json', '--log', out / 'record.log', '--godot', m.EDITOR, '--project', stage])
        run('delivery-components', [sys.executable, '-I', stage / 'tests/test_r16_delivery.py', '--out', out / 'components.json', '--feature-run', out / 'source/features'])
        changes = [name for name, digest in source_hashes.items() if not (stage / name).is_file() or m.digest(stage / name) != digest]
        if changes:
            raise m.Rejected('frozen source changed during execution: ' + str(changes))
        print('R16 source checks passed; Linux exact-pack and Windows native execution remain separate', flush=True)
except (m.Rejected, OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
    checks.append({'name': 'source wrapper', 'ok': False, 'error': str(error)})
    print(str(error), file=sys.stderr)
except KeyboardInterrupt:
    cancelled = True
    checks.append({'name': 'source wrapper', 'ok': False, 'error': 'cancelled'})
finally:
    if stage is not None:
        shutil.rmtree(stage, ignore_errors=True)
    m.compress_evidence(out)
    (out / 'RESULTS.json').write_text(json.dumps({'checks': checks, 'ok': bool(checks) and all(c['ok'] for c in checks),
        'source_removed': stage is None or not stage.exists(), 'scope': 'frozen source only; no R16 packed acceptance'}, indent=2) + '\n')
sys.exit(130 if cancelled else 0 if checks and all(c['ok'] for c in checks) else 1)
PY
