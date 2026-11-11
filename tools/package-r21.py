#!/usr/bin/env python3
"""R21 portable assembly and exact-package verification around private frozen R20 gates.

prepare is engine-free. Runtime commands need explicit execution, committed source,
reviewed identity and installed production component adapters. No default fixtures.
"""
import argparse
import copy
import io
import os
import tarfile
import tempfile
import zipfile
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import types

sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[1]
BASE = 'e6baa995da84d380abc8b8d6a3769b33e771945e'
ARTIFACT_SOURCE = '7f8fb41b741c01455682ae0c6ee612d5d6fd1fc4'
PREFIX = 'projects/foldrunner'
OUTER = Path('/home/thatmike1/foldrunner-build-2026-11-05')
BASE_DELIVERY = OUTER / 'delivery/spillway-r20'
FLOOR = 15_000_000_000
PREP_LIMIT = 30 * 2**20
DURABLE_LIMIT = 2 * 2**20
SCRATCH = Path('/tmp/r21-package-helpers')
EXPORT_OUTPUT = SCRATCH / 'export/spillway-r21'
EXPORT_LIMIT = 700_000_000
ASSEMBLY_RESERVE = 2_200_000_000
RECEIPTS = {
    'BUILD.json': '61389e07d5173fc6498e9af9639689e20676b752153685b40c9150dff504ae75',
    'VERIFICATION.json': 'b12e209a3f4ba46a23ba64365801d91dcb79aa5d1998f87374d47d692a73e880',
    'SHA256SUMS': '51a3b8124d34dc2e87e86a810870a7ad10abc2655937624ed9d4e215ccc992de',
}


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


# r20 constructs private r18/r16 instances; never modify a separately loaded gate.
r20 = load('r21_private_r20', PROJECT / 'tools/package-r20.py')
r18, r16 = r20.r18, r20.r16
Rejected = r20.Rejected
require, canonical = r20.require, r20.canonical
ORIGINAL_MAPS = tuple(r20.ORIGINAL_MAPS)
REQUIRED_MAPS = (*ORIGINAL_MAPS, 'saltglass', 'tether-yard', 'through-line')
EXPERIMENTAL_MAPS = ('experiment', 'tether-yard', 'through-line')
ORIGINAL_MODELS = ('classic', 'pendulum', 'elastic')
F2_PATHS = tuple(r20.F2_PATHS)
OWNED = ('tools/package-r21.py', 'tools/r21-pack-probe.gd',
         'tests/test_package_r21.py', 'docs/r21/DELIVERY.md',
         'tools/r21-delivery-components.py', 'tests/test_r21_delivery_components.py')
PRESERVATION_HELPER = 'tools/check-r21-preservation.py'
HELPERS = tuple(dict.fromkeys((*r20.HELPERS, *OWNED, PRESERVATION_HELPER,
    'tools/check-r20-windows-release.py', 'tools/r19-windows-wine.py')))

# preparation describes outstanding work; runtime readiness comes from actual bindings below.
PENDING_GATES = (
    'final frozen-source Saltglass and Tether production fixture execution',
    'parent-reviewed complete final parity contract and raw 48-play audit',
    'Godot parse/import/export and exact packed lifecycle/control/play/reload audits',
    'exact Windows ZIP all-map Wine startup, raw-proof archival and final publication',
)
NAME = 'SpillwayR21'
ASSEMBLY = SCRATCH / 'assembly'
PROBES = ('r16-pack-probe.gd', 'r20-pack-probe.gd', 'r21-pack-probe.gd',
          'r20-direction-driver.gd', 'r20-raw-input-driver.gd')


class ComponentGate:
    """delivery-owned seam, not an assumed API of an unfinished gameplay component.

    a final adapter names its committed inputs and source/report validators here.
    the freeze pins those exact inputs. Callbacks must return evidence, never bool.
    """
    def __init__(self, paths=(), source=None, packed=None):
        self.paths, self.source, self.packed = tuple(paths), source, packed


# installed adapters still require the parent's complete final freeze and raw artifacts.
delivery = load('r21_delivery_components', PROJECT / 'tools/r21-delivery-components.py')
COMPONENTS = {}  # installed after this module's functions exist


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, 'duplicate JSON key: ' + key)
        result[key] = value
    return result


def read_json(path):
    return json.loads(Path(path).read_text(), object_pairs_hook=unique_object)


def hex_value(value, length):
    return isinstance(value, str) and re.fullmatch('[0-9a-f]{%d}' % length, value) is not None


def committed_bytes(commit, path):
    return r16.git('show', commit + ':' + PREFIX + '/' + path, binary=True, cwd=PROJECT)


def inherited_sources(commit):
    """check every inherited helper before any future runtime operation."""
    paths = tuple(dict.fromkeys((*r20.HELPERS, 'tools/check-r20-windows-release.py',
                                'tools/r19-windows-wine.py')))
    pins = {}
    for path in paths:
        data = committed_bytes(BASE, path)
        require(data == committed_bytes(commit, path) == (PROJECT / path).read_bytes(),
                'inherited gate differs from exact R20 verifier baseline: ' + path)
        pins[path] = hashlib.sha256(data).hexdigest()
    return pins


def baseline_delivery():
    for name, digest in RECEIPTS.items():
        require(r16.digest(BASE_DELIVERY / name) == digest, 'frozen R20 receipt changed: ' + name)
    build = read_json(BASE_DELIVERY / 'BUILD.json')
    verified = read_json(BASE_DELIVERY / 'VERIFICATION.json')
    require(build['round'] == 'R20' and build['source_commit'] == ARTIFACT_SOURCE
            and verified['source_commit'] == ARTIFACT_SOURCE and verified['ok'] is True
            and verified['pack_sha256'] == build['pack_sha256'], 'wrong R20 artifact identity')
    # the verifier-only descendant is evidence about the old ZIP, not its source.
    changes = r16.git('diff', '--name-only', ARTIFACT_SOURCE, BASE, cwd=PROJECT).splitlines()
    require(set(changes) == {PREFIX + '/' + p for p in (
        'tools/check-r20-windows-release.py', 'tests/test_r20_windows_release.py', 'docs/r20/DELIVERY.md')},
        'R20 artifact/verifier distinction no longer verifier-only')
    sums = (BASE_DELIVERY / 'SHA256SUMS').read_text().splitlines()
    require(len(sums) == 2, 'R20 must retain both ZIP checksums')
    checksum_names = []
    for line in sums:
        digest, name = line.split('  ', 1)
        require(hex_value(digest, 64) and Path(name).name == name and name.endswith('.zip'),
                'unsafe R20 checksum entry')
        require((BASE_DELIVERY / name).is_file(), 'frozen R20 ZIP missing: ' + name)
        checksum_names.append(name)
    require(sorted(checksum_names) == sorted(build['platforms'])
            and len(set(checksum_names)) == 2, 'R20 receipt/ZIP membership mismatch')
    return build


def preservation(commit, approved):
    """consume the preservation owner's committed API, with no local allowlist."""
    code = committed_bytes(commit, PRESERVATION_HELPER)
    helper = types.ModuleType('r21_committed_preservation')
    helper.__file__ = str(PROJECT / PRESERVATION_HELPER)
    exec(compile(code, helper.__file__, 'exec'), helper.__dict__)
    require(helper.BASELINE == BASE and helper.SUBTREE == PREFIX, 'wrong preservation baseline/subtree')
    before, after = helper.inventory(BASE), helper.inventory(commit)
    result = helper.compare(before['files'], after['files'], approved)
    if 'project.godot' in result['changed_old_files']:
        require(helper.project_settings_preserved(committed_bytes(BASE, 'project.godot'),
                committed_bytes(commit, 'project.godot')), 'project settings exceed scene/version wiring')
    require(result['ok'] is True, 'R21 preservation refused: ' + '; '.join(result['errors']))
    pins = {p: before['files'][p]['sha256'] for p in F2_PATHS}
    require(all(after['files'].get(p) == before['files'][p] for p in F2_PATHS), 'F2 six-pin drift')
    return dict(result, baseline_commit=BASE, candidate_commit=commit,
                baseline_tree=before['tree'], candidate_tree=after['tree'],
                baseline_archive_sha256=before['archive_sha256'],
                candidate_archive_sha256=after['archive_sha256'], F2_pins=pins,
                checker_sha256=hashlib.sha256(code).hexdigest())


def validate_freeze(freeze, commit):
    require(isinstance(freeze, dict) and type(freeze.get('schema')) is int and freeze['schema'] == 1
            and freeze.get('runtime_frozen') is True, 'explicit schema=1/runtime_frozen=true required')
    require(hex_value(commit, 40) and freeze.get('source_commit') == commit, 'exact full source commit required')
    require(hex_value(freeze.get('identity_sha256'), 64), 'reviewed whole identity SHA256 required')
    require(freeze.get('required_maps') == list(REQUIRED_MAPS), 'exact ordered eleven-map catalog required')
    require(freeze.get('experimental_maps') == list(EXPERIMENTAL_MAPS), 'exact experimental catalog required')
    reached = freeze.get('reached_items')
    require(isinstance(reached, list) and 1 <= len(reached) <= 4
            and all(type(n) is int for n in reached) and reached == list(range(1, len(reached) + 1)),
            'reached_items must be a contiguous priority prefix of R21 spec items 1-4')
    changes = freeze.get('intentional_changes')
    require(isinstance(changes, dict) and all(isinstance(p, str) and hex_value(h, 64) for p, h in changes.items()),
            'exact intentional old-path hashes required; preservation checker owns permissions')
    runtime = freeze.get('runtime')
    require(isinstance(runtime, dict) and set(runtime) == {'build', 'version', 'main_scene', 'main_script', 'hud_script'},
            'parent must freeze all runtime identifiers')
    require(all(isinstance(v, str) and v and '*' not in v for v in runtime.values())
            and runtime['build'].endswith('-r21') and runtime['version'].endswith('-r21'), 'invalid R21 runtime IDs')
    for field, suffix in [('main_scene', '.tscn'), ('main_script', '.gd'), ('hud_script', '.gd')]:
        value = runtime[field]
        require(value.startswith('res://') and value.endswith(suffix)
                and all(p not in ('', '.', '..') for p in value[6:].split('/')), 'invalid runtime resource: ' + field)
    versions = freeze.get('map_versions')
    require(isinstance(versions, dict) and set(versions) == {'saltglass', 'tether-yard'}, 'two revised map contracts required')
    for name, value in versions.items():
        require(isinstance(value, dict) and set(value) == {'level_id', 'level_version', 'geometry', 'level_script'}
                and isinstance(value['level_id'], str) and bool(value['level_id'])
                and type(value['level_version']) is int and value['level_version'] > 0
                and hex_value(value['geometry'], 64) and isinstance(value['level_script'], str)
                and value['level_script'].startswith('res://scripts/') and value['level_script'].endswith('.gd'),
                'invalid revised map version: ' + name)
    models = freeze.get('models')
    require(isinstance(models, dict) and set(models) == {'original', 'elastic_variants'}
            and isinstance(models['original'], dict) and list(models['original']) == list(ORIGINAL_MODELS)
            and all(hex_value(h, 64) for h in models['original'].values()), 'original model rules hashes required')
    variants = models['elastic_variants']
    require(isinstance(variants, list) and len(variants) in (2, 3), 'exact two or three Elastic variants required')
    ids = []
    for variant in variants:
        require(isinstance(variant, dict) and set(variant) == {'id', 'base', 'rules_sha256'}
                and isinstance(variant['id'], str) and re.fullmatch('[a-z][a-z0-9-]*', variant['id']) is not None
                and variant['base'] == 'elastic' and hex_value(variant['rules_sha256'], 64), 'invalid approved Elastic variant')
        ids.append(variant['id'])
    require(len(set(ids)) == len(ids) and not set(ids) & set(ORIGINAL_MODELS), 'duplicate or aliased model IDs')
    require(not any(k in freeze for k in ('pending', 'skip_gates', 'allow_failures', 'breakwater_geometry', 'breakwater_overlay')),
            'gate exemptions are not a freeze contract')
    return freeze


def identity_boundary(identity, freeze, baseline):
    r20.catalog(identity, REQUIRED_MAPS)
    require(hashlib.sha256(canonical(identity)).hexdigest() == freeze['identity_sha256'], 'whole identity differs from freeze')
    require(all(identity.get(field) == baseline.get(field) for field in ('project_name', 'stats_script', 'audio_script')),
            'shared project/stats/audio identity changed')
    require(identity['registry'] == baseline['registry'], 'original preset/style/input/timing registry changed')
    require(identity['start'] == baseline['start'], 'original Breakwater/F2 startup identity changed')
    for name in (*ORIGINAL_MAPS, 'through-line'):
        require(identity['maps'][name] == baseline['maps'][name]
                and identity['keys'][name] == baseline['keys'][name], 'frozen map identity changed: ' + name)
    for name, version in freeze['map_versions'].items():
        require(all(identity['maps'][name].get(k) == v for k, v in version.items()), 'map differs from version freeze: ' + name)
        old = baseline['maps'][name]
        require(version['geometry'] != old['geometry'] and version['level_version'] > old['level_version']
                and version['level_script'] != old['level_script'], 'map needs a new geometry/module/version: ' + name)
        require(set(identity['keys'][name]) == set(baseline['keys'][name]), 'preset membership changed: ' + name)
        for preset, key in identity['keys'][name].items():
            prior = baseline['keys'][name][preset]
            require(key['course_key'] != prior['course_key'] and key['record_identity'] != prior['record_identity'],
                    'changed map would accept old ghosts: ' + name)
            record, previous = json.loads(key['record_identity']), json.loads(prior['record_identity'])
            require(len(record) == len(previous) == 13
                    and record[1] == [name, key['map_kind'], version['level_id'], version['level_version'], identity['maps'][name]['variant']]
                    and record[2] == version['geometry'] and record[3] == identity['maps'][name]['titles'],
                    'record identity does not bind revised geometry/version: ' + name)
            for index in (0, 4, 5, 8, 9, 10, 12):
                require(record[index] == previous[index], 'record timing/Source/style identity drift: ' + name)
            for field in ('preset', 'physics_hz', 'engine_hz', 'fingerprint', 'hull', 'map_kind', 'clean', 'pending'):
                require(key[field] == prior[field], 'Source law/input/hull drift: ' + name + '/' + field)
            if name == 'saltglass':
                require(all(record[i] == previous[i] for i in (6, 7, 11)), 'Saltglass record motor drift')
                for field in ('runner', 'runner_chain', 'mechanics', 'family_version'):
                    require(key[field] == prior[field], 'Saltglass Source motor changed: ' + field)
    require(identity['main_script'] == freeze['runtime']['main_script']
            and identity['hud_script'] == freeze['runtime']['hud_script'], 'host/HUD differs from freeze')


def model_boundary(observed, freeze, baseline):
    """future production observer must supply exact rules, not just model labels."""
    expected = dict(freeze['models']['original'])
    expected.update({v['id']: v['rules_sha256'] for v in freeze['models']['elastic_variants']})
    require(isinstance(observed, dict) and list(observed) == list(expected), 'exact observed model list/order required')
    require(set(baseline) == set(ORIGINAL_MODELS), 'original model observation missing')
    for name in ORIGINAL_MODELS:
        require(hashlib.sha256(canonical(baseline[name])).hexdigest() == expected[name], 'original model law freeze drift: ' + name)
        require(observed[name] == baseline[name], 'original model rules changed: ' + name)
    require(all(hashlib.sha256(canonical(v)).hexdigest() == expected[k] for k, v in observed.items()), 'observed model rules hash differs')


def generated_sidecars(source, committed):
    """retain R20 check-r20-candidate-parity.import_metadata_guard's exact UID/asset policy."""
    source = Path(source)
    generated = {}
    for path in source.rglob('*'):
        require(not path.is_symlink(), 'source/import symlink refused: ' + str(path))
        require(path.is_dir() or path.is_file(), 'special source/import entry refused: ' + str(path))
        if not path.is_file():
            continue
        name = path.relative_to(source).as_posix()
        data = path.read_bytes()
        if name in committed:
            require(hashlib.sha256(data).hexdigest() == committed[name], 'committed snapshot changed: ' + name)
            continue
        require(len(data) <= 65536, 'oversized generated metadata: ' + name)
        if name.endswith('.uid'):
            paired = name[:-4]
            require(paired in committed and paired.endswith(('.gd', '.gdshader'))
                    and re.fullmatch(rb'uid://[a-z0-9]{1,13}\n', data) is not None, 'invalid/unpaired UID sidecar: ' + name)
        elif name.endswith('.import'):
            paired = name[:-7]
            require(paired in committed and Path(paired).suffix in ('.png', '.jpg', '.hdr', '.gltf', '.glb', '.ttf')
                    and data.startswith(b'[remap]\n'), 'invalid/unpaired import sidecar: ' + name)
        else:
            raise Rejected('unknown generated source file: ' + name)
        generated[name] = hashlib.sha256(data).hexdigest()
    require(all((source / p).is_file() for p in committed), 'committed snapshot file missing')
    return generated


def storage_plan(output=EXPORT_OUTPUT):
    require(Path(output).resolve() == EXPORT_OUTPUT, 'full export/evidence must use the bounded /tmp R21 output')
    require(not EXPORT_OUTPUT.exists() or not any(EXPORT_OUTPUT.iterdir()), 'export output must be new/empty')
    return {'output': str(EXPORT_OUTPUT), 'assembly_scratch': str(SCRATCH / 'assembly'),
            'assembly_reserve_bytes': ASSEMBLY_RESERVE, 'full_output_limit_bytes': EXPORT_LIMIT,
            'combined_tmp_reserve_bytes': ASSEMBLY_RESERVE + EXPORT_LIMIT,
            'home_floor_bytes': FLOOR, 'prepare_limit_bytes': PREP_LIMIT,
            'durable_preparation_limit_bytes': DURABLE_LIMIT,
            'final_destination': str(OUTER / 'delivery/spillway-r21'),
            'publication': 'parent verifies lossless raw-proof archive and file-hash manifest on existing trusted backup; then keeps exact verified ZIPs and compact receipts',
            'automatic_cleanup': False}


def resource_path(value):
    require(isinstance(value, str) and value.startswith('res://'), 'resource path required')
    name = value[6:]
    require(name and '\\' not in name and all(part not in ('', '.', '..') for part in name.split('/')),
            'unsafe resource path: ' + value)
    return name


def component_bindings(freeze, manifest):
    """refuse absent implementations before creating output or starting any process."""
    declared = freeze.get('delivery_components')
    require(isinstance(declared, dict) and set(declared) == set(COMPONENTS),
            'final delivery_components paths/hashes required for Saltglass, Tether and parity')
    pins = {}
    for name, gate in COMPONENTS.items():
        require(gate.paths and callable(gate.source) and callable(gate.packed),
                name + ': final actual source/packed contract adapter is not installed')
        expected = declared[name]
        require(isinstance(expected, dict) and set(expected) == set(gate.paths)
                and all(hex_value(value, 64) for value in expected.values()),
                name + ': exact committed adapter/fixture input pins required')
        for path in gate.paths:
            require(resource_path('res://' + path) == path and path in manifest
                    and manifest[path] == expected[path], name + ': contract source differs: ' + path)
        pins[name] = dict(expected)
    return pins


def integration_ready(freeze, manifest=None):
    require(freeze['reached_items'] == [1, 2, 3, 4], 'partial priority progress is not complete R21 delivery')
    commit = freeze['source_commit']
    if manifest is None:
        manifest = r20.committed_manifest(commit, PREFIX, PROJECT)
    for key in ('main_scene', 'main_script', 'hud_script'):
        require(resource_path(freeze['runtime'][key]) in manifest, 'missing committed runtime resource: ' + key)
    for version in freeze['map_versions'].values():
        require(resource_path(version['level_script']) in manifest, 'missing committed revised level module')
    return component_bindings(freeze, manifest)


def tree_bytes(root):
    root = Path(root)
    require(not root.is_symlink(), 'owned resource root is a symlink')
    total = 0
    if root.exists():
        for path in root.rglob('*'):
            require(not path.is_symlink(), 'owned resource symlink refused: ' + str(path))
            require(path.is_dir() or path.is_file(), 'owned special file refused')
            if path.is_file():
                total += path.stat().st_size
    return total


def resource_guard(assembly=False, reserve=False):
    """measure all owned assembly/output together, including tmpfs memory, before work."""
    home = shutil.disk_usage(Path.home()).free
    tmp = shutil.disk_usage('/tmp').free
    available = int(next(row.split()[1] for row in Path('/proc/meminfo').read_text().splitlines()
                         if row.startswith('MemAvailable:'))) * 1024
    size = tree_bytes(SCRATCH)
    required = ASSEMBLY_RESERVE + EXPORT_LIMIT if assembly else PREP_LIMIT
    require(home >= FLOOR, 'HOME below 15,000,000,000-byte floor')
    require(size <= required, 'combined R21 scratch/output exceeded budget')
    if assembly:
        require(tree_bytes(ASSEMBLY) <= ASSEMBLY_RESERVE, 'assembly exceeded 2.2 GB')
        require(tree_bytes(SCRATCH / 'export') <= EXPORT_LIMIT, 'output/evidence exceeded 700 MB')
        require(available >= (required if reserve else 512 * 2**20), 'insufficient available memory for tmpfs work')
    if reserve:
        require(tmp >= required, 'insufficient tmpfs space for combined assembly and output reserve')
    return {'home_free': home, 'tmp_free': tmp, 'memory_available': available, 'owned_bytes': size,
            'assembly_limit': ASSEMBLY_RESERVE, 'output_limit': EXPORT_LIMIT}


def owned_path(path, root, fresh=False):
    path, root = Path(path), Path(root)
    require(path.is_absolute(), 'absolute owned path required')
    require(not any(p.is_symlink() for p in (path, *path.parents)), 'owned path traverses a symlink')
    resolved = path.resolve()
    require(resolved != root and resolved.is_relative_to(root), 'path outside owned ' + str(root))
    if fresh:
        require(not resolved.exists(), 'owned output/evidence must be new: ' + str(resolved))
    return resolved


def preflight(freeze, complete=True):
    commit = r16.git('rev-parse', 'HEAD').strip()
    validate_freeze(freeze, commit)
    require(r16.git('branch', '--show-current').strip() == 'feat/spillway-r21', 'only feat/spillway-r21 allowed')
    r20.clean_source()
    require(subprocess.run(['git', 'merge-base', '--is-ancestor', BASE, commit], cwd=PROJECT).returncode == 0,
            'R21 source must descend from exact e6baa')
    inherited_sources(commit)
    baseline_delivery()
    manifest = r20.committed_manifest(commit, PREFIX, PROJECT)
    if complete:
        integration_ready(freeze, manifest)
    for path in HELPERS:
        require(path in manifest and r16.digest(PROJECT / path) == manifest[path], 'uncommitted helper: ' + path)
    project = committed_bytes(commit, 'project.godot').decode().splitlines()
    runtime = freeze['runtime']
    require(all(line in project for line in ('run/main_scene="' + runtime['main_scene'] + '"',
            'config/version="' + runtime['version'] + '"', 'config/name="Spillway"'))
            and 'config/use_custom_user_dir=true' not in project, 'committed project runtime/profile identity differs')
    scene = committed_bytes(commit, resource_path(runtime['main_scene'])).decode()
    require('path="' + runtime['main_script'] + '"' in scene
            and all(line in scene.splitlines() for line in ('persist = true', 'record_runs = true')),
            'normal production scene must enable real recording/persistence')
    require(committed_bytes(commit, resource_path(runtime['main_script'])).startswith(
            b'extends "res://scripts/r20_main.gd"'), 'R21 must extend the frozen R20 host')
    preset = next((part for part in re.split(r'^(?=\[preset\.\d+\]$)',
            committed_bytes(commit, 'export_presets.cfg').decode(), flags=re.M)
            if 'name="R17 Pack"' in part.splitlines()), '')
    require('platform="Linux"' in preset and all(p in preset for p in ('look/*', 'tests/*', 'tools/*', 'docs/*'))
            and 'override.cfg' not in manifest, 'export exclusions or source override differ')
    return {'commit': commit, 'prefix': PREFIX, 'files': list(manifest), 'manifest': manifest,
            'tree': r16.git('rev-parse', commit + ':' + PREFIX).strip(),
            'stamp': r16.git('show', '-s', '--format=%ct', commit).strip(), 'project_name': 'Spillway',
            'engine': r16.ENGINE_VERSION, 'templates': r16.templates(),
            'preservation': preservation(commit, freeze['intentional_changes'])}


def configure(freeze):
    """explicit private object configuration; physical/recording auditor code stays original."""
    runtime = freeze['runtime']
    r20.BUILD, r20.VERSION, r20.NAME = runtime['build'], runtime['version'], NAME
    r18.BUILD, r18.VERSION, r18.NAME, r18.MAIN = runtime['build'], runtime['version'], NAME, runtime['main_scene']
    r16.NAME, r16.MAIN_SCENE, r16.MAIN_SCRIPT = NAME, runtime['main_scene'], runtime['main_script']
    r16.TITLE_PREFIX, r16.PROBE = 'Spillway R21 · ', PROJECT / 'tools/r21-pack-probe.gd'
    r16.MIN_FREE_GIB = FLOOR / 2**30
    r16.LINUX = {NAME + '.x86_64': 'linux_release.x86_64'}
    r16.WINDOWS = {NAME + '.exe': 'windows_release_x86_64.exe', NAME + '.console.exe': 'windows_release_x86_64_console.exe'}
    for module in (r16, r18):
        module.HELPERS = HELPERS
    r16.EXPECT = dict(r16.EXPECT, main_scene=runtime['main_scene'], title_prefix=r16.TITLE_PREFIX)
    original_spec = _SPEC_FOR
    def bound_spec(*args, **kwargs):
        result = original_spec(*args, **kwargs)
        result['r21'] = copy.deepcopy(freeze)
        return result
    r16.spec_for = bound_spec
    def bounded_engine(*args, **kwargs):
        resource_guard(assembly=True)
        result = _RUN_ENGINE(*args, **kwargs)
        resource_guard(assembly=True)
        return result
    r16.run_engine = bounded_engine
    r16.readme = readme
    r18.verify_manifest = verify_manifest
    r20.verify_manifest = verify_manifest
    r20.harness, r20.space = harness, lambda *a, **kw: resource_guard(assembly=True)
    r20.controls_features_ok = controls_features_ok
    model_ids = (*ORIGINAL_MODELS, *(item['id'] for item in freeze['models']['elastic_variants']))
    def model_boundary_event(rec, event, value):
        if _DIRECTION_BOUNDARY(rec, event, value):
            return True
        # the current production host records actual model selection as this typed loadout.
        data = event.get('d', {})
        typed = (data.get('key') == 'tether_model'
                 and all(type(data.get(key)) is str and data[key] in model_ids for key in ('from', 'to')))
        if data.get('key') == 'tether_anchor_assist':
            typed = all(type(data.get(key)) is bool for key in ('from', 'to'))
        return (value.get('reason') == 'tether_settings' and event.get('s') == 'event'
            and type(event.get('t')) is int and type(value.get('tick')) is int
            and event['t'] == value['tick'] and event.get('k') == 'loadout'
            and getattr(rec, 'header', {}).get('metadata', {}).get('map') == 'tether-yard'
            and typed and data['from'] != data['to'])
    r20.direction_boundary_matches = model_boundary_event


_SPEC_FOR = r16.spec_for
_CONTROLS_OK = r20.controls_features_ok
_RUN_ENGINE = r16.run_engine
_DIRECTION_BOUNDARY = r20.direction_boundary_matches


def readme(platform, facts, identity, launch, user_dir, newline):
    return newline.join(['SPILLWAY R21', r20.BUILD + ' · source ' + facts['commit'], '', *launch, '',
        'Esc opens all eleven maps, Advanced settings, grapple preferences and Race a friend.',
        'F2 is the unchanged 128 Hz Bhop server. F9 shows telemetry. L compares painted and original presentation.',
        'The R16 build identifier in the behavioral host and shared spillway_r16.cfg is preserved.',
        'R21 recording metadata and revised Saltglass/Tether identities reject older incompatible ghosts.',
        'Automatic recordings: r16_runs/ in ' + user_dir, 'RMB reels; release LMB to coast; E remains the lab control.',
        'Export my runs creates a data ZIP. Race a friend exports a separate .spillghost file.',
        'Licences and asset provenance: licenses/. Native Windows execution is unverified.',
        'Exact Linux checks are in VERIFICATION.json; Wine startup is separate and is not native Windows play.', ''])


def copy_probes(root, out):
    for name in PROBES:
        shutil.copy2(root / 'tools' / name, out / name)


def source_identity(source, evidence, files, freeze):
    out = evidence / 'identity'
    out.mkdir(parents=True)
    copy_probes(source, out)
    probe = out / 'r21-pack-probe.gd'
    spec = {'mode': 'identity', 'out': str(out), 'committed_resources': r16.resources(files), 'expect': {}, 'r21': freeze}
    (out / 'spec.json').write_text(json.dumps(spec))
    r16.checked([r16.EDITOR, '--headless', '--path', source, '--check-only', '--script', probe],
                source, r16.engine_env(out / 'parse-profile'), out / 'parse.log', 60)
    override = source / 'override.cfg'
    require(not override.exists(), 'snapshot already carries override.cfg')
    try:
        override.write_text('[autoload]\nPackProbe="*%s"\n' % probe)
        r16.checked([r16.EDITOR, '--headless', '--audio-driver', 'Dummy', '--path', source,
                     '--', '--pack-probe=' + str(out / 'spec.json')], source,
                    r16.engine_env(out / 'profile'), out / 'engine.log', 180)
    finally:
        override.unlink(missing_ok=True)
    report = read_json(out / 'probe.json')
    require(report.get('failures') == 0 and bool(report.get('identity')), 'source identity observer failed or empty')
    identity = report['identity']
    identity_boundary(identity, freeze, baseline_delivery()['identity'])
    model_boundary(report.get('r21_models'), freeze, report.get('r20_models', {}))
    return identity


def frozen_source(facts, source):
    """archive only committed regular blobs; compare every extracted byte and helper."""
    top = Path(r16.git('rev-parse', '--show-toplevel').strip())
    tar = r16.source_archive(facts['commit'], PREFIX, top)
    require(not source.exists(), 'snapshot destination must be new')
    with tarfile.open(fileobj=io.BytesIO(tar)) as archive:
        for member in archive.getmembers():
            require(member.isfile() or member.isdir(), 'archive contains symlink/special entry')
            resource_path('res://' + member.name.rstrip('/'))
        archive.extractall(source, filter='data')
    require(generated_sidecars(source, facts['manifest']) == {}, 'pristine archive generated unexpected sidecars')
    require(all(r16.digest(source / path) == r16.digest(PROJECT / path) for path in HELPERS),
            'executed helpers differ from frozen snapshot')
    return tar


def import_snapshot(source, facts, evidence, work):
    """check before/after import; retain cache and exact generated sidecars for raw proof."""
    require(generated_sidecars(source, facts['manifest']) == {}, 'snapshot not pristine before import')
    env = r16.engine_env(work / 'import-profile')
    r16.checked([r16.EDITOR, '--headless', '--path', source, '--import'], source, env, evidence / 'import.log')
    # the engine cache is outside source provenance. Inventory every cache byte separately.
    cache = source / '.godot'
    cache_files = {}
    if cache.exists():
        require(cache.is_dir() and not cache.is_symlink(), 'import cache symlink/special root')
        for path in cache.rglob('*'):
            require(not path.is_symlink() and (path.is_file() or path.is_dir()), 'import cache special entry')
            if path.is_file():
                require(path.suffix not in ('.gd', '.gdshader', '.py'), 'unexpected source code in import cache')
                cache_files[path.relative_to(cache).as_posix()] = {'sha256': r16.digest(path), 'bytes': path.stat().st_size}
        moved = work / 'import-cache'
        require(not moved.exists(), 'import cache destination exists')
        cache.rename(moved)
    generated = generated_sidecars(source, facts['manifest'])
    (evidence / 'IMPORT.json').write_text(json.dumps({'source_commit': facts['commit'],
        'committed': facts['manifest'], 'generated_sidecars': generated, 'cache': cache_files}, indent=2) + '\n')
    if not cache.exists() and (work / 'import-cache').exists():
        (work / 'import-cache').rename(cache)
    return env, generated


def snapshot_guard(source, facts, generated):
    cache = source / '.godot'
    # no exclusions hidden in the sidecar guard: move the cache aside under owned assembly.
    moved = source.parent / 'guard-cache'
    require(not moved.exists(), 'cache guard destination exists')
    has_cache = cache.exists()
    if has_cache:
        require(not cache.is_symlink(), 'cache symlink refused')
        cache.rename(moved)
    try:
        require(generated_sidecars(source, facts['manifest']) == generated, 'generated sidecar inventory changed after import')
    finally:
        if has_cache:
            moved.rename(cache)


def evidence_binding(component, stage, freeze):
    return {'component': component, 'stage': stage, 'source_commit': freeze['source_commit'],
            'identity_sha256': freeze['identity_sha256']}


def validate_evidence(value, label, root, binding):
    require(isinstance(value, dict), label + ': adapter returned no evidence object')
    require(value.get('binding') == binding, label + ': wrong source/identity/component/stage binding')
    checks, proof = value.get('checks'), value.get('proof')
    require(isinstance(checks, list) and checks and all(isinstance(c, dict)
            and isinstance(c.get('name'), str) and c['name'] and c.get('ok') is True for c in checks),
            label + ': empty, missing or failed actual checks')
    require(isinstance(proof, dict) and proof, label + ': raw proof inventory required')
    for name, digest in proof.items():
        require(hex_value(digest, 64), label + ': invalid proof hash')
        path = owned_path(Path(root) / name, Path(root))
        require(path.is_file() and r16.digest(path) == digest, label + ': proof missing or changed')
    return value


def component_source(name, source, evidence, identity, freeze):
    gate = COMPONENTS[name]
    require(callable(gate.source), name + ': actual production fixture adapter missing')
    evidence.mkdir(parents=True)
    result = gate.source(source, evidence, identity, freeze)
    return validate_evidence(result, name + ' source', evidence, evidence_binding(name, 'source', freeze))


def validate_routes(routes, freeze):
    require(isinstance(routes, list) and routes, 'empty source fixture set refused')
    names = set()
    for item in routes:
        require(isinstance(item, dict) and isinstance(item.get('route'), dict), 'invalid route fixture')
        route = item['route']
        require(route.get('name') not in names and route.get('name') and route.get('preset') == 'server128'
                and route.get('map') in REQUIRED_MAPS and not route.get('game_diff'), 'route alias/preset/exemption refused')
        names.add(route['name'])
        require(item.get('ticks', 0) > 0 and item.get('exit') == 0 and item.get('ordered') is True
                and all(item.get(k) is True for k in ('rate_ok', 'delivery_ok', 'order_ok', 'cleanup_ok'))
                and item.get('integrity_flags') == [], 'fixture has not earned a complete source replay')
        require(item.get('source_finish', {}).get('finished') is True
                and item['source_finish'].get('finish_kind') == 'clean' and item['source_finish'].get('respawns') == 0,
                'fixture must be an earned clean actual production finish')
        require(Path(item.get('trace', '')).is_file() and Path(item.get('tape', '')).is_file(), 'fixture bytes absent')
        plan = read_json(item['tape'])
        require(plan.get('events') and plan.get('duration_ticks') == item['ticks']
                and plan.get('physics_hz') == 128 and item['physics_hz'] == 128, 'empty or wrong-rate fixture tape')
        require(r16.trace_error(r16.read_rows(item['trace']), expected=item['ticks']) is None, 'invalid source trace')
    require({'breakwater', 'saltglass'} <= {item['route']['map'] for item in routes}, 'required release routes missing')
    return routes


def route_freeze(source, evidence, identity, freeze):
    # Through Line uses exactly its frozen generator and reader. Changed courses never do.
    original = r18.route_freeze(source, evidence, identity)
    salt = component_source('saltglass', source, evidence / 'saltglass', identity, freeze)
    tether = component_source('tether', source, evidence / 'tether', identity, freeze)
    parity = component_source('parity', source, evidence / 'parity', identity, freeze)
    routes = original + salt.get('routes', []) + tether.get('routes', [])
    require(salt.get('routes'), 'Saltglass adapter supplied no actual source route')
    tapes = tether.get('feature_tapes')
    models = [*ORIGINAL_MODELS, *(v['id'] for v in freeze['models']['elastic_variants'])]
    require(isinstance(tapes, dict) and set(tapes.get('tether', {})) == set(models), 'all original and variant Tether tapes required')
    require(all(Path(path).is_file() and read_json(path).get('events') for path in tapes['tether'].values()),
            'missing or empty Tether recording-derived tapes')
    features = {**tapes, **r20.through_feature_freeze(source, evidence, identity)}
    features['r21_source_components'] = {name: {'root': str(evidence / name), 'receipt': receipt}
        for name, receipt in [('saltglass', salt), ('tether', tether), ('parity', parity)]}
    for route in routes:
        route['feature_tapes'] = features
    validate_routes(routes, freeze)
    return routes, {name: result for name, result in [('saltglass', salt), ('tether', tether), ('parity', parity)]}


def harness(folder, work, probe_root=PROJECT):
    work.mkdir(parents=True)
    for name in (NAME + '.x86_64', NAME + '.pck'):
        os.link(folder / name, work / name)
    copy_probes(probe_root, work)
    (work / 'override.cfg').write_text('[autoload]\nPackProbe="*%s"\n' % (work / 'r21-pack-probe.gd'))
    return work


def controls_features_ok(result, audit, required_maps):
    # the complete original control/stack/through/export/profile verdict remains mandatory.
    return _CONTROLS_OK(result, audit, required_maps)


def verify_manifest(build):
    require(isinstance(build, dict) and isinstance(build.get('freeze'), dict), 'manifest freeze missing')
    freeze = validate_freeze(build['freeze'], r16.git('rev-parse', 'HEAD').strip())
    facts = preflight(freeze)
    runtime = freeze['runtime']
    expected = {'round': 'R21', 'build': runtime['build'], 'project_version': runtime['version'],
        'main_scene': runtime['main_scene'], 'behavioral_build': r16.BUILD, 'recording_build': runtime['build'],
        'records_file': r16.SAVE_PATH, 'user_data_folder': 'Spillway', 'default_map': 'breakwater',
        'default_preset': 'server128', 'export_preset': 'R17 Pack', 'export_editor_sha256': r16.EDITOR_SHA256,
        'helpers_committed': True, 'engine': r16.ENGINE_VERSION, 'source_project_path': PREFIX, 'release_candidate': True}
    require(all(build.get(k) == v for k, v in expected.items()), 'manifest identity differs')
    top = Path(r16.git('rev-parse', '--show-toplevel').strip())
    tar = r16.source_archive(facts['commit'], PREFIX, top)
    require(build.get('source_commit') == facts['commit'] and build.get('source_tree') == facts['tree']
            and build.get('source_archive_sha256') == hashlib.sha256(tar).hexdigest()
            and build.get('source_manifest_sha256') == hashlib.sha256(r16.archive_manifest(tar).encode()).hexdigest()
            and build.get('source_files') == len(facts['files'])
            and build.get('helpers_sha256') == {p: facts['manifest'][p] for p in HELPERS}
            and build.get('preservation') == facts['preservation'], 'source/helper/provenance manifest differs')
    require(build.get('runtime', {}).get('members_sha256') == r16.TEMPLATE_MEMBERS
            and build['runtime'].get('archive_sha256') == r16.TEMPLATES_SHA256, 'official runtime manifest differs')
    identity_boundary(build['identity'], freeze, baseline_delivery()['identity'])
    assets = json.loads(committed_bytes(facts['commit'], 'assets/look/r17/MANIFEST.json'))
    require(len(assets.get('files', {})) == 14 and all(
            facts['manifest'].get('assets/look/r17/' + name) == digest for name, digest in assets['files'].items()),
            'asset manifest members differ from committed source')
    require(build.get('r17_assets') == {'files': 14,
            'manifest_sha256': facts['manifest']['assets/look/r17/MANIFEST.json']}, 'asset provenance receipt differs')
    return facts['files']


def check(dist, args, evidence, work, routes):
    build = read_json(dist / 'BUILD.json')
    verify_manifest(build)
    validate_routes(routes, build['freeze'])
    evidence.mkdir(parents=True)
    # unchanged R20 ZIP path/mode/CRC and R18 runtime/licence/common-PCK checks.
    build, files, extracted, static = r20.static_check(dist, work / 'extract')
    folder = extracted['linux-x86_64']
    code, text = r18.normal_start(folder, evidence / 'normal-startup')
    line = r16.STARTUP.search(text)
    require(code == 0 and not r16.ERRORS.search(text) and line and line['build'] == r16.BUILD
            and line['key'] == build['identity']['start']['course_key'] and 'r21: ' + r20.BUILD in text
            and 'ObjectDB instances leaked' not in text, 'normal uninstrumented R21 startup failed')
    require(not r16.profile_files(evidence / 'normal-startup/profile')
            and not any((evidence / 'normal-startup/cwd').iterdir()), 'normal startup wrote user data/cwd')
    negatives = r20.pack_negatives(folder, work, evidence / 'negatives')
    require(len(negatives) == 4 and all(n['refused'] and type(n['exit']) is int and n['exit'] != 0 for n in negatives),
            'all four broken-pack nonzero refusals required')
    # original function, including every control, input, recording, friend and reload audit.
    runs = r20.native_checks(folder, build, files, args, evidence, work, routes)
    require(runs.get('display_released') is True, 'private display not released')
    components = {}
    for name, gate in COMPONENTS.items():
        out = evidence / ('packed-' + name)
        out.mkdir()
        components[name] = validate_evidence(gate.packed(folder, build, args, evidence, out, routes),
            name + ' packed', out, evidence_binding(name, 'packed', build['freeze']))
    require(not r16.owned_leftovers(evidence), 'owned engine processes remain')
    result = {'ok': True, 'source_commit': build['source_commit'], 'pack_sha256': build['pack_sha256'],
        'static': static, 'negative_controls': negatives, 'native_linux': runs, 'components': components,
        'normal_startup': {'exit': code, 'behavior_identity': line.group(0), 'r21_print': True, 'empty_cwd': True},
        'windows': {'static_only': True, 'native_execution': 'unverified', 'wine': 'separate explicit wine command required'},
        'limits': ['No native Windows play, enjoyment, physical latency or listening claim.',
                   'Raw proof must be archived losslessly before deleting owned intermediates.']}
    (evidence / 'summary.json').write_text(json.dumps(result, indent=2) + '\n')
    return result


def build_manifest(facts, freeze, identity, tar, pack, assets, routes):
    return {'game': 'Spillway', 'round': 'R21', 'build': r20.BUILD, 'behavioral_build': r16.BUILD,
        'recording_build': r20.BUILD, 'project_version': r20.VERSION, 'release_candidate': True,
        'status': 'Linux verification required; Wine and publication separate', 'source_commit': facts['commit'],
        'source_tree': facts['tree'], 'source_project_path': PREFIX, 'source_files': len(facts['files']),
        'source_archive_sha256': hashlib.sha256(tar).hexdigest(),
        'source_manifest_sha256': hashlib.sha256(r16.archive_manifest(tar).encode()).hexdigest(),
        'engine': facts['engine'], 'export_editor_sha256': r16.EDITOR_SHA256, 'export_preset': 'R17 Pack',
        'runtime': {'kind': 'official Godot 4.7.2 release export templates',
                    'archive': facts['templates']['archive_url'], 'archive_sha256': r16.TEMPLATES_SHA256,
                    'members_sha256': r16.TEMPLATE_MEMBERS},
        'pack_sha256': r16.digest(pack), 'main_scene': freeze['runtime']['main_scene'],
        'records_file': r16.SAVE_PATH, 'user_data_folder': 'Spillway', 'default_map': 'breakwater',
        'default_preset': 'server128', 'identity': identity, 'freeze': freeze, 'preservation': facts['preservation'],
        'r17_assets': assets, 'helpers_committed': True, 'helpers_sha256': {p: facts['manifest'][p] for p in HELPERS},
        'routes': [{k: v for k, v in row.items() if k not in ('trace', 'tape')} for row in routes]}


def package(args, freeze, facts):
    output = Path(args.output)
    storage_plan(output)
    owned_path(output, SCRATCH / 'export', fresh=True)
    resource_guard(assembly=True, reserve=True)
    ASSEMBLY.mkdir(parents=True, exist_ok=True)
    output.mkdir(parents=True)
    evidence = output / 'evidence'
    evidence.mkdir()
    # keep raw proof on failure; parent archives it before explicit owned cleanup.
    work = Path(tempfile.mkdtemp(prefix='assembly-', dir=ASSEMBLY))
    source = work / 'source'
    try:
        tar = frozen_source(facts, source)
        (evidence / 'source-sha256.txt').write_text(r16.archive_manifest(tar))
        env, sidecars = import_snapshot(source, facts, evidence, work)
        identity = source_identity(source, evidence, facts['files'], freeze)
        snapshot_guard(source, facts, sidecars)
        assets = r18.asset_manifest(source)
        resource_guard(assembly=True)
        pack = work / (NAME + '.pck')
        r16.checked([r16.EDITOR, '--headless', '--path', source, '--export-pack', 'R17 Pack', pack],
                    source, env, evidence / 'export.log')
        snapshot_guard(source, facts, sidecars)
        resource_guard(assembly=True)
        routes, features = route_freeze(source, evidence / 'source-routes', identity, freeze)
        snapshot_guard(source, facts, sidecars)
        build = build_manifest(facts, freeze, identity, tar, pack, assets, routes)
        folders = r16.assemble(work, pack, facts, identity, build)
        dist = work / 'candidate'
        dist.mkdir()
        for platform, folder in folders.items():
            r16.archive(folder, dist / ('%s-%s-%s.zip' % (r20.BUILD, platform, facts['commit'][:8])), facts['stamp'])
        build['platforms'] = sorted(path.name for path in dist.glob('*.zip'))
        (dist / 'BUILD.json').write_text(json.dumps(build, indent=2) + '\n')
        (dist / 'SHA256SUMS').write_text(''.join('%s  %s\n' % (r16.digest(path), path.name) for path in sorted(dist.glob('*.zip'))))
        # remove only this assembly's loose source/folders; proof and imported inventory remain.
        shutil.rmtree(source)
        for folder in folders.values():
            shutil.rmtree(folder)
        resource_guard(assembly=True)
        result = check(dist, args, evidence / 'check', work / 'verify', routes)
        result['source_components'] = features
        (dist / 'VERIFICATION.json').write_text(json.dumps(result, indent=2) + '\n')
        require(tree_bytes(dist) + tree_bytes(evidence) <= EXPORT_LIMIT, 'accepted output/proof exceeds 700 MB')
        for path in dist.iterdir():
            shutil.move(path, output / path.name)
        resource_guard(assembly=True)
        return {'ok': True, 'output': str(output), 'source_commit': facts['commit'], 'windows_wine_pending': True,
                'raw_assembly_retained': str(work), 'publication_pending': True}
    except BaseException as error:
        (evidence / 'FAILURE.json').write_text(json.dumps({'ok': False, 'error': str(error), 'retained_work': str(work)}) + '\n')
        raise


def identity_command(args, freeze, facts):
    evidence = owned_path(args.evidence, SCRATCH / 'export', fresh=True)
    resource_guard(assembly=True, reserve=True)
    ASSEMBLY.mkdir(parents=True, exist_ok=True)
    evidence.mkdir(parents=True)
    work = Path(tempfile.mkdtemp(prefix='identity-', dir=ASSEMBLY))
    source = work / 'source'
    frozen_source(facts, source)
    _, generated = import_snapshot(source, facts, evidence, work)
    identity = source_identity(source, evidence, facts['files'], freeze)
    snapshot_guard(source, facts, generated)
    (evidence / 'IDENTITY.json').write_text(json.dumps(identity, indent=2) + '\n')
    resource_guard(assembly=True)
    return {'identity_sha256': hashlib.sha256(canonical(identity)).hexdigest(), 'candidate_exported': False,
            'raw_work': str(work), 'evidence': str(evidence)}


def check_command(args, freeze, facts):
    evidence = owned_path(args.evidence, SCRATCH / 'export', fresh=True)
    dist = owned_path(args.package_dir, SCRATCH / 'export')
    require(read_json(dist / 'BUILD.json')['freeze'] == freeze, 'CLI freeze differs from packaged freeze')
    verify_manifest(read_json(dist / 'BUILD.json'))
    resource_guard(assembly=True, reserve=True)
    ASSEMBLY.mkdir(parents=True, exist_ok=True)
    evidence.mkdir(parents=True)
    work = Path(tempfile.mkdtemp(prefix='recheck-', dir=ASSEMBLY))
    source = work / 'source'
    frozen_source(facts, source)
    _, generated = import_snapshot(source, facts, evidence, work)
    identity = source_identity(source, evidence, facts['files'], freeze)
    routes, _ = route_freeze(source, evidence / 'source-routes', identity, freeze)
    snapshot_guard(source, facts, generated)
    shutil.rmtree(source)
    result = check(dist, args, evidence / 'check', work / 'verify', routes)
    (evidence / 'VERIFICATION.json').write_text(json.dumps(result, indent=2) + '\n')
    return result


WINE_SHA256 = '91dfdd714f2c9078f010341346196d426e81c633ca0865cf7cc678e2825562db'


def wine_command(args, freeze):
    """explicit later invocation on the exact Windows ZIP; never called by package."""
    dist = owned_path(args.package_dir, SCRATCH / 'export')
    out = owned_path(args.evidence, SCRATCH / 'export', fresh=True)
    build = read_json(dist / 'BUILD.json')
    require(build['freeze'] == freeze, 'Wine freeze differs from exact candidate')
    verify_manifest(build)
    require(r16.digest(args.wine) == WINE_SHA256, 'pinned portable Wine loader differs')
    resource_guard(assembly=True, reserve=True)
    ASSEMBLY.mkdir(parents=True, exist_ok=True)
    out.mkdir(parents=True)
    verifier = load('r21_private_windows', PROJECT / 'tools/check-r20-windows-release.py')
    runner = verifier.W
    work = Path(tempfile.mkdtemp(prefix='wine-', dir=ASSEMBLY))
    release = work / 'release'
    # use the same static ZIP/runtime/PCK/licence verifier before executing any PE.
    _, _, extracted, _ = r20.static_check(dist, release)
    folder = extracted['windows-x86_64']
    zname = next(name for name in build['platforms'] if '-windows-' in name)
    before = {str(p.relative_to(folder)): r16.digest(p) for p in folder.rglob('*') if p.is_file()}
    env = dict(os.environ)
    for key in ('DISPLAY', 'WAYLAND_DISPLAY', 'DBUS_SESSION_BUS_ADDRESS', 'SESSION_MANAGER',
                'WINEPREFIX', 'WINESERVER', 'WINELOADER'):
        env.pop(key, None)
    for key in ('HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME', 'XDG_DATA_HOME', 'XDG_RUNTIME_DIR', 'TMPDIR'):
        env[key] = str(work / 'profile' / key.lower())
        Path(env[key]).mkdir(parents=True)
    env.update(WINEPREFIX=str(work / 'prefix'), WINEARCH='win64', WINEDEBUG='-all',
               WINEDLLOVERRIDES='winemenubuilder.exe=d;mscoree,mshtml,winegstreamer=')
    receipt = {'ok': False, 'native_windows': False, 'source_commit': build['source_commit'],
        'zip_sha256': r16.digest(dist / zname), 'pack_sha256': build['pack_sha256'],
        'wine_sha256': WINE_SHA256, 'commands': [], 'maps': [], 'raw_work': str(work),
        'limits': ['Exact official Windows PE startup under Wine only, no native Windows play.']}
    try:
        for map_id in REQUIRED_MAPS:
            resource_guard(assembly=True)
            log, engine_log = out / (map_id + '.log'), out / (map_id + '.engine.log')
            # the repaired R20 seam puts engine logs OUTSIDE the game-data profile.
            command = [args.wine.resolve(), folder / (NAME + '.exe'), '--headless', '--audio-driver', 'Dummy',
                '--log-file', runner.win(engine_log), '--quit-after', '12', '--', '--no-records',
                '--no-run-recordings', '--verify-startup', '--r16-map=' + map_id]
            execution = runner.execute(command, env, folder, log, work, seconds=60)
            text = log.read_text(errors='replace')
            startup = r16.STARTUP.search(text)
            marker = 'r21: ' + freeze['runtime']['build'] + ';'
            require(startup and startup['map'] == map_id and startup['build'] == r16.BUILD
                    and startup['hz'] == '128' and startup['preset'] == 'server128'
                    and startup['records'] == startup['recordings'] == 'off'
                    and marker in text and not r16.ERRORS.search(text)
                    and 'startup_error=' not in text and 'ObjectDB instances leaked' not in text,
                    map_id + ': Wine startup identity/error check failed')
            require(engine_log.is_file() and not engine_log.is_symlink()
                    and 0 < engine_log.stat().st_size <= 8 * 2**20, 'missing/unsafe engine log')
            engine_text = engine_log.read_text(errors='replace')
            require(startup.group(0) in engine_text and marker in engine_text
                    and not r16.ERRORS.search(engine_text) and 'startup_error=' not in engine_text
                    and 'ObjectDB instances leaked' not in engine_text, 'Wine engine log differs or has errors')
            receipt['commands'].append(execution)
            receipt['maps'].append({'map': map_id, 'ok': True, 'log_sha256': r16.digest(log),
                'engine_log_sha256': r16.digest(engine_log), 'startup': startup.group(0)})
        require(before == {str(p.relative_to(folder)): r16.digest(p) for p in folder.rglob('*') if p.is_file()},
                'Wine changed extracted candidate files')
        writes = [str(p.relative_to(work)) for p in work.rglob('*') if p.is_file()
                  and '/godot/app_userdata/spillway/' in p.as_posix().lower()]
        require(not writes, 'no-records Wine startup wrote game data: ' + str(writes))
        receipt['ok'] = True
        receipt['resources'] = resource_guard(assembly=True)
    except BaseException as error:
        receipt['failure'] = str(error)
        raise
    finally:
        try:
            subprocess.run([str(args.wine.parent / 'wineserver'), '-k'], env=env, timeout=5, check=False,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        finally:
            (out / 'RESULT.json').write_text(json.dumps(receipt, indent=2) + '\n')
    return receipt


def prepare():
    resources = resource_guard()
    require(r16.git('branch', '--show-current').strip() == 'feat/spillway-r21', 'only feat/spillway-r21 allowed')
    commit = r16.git('rev-parse', 'HEAD').strip()
    require(subprocess.run(['git', 'merge-base', '--is-ancestor', BASE, commit], cwd=PROJECT).returncode == 0,
            'R21 must descend from exact e6baa R20 baseline')
    build = baseline_delivery()
    try:
        preserved = preservation(commit, {})
    except Rejected as error:
        preserved = {'ok': False, 'approval_required': True, 'reason': str(error)}
    return {'prepared': True, 'release_ready': False, 'candidate_exported': False, 'runtime_checked': False,
        'source_commit': commit, 'preservation_baseline': BASE, 'artifact_source': ARTIFACT_SOURCE,
        'r20_receipts_sha256': dict(RECEIPTS), 'inherited_helpers_sha256': inherited_sources(commit),
        'engine_pins': r20.engine_pins(), 'baseline_identity_sha256': hashlib.sha256(canonical(build['identity'])).hexdigest(),
        'pending': list(PENDING_GATES), 'unbound_components': [name for name, gate in COMPONENTS.items()
            if not gate.paths or not callable(gate.source) or not callable(gate.packed)],
        'storage': storage_plan(), 'resources': resources, 'preservation': preserved,
        'working_tree_clean': not bool(r16.git('status', '--porcelain', '--untracked-files=all', '--', '.').strip())}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    commands.add_parser('prepare', help='Python/Git only; no engine, export or cleanup')
    for name in ('identity', 'package', 'check', 'wine'):
        command = commands.add_parser(name)
        command.add_argument('--freeze', type=Path, required=True)
        command.add_argument('--parity-contract', type=Path)
        command.add_argument('--parity-contract-sha256')
        command.add_argument('--parity-identity', type=Path)
        command.add_argument('--execute-frozen-runtime', action='store_true', help='explicit post-freeze engine authorization; not for preparation')
        command.add_argument('--display', type=int, choices=range(190, 200), default=198)
        command.add_argument('--deadline', type=float, default=600)
        command.add_argument('--desktop-unavailable', action='store_true')
        if name == 'package':
            command.add_argument('--output', type=Path, default=EXPORT_OUTPUT)
        else:
            command.add_argument('--evidence', type=Path, required=True)
        if name in ('check', 'wine'):
            command.add_argument('package_dir', type=Path)
        if name == 'wine':
            command.add_argument('--wine', type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        if args.command == 'prepare':
            result = prepare()
        else:
            require(args.execute_frozen_runtime, 'runtime execution is not authorized by preparation; explicit post-freeze invocation required')
            freeze = validate_freeze(read_json(args.freeze), r16.git('rev-parse', 'HEAD').strip())
            global _delivery_args
            _delivery_args = args
            facts = preflight(freeze)
            delivery.review_inputs(_DeliveryContext(), args, freeze)
            configure(freeze)
            with r16.cancellation_signals():
                if args.command == 'package':
                    result = package(args, freeze, facts)
                elif args.command == 'identity':
                    result = identity_command(args, freeze, facts)
                elif args.command == 'check':
                    result = check_command(args, freeze, facts)
                else:
                    result = wine_command(args, freeze)
        print(json.dumps(result, indent=2))
    except (Rejected, r16.nd.NativeDisplayError, OSError, ValueError, TypeError, KeyError,
            subprocess.CalledProcessError, zipfile.BadZipFile, RuntimeError) as error:
        print('package-r21: ' + str(error), file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print('package-r21: cancelled; owned process scopes released; raw proof retained', file=sys.stderr)
        return 130
    return 0


class _DeliveryContext:
    def __getattr__(self, name):
        if name not in globals():
            raise AttributeError(name)
        return globals()[name]


COMPONENTS = delivery.install(_DeliveryContext())
HELPERS = tuple(dict.fromkeys((*HELPERS, *(p for gate in COMPONENTS.values() for p in gate.paths))))


if __name__ == '__main__':
    sys.exit(main())
