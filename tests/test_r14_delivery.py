#!/usr/bin/env python3
"""negative controls for the r14 delivery tools: each packaging hazard must be refused.

integrity: provenance resolution against git, changed manifest fields, self-attested runtime
replacements, route specs and the packed cadence rule; no package or engine needed.
preflight: a throwaway sparse clone gets one deliberate break per case and
`package-r14.py package --startup-only --diagnostic` must refuse it before writing a package.
contents: copies of a good package get one break each (checksums and manifests made consistent
where the break must reach a later check) and `package-r14.py check` must fail on that check.
runtime: packs exported from the package's own commit with one source break each must fail the
shipped startup or the probe. cancel: SIGTERM during a native run must release the display and
every owned process. evidence goes to --evidence, outside Git.

python3 tests/test_r14_delivery.py --package GOOD_PACKAGE_DIR --evidence NEW_DIR
    [--only integrity preflight contents runtime cancel] [--display 182] [--scratch RAMDIR]
python3 tests/test_r14_delivery.py --only integrity --evidence NEW_DIR
"""
import argparse
import copy
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
import time
from unittest.mock import patch

PROJECT = Path(__file__).resolve().parents[1]
TOOL = PROJECT / 'tools/package-r14.py'
spec = importlib.util.spec_from_file_location('package_r14', TOOL)
pr = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pr)
results = []
ARGS = None
ORIGINAL_SIGNALS = {sig: signal.getsignal(sig) for sig in (signal.SIGINT, signal.SIGTERM)}
RESULT_PATH = None


def check(name, ok, detail=''):
    results.append({'name': name, 'ok': bool(ok), 'detail': detail})
    if RESULT_PATH is not None:
        temporary = RESULT_PATH.with_suffix('.json.tmp')
        temporary.write_text(json.dumps(results, indent=2) + '\n')
        temporary.replace(RESULT_PATH)
    print('%s %s%s' % ('PASS' if ok else 'FAIL', name, '' if not detail else ' (%s)' % str(detail)[:300]), flush=True)


def run(cmd, cwd, log):
    result = subprocess.run([str(c) for c in cmd], cwd=cwd, capture_output=True, text=True)
    Path(log).write_text(result.stdout + result.stderr)
    return result


def refused(name, call, expected):
    try:
        call()
    except (pr.Rejected, argparse.ArgumentTypeError) as error:
        check(name, expected in str(error), str(error))
    else:
        check(name, False, 'accepted')


def ownership(evidence):
    """cancel at the exact process-acquisition boundary, before assignment returns."""
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
                        with pr.Display(189, evidence / ('launch-%s-%d.log' % (kind, sig))):
                            raise AssertionError('cancelled acquisition entered the display body')
            except KeyboardInterrupt:
                interrupted = True
            finally:
                gone = bool(children) and all(child.poll() is not None for child in children)
                for child in children:
                    pr.stop_process(child)
            check('%s acquisition cancellation %s unwinds ownership' % (kind, sig.name), interrupted and gone)
    for sig in (signal.SIGINT, signal.SIGTERM):
        check('terminal handler restored after acquisition: ' + sig.name, signal.getsignal(sig) == ORIGINAL_SIGNALS[sig])
    blocked = False
    with patch.object(pr.nd, 'display_busy', return_value=True), patch.object(pr.subprocess, 'Popen') as launch:
        try:
            with pr.Display(189, evidence / 'busy.log'):
                pass
        except pr.Rejected:
            blocked = not launch.called
    check('held display is refused before any process is started', blocked)


def gates(evidence):
    """exercise the actual shell review/gate functions with bounded child outcomes."""
    wrapper = (PROJECT / 'tools/check-r14.sh').read_text()
    functions = []
    for name in ('clean_log', 'pack_traces', 'step', 'retained', 'source_review'):
        match = re.search(r'^' + name + r'\(\) \{\n.*?^\}', wrapper, re.M | re.S)
        assert match, name
        functions.append(match.group())
    names = ['slope_flat_probe_contacts_earned_' + suffix for suffix in
             ('trial1', 'trial2', 'phase_y138.5', 'phase_y139.0', 'phase_y139.5',
              'phase_y140.5', 'phase_y141.0', 'phase_y142.0', 'phase_y144.0', 'phase_y148.0')]
    child = evidence / 'review-child.py'
    child.write_text('#!/usr/bin/env python3\nimport json,os,pathlib,sys\n'
                     'out=next(a[6:] for a in sys.argv if a.startswith("--out="))\n'
                     'pathlib.Path(out).mkdir(parents=True,exist_ok=True)\n'
                     'pathlib.Path(out,"summary.json").write_text(os.environ["GATE_SUMMARY"])\n'
                     'print(os.environ.get("GATE_LOG", "review complete"))\n'
                     'sys.exit(int(os.environ["GATE_EXIT"]))\n')
    child.chmod(0o700)
    cases = [('known failures accepted', names, 1, '', 0),
             ('new failure rejects the wrapper', names + ['new_contact_regression'], 1, '', 1),
             ('retired failure rejects changed expectations', names[:-1], 1, '', 1),
             ('unexpected child exit rejects', names, 2, '', 1),
             ('engine error rejects matching summary', names, 1, 'SCRIPT ERROR: negative control', 1)]
    for i, (name, failed_names, child_exit, log, wanted) in enumerate(cases):
        out = evidence / ('gate-%d' % i)
        out.mkdir()
        env = dict(os.environ, GATE_SUMMARY=json.dumps({'checks': [{'name': n, 'pass': False} for n in failed_names]}),
                   GATE_EXIT=str(child_exit), GATE_LOG=log)
        script = 'set -euo pipefail\n' + '\n'.join(functions) + '\n' + '''
out="$1"; src="$2"; GODOT="$3"; results=(); failed=0; control_failed=0
# this reduction controls the child result; full-wrapper ownership is tested separately.
owned_run() { local log="$1"; shift 2; "$@" >"$log" 2>&1; }
step retained source_review
printf '%s\n' "${results[@]}"
exit "$failed"
'''
        result = subprocess.run(['bash', '-c', script, 'gate-test', str(out), str(evidence), str(child)],
                                env=env, capture_output=True, text=True)
        (out / 'wrapper.log').write_text(result.stdout + result.stderr)
        check(name, result.returncode == wanted, {'exit': result.returncode, 'output': result.stdout[-500:]})


# --- integrity ---------------------------------------------------------------------------------

def integrity(evidence):
    """declared provenance against git and the immutable runtime anchors."""
    top = Path(pr.git('rev-parse', '--show-toplevel').strip())
    commit = pr.git('rev-parse', 'HEAD').strip()
    prefix = str(PROJECT.relative_to(top))
    files = pr.git('ls-tree', '-r', '--name-only', '--full-tree', commit + ':' + prefix, cwd=top).splitlines()
    archive = pr.source_archive(commit, prefix, top)
    check('canonical source archive repeats exactly', archive == pr.source_archive(commit, prefix, top))
    stamp = int(pr.git('show', '-s', '--format=%ct', commit, cwd=top).strip())
    with tarfile.open(fileobj=io.BytesIO(archive)) as frozen:
        check('archive entry times equal the source commit', all(member.mtime == stamp for member in frozen.getmembers()))
    manifest = pr.archive_manifest(archive)
    check('archive file manifest lists every committed file', len(manifest.splitlines()) == len(files))
    key = '0123456789abcdef'
    build = {'build': pr.BUILD, 'main_scene': pr.MAIN_SCENE, 'records_file': pr.SAVE_PATH, 'default_map': pr.DEFAULT_MAP,
             'default_preset': pr.DEFAULT_PRESET, 'user_data_folder': pr.PROJECT_NAME,
             'helpers_committed': True, 'export_editor_sha256': pr.EDITOR_SHA256, 'export_preset': pr.PRESET,
             'source_commit': commit, 'source_project_path': prefix,
             'source_tree': pr.git('rev-parse', commit + ':' + prefix, cwd=top).strip(),
             'source_archive_sha256': hashlib.sha256(archive).hexdigest(), 'source_files': len(files),
             'source_manifest_sha256': hashlib.sha256(manifest.encode()).hexdigest(),
             'helpers_sha256': {p: hashlib.sha256(pr.git('show', commit + ':' + prefix + '/' + p, binary=True, cwd=top)).hexdigest() for p in pr.HELPERS},
             'runtime': {'archive_sha256': pr.TEMPLATES_SHA256, 'members_sha256': dict(pr.TEMPLATE_MEMBERS)},
             'identity': {'start': {'map': pr.DEFAULT_MAP, 'preset': pr.DEFAULT_PRESET, 'course_key': key}},
             'startup_line': 'r14: build=%s; map=practice; preset=server128; physics_hz=128; course_key=%s; records=off; '
                             'runner=res://scripts/r14_source_player.gd; renderer=gl_compatibility' % (pr.BUILD, key)}
    check('valid source provenance resolves', pr.verify_source_manifest(build)[0] == files)
    changes = [('source_tree', '0' * 40), ('source_archive_sha256', '0' * 64), ('source_manifest_sha256', '0' * 64),
               ('source_files', -1), ('helpers_sha256', {}), ('helpers_committed', False),
               ('records_file', 'user://spillway_r13.cfg'), ('default_preset', 'vanilla64'), ('user_data_folder', 'Spillway R14'),
               ('runtime', {'archive_sha256': pr.TEMPLATES_SHA256, 'members_sha256': {**pr.TEMPLATE_MEMBERS, 'linux_release.x86_64': pr.EDITOR_SHA256}}),
               ('startup_line', build['startup_line'].replace(key, 'fedcba9876543210')),
               ('identity', {'start': {'map': 'overflow', 'preset': pr.DEFAULT_PRESET, 'course_key': key}})]
    for field, value in changes:
        changed = copy.deepcopy(build)
        changed[field] = value
        refused('reject changed provenance: ' + field, lambda: pr.verify_source_manifest(changed), '')
    fake = evidence / 'fake-template-cache'
    fake.mkdir()
    provenance = json.loads((pr.TEMPLATES / 'PROVENANCE.json').read_text())
    for name in pr.TEMPLATE_MEMBERS:
        (fake / name).write_bytes(b'not an engine\n')
        provenance['members']['templates/' + name] = pr.digest(fake / name)
    (fake / 'PROVENANCE.json').write_text(json.dumps(provenance))
    (fake / 'version.txt').write_text('4.7.2.stable\n')
    actual = pr.TEMPLATES
    try:
        pr.TEMPLATES = fake
        refused('reject self-attested replacement runtimes', pr.templates, 'differs from the verified archive member')
    finally:
        pr.TEMPLATES = actual
    for text, expected in [('map=overflow,tape=/x.json', 'route needs'), ('map=overflow,preset=server128,tape=/x,speed=3', 'route needs'),
                           ('map=overflow,preset=server128,tape=/x,name=Bad Name', 'route name')]:
        refused('reject route spec ' + text, lambda: pr.parse_route(text), expected)
    refused('reject a packed route at another cadence', lambda: pr.packed_cadence([pr.parse_route('map=overflow,preset=server128,tape=/x,fps=30')]), 'one frame per tick')
    route = pr.parse_route('map=overflow,preset=server128,tape=/x,sensitivity=5.729577951308232,name=probe')
    game = pr.route_game(route, evidence / 'route-game.gd').read_text()
    check('route game only sets the start map and sensitivity', game.count('\n\t') == 2 and 'map_id = "overflow"' in game
          and 'source_sensitivity_override = 5.729577951308232' in game and 'extends "res://scripts/r14_main.gd"' in game, game)
    free = shutil.disk_usage('/home').free
    floor = pr.MIN_FREE_GIB
    try:
        pr.MIN_FREE_GIB = free / 2 ** 30 + 1.0
        refused('storage floor refuses before starting', lambda: pr.require_space(evidence, 'a probe'), 'below the')
        if evidence.stat().st_dev != Path.home().stat().st_dev:
            # a ram-disk target is held to /home's floor, not to 15 GiB of its own.
            pr.MIN_FREE_GIB = free / 2 ** 30 - 0.5
            try:
                pr.require_space(evidence, 'a probe')
                check('a target on another disk is judged by the /home floor', True)
            except pr.Rejected as error:
                check('a target on another disk is judged by the /home floor', False, str(error))
    finally:
        pr.MIN_FREE_GIB = floor


# --- preflight ---------------------------------------------------------------------------------

def preflight(evidence):
    top = Path(pr.git('rev-parse', '--show-toplevel').strip())
    prefix = str(PROJECT.relative_to(top))
    clone = evidence / 'clone'
    subprocess.run(['git', 'clone', '-q', '--no-checkout', '--local', str(top), str(clone)], check=True)
    subprocess.run(['git', '-C', clone, 'sparse-checkout', 'set', prefix], check=True)
    subprocess.run(['git', '-C', clone, 'checkout', '-q', pr.git('rev-parse', 'HEAD').strip()], check=True)
    for key in ['user.name', 'user.email']:
        subprocess.run(['git', '-C', clone, 'config', key, 'negative-control'], check=True)
    project = clone / prefix
    cases = [
        ('wrong default scene', 'project.godot', r'^run/main_scene=.*$', 'run/main_scene="res://scenes/momentum_overflow.tscn"', True, 'committed default scene'),
        ('other profile identity', 'project.godot', r'^config/name=.*$', 'config/name="Spillway R14"', True, 'committed profile identity'),
        ('wrong build id', 'scripts/r14_main.gd', r'^const BUILD_ID := .*$', 'const BUILD_ID := "spillway-2026.11.07-r13-overflow"', True, 'committed BUILD_ID'),
        ('r13 records file', 'scripts/r14_main.gd', r'^const SAVE_PATH := .*$', 'const SAVE_PATH := "user://spillway_r13.cfg"', True, 'committed records file'),
        ('scene without persist', 'scenes/r14.tscn', r'^persist = true$', 'persist = false', True, 'persist = true'),
        ('missing export preset', 'export_presets.cfg', r'^name="R14 Pack"$', 'name="R14 Pack (renamed)"', True, 'no "R14 Pack" preset'),
        ('committed override.cfg', 'override.cfg', r'\A', '[application]\nrun/main_scene="res://scenes/main.tscn"\n', True, 'override.cfg'),
        ('uncommitted edit', 'scripts/r14_hud.gd', r'\Z', '\n# uncommitted\n', False, 'commit the project'),
    ]
    base = pr.git('rev-parse', 'HEAD', cwd=clone).strip()
    for name, path, pattern, replacement, commit, expected in cases:
        subprocess.run(['git', '-C', clone, 'reset', '-q', '--hard', base], check=True)
        subprocess.run(['git', '-C', clone, 'clean', '-qfd'], check=True)
        target = project / path
        before = target.read_text() if target.exists() else ''
        text, count = re.subn(pattern, lambda _: replacement, before, count=1, flags=re.M)
        target.write_text(text)
        if commit:
            subprocess.run(['git', '-C', clone, 'add', '-A'], check=True)
            subprocess.run(['git', '-C', clone, 'commit', '-qm', 'negative control: ' + name], check=True)
        out = evidence / ('preflight-' + name.replace(' ', '-'))
        result = run([sys.executable, '-I', project / 'tools/package-r14.py', 'package', '--output', out / 'package', '--startup-only',
                      '--diagnostic'], project, out.with_suffix('.log'))
        made = list((out / 'package').rglob('*.zip')) if (out / 'package').exists() else []
        check('preflight refuses: ' + name, count == 1 and result.returncode == 1 and expected in result.stderr and not made,
              result.stderr.strip().splitlines()[-1] if result.stderr.strip() else result.returncode)
    shutil.rmtree(clone)


# --- tampered packages -------------------------------------------------------------------------

def unpack(package, work):
    work.mkdir(parents=True)
    for name in ['BUILD.json', 'SHA256SUMS'] + [z.name for z in package.glob('*.zip')]:
        shutil.copy2(package / name, work / name)
    folders = {}
    for z in sorted(work.glob('*.zip')):
        pr.extract(z, work / 'unzipped')
        platform = 'linux-x86_64' if '-linux-' in z.name else 'windows-x86_64'
        folders[z] = work / 'unzipped' / ('%s-%s' % (pr.NAME, platform))
    return folders


def repack(work, folders, pack=None, manifest_edit=None):
    def edit(path):
        manifest = json.loads(path.read_text())
        if pack is not None:
            manifest['pack_sha256'] = pr.digest(pack)
        if manifest_edit:
            manifest_edit(manifest)
        path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + '\n')
    edit(work / 'BUILD.json')
    stamp = int(json.loads((work / 'BUILD.json').read_text()).get('source_commit') and 0) or 315532800
    for z, folder in folders.items():
        if pack is not None:
            shutil.copy2(pack, folder / (pr.NAME + '.pck'))
        edit(folder / 'BUILD.json')
        z.unlink()
        pr.archive(folder, z, stamp)
    (work / 'SHA256SUMS').write_text(''.join('%s  %s\n' % (pr.digest(z), z.name) for z in folders))
    shutil.rmtree(work / 'unzipped')


def checker(work, evidence, name, expected):
    out = evidence / ('check-' + name.replace(' ', '-').replace('/', '-'))
    cmd = [sys.executable, '-I', TOOL, 'check', work, '--evidence', out, '--display', str(ARGS.display), '--native-backend', ARGS.native_backend, '--deadline', '180']
    if ARGS.scratch:
        cmd += ['--scratch', ARGS.scratch]
    result = run(cmd, PROJECT, str(out) + '.log')
    failed = [line for line in result.stdout.splitlines() if line.startswith('FAIL')]
    check('check refuses: ' + name, result.returncode == 1 and any(expected in line for line in failed), failed[:4])
    shutil.rmtree(work)


def linux(folders):
    return next(f for z, f in folders.items() if '-linux-' in z.name)


def contents(package, evidence):
    work = evidence / 'pkg-override'
    folders = unpack(package, work)
    (linux(folders) / 'override.cfg').write_text('[application]\nrun/main_scene="res://scenes/main.tscn"\n')
    repack(work, folders)
    checker(work, evidence, 'override.cfg beside the runtime', 'nothing but runtime')
    work = evidence / 'pkg-loose'
    folders = unpack(package, work)
    (linux(folders) / 'scripts').mkdir()
    shutil.copy2(PROJECT / 'scripts/r14_hud.gd', linux(folders) / 'scripts/r14_hud.gd')
    repack(work, folders)
    checker(work, evidence, 'loose source script in the folder', 'nothing but runtime')
    work = evidence / 'pkg-tests'
    folders = unpack(package, work)
    (linux(folders) / 'tests').mkdir()
    shutil.copy2(PROJECT / 'tests/test_r14_loop.gd', linux(folders) / 'tests/test_r14_loop.gd')
    repack(work, folders)
    checker(work, evidence, 'test file in the folder', 'nothing but runtime')
    work = evidence / 'pkg-editor'
    folders = unpack(package, work)
    shutil.copy2(pr.EDITOR, linux(folders) / (pr.NAME + '.x86_64'))
    repack(work, folders, manifest_edit=lambda m: m.get('runtime_sha256') and m['runtime_sha256'].update({pr.NAME + '.x86_64': pr.EDITOR_SHA256}) if 'platform' in m and m['platform'].startswith('linux') else None)
    checker(work, evidence, 'editor binary as the runtime', 'runtime is the official release template')
    work = evidence / 'pkg-exec-bit'
    folders = unpack(package, work)
    (linux(folders) / (pr.NAME + '.x86_64')).chmod(0o644)
    repack(work, folders)
    checker(work, evidence, 'runtime without its executable bit', 'executable bit')
    work = evidence / 'pkg-licence'
    folders = unpack(package, work)
    for folder in folders.values():
        licence = next(p for p in sorted((folder / 'licenses/assets').rglob('*')) if p.is_file())
        licence.write_text(licence.read_text() + '\nedited\n')
    repack(work, folders)
    checker(work, evidence, 'asset licence edited', 'licences and asset provenance')
    work = evidence / 'pkg-readme'
    folders = unpack(package, work)
    for folder in folders.values():
        notes = (folder / 'README.txt').read_bytes()
        (folder / 'README.txt').write_bytes(notes.replace(b'CS:GO vanilla', b'CS vanilla'))
    repack(work, folders)
    checker(work, evidence, 'readme missing a preset', 'readme names the build, every preset')
    work = evidence / 'pkg-identity'
    folders = unpack(package, work)
    repack(work, folders, manifest_edit=lambda m: m.update(default_preset='vanilla64'))
    checker(work, evidence, 'manifest names another default preset', 'source manifest matches')
    work = evidence / 'pkg-registry'
    folders = unpack(package, work)
    repack(work, folders, manifest_edit=lambda m: m['identity']['keys']['practice']['server128'].update(course_key='0' * 16))
    checker(work, evidence, 'frozen record key altered', 'record key equals the frozen source')
    work = evidence / 'pkg-tampered'
    folders = unpack(package, work)
    for folder in folders.values():
        with open(folder / (pr.NAME + '.pck'), 'r+b') as stream:
            stream.seek(-1, 2)
            last = stream.read(1)
            stream.seek(-1, 2)
            stream.write(bytes([last[0] ^ 1]))
    repack(work, folders)
    checker(work, evidence, 'pack differs from its manifest', 'manifest names this pack')
    work = evidence / 'pkg-sums'
    unpack(package, work)
    shutil.rmtree(work / 'unzipped')
    sums = (work / 'SHA256SUMS').read_text()
    (work / 'SHA256SUMS').write_text(sums.replace(sums[:8], '00000000', 1))
    checker(work, evidence, 'zip checksum mismatch', 'zip checksums match')
    work = evidence / 'pkg-truncated'
    unpack(package, work)
    shutil.rmtree(work / 'unzipped')
    z = next(work.glob('*-linux-*.zip'))
    data = z.read_bytes()
    z.write_bytes(data[:len(data) // 2])
    (work / 'SHA256SUMS').write_text(''.join('%s  %s\n' % (pr.digest(p), p.name) for p in sorted(work.glob('*.zip'))))
    checker(work, evidence, 'truncated zip with matching checksum', 'zip opens')
    work = evidence / 'pkg-extra-zip'
    unpack(package, work)
    shutil.rmtree(work / 'unzipped')
    shutil.copy2(next(work.glob('*-linux-*.zip')), work / (pr.BUILD + '-linux-x86_64-deadbeef.zip'))
    checker(work, evidence, 'an extra zip beside the package', 'manifest names exactly the two packages')


def variant_pack(package, evidence, name, path, pattern, replacement, preset_exclude=None):
    """a pack exported from the package's own commit with one deliberate source break."""
    build = json.loads((package / 'BUILD.json').read_text())
    top = Path(pr.git('rev-parse', '--show-toplevel').strip())
    source = evidence / ('variant-' + name) / 'source'
    source.mkdir(parents=True)
    with tarfile.open(fileobj=io.BytesIO(pr.source_archive(build['source_commit'], build['source_project_path'], top))) as frozen:
        frozen.extractall(source, filter='data')
    if path:
        target = source / path
        text, count = re.subn(pattern, lambda _: replacement, target.read_text(), count=1, flags=re.M)
        assert count == 1, (name, path)
        target.write_text(text)
    if preset_exclude:
        presets = source / 'export_presets.cfg'
        presets.write_text(re.sub(r'(name="R14 Pack"[\s\S]*?exclude_filter=")', r'\g<1>' + preset_exclude + ',', presets.read_text(), count=1))
    env = pr.engine_env(source.parent / 'profile')
    pr.checked([pr.EDITOR, '--headless', '--path', source, '--import'], source, env, source.parent / 'import.log')
    pack = source.parent / (pr.NAME + '.pck')
    pr.checked([pr.EDITOR, '--headless', '--path', source, '--export-pack', pr.PRESET, pack], source, env, source.parent / 'export.log')
    shutil.rmtree(source)
    shutil.rmtree(source.parent / 'profile', ignore_errors=True)
    return pack


def runtime(package, evidence):
    pr.require_space(evidence, 'variant exports')
    cases = [('no-hud', None, None, None, 'scripts/r14_hud.gd', 'shipped binary starts r14'),
             ('r13-records', 'scripts/r14_main.gd', r'^const SAVE_PATH := .*$', 'const SAVE_PATH := "user://spillway_r13.cfg"', None, 'records namespace'),
             ('other-profile', 'project.godot', r'^config/name=.*$', 'config/name="Spillway R14"', None, 'profile identity is the shipped project'),
             ('other-default-preset', 'scripts/r14_main.gd', r'^const DEFAULT_PRESET := .*$', 'const DEFAULT_PRESET := "vanilla64"', None, 'shipped binary starts r14')]
    for name, path, pattern, replacement, exclude, expected in cases:
        pack = variant_pack(package, evidence, name, path, pattern, replacement, preset_exclude=exclude)
        work = evidence / ('pkg-' + name)
        repack(work, unpack(package, work), pack)
        checker(work, evidence, 'pack variant ' + name, expected)
        pack.unlink()


def cancel(package, evidence):
    """SIGTERM while the native controls run: exit 130, display and processes released."""
    out = evidence / 'cancel-check'
    cmd = [sys.executable, '-I', TOOL, 'check', package, '--evidence', out, '--display', str(ARGS.display), '--native-backend', ARGS.native_backend]
    if ARGS.scratch:
        cmd += ['--scratch', ARGS.scratch]
    with open(str(out) + '.log', 'wb') as log:
        process = subprocess.Popen([str(c) for c in cmd], cwd=PROJECT, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
        number = None
        started = False
        for _ in range(1200):
            for pid in pr.owned_leftovers(out / 'runs/controls'):
                try:
                    argv = Path('/proc/%s/cmdline' % pid).read_bytes().split(b'\0')
                    if Path(os.fsdecode(argv[0])).name != pr.NAME + '.x86_64':
                        continue
                    # read only our child's display routing, never expose its other environment.
                    display = next(value[8:] for value in Path('/proc/%s/environ' % pid).read_bytes().split(b'\0') if value.startswith(b'DISPLAY='))
                    number = int(display.decode().lstrip(':').split('.')[0])
                    started = Path('/tmp/.X11-unix/X%d' % number).exists()
                except (OSError, ValueError, StopIteration):
                    pass
            if started:
                break
            if process.poll() is not None:
                break
            time.sleep(0.1)
        time.sleep(3)
        if process.poll() is None:
            os.kill(process.pid, signal.SIGTERM)
        code = process.wait(90)
    time.sleep(1)
    check('cancel reached the native run', started)
    check('cancelled check exits 130', code == 130, code)
    check('cancel released the private display', number is not None and not Path('/tmp/.X11-unix/X%d' % number).exists() and not Path('/tmp/.X%d-lock' % number).exists(), {'backend': ARGS.native_backend, 'display': number})
    leftovers = pr.owned_leftovers(out)
    check('cancel left no owned process', not leftovers, leftovers)


def main():
    global ARGS, RESULT_PATH
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--package', type=Path)
    parser.add_argument('--evidence', type=Path, required=True)
    parser.add_argument('--only', nargs='*', choices=['ownership', 'gates', 'integrity', 'preflight', 'contents', 'runtime', 'cancel'])
    parser.add_argument('--display', type=int, default=182)
    parser.add_argument('--native-backend', choices=['xvfb', 'amd'], default='xvfb')
    parser.add_argument('--scratch', type=Path, help='a RAM directory for transient copies')
    ARGS = parser.parse_args()
    needs_package = {'contents', 'runtime', 'cancel'}
    if ARGS.package is None and (not ARGS.only or needs_package & set(ARGS.only)):
        parser.error('--package is required for contents, runtime and cancel')
    package, evidence = ARGS.package.resolve() if ARGS.package else None, ARGS.evidence.resolve()
    if evidence.exists() and any(evidence.iterdir()):
        sys.exit('evidence directory must be new or empty')
    evidence.mkdir(parents=True, exist_ok=True)
    RESULT_PATH = evidence / 'partial-summary.json'
    for group, function in [('ownership', lambda: ownership(evidence)), ('gates', lambda: gates(evidence)),
                            ('integrity', lambda: integrity(evidence)), ('preflight', lambda: preflight(evidence)),
                            ('contents', lambda: contents(package, evidence)), ('runtime', lambda: runtime(package, evidence)),
                            ('cancel', lambda: cancel(package, evidence))]:
        if not ARGS.only or group in ARGS.only:
            function()
    (evidence / 'summary.json').write_text(json.dumps(results, indent=2) + '\n')
    failures = [r for r in results if not r['ok']]
    print('%d delivery controls, %d failed' % (len(results), len(failures)))
    sys.exit(1 if failures else 0)


if __name__ == '__main__':
    main()
