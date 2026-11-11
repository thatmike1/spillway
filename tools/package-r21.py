#!/usr/bin/env python3
"""Engine-free R21 delivery preparation; runtime/export acceptance remains closed.

Compose the committed e6baa R20 gate and its private R18/R16 implementations.
Do not retarget their R20 assertions by replacing strings or weakening failures.
The parent must implement the listed production seams after reviewing the freeze.
"""
import argparse
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
DURABLE_LIMIT = 5 * 2**20
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
         'tests/test_package_r21.py', 'docs/r21/DELIVERY.md')
PRESERVATION_HELPER = 'tools/check-r21-preservation.py'
HELPERS = tuple(dict.fromkeys((*r20.HELPERS, *OWNED, PRESERVATION_HELPER,
    'tools/check-r20-windows-release.py', 'tools/r19-windows-wine.py')))

# these are missing implementations, never a list the external freeze can clear.
PENDING_GATES = (
    'reviewed R21 host/HUD/build identity and inherited R20 probe adaptation',
    'lowered spaced exits: input-earned 40-70s F2, high fin entries, flat landings, no safety/free skip',
    'skill outside lines on real geometry, no hand-placed style bonuses',
    'generous acquisition, preview and blocked/occluded anchor negatives',
    'two or three approved Elastic variant routes, recordings and exact replays',
    'frozen Classic/Pendulum/Elastic law, E/LMB/RMB/reel/release and platform clearance',
    'original-eight parity, eleven-map old/new L, R18 UI, stack, Through Line and export',
    'committed import/UID sidecar audit and final empty-cwd packed runtime suite',
    'two final ZIPs, CRC/SHA/runtime/PCK/manifests/licences and four nonzero negative packs',
    'pinned Wine startup on exact final Windows ZIP for all eleven maps',
    'verified lossless raw-proof archival and bounded final publication',
)


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


def integration_ready(freeze):
    require(freeze['reached_items'] == [1, 2, 3, 4], 'partial priority progress is not complete R21 delivery')
    raise Rejected('R21 production integration pending: ' + '; '.join(PENDING_GATES))


def prepare():
    require(shutil.disk_usage(Path.home()).free >= FLOOR, 'HOME below 15,000,000,000-byte floor')
    require(r16.git('branch', '--show-current').strip() == 'feat/spillway-r21', 'only feat/spillway-r21 allowed')
    commit = r16.git('rev-parse', 'HEAD').strip()
    require(subprocess.run(['git', 'merge-base', '--is-ancestor', BASE, commit], cwd=PROJECT).returncode == 0,
            'R21 must descend from exact e6baa R20 baseline')
    build = baseline_delivery()
    # uncommitted sibling work is reported; only committed Git blobs are inspected.
    result = {'prepared': True, 'release_ready': False, 'candidate_exported': False, 'runtime_checked': False,
              'source_commit': commit, 'preservation_baseline': BASE, 'artifact_source': ARTIFACT_SOURCE,
              'r20_receipts_sha256': dict(RECEIPTS), 'inherited_helpers_sha256': inherited_sources(commit),
              'engine_pins': r20.engine_pins(), 'baseline_identity_sha256': hashlib.sha256(canonical(build['identity'])).hexdigest(),
              'pending': list(PENDING_GATES), 'storage': storage_plan(),
              'working_tree_clean': not bool(r16.git('status', '--porcelain', '--untracked-files=all', '--', '.').strip())}
    exists = subprocess.run(['git', 'cat-file', '-e', commit + ':' + PREFIX + '/' + PRESERVATION_HELPER],
                            cwd=PROJECT, capture_output=True).returncode == 0
    if exists:
        result['preservation'] = preservation(commit, {})
    else:
        # the independent worker may not yet have committed its API; this never opens release gates.
        result['preservation_pending'] = 'committed R21 preservation API unavailable'
    return result


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    commands.add_parser('prepare', help='read committed sources/pins only; no engine, export or cleanup')
    for name in ('identity', 'package', 'check'):
        command = commands.add_parser(name, help='closed pending parent-reviewed runtime integration')
        command.add_argument('--freeze', type=Path, required=True)
        if name == 'package':
            command.add_argument('--output', type=Path, default=EXPORT_OUTPUT)
        if name == 'check':
            command.add_argument('package_dir', type=Path)
    args = parser.parse_args(argv)
    try:
        if args.command == 'prepare':
            print(json.dumps(prepare(), indent=2))
        else:
            freeze = validate_freeze(read_json(args.freeze), r16.git('rev-parse', 'HEAD').strip())
            r20.clean_source()
            integration_ready(freeze)
    except (Rejected, OSError, ValueError, TypeError, KeyError, subprocess.CalledProcessError) as error:
        print('package-r21: ' + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
