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
        # final Saltglass commit includes the parent's two exact approved integration edits.
        approvals = {p: hashlib.sha256(pkg.committed_bytes(commit, p)).hexdigest()
                     for p in ('project.godot', 'scripts/r19_ghost_share.gd')}
        self.refused(pkg.preservation, commit, {})
        result = pkg.preservation(commit, approvals)
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

    def test_slow_reel_observation_cannot_alias_the_reference_rate(self):
        _, _, freeze, _ = fixture()
        # synthetic observations isolate the reel axis from identical spring coefficients.
        original = {name: {'classic': {'reel_ups': 260.0}, 'alternative': {},
                          'controls': 'fixture mouse controls', 'effective_reel_ups': 260.0}
                    for name in pkg.ORIGINAL_MODELS}
        freeze['models']['original'] = {name: hashlib.sha256(pkg.canonical(value)).hexdigest()
                                        for name, value in original.items()}
        observed = copy.deepcopy(original)
        for index, variant in enumerate(freeze['models']['elastic_variants']):
            value = copy.deepcopy(original['elastic'])
            value['effective_reel_ups'] = 180.0 if index == 0 else 220.0
            observed[variant['id']] = value
            variant['rules_sha256'] = hashlib.sha256(pkg.canonical(value)).hexdigest()
        pkg.model_boundary(observed, freeze, original)
        name = freeze['models']['elastic_variants'][0]['id']
        bad = copy.deepcopy(observed); bad[name]['effective_reel_ups'] = 260.0
        self.refused(pkg.model_boundary, bad, freeze, original)
        bad = copy.deepcopy(observed); del bad[name]['effective_reel_ups']
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
                args = [command, '--freeze', str(path)] + (['--evidence', str(Path(directory)/'proof')] if command != 'package' else []) + ([directory] if command == 'check' else [])
                with patch.object(pkg.r20, 'clean_source'), patch.object(pkg.r16, 'checked') as engine, contextlib.redirect_stderr(io.StringIO()):
                    self.assertEqual(pkg.main(args), 1)
                    engine.assert_not_called()
            self.assertEqual(sorted(p.name for p in Path(directory).iterdir()), ['freeze.json'])


class Orchestration(unittest.TestCase):
    """synthetic byte fixtures exercise plumbing, never a runtime acceptance claim."""
    def refused(self, function, *args, **kwargs):
        with self.assertRaises(pkg.Rejected):
            function(*args, **kwargs)

    def test_private_configuration_retains_all_original_audit_code(self):
        separate = load('r21_config_test', PROJECT / 'tools/package-r21.py')
        original = load('r21_unadapted_test', PROJECT / 'tools/package-r20.py')
        _, _, freeze, _ = fixture()
        saved = {name: getattr(separate.r20, name) for name in
            ('native_checks', 'audit_profile', 'audit_style_stream', 'run_export_profile_audit',
             'pack_negatives', 'static_check', 'through_feature_freeze')}
        separate.configure(freeze)
        for name, function in saved.items():
            self.assertIs(getattr(separate.r20, name), function)
            self.assertEqual(function.__code__.co_code, getattr(original, name).__code__.co_code)
        self.assertEqual(original.BUILD, 'spillway-2026.11.10-r20')
        self.assertEqual(original.r16.NAME, 'SpillwayR20')
        self.assertEqual(separate.r16.NAME, 'SpillwayR21')
        self.assertEqual(separate.r16.BUILD, original.r16.BUILD)
        self.assertEqual(separate.r16.EXPECT['build'], original.r16.EXPECT['build'])
        self.assertIs(separate.r20.verify_manifest, separate.verify_manifest)
        self.assertIs(separate.r18.verify_manifest, separate.verify_manifest)
        self.assertEqual(separate.r16.SAVE_PATH, original.r16.SAVE_PATH)
        self.assertTrue(set(original.HELPERS) <= set(separate.r16.HELPERS))

    def test_new_model_stack_boundary_keeps_exact_typed_lifecycle_requirements(self):
        from types import SimpleNamespace
        local = load('r21_boundary_test', PROJECT / 'tools/package-r21.py')
        _, _, freeze, _ = fixture()
        local.configure(freeze)
        rec = SimpleNamespace(header={'metadata': {'map': 'tether-yard'}})
        event = {'s': 'event', 't': 5, 'k': 'loadout',
                 'd': {'key': 'tether_model', 'from': 'elastic', 'to': 'fixture-elastic-a'}}
        diagnostic = {'tick': 5, 'reason': 'tether_settings'}
        self.assertTrue(local.r20.direction_boundary_matches(rec, event, diagnostic))
        for field, value in [('s', 'capture'), ('t', 4), ('k', 'settings')]:
            bad = copy.deepcopy(event); bad[field] = value
            self.assertFalse(local.r20.direction_boundary_matches(rec, bad, diagnostic))
        for field, value in [('key', 'guessed_assist'), ('from', True), ('to', 'unfrozen-model'), ('to', 'elastic')]:
            bad = copy.deepcopy(event); bad['d'][field] = value
            self.assertFalse(local.r20.direction_boundary_matches(rec, bad, diagnostic))
        for target in local.ORIGINAL_MODELS:
            old = copy.deepcopy(event); old['d'].update({'from': 'classic', 'to': target})
            self.assertEqual(local.r20.direction_boundary_matches(rec, old, diagnostic),
                             local._DIRECTION_BOUNDARY(rec, old, diagnostic))
        rec.header['metadata']['map'] = 'breakwater'
        self.assertFalse(local.r20.direction_boundary_matches(rec, event, diagnostic))

    def test_component_readiness_requires_real_paths_callbacks_and_exact_pins(self):
        _, _, freeze, _ = fixture()
        paths = [pkg.resource_path(freeze['runtime'][k]) for k in ('main_scene', 'main_script', 'hud_script')]
        paths += [pkg.resource_path(v['level_script']) for v in freeze['map_versions'].values()]
        manifest = dict.fromkeys(paths, 'a'*64)
        self.refused(pkg.integration_ready, freeze, manifest)
        callbacks = {name: pkg.ComponentGate((name+'.py',), lambda *a: True, lambda *a: True)
                     for name in pkg.COMPONENTS}
        freeze['delivery_components'] = {name: {name+'.py': 'b'*64} for name in callbacks}
        manifest.update({name+'.py': 'b'*64 for name in callbacks})
        with patch.object(pkg, 'COMPONENTS', callbacks):
            self.assertEqual(pkg.integration_ready(freeze, manifest), freeze['delivery_components'])
            for name in callbacks:
                bad = copy.deepcopy(manifest); bad[name+'.py'] = 'c'*64
                self.refused(pkg.integration_ready, freeze, bad)
            bad = dict(manifest); del bad[paths[0]]
            self.refused(pkg.integration_ready, freeze, bad)
            callbacks['tether'].source = None
            self.refused(pkg.integration_ready, freeze, manifest)
        self.refused(pkg.integration_ready, freeze, manifest)

    def test_no_op_adapter_and_wrong_stage_or_source_refuse(self):
        _, _, freeze, _ = fixture()
        with tempfile.TemporaryDirectory(prefix='r21-stage-') as directory:
            root = Path(directory)
            (root/'proof.json').write_text('{"synthetic": true}')
            binding = pkg.evidence_binding('saltglass', 'source', freeze)
            good = {'binding': binding, 'checks': [{'name': 'synthetic transport check', 'ok': True}],
                    'proof': {'proof.json': pkg.r16.digest(root/'proof.json')}}
            self.assertIs(pkg.validate_evidence(good, 'synthetic', root, binding), good)
            for value in (None, True, {}, {'ok': True}, dict(good, checks=[]), dict(good, proof={}),
                          dict(good, checks=[{'name': 'synthetic', 'ok': False}])):
                self.refused(pkg.validate_evidence, value, 'synthetic', root, binding)
            for key in binding:
                bad = copy.deepcopy(good); bad['binding'][key] = 'wrong'
                self.refused(pkg.validate_evidence, bad, 'synthetic', root, binding)
            bad = copy.deepcopy(good); bad['proof'] = {'../escape': 'a'*64}
            self.refused(pkg.validate_evidence, bad, 'synthetic', root, binding)
            (root/'proof.json').write_text('mutated')
            self.refused(pkg.validate_evidence, good, 'synthetic', root, binding)
            with patch.object(pkg, 'COMPONENTS', {'saltglass': pkg.ComponentGate(('synthetic.py',), lambda *a: True)}):
                self.refused(pkg.component_source, 'saltglass', root, root/'result', {}, freeze)

    def test_import_guard_is_wired_before_and_after_engine_import(self):
        with tempfile.TemporaryDirectory(prefix='r21-import-') as directory:
            work = Path(directory); source = work/'source'; source.mkdir(); evidence = work/'proof'; evidence.mkdir()
            (source/'a.gd').write_bytes(b'extends Node\n')
            facts = {'commit': 'a'*40, 'manifest': {'a.gd': pkg.r16.digest(source/'a.gd')}}
            def synthetic_import(*args):
                (source/'a.gd.uid').write_bytes(b'uid://abc\n')
                (source/'.godot').mkdir()
                (source/'.godot/cache.bin').write_bytes(b'synthetic cache')
            with patch.object(pkg.r16, 'checked', side_effect=synthetic_import), patch.object(pkg.r16, 'engine_env', return_value={}):
                _, generated = pkg.import_snapshot(source, facts, evidence, work)
            receipt = pkg.read_json(evidence/'IMPORT.json')
            self.assertEqual(receipt['source_commit'], facts['commit'])
            self.assertEqual(receipt['committed'], facts['manifest'])
            self.assertEqual(receipt['generated_sidecars'], generated)
            self.assertEqual(receipt['cache']['cache.bin']['bytes'], 15)
            self.assertTrue((source/'.godot/cache.bin').exists())
            pkg.snapshot_guard(source, facts, generated)
            (source/'injected.gd').write_bytes(b'extends Node')
            self.refused(pkg.snapshot_guard, source, facts, generated)
            (source/'injected.gd').unlink()
            (source/'a.gd').write_bytes(b'mutated committed source')
            with patch.object(pkg.r16, 'checked') as engine:
                self.refused(pkg.import_snapshot, source, facts, evidence, work)
                engine.assert_not_called()

    def test_import_cache_cannot_hide_new_source_code(self):
        with tempfile.TemporaryDirectory(prefix='r21-cache-injection-') as directory:
            root = Path(directory); source = root/'source'; source.mkdir(); evidence = root/'proof'; evidence.mkdir()
            (source/'a.gd').write_bytes(b'extends Node')
            facts = {'commit': 'a'*40, 'manifest': {'a.gd': pkg.r16.digest(source/'a.gd')}}
            def injected(*args):
                (source/'.godot').mkdir(); (source/'.godot/injected.gd').write_bytes(b'extends Node')
            with patch.object(pkg.r16, 'checked', side_effect=injected), patch.object(pkg.r16, 'engine_env', return_value={}):
                self.refused(pkg.import_snapshot, source, facts, evidence, root)

    def test_source_archive_rejects_wrong_hash_extra_file_and_links(self):
        import tarfile
        with tempfile.TemporaryDirectory(prefix='r21-snapshot-') as directory:
            root = Path(directory)
            def archive(rows):
                stream = io.BytesIO()
                with tarfile.open(fileobj=stream, mode='w') as tar:
                    for name, data in rows:
                        member = tarfile.TarInfo(name); member.size = len(data)
                        tar.addfile(member, io.BytesIO(data))
                return stream.getvalue()
            data = b'synthetic source bytes'
            facts = {'commit': 'a'*40, 'manifest': {'a.gd': hashlib.sha256(data).hexdigest()}}
            with patch.object(pkg.r16, 'source_archive', return_value=archive([('a.gd',data)])), patch.object(pkg,'HELPERS', ()):
                pkg.frozen_source(facts, root/'good')
            for label, rows in [('hash', [('a.gd',b'wrong')]), ('extra', [('a.gd',data),('extra.gd',data)]),
                                ('traversal', [('../escape',data)])]:
                with patch.object(pkg.r16, 'source_archive', return_value=archive(rows)), patch.object(pkg,'HELPERS', ()):
                    self.refused(pkg.frozen_source, facts, root/label)
            self.assertFalse((root/'escape').exists())

    def test_owned_paths_refuse_source_output_symlinks_and_overwrite(self):
        with tempfile.TemporaryDirectory(prefix='r21-owned-') as directory:
            root = Path(directory); (root/'link').symlink_to(root, target_is_directory=True)
            self.refused(pkg.owned_path, root/'link/proof', root)
            self.refused(pkg.owned_path, root, root)
            self.refused(pkg.owned_path, root/'../elsewhere', root)
            (root/'existing').mkdir()
            self.refused(pkg.owned_path, root/'existing', root, fresh=True)
            self.assertEqual(pkg.owned_path(root/'new', root, fresh=True), root/'new')

    def test_resource_guard_checks_total_memory_space_HOME_and_combined_bytes(self):
        from types import SimpleNamespace
        real = pkg.shutil.disk_usage
        with tempfile.TemporaryDirectory(prefix='r21-resources-') as directory:
            with patch.object(pkg, 'SCRATCH', Path(directory)), patch.object(pkg, 'ASSEMBLY', Path(directory)/'assembly'):
                for home, tmp, size in [(pkg.FLOOR-1, 10**10, 0), (pkg.FLOOR+1, 2_800_000_000, 0),
                                        (pkg.FLOOR+1, 10**10, pkg.ASSEMBLY_RESERVE+pkg.EXPORT_LIMIT+1)]:
                    def usage(path):
                        return SimpleNamespace(free=home if Path(path) == Path.home() else tmp)
                    with patch.object(pkg.shutil, 'disk_usage', side_effect=usage), patch.object(pkg, 'tree_bytes', return_value=size):
                        self.refused(pkg.resource_guard, assembly=True, reserve=True)
                with patch.object(pkg.shutil, 'disk_usage', return_value=SimpleNamespace(free=10**11)), \
                     patch.object(pkg.Path, 'read_text', return_value='MemAvailable: 1024 kB\n'):
                    self.refused(pkg.resource_guard, assembly=True, reserve=True)

    def test_later_wine_reserves_remaining_budget_without_counting_existing_proof_twice(self):
        from types import SimpleNamespace
        owned = 600 * 2**20
        remaining = pkg.ASSEMBLY_RESERVE + pkg.EXPORT_LIMIT - owned
        sizes = {pkg.SCRATCH: owned, pkg.ASSEMBLY: owned // 2,
                 pkg.SCRATCH / 'export': owned // 2}
        for label, home, tmp, memory, accepted in [
            ('existing proof fits total budget', pkg.FLOOR, remaining, remaining + 1024, True),
            ('one byte short on disk', pkg.FLOOR, remaining - 1, remaining + 1024, False),
            ('insufficient memory', pkg.FLOOR, remaining, remaining - 1024, False),
            ('HOME floor remains independent', pkg.FLOOR - 1, remaining, remaining + 1024, False),
        ]:
            def usage(path):
                return SimpleNamespace(free=home if Path(path) == Path.home() else tmp)
            with self.subTest(label=label), patch.object(pkg.shutil,'disk_usage',side_effect=usage), \
                 patch.object(pkg,'tree_bytes',side_effect=lambda root:sizes[Path(root)]), \
                 patch.object(pkg.Path,'read_text',return_value='MemAvailable: '+str(memory//1024)+' kB\n'):
                if accepted:
                    result = pkg.resource_guard(assembly=True,reserve=True)
                    self.assertEqual(result['remaining_reserve_bytes'],remaining)
                    self.assertEqual(result['owned_bytes'],owned)
                else:
                    self.refused(pkg.resource_guard,assembly=True,reserve=True)

    def test_four_original_pack_negatives_require_nonzero_even_with_error_text(self):
        from types import SimpleNamespace
        def run(code):
            with tempfile.TemporaryDirectory(prefix='r21-pack-negative-') as directory:
                root = Path(directory); folder = root/'release'; folder.mkdir(); work = root/'work'; work.mkdir()
                (folder/(pkg.r20.NAME+'.x86_64')).write_bytes(b'synthetic ELF fixture')
                (folder/(pkg.r20.NAME+'.pck')).write_bytes(b'synthetic whiteout-sky.png pack fixture')
                calls = []
                def start(case, out, args):
                    out.mkdir(parents=True); calls.append(list(args))
                    return code, 'ERROR: synthetic broken package'
                with patch.object(pkg.r18, 'normal_start', side_effect=start):
                    result = pkg.r20.pack_negatives(folder, work, root/'proof')
                self.assertEqual(len(result), 4)
                self.assertEqual(sum('--look=old' in args for args in calls), 1)
                self.assertTrue(all(row['refused'] for row in result))
        run(3)
        for code in (0, 'timeout', None):
            self.refused(run, code)

    def test_routes_refuse_empty_unearned_and_missing_actual_bytes(self):
        _, _, freeze, _ = fixture()
        for rows in (None, [], [{}], [{'route': {'name': 'synthetic', 'map': 'saltglass', 'preset': 'server128'}}]):
            self.refused(pkg.validate_routes, rows, freeze)

    def test_probe_keeps_base_identity_and_friend_controls_without_blanket_start(self):
        import re
        current = (PROJECT/'tools/r21-pack-probe.gd').read_text()
        old = pkg.committed_bytes(pkg.BASE, 'tools/r20-pack-probe.gd').decode()
        base = pkg.committed_bytes(pkg.BASE, 'tools/r16-pack-probe.gd').decode()
        def method(text, name):
            return re.search(r'^func '+name+r'\(.*?(?=^func |\Z)', text, re.M|re.S)[0]
        self.assertNotIn('func _start()', current)
        original_identity = method(base, '_check_identity').rstrip()
        self.assertTrue(method(current, '_check_identity').startswith(original_identity))
        original_friend = method(old, '_friend_release').replace(
            'checked.build == "spillway-2026.11.10-r20"','checked.build == str(spec.r21.runtime.build)')
        self.assertEqual(method(current, '_friend_release'), original_friend)
        for method_name in ('observe_actual', 'early_step', 'late_step', '_judge_run', '_through_controls',
                            '_directional_controls', '_tether_controls', '_ghost_checks'):
            self.assertNotIn('func '+method_name+'(', current)
        self.assertIn('await super._controls()', current)
        self.assertIn('await super._end(reason)', current)
        self.assertIn('R21 observer checks failed', current)

    def test_synthetic_assembly_checks_exact_archives_after_removing_loose_source(self):
        """mock engine stages; real ZIP assembly plumbing, no game or acceptance fixture."""
        from types import SimpleNamespace
        import tarfile
        for accepted in (True, False):
            with tempfile.TemporaryDirectory(prefix='r21-pipeline-') as directory:
                root = Path(directory); output = root/'export/spillway-r21'; assembly = root/'assembly'
                _, identity, freeze, _ = fixture()
                facts = {'commit': 'a'*40, 'tree': 'b'*40, 'files': ['synthetic.txt'], 'stamp': '1700000000',
                    'project_name': 'Spillway', 'engine': pkg.r16.ENGINE_VERSION, 'templates': {'archive_url': 'synthetic'},
                    'manifest': dict.fromkeys(pkg.HELPERS, 'a'*64), 'preservation': {'synthetic': True}}
                stream = io.BytesIO()
                with tarfile.open(fileobj=stream, mode='w') as tar:
                    item = tarfile.TarInfo('synthetic.txt'); item.size = 1; tar.addfile(item, io.BytesIO(b'x'))
                def snapshot(facts, source):
                    source.mkdir(); (source/'synthetic.txt').write_bytes(b'x'); return stream.getvalue()
                def export(*args):
                    Path(args[0][-1]).write_bytes(b'synthetic PCK; no engine ran')
                def folders(work, pack, facts, identity, build):
                    result = {}
                    for platform in ('linux-x86_64','windows-x86_64'):
                        folder = work/'dist'/('SpillwayR21-'+platform); folder.mkdir(parents=True)
                        (folder/'synthetic.txt').write_bytes(b'synthetic fixture')
                        result[platform] = folder
                    return result
                def check(dist, args, evidence, work, routes):
                    self.assertFalse((dist.parent/'source').exists())
                    self.assertEqual(len(list(dist.glob('*.zip'))), 2)
                    self.assertEqual(pkg.read_json(dist/'BUILD.json')['source_commit'], facts['commit'])
                    self.assertTrue(all(path.name.startswith(freeze['runtime']['build']) for path in dist.glob('*.zip')))
                    self.assertEqual(len((dist/'SHA256SUMS').read_text().splitlines()), 2)
                    if not accepted:
                        raise pkg.Rejected('synthetic audit failure')
                    return {'ok': True, 'synthetic': True}
                args = SimpleNamespace(output=output)
                with patch.object(pkg.r20, 'BUILD', freeze['runtime']['build']), \
                     patch.object(pkg.r20, 'VERSION', freeze['runtime']['version']), \
                     patch.object(pkg, 'SCRATCH', root), patch.object(pkg, 'EXPORT_OUTPUT', output), \
                     patch.object(pkg, 'ASSEMBLY', assembly), patch.object(pkg, 'resource_guard', return_value={}), \
                     patch.object(pkg, 'frozen_source', side_effect=snapshot), \
                     patch.object(pkg, 'import_snapshot', return_value=({}, {})), \
                     patch.object(pkg, 'source_identity', return_value=identity), patch.object(pkg, 'snapshot_guard') as guard, \
                     patch.object(pkg.r18, 'asset_manifest', return_value={'synthetic': True}), \
                     patch.object(pkg.r16, 'checked', side_effect=export), \
                     patch.object(pkg, 'route_freeze', return_value=([{'synthetic': True}], {'synthetic': True})), \
                     patch.object(pkg.r16, 'assemble', side_effect=folders), patch.object(pkg, 'check', side_effect=check):
                    if accepted:
                        result = pkg.package(args, freeze, facts)
                        self.assertTrue(result['windows_wine_pending'])
                        self.assertTrue(result['publication_pending'])
                        self.assertEqual(len(list(output.glob('*.zip'))), 2)
                        self.assertTrue(pkg.read_json(output/'VERIFICATION.json')['synthetic'])
                        self.assertTrue(Path(result['raw_assembly_retained']).is_dir())
                    else:
                        self.refused(pkg.package, args, freeze, facts)
                        self.assertEqual(list(output.glob('*.zip')), [])
                        self.assertFalse(pkg.read_json(output/'evidence/FAILURE.json')['ok'])
                    self.assertEqual(guard.call_count, 3)

    def test_all_runtime_CLI_paths_refuse_before_any_engine_when_unbound(self):
        _, _, freeze, _ = fixture()
        freeze['source_commit'] = pkg.r16.git('rev-parse', 'HEAD').strip()
        with tempfile.TemporaryDirectory(prefix='r21-cli-unbound-') as directory:
            root = Path(directory); path = root/'freeze.json'; path.write_text(json.dumps(freeze))
            manifest = {pkg.resource_path(freeze['runtime'][k]): 'a'*64 for k in ('main_scene','main_script','hud_script')}
            manifest.update({pkg.resource_path(v['level_script']): 'a'*64 for v in freeze['map_versions'].values()})
            for command in ('identity', 'package', 'check', 'wine'):
                args = [command, '--freeze', str(path), '--execute-frozen-runtime']
                if command != 'package':
                    args += ['--evidence', str(root/'proof')]
                if command in ('check','wine'):
                    args += [str(root/'candidate')]
                if command == 'wine':
                    args += ['--wine', str(root/'not-executed')]
                with patch.object(pkg, 'preflight', side_effect=lambda freeze: pkg.integration_ready(freeze, manifest)), \
                     patch.object(pkg.r16, 'checked') as engine, patch.object(pkg, 'package') as assembly, \
                     contextlib.redirect_stderr(io.StringIO()):
                    self.assertEqual(pkg.main(args), 1)
                    engine.assert_not_called(); assembly.assert_not_called()
            self.assertEqual([p.name for p in root.iterdir()], ['freeze.json'])


if __name__ == '__main__':
    unittest.main()
