#!/usr/bin/env python3
"""pure adapter acceptance/refusal tests. Fixture bytes never establish engine behavior."""
import copy
import gzip
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('r21_delivery_test_package', PROJECT / 'tools/package-r21.py')
d = importlib.util.module_from_spec(spec)
spec.loader.exec_module(d)
c = d.delivery
SCRATCH = Path('/tmp/r21-delivery-bindings')
SCRATCH.mkdir(exist_ok=True)


class Bindings(unittest.TestCase):
    def refused(self, function, *args, **kwargs):
        with self.assertRaises((d.Rejected, AssertionError, KeyError, ValueError, OSError)):
            function(*args, **kwargs)

    def test_installed_interfaces_and_new_helpers_are_exactly_pinned(self):
        self.assertEqual(set(d.COMPONENTS), {'saltglass', 'tether', 'parity'})
        for name, gate in d.COMPONENTS.items():
            self.assertEqual(gate.paths, c.PATHS[name])
            self.assertTrue(callable(gate.source) and callable(gate.packed))
            self.assertTrue(set(gate.paths) <= set(d.HELPERS))
            self.assertTrue(set(c.COMMON) <= set(gate.paths))
        self.assertIn('tools/r21-delivery-components.py', d.OWNED)
        self.assertIn('tests/test_r21_delivery_components.py', d.OWNED)
        self.assertEqual(c.MODELS, ('classic', 'pendulum', 'elastic', 'elastic-soft', 'elastic-firm', 'elastic-arc'))

    def test_source_guard_checks_every_committed_byte_unknown_files_and_sidecars(self):
        with tempfile.TemporaryDirectory(dir=SCRATCH) as directory:
            root = Path(directory)
            (root/'scripts').mkdir()
            (root/'scripts/player.gd').write_text('extends Node\n')
            manifest = {'scripts/player.gd': d.r16.digest(root/'scripts/player.gd')}
            freeze = {'source_commit': 'a'*40}
            # the inherited real sidecar parser runs; only the source inventory/binding is synthetic.
            with patch.object(d.r20, 'committed_manifest', return_value=manifest), \
                 patch.object(d, 'component_bindings'), patch.object(d, 'HELPERS', tuple(manifest)):
                state = c.source_guard(d, root, freeze)
                self.assertEqual(state['committed'], manifest)
                (root/'scripts/player.gd.uid').write_text('uid://abc123\n')
                self.assertIn('scripts/player.gd.uid', c.source_guard(d, root, freeze)['generated'])
                (root/'scripts/foreign.gd').write_text('extends Node\n')
                self.refused(c.source_guard, d, root, freeze)
                (root/'scripts/foreign.gd').unlink()
                (root/'scripts/player.gd.uid').write_text('uid://bad syntax\n')
                self.refused(c.source_guard, d, root, freeze)
                (root/'scripts/player.gd.uid').unlink()
                (root/'scripts/player.gd').write_text('extends Node3D\n')
                self.refused(c.source_guard, d, root, freeze)
                (root/'scripts/player.gd').unlink()
                self.refused(c.source_guard, d, root, freeze)
                (root/'scripts/player.gd').symlink_to(PROJECT/'scripts/r15_source_player.gd')
                self.refused(c.source_guard, d, root, freeze)

    def test_source_cache_uses_existing_guard_and_refuses_code_injection(self):
        with tempfile.TemporaryDirectory(dir=SCRATCH) as directory:
            root=Path(directory)/'source';root.mkdir()
            out=Path(directory)/'proof';out.mkdir()
            (root/'scripts').mkdir();(root/'.godot').mkdir()
            (root/'scripts/player.gd').write_text('extends Node\n')
            (root/'.godot/cache.bin').write_bytes(b'cache data')
            manifest={'scripts/player.gd':d.r16.digest(root/'scripts/player.gd')}
            freeze={'source_commit':'a'*40}
            with patch.object(d.r20,'committed_manifest',return_value=manifest), \
                 patch.object(d,'component_bindings'),patch.object(d,'HELPERS',tuple(manifest)):
                before=c.source_guard(d,root,freeze)
                self.assertIn('cache.bin',before['cache'])
                (root/'.godot/cache.bin').write_bytes(b'changed legitimate cache data')
                c.source_postflight(d,root,out,freeze,before)
                self.assertTrue((out/'SOURCE-after.json').is_file())
                (root/'.godot/injected.gd').write_text('extends Node\n')
                self.refused(c.source_guard,d,root,freeze)

    def test_evidence_envelope_refuses_empty_failed_changed_and_cross_stage(self):
        freeze = {'source_commit': 'a'*40, 'identity_sha256': 'b'*64}
        with tempfile.TemporaryDirectory(dir=SCRATCH) as directory:
            root = Path(directory)
            c.write(root/'raw.json', {'fixture': True})
            checks = [{'name': 'fixture transport only', 'ok': True}]
            result = c.envelope(d, 'tether', 'source', root, freeze, checks)
            d.validate_evidence(result, 'fixture', root, d.evidence_binding('tether', 'source', freeze))
            self.refused(c.envelope, d, 'tether', 'source', root, freeze, [])
            self.refused(c.envelope, d, 'tether', 'source', root, freeze, [{'name': 'failed', 'ok': False}])
            self.refused(d.validate_evidence, result, 'fixture', root, d.evidence_binding('tether', 'packed', freeze))
            c.write(root/'raw.json', {'fixture': 'changed'})
            self.refused(d.validate_evidence, result, 'fixture', root, result['binding'])

    def test_component_checks_are_nonempty_typed_and_all_mandatory(self):
        value = {'ok': True, 'checks': [{'check': 'fixture only', 'ok': True}]}
        self.assertEqual(c.passed(d, value, 'fixture'), [{'name': 'fixture only', 'ok': True}])
        for bad in ({'ok': True}, dict(value, checks=[]), dict(value, ok=False),
                    dict(value, checks=[{'check': '', 'ok': True}]),
                    dict(value, checks=[{'check': 'failed', 'ok': False}]),
                    dict(value, checks=[{'check': 'integer', 'ok': 1}])):
            self.refused(c.passed, d, bad, 'fixture')
        self.refused(c.passed, d, value, 'fixture', minimum=72)

    def test_salt_normal_spawn_acceptance_rejects_stale_host_fin_count_and_law(self):
        identity = {'maps': {'saltglass': {'geometry': '1'*64}}}
        freeze = {'runtime': {'main_script': 'res://scripts/r21_main.gd', 'main_scene': 'res://scenes/r21.tscn'}}
        summary = {'pass': True, 'finished': True, 'finish_kind': 'clean', 'respawns': 0,
            'configured_main': freeze['runtime']['main_script'], 'configured_scene': freeze['runtime']['main_scene'],
            'runner': 'res://scripts/r15_source_player.gd', 'physics_hz': 128, 'engine_hz': 128,
            'elapsed': 55, 'actual_v_mismatches': 0, 'rate_mismatch_ticks': 0,
            'geometry_hash': '1'*64, 'contact_pieces': dict.fromkeys(map(str, range(16)), 1), 'grounded_steep_ticks': 0}
        c.salt_summary(d, summary, identity, freeze)
        for key, value in [('pass', False), ('finished', False), ('finish_kind', 'practice'), ('respawns', 1),
                           ('configured_main', 'res://scripts/r20_main.gd'), ('configured_scene', 'component fixture'),
                           ('runner', 'res://scripts/r14_source_motion.gd'), ('physics_hz', 64), ('engine_hz', 64),
                           ('elapsed', 39), ('elapsed', 71), ('actual_v_mismatches', 1), ('rate_mismatch_ticks', 1),
                           ('geometry_hash', '2'*64), ('contact_pieces', {'one': 16}), ('grounded_steep_ticks', 1)]:
            bad = copy.deepcopy(summary); bad[key] = value
            self.refused(c.salt_summary, d, bad, identity, freeze)

    def test_tether_summary_requires_actual_host_model_assist_and_geometry(self):
        identity = {'maps': {'tether-yard': {'geometry': '1'*64}}}
        summary = {'scope': 'actual production host/UI', 'pass': True, 'finished': True,
            'finish_kind': 'clean', 'respawns': 0, 'actual_v_mismatches': 0, 'rate_mismatch_ticks': 0,
            'runner': 'res://scripts/r21_tether_player.gd', 'physics_hz': 128,
            'anchors': dict.fromkeys(['Transfer 1', 'Transfer 2', 'Transfer 3'], 10),
            'geometry_hash': '1'*64, 'options': {'production': '1', 'model': 'elastic-arc'}}
        c.tether_summary(d, summary, 'elastic-arc', True, identity)
        self.refused(c.tether_summary, d, summary, 'elastic-soft', True, identity)
        self.refused(c.tether_summary, d, summary, 'elastic-arc', False, identity)
        for key, value in [('scope', 'component adapter; not production host acceptance'), ('pass', False),
                           ('finished', False), ('finish_kind', 'practice'), ('respawns', 1), ('actual_v_mismatches', 1),
                           ('rate_mismatch_ticks', 1), ('runner', 'old'), ('physics_hz', 64),
                           ('anchors', {'Transfer 1': 30}), ('geometry_hash', '2'*64)]:
            bad = copy.deepcopy(summary); bad[key] = value
            self.refused(c.tether_summary, d, bad, 'elastic-arc', True, identity)
        for key in ('human', 'old-e', 'frozen-r20', 'original-geometry', 'isolate-dispatch', 'auto'):
            bad = copy.deepcopy(summary); bad['options'][key] = '1'
            self.refused(c.tether_summary, d, bad, 'elastic-arc', True, identity)
        off = copy.deepcopy(summary); off['options']['assist-off'] = '1'
        c.tether_summary(d, off, 'elastic-arc', False, identity)

    def test_raw_reader_tape_retains_every_raw_field_and_action_exclusion(self):
        rec = SimpleNamespace(columns={'tick': list(range(36)), 'dt': [1/128]*36, 'physics_hz': [128]*36},
            inputs={'tick': [33, 33, 34, 35], 'kind': [1, 4, 3, 2], 'flags': [1, 1, 0, 0],
                    'code': [87, 0, 0, 1], 'aux': [87, 0, 0, 0], 'x': [0, 0, 1.25, 0],
                    'y': [0, 0, -0.5, 0], 'x2': [0, 0, 3, 0], 'y2': [0, 0, 4, 0]})
        plan = c.reader_tape(d, rec)
        self.assertEqual(plan['duration_ticks'], 3)
        self.assertEqual([e['tick'] for e in plan['events']], [0, 1, 2])
        self.assertEqual(plan['events'][1]['raw'], {k: v[2] for k, v in rec.inputs.items()})
        for key, value in [('tick', [32, 33, 34, 35]), ('kind', [1, 4, 7, 2])]:
            bad = copy.deepcopy(rec); bad.inputs[key] = value
            self.refused(c.reader_tape, d, bad)
        bad = copy.deepcopy(rec); bad.columns['tick'][10] = 9
        self.refused(c.reader_tape, d, bad)
        bad = copy.deepcopy(rec); bad.columns['dt'][-1] = 1/64
        self.refused(c.reader_tape, d, bad)

    def test_exact_source_replay_rejects_every_field_missing_rows_and_binary_input_drift(self):
        row = {k: 0 for k in (*c.TRACE_FIELDS, 'reference_p', 'style', 'motion', 'rope_length_u')}
        rec = SimpleNamespace(columns={'tick': [0]}, inputs={'kind': [1]})
        with tempfile.TemporaryDirectory(dir=SCRATCH) as directory:
            root = Path(directory); a = root/'a'; b = root/'b'; a.mkdir(); b.mkdir()
            def trace(folder, items):
                with gzip.open(folder/'trace.jsonl.gz', 'wt') as out:
                    out.writelines(json.dumps(v)+'\n' for v in items)
            trace(a, [row]); trace(b, [row])
            self.assertEqual(c.exact_replay(d, a, b, rec, copy.deepcopy(rec)), 1)
            for key in row:
                bad = dict(row); bad[key] = 1
                trace(b, [bad]); self.refused(c.exact_replay, d, a, b, rec, rec)
            trace(b, []); self.refused(c.exact_replay, d, a, b, rec, rec)
            trace(b, [row]); other = copy.deepcopy(rec); other.inputs['kind'][0] = 2
            self.refused(c.exact_replay, d, a, b, rec, other)
            other = copy.deepcopy(rec); other.columns['tick'][0] = 1
            self.refused(c.exact_replay, d, a, b, rec, other)

    def test_only_exact_settings_key_boolean_type_and_real_loadout_boundary_are_admitted(self):
        settings = {k: (False if types == (bool,) else 'elastic' if types == (str,) else 1.0)
                    for k, types in c.SETTING_TYPES.items()}
        c.settings_contract(d, settings)
        for key, value in [('tether_anchor_assist', 1), ('tether_model', 'unknown'), ('source_fov', True),
                           ('volume', float('nan')), ('guessed_assist', True)]:
            bad = dict(settings); bad[key] = value
            self.refused(c.settings_contract, d, bad)
        rec = SimpleNamespace(header={'metadata': {'map': 'tether-yard'}}, columns={'tick': [0,1]},
              events=[{'s': 'event', 't': 1, 'k': 'loadout', 'd': {'key': 'tether_anchor_assist', 'from': True, 'to': False}}])
        c.recording_preferences(d, rec)
        for key, value in [('key', 'guessed_assist'), ('from', 1), ('to', 0), ('to', True)]:
            bad = copy.deepcopy(rec); bad.events[0]['d'][key] = value
            self.refused(c.recording_preferences, d, bad)
        for key, value in [('s', 'capture'), ('t', True), ('t', 2)]:
            bad = copy.deepcopy(rec); bad.events[0][key] = value
            self.refused(c.recording_preferences, d, bad)
        bad = copy.deepcopy(rec); bad.header['metadata']['map'] = 'breakwater'
        self.refused(c.recording_preferences, d, bad)

    def test_settings_event_cannot_disguise_assist_loadout_or_unknown_key(self):
        rec = SimpleNamespace(events=[{'k':'settings','d':{'key':'source_fov','value':90.0}}])
        c.recording_preferences(d,rec)
        for key, value in [('unknown',True),('tether_anchor_assist',True),('source_fov',False)]:
            bad = copy.deepcopy(rec);bad.events[0]['d']={'key':key,'value':value}
            self.refused(c.recording_preferences,d,bad)

    def test_recording_requires_actual_exercised_model_assist_build_and_identity(self):
        freeze={'runtime':{'build':'fixture-r21'}}
        metadata={'map':'tether-yard','build':'fixture-r21',
            'physics':{'mechanics':[{'model':'elastic-arc','automatic_reel':False,'acquisition':{'law':'r21-anchor-assist-1'}}]}}
        rec=SimpleNamespace(header={'metadata':metadata,'identity':{'fixture':'motion'}},events=[])
        summary={'identity':{'fixture':'motion'}}
        c.tether_record(d,rec,summary,'elastic-arc',True,freeze)
        self.refused(c.tether_record,d,rec,summary,'elastic-arc',False,freeze)
        self.refused(c.tether_record,d,rec,summary,'elastic-soft',True,freeze)
        for key, value in [('map','breakwater'),('build','fixture-r20')]:
            bad=copy.deepcopy(rec);bad.header['metadata'][key]=value
            self.refused(c.tether_record,d,bad,summary,'elastic-arc',True,freeze)
        bad=copy.deepcopy(rec);bad.header['identity']={}
        self.refused(c.tether_record,d,bad,summary,'elastic-arc',True,freeze)
        bad=copy.deepcopy(rec);bad.header['metadata']['physics']['mechanics'][-1]['automatic_reel']=True
        self.refused(c.tether_record,d,bad,summary,'elastic-arc',True,freeze)

    def test_missing_final_review_refuses_before_an_engine_command(self):
        args=SimpleNamespace(parity_identity=None)
        with patch.object(d.r16,'checked') as engine:
            self.refused(c.review_inputs,d,args,{'source_commit':'a'*40})
            engine.assert_not_called()

    def test_parity_requires_explicit_parent_review_and_shared_identity(self):
        freeze = {'source_commit': 'a'*40}; identity = {'fixture': 'identity'}
        self.refused(c.parity_arguments, d, None, freeze, identity)
        with tempfile.TemporaryDirectory(dir=SCRATCH) as directory:
            root=Path(directory)
            for name, value in [('freeze', freeze), ('identity', identity), ('contract', {'fixture': 'review'})]:
                c.write(root/(name+'.json'), value)
            args=SimpleNamespace(freeze=root/'freeze.json', parity_identity=root/'identity.json',
                                 parity_contract=root/'contract.json', parity_contract_sha256=d.r16.digest(root/'contract.json'))
            argv=c.parity_arguments(d,args,freeze,identity)
            self.assertIn('/tmp/r21-candidate-parity', argv)
            self.assertIn('/tmp/r21-r20-baseline', argv)
            bad=copy.copy(args); bad.parity_contract_sha256='f'*64
            self.refused(c.parity_arguments,d,bad,freeze,identity)
            self.refused(c.parity_arguments,d,args,freeze,{'fixture':'other'})
            self.refused(c.parity_arguments,d,args,{'source_commit':'b'*40},identity)

    def test_parity_never_accepts_ok_receipt_without_unchanged_raw_auditor(self):
        with tempfile.TemporaryDirectory(dir=SCRATCH) as directory:
            root=Path(directory); (root/'audit').mkdir()
            c.write(root/'REPORT.json', {'inputs': {}})
            c.write(root/'audit/AUDIT.json', {'ok': True})
            auditor=SimpleNamespace(raw_guard=lambda *a: (_ for _ in ()).throw(ValueError('missing actual 144 streams')))
            with patch.object(c,'PARITY_ROOT',root), patch.object(c,'module',return_value=auditor) as loaded:
                self.refused(c.parity_receipt,d,root,{'source_commit':'a'*40},{})
                loaded.assert_called_once()
            self.refused(c.parity_receipt,d,root,{'source_commit':'a'*40},{}, {'different': True})

    def test_packed_tether_requires_all_ten_exact_replays_bound_bytes_and_binary_columns(self):
        with tempfile.TemporaryDirectory(dir=SCRATCH) as directory:
            root = Path(directory)
            c.write(root/'tape.json', {'fixture': 'input'})
            c.write(root/'trace.json', [{'tick': 0, 'fixture': 'motion'}])
            (root/'source.r16run').write_bytes(b'pure transport fixture, not an engine recording')
            references, observations = {}, {}
            for model in c.MODELS:
                for assist in ([True] if model in c.MODELS[:2] else [True, False]):
                    label = model if assist else model+'-assist-off'
                    references[label] = {'model': model, 'assist': assist, 'identity': {'fixture': label},
                        'tape': str(root/'tape.json'), 'tape_sha256': d.r16.digest(root/'tape.json'),
                        'trace': str(root/'trace.json'), 'trace_sha256': d.r16.digest(root/'trace.json'),
                        'recording': str(root/'source.r16run'), 'recording_sha256': d.r16.digest(root/'source.r16run')}
                    observations[label] = {'model': model, 'assist': assist, 'identity': {'fixture': label},
                        'tape_sha256': d.r16.digest(root/'tape.json'), 'trace': d.read_json(root/'trace.json'),
                        'recording': str(root/(label+'.r16run'))}
            # strict decoding is independently covered by the existing format/reader suites.
            # this fake decoder challenges adapter dispatch and comparisons, not file validity.
            def decoded(path):
                label=path.name.removesuffix('.r16run')
                return SimpleNamespace(ok=True, columns={'tick':[0], 'actual_v_x':[1.0]},
                    header={'identity':{'fixture':label}})
            decoder=SimpleNamespace(read=decoded)
            for label, ref in references.items():
                path=root/(label+'-source.r16run');path.write_bytes(b'fixture '+label.encode())
                ref.update(recording=str(path),recording_sha256=d.r16.digest(path))
            def read(path):
                if path.name.endswith('-source.r16run'):
                    path=path.with_name(path.name.replace('-source.r16run','.r16run'))
                return decoded(path)
            decoder.read=read
            with patch.object(c,'module',return_value=decoder):
                c.packed_tether_routes(d, {'routes':observations}, references)
                self.refused(c.packed_tether_routes,d,{'routes':dict(list(observations.items())[:-1])},references)
                for key, value in [('model','elastic-soft'), ('assist',False), ('identity',{}),
                                   ('trace',[{'tick':1}]), ('tape_sha256','f'*64)]:
                    bad=copy.deepcopy(observations);bad['classic'][key]=value
                    self.refused(c.packed_tether_routes,d,{'routes':bad},references)
                def drift(path):
                    rec=read(path)
                    if '-source.r16run' not in path.name:
                        rec.columns['actual_v_x'][0]=1.0000001
                    return rec
                decoder.read=drift
                self.refused(c.packed_tether_routes,d,{'routes':observations},references)
                decoder.read=read
                (root/'tape.json').write_text('changed')
                self.refused(c.packed_tether_routes,d,{'routes':observations},references)

    def test_probe_preserves_inherited_controls_and_adds_real_interface_observers(self):
        text=(PROJECT/'tools/r21-pack-probe.gd').read_text()
        self.assertIn('await super._controls()',text)
        self.assertNotIn('contract is not bound',text)
        for method in ('late_step','early_step','observe_actual','_tether_controls','_through_controls','_judge_run'):
            self.assertNotIn('func '+method+'(',text)
        for evidence in ('r21_acquisition_snapshot()', '_r21_readiness_agreements >= 3',
                         'reference == _tether_trace', 'game.hud.anchor_assist_switch',
                         'game.session.ghost.load_run', 'SubViewport.UPDATE_DISABLED',
                         'for cadence: int in [0, 1, 3]', '_r21_lifecycle_controls()',
                         'not game.player.has_method("r21_acquisition_snapshot")'):
            self.assertIn(evidence,text)


if __name__ == '__main__':
    unittest.main()
