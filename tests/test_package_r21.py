#!/usr/bin/env python3
"""Pure preparation/refusal tests; synthetic identities never prove runtime behavior."""
import contextlib
import copy
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[1]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


pkg = load('r21_package_test', PROJECT / 'tools/package-r21.py')


def fixture():
    baseline = pkg.baseline_delivery()['identity']
    identity = copy.deepcopy(baseline)
    models = {name: {'synthetic_law': name} for name in pkg.ORIGINAL_MODELS}
    variants = [{'id': 'fixture-elastic-a', 'base': 'elastic', 'rules_sha256': 'c'*64},
                {'id': 'fixture-elastic-b', 'base': 'elastic', 'rules_sha256': 'd'*64}]
    freeze = {'schema': 1, 'runtime_frozen': True, 'source_commit': 'a'*40,
        'identity_sha256': 'b'*64, 'intentional_changes': {},
        'required_maps': list(pkg.REQUIRED_MAPS), 'experimental_maps': list(pkg.EXPERIMENTAL_MAPS),
        'reached_items': [1, 2, 3, 4], 'runtime': {'build': 'synthetic-r21', 'version': 'synthetic-r21',
            'main_scene': 'res://scenes/fixture.tscn', 'main_script': 'res://scripts/fixture.gd',
            'hud_script': 'res://scripts/fixture_hud.gd'}, 'map_versions': {},
        'models': {'original': {name: hashlib.sha256(pkg.canonical(value)).hexdigest() for name, value in models.items()},
                   'elastic_variants': variants}}
    identity['main_script'] = freeze['runtime']['main_script']
    identity['hud_script'] = freeze['runtime']['hud_script']
    for index, name in enumerate(('saltglass', 'tether-yard')):
        version = {'level_id': 'synthetic-'+name, 'level_version': baseline['maps'][name]['level_version']+1,
                   'geometry': str(index+1)*64, 'level_script': 'res://scripts/fixture_'+str(index)+'.gd'}
        freeze['map_versions'][name] = version
        identity['maps'][name].update(version)
        for preset, key in identity['keys'][name].items():
            key['course_key'] = 'synthetic-'+name+'-'+preset
            record = json.loads(key['record_identity'])
            record[1][2], record[1][3], record[2] = version['level_id'], version['level_version'], version['geometry']
            key['record_identity'] = json.dumps(record)
    seal(freeze, identity)
    return baseline, identity, freeze, models


def seal(freeze, identity):
    freeze['identity_sha256'] = hashlib.sha256(pkg.canonical(identity)).hexdigest()


class Preparation(unittest.TestCase):
    def refused(self, function, *args):
        with self.assertRaises(pkg.Rejected):
            function(*args)

    def test_separate_r20_r19_modules_are_unchanged_by_r21(self):
        old20 = load('separate_r20', PROJECT / 'tools/package-r20.py')
        old19 = load('separate_r19', PROJECT / 'tools/package-r19.py')
        watched = ('BUILD', 'NAME', 'HELPERS', 'MAIN', 'VERSION', 'BASE')
        before20 = {k: copy.deepcopy(getattr(old20, k)) for k in watched}
        before19 = {k: copy.deepcopy(getattr(old19, k)) for k in watched}
        before16 = {k: copy.deepcopy(getattr(old20.r16, k)) for k in ('NAME', 'HELPERS', 'EXPECT', 'TITLE_PREFIX', 'PROBE')}
        other = load('second_r21', PROJECT / 'tools/package-r21.py')
        self.assertIsNot(other.r20, old20)
        self.assertIsNot(other.r16, old20.r16)
        self.assertIsNot(other.r16, old19.r16)
        self.assertEqual(before20, {k: getattr(old20, k) for k in watched})
        self.assertEqual(before19, {k: getattr(old19, k) for k in watched})
        self.assertEqual(before16, {k: getattr(old20.r16, k) for k in before16})

    def test_composed_gates_retain_exact_r20_callable_objects(self):
        for name in ('audit_profile', 'audit_style_stream', 'run_export_profile_audit',
                     'raw_motion_input', 'validate_archive', 'pack_negatives', 'native_checks',
                     'route_freeze', 'static_check', 'frozen_source', 'check'):
            self.assertTrue(callable(getattr(pkg.r20, name)))
        self.assertIs(pkg.r16, pkg.r20.r18.r16)
        self.assertTrue(set(pkg.r20.HELPERS) <= set(pkg.HELPERS))
        self.assertTrue(set(pkg.OWNED) <= set(pkg.HELPERS))

    def test_exact_artifact_and_verifier_sources_are_distinct(self):
        build = pkg.baseline_delivery()
        self.assertEqual(build['source_commit'], pkg.ARTIFACT_SOURCE)
        self.assertNotEqual(pkg.ARTIFACT_SOURCE, pkg.BASE)
        self.assertEqual(pkg.BASE, 'e6baa995da84d380abc8b8d6a3769b33e771945e')
        with patch.object(pkg.r16, 'digest', return_value='wrong'):
            self.refused(pkg.baseline_delivery)

    def test_inherited_helpers_are_pinned_to_e6baa(self):
        pins = pkg.inherited_sources(pkg.BASE)
        self.assertTrue(set(pkg.r20.HELPERS) <= set(pins))
        self.assertEqual(pins['tools/check-r20-windows-release.py'], hashlib.sha256(
            pkg.committed_bytes(pkg.BASE, 'tools/check-r20-windows-release.py')).hexdigest())

    def test_preservation_uses_committed_owner_api_and_six_pins(self):
        commit = pkg.r16.git('rev-parse', 'HEAD').strip()
        result = pkg.preservation(commit, {})
        self.assertTrue(result['ok'])
        self.assertEqual(result['baseline_commit'], pkg.BASE)
        self.assertEqual(set(result['F2_pins']), set(pkg.F2_PATHS))
        self.assertGreater(result['baseline_files'], 1309)
        self.assertFalse(hasattr(pkg, 'OLD_CHANGES'))
        self.refused(pkg.preservation, commit, {'scripts/r16_style.gd': 'a'*64})

    def test_missing_or_malformed_freeze_fields_refuse(self):
        _, _, freeze, _ = fixture()
        pkg.validate_freeze(freeze, 'a'*40)
        for key in freeze:
            bad = copy.deepcopy(freeze); del bad[key]
            self.refused(pkg.validate_freeze, bad, 'a'*40)
        for key, value in [('schema', True), ('runtime_frozen', 1), ('source_commit', 'a'*8),
                           ('identity_sha256', ''), ('intentional_changes', {'project.godot': 'bad'}),
                           ('reached_items', [True]), ('reached_items', []), ('reached_items', [1,3]),
                           ('reached_items', [1,2,3,4,5]), ('runtime', {}), ('map_versions', {})]:
            bad = copy.deepcopy(freeze); bad[key] = value
            self.refused(pkg.validate_freeze, bad, 'a'*40)
        self.refused(pkg.validate_freeze, freeze, 'f'*40)

    def test_explicit_catalogs_cannot_drop_duplicate_reorder_or_add_maps(self):
        _, _, freeze, _ = fixture()
        for field in ('required_maps', 'experimental_maps'):
            values = freeze[field]
            for value in (None, values[:-1], values+[values[-1]], list(reversed(values)), values+['fall-line']):
                bad = copy.deepcopy(freeze); bad[field] = value
                self.refused(pkg.validate_freeze, bad, 'a'*40)

    def test_model_ids_hashes_and_exact_two_or_three_variants_required(self):
        _, _, freeze, _ = fixture()
        for key in ('original', 'elastic_variants'):
            bad = copy.deepcopy(freeze); del bad['models'][key]
            self.refused(pkg.validate_freeze, bad, 'a'*40)
        for value in ([], freeze['models']['elastic_variants'][:1], [{}]*4):
            bad = copy.deepcopy(freeze); bad['models']['elastic_variants'] = value
            self.refused(pkg.validate_freeze, bad, 'a'*40)
        for field, value in [('id', 'elastic'), ('base', 'pendulum'), ('rules_sha256', 'bad')]:
            bad = copy.deepcopy(freeze); bad['models']['elastic_variants'][0][field] = value
            self.refused(pkg.validate_freeze, bad, 'a'*40)
        bad = copy.deepcopy(freeze); bad['models']['elastic_variants'][1] = copy.deepcopy(bad['models']['elastic_variants'][0])
        self.refused(pkg.validate_freeze, bad, 'a'*40)

    def test_production_model_observation_must_preserve_each_original_rule(self):
        _, _, freeze, original = fixture()
        observed = copy.deepcopy(original)
        for index, variant in enumerate(freeze['models']['elastic_variants']):
            observed[variant['id']] = {'synthetic_variant': index}
            variant['rules_sha256'] = hashlib.sha256(pkg.canonical(observed[variant['id']])).hexdigest()
        pkg.model_boundary(observed, freeze, original)
        for name in original:
            bad = copy.deepcopy(observed); bad[name]['synthetic_law'] = 'drift'
            self.refused(pkg.model_boundary, bad, freeze, original)
        bad = copy.deepcopy(observed); bad['extra'] = {}
        self.refused(pkg.model_boundary, bad, freeze, original)

    def test_all_original_map_and_through_line_identities_are_exact(self):
        baseline, identity, freeze, _ = fixture()
        pkg.identity_boundary(identity, freeze, baseline)
        for name in (*pkg.ORIGINAL_MAPS, 'through-line'):
            for field in baseline['maps'][name]:
                bad = copy.deepcopy(identity); bad['maps'][name][field] = 'drift'; seal(freeze, bad)
                self.refused(pkg.identity_boundary, bad, freeze, baseline)
            for preset, key in baseline['keys'][name].items():
                for field in key:
                    bad = copy.deepcopy(identity); bad['keys'][name][preset][field] = 'drift'; seal(freeze, bad)
                    self.refused(pkg.identity_boundary, bad, freeze, baseline)

    def test_revised_maps_refuse_old_ghosts_and_Source_or_style_drift(self):
        baseline, identity, freeze, _ = fixture()
        for name in ('saltglass', 'tether-yard'):
            for field in ('course_key', 'record_identity', 'fingerprint', 'hull', 'physics_hz'):
                bad = copy.deepcopy(identity)
                bad['keys'][name]['server128'][field] = baseline['keys'][name]['server128'][field] if field in ('course_key','record_identity') else 'drift'
                seal(freeze, bad); self.refused(pkg.identity_boundary, bad, freeze, baseline)
            for index in (0, 2, 4, 5, 8, 9, 10, 12):
                bad = copy.deepcopy(identity); record = json.loads(bad['keys'][name]['server128']['record_identity'])
                record[index] = 'drift'; bad['keys'][name]['server128']['record_identity'] = json.dumps(record)
                seal(freeze, bad); self.refused(pkg.identity_boundary, bad, freeze, baseline)
        bad = copy.deepcopy(identity); bad['registry']['timing_rules'] = 'drift'; seal(freeze, bad)
        self.refused(pkg.identity_boundary, bad, freeze, baseline)

    def test_whole_identity_hash_must_match(self):
        baseline, identity, freeze, _ = fixture()
        freeze['identity_sha256'] = '0'*64
        self.refused(pkg.identity_boundary, identity, freeze, baseline)

    def test_parent_freeze_cannot_turn_pending_gates_green(self):
        _, _, freeze, _ = fixture()
        pkg.validate_freeze(freeze, 'a'*40)
        self.refused(pkg.integration_ready, freeze)
        for name in ('pending', 'skip_gates', 'allow_failures', 'breakwater_geometry'):
            bad = copy.deepcopy(freeze); bad[name] = []
            self.refused(pkg.validate_freeze, bad, 'a'*40)
        freeze['reached_items'] = [1]
        pkg.validate_freeze(freeze, 'a'*40)
        self.refused(pkg.integration_ready, freeze)

    def test_duplicate_JSON_keys_refuse(self):
        with self.assertRaises(pkg.Rejected):
            json.loads('{"x":1,"x":2}', object_pairs_hook=pkg.unique_object)

    def test_valid_generated_sidecars_and_committed_hashes(self):
        with tempfile.TemporaryDirectory(prefix='r21-sidecars-') as directory:
            root = Path(directory)
            (root/'a.gd').write_bytes(b'extends Node\n')
            (root/'sky.png').write_bytes(b'synthetic png')
            committed = {p.name: pkg.r16.digest(p) for p in root.iterdir()}
            (root/'a.gd.uid').write_bytes(b'uid://abc123\n')
            (root/'sky.png.import').write_bytes(b'[remap]\nimporter="texture"\n')
            self.assertEqual(set(pkg.generated_sidecars(root, committed)), {'a.gd.uid', 'sky.png.import'})
            for name, value in [('a.gd.uid', b'uid://abc\ncode'), ('sky.png.import', b'bad'),
                                ('a.gd.uid', b'uid://abcdefghijklmn\n'), ('a.gd.uid', b'uid://abc'),
                                ('extra.gd', b'code'), ('absent.gd.uid', b'uid://abc'),
                                ('huge.gd.uid', b'x'*65537)]:
                path = root/name; original = path.read_bytes() if path.exists() else None
                path.write_bytes(value); self.refused(pkg.generated_sidecars, root, committed)
                if original is None:
                    path.unlink()
                else:
                    path.write_bytes(original)
            (root/'a.gd').write_bytes(b'changed')
            self.refused(pkg.generated_sidecars, root, committed)

    def test_generated_metadata_policy_does_not_expand_r20(self):
        # r20's committed policy fixes UID length/newline, asset extensions and size.
        old = pkg.committed_bytes(pkg.BASE, 'tools/check-r20-candidate-parity.py').decode()
        self.assertIn("rb'uid://[a-z0-9]{1,13}\\n'", old)
        self.assertIn("('.png', '.jpg', '.hdr', '.gltf', '.glb', '.ttf')", old)
        with tempfile.TemporaryDirectory(prefix='r21-sidecar-policy-') as directory:
            root = Path(directory)
            for name in ('a.webp', 'a.svg', 'a.wav', 'a.otf', 'a.PNG'):
                (root/name).write_bytes(b'fixture')
                (root/(name+'.import')).write_bytes(b'[remap]\n')
                self.refused(pkg.generated_sidecars, root, {name:pkg.r16.digest(root/name)})
                (root/(name+'.import')).unlink(); (root/name).unlink()

    def test_generated_symlinks_and_missing_sources_refuse(self):
        with tempfile.TemporaryDirectory(prefix='r21-symlink-') as directory:
            root = Path(directory); (root/'link').symlink_to('/etc/passwd')
            self.refused(pkg.generated_sidecars, root, {})
            (root/'link').unlink()
            self.refused(pkg.generated_sidecars, root, {'missing.gd':'a'*64})
            (root/'.godot').mkdir(); (root/'.godot/injected.gd').write_bytes(b'extends Node')
            self.refused(pkg.generated_sidecars, root, {})

    def test_storage_plan_has_no_HOME_full_output_or_hidden_cleanup(self):
        plan = pkg.storage_plan()
        self.assertEqual(plan['output'], '/tmp/r21-package-helpers/export/spillway-r21')
        self.assertEqual(plan['home_floor_bytes'], 15_000_000_000)
        self.assertFalse(plan['automatic_cleanup'])
        self.assertLessEqual(plan['prepare_limit_bytes'], 30*2**20)
        self.assertLessEqual(plan['durable_preparation_limit_bytes'], 5*2**20)
        self.refused(pkg.storage_plan, pkg.OUTER/'delivery/spillway-r21')

    def test_prepare_has_no_engine_execution_or_source_mutation(self):
        # all subprocesses in preparation must be Git, never editor/native/export.
        original = subprocess.Popen
        calls = []
        def git_only(args, *a, **kw):
            self.assertEqual(str(args[0]), 'git')
            calls.append(args)
            return original(args, *a, **kw)
        with patch.object(subprocess, 'Popen', side_effect=git_only):
            result = pkg.prepare()
        self.assertTrue(calls)
        self.assertTrue(result['prepared'])
        self.assertFalse(result['release_ready'])
        self.assertFalse(result['candidate_exported'])
        self.assertFalse(result['runtime_checked'])
        self.assertEqual(result['pending'], list(pkg.PENDING_GATES))

    def test_cli_refuses_runtime_before_engine_or_output_creation(self):
        _, _, freeze, _ = fixture()
        freeze['source_commit'] = pkg.r16.git('rev-parse','HEAD').strip()
        with tempfile.TemporaryDirectory(prefix='r21-refusal-') as directory:
            path = Path(directory)/'freeze.json'; path.write_text(json.dumps(freeze))
            for command in ('identity', 'package', 'check'):
                args = [command, '--freeze', str(path)] + ([directory] if command == 'check' else [])
                with patch.object(pkg.r20, 'clean_source'), patch.object(pkg.r16, 'checked') as engine, contextlib.redirect_stderr(io.StringIO()):
                    self.assertEqual(pkg.main(args), 1)
                    engine.assert_not_called()
            self.assertEqual(sorted(p.name for p in Path(directory).iterdir()), ['freeze.json'])


if __name__ == '__main__':
    unittest.main()
