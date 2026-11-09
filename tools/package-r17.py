#!/usr/bin/env python3
"""freeze committed R17, export once, assemble official releases and verify exact ZIP bytes.

R16 supplies process ownership, pinned runtimes, source archive, input/recording audits,
ZIP assembly and the full controls/play/ghost probe. R17 adds strict presentation identity,
the delivered R16 preservation boundary, all eight L comparisons and package negatives.
"""
import argparse
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import zipfile

PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT / 'tools'))
_spec = importlib.util.spec_from_file_location('r17_delivery_r16', PROJECT / 'tools/package-r16.py')
r16 = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(r16)
Rejected = r16.Rejected
BUILD = 'spillway-2026.11.09-r17'
VERSION = '2026.11.09-r17'
BASE = '7261ba593'
IMPLEMENTATION = '7c82e0877'
FLOOR = 15_000_000_000
NAME = 'SpillwayR17'
MAIN = 'res://scenes/r17.tscn'
HELPERS = tuple(dict.fromkeys((*r16.HELPERS, 'tools/package-r17.py', 'tools/check-r17-pack.sh', 'tools/r17-pack-probe.gd')))
r16.NAME = NAME
r16.MAIN_SCENE = MAIN
r16.MAIN_SCRIPT = 'res://scripts/r17_main.gd'
r16.PRESET = 'R17 Pack'
r16.TITLE_PREFIX = 'Spillway R17 · '
r16.PROBE = PROJECT / 'tools/r17-pack-probe.gd'
r16.HELPERS = HELPERS
r16.MIN_FREE_GIB = FLOOR / 2**30
r16.LINUX = {NAME + '.x86_64': 'linux_release.x86_64'}
r16.WINDOWS = {NAME + '.exe': 'windows_release_x86_64.exe', NAME + '.console.exe': 'windows_release_x86_64_console.exe'}
r16.EXPECT = dict(r16.EXPECT, main_scene=MAIN, title_prefix=r16.TITLE_PREFIX,
                  pack_forbidden_prefixes=[*r16.EXPECT['pack_forbidden_prefixes'], 'res://look/'])
_licences = r16.licence_files
_readme = r16.readme


def licence_files(files):
    found = _licences(files)
    for path in files:
        if path.startswith('assets/') and (Path(path).name == 'PROVENANCE.md' or path.endswith('-prompt.txt')):
            found['licenses/' + path] = ('source', path)
    return found


def readme(platform, facts, identity, launch, user_dir, newline):
    text = _readme(platform, facts, identity, launch, user_dir, newline)
    text = text.replace('SPILLWAY R16', 'SPILLWAY R17').replace('build ' + r16.BUILD, 'build ' + BUILD)
    return text + newline.join(['', 'R17 presentation: painted skies, ink contours and jump lips on all eight maps.',
        'L compares the painted and original R16 presentation. Gameplay remains delivered R16.',
        'The R16 build identifier in recordings and profiles is intentional and preserved.',
        'Use the same Spillway user-data folder: existing R16 times, style bests and ghosts remain compatible.',
        'Full sixteen-tape physics parity is a separate report, not implied by this delivery check.', ''])


r16.licence_files = licence_files
r16.readme = readme


def space(expected, scratch=None):
    free = shutil.disk_usage(Path.home()).free
    if free < FLOOR + expected:
        raise Rejected('storage floor: %d free; need %d floor + %d bounded output' % (free, FLOOR, expected))
    if scratch and shutil.disk_usage(scratch).free < 2_200_000_000:
        raise Rejected('RAM scratch needs at least 2.2 GB free')
    return free


def status_ok(status):
    allowed = ('?? tests/r17_parity', '?? tools/check-r17-parity.py')
    lines = [line[:3] + line[3:].removeprefix('projects/foldrunner/') for line in status.splitlines()]
    bad = [line for line in lines if line and not line.startswith(allowed)]
    if bad:
        raise Rejected('commit owned helpers first; runtime and other dirty files refused:\n' + '\n'.join(bad))


def preservation(commit, prefix):
    top = Path(r16.git('rev-parse', '--show-toplevel').strip())
    files = r16.git('ls-tree', '-r', '--name-only', BASE + ':' + prefix, cwd=top).splitlines()
    protected = [p for p in files if p.startswith(('scripts/', 'scenes/', 'shaders/', 'assets/'))]
    changed = []
    for path in protected:
        before = r16.git('rev-parse', BASE + ':' + prefix + '/' + path, cwd=top).strip()
        after = r16.git('rev-parse', commit + ':' + prefix + '/' + path, cwd=top).strip()
        if before != after:
            changed.append(path)
    if changed or len(protected) != 475:
        raise Rejected('delivered R16 preservation differs: count=%d changed=%s' % (len(protected), changed))
    return {'base_commit': r16.git('rev-parse', BASE, cwd=top).strip(), 'files': len(protected), 'unchanged': True}


def preflight():
    if r16.git('branch', '--show-current').strip() != 'feat/spillway-look-c':
        raise Rejected('only feat/spillway-look-c may build this candidate')
    status_ok(r16.git('status', '--porcelain', '--untracked-files=all', '--', '.'))
    commit = r16.git('rev-parse', 'HEAD').strip()
    top = Path(r16.git('rev-parse', '--show-toplevel').strip())
    prefix = str(PROJECT.relative_to(top))
    if subprocess.run(['git', '-C', str(top), 'merge-base', '--is-ancestor', IMPLEMENTATION, commit]).returncode:
        raise Rejected('R17 implementation commit is not in this source history')
    project = r16.committed('project.godot')
    for line in ['run/main_scene="' + MAIN + '"', 'config/name="Spillway"', 'config/version="' + VERSION + '"']:
        if line not in project.splitlines():
            raise Rejected('committed project identity missing: ' + line)
    if 'config/use_custom_user_dir=true' in project:
        raise Rejected('custom user folder would break delivered R16 profiles')
    scene = r16.committed('scenes/r17.tscn')
    if 'path="res://scripts/r17_main.gd"' not in scene or not all(x in scene.splitlines() for x in ['persist = true', 'record_runs = true']):
        raise Rejected('R17 normal scene must persist records and enable default recordings')
    if not r16.committed('scripts/r17_main.gd').startswith('extends "res://scripts/r16_main.gd"'):
        raise Rejected('R17 must inherit delivered R16')
    preset = next((b for b in re.split(r'^(?=\[preset\.\d+\]$)', r16.committed('export_presets.cfg'), flags=re.M)
                   if 'name="R17 Pack"' in b.splitlines()), '')
    if 'platform="Linux"' not in preset or not all(x in preset for x in ['look/*', 'docs/*', 'tests/*', 'tools/*']):
        raise Rejected('R17 Pack preset must exclude private look, docs, tests and tools')
    if r16.digest(r16.EDITOR) != r16.EDITOR_SHA256:
        raise Rejected('pinned official editor changed')
    engine = subprocess.check_output([str(r16.EDITOR), '--headless', '--version'], text=True, timeout=15).strip()
    if engine != r16.ENGINE_VERSION:
        raise Rejected('wrong pinned editor version')
    for name, value in r16.LICENCE_SHA256.items():
        if r16.digest(r16.LICENCES / name) != value:
            raise Rejected('pinned Godot licence changed: ' + name)
    return {'commit': commit, 'prefix': prefix, 'tree': r16.git('rev-parse', 'HEAD:./').strip(),
            'files': r16.git('ls-tree', '-r', '--name-only', 'HEAD:./').splitlines(),
            'stamp': r16.git('show', '-s', '--format=%ct', commit).strip(), 'engine': engine,
            'templates': r16.templates(), 'project_name': 'Spillway', 'preservation': preservation(commit, prefix)}


def asset_manifest(source):
    root = source / 'assets/look/r17'
    manifest = json.loads((root / 'MANIFEST.json').read_text())
    if len(manifest.get('files', {})) != 14:
        raise Rejected('R17 sky manifest must name seven PNGs and seven prompts')
    for name, value in manifest['files'].items():
        if Path(name).name != name or r16.digest(root / name) != value:
            raise Rejected('R17 asset manifest differs: ' + name)
    if not (root / 'PROVENANCE.md').read_text().strip():
        raise Rejected('R17 sky provenance is empty')
    return {'files': 14, 'manifest_sha256': r16.digest(root / 'MANIFEST.json')}


def source_identity(source, evidence, files):
    out = evidence / 'identity'
    out.mkdir()
    for name in ['r16-pack-probe.gd', 'r17-pack-probe.gd']:
        shutil.copy2(source / 'tools' / name, out / name)
    probe = out / 'r17-pack-probe.gd'
    spec = {'mode': 'identity', 'out': str(out), 'committed_resources': r16.resources(files), 'expect': {}}
    (out / 'spec.json').write_text(json.dumps(spec))
    r16.checked([r16.EDITOR, '--headless', '--path', source, '--check-only', '--script', probe], source,
                r16.engine_env(out / 'parse-profile'), out / 'parse.log', 60)
    override = source / 'override.cfg'
    if override.exists():
        raise Rejected('frozen source carries override.cfg')
    try:
        override.write_text('[autoload]\nPackProbe="*%s"\n' % probe)
        r16.checked([r16.EDITOR, '--headless', '--audio-driver', 'Dummy', '--path', source, '--', '--pack-probe=' + str(out / 'spec.json')],
                    source, r16.engine_env(out / 'profile'), out / 'engine.log', 180)
    finally:
        override.unlink(missing_ok=True)
    report = json.loads((out / 'probe.json').read_text())
    identity = report['identity']
    identity['probe_sha256'] = r16.digest(probe)
    if report['failures'] or identity['registry']['build'] != r16.BUILD or identity['registry']['save_path'] != r16.SAVE_PATH:
        raise Rejected('frozen source lost R16 behavior identity')
    if identity['main_script'] != r16.MAIN_SCRIPT or identity['project_name'] != 'Spillway' or set(identity['maps']) != set(r16.REQUIRED_MAPS):
        raise Rejected('frozen source lost R17 main, maps or shared user folder')
    if identity['start']['map'] != 'breakwater' or identity['start']['preset'] != 'server128':
        raise Rejected('frozen source default is not Breakwater/F2')
    return identity


def verify_manifest(build):
    expected = {'build': BUILD, 'round': 'R17', 'main_scene': MAIN, 'project_version': VERSION,
                'behavioral_build': r16.BUILD, 'records_file': r16.SAVE_PATH, 'export_preset': 'R17 Pack',
                'export_editor_sha256': r16.EDITOR_SHA256, 'helpers_committed': True}
    if any(build.get(k) != v for k, v in expected.items()):
        raise Rejected('manifest presentation/behavior identity differs')
    commit, prefix = build['source_commit'], build['source_project_path']
    if not re.fullmatch('[a-f0-9]{40}', commit):
        raise Rejected('full frozen source commit required')
    top = Path(r16.git('rev-parse', '--show-toplevel').strip())
    tar = r16.source_archive(commit, prefix, top)
    files = r16.git('ls-tree', '-r', '--name-only', commit + ':' + prefix, cwd=top).splitlines()
    hashes = {p: hashlib.sha256(r16.git('show', commit + ':' + prefix + '/' + p, binary=True, cwd=top)).hexdigest() for p in HELPERS}
    if (build['source_tree'] != r16.git('rev-parse', commit + ':' + prefix, cwd=top).strip()
            or build['source_archive_sha256'] != hashlib.sha256(tar).hexdigest()
            or build['source_manifest_sha256'] != hashlib.sha256(r16.archive_manifest(tar).encode()).hexdigest()
            or build['source_files'] != len(files) or build['helpers_sha256'] != hashes or hashes != r16.helper_hashes()):
        raise Rejected('source/helper/archive manifest differs from committed frozen bytes')
    if build['runtime']['members_sha256'] != r16.TEMPLATE_MEMBERS or build['runtime']['archive_sha256'] != r16.TEMPLATES_SHA256:
        raise Rejected('runtime provenance differs from official pins')
    if build['preservation'] != preservation(commit, prefix):
        raise Rejected('delivered R16 preservation metadata differs')
    return files


def harness(folder, work, probe_root=PROJECT):
    """reusable exact-release setup for GPU/movie callers; never edit the extracted folder."""
    work.mkdir(parents=True)
    for name in [NAME + '.x86_64', NAME + '.pck']:
        os.link(folder / name, work / name)
    for probe in ['r16-pack-probe.gd', 'r17-pack-probe.gd']:
        shutil.copy2(probe_root / 'tools' / probe, work / probe)
    (work / 'override.cfg').write_text('[autoload]\nPackProbe="*%s"\n' % (work / 'r17-pack-probe.gd'))
    return work


def static_check(dist, work):
    build = json.loads((dist / 'BUILD.json').read_text())
    files = verify_manifest(build)
    r16.templates()
    zips = sorted(dist.glob('*.zip'))
    expected = sorted('%s-%s-%s.zip' % (BUILD, p, build['source_commit'][:8]) for p in ['linux-x86_64', 'windows-x86_64'])
    sums = (dist / 'SHA256SUMS').read_text().splitlines()
    if [p.name for p in zips] != expected or sorted(build['platforms']) != expected or sorted(sums) != sorted('%s  %s' % (r16.digest(z), z.name) for z in zips):
        raise Rejected('ZIP set or SHA256SUMS differs')
    licences = licence_files(files)
    top = Path(r16.git('rev-parse', '--show-toplevel').strip())
    extracted = {}
    results = []
    for z in zips:
        platform = 'linux-x86_64' if '-linux-' in z.name else 'windows-x86_64'
        target = work / platform
        folder = target / (NAME + '-' + platform)
        runtimes = r16.LINUX if platform.startswith('linux') else r16.WINDOWS
        expected_files = sorted([*runtimes, NAME + '.pck', 'BUILD.json', 'README.txt', *licences])
        with zipfile.ZipFile(z) as archive:
            names = archive.namelist()
            if len(names) != len(set(names)) or sorted(names) != [folder.name + '/' + p for p in expected_files] or archive.testzip():
                raise Rejected(platform + ': unsafe, unexpected, duplicate or CRC-damaged ZIP entries')
            if platform.startswith('linux') and archive.getinfo(folder.name + '/' + NAME + '.x86_64').external_attr >> 16 & 0o111 != 0o111:
                raise Rejected('Linux ZIP lost executable mode')
        r16.extract(z, target)
        for name, member in runtimes.items():
            runtime = folder / name
            header = runtime.read_bytes()[:4]
            if r16.digest(runtime) != r16.TEMPLATE_MEMBERS[member] or not (header == b'\x7fELF' if platform.startswith('linux') else header[:2] == b'MZ'):
                raise Rejected(platform + ': runtime header/digest is not the official release')
        if platform.startswith('linux') and not os.access(folder / (NAME + '.x86_64'), os.X_OK):
            raise Rejected('extracted Linux executable bit absent')
        if r16.digest(folder / (NAME + '.pck')) != build['pack_sha256']:
            raise Rejected(platform + ': PCK differs from the common pack digest')
        embedded = json.loads((folder / 'BUILD.json').read_text())
        if any(embedded.get(k) != v for k, v in build.items() if k != 'platforms') or embedded.get('runtime_sha256') != {n: r16.TEMPLATE_MEMBERS[m] for n, m in runtimes.items()}:
            raise Rejected(platform + ': embedded metadata differs')
        for name, (origin, source) in licences.items():
            data = (r16.LICENCES / source).read_bytes() if origin == 'godot' else r16.git('show', build['source_commit'] + ':' + build['source_project_path'] + '/' + source, binary=True, cwd=top)
            if (folder / name).read_bytes() != data:
                raise Rejected(platform + ': licence or provenance differs: ' + name)
        notes = (folder / 'README.txt').read_text()
        if any(s not in notes for s in [BUILD, 'L compares', NAME + '.pck', 'spillway_r16.cfg', 'r16_runs/', 'R16 build identifier']):
            raise Rejected(platform + ': README misses launch/presentation/behavior details')
        extracted[platform] = folder
        results.append({'platform': platform, 'crc': True, 'files': len(names), 'licences': len(licences), 'official_headers_hashes': True,
                        'zip_sha256': r16.digest(z), 'pack_sha256': build['pack_sha256'], 'embedded_metadata': True})
    return build, files, extracted, results


def normal_start(folder, out, extra=()):
    out.mkdir(parents=True)
    cwd = out / 'cwd'
    cwd.mkdir()
    code, text = r16.run_engine([folder / (NAME + '.x86_64'), '--headless', '--audio-driver', 'Dummy', '--', '--verify-startup', *extra],
                               cwd, r16.engine_env(out / 'profile'), out / 'engine.log', 60)
    return code, text


def pack_negatives(folder, work, evidence):
    """mutate private copies only; no export and no link writes to positive package bytes."""
    results = []
    for kind in ['missing-pack', 'malformed-pack', 'missing-critical-r17-sky']:
        case = work / ('negative-' + kind)
        case.mkdir()
        os.link(folder / (NAME + '.x86_64'), case / (NAME + '.x86_64'))
        if kind == 'malformed-pack':
            (case / (NAME + '.pck')).write_bytes(b'not a Godot pack')
        elif kind == 'missing-critical-r17-sky':
            data = (folder / (NAME + '.pck')).read_bytes()
            # the import remap and ctex index names become unavailable. payload bytes stay private.
            if b'whiteout-sky.png' not in data:
                raise Rejected('critical asset negative did not find its target')
            (case / (NAME + '.pck')).write_bytes(data.replace(b'whiteout-sky.png', b'whiteouX-sky.png'))
        code, text = normal_start(case, evidence / kind, ['--r16-map=whiteout-relay'])
        refused = code != 0 or bool(r16.ERRORS.search(text))
        if kind != 'missing-critical-r17-sky':
            refused = refused and 'r17: spillway-' not in text
        results.append({'case': kind, 'refused': refused, 'exit': code, 'engine_errors': bool(r16.ERRORS.search(text)),
                        'scope': 'exact official runtime, empty cwd; malformed critical asset must cause an engine error or failure, never accepted as success'})
        shutil.rmtree(case)
        if not refused:
            raise Rejected('broken package was silently accepted: ' + kind)
    return results


def native_checks(folder, build, files, args, evidence, work, routes):
    host = harness(folder, work / 'harness')
    args.pack_required = r16.resources(files)
    args.require = []
    args.native_backend = 'amd'
    args.identity = build['identity']
    args.controls_fps = 60
    runs = {}
    with r16.nd.NativeDisplay(evidence / 'native-display', displays=(args.display,), min_free_gib=FLOOR / 2**30) as display:
        args._active_display = display
        cases = [('controls', None)]
        for route in routes:
            cases += [('play', route), ('reload', route)]
        best = {}
        for mode, route in cases:
            label = mode if route is None else route['route']['name'] + '-' + mode
            out = evidence / label
            profile = evidence / ('controls-profile' if route is None else route['route']['name'] + '-profile')
            if mode != 'reload':
                r16.seed_old_profiles(profile)
            before = r16.profile_files(profile)
            spec = r16.spec_for(mode, host, out, args, args.identity, {'profile_state': 'loaded' if mode == 'reload' else 'new', **({'records': best} if mode == 'reload' else {})}, route['route'] if route else None)
            if route:
                spec['route'] = route['route']
                if mode == 'play':
                    spec.update(tape=route['tape'], arm_motor_steps=route['arm_motor_steps'], reference_trace=route['trace'], capture_ticks=[0, route['ticks'] // 2, route['ticks'] - 1])
            code, text, report, titles = r16.native(host, out, spec, args, profile, route['physics_hz'] if route else 60, r16.route_args(route['route']) if route else ())
            r16.read_recordings(host, out / 'reader', profile, report)
            audit = r16.audit_profile(profile, before, r16.profile_files(profile), report, build['helpers_sha256'], allow_config=mode == 'play')
            result = {'exit': code, 'checks': len(report.get('checks', [])), 'failures': report.get('failures'),
                      'failed': [c for c in report.get('checks', []) if not c['ok']], 'recordings': audit,
                      'native_backend': report.get('native_backend'), 'titles': sorted(titles), 'frames': len(report.get('frames', [])),
                      'r17_maps': report.get('r17_maps', []), 'cwd_empty': not any((out / 'cwd').iterdir())}
            if mode == 'play':
                best = {key: report['run'].get(key) for key in ['best_time', 'open_best_time', 'best_splits', 'best_segments', 'record_ticks', 'style_best', 'ghost_pointer']}
                result['exact_source_trace'] = r16.shipped_trace_match(out / 'trace.jsonl', route['trace'])
                result['input_order'] = r16.packed_input_audit(r16.read_rows(out / 'trace.jsonl'), json.loads(Path(route['tape']).read_text()), route['input_settings'], observer_path=PROJECT / 'tools/momentum-tape.py', expected_observer_sha256=build['helpers_sha256']['tools/momentum-tape.py'])
                result['best'] = best
            if mode == 'reload':
                after = r16.profile_files(profile)
                cfg = 'Spillway/spillway_r16.cfg'
                result['config_not_rewritten'] = before.get(cfg) is not None and before.get(cfg) == after.get(cfg)
            result['ok'] = (code == 0 and report.get('failures') == 0 and audit['ok'] and not r16.ERRORS.search(text)
                            and result['cwd_empty'] and any(t.startswith('Spillway R17 · ') for t in titles)
                            and (mode != 'controls' or len(result['r17_maps']) == 8)
                            and result.get('exact_source_trace', {'ok': True})['ok'] and result.get('input_order', {'ok': True})['ok']
                            and result.get('config_not_rewritten', True))
            runs[label] = result
            (out / 'delivery-result.json').write_text(json.dumps(result, indent=2) + '\n')
            if not result['ok']:
                raise Rejected('exact release ' + label + ' failed; see ' + str(out / 'delivery-result.json'))
    runs['display_released'] = display.released
    return runs


def check(dist, args, evidence, work, routes):
    evidence.mkdir(parents=True)
    build, files, extracted, static = static_check(dist, work / 'extract')
    folder = extracted['linux-x86_64']
    code, text = normal_start(folder, evidence / 'normal-startup')
    line = r16.STARTUP.search(text)
    if code or r16.ERRORS.search(text) or not line or line['build'] != r16.BUILD or line['key'] != build['identity']['start']['course_key'] or 'r17: ' + BUILD not in text:
        raise Rejected('normal uninstrumented R17 startup failed')
    if r16.profile_files(evidence / 'normal-startup/profile') or any((evidence / 'normal-startup/cwd').iterdir()):
        raise Rejected('headless startup wrote user files or empty cwd')
    negatives = pack_negatives(folder, work, evidence / 'negatives')
    runs = native_checks(folder, build, files, args, evidence, work, routes)
    result = {'ok': True, 'source_commit': build['source_commit'], 'pack_sha256': build['pack_sha256'],
              'static': static, 'normal_startup': {'exit': code, 'r16_identity': line.group(0), 'r17_print': True, 'empty_cwd': True},
              'negative_controls': negatives, 'native_linux': runs, 'windows': {'static_only': True, 'native_execution': 'unverified',
              'wine_on_path': shutil.which('wine'), 'wine64_on_path': shutil.which('wine64')},
              'limits': ['Windows native execution unverified; Linux success is not Windows proof.',
                         'One complete packed course plus reload; full sixteen-tape parity is a separate worker/report.',
                         'Synthetic engine input, private AMD/X11; no physical latency or player-feel verdict.',
                         'R16 behavioral BUILD_ID and recording/profile identities are deliberately preserved.']}
    (evidence / 'summary.json').write_text(json.dumps(result, indent=2) + '\n')
    return result


def route_freeze(source, evidence, identity):
    # one complete published R16 line proves default recording, best promotion and reload/ghost.
    outer = Path('/home/thatmike1/foldrunner-build-2026-11-05')
    route = r16.parse_route('map=breakwater,preset=server128,tape=' + str(outer / 'checkpoints/spillway/r15/release-plan/tapes/breakwater-basic.json') + ',warmup=33,name=breakwater-basic')
    return [r16.source_route(route, source, evidence, identity)]


def package(args):
    output = args.output.resolve()
    top = Path(r16.git('rev-parse', '--show-toplevel').strip())
    if output == top or top in output.parents or (output.exists() and any(output.iterdir())):
        raise Rejected('output must be a new/empty directory outside source; deliveries are immutable')
    facts = preflight()
    space(400_000_000, args.scratch)
    output.mkdir(parents=True, exist_ok=True)
    evidence = output / 'evidence'
    evidence.mkdir()
    with tempfile.TemporaryDirectory(prefix='r17-package-', dir=args.scratch) as temporary:
        work = Path(temporary)
        tar = r16.source_archive(facts['commit'], facts['prefix'], top)
        manifest = r16.archive_manifest(tar)
        (evidence / 'source-sha256.txt').write_text(manifest)
        source = work / 'source'
        with tarfile.open(fileobj=io.BytesIO(tar)) as frozen:
            frozen.extractall(source, filter='data')
        if any(r16.digest(source / p) != r16.digest(PROJECT / p) for p in HELPERS):
            raise Rejected('executed helpers differ from committed freeze')
        assets = asset_manifest(source)
        env = r16.engine_env(work / 'import-profile')
        r16.checked([r16.EDITOR, '--headless', '--path', source, '--import'], source, env, evidence / 'import.log')
        # relative inheritance needs the unchanged R16 probe beside the executed R17 probe.
        identity = source_identity(source, evidence, facts['files'])
        pack = work / (NAME + '.pck')
        r16.checked([r16.EDITOR, '--headless', '--path', source, '--export-pack', 'R17 Pack', pack], source, env, evidence / 'export.log')
        routes = route_freeze(source, evidence / 'source-routes', identity)
        build = {'game': 'Spillway', 'round': 'R17', 'build': BUILD, 'behavioral_build': r16.BUILD, 'project_version': VERSION,
                 'release_candidate': True, 'status': 'verified delivery candidate; parent decides promotion',
                 'source_commit': facts['commit'], 'source_tree': facts['tree'], 'source_project_path': facts['prefix'],
                 'source_archive_sha256': hashlib.sha256(tar).hexdigest(), 'source_manifest_sha256': hashlib.sha256(manifest.encode()).hexdigest(),
                 'source_files': len(facts['files']), 'engine': facts['engine'], 'export_editor_sha256': r16.EDITOR_SHA256,
                 'export_preset': 'R17 Pack', 'runtime': {'kind': 'official Godot 4.7.2 release export templates',
                 'archive': facts['templates']['archive_url'], 'archive_sha256': r16.TEMPLATES_SHA256, 'members_sha256': r16.TEMPLATE_MEMBERS},
                 'pack_sha256': r16.digest(pack), 'main_scene': MAIN, 'records_file': r16.SAVE_PATH, 'user_data_folder': 'Spillway',
                 'default_map': r16.DEFAULT_MAP, 'default_preset': r16.DEFAULT_PRESET, 'identity': identity,
                 'preservation': facts['preservation'], 'r17_assets': assets,
                 'helpers_sha256': {p: r16.digest(source / p) for p in HELPERS}, 'helpers_committed': True,
                 'verification': 'VERIFICATION.json beside ZIPs; raw evidence/ contains exact-release probes',
                 'routes': [{k: v for k, v in r.items() if k not in ('trace', 'tape')} for r in routes]}
        folders = r16.assemble(work, pack, facts, identity, build)
        zips = []
        for platform, folder in folders.items():
            z = work / ('%s-%s-%s.zip' % (BUILD, platform, facts['commit'][:8]))
            r16.archive(folder, z, facts['stamp'])
            zips.append(z)
            shutil.rmtree(folder)
        dist = work / 'candidate'
        dist.mkdir()
        for z in zips:
            shutil.move(z, dist / z.name)
        build['platforms'] = sorted(p.name for p in dist.glob('*.zip'))
        (dist / 'BUILD.json').write_text(json.dumps(build, indent=2) + '\n')
        (dist / 'SHA256SUMS').write_text(''.join('%s  %s\n' % (r16.digest(z), z.name) for z in sorted(dist.glob('*.zip'))))
        # loose source is gone before any exact-release launch; routes retain data, no fallback.
        shutil.rmtree(source)
        result = check(dist, args, evidence / 'check', work / 'verify', routes)
        (dist / 'VERIFICATION.json').write_text(json.dumps(result, indent=2) + '\n')
        (dist / 'README.txt').write_text('SPILLWAY R17 delivery candidate\n\nExtract either whole ZIP. Linux: ./SpillwayR17.x86_64. Windows: SpillwayR17.exe.\nKeep SpillwayR17.pck adjacent. L compares paint/ink with original R16 presentation.\nR16 gameplay, profiles, automatic recordings, style bests and ghosts remain shared.\nLinux exact release verified on private AMD/X11. Windows static-only; native execution unverified.\nBUILD.json pins committed source and official runtimes; VERIFICATION.json states checks and limits.\nFull sixteen-tape parity is separate. Parent must inspect visual evidence and decide promotion.\n')
        space(sum(p.stat().st_size for p in dist.iterdir()) + 20_000_000)
        for p in dist.iterdir():
            shutil.move(p, output / p.name)
        print(json.dumps({'output': str(output), 'source_commit': facts['commit'], 'pack_sha256': build['pack_sha256'], 'ok': True}))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    for name in ['package', 'check']:
        p = sub.add_parser(name)
        p.add_argument('--scratch', type=Path, default=Path('/tmp'))
        p.add_argument('--display', type=int, choices=range(190, 200), default=198)
        p.add_argument('--deadline', type=float, default=600)
        if name == 'package':
            p.add_argument('--output', type=Path, required=True)
        else:
            p.add_argument('package_dir', type=Path)
            p.add_argument('--evidence', type=Path, required=True)
    args = parser.parse_args()
    try:
        with r16.cancellation_signals():
            if args.command == 'package':
                package(args)
            else:
                if args.evidence.exists():
                    raise Rejected('recheck evidence must be a new directory')
                space(100_000_000, args.scratch)
                with tempfile.TemporaryDirectory(prefix='r17-recheck-', dir=args.scratch) as temporary:
                    work = Path(temporary)
                    build = json.loads((args.package_dir / 'BUILD.json').read_text())
                    verify_manifest(build)
                    source = work / 'source'
                    tar = r16.source_archive(build['source_commit'], build['source_project_path'], Path(r16.git('rev-parse', '--show-toplevel').strip()))
                    with tarfile.open(fileobj=io.BytesIO(tar)) as frozen:
                        frozen.extractall(source, filter='data')
                    args.evidence.mkdir(parents=True)
                    r16.checked([r16.EDITOR, '--headless', '--path', source, '--import'], source, r16.engine_env(work / 'profile'), args.evidence / 'import.log')
                    routes = route_freeze(source, args.evidence / 'source-routes', build['identity'])
                    shutil.rmtree(source)
                    result = check(args.package_dir.resolve(), args, args.evidence / 'check', work / 'verify', routes)
                    (args.evidence / 'VERIFICATION.json').write_text(json.dumps(result, indent=2) + '\n')
    except (Rejected, r16.nd.NativeDisplayError, OSError, ValueError, KeyError) as error:
        print('package-r17: ' + str(error), file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print('package-r17: cancelled; owned process scopes released', file=sys.stderr)
        return 130
    return 0


if __name__ == '__main__':
    sys.exit(main())
