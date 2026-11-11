#!/usr/bin/env python3
"""serialized, bounded R21 tether component/production test runner; never uses live imports."""
from __future__ import annotations
import argparse
import fcntl
import gzip
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tarfile
import time

sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[1]
ENGINE = Path('/home/thatmike1/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64')
BASE = 'e6baa995da84d380abc8b8d6a3769b33e771945e'
CAP = 350 * 2**20
ERRORS = re.compile(r'SCRIPT ERROR:|(^|\n)ERROR:|Parse Error:|Failed to load script|ObjectDB instances (?:were )?leaked')


def sha(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def inventory(root):
    return {str(p.relative_to(root)): sha(p) for p in root.rglob('*') if p.is_file() and '.godot' not in p.parts}


def resources():
    roots = list(Path('/tmp').glob('r21-tether*'))
    size = sum(p.stat().st_size for root in roots for p in (root.rglob('*') if root.is_dir() else [root]) if p.is_file())
    mem = int(next(row.split()[1] for row in Path('/proc/meminfo').read_text().splitlines() if row.startswith('MemAvailable:'))) * 1024
    values = dict(scratch=size, home=shutil.disk_usage('/home').free, tmp=shutil.disk_usage('/tmp').free, memory=mem)
    if size > CAP or values['home'] < 15_000_000_000 or values['tmp'] < 1_000_000_000 or mem < 3_000_000_000:
        raise RuntimeError('resource floor/cap: ' + json.dumps(values))
    return values


def snapshot(out):
    source = out / 'source'
    source.mkdir(exist_ok=True)
    # read frozen files directly from Git; no shared cache, checkout mutation or loose inherited edits.
    proc = subprocess.Popen(['git', 'archive', BASE, 'projects/foldrunner'], cwd=PROJECT.parents[1], stdout=subprocess.PIPE)
    with tarfile.open(fileobj=proc.stdout, mode='r|') as archive:
        for entry in archive:
            if entry.name == 'projects':
                continue
            relative = Path(entry.name).relative_to('projects/foldrunner')
            if str(relative) == '.':
                continue
            target = source / relative
            if entry.isdir():
                target.mkdir(exist_ok=True, parents=True)
            elif entry.isfile():
                target.parent.mkdir(exist_ok=True, parents=True)
                with archive.extractfile(entry) as src, target.open('wb') as dst:
                    shutil.copyfileobj(src, dst)
                target.chmod(entry.mode)
            else:
                raise RuntimeError('nonregular Git archive member: ' + entry.name)
    assert proc.wait() == 0
    return source


def preservation(source, production=False):
    lines=subprocess.check_output(['git','ls-tree','-r',BASE,'--','projects/foldrunner'],cwd=PROJECT.parents[1],text=True).splitlines()
    assert lines, 'empty baseline Git preservation query'
    seam=json.loads((PROJECT.parents[2]/'evidence/r21-tether-parent-seam.json').read_text()) if production else {'files':{}}
    approved={'project.godot','scripts/r19_ghost_share.gd'} if production else set()
    rows={}
    for line in lines:
        meta, full=line.split('\t',1)
        mode, kind, oid=meta.split()
        assert kind=='blob' and mode in {'100644','100755'}
        relative=full.removeprefix('projects/foldrunner/')
        data=(source/relative).read_bytes()
        blob=hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
        same=blob==oid
        rows[relative]={'baseline_blob':oid,'executed_sha256':hashlib.sha256(data).hexdigest(),'same':same,'approved_parent_change':relative in approved}
        assert same or (relative in approved and rows[relative]['executed_sha256']==seam['files'][relative]), relative
    return {'ok':True,'baseline':BASE,'baseline_file_count':len(rows),'files':rows}


def overlay(source, production=False):
    if not production:
        for relative in ['project.godot','scripts/r19_ghost_share.gd']:
            (source/relative).write_bytes(subprocess.check_output(['git','show',BASE+':projects/foldrunner/'+relative],cwd=PROJECT))
    paths = [*PROJECT.glob('scripts/r21_tether*.gd'), *PROJECT.glob('tests/r21_tether*')]
    if production:
        paths += [*PROJECT.glob('scripts/r21*.gd'), PROJECT / 'scenes/r21.tscn', PROJECT / 'project.godot', PROJECT / 'scripts/r19_ghost_share.gd']
    if production:
        seam = json.loads((PROJECT.parents[2] / 'evidence/r21-tether-parent-seam.json').read_text())
        assert all(sha(PROJECT / path) == digest for path, digest in seam['files'].items()), 'frozen parent integration bytes changed'
    for path in paths:
        if path.is_file() and not path.name.endswith('.pyc'):
            target = source / path.relative_to(PROJECT)
            shutil.copy2(path, target)


def engine(out, label, script=None, extra=(), production=False, imported=False, mutation=None):
    with open('/tmp/spillway-r21-engine.lock','a') as lock:
        try:
            fcntl.flock(lock,fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise RuntimeError('engine lock occupied; no engine launched') from None
        try:
            return _engine_locked(out,label,script,extra,production,imported,mutation)
        finally:
            fcntl.flock(lock,fcntl.LOCK_UN)


def _engine_locked(out,label,script,extra,production,imported,mutation):
    resources()
    source = out / 'source'
    overlay(source, production)
    if mutation:
        relative, before_text, after_text = mutation
        path = source / relative
        original = path.read_text()
        assert original.count(before_text) == 1, 'mutation must name one exact source site'
        path.write_text(original.replace(before_text, after_text))
    preserved=preservation(source,production)
    target = out / label
    if target.exists():
        raise RuntimeError('refuse existing proof ' + str(target))
    profile = out / 'profiles' / label
    env = os.environ.copy()
    env['HOME'] = str(profile / 'home')
    Path(env['HOME']).mkdir(parents=True)
    for key in ['DATA', 'CONFIG', 'CACHE']:
        env['XDG_' + key + '_HOME'] = str(profile / key.lower())
    argv = [str(ENGINE), '--headless', '--verbose', '--audio-driver', 'Dummy', '--fixed-fps', '128', '--path', str(source)]
    argv += ['--editor', '--import', '--quit'] if imported else ['--script', 'res://tests/' + script, '--', '--out=' + str(target), *extra]
    log_path = out / (label + '.log')
    receipt = dict(preservation=preserved, mutation=mutation, label=label, argv=argv, engine_sha256=sha(ENGINE), before=resources(), source_sha256=inventory(source), scope='production snapshot' if production else 'frozen R20 + component overlay')
    failure = ''
    samples = [receipt['before']]
    started = time.monotonic()
    with log_path.open('x') as log:
        process = subprocess.Popen(argv, cwd=source, env=env, stdout=log, stderr=subprocess.STDOUT)
        try:
            while process.poll() is None:
                samples.append(resources())
                if time.monotonic() - started > 180:
                    raise RuntimeError('engine timeout')
                if ERRORS.search(log_path.read_text()):
                    raise RuntimeError('engine error')
                time.sleep(.25)
        except BaseException as exc:
            failure = str(exc)
            process.terminate()
            try:
                process.wait(timeout=8)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
    for trace_path in target.rglob('trace.jsonl') if target.exists() else []:
        with trace_path.open('rb') as src, gzip.open(str(trace_path)+'.gz', 'wb') as dst:
            shutil.copyfileobj(src,dst)
        trace_path.unlink()
    samples.append(resources())
    receipt['resource_samples'] = len(samples)
    receipt['resource_extrema'] = dict(maximum_scratch_bytes=max(r['scratch'] for r in samples), minimum_home_bytes=min(r['home'] for r in samples), minimum_tmp_bytes=min(r['tmp'] for r in samples), minimum_mem_available_bytes=min(r['memory'] for r in samples))
    receipt.update(exit=process.returncode, failure=failure, seconds=time.monotonic()-started, after=resources(), log_sha256=sha(log_path))
    receipt['ok'] = process.returncode == 0 and not failure and not ERRORS.search(log_path.read_text())
    (out / (label + '.receipt.json')).write_text(json.dumps(receipt, indent=2)+'\n')
    print(label, receipt['ok'], flush=True)
    if not receipt['ok']:
        print(log_path.read_text()[-7000:])
        raise RuntimeError(label)
    return target


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--label', default='import')
    parser.add_argument('--script')
    parser.add_argument('--production', action='store_true')
    parser.add_argument('--cleanup', action='store_true')
    args, extra=parser.parse_known_args()
    out=args.out.resolve()
    if out.parent != Path('/tmp') or not out.name.startswith('r21-tether'):
        parser.error('out must be /tmp/r21-tether*')
    resources()
    out.mkdir(exist_ok=True)
    if args.cleanup:
        for owned in ['source','profiles']:
            if (out / owned).exists():
                shutil.rmtree(out / owned)
        (out / 'CLEANUP.json').write_text(json.dumps(dict(removed=['source','profiles'], resources=resources()),indent=2)+'\n')
        return
    if not (out / 'source/project.godot').exists():
        snapshot(out)
    engine(out,args.label,args.script,[x for x in extra if x != '--'],args.production,args.script is None)


if __name__=='__main__':
    main()
