#!/usr/bin/env python3
"""negative delivery controls for the r15 package tool: each hazard must reach its own refusal.

ownership: cancellation at the engine and Xvfb acquisition boundary, the held-display refusal
and the storage floor; in process, no engine. provenance: the candidate's own BUILD.json
resolves against git, and each changed identity field is refused by verify_source_manifest.
preflight: a disposable sparse clone (objects shared, never copied) gets one deliberate break
per case and its own `package-r15.py package` must refuse before writing anything; the
unmutated clone passes the same preflight. baseline: the unmutated candidate passes every
static check of the actual check_package (native runs are the root's positive job and are
stubbed here only). contents: copies of the candidate ZIPs get one break each, with
checksums and manifests made consistent where the break must reach a later check, and
`package-r15.py check` must fail on exactly the named static checks. runtime: packs exported
from the candidate's exact committed source with one break each, and one manifest-only
record-key lie, must fail the shipped startup or the release probe on the private AMD/X11
backend. cancel: SIGTERM to the checker alone during the native controls run must release
the engine, weston, Xwayland, the display files and the runtime directory.

candidate bytes are read from --candidate and verified against --base-manifest first; they
are never written. bulky copies live in --scratch (outside Git, bounded); --evidence keeps
summaries, gzipped logs and hashes only.

python3 -I tests/test_r15_delivery.py --candidate DIR --base-manifest NEGATIVE-BASE.json \
    --evidence NEW_DIR --scratch RAM_DIR [--only ownership provenance preflight baseline contents runtime cancel]
"""
import argparse
import copy
import gzip
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import tarfile
import tempfile
import time
from unittest.mock import patch
import zipfile

PROJECT = Path(__file__).resolve().parents[1]
TOOL = PROJECT / 'tools/package-r15.py'
spec = importlib.util.spec_from_file_location('package_r15', TOOL)
pr = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pr)
ORIGINAL_SIGNALS = {sig: signal.getsignal(sig) for sig in (signal.SIGINT, signal.SIGTERM)}
# p / storage steering for this suite: scratch stays under 1 GiB and /tmp keeps room for the
# root's positive run and the other delegates.
SCRATCH_LIMIT = 1 << 30
TMP_FLOOR = int(1.2 * (1 << 30))
L, W = 'linux-x86_64: ', 'windows-x86_64: '
FOLDERS = {'linux': pr.NAME + '-linux-x86_64', 'windows': pr.NAME + '-windows-x86_64'}
results = []
ARGS = None
RESULT_PATH = None


def check(name, ok, detail='', group=''):
    results.append({'group': group, 'name': name, 'ok': bool(ok), 'detail': detail})
    if RESULT_PATH is not None:
        temporary = RESULT_PATH.with_suffix('.json.tmp')
        temporary.write_text(json.dumps(results, indent=2, ensure_ascii=False, default=str) + '\n')
        temporary.replace(RESULT_PATH)
    print('%s %s%s' % ('PASS' if ok else 'FAIL', name, '' if detail in ('', None) else ' (%s)' % str(detail)[:300]), flush=True)
    return ok


def refused(name, call, expected, group):
    try:
        call()
    except (pr.Rejected, argparse.ArgumentTypeError) as error:
        return check(name, expected in str(error), str(error), group)
    return check(name, False, 'accepted', group)


def du(path):
    """bytes this suite owns under path; hard links to the immutable candidate cost nothing."""
    path = Path(path)
    return sum(p.lstat().st_size for p in path.rglob('*') if p.is_file() and not p.is_symlink() and p.lstat().st_nlink == 1) if path.exists() else 0


def budget(what):
    """scratch and /tmp limits before every bulky step; a breach stops the suite, never the root."""
    used, free = du(ARGS.scratch), shutil.disk_usage(ARGS.scratch).free
    if used > SCRATCH_LIMIT or free < TMP_FLOOR:
        raise SystemExit('storage limit before %s: scratch %.2f GiB, %s free %.2f GiB' % (what, used / 2 ** 30, ARGS.scratch, free / 2 ** 30))
    return {'scratch_bytes': used, 'tmp_free_bytes': free}


def gz(source, target):
    with open(source, 'rb') as stream, gzip.open(target, 'wb', compresslevel=9) as out:
        shutil.copyfileobj(stream, out)


def retain(raw, dest):
    """the small part of a checker evidence tree: hashes of everything, summaries and gzipped logs."""
    dest.mkdir(parents=True, exist_ok=True)
    listing = []
    for path in sorted(p for p in raw.rglob('*') if p.is_file()):
        rel = path.relative_to(raw)
        listing.append('%s  %d  %s' % (pr.digest(path), path.stat().st_size, rel))
        skip = {'frames', 'profile', 'cwd', 'work'} & set(rel.parts) or path.suffix in ('.png', '.jpg', '.mp4', '.pck', '.zip')
        if skip:
            continue
        flat = str(rel).replace('/', '__')
        if path.suffix in ('.log', '.jsonl') or path.name == 'probe.json' or path.stat().st_size > 64 << 10:
            gz(path, dest / (flat + '.gz'))
        elif path.suffix in ('.json', '.txt', '.gz', '.sha256'):
            shutil.copy2(path, dest / flat)
    (dest / 'FILES.sha256').write_text('\n'.join(listing) + '\n')


def candidate_files():
    return {p.name: p for p in ARGS.candidate.iterdir() if p.is_file()}


def verify_candidate():
    """the immutable candidate copy against the root's NEGATIVE-BASE.json, before any use."""
    base = json.loads(ARGS.base_manifest.read_text())
    found = {name: pr.digest(path) for name, path in candidate_files().items()}
    sums = dict(reversed(line.split('  ', 1)) for line in (ARGS.candidate / 'SHA256SUMS').read_text().splitlines() if '  ' in line)
    build = json.loads((ARGS.candidate / 'BUILD.json').read_text())
    ok = (found == base['files'] and all(found[n] == h for n, h in sums.items()) and build.get('source_commit') == base['source_commit']
          and build.get('source_commit') == pr.git('rev-parse', 'HEAD').strip())
    check('candidate bytes equal NEGATIVE-BASE.json, SHA256SUMS and this checkout\'s commit', ok,
          {'files': found, 'source_commit': build.get('source_commit')}, 'setup')
    tools = {p: pr.digest(PROJECT / p) for p in pr.HELPERS}
    check('this checkout\'s helpers are the candidate\'s packaging helpers', tools == build['helpers_sha256'], tools, 'setup')
    if not ok or tools != build['helpers_sha256']:
        raise SystemExit('candidate does not match its recorded base; nothing was run')
    return build


# --- ownership (in process, no engine) ----------------------------------------------------------

def ownership(evidence):
    """cancel at the exact process-acquisition boundary, before assignment returns."""
    g = 'ownership'
    real_popen = subprocess.Popen
    for kind in ('engine', 'display'):
        for sig in (signal.SIGINT, signal.SIGTERM):
            children = []
            def acquire(*args, **kwargs):
                child = real_popen([sys.executable, '-c', 'import time; time.sleep(60)'],
                                   start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                children.append(child)
                os.kill(os.getpid(), sig)
                return child
            interrupted = False
            try:
                with patch.object(pr.subprocess, 'Popen', acquire), patch.object(pr.nd, 'display_busy', return_value=False):
                    if kind == 'engine':
                        pr.run_engine(['unused'], evidence, os.environ.copy(), evidence / ('launch-%s-%d.log' % (kind, sig)), 2)
                    else:
                        # never started for real: Popen is the stub above, the number is only a label.
                        with pr.Display(189, evidence / ('launch-%s-%d.log' % (kind, sig))):
                            raise AssertionError('cancelled acquisition entered the display body')
            except KeyboardInterrupt:
                interrupted = True
            finally:
                gone = bool(children) and all(child.poll() is not None for child in children)
                for child in children:
                    pr.stop_process(child)
            check('%s acquisition cancellation %s unwinds ownership' % (kind, sig.name), interrupted and gone, group=g)
    for sig in (signal.SIGINT, signal.SIGTERM):
        check('terminal handler restored after acquisition: ' + sig.name, signal.getsignal(sig) == ORIGINAL_SIGNALS[sig], group=g)
    blocked = False
    with patch.object(pr.nd, 'display_busy', return_value=True), patch.object(pr.subprocess, 'Popen') as launch:
        try:
            with pr.Display(189, evidence / 'busy.log'):
                pass
        except pr.Rejected:
            blocked = not launch.called
    check('held display is refused before any process is started', blocked, group=g)
    pidfile = evidence / 'deadline.pid'
    sleeper = 'import os,subprocess,sys,time;from pathlib import Path;c=subprocess.Popen([sys.executable,"-c","import time;time.sleep(30)"]);' \
              'Path(%r).write_text("%%d %%d"%%(os.getpid(),c.pid));time.sleep(30)' % str(pidfile)
    code, _ = pr.run_engine([sys.executable, '-c', sleeper], evidence, os.environ.copy(), evidence / 'deadline.log', 1.5, cleanup_grace=1)
    pids = [int(n) for n in pidfile.read_text().split()] if pidfile.exists() else []
    time.sleep(0.3)
    check('engine deadline releases the owned group, child included', code == 'timeout' and len(pids) == 2 and not any(alive(p) for p in pids),
          {'code': code, 'pids': pids}, g)
    free = shutil.disk_usage(Path.home()).free
    floor = pr.MIN_FREE_GIB
    try:
        pr.MIN_FREE_GIB = free / 2 ** 30 + 1.0
        refused('storage floor refuses before starting', lambda: pr.require_space(evidence, 'a probe'), 'below the', g)
    finally:
        pr.MIN_FREE_GIB = floor


def alive(pid):
    try:
        return Path('/proc/%d/stat' % pid).read_text().rsplit(')', 1)[1].split()[0] != 'Z'
    except (FileNotFoundError, ProcessLookupError):
        return False


# --- provenance (in process, git only) ----------------------------------------------------------

def provenance(build):
    g = 'provenance'
    try:
        files, _ = pr.verify_source_manifest(build)
        check('candidate BUILD.json resolves against its committed tree', len(files) == build['source_files'], len(files), g)
    except pr.Rejected as error:
        check('candidate BUILD.json resolves against its committed tree', False, str(error), g)
        return
    line = build['startup_line']
    key = build['identity']['start']['course_key']
    changes = [('source_tree', '0' * 40, 'source tree'), ('source_archive_sha256', '0' * 64, 'source tree'),
               ('source_manifest_sha256', '0' * 64, 'source tree'), ('source_files', build['source_files'] - 1, 'source tree'),
               ('helpers_sha256', dict(build['helpers_sha256'], **{'tools/r15-pack-probe.gd': '0' * 64}), 'source tree'),
               ('helpers_committed', False, 'incorrect identity'), ('records_file', 'user://spillway_r14.cfg', 'incorrect identity'),
               ('default_map', 'practice', 'incorrect identity'), ('default_preset', 'server128_aa1000', 'incorrect identity'),
               ('main_scene', 'res://scenes/r14.tscn', 'incorrect identity'), ('user_data_folder', 'Spillway R15', 'incorrect identity'),
               ('export_preset', 'R14 Pack', 'incorrect identity'), ('build', 'spillway-2026.11.07-r14', 'incorrect identity'),
               ('source_commit', build['source_commit'][:8], 'full source commit'),
               ('runtime', dict(build['runtime'], members_sha256=dict(pr.TEMPLATE_MEMBERS, **{'linux_release.x86_64': pr.EDITOR_SHA256})), 'different runtime'),
               ('startup_line', line.replace(key, 'fedcba9876543210'), 'startup line and frozen identity disagree'),
               ('startup_line', line.replace('build=' + pr.BUILD, 'build=spillway-2026.11.07-r14'), 'startup line and frozen identity disagree'),
               ('identity', dict(build['identity'], start=dict(build['identity']['start'], map='practice')), 'no valid frozen identity')]
    seen = set()
    for field, value, expected in changes:
        changed = copy.deepcopy(build)
        changed[field] = value
        label = field if field not in seen else '%s (%s)' % (field, 'build id')
        seen.add(field)
        refused('provenance refuses changed %s' % label, lambda: pr.verify_source_manifest(changed), expected, g)


# --- preflight (disposable sparse clone) --------------------------------------------------------

def preflight(evidence):
    g = 'preflight'
    budget('the preflight clone')
    top = Path(pr.git('rev-parse', '--show-toplevel').strip())
    common = Path(pr.git('rev-parse', '--path-format=absolute', '--git-common-dir').strip())
    prefix = str(PROJECT.relative_to(top))
    commit = pr.git('rev-parse', 'HEAD').strip()
    clone = ARGS.scratch / 'preflight-clone'
    # --shared borrows the object store through alternates: nothing under .git/objects is copied.
    subprocess.run(['git', 'clone', '-q', '--shared', '--no-checkout', str(common), str(clone)], check=True)
    subprocess.run(['git', '-C', clone, 'sparse-checkout', 'set', prefix], check=True)
    subprocess.run(['git', '-C', clone, 'checkout', '-q', '--detach', commit], check=True)
    for key in ['user.name', 'user.email']:
        subprocess.run(['git', '-C', clone, 'config', key, 'negative-control'], check=True)
    project = clone / prefix
    tool = project / 'tools/package-r15.py'
    objects = du(clone / '.git/objects')
    check('preflight clone copies no object store', objects < 8 << 20 and (clone / '.git/objects/info/alternates').is_file(), objects, g)
    # baseline: the unmutated clone passes the same preflight (editor --version only, no export).
    sp = importlib.util.spec_from_file_location('package_r15_clone', tool)
    cloned = importlib.util.module_from_spec(sp)
    sp.loader.exec_module(cloned)
    try:
        facts = cloned.preflight(argparse.Namespace())
        check('baseline: the unmutated clone passes preflight', facts['commit'] == commit and facts['engine'].startswith(pr.ENGINE_VERSION),
              {'commit': facts['commit'], 'engine': facts['engine']}, g)
    except Exception as error:
        check('baseline: the unmutated clone passes preflight', False, repr(error), g)
    package_args = ['--startup-only', '--diagnostic']
    cases = [
        ('uncommitted tracked edit', 'scripts/r15_hud.gd', r'\Z', '\n# uncommitted negative control\n', 'edit', 'commit the project'),
        ('untracked file', 'scripts/r15_negative_untracked.gd', r'\A', 'extends Node\n', 'edit', 'commit the project'),
        ('wrong default scene', 'project.godot', r'^run/main_scene=.*$', 'run/main_scene="res://scenes/r14.tscn"', 'commit', 'committed default scene is res://scenes/r14.tscn'),
        ('other profile name', 'project.godot', r'^config/name=.*$', 'config/name="Spillway R15"', 'commit', 'committed profile identity is Spillway R15'),
        ('custom user dir', 'project.godot', r'^config/name=.*$', 'config/name="Spillway"\nconfig/use_custom_user_dir=true', 'commit', 'committed profile identity'),
        ('wrong build id', 'scripts/r15_main.gd', r'^const BUILD_ID := .*$', 'const BUILD_ID := "spillway-2026.11.07-r14"', 'commit', 'committed BUILD_ID is spillway-2026.11.07-r14'),
        ('r14 records file', 'scripts/r15_main.gd', r'^const SAVE_PATH := .*$', 'const SAVE_PATH := "user://spillway_r14.cfg"', 'commit', 'committed records file is user://spillway_r14.cfg'),
        ('scene without persist', 'scenes/r15.tscn', r'^persist = true$', 'persist = false', 'commit', 'persist = true'),
        ('scene runs another script', 'scenes/r15.tscn', r'path="res://scripts/r15_main.gd"', 'path="res://scripts/r14_main.gd"', 'commit', 'must run res://scripts/r15_main.gd'),
        ('startup line removed', 'scripts/r15_main.gd', r'print\("r15: build=%s; map=%s; ', 'print("r15 build=%s; map=%s; ', 'commit', 'r15 startup line is missing'),
        ('missing export preset', 'export_presets.cfg', r'^name="R15 Pack"$', 'name="R15 Pack (renamed)"', 'commit', 'no "R15 Pack" preset'),
        ('preset ships tests', 'export_presets.cfg', r'(name="R15 Pack"[\s\S]*?exclude_filter=")docs/\*,tests/\*,', r'\g<1>docs/*,', 'commit', 'excluding tests/*, tools/* and docs/*'),
        ('committed override.cfg', 'override.cfg', r'\A', '[application]\nrun/main_scene="res://scenes/r15.tscn"\n', 'commit', 'carries an override.cfg'),
    ]
    base = commit
    for name, path, pattern, replacement, how, expected in cases:
        subprocess.run(['git', '-C', clone, 'reset', '-q', '--hard', base], check=True)
        subprocess.run(['git', '-C', clone, 'clean', '-qfd'], check=True)
        target = project / path
        before = target.read_text() if target.exists() else ''
        text, count = re.subn(pattern, (lambda _: replacement) if '\\g<' not in replacement else replacement, before, count=1, flags=re.M)
        target.write_text(text)
        if how == 'commit':
            subprocess.run(['git', '-C', clone, 'add', '-A'], check=True)
            subprocess.run(['git', '-C', clone, 'commit', '-qm', 'negative control: ' + name], check=True)
        dirty = pr.git('status', '--porcelain', '--untracked-files=all', '--', '.', cwd=project).strip()
        out = ARGS.scratch / ('preflight-out-' + slug(name))
        cmd = [sys.executable, '-I', tool, 'package', '--output', out / 'package', *package_args]
        result = run(cmd, project, evidence / ('preflight-%s.log' % slug(name)))
        made = sorted(str(p) for p in out.rglob('*')) if out.exists() else []
        last = result.stderr.strip().splitlines()[-1] if result.stderr.strip() else result.returncode
        check('preflight refuses %s' % name, count == 1 and bool(dirty) == (how == 'edit') and result.returncode == 1
              and expected in result.stderr and not made, {'refusal': last, 'dirty': dirty, 'written': made}, g)
        shutil.rmtree(out, ignore_errors=True)
    # argument refusals in package() itself, on the clean clone, before preflight.
    subprocess.run(['git', '-C', clone, 'reset', '-q', '--hard', base], check=True)
    subprocess.run(['git', '-C', clone, 'clean', '-qfd'], check=True)
    tape = ARGS.scratch / 'unused-tape.json'
    args_cases = [('output inside the checkout', ['--output', project / 'builds/negative', *package_args], 'outside the Git checkout'),
                  ('startup-only release', ['--output', ARGS.scratch / 'preflight-out-release', '--startup-only'], 'never an R15 release candidate'),
                  ('release without every F2 course', ['--output', ARGS.scratch / 'preflight-out-routes', '--route', 'map=breakwater,preset=server128,tape=%s' % tape,
                                                     '--route', 'map=overflow,preset=server128_aa1000,tape=%s' % tape], 'F2 on every course'),
                  ('diagnostic into the final delivery folder', ['--output', ARGS.scratch / 'delivery/spillway-r15', *package_args], 'never written to the final delivery')]
    for name, extra, expected in args_cases:
        result = run([sys.executable, '-I', tool, 'package', *extra], project, evidence / ('preflight-%s.log' % slug(name)))
        written = [str(p) for p in (ARGS.scratch / 'delivery', ARGS.scratch / 'preflight-out-release', ARGS.scratch / 'preflight-out-routes',
                                    project / 'builds/negative') if p.exists()]
        check('package refuses %s' % name, result.returncode == 1 and expected in result.stderr and not written,
              result.stderr.strip().splitlines()[-1:] or result.returncode, g)
    shutil.rmtree(clone)


def slug(text):
    return re.sub(r'[^a-z0-9]+', '-', text.lower()).strip('-')


def run(cmd, cwd, log, timeout=None):
    started = time.time()
    result = subprocess.run([str(c) for c in cmd], cwd=cwd, capture_output=True, text=True, timeout=timeout)
    Path(log).write_text('$ %s\n# cwd %s, %.1f s, exit %s\n%s%s' % (' '.join(map(str, cmd)), cwd, time.time() - started, result.returncode,
                                                                   result.stdout, result.stderr))
    return result


# --- candidate zips -----------------------------------------------------------------------------

def write_build(path, edit):
    manifest = json.loads(path.read_text()) if isinstance(path, Path) else json.loads(path)
    edit(manifest)
    return (json.dumps(manifest, indent=2, ensure_ascii=False) + '\n').encode()


def rewrite_zip(source, target, platform, edits=None, adds=None, modes=None, build_edit=None):
    """copy a candidate zip member by member; one member replaced, removed or added, modes kept."""
    edits, adds, modes = dict(edits or {}), dict(adds or {}), dict(modes or {})
    folder = FOLDERS[platform]
    if build_edit:
        edits['BUILD.json'] = lambda data: write_build(data.decode(), build_edit)
    with zipfile.ZipFile(source) as old, zipfile.ZipFile(target, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as new:
        when = old.infolist()[0].date_time
        for info in old.infolist():
            rel = info.filename.split('/', 1)[1]
            change = edits.pop(rel, Ellipsis)
            if change is None:
                continue
            data = old.read(info)
            if change is not Ellipsis:
                data = change(data) if callable(change) else change
            entry = zipfile.ZipInfo(info.filename, info.date_time)
            entry.compress_type = zipfile.ZIP_DEFLATED
            entry.external_attr = (0o100000 | modes.pop(rel)) << 16 if rel in modes else info.external_attr
            new.writestr(entry, data, compresslevel=6)
        for rel, data in adds.items():
            entry = zipfile.ZipInfo('%s/%s' % (folder, rel), when)
            entry.compress_type = zipfile.ZIP_DEFLATED
            entry.external_attr = (0o100000 | 0o644) << 16
            new.writestr(entry, data, compresslevel=6)
    assert not edits and not modes, ('members not found', list(edits), list(modes))


def make_dist(name, linux=None, windows=None, build_edit=None, sums_edit=None, after=None):
    """a package directory for one case: unchanged zips are hard links to the immutable candidate,
    changed zips are rewritten, BUILD.json and SHA256SUMS follow unless the case breaks them."""
    budget('case ' + name)
    dist = ARGS.scratch / ('case-' + slug(name))
    dist.mkdir()
    zips = {('linux' if '-linux-' in n else 'windows'): p for n, p in candidate_files().items() if n.endswith('.zip')}
    for platform, change in (('linux', linux), ('windows', windows)):
        target = dist / zips[platform].name
        if change is None and build_edit is None:
            os.link(zips[platform], target)
        else:
            rewrite_zip(zips[platform], target, platform, build_edit=build_edit, **(change or {}))
    build = ARGS.candidate / 'BUILD.json'
    (dist / 'BUILD.json').write_bytes(write_build(build, build_edit) if build_edit else build.read_bytes())
    sums = ''.join('%s  %s\n' % (pr.digest(z), z.name) for z in sorted(dist.glob('*.zip')))
    (dist / 'SHA256SUMS').write_text(sums_edit(sums) if sums_edit else sums)
    if after:
        after(dist)
    return dist


def committed_bytes(path):
    return pr.git('show', 'HEAD:./' + path, binary=True)


def checker(dist, name, group, native=False, deadline=180):
    """run the actual check command on one case; returns (exit, failed top-level names, summary)."""
    raw = ARGS.scratch / ('check-' + slug(name))
    log = ARGS.evidence / group / (slug(name) + '.log')
    log.parent.mkdir(parents=True, exist_ok=True)
    cmd = [sys.executable, '-I', TOOL, 'check', dist, '--evidence', raw, '--scratch', ARGS.scratch, '--native-backend', 'amd' if native else ARGS.static_backend,
           '--display', str(ARGS.display), '--deadline', str(deadline)]
    if native:
        pr.require_space(ARGS.scratch, 'a native check')
    result = run(cmd, PROJECT, log, timeout=900 if not native else deadline * 3 + 600)
    summary = {}
    if (raw / 'summary.json').is_file():
        summary = json.loads((raw / 'summary.json').read_text())
    retain(raw, ARGS.evidence / group / slug(name))
    gz(log, log.with_suffix('.log.gz'))
    log.unlink()
    shutil.rmtree(raw, ignore_errors=True)
    failed = [c['name'] for c in summary.get('checks', []) if not c['ok']]
    return result.returncode, failed, summary


def static_case(name, expected, **dist_options):
    g = 'contents'
    dist = make_dist(name, **dist_options)
    try:
        code, failed, summary = checker(dist, name, g)
    finally:
        shutil.rmtree(dist)
    passed = [c['name'] for c in summary.get('checks', []) if c['ok']]
    check('check refuses %s at exactly %s' % (name, sorted(expected)), code == 1 and sorted(failed) == sorted(expected)
          and summary.get('runs') == 'skipped: static checks failed',
          {'exit': code, 'failed': failed, 'passed': len(passed), 'runs': summary.get('runs')}, g)


def baseline(evidence):
    """the unmutated candidate through the actual check_package; only the native stage is stubbed."""
    g = 'baseline'
    work = ARGS.scratch / 'baseline-work'
    raw = ARGS.scratch / 'baseline-evidence'
    budget('the static baseline')
    args = argparse.Namespace(work=work, native_backend='amd', identity=None)
    called = []
    def stub(*_args, **_kwargs):
        called.append(True)
        return {'stub': "native runs are the root's positive job; this baseline is static only"}
    with patch.object(pr, 'check_runs', stub):
        result = pr.check_package(ARGS.candidate, args, raw, [])
    names = [c['name'] for c in result['checks']]
    failed = [c['name'] for c in result['checks'] if not c['ok']]
    ARGS.static_total = len(names)
    retain(raw, evidence / 'baseline')
    shutil.rmtree(raw, ignore_errors=True)
    shutil.rmtree(work, ignore_errors=True)
    check('baseline: unmutated candidate passes every static check of check_package', not failed and called and len(names) == 19,
          {'checks': len(names), 'failed': failed}, g)
    (evidence / 'baseline' / 'STATIC-CHECKS.json').write_text(json.dumps(names, indent=1) + '\n')
    for name in names:
        print('  static: ' + name)


def contents(evidence):
    hud = committed_bytes('scripts/r15_hud.gd')
    test = committed_bytes('tests/test_r15_crouch.gd')
    licence = 'licenses/assets/r15/library/licences/kenney-train-License.txt'
    def readme_without(label):
        def edit(data):
            assert data.count(label.encode()) == 1, label
            return data.replace(label.encode(), b'')
        return edit
    def flip_last(data):
        return data[:-1] + bytes([data[-1] ^ 1])
    def edited(data):
        return data + b'\nedited by a negative control\n'
    editor = pr.EDITOR.read_bytes()
    static_case('override.cfg beside the runtime', [L + 'nothing but runtime, pack, readme, manifest and licences'],
                linux={'adds': {'override.cfg': b'[application]\nrun/main_scene="res://scenes/r14.tscn"\n'}})
    static_case('loose committed hud script in the folder', [L + 'nothing but runtime, pack, readme, manifest and licences'],
                linux={'adds': {'scripts/r15_hud.gd': hud}})
    static_case('committed test file in the folder', [L + 'nothing but runtime, pack, readme, manifest and licences'],
                linux={'adds': {'tests/test_r15_crouch.gd': test}})
    static_case('editor binary as the linux runtime', [L + 'runtime is the official release template, never the editor'],
                linux={'edits': {pr.NAME + '.x86_64': editor}})
    static_case('editor runtime with a manifest that claims it',
                [L + 'runtime is the official release template, never the editor', L + 'embedded and external provenance agree'],
                linux={'edits': {pr.NAME + '.x86_64': editor,
                                 'BUILD.json': lambda data: write_build(data.decode(), lambda m: m['runtime_sha256'].update({pr.NAME + '.x86_64': pr.EDITOR_SHA256}))}})
    del editor
    static_case('runtime without its executable bit', [L + 'the runtime keeps its executable bit'], linux={'modes': {pr.NAME + '.x86_64': 0o644}})
    static_case('nested r15 asset licence edited', [L + 'licences and asset provenance equal the pinned and committed bytes',
                                                    W + 'licences and asset provenance equal the pinned and committed bytes'],
                linux={'edits': {licence: edited}}, windows={'edits': {licence: edited}})
    static_case('nested r15 kit manifest missing', [L + 'nothing but runtime, pack, readme, manifest and licences',
                                                    L + 'licences and asset provenance equal the pinned and committed bytes'],
                linux={'edits': {'licenses/assets/r15/breakwater/MANIFEST.json': None}})
    static_case('readme missing the active F5 preset label', [L + 'readme names the build, every preset and the launch',
                                                              W + 'readme names the build, every preset and the launch'],
                linux={'edits': {'README.txt': readme_without('Bhop server AA 1000')}},
                windows={'edits': {'README.txt': readme_without('Bhop server AA 1000')}})
    # an unresolved manifest yields no committed file list, so no licence set can be expected either.
    untrusted = ['source manifest matches its committed tree, file hashes and helpers'] + [
        p + n for p in (L, W) for n in ('nothing but runtime, pack, readme, manifest and licences',
                                        'licences and asset provenance equal the pinned and committed bytes')]
    static_case('manifests claim another default map', untrusted, build_edit=lambda m: m.update(default_map='practice'))
    static_case('manifests claim another records file', untrusted,
                build_edit=lambda m: m.update(records_file='user://spillway_r14.cfg'))
    static_case('embedded manifest alone claims another default preset', [L + 'embedded and external provenance agree'],
                linux={'edits': {'BUILD.json': lambda data: write_build(data.decode(), lambda m: m.update(default_preset='server128_aa1000'))}})
    static_case('both packs differ from their manifests', [L + 'manifest names this pack and build', W + 'manifest names this pack and build'],
                linux={'edits': {pr.NAME + '.pck': flip_last}}, windows={'edits': {pr.NAME + '.pck': flip_last}})
    static_case('linux pack alone differs', [L + 'manifest names this pack and build', 'both platforms carry the same pack'],
                linux={'edits': {pr.NAME + '.pck': flip_last}})
    static_case('zip checksum mismatch', ['zip checksums match'], sums_edit=lambda s: ('0' if s[0] != '0' else '1') + s[1:])
    def truncate(dist):
        z = next(dist.glob('*-linux-*.zip'))
        data = z.read_bytes()
        z.unlink()
        z.write_bytes(data[:len(data) // 2])
        (dist / 'SHA256SUMS').write_text(''.join('%s  %s\n' % (pr.digest(p), p.name) for p in sorted(dist.glob('*.zip'))))
    static_case('truncated linux zip with a matching checksum', [L + 'zip opens'], after=truncate)
    def extra(dist):
        z = next(dist.glob('*-linux-*.zip'))
        os.link(z, dist / (pr.BUILD + '-linux-x86_64-deadbeef.zip'))
    static_case('an extra zip beside the package', ['manifest names exactly the two packages', 'SHA256SUMS lists exactly the zips', 'zip checksums match'],
                after=extra)


# --- runtime: broken game packs from the exact committed source ---------------------------------

def frozen_source(build):
    """the candidate's committed project, extracted and imported once in scratch."""
    top = Path(pr.git('rev-parse', '--show-toplevel').strip())
    tar = pr.source_archive(build['source_commit'], build['source_project_path'], top)
    check('variant source is the candidate\'s exact committed archive', hashlib.sha256(tar).hexdigest() == build['source_archive_sha256'],
          hashlib.sha256(tar).hexdigest(), 'runtime')
    root = ARGS.scratch / 'variant'
    source = root / 'source'
    with tarfile.open(fileobj=io.BytesIO(tar)) as frozen:
        frozen.extractall(source, filter='data')
    pr.require_space(root, 'the variant import')
    budget('the variant import')
    env = pr.engine_env(root / 'profile')
    started = time.time()
    pr.checked([pr.EDITOR, '--headless', '--path', source, '--import'], source, env, root / 'import.log')
    gz(root / 'import.log', ARGS.evidence / 'runtime' / 'variant-import.log.gz')
    print('  variant import %.0f s, scratch %.0f MiB' % (time.time() - started, du(ARGS.scratch) / 2 ** 20), flush=True)
    return root, source, env


def export_variant(root, source, env, name, path=None, pattern=None, replacement=None, exclude=None):
    """export one variant pack from the imported source; the source is restored afterwards."""
    changed = []
    try:
        if path:
            target = source / path
            original = target.read_bytes()
            changed.append((target, original))
            text, count = re.subn(pattern, lambda _: replacement, original.decode(), count=1, flags=re.M)
            assert count == 1, (name, path)
            target.write_text(text)
        if exclude:
            presets = source / 'export_presets.cfg'
            original = presets.read_bytes()
            changed.append((presets, original))
            text, count = re.subn(r'(name="R15 Pack"[\s\S]*?exclude_filter=")', lambda m: m.group(1) + exclude + ',', original.decode(), count=1)
            assert count == 1, name
            presets.write_text(text)
        pr.require_space(root, 'a variant export')
        budget('the %s export' % name)
        pack = root / ('%s.pck' % slug(name))
        pr.checked([pr.EDITOR, '--headless', '--path', source, '--export-pack', pr.PRESET, pack], source, env, root / ('export-%s.log' % slug(name)))
        gz(root / ('export-%s.log' % slug(name)), ARGS.evidence / 'runtime' / ('export-%s.log.gz' % slug(name)))
        return pack
    finally:
        for target, original in changed:
            target.write_bytes(original)


def pack_dist(name, pack):
    data = pack.read_bytes()
    sha = hashlib.sha256(data).hexdigest()
    dist = make_dist(name, linux={'edits': {pr.NAME + '.pck': data}}, windows={'edits': {pr.NAME + '.pck': data}},
                     build_edit=lambda m: m.update(pack_sha256=sha))
    return dist, sha


def native_case(name, dist, expected_top, expected_probe, allowed_probe=(), log_needle=None):
    """a native check of one broken package: the named refusal must appear, every other failure
    must be one of its declared consequences, and the static stage must have passed."""
    g = 'runtime'
    try:
        code, failed, summary = checker(dist, name, g, native=True, deadline=ARGS.deadline)
    finally:
        shutil.rmtree(dist)
    runs = summary.get('runs') if isinstance(summary.get('runs'), dict) else {}
    controls = runs.get('controls', {}) or {}
    probe_failed = controls.get('failed') if isinstance(controls.get('failed'), list) else [controls.get('failed')] if controls.get('failed') else []
    static_failed = [n for n in failed if n in ARGS.static_names]
    backend = (controls.get('native_backend') or {})
    named = all(any(e in f for f in failed) for e in expected_top) and all(any(e in f for f in probe_failed) for e in expected_probe)
    stray = [f for f in probe_failed if not any(re.search(a, f) for a in list(expected_probe) + list(allowed_probe))]
    log_ok = True
    if log_needle:
        raw_log = ARGS.evidence / g / slug(name) / 'runs__startup-headless__engine.log.gz'
        text = gzip.decompress(raw_log.read_bytes()).decode(errors='replace') if raw_log.is_file() else ''
        log_ok = log_needle in text
    detail = {'exit': code, 'failed': failed, 'probe_failed': probe_failed[:40], 'stray_probe_failures': stray,
              'startup': runs.get('startup_headless'), 'device': (backend.get('device') or {}).get('device'),
              'gpu_ok': (backend.get('gpu') or {}).get('ok'), 'display_released': runs.get('display_released')}
    return check('broken pack %s reaches %s' % (name, list(expected_top) + list(expected_probe)),
                 code == 1 and not static_failed and named and not stray and log_ok and runs.get('display_released') is True
                 and 'no owned engine process remains' not in failed, detail, g)


def runtime(evidence, build):
    root, source, env = frozen_source(build)
    try:
        base_pack = export_variant(root, source, env, 'unmutated')
        same = pr.digest(base_pack) == build['pack_sha256']
        # not a negative: says whether the variant pipeline reproduces the candidate byte for byte.
        check('unmutated re-export reproduces the candidate pack bytes (informational)', True,
              {'equal': same, 'export': pr.digest(base_pack), 'candidate': build['pack_sha256']}, 'runtime')
        base_pack.unlink()
        no_hud = export_variant(root, source, env, 'no hud', exclude='scripts/r15_hud.gd')
        records = export_variant(root, source, env, 'wrong records namespace', 'scripts/r15_main.gd', r'^const SAVE_PATH := .*$',
                                 'const SAVE_PATH := "user://spillway_r15_negative.cfg"')
    finally:
        shutil.rmtree(source, ignore_errors=True)
        shutil.rmtree(root / 'profile', ignore_errors=True)
    packs = {}
    for name, pack in (('no hud', no_hud), ('wrong records namespace', records)):
        packs[name] = pr.digest(pack)
    (evidence / 'runtime' / 'VARIANT-PACKS.json').write_text(json.dumps(packs, indent=1) + '\n')
    dist, _ = pack_dist('no hud', no_hud)
    no_hud.unlink()
    # main cannot parse without its preloaded hud: no startup line, and a game that never quits
    # (headless startup reaches its 120 s deadline); the probe then finds no r15 main.
    native_case('no hud', dist, ['shipped binary starts r15 from its own pack', 'headless startup is error-free'], [],
                allowed_probe=[r'.*'], log_needle='Preload file "res://scripts/r15_hud.gd" does not exist')
    dist, _ = pack_dist('wrong records namespace', records)
    records.unlink()
    # the registry reports the same SAVE_PATH constant, so its frozen comparison fails with it.
    native_case('wrong records namespace', dist, ['controls: probe ran and found no failures'], ['records namespace'],
                allowed_probe=[r'^registry save_path equals the frozen source$'])
    key = build['identity']['keys']['breakwater']['server128']['course_key']
    def lie(m):
        assert m['identity']['keys']['breakwater']['server128']['course_key'] == key
        m['identity']['keys']['breakwater']['server128']['course_key'] = '0' * 16
    dist = make_dist('frozen record key altered', build_edit=lie)
    native_case('frozen record key altered', dist, ['controls: probe ran and found no failures'], ['record key equals the frozen source key'],
                # leaving the lab compares the restored breakwater/F2 key with the same altered entry.
                allowed_probe=[r'^normal course hides experimental state and restores its record key$'])
    shutil.rmtree(root, ignore_errors=True)


# --- cancel -------------------------------------------------------------------------------------

def descendants(pid):
    """{pid: command name} of every live descendant, from one pass over /proc."""
    parents, names = {}, {}
    for entry in os.listdir('/proc'):
        if entry.isdigit():
            try:
                stat = Path('/proc/%s/stat' % entry).read_text()
            except OSError:
                continue
            parents[int(entry)] = int(stat.rsplit(')', 1)[1].split()[1])
            names[int(entry)] = stat[stat.index('(') + 1:stat.rindex(')')]
    found, frontier = {}, [pid]
    while frontier:
        parent = frontier.pop()
        for child, owner in parents.items():
            if owner == parent and child not in found:
                found[child] = names[child]
                frontier.append(child)
    return found


def cancel(evidence):
    """SIGTERM to the checker alone while the native controls run: exit 130, everything owned gone."""
    g = 'cancel'
    raw = ARGS.scratch / 'cancel-check'
    pr.require_space(ARGS.scratch, 'the cancellation run')
    budget('the cancellation run')
    cmd = [sys.executable, '-I', TOOL, 'check', ARGS.candidate, '--evidence', raw, '--scratch', ARGS.scratch, '--native-backend', 'amd',
           '--deadline', str(ARGS.deadline)]
    log = evidence / 'cancel' / 'check.log'
    log.parent.mkdir(parents=True, exist_ok=True)
    seen, engine, number = {}, None, None
    with open(log, 'wb') as output:
        output.write(('$ %s\n' % ' '.join(map(str, cmd))).encode())
        output.flush()
        process = subprocess.Popen([str(c) for c in cmd], cwd=PROJECT, stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
        deadline = time.monotonic() + 600
        while time.monotonic() < deadline and process.poll() is None:
            seen.update(descendants(process.pid))
            for pid in pr.owned_leftovers(raw / 'runs/controls'):
                try:
                    argv = Path('/proc/%s/cmdline' % pid).read_bytes().split(b'\0')
                    if Path(os.fsdecode(argv[0])).name != pr.NAME + '.x86_64':
                        continue
                    # only our child's display routing is read, never its other environment.
                    display = next(v[8:] for v in Path('/proc/%s/environ' % pid).read_bytes().split(b'\0') if v.startswith(b'DISPLAY='))
                    number, engine = int(display.decode().lstrip(':').split('.')[0]), int(pid)
                except (OSError, ValueError, StopIteration):
                    pass
            if engine and (raw / 'runs/controls/engine.log').is_file() and 'r15 pack probe' in (raw / 'runs/controls/engine.log').read_text(errors='replace'):
                break
            time.sleep(0.2)
        seen.update(descendants(process.pid))
        reached = engine is not None and alive(engine) and process.poll() is None
        if process.poll() is None:
            os.kill(process.pid, signal.SIGTERM)
        try:
            code = process.wait(120)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            code = 'hung'
    time.sleep(1)
    record = {}
    nd_json = raw / 'runs/native-display/native-display.json'
    if nd_json.is_file():
        record = json.loads(nd_json.read_text())
    owned = {pid: name for pid, name in seen.items()}
    remaining = {pid: name for pid, name in owned.items() if alive(pid)}
    cleanup = record.get('cleanup', {})
    runtime_dir = record.get('runtime_dir')
    files_left = [p for p in ('/tmp/.X11-unix/X%s' % number, '/tmp/.X%s-lock' % number) if number is not None and os.path.lexists(p)]
    names = sorted(set(owned.values()))
    check('cancel reached the private AMD controls run', reached and number in pr.nd.DISPLAYS and 'weston' in names and 'Xwayland' in names,
          {'engine': engine, 'display': number, 'processes': names}, g)
    check('wrapper-only SIGTERM exits 130 with the cancellation message', code == 130 and 'cancelled; owned process scopes released' in log.read_text(errors='replace'), code, g)
    check('engine, weston, Xwayland and every other owned descendant are gone', bool(owned) and not remaining, {'owned': owned, 'remaining': remaining}, g)
    check('display socket, lock and wayland runtime directory are gone', number is not None and not files_left and runtime_dir and not Path(runtime_dir).exists()
          and record.get('clean') is True and not cleanup.get('owned_processes_remaining'), {'left': files_left, 'runtime_dir': runtime_dir,
                                                                                            'clean': record.get('clean'), 'deferred': cleanup.get('deferred_signals')}, g)
    check('no process names the cancelled evidence tree', not pr.owned_leftovers(raw), pr.owned_leftovers(raw), g)
    check('checker removed its scratch work tree on cancel', not any(p.name.startswith('r15-check-') for p in ARGS.scratch.iterdir()),
          sorted(p.name for p in ARGS.scratch.iterdir()), g)
    retain(raw, evidence / 'cancel' / 'evidence')
    gz(log, log.with_suffix('.log.gz'))
    log.unlink()
    shutil.rmtree(raw, ignore_errors=True)


def main():
    global ARGS, RESULT_PATH
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--candidate', type=Path, required=True, help='the immutable candidate package directory (read only)')
    parser.add_argument('--base-manifest', type=Path, required=True, help="the root's NEGATIVE-BASE.json for the candidate")
    parser.add_argument('--evidence', type=Path, required=True)
    parser.add_argument('--scratch', type=Path, required=True, help='a RAM directory outside Git for transient copies')
    parser.add_argument('--only', nargs='*', choices=['ownership', 'provenance', 'preflight', 'baseline', 'contents', 'runtime', 'cancel'])
    parser.add_argument('--display', type=int, default=183, help='Xvfb number for static checks; never started when static checks fail')
    parser.add_argument('--deadline', type=float, default=900, help='per native run, seconds')
    ARGS = parser.parse_args()
    ARGS.static_backend = 'xvfb'
    ARGS.candidate, ARGS.evidence = ARGS.candidate.resolve(), ARGS.evidence.resolve()
    if ARGS.evidence.exists() and any(ARGS.evidence.iterdir()):
        sys.exit('evidence directory must be new or empty')
    ARGS.evidence.mkdir(parents=True, exist_ok=True)
    ARGS.scratch.mkdir(parents=True, exist_ok=True)
    ARGS.scratch = Path(tempfile.mkdtemp(prefix='r15-negatives-', dir=ARGS.scratch.resolve()))
    RESULT_PATH = ARGS.evidence / 'partial-summary.json'
    groups = ARGS.only or ['ownership', 'provenance', 'preflight', 'baseline', 'contents', 'runtime', 'cancel']
    started = time.time()
    try:
        build = verify_candidate()
        for group in groups:
            (ARGS.evidence / group).mkdir(exist_ok=True)
        if 'ownership' in groups:
            ownership(ARGS.scratch)
        if 'provenance' in groups:
            provenance(build)
        if 'preflight' in groups:
            preflight(ARGS.evidence / 'preflight')
        if {'baseline', 'contents', 'runtime'} & set(groups):
            # contents and runtime judge failures against the baseline's static check list.
            baseline(ARGS.evidence)
            ARGS.static_names = set(json.loads((ARGS.evidence / 'baseline/STATIC-CHECKS.json').read_text()))
        if 'contents' in groups:
            contents(ARGS.evidence)
        if 'runtime' in groups:
            runtime(ARGS.evidence, build)
        if 'cancel' in groups:
            cancel(ARGS.evidence)
    finally:
        leftovers = sorted(str(p) for p in ARGS.scratch.iterdir()) if ARGS.scratch.exists() else []
        shutil.rmtree(ARGS.scratch, ignore_errors=True)
    tool = {p: pr.digest(PROJECT / p) for p in pr.HELPERS}
    summary = {'scope': 'R15 delivery negatives on the immutable candidate; not release acceptance, feel or Windows execution',
               'candidate': str(ARGS.candidate), 'source_commit': build['source_commit'], 'helpers_sha256': tool,
               'suite_sha256': pr.digest(Path(__file__)), 'groups': groups, 'seconds': round(time.time() - started),
               'scratch_left_at_end': leftovers, 'passed': sum(r['ok'] for r in results), 'failed': sum(not r['ok'] for r in results),
               'results': results}
    (ARGS.evidence / 'summary.json').write_text(json.dumps(summary, indent=2, ensure_ascii=False, default=str) + '\n')
    RESULT_PATH.unlink(missing_ok=True)
    print('%d delivery negatives, %d failed' % (len(results), summary['failed']))
    sys.exit(1 if summary['failed'] else 0)


if __name__ == '__main__':
    main()
