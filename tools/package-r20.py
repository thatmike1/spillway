#!/usr/bin/env python3
"""R20 release gates, adapted from package-r19.py at 065f7b279.

The R16 audit/input/ghost and R18 assembly implementations retain their provenance.
Each load constructs private r18/r16 module instances; no old gate module is mutated.
New feature acceptance is deliberately pending until the parent supplies real controls.

 `prepare` is read-only; `package` requires an explicit frozen commit.

compose R16 process/input/recording machinery and R18 archive/asset gates. Full host
parity is separate. No candidate is exported by importing this module or preparing it.
"""
import argparse
import copy
import hashlib
import importlib.util
import io
import json
import math
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys
import tarfile
import tempfile
import zipfile

sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT / 'tools'))
_spec = importlib.util.spec_from_file_location('r20_delivery_r18', PROJECT / 'tools/package-r18.py')
r18 = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(r18)
r16 = r18.r16
from r19_native_guard import DesktopGuard
Rejected = r16.Rejected
BUILD = 'spillway-2026.11.10-r20'
VERSION = '2026.11.10-r20'
BASE = '065f7b27993df7ae2511eb34eb665d271dded13c'
FLOOR = 15_000_000_000
PREP_LIMIT = 100 * 2**20
ASSEMBLY_LIMIT = 2_200_000_000
SCRATCH = Path('/tmp/r20-package-helpers')
NAME = 'SpillwayR20'
MAIN = 'res://scenes/r20.tscn'
MAIN_SCRIPT = 'res://scripts/r20_main.gd'
ORIGINAL_MAPS = tuple(r16.REQUIRED_MAPS)
OUTER = Path('/home/thatmike1/foldrunner-build-2026-11-05')
BASELINE = OUTER / 'look/evidence/r20-baseline/SOURCE.json'
TRACKED = OUTER / 'look/evidence/r20-baseline/TRACKED.json'
R19_BUILD = OUTER / 'delivery/spillway-r19/BUILD.json'
R19_VERIFICATION = OUTER / 'delivery/spillway-r19/VERIFICATION.json'
BASELINE_SHA = '372c06a6ced068e79f47770a10e15118903186d86bbe1a3397276a64490da467'
TRACKED_SHA = 'd05d78afb31345f42d1d448015b42418b92de6fec9348013f89b298ff9a0033d'
R19_BUILD_SHA = '0d28841c00b30b62dd09aba74403621e9b5ab9a9483acec97e99a2b6a9bf99b4'
R19_VERIFICATION_SHA = '39981c6f76c34b026244769356c709cb7ba6071be46dbdb8408988ee1c931ad5'
# independently enumerate the parent's exact boundary, never R19's R18 allowlist.
OLD_CHANGES = frozenset(('project.godot', 'scripts/r16_style.gd', 'scripts/r16_style_panel.gd',
    'scripts/r18_style_panel.gd', 'scripts/r19_ghost_share.gd'))
F2_PATHS = ('scripts/r14_presets.gd', 'scripts/r14_source_motion.gd', 'scripts/r14_source_player.gd',
    'scripts/r15_presets.gd', 'scripts/r15_source_player.gd', 'scripts/spillway_player.gd')
NEW_MAPS = ('saltglass', 'tether-yard', 'through-line')
REQUIRED_MAPS = (*ORIGINAL_MAPS, *NEW_MAPS)
EXPERIMENTAL_MAPS = ('experiment', 'tether-yard', 'through-line')
SHELVED = ('line-drive', 'fall-line')
# these are integration work, not claims about unfinished runtime APIs.
PENDING_FEATURES = ('saltglass-route', 'directional-stack', 'tether-controls', 'through-line', 'export-my-runs')
HELPERS = tuple(dict.fromkeys((*r18.HELPERS, 'tools/package-r19.py', 'tools/r19-pack-probe.gd',
    'tools/r19_native_guard.py', 'tools/package-r20.py', 'tools/r20-pack-probe.gd',
    'tests/test_package_r20.py', 'tools/check-r20-preservation.py',
    'tests/r20_release_style_observer.gd', 'tools/check-r20-style-events.py',
    'tools/r20-direction-driver.gd', 'tests/r20_pack_direction_route.gd')))
for module in (r18, r16):
    module.NAME = NAME
    module.HELPERS = HELPERS
r18.BUILD, r18.VERSION, r18.MAIN, r18.FLOOR = BUILD, VERSION, MAIN, FLOOR
r16.MAIN_SCENE, r16.MAIN_SCRIPT = MAIN, MAIN_SCRIPT
r16.TITLE_PREFIX = 'Spillway R20 · '
r16.PROBE = PROJECT / 'tools/r20-pack-probe.gd'
r16.MIN_FREE_GIB = FLOOR / 2**30
r16.LINUX = {NAME + '.x86_64': 'linux_release.x86_64'}
r16.WINDOWS = {NAME + '.exe': 'windows_release_x86_64.exe', NAME + '.console.exe': 'windows_release_x86_64_console.exe'}
r16.EXPECT = dict(r16.EXPECT, main_scene=MAIN, title_prefix=r16.TITLE_PREFIX,
    hud_forbidden=['R12', 'debug'], pack_forbidden_prefixes=[*r16.EXPECT['pack_forbidden_prefixes'], 'res://look/'])


def require(condition, reason):
    if not condition:
        raise Rejected(reason)


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=False).encode()


def pinned_json(path, digest):
    require(r16.digest(path) == digest, 'reference digest changed: ' + str(path))
    return json.loads(Path(path).read_text())


def space(expected=0, scratch=None, assembly=False):
    require(type(expected) is int and expected >= 0, 'invalid output reserve')
    free = shutil.disk_usage(Path.home()).free
    require(free >= FLOOR + expected, 'storage floor: need 15,000,000,000 bytes plus %d bounded output; have %d' % (expected, free))
    if scratch is not None:
        root = Path(scratch).resolve()
        require(root == SCRATCH or SCRATCH in root.parents, 'scratch must stay under ' + str(SCRATCH))
        root.mkdir(parents=True, exist_ok=True)
        require(shutil.disk_usage(root).free >= (ASSEMBLY_LIMIT if assembly else PREP_LIMIT), 'insufficient RAM scratch reserve')
    return free


def bounded(root, limit=PREP_LIMIT):
    size = sum(p.stat().st_size for p in Path(root).rglob('*') if p.is_file())
    require(size <= limit, 'scratch exceeded its byte budget: %d > %d' % (size, limit))
    return size


def preserved_changes(before, after, approved=None):
    changed = {p for p in before if before[p] != after.get(p)}
    require(not changed - OLD_CHANGES, 'unexpected old-file byte changes: ' + ', '.join(sorted(changed - OLD_CHANGES)))
    require(changed <= after.keys(), 'old files may not be deleted')
    if approved is not None:
        require(set(approved) == changed and all(after.get(p) == approved[p] for p in changed), 'frozen intentional old-file hash set differs')
    return {p: after[p] for p in sorted(changed)}


def committed_manifest(commit, prefix, top):
    """hash Git blobs from an explicit root subtree; no archive, import or source writes."""
    rows = r16.git('ls-tree', '-r', '-z', '--full-tree', commit + ':' + prefix, binary=True, cwd=top).split(b'\0')
    entries = []
    for row in filter(None, rows):
        header, path = row.split(b'\t', 1)
        mode, kind, oid = header.split()
        require(mode in (b'100644', b'100755') and kind == b'blob', 'source contains symlink/special file')
        entries.append((path.decode(), oid))
    require(any(p == 'project.godot' for p, _ in entries), 'empty committed project manifest')
    result = {}
    with subprocess.Popen(['git', '-C', str(top), 'cat-file', '--batch'], stdin=subprocess.PIPE, stdout=subprocess.PIPE) as proc:
        try:
            for path, oid in entries:
                proc.stdin.write(oid + b'\n')
                proc.stdin.flush()
                header = proc.stdout.readline().split()
                require(len(header) == 3 and header[0] == oid and header[1] == b'blob', 'Git blob read failed')
                remaining = int(header[2])
                digest = hashlib.sha256()
                while remaining:
                    data = proc.stdout.read(min(remaining, 1 << 20))
                    require(bool(data), 'truncated Git blob')
                    digest.update(data)
                    remaining -= len(data)
                require(proc.stdout.read(1) == b'\n', 'Git blob terminator missing')
                result[path] = digest.hexdigest()
        finally:
            proc.stdin.close()
        require(proc.wait() == 0, 'git cat-file failed')
    return result


def preservation(commit, prefix, approved=None):
    top = Path(r16.git('rev-parse', '--show-toplevel').strip())
    before = committed_manifest(BASE, prefix, top)
    after = committed_manifest(commit, prefix, top)
    baseline = pinned_json(BASELINE, BASELINE_SHA)
    tracked = pinned_json(TRACKED, TRACKED_SHA)
    require(baseline['baseline'] == tracked['baseline'] == BASE, 'wrong R19 baseline commit')
    require(tracked['file_count'] == len(before) == 1309, 'protected R19 inventory incomplete')
    require({p: v['sha256'] for p, v in tracked['files'].items()} == before, 'TRACKED differs from exact R19 Git bytes')
    generated = []
    for path, value in baseline['files'].items():
        if path not in before:
            require(path.endswith('.import'), 'SOURCE contains unknown noncommitted input: ' + path)
            generated.append(path)
            continue
        require(before[path] == value, 'SOURCE differs from exact R19 Git bytes: ' + path)
    changes = preserved_changes(before, after, approved)
    pins = {}
    for path in F2_PATHS:
        require(before[path] == after.get(path) == baseline['files'][path], 'frozen F2 pin differs: ' + path)
        pins[path] = before[path]
    return {'base_commit': BASE, 'old_files': len(before), 'old_manifest_sha256': hashlib.sha256(canonical(before)).hexdigest(),
        'intentional_changes': changes, 'F2_pins': pins, 'baseline_sha256': BASELINE_SHA, 'tracked_sha256': TRACKED_SHA, 'SOURCE_generated_imports_not_tracked': len(generated)}


def baseline_identity():
    build = pinned_json(R19_BUILD, R19_BUILD_SHA)
    verified = pinned_json(R19_VERIFICATION, R19_VERIFICATION_SHA)
    require(build['round'] == 'R19' and build['build'] == 'spillway-2026.11.09-r19'
        and verified['ok'] is True and verified['source_commit'] == build['source_commit']
        and verified['pack_sha256'] == build['pack_sha256'], 'R19 delivery identity/verification differs')
    return build['identity']


def project_files(commit, prefix, top):
    files = r16.git('ls-tree', '-r', '--name-only', commit + ':' + prefix, cwd=top).splitlines()
    require('project.godot' in files and 'scenes/r20.tscn' in files,
        'committed project inventory is empty or missing the configured R20 scene')
    return files


def validate_freeze(freeze, commit):
    require(isinstance(freeze, dict) and type(freeze.get('schema')) is int and freeze['schema'] == 1
        and freeze.get('runtime_frozen') is True, 'parent must explicitly freeze all runtime (schema=1, runtime_frozen=true)')
    require(re.fullmatch('[0-9a-f]{40}', str(freeze.get('source_commit', ''))) is not None
        and freeze['source_commit'] == commit, 'freeze must name this exact full source commit')
    require(freeze.get('new_maps') == list(NEW_MAPS), 'explicit final new_maps must be saltglass, tether-yard, through-line')
    require(freeze.get('required_maps') == list(REQUIRED_MAPS), 'explicit ordered catalog must contain exactly the final eleven maps')
    require(freeze.get('experimental_maps') == list(EXPERIMENTAL_MAPS), 'Movement Lab and exactly Tether Yard/Through Line must be experimental')
    reached = freeze.get('reached_items')
    require(isinstance(reached, list) and bool(reached) and all(type(n) is int for n in reached)
        and reached == list(range(1, len(reached)+1)) and len(reached) <= 6,
        'reached_items must explicitly be a contiguous priority prefix, targeting all six')
    intentional = freeze.get('intentional_changes')
    require(isinstance(intentional, dict) and set(intentional) <= OLD_CHANGES
        and all(isinstance(v, str) and re.fullmatch('[0-9a-f]{64}', v) for v in intentional.values()),
        'freeze needs exact reviewed SHA256 for only listed old presentation/scoring files')
    require(re.fullmatch('[0-9a-f]{64}', str(freeze.get('identity_sha256', ''))) is not None,
        'freeze needs independently reviewed full identity_sha256')
    require('breakwater_geometry' not in freeze and 'breakwater_overlay' not in freeze,
        'R20 permits no Breakwater exception')
    return freeze


def catalog(identity, required):
    listed = identity['registry']['maps']
    require(isinstance(listed, list) and all(isinstance(m, str) for m in listed) and listed == list(required)
        and len(listed) == len(set(listed)) and set(listed) == set(identity['maps']) == set(identity['keys']), 'playable catalog differs from explicit required maps')
    require(set(ORIGINAL_MAPS) <= set(listed), 'original eight maps missing')
    for map_id in listed:
        require(identity['keys'][map_id] and 'server128' in identity['keys'][map_id], 'map lacks playable F2: ' + map_id)
    new = set(listed) - set(ORIGINAL_MAPS)
    ids = [(v['level_id'], v['geometry']) for v in identity['maps'].values()]
    require(len(ids) == len(set(ids)), 'new map aliases an existing identity')
    for m in new:
        require(identity['maps'][m]['geometry'] and identity['maps'][m]['level_id'], 'new map lacks distinct identity')


def identity_boundary(identity, freeze, baseline):
    catalog(identity, freeze['required_maps'])
    require(hashlib.sha256(canonical(identity)).hexdigest() == freeze['identity_sha256'], 'identity differs from parent-reviewed freeze')
    for field in ['order', 'presets', 'families', 'slots', 'record_ticks_version', 'default_preset', 'default_map', 'timing_rules', 'build', 'save_path']:
        require(identity['registry'][field] == baseline['registry'][field], 'original registry changed: ' + field)
    require(identity['start']['map'] == 'breakwater' and identity['start']['preset'] == 'server128', 'default must remain Breakwater/F2')
    for map_id in ORIGINAL_MAPS:
        require(identity['maps'][map_id] == baseline['maps'][map_id], 'original map identity changed: ' + map_id)
        require(identity['keys'][map_id] == baseline['keys'][map_id], 'original preset/geometry/overlay/record/time/hull/law identity changed: ' + map_id)
    for map_id in freeze['required_maps']:
        for preset, key in identity['keys'][map_id].items():
            require(preset in baseline['registry']['presets'] and key['preset'] == preset
                and key['clean'] is True and key['pending'] == '', 'wrong preset or unavailable map identity: ' + map_id)
            prior = baseline['keys']['breakwater'][preset]
            for field in ('physics_hz', 'engine_hz', 'fingerprint', 'hull'):
                require(key[field] == prior[field], 'physical preset drift: %s/%s/%s' % (map_id, preset, field))
    require(identity['main_script'] == MAIN_SCRIPT, 'identity must observe the actual R20 host')
    require(identity['maps']['saltglass']['geometry'] != baseline['maps']['saltglass']['geometry'], 'Saltglass must not retain stale R19 geometry')
    for map_id in ('saltglass', 'tether-yard'):
        for preset, key in identity['keys'][map_id].items():
            prior = baseline['keys'][map_id].get(preset)
            require(prior is None or (key['course_key'] != prior['course_key'] and key['record_identity'] != prior['record_identity']),
                'stale R19 revised-map record identity: %s/%s' % (map_id, preset))


def clean_source():
    require(not r16.git('status', '--porcelain', '--untracked-files=all', '--', '.').strip(),
        'commit all project source, including untracked files, before runtime freeze/export')


def integration_ready(freeze):
    require(freeze['reached_items'] == list(range(1, 7)), 'partial priority progress is not a complete R20 delivery')
    require(not PENDING_FEATURES, 'final exact-pack feature probes pending: ' + ', '.join(PENDING_FEATURES))


def engine_pins():
    require(r16.digest(r16.EDITOR) == r16.EDITOR_SHA256, 'pinned official editor changed')
    r16.templates()
    for name, value in r16.LICENCE_SHA256.items():
        require(r16.digest(r16.LICENCES / name) == value, 'Godot licence changed: ' + name)
    return {'version': r16.ENGINE_VERSION, 'editor_sha256': r16.EDITOR_SHA256,
        'archive_sha256': r16.TEMPLATES_SHA256, 'members_sha256': dict(r16.TEMPLATE_MEMBERS)}


def preflight(freeze=None, strict=False, runtime=False):
    require(r16.git('branch', '--show-current').strip() == 'feat/spillway-r20', 'only feat/spillway-r20 is allowed')
    if strict:
        clean_source()
    commit = r16.git('rev-parse', 'HEAD').strip()
    require(subprocess.run(['git', 'merge-base', '--is-ancestor', BASE, commit], cwd=PROJECT).returncode == 0, 'source must descend from the exact R19 preservation baseline')
    top = Path(r16.git('rev-parse', '--show-toplevel').strip())
    prefix = str(PROJECT.relative_to(top))
    if strict:
        validate_freeze(freeze, commit)
    files = r16.git('ls-tree', '-r', '--name-only', commit + ':' + prefix, cwd=top).splitlines()
    require('project.godot' in files and bool(r16.resources(files)), 'empty committed project inventory')
    if not runtime:
        return {'commit': commit, 'prefix': prefix, 'files': len(files), 'preservation': preservation(commit, prefix, freeze['intentional_changes'] if strict else None),
            'baseline_identity_sha256': hashlib.sha256(canonical(baseline_identity())).hexdigest(),
            'engine_pins': engine_pins(), 'pending': list(PENDING_FEATURES), 'runtime_checked': False, 'working_tree_clean': not bool(r16.git('status', '--porcelain', '--untracked-files=all', '--', '.').strip())}
    project = r16.committed('project.godot').splitlines()
    for line in ['run/main_scene="' + MAIN + '"', 'config/name="Spillway"', 'config/version="' + VERSION + '"']:
        require(line in project, 'committed project identity missing: ' + line)
    require('config/use_custom_user_dir=true' not in project, 'shared Spillway profile folder changed')
    scene = r16.committed('scenes/r20.tscn')
    require('path="' + MAIN_SCRIPT + '"' in scene and all(s in scene.splitlines() for s in ['persist = true', 'record_runs = true']), 'R20 scene must explicitly persist and record')
    for path, parent in [('scripts/r20_main.gd','r19_main'), ('scripts/r19_main.gd','r17_main'), ('scripts/r17_main.gd','r16_main'), ('scripts/r20_hud.gd','r19_hud'), ('scripts/r19_hud.gd','r18_hud')]:
        require(r16.committed(path).startswith('extends "res://scripts/' + parent + '.gd"'), 'host/HUD inheritance changed: ' + path)
    preset = next((b for b in re.split(r'^(?=\[preset\.\d+\]$)', r16.committed('export_presets.cfg'), flags=re.M) if 'name="R17 Pack"' in b.splitlines()), '')
    require('platform="Linux"' in preset and all(x in preset for x in ['look/*', 'docs/*', 'tests/*', 'tools/*']), 'export must exclude private concepts and verification helpers')
    require(r16.digest(r16.EDITOR) == r16.EDITOR_SHA256, 'pinned official editor changed')
    engine = subprocess.check_output([str(r16.EDITOR), '--headless', '--version'], text=True, timeout=15).strip()
    require(engine == r16.ENGINE_VERSION, 'wrong pinned Godot version')
    for name, digest in r16.LICENCE_SHA256.items():
        require(r16.digest(r16.LICENCES / name) == digest, 'Godot licence changed: ' + name)
    return {'commit': commit, 'prefix': prefix, 'tree': r16.git('rev-parse', commit + ':' + prefix, cwd=top).strip(),
        'files': project_files(commit, prefix, top),
        'stamp': r16.git('show', '-s', '--format=%ct', commit).strip(), 'engine': engine, 'templates': r16.templates(),
        'project_name': 'Spillway', 'preservation': preservation(commit, prefix, freeze['intentional_changes'] if strict else None)}


def readme(platform, facts, identity, launch, user_dir, newline):
    return newline.join(['SPILLWAY R20', BUILD + ' · source ' + facts['commit'], '', *launch, '',
        'Esc lists every course and experiment. F2 is Bhop server (128 Hz); F5 is AA1000.',
        'Maps (Esc): ' + ', '.join(identity.get('maps', {}).get(m, {}).get('name', m) for m in identity.get('registry', {}).get('maps', [])),
        'F9 shows telemetry and the Look C / L label. Advanced holds R13 mouse settings.',
        'L compares painted and original presentation. Experimental maps retain EXPERIMENTAL in the title.',
        'Records/settings: spillway_r16.cfg in ' + user_dir, 'Automatic local recordings: r16_runs/ in the same folder.',
        'The R16 build identifier in the behavioral host is retained; R20 recording metadata uses ' + BUILD + '.',
        'Race a friend: Esc > Race a friend > enter your player name > Export my clean best.',
        'Send the one .spillghost file. Drop received files into ghosts/ next to the executable.',
        'Open ghosts folder shows that folder; Refresh imports the list; choose a named player/time to race.',
        'Only this exact R20 version and matching map revision/preset can race. G toggles the chosen ghost.',
        'Tether Yard: hold left mouse to attach; hold right mouse to reel. Both reproduce the inherited reel mode.',
        'Esc offers automatic reel and alternative grapple models. Ground reel pulls under an anchor; jump to lift.',
        'Export all attempts: Esc > Export my runs. Send the real ZIP manually; ghosts are separate .spillghost files.',
        'Windows recordings: %APPDATA%\\Godot\\app_userdata\\Spillway\\r16_runs\\',
        'Windows settings: spillway_r16.cfg beside the r16_runs folder.',
        'Licences and asset provenance: licenses/. Nothing is uploaded.',
        'Linux exact release checks and limits are in VERIFICATION.json beside the ZIPs.',
        'Native Windows execution is unverified. Static hashes/shared format do not establish Windows execution.',
        'Full old-host parity is separate from delivery. Scripted completion does not establish enjoyment.', ''])


r16.readme = readme


def copy_probes(root, out):
    for name in ['r16-pack-probe.gd', 'r20-pack-probe.gd', 'r20-direction-driver.gd']:
        shutil.copy2(root / 'tools' / name, out / name)


def source_identity(source, evidence, files):
    out = evidence / 'identity'
    out.mkdir(parents=True)
    copy_probes(source, out)
    probe = out / 'r20-pack-probe.gd'
    (out / 'spec.json').write_text(json.dumps({'mode': 'identity', 'out': str(out), 'committed_resources': r16.resources(files), 'expect': {}}))
    r16.checked([r16.EDITOR, '--headless', '--path', source, '--check-only', '--script', probe], source, r16.engine_env(out / 'parse-profile'), out / 'parse.log', 60)
    override = source / 'override.cfg'
    require(not override.exists(), 'frozen source carries override.cfg')
    try:
        override.write_text('[autoload]\nPackProbe="*%s"\n' % probe)
        r16.checked([r16.EDITOR, '--headless', '--audio-driver', 'Dummy', '--path', source, '--', '--pack-probe=' + str(out / 'spec.json')], source, r16.engine_env(out / 'profile'), out / 'engine.log', 180)
    finally:
        override.unlink(missing_ok=True)
    report = json.loads((out / 'probe.json').read_text())
    require(report['failures'] == 0, 'source identity probe failed')
    identity = report['identity']
    require(identity['main_script'] == MAIN_SCRIPT and identity['hud_script'] == 'res://scripts/r20_hud.gd', 'wrong R20 source host/HUD')
    return identity


def harness(folder, work, probe_root=PROJECT):
    work.mkdir(parents=True)
    for name in [NAME + '.x86_64', NAME + '.pck']:
        os.link(folder / name, work / name)
    copy_probes(probe_root, work)
    (work / 'override.cfg').write_text('[autoload]\nPackProbe="*%s"\n' % (work / 'r20-pack-probe.gd'))
    return work


def verify_manifest(build):
    require(isinstance(build, dict) and isinstance(build.get('freeze'), dict) and isinstance(build.get('source_commit'), str), 'manifest lacks source/freeze')
    integration_ready(validate_freeze(build['freeze'], build['source_commit']))
    expected = {'build': BUILD, 'round': 'R20', 'main_scene': MAIN, 'project_version': VERSION,
        'behavioral_build': r16.BUILD, 'recording_build': BUILD, 'records_file': r16.SAVE_PATH,
        'engine': r16.ENGINE_VERSION, 'user_data_folder': 'Spillway', 'default_map': 'breakwater', 'default_preset': 'server128',
        'export_preset': 'R17 Pack', 'export_editor_sha256': r16.EDITOR_SHA256, 'helpers_committed': True}
    require(all(build.get(k) == v for k, v in expected.items()), 'manifest presentation/behavior/recording identity differs')
    commit, prefix = build['source_commit'], build['source_project_path']
    freeze = validate_freeze(build['freeze'], commit)
    top = Path(r16.git('rev-parse', '--show-toplevel').strip())
    require(prefix == str(PROJECT.relative_to(top)), 'wrong source project path')
    tar = r16.source_archive(commit, prefix, top)
    files = project_files(commit, prefix, top)
    hashes = {p: hashlib.sha256(r16.git('show', commit + ':' + prefix + '/' + p, binary=True, cwd=top)).hexdigest() for p in HELPERS}
    require(build['source_tree'] == r16.git('rev-parse', commit + ':' + prefix, cwd=top).strip()
        and build['source_archive_sha256'] == hashlib.sha256(tar).hexdigest()
        and build['source_manifest_sha256'] == hashlib.sha256(r16.archive_manifest(tar).encode()).hexdigest()
        and build['source_files'] == len(files) and build['helpers_sha256'] == hashes == r16.helper_hashes(), 'source/helper/archive manifest differs from frozen bytes')
    require(build['runtime']['members_sha256'] == r16.TEMPLATE_MEMBERS and build['runtime']['archive_sha256'] == r16.TEMPLATES_SHA256, 'official runtime pins differ')
    require(build['preservation'] == preservation(commit, prefix, freeze['intentional_changes']), 'preservation manifest differs')
    identity_boundary(build['identity'], freeze, baseline_identity())
    return files


r18.verify_manifest = verify_manifest


def validate_archive(archive, names, executable=None):
    actual = archive.namelist()
    require(len(actual) == len(set(actual)) and sorted(actual) == sorted(names) and archive.testzip() is None, 'unsafe, duplicate, unexpected or CRC-damaged ZIP entries')
    for name in actual:
        require(bool(name) and not name.startswith('/') and '\\' not in name
            and all(p not in ('', '.', '..') for p in name.split('/')), 'unsafe ZIP path')
        mode = archive.getinfo(name).external_attr >> 16
        require((mode & 0o170000) in (0, 0o100000) and not mode & 0o6000, 'ZIP contains symlink, special file or unsafe mode')
    if executable:
        require(archive.getinfo(executable).external_attr >> 16 & 0o111 == 0o111, 'Linux ZIP lost executable mode')


def static_check(dist, work):
    build = json.loads((dist / 'BUILD.json').read_text())
    files = verify_manifest(build)
    for platform, runtimes in [('linux-x86_64', r16.LINUX), ('windows-x86_64', r16.WINDOWS)]:
        folder = NAME + '-' + platform
        path = dist / ('%s-%s-%s.zip' % (BUILD, platform, build['source_commit'][:8]))
        names = [folder + '/' + p for p in [*runtimes, NAME + '.pck', 'BUILD.json', 'README.txt', *r18.licence_files(files)]]
        with zipfile.ZipFile(path) as archive:
            validate_archive(archive, names, folder + '/' + NAME + '.x86_64' if platform.startswith('linux') else None)
    return r18.static_check(dist, work)


def pack_negatives(folder, work, evidence):
    results = []
    for kind in ['missing-pack', 'malformed-pack', 'missing-critical-r17-sky']:
        for old in ([False, True] if kind == 'missing-critical-r17-sky' else [False]):
            label = kind + ('-old-look' if old else '')
            case = work / ('negative-' + label)
            case.mkdir()
            os.link(folder / (NAME + '.x86_64'), case / (NAME + '.x86_64'))
            if kind == 'malformed-pack':
                (case / (NAME + '.pck')).write_bytes(b'not a Godot pack')
            elif kind == 'missing-critical-r17-sky':
                data = (folder / (NAME + '.pck')).read_bytes()
                require(b'whiteout-sky.png' in data, 'critical-sky negative target absent')
                (case / (NAME + '.pck')).write_bytes(data.replace(b'whiteout-sky.png', b'whiteouX-sky.png'))
            args = ['--r16-map=whiteout-relay'] + (['--look=old'] if old else [])
            code, text = r18.normal_start(case, evidence / label, args)
            refused = type(code) is int and code != 0
            refused = refused and 'r20: ' + BUILD not in text
            result = {'case': label, 'refused': refused, 'exit': code, 'old_look': old}
            (evidence / label / 'result.json').write_text(json.dumps(result, indent=2))
            results.append(result)
            shutil.rmtree(case)
            require(refused, 'broken package silently accepted: ' + label)
    return results


def strict_legacy_style(value, at):
    require(isinstance(value, dict) and value.get('tick') == at and value.get('v') == 1, 'invalid R20 style tick/schema')
    require(value.get('kind') in ('speed', 'sync', 'gap', 'edge', 'near_miss', 'crouch_save', 'backward_bhop', 'sideways_bhop'), 'unknown R20 style kind')
    base, mult, points = value.get('base'), value.get('mult'), value.get('points')
    direction, combo = value.get('direction_mult'), value.get('combo_mult')
    require(type(base) is int and 0 < base <= 1500 and type(points) is int and 0 < points <= 18000, 'invalid R20 style points/base')
    require(type(direction) in (int, float) and math.isfinite(direction) and 1 <= direction <= 4
        and type(combo) in (int, float) and combo in (1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75, 3)
        and type(mult) in (int, float) and math.isfinite(mult) and math.isclose(mult, direction * combo, abs_tol=1e-9)
        and abs(points - base * mult) <= (mult + 1) / 2 + 1e-8, 'invalid R20 direction/combo product')
    require(isinstance(value.get('m'), dict) and isinstance(value.get('geo'), dict) and isinstance(value.get('label'), str) and bool(value['label']), 'invalid R20 style detail')


DIRECTION_UNITS = {'backward_bhop': 160, 'sideways_bhop': 50}
DIRECTION_FORMULA = 'unit*n*(n-1)/2'
DIRECTION_BANK_REASONS = frozenset(('finish', 'facing', 'ground_dwell', 'no_motor_jump',
    'flight_timeout', 'flight_short', 'travel_short', 'rise_short', 'fall_short',
    'efficiency', 'heading', 'novelty'))


def finite_number(value):
    try:
        return type(value) in (int, float) and math.isfinite(value)
    except OverflowError:
        return False


def strict_stack_style(value, at):
    """validate a bank independently of the ordinary combo and its legacy point ceiling."""
    fields = {'v', 'kind', 'tick', 'time_s', 'elapsed', 'points', 'base', 'mult',
        'direction_mult', 'combo_mult', 'combo', 'label', 'm', 'geo', 'p', 'clean'}
    require(isinstance(value, dict) and set(value) == fields, 'invalid direction bank fields')
    require(type(at) is int and at >= 0 and type(value['tick']) is int
        and value['tick'] == at and type(value['v']) is int and value['v'] == 2, 'invalid direction bank tick/schema')
    measures = value['m']
    require(isinstance(measures, dict) and set(measures) == {'direction', 'hops', 'unit',
        'formula', 'reason', 'start_tick', 'last_hop_tick', 'end_ups'}, 'invalid direction bank measures')
    direction, hops = measures['direction'], measures['hops']
    require(isinstance(direction, str) and direction in DIRECTION_UNITS
        and value['kind'] == direction + '_bank', 'invalid direction bank kind')
    require(value['label'] == ('Backwards banked' if direction == 'backward_bhop' else 'Half-sideways banked'),
        'direction bank label differs from its category')
    require(type(hops) is int and 2 <= hops <= at + 1
        and type(measures['unit']) is int and measures['unit'] == DIRECTION_UNITS[direction]
        and measures['formula'] == DIRECTION_FORMULA, 'invalid direction bank formula')
    expected = DIRECTION_UNITS[direction] * hops * (hops - 1) // 2
    require(type(value['base']) is int and type(value['points']) is int
        and value['base'] == value['points'] == expected, 'invalid direction bank points')
    require(all(finite_number(value[key]) and value[key] == 1
        for key in ('mult', 'direction_mult', 'combo_mult'))
        and type(value['combo']) is int and value['combo'] == 0, 'direction bank must be outside the ordinary combo')
    require(type(measures['start_tick']) is int and type(measures['last_hop_tick']) is int
        and 0 <= measures['start_tick'] < measures['last_hop_tick'] <= at
        and hops <= measures['last_hop_tick'] - measures['start_tick'] + 1, 'invalid direction bank hop ticks')
    require(isinstance(measures['reason'], str) and measures['reason'] in DIRECTION_BANK_REASONS
        and finite_number(measures['end_ups']) and measures['end_ups'] >= 300, 'invalid direction bank end')
    require(all(finite_number(value[key]) and value[key] >= 0 for key in ('time_s', 'elapsed'))
        and type(value['clean']) is bool and value['geo'] == {}
        and isinstance(value['label'], str) and bool(value['label'])
        and isinstance(value['p'], list) and len(value['p']) == 3
        and all(finite_number(component) for component in value['p']), 'invalid direction bank observation')


def strict_direction(value, at):
    """validate the payload tick; queued loss envelope attribution is a separate audit."""
    fields = {'record_kind', 'v', 'kind', 'reason', 'serial', 'tick', 'time_s',
        'direction', 'hops', 'pending', 'unit', 'formula', 'm'}
    require(isinstance(value, dict) and set(value) == fields, 'invalid direction diagnostic fields')
    require(type(at) is int and at >= 0 and type(value['tick']) is int and value['tick'] == at
        and type(value['v']) is int and value['v'] == 1 and value['record_kind'] == 'direction', 'invalid direction diagnostic tick/schema')
    direction, hops = value['direction'], value['hops']
    require(isinstance(direction, str) and direction in DIRECTION_UNITS
        and type(hops) is int and 1 <= hops <= at + 1
        and type(value['unit']) is int and value['unit'] == DIRECTION_UNITS[direction]
        and value['formula'] == DIRECTION_FORMULA, 'invalid direction diagnostic formula')
    require(type(value['pending']) is int
        and value['pending'] == DIRECTION_UNITS[direction] * hops * (hops - 1) // 2,
        'invalid direction diagnostic amount')
    require(type(value['serial']) is int and value['serial'] > 0
        and finite_number(value['time_s']) and value['time_s'] >= 0
        and isinstance(value['m'], dict), 'invalid direction diagnostic observation')
    require(isinstance(value['reason'], str) and bool(value['reason']), 'missing direction diagnostic reason')
    require(value['kind'] in ('direction_pending', 'direction_banked', 'direction_lost'), 'invalid direction diagnostic kind')
    if value['kind'] == 'direction_pending':
        require(value['reason'] == 'eligible', 'invalid pending reason')
        measures = value['m']
        require(set(measures) == {'air_s', 'track_m', 'progress_m', 'rise_m', 'fall_m',
            'heading_dot', 'landing_ups'} and all(finite_number(component) for component in measures.values()),
            'invalid pending flight measures')
        require(0.18 <= measures['air_s'] <= 1.2 and measures['track_m'] >= 3
            and measures['progress_m'] >= measures['track_m'] * 0.85
            and measures['rise_m'] >= 0.25 and measures['fall_m'] >= 0.2
            and measures['heading_dot'] >= 0.5 and measures['landing_ups'] >= 300,
            'pending diagnostic violates R19 flight eligibility')
    elif value['kind'] == 'direction_banked':
        require(value['reason'] in DIRECTION_BANK_REASONS and value['m'] == {}, 'invalid bank diagnostic reason')
    else:
        require(value['m'] == {} and value['reason'] not in ('pause', 'resume'), 'invalid loss diagnostic reason')


def strict_style(value, at):
    if isinstance(value, dict) and value.get('v') == 2:
        strict_stack_style(value, at)
        return
    strict_legacy_style(value, at)
    require(type(value['v']) is int and type(value['tick']) is int
        and value['kind'] not in DIRECTION_UNITS and value['direction_mult'] == 1,
        'R20 ordinary style must not multiply or immediately score direction')


def source_horizontal_ups(x, z):
    """reproduce the pinned float32 Vector2.length before its double source-unit division."""
    f32 = lambda value: struct.unpack('<f', struct.pack('<f', value))[0]
    x, z = f32(x), f32(z)
    return f32(math.sqrt(f32(f32(x * x) + f32(z * z)))) / 0.0254


def audit_style_stream(rec, rows):
    """reconcile scored events and non-scored state transitions with post-step observations."""
    n = len(rows)
    scored = [[] for _ in rows]
    captures = [[] for _ in rows]
    lifecycle = [[] for _ in rows]
    banks = {}
    by_kind = {}
    diagnostics = []
    for event in rec.events:
        source, kind, at, value = event.get('s'), event.get('k'), event['t'], event['d']
        if source == 'capture' and kind == 'style':
            require(type(at) is int and 0 <= at < n, 'invalid style lifecycle attribution')
            strict_style(value, at)
            scored[at].append(value)
            entry = by_kind.setdefault(value['kind'], {'n': 0, 'points': 0})
            entry['n'] += 1; entry['points'] += value['points']
            if value['v'] == 2:
                key = (at, value['m']['direction'], value['m']['hops'])
                require(key not in banks, 'duplicate direction bank')
                banks[key] = value
        elif kind == 'direction':
            require(source in ('capture', 'event') and type(at) is int and 0 <= at < n,
                'invalid direction lifecycle attribution')
            require(isinstance(value, dict) and type(value.get('tick')) is int
                and 0 <= value['tick'] <= at, 'direction diagnostic refers to a future or missing sample')
            strict_direction(value, value['tick'])
            require(value['kind'] == 'direction_lost' or value['tick'] == at,
                'only a queued loss may precede its capture tick')
            require(source != 'event' or value['kind'] == 'direction_lost',
                'lifecycle must never bank or synthesize a pending landing')
            (captures if source == 'capture' else lifecycle)[at].append(value)
            diagnostics.append(value)
        elif source == 'capture':
            raise Rejected('unknown capture kind')
        elif kind == 'style':
            raise Rejected('scored style must belong to a physical capture')
    require([d['serial'] for d in diagnostics] == list(range(1, len(diagnostics) + 1)),
        'missing, duplicate or reordered direction diagnostics')
    inactive = {'kind': '', 'hops': 0, 'pending': 0, 'unit': 0}
    active, last, start_tick, last_hop_tick, total = dict(inactive), {}, -1, -1, 0

    def transition(value, at):
        nonlocal active, last, start_tick, last_hop_tick
        if value['kind'] == 'direction_pending':
            require((active['kind'] == '' and value['hops'] == 1)
                or (active['kind'] == value['direction'] and value['hops'] == active['hops'] + 1),
                'direction pending does not extend the observed chain')
            if active['kind'] == '':
                start_tick = value['tick']
            last_hop_tick = value['tick']
            active = {'kind': value['direction'], 'hops': value['hops'],
                'pending': value['pending'], 'unit': value['unit']}
            return
        require(active == {'kind': value['direction'], 'hops': value['hops'],
            'pending': value['pending'], 'unit': value['unit']}, 'direction terminal does not match the observed pending chain')
        key = (at, value['direction'], value['hops'])
        bank = banks.pop(key, None) if value['kind'] == 'direction_banked' else None
        if value['kind'] == 'direction_banked' and value['pending'] > 0:
            require(bank is not None and bank['points'] == value['pending']
                and bank['m']['reason'] == value['reason'] and bank['m']['start_tick'] == start_tick
                and bank['m']['last_hop_tick'] == last_hop_tick, 'direction bank differs from its earned diagnostic chain')
            speed = source_horizontal_ups(rec.columns['actual_v_x'][at], rec.columns['actual_v_z'][at])
            require(speed >= 300 and json_numbers_match(bank['m']['end_ups'], speed),
                'direction bank speed differs from its actual recorded sample')
        else:
            require(bank is None and key not in banks, 'lost or zero pending chain awarded a bank')
        last = value
        active = dict(inactive)

    for i, row in enumerate(rows):
        for value in captures[i]:
            if value['kind'] == 'direction_pending':
                require(finite_number(row.get('style_time_s'))
                    and math.isclose(value['time_s'], row['style_time_s'], abs_tol=0.00000051, rel_tol=0),
                    'pending diagnostic time differs from the physical style clock')
                require(json_numbers_match(row.get('style_direction_verdict'),
                    {'verdict': 'eligible', 'tick': value['tick'], 'm': value['m']}),
                    'pending diagnostic flight differs from the live detector verdict')
            transition(value, i)
        state = row.get('style_direction')
        require(isinstance(state, dict) and set(state) == {'kind', 'hops', 'pending', 'unit',
            'formula', 'suspended', 'last'} and state['formula'] == DIRECTION_FORMULA
            and state['suspended'] is False, 'independent direction observation is missing or suspended')
        require(isinstance(state['kind'], str) and state['kind'] in ('', *DIRECTION_UNITS)
            and all(type(state[key]) is int for key in ('hops', 'pending', 'unit')),
            'invalid observed direction state types')
        # a first physical flight names its direction before its zero-point landing arms.
        expected = active if active['hops'] else dict(active, kind=state['kind'],
            unit=DIRECTION_UNITS.get(state['kind'], 0))
        require({key: state[key] for key in active} == expected
            and json_numbers_match(state['last'], last), 'recorded direction transitions differ from live pending state')
        require('style_events' in row and json_numbers_match(scored[i], row['style_events']),
            'recorded style events differ from live scoring observations')
        total += sum(value['points'] for value in scored[i])
        require(type(row.get('style_score')) is int and row['style_score'] == total,
            'style score differs from live scoring observation')
        # lifecycle events are emitted after the recorder's last physical sample.
        for value in lifecycle[i]:
            require(any(event.get('s') == 'event' and event.get('k') == value['reason']
                and event.get('t') == value['tick'] for event in rec.events),
                'direction lifecycle loss has no matching host boundary')
            transition(value, i)
    require(not banks, 'direction bank has no matching bank diagnostic')
    outcome = rec.seal['outcome']
    require(type(outcome.get('style', {}).get('score')) is int and outcome['style']['score'] == total
        and json_numbers_match(outcome['style'].get('by_kind'), by_kind),
        'style total differs from recorded and observed scored events')
    return total, by_kind


# retain the strict R19 v1 schema and physical/input audit; versioned banks are reconciled separately.
digest, profile_root, json_numbers_match = r16.digest, r16.profile_root, r16.json_numbers_match
PROJECT_NAME, SAVE_PATH = r16.PROJECT_NAME, r16.SAVE_PATH

MOTION_KEYS = {87, 65, 83, 68, 32, 4194326, 4194325, 69}


def raw_motion_input(data):
    """canonicalize the independent pre-serialization receipt, including mouse edges."""
    f32 = lambda value: struct.unpack('<f', struct.pack('<f', value))[0]
    if data.get('type') == 'key' and (data.get('physical_keycode') or data.get('keycode')) in MOTION_KEYS:
        return (1, data['keycode'], data['physical_keycode'], int(data['pressed']) | (int(data.get('echo', False)) << 1), 0., 0., 0., 0.)
    if data.get('type') == 'mouse_button':
        return (2, data['button_index'], 0, int(data['pressed']) | (int(data.get('double_click', False)) << 2), f32(data.get('factor', 1.)), 0., 0., 0.)
    if data.get('type') == 'mouse_motion':
        return (3, 0, 0, 0, *[f32(value) for value in data['screen_relative']], *[f32(value) for value in data['relative']])
    return None

def audit_profile(profile, before, after, report, helpers, allow_config=False):
    """admit only observed attempt paths, never a wildcard for arbitrary new profile files."""
    result = {'ok': False, 'runs': [], 'errors': []}
    try:
        if helpers.get('tools/analyze-r16-runs.py') != digest(PROJECT / 'tools/analyze-r16-runs.py'):
            raise Rejected('current independent reader differs from the pinned helper')
        spec = importlib.util.spec_from_file_location('r16_delivery_analyzer', PROJECT / 'tools/analyze-r16-runs.py')
        analyzer = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(analyzer)
        attempts = report['recordings']['attempts']
        observer = report['recordings']['observed']
        if report['recordings'].get('audit_version') != 2 or not isinstance(report['recordings'].get('delivered_inputs'), list):
            raise Rejected('independent raw input observations are missing')
        deliveries = report['recordings']['delivered_inputs']
        expected_ids = {a['run_id'] for a in attempts}
        if any(r.get('run_id') not in expected_ids or type(r.get('tick')) is not int or r['tick'] < 0 for r in deliveries):
            raise Rejected('unknown attempt or invalid raw input tick')
        tape_rows_all = report.get('recorded_tape_inputs', [])
        if not isinstance(tape_rows_all, list) or any(r.get('run_id') not in expected_ids or type(r.get('recording_tick')) is not int or r['recording_tick'] < 0 for r in tape_rows_all):
            raise Rejected('unknown attempt or invalid tape input tick')
        if report.get('mode') == 'play':
            if (type(report.get('recorded_tape_tick_count')) is not int or report['recorded_tape_tick_count'] < 1
                    or len(tape_rows_all) != report['recorded_tape_tick_count']
                    or [r.get('tape_tick') for r in tape_rows_all] != list(range(len(tape_rows_all)))):
                raise Rejected('packed play lacks its complete recorded tape input coverage')
        carry = []
        root = profile_root(profile).resolve()
        allowed = {PROJECT_NAME + '/' + SAVE_PATH.removeprefix('user://')} if allow_config else set()
        if not attempts:
            raise Rejected('probe observed no recorded attempts')
        run_ids, paths = set(), set()
        for attempt in attempts:
            path = Path(attempt['path']).resolve()
            relative = path.relative_to(root)
            if len(relative.parts) != 2 or relative.parts[0] != 'r16_runs' or path.suffix != '.r16run' or path.is_symlink():
                raise Rejected('attempt is outside the exact isolated r16_runs directory')
            name = PROJECT_NAME + '/' + str(relative)
            if name in before or str(path) in paths or attempt['run_id'] in run_ids:
                raise Rejected('duplicate or preexisting attempt in the probe')
            paths.add(str(path)); run_ids.add(attempt['run_id']); allowed.add(name)
            rec = analyzer.read(path)
            if not rec.ok or rec.header['run_id'] != attempt['run_id']:
                raise Rejected('complete attempt refused: ' + str(rec.errors))
            require(rec.header.get('metadata', {}).get('build') == BUILD, 'recording metadata must name R20')
            c = rec.columns
            n = len(c['tick'])
            if c['tick'] != list(range(n)) or n < 1:
                raise Rejected('missing, duplicate or unordered recorded tick')
            outcome = rec.seal.get('outcome', {})
            if outcome.get('kind') != attempt['kind']:
                raise Rejected('attempt boundary differs from the observed boundary')
            rows = [r for r in observer if r['run_id'] == attempt['run_id']]
            # the autoload attaches before the first motor frame, including pre-arm idle.
            if len(rows) != n or [r['tick'] for r in rows] != list(range(n)):
                raise Rejected('independent observations do not cover every recorded tick')
            held_names = []
            for event in rec.events:
                if event.get('k') == 'held_names':
                    held_names = event['d']['names']
            import struct
            f32 = lambda v: struct.unpack('<f', struct.pack('<f', v))[0]
            for i, row in enumerate(rows):
                for field in ('p', 'v'):
                    if [c[field + '_' + a][i] for a in 'xyz'] != [f32(v) for v in row[field]]:
                        raise Rejected('%s differs from actual motor observation at tick %d' % (field, i))
                for field in ('yaw', 'pitch', 'dt', 'elapsed', 'physics_hz', 'checkpoint', 'respawns'):
                    if c[field][i] != (struct.unpack('<d', bytes.fromhex(row['scalar_hex'][field]))[0] if field in row.get('scalar_hex', {}) else row[field]):
                        raise Rejected('%s differs from actual observation at tick %d' % (field, i))
                expected_held = sum(1 << j for j, name in enumerate(held_names) if row['held'].get(name, False))
                if c['held'][i] != expected_held:
                    raise Rejected('held input differs from actual observation at tick %d' % i)
            # compare every decoded field with the current engine reader, including input order.
            engine = report['reader_runs'][str(path)]
            if not engine['ok'] or not json_numbers_match(engine['header'], rec.header) or not json_numbers_match(engine['seal'], rec.seal) or not json_numbers_match(engine['events'], rec.events):
                raise Rejected('engine and Python readers disagree')
            for field, fmt, _ in analyzer.TICK_LAYOUT:
                values = ([v for i in range(n) for v in [c[field + '_' + axis][i] for axis in 'xyz']]
                          if field in analyzer.VECTORS else c[field])
                raw = b''.join(struct.pack('<' + (fmt[0] if field in analyzer.VECTORS else fmt), value) for value in values)
                if raw.hex() != engine['column_hex'][field]:
                    raise Rejected('engine/Python column bytes disagree: ' + field)
            for field, fmt, _ in analyzer.INPUT_LAYOUT:
                if b''.join(struct.pack('<' + fmt, value) for value in rec.inputs[field]).hex() != engine['input_hex'][field]:
                    raise Rejected('engine/Python input bytes disagree: ' + field)
            # the raw observer sees Input before serialization; reset tails live in boundary events.
            wanted_inputs = [[] for _ in range(n)]
            wanted_inputs[0].extend(carry)
            carry = []
            tail = []
            for delivery in (r for r in deliveries if r['run_id'] == attempt['run_id']):
                value = raw_motion_input(delivery['data'])
                if value is None or delivery['tick'] > n:
                    raise Rejected('invalid or unconsumed raw input observation')
                (wanted_inputs[delivery['tick']] if delivery['tick'] < n else tail).append(value)
            if tail:
                boundaries = [e for e in rec.events if e.get('s') == 'event' and e.get('k') == outcome.get('kind')]
                if not boundaries:
                    raise Rejected('raw input tail has no observed lifecycle boundary')
                boundary = boundaries[-1]['d']
                if outcome.get('kind') in ('spawn', 'restart', 'practice', 'map', 'quit'):
                    saved_tail = [raw_motion_input(v) for v in boundary.get('inputs', [])]
                    if tail != [v for v in saved_tail if v is not None]:
                        raise Rejected('raw input tail differs from the reset boundary')
                elif type(boundary.get('inputs_carried')) is int and boundary['inputs_carried'] >= len(tail):
                    carry = tail
                else:
                    raise Rejected('raw input tail was not consumed or carried')
            recorded_inputs = [[] for _ in range(n)]
            for j, tick in enumerate(rec.inputs['tick']):
                if rec.inputs['kind'][j] in (2, 3) or (rec.inputs['kind'][j] == 1 and (rec.inputs['aux'][j] or rec.inputs['code'][j]) in MOTION_KEYS):
                    if type(tick) is not int or tick < 0 or tick >= n:
                        raise Rejected('recorded input lies outside its tick stream')
                    recorded_inputs[tick].append(tuple(rec.inputs[k][j] for k in ('kind', 'code', 'aux', 'flags', 'x', 'y', 'x2', 'y2')))
            if recorded_inputs != wanted_inputs:
                raise Rejected('recorded motion input differs from independently delivered raw input')
            tape_rows = [r for r in tape_rows_all if r['run_id'] == attempt['run_id']]

            codes = {'w': 87, 'a': 65, 's': 83, 'd': 68, 'space': 32, 'ctrl': 4194326, 'shift': 4194325, 'e': 69}
            for row in tape_rows:
                at = row['recording_tick']
                if at >= n:
                    raise Rejected('unconsumed tape observation beyond the seal')
                indices = [j for j, tick in enumerate(rec.inputs['tick']) if tick == at]
                keys = [(rec.inputs['aux'][j] or rec.inputs['code'][j], bool(rec.inputs['flags'][j] & 1))
                        for j in indices if rec.inputs['kind'][j] == 1]
                want = [(codes[e['key']], e['edge'] == 'press') for e in row['keys']]
                mouse = [(rec.inputs['x'][j], rec.inputs['y'][j]) for j in indices if rec.inputs['kind'][j] == 3]
                want_mouse = [tuple(f32(v) for v in row['mouse']['screen_relative'])] if row['mouse'] else []
                if keys != want or mouse != want_mouse:
                    raise Rejected('delivered input edges/mouse differ on their actual tick %d' % at)
            if [e.get('q') for e in rec.events] != list(range(len(rec.events))) or any(type(e.get('t')) is not int or not -1 <= e['t'] < n for e in rec.events):
                raise Rejected('event sequence or tick attribution is invalid')
            total, by_kind = audit_style_stream(rec, rows)
            if outcome.get('kind') == 'finish':
                if rec.seal.get('finish_tick') != n - 1 or not (c['flags'][-1] & 2):
                    raise Rejected('finish did not include and seal its final observed tick')
                if not outcome.get('clean') and outcome.get('style', {}).get('best_eligible'):
                    raise Rejected('practice recording claimed clean style eligibility')
            result['runs'].append({'path': str(path), 'sha256': digest(path), 'ticks': n, 'kind': outcome.get('kind'),
                                   'score': total, 'inputs': len(rec.inputs['tick']), 'both_readers': True})
        if carry:
            raise Rejected('unconsumed raw input at final attempt boundary')
        changed = {name for name in after if before.get(name) != after[name]}
        deleted = set(before) - set(after)
        if deleted or changed - allowed or not paths or not all(after.get(PROJECT_NAME + '/' + str(Path(p).relative_to(root))) for p in paths):
            raise Rejected('unobserved profile change: changed=%s deleted=%s' % (sorted(changed - allowed), sorted(deleted)))
        result['ok'] = True
    except (KeyError, OSError, ValueError, TypeError, Rejected) as error:
        result['errors'].append(str(error))
    return result


def friend_profile_audit(profile, before, after, report, helpers, allow_config):
    # only these exact preferences and binary cache writes may be produced by friend UI.
    permitted = set(report.get('friend_profile_files', {}))
    for name in permitted:
        require(name == 'Spillway/r19_ghost_share/selection.json' or re.fullmatch(r'Spillway/r19_ghost_share/cache/[0-9a-f]{64}\.r16run', name), 'unrecognized friend profile file')
        path = r16.profile_root(profile).parent / name
        require(after.get(name) == report['friend_profile_files'][name] == digest(path), 'friend preference/cache receipt differs')
        if name.endswith('.r16run'):
            require(path.stat().st_size <= 4 * 2**20 and digest(path) == path.stem, 'friend binary cache differs from its content-addressed name')
        if name.endswith('selection.json'):
            prefs = json.loads(path.read_text())
            require(prefs == {'player': 'Release probe', 'selected': ''}, 'friend selection must be restored to local best')
    filtered = {k:v for k,v in after.items() if k not in permitted}
    old = {k:v for k,v in before.items() if k not in permitted}
    result = audit_profile(profile, old, filtered, report, helpers, allow_config)
    result['friend_files'] = sorted(permitted)
    return result


def native_checks(folder, build, files, args, evidence, work, routes):
    host = harness(folder, work / 'harness')
    args.pack_required = r16.resources(files)
    args.require, args.native_backend, args.identity, args.controls_fps = [], 'amd', build['identity'], 60
    runs = {}
    with DesktopGuard(evidence / 'desktop-guard', allow_unavailable=args.desktop_unavailable) as desktop:
        with r16.nd.NativeDisplay(evidence / 'native-display', displays=(args.display,), desktop=desktop.desktop, min_free_gib=FLOOR / 2**30) as display:
            args._active_display = display
            cases = [('startup', None), ('controls', None)]
            for route in routes:
                cases += [('play', route), ('reload', route)]
            best = {}
            for mode, route in cases:
                space(100_000_000)
                label = mode if route is None else route['route']['name'] + '-' + mode
                out = evidence / label
                profile = evidence / (label + '-profile' if route is None else route['route']['name'] + '-profile')
                if mode != 'reload':
                    r16.seed_old_profiles(profile)
                before = r16.profile_files(profile)
                spec = r16.spec_for(mode, host, out, args, args.identity, {'profile_state': 'loaded' if mode == 'reload' else 'new', **({'records': best} if mode == 'reload' else {})}, route['route'] if route else None)
                spec['expect']['required_maps'] = build['freeze']['required_maps']
                spec['expect']['experimental_maps'] = build['freeze']['experimental_maps']
                if route:
                    spec['route'] = route['route']
                    if mode == 'play':
                        spec.update(tape=route['tape'], arm_motor_steps=route['arm_motor_steps'], reference_trace=route['trace'], capture_ticks=[0, route['ticks'] // 2, route['ticks'] - 1])
                code, text, report, titles = r16.native(host, out, spec, args, profile, route['physics_hz'] if route else 60, r16.route_args(route['route']) if route else ())
                r16.read_recordings(host, out / 'reader', profile, report)
                audit = friend_profile_audit(profile, before, r16.profile_files(profile), report, build['helpers_sha256'], mode == 'play')
                result = {'exit': code, 'checks': len(report.get('checks', [])), 'failures': report.get('failures'),
                    'failed': [c for c in report.get('checks', []) if not c['ok']], 'recordings': audit,
                    'native_backend': report.get('native_backend'), 'titles': sorted(titles), 'frames': len(report.get('frames', [])),
                    'r20_maps': report.get('r20_maps', []), 'friend': report.get('friend', {}),
                    'cwd_empty': not any((out / 'cwd').iterdir())}
                if mode == 'play':
                    best = {key: report['run'].get(key) for key in ['best_time','open_best_time','best_splits','best_segments','record_ticks','style_best','ghost_pointer']}
                    result['exact_source_trace'] = r16.shipped_trace_match(out / 'trace.jsonl', route['trace'])
                    result['input_order'] = r16.packed_input_audit(r18.packed_rows(out / 'trace.jsonl'), json.loads(Path(route['tape']).read_text()), route['input_settings'], observer_path=PROJECT / 'tools/momentum-tape.py', expected_observer_sha256=build['helpers_sha256']['tools/momentum-tape.py'])
                    result['best'] = best
                if mode == 'reload':
                    cfg = 'Spillway/spillway_r16.cfg'
                    result['config_not_rewritten'] = before.get(cfg) is not None and before.get(cfg) == r16.profile_files(profile).get(cfg)
                result['ok'] = (code == 0 and report.get('failures') == 0 and audit['ok'] and not r16.ERRORS.search(text)
                    and 'ObjectDB instances leaked' not in text and result['cwd_empty']
                    and any(t.startswith(r16.TITLE_PREFIX) for t in titles)
                    and (mode != 'controls' or set(r['map'] for r in result['r20_maps']) == set(build['freeze']['required_maps']))
                    and (mode != 'play' or result['friend'].get('ok') is True)
                    and result.get('exact_source_trace', {'ok': True})['ok'] and result.get('input_order', {'ok': True})['ok']
                    and result.get('config_not_rewritten', True))
                runs[label] = result
                (out / 'delivery-result.json').write_text(json.dumps(result, indent=2) + '\n')
                require(result['ok'], 'exact release ' + label + ' failed; see ' + str(out / 'delivery-result.json'))
    runs['display_released'] = display.released
    return runs


def check(dist, args, evidence, work, routes):
    freeze = json.loads((dist / 'BUILD.json').read_text())['freeze']
    validate_freeze(freeze, r16.git('rev-parse', 'HEAD').strip())
    clean_source()
    integration_ready(freeze)
    evidence.mkdir(parents=True)
    build, files, extracted, static = static_check(dist, work / 'extract')
    folder = extracted['linux-x86_64']
    code, text = r18.normal_start(folder, evidence / 'normal-startup')
    line = r16.STARTUP.search(text)
    require(code == 0 and not r16.ERRORS.search(text) and line and line['build'] == r16.BUILD
        and line['key'] == build['identity']['start']['course_key'] and 'r20: ' + BUILD in text
        and 'ObjectDB instances leaked' not in text, 'normal uninstrumented R20 startup failed')
    # friend service may create the portable folder, but startup must not write user state.
    require(not r16.profile_files(evidence / 'normal-startup/profile') and not any((evidence / 'normal-startup/cwd').iterdir()), 'normal startup wrote user files or cwd')
    negatives = pack_negatives(folder, work, evidence / 'negatives')
    runs = native_checks(folder, build, files, args, evidence, work, routes)
    result = {'ok': True, 'source_commit': build['source_commit'], 'pack_sha256': build['pack_sha256'],
        'static': static, 'normal_startup': {'exit': code, 'behavior_identity': line.group(0), 'r20_print': True, 'empty_cwd': True},
        'negative_controls': negatives, 'native_linux': runs,
        'windows': {'static_only': True, 'native_execution': 'unverified', 'shared_format': 'same PCK; release and independent reader checks on Linux'},
        'limits': ['Native Windows execution unverified; even pinned PE execution under Wine is separate evidence, not native Windows.',
        'Full old-host parity is separate. This delivery probes controls on the complete explicit catalog and a clean recorded route/reload.',
        'Private AMD/X11 and synthetic input do not establish physical latency or enjoyment.',
        'R16 behavioral BUILD_ID retained; R20 recording_metadata.build required.']}
    (evidence / 'summary.json').write_text(json.dumps(result, indent=2) + '\n')
    return result


def include_cleanup_tick(plan):
    """keep every generator edge, including its neutral releases at the closing boundary."""
    result = copy.deepcopy(plan)
    end = result['duration_ticks']
    tail = [event for event in result['events'] if event['tick'] >= end]
    if tail:
        require(all(event['tick'] == end and 'key' in event and event.get('edge') == 'release' for event in tail),
            'route generator has non-neutral or late input outside its duration')
        result['duration_ticks'] = end + 1
        result['duration_s'] = (end + 1) / result['physics_hz']
    return result


def saltglass_route_freeze(source, evidence, identity):
    generated = evidence / 'generated-saltglass'
    generated.mkdir(parents=True)
    r16.checked([r16.EDITOR, '--headless', '--audio-driver', 'Dummy', '--fixed-fps', '128',
        '--path', source, '--script', 'res://tests/r20_surf_route.gd', '--', '--out=' + str(generated)],
        source, r16.engine_env(generated / 'engine-profile'), generated / 'engine.log', 180)
    summary = json.loads((generated / 'summary.json').read_text())
    require(summary.get('pass') is True and summary.get('finished') is True
        and summary.get('finish_kind') == 'clean' and summary.get('respawns') == 0
        and summary.get('configured_main') == MAIN_SCRIPT and summary.get('configured_scene') == MAIN
        and summary.get('runner') == 'res://scripts/r15_source_player.gd'
        and summary.get('physics_hz') == summary.get('engine_hz') == 128
        and 40 <= summary.get('elapsed', -1) <= 70
        and summary.get('geometry_hash') == identity['maps']['saltglass']['geometry'],
        'Saltglass release tape generator did not earn the required production route')
    raw_plan = json.loads((generated / 'events.tape.json').read_text())
    plan = include_cleanup_tick(raw_plan)
    tape = generated / 'release.tape.json'
    tape.write_text(json.dumps(plan, indent=1) + '\n')
    route = r16.parse_route('map=saltglass,preset=server128,tape=' + str(tape)
        + ',warmup=33,sensitivity=2.5,name=r20-saltglass')
    frozen = r16.source_route(route, source, evidence, identity)
    frozen['generated_route'] = {'script': 'tests/r20_surf_route.gd',
        'script_sha256': digest(source / 'tests/r20_surf_route.gd'),
        'summary_sha256': digest(generated / 'summary.json'), 'elapsed': summary['elapsed'],
        'normal_spawn_input_only': True, 'original_tape_sha256': digest(generated / 'events.tape.json'),
        'cleanup_tick_added': plan['duration_ticks'] != raw_plan['duration_ticks'],
        'all_original_edges_retained': plan['events'] == raw_plan['events']}
    return frozen


def route_freeze(source, evidence, identity):
    return [*r18.route_freeze(source, evidence, identity), saltglass_route_freeze(source, evidence, identity)]


def output_ok(output, top):
    output = output.resolve()
    require(output == OUTER / 'delivery/spillway-r20', 'R20 output must be the new delivery/spillway-r20 only')
    require(output != top and top not in output.parents and (not output.exists() or not any(output.iterdir())), 'output must be new/empty and outside source; previous deliveries are immutable')
    for ancestor in [output, *output.parents]:
        if ancestor.exists():
            return output, ancestor


def frozen_source(commit, prefix, top, source):
    tar = r16.source_archive(commit, prefix, top)
    with tarfile.open(fileobj=io.BytesIO(tar)) as frozen:
        require(all(m.isfile() or m.isdir() for m in frozen.getmembers()), 'source contains symlinks/special files')
        frozen.extractall(source, filter='data')
    require(all(digest(source / p) == digest(PROJECT / p) for p in HELPERS), 'executed helpers differ from frozen commit')
    return tar


def package(args):
    # no export is reachable until the parent supplies an exact runtime freeze.
    freeze = json.loads(args.freeze.read_text())
    validate_freeze(freeze, r16.git('rev-parse', 'HEAD').strip())
    clean_source()
    integration_ready(freeze)
    facts = preflight(freeze, strict=True, runtime=True)
    top = Path(r16.git('rev-parse', '--show-toplevel').strip())
    output, ancestor = output_ok(args.output, top)
    home_output = ancestor.stat().st_dev == Path.home().stat().st_dev
    space(args.home_reserve if home_output else 0, args.scratch, assembly=True)
    require(args.home_reserve >= 400_000_000, 'HOME output reserve must bound both ZIPs and evidence (at least 400 MB)')
    output.mkdir(parents=True, exist_ok=True)
    evidence = output / 'evidence'
    evidence.mkdir()
    with tempfile.TemporaryDirectory(prefix='assembly-', dir=args.scratch) as temporary:
        work = Path(temporary)
        source = work / 'source'
        tar = frozen_source(facts['commit'], facts['prefix'], top, source)
        manifest = r16.archive_manifest(tar)
        (evidence / 'source-sha256.txt').write_text(manifest)
        assets = r18.asset_manifest(source)
        env = r16.engine_env(work / 'import-profile')
        r16.checked([r16.EDITOR, '--headless', '--path', source, '--import'], source, env, evidence / 'import.log')
        identity = source_identity(source, evidence, facts['files'])
        identity_boundary(identity, freeze, baseline_identity())
        bounded(work, ASSEMBLY_LIMIT)
        pack = work / (NAME + '.pck')
        r16.checked([r16.EDITOR, '--headless', '--path', source, '--export-pack', 'R17 Pack', pack], source, env, evidence / 'export.log')
        bounded(work, ASSEMBLY_LIMIT)
        routes = route_freeze(source, evidence / 'source-routes', identity)
        build = {'game': 'Spillway', 'round': 'R20', 'build': BUILD, 'behavioral_build': r16.BUILD, 'recording_build': BUILD,
            'project_version': VERSION, 'release_candidate': True, 'status': 'verification required; no gameplay promotion',
            'source_commit': facts['commit'], 'source_tree': facts['tree'], 'source_project_path': facts['prefix'],
            'source_archive_sha256': hashlib.sha256(tar).hexdigest(), 'source_manifest_sha256': hashlib.sha256(manifest.encode()).hexdigest(),
            'source_files': len(facts['files']), 'engine': facts['engine'], 'export_editor_sha256': r16.EDITOR_SHA256,
            'export_preset': 'R17 Pack', 'runtime': {'kind': 'official Godot 4.7.2 release export templates',
            'archive': facts['templates']['archive_url'], 'archive_sha256': r16.TEMPLATES_SHA256, 'members_sha256': r16.TEMPLATE_MEMBERS},
            'pack_sha256': digest(pack), 'main_scene': MAIN, 'records_file': SAVE_PATH, 'user_data_folder': 'Spillway',
            'default_map': 'breakwater', 'default_preset': 'server128', 'identity': identity, 'freeze': freeze,
            'preservation': facts['preservation'], 'r17_assets': assets,
            'helpers_sha256': {p:digest(source / p) for p in HELPERS}, 'helpers_committed': True,
            'verification': 'VERIFICATION.json beside ZIPs; raw evidence/ contains exact-release probes',
            'routes': [{k:v for k,v in r.items() if k not in ('trace','tape')} for r in routes]}
        folders = r16.assemble(work, pack, facts, identity, build)
        dist = work / 'candidate'
        dist.mkdir()
        for platform, folder in folders.items():
            z = dist / ('%s-%s-%s.zip' % (BUILD, platform, facts['commit'][:8]))
            r16.archive(folder, z, facts['stamp'])
            shutil.rmtree(folder)
        build['platforms'] = sorted(p.name for p in dist.glob('*.zip'))
        (dist / 'BUILD.json').write_text(json.dumps(build, indent=2) + '\n')
        (dist / 'SHA256SUMS').write_text(''.join('%s  %s\n' % (digest(z),z.name) for z in sorted(dist.glob('*.zip'))))
        # no loose runtime remains when the official executable is launched.
        shutil.rmtree(source)
        result = check(dist, args, evidence / 'check', work / 'verify', routes)
        (dist / 'VERIFICATION.json').write_text(json.dumps(result, indent=2) + '\n')
        (dist / 'README.txt').write_text('Spillway R20 portable candidate. Extract the full ZIP; keep PCK beside executable.\nLinux exact-release verification: VERIFICATION.json. Windows native execution unverified.\nEsc opens maps, Advanced settings and Race a friend. F9 telemetry; L look.\nFull old-host parity and gameplay promotion remain separate.\n')
        total = sum(p.stat().st_size for p in dist.iterdir())
        evidence_size = bounded(evidence, args.home_reserve)
        require(total + evidence_size <= args.home_reserve, 'actual release/evidence exceeds explicit HOME reserve')
        space(total if home_output else 0)
        for path in dist.iterdir():
            shutil.move(path, output / path.name)
        print(json.dumps({'output': str(output), 'source_commit': facts['commit'], 'ok': True}))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    sub.add_parser('prepare', help='read-only committed source, preservation and official engine/runtime pins; no source export')
    for command in ['identity', 'package', 'check']:
        p = sub.add_parser(command)
        p.add_argument('--scratch', type=Path, default=SCRATCH)
        if command != 'package':
            p.add_argument('--runtime-frozen', action='store_true')
            p.add_argument('--source-commit')
        p.add_argument('--display', type=int, choices=range(190,200), default=198)
        p.add_argument('--deadline', type=float, default=600)
        p.add_argument('--desktop-unavailable', action='store_true', help='explicitly preserve a pre-existing unavailable :0 using DesktopGuard')
        if command == 'package':
            p.add_argument('--freeze', type=Path, required=True)
            p.add_argument('--output', type=Path, required=True)
            p.add_argument('--home-reserve', type=int, default=500_000_000)
        else:
            p.add_argument('--evidence', type=Path, required=True)
            if command == 'check':
                p.add_argument('package_dir', type=Path)
    args = parser.parse_args(argv)
    try:
        with r16.cancellation_signals():
            if args.command == 'prepare':
                space(0, SCRATCH)
                bounded(SCRATCH)
                facts = preflight()
                bounded(SCRATCH)
                print(json.dumps({'prepared': True, 'candidate_exported': False, **facts}, indent=2))
            elif args.command == 'package':
                package(args)
            else:
                require(not args.evidence.exists(), 'evidence directory must be new')
                require(args.runtime_frozen is True and args.source_commit == r16.git('rev-parse','HEAD').strip(), 'identity/check requires explicit --runtime-frozen and exact --source-commit')
                clean_source()
                if args.command == 'identity':
                    evidence = args.evidence.resolve()
                    require(evidence == SCRATCH or SCRATCH in evidence.parents, 'preparation evidence must stay under ' + str(SCRATCH))
                    facts = preflight(runtime=True)
                    require(not r16.git('status','--porcelain','--untracked-files=all','--','.').strip(), 'identity freeze requires committed project source')
                    space(0, args.scratch, assembly=True)
                else:
                    space(0, args.scratch, assembly=True)
                    build = json.loads((args.package_dir / 'BUILD.json').read_text())
                    verify_manifest(build)
                args.evidence.mkdir(parents=True)
                with tempfile.TemporaryDirectory(prefix='identity-' if args.command == 'identity' else 'recheck-', dir=args.scratch) as temporary:
                    work = Path(temporary)
                    source = work / 'source'
                    top = Path(r16.git('rev-parse','--show-toplevel').strip())
                    frozen_source(facts['commit'] if args.command == 'identity' else build['source_commit'], facts['prefix'] if args.command == 'identity' else build['source_project_path'], top, source)
                    r16.checked([r16.EDITOR,'--headless','--path',source,'--import'],source,r16.engine_env(work / 'profile'),args.evidence / 'import.log')
                    if args.command == 'identity':
                        identity = source_identity(source,args.evidence,facts['files'])
                        bounded(work, ASSEMBLY_LIMIT)
                        bounded(args.evidence, PREP_LIMIT)
                        (args.evidence / 'IDENTITY.json').write_text(json.dumps(identity,indent=2))
                        print(json.dumps({'identity_sha256':hashlib.sha256(canonical(identity)).hexdigest(), 'evidence':str(args.evidence), 'candidate_exported':False}))
                    else:
                        routes = route_freeze(source,args.evidence / 'source-routes',build['identity'])
                        shutil.rmtree(source)
                        result = check(args.package_dir.resolve(),args,args.evidence / 'check',work / 'verify',routes)
                        (args.evidence / 'VERIFICATION.json').write_text(json.dumps(result,indent=2))
    except (Rejected, r16.nd.NativeDisplayError, RuntimeError, OSError, ValueError, KeyError, TypeError, zipfile.BadZipFile) as error:
        print('package-r20: ' + str(error),file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print('package-r20: cancelled; owned process scopes released',file=sys.stderr)
        return 130
    return 0


if __name__ == '__main__':
    sys.exit(main())
