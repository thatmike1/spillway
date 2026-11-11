#!/usr/bin/env python3
"""Engine-free preparation tests using the restored delivered R20 data.

No synthetic fixture is a runtime freeze or a candidate-acceptance result.
"""
import copy
import gzip
import hashlib
import itertools
import json
import math
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import tempfile
import time
import unittest
import zlib

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[1]/'tools'))
import r21_parity_core as K
DRIVER = K.module('r21_pure_driver', K.PROJECT/'tools/check-r21-parity.py')
M = K.module('r21_original_mutations', K.PROJECT/'tests/r20_parity_mutations.py')


def edit_header(data, edit):
    length = struct.unpack_from('<I', data, 12)[0]
    header = json.loads(data[16:16+length])
    edit(header)
    raw = json.dumps(header, separators=(',',':')).encode()
    output = bytearray(data[:12]+struct.pack('<I',len(raw))+raw)
    chain = hashlib.sha256(output).digest()
    output.extend(chain)
    at = 16+length+32
    while at < len(data):
        h = list(struct.unpack_from('<4sBBHIIIII',data,at))
        stored = data[at+60:at+60+h[6]]
        if h[1] == K.A.CHUNK_SEAL:
            seal = json.loads(zlib.decompress(stored) if h[2] == 1 else stored)
            seal['counts']['bytes'] = len(output)
            raw = json.dumps(seal, separators=(',',':')).encode()
            stored = zlib.compress(raw)
            h[2], h[5], h[6] = 1, len(raw), len(stored)
        packed = struct.pack('<4sBBHIIIII', *h)
        chain = hashlib.sha256(chain+packed+stored).digest()
        output.extend(packed+chain+stored)
        at += 60+struct.unpack_from('<I',data,at+16)[0]
    return bytes(output)


def duplicate_record_json(data, section):
    # rebuild every digest/count so only the shadowed JSON key can cause refusal.
    length = struct.unpack_from('<I', data, 12)[0]
    header = data[16:16+length]
    touched = False
    if section == 'header':
        header = b'{"metadata":{"unreviewed":true},'+header[1:]
        touched = True
    out = bytearray(data[:12]+struct.pack('<I',len(header))+header)
    chain = hashlib.sha256(out).digest()
    out.extend(chain)
    at = 16+length+32
    while at < len(data):
        head = list(struct.unpack_from('<4sBBHIIIII',data,at))
        stored = data[at+60:at+60+head[6]]
        raw = zlib.decompress(stored) if head[2] == 1 else stored
        if section == 'events' and head[1] == K.A.CHUNK_TICKS and not touched:
            count = struct.unpack_from('<I',raw)[0]
            offset = 4+count*sum(size for _,_,size in K.A.TICK_LAYOUT)
            inputs = struct.unpack_from('<I',raw,offset)[0]
            offset += 4+inputs*K.A.INPUT_ROW
            events = raw[offset+4:]
            first = events.find(b'{')
            if first >= 0:
                events = events[:first+1]+b'"k":"unreviewed",'+events[first+1:]
                raw = raw[:offset]+struct.pack('<I',len(events))+events
                touched = True
        if head[1] == K.A.CHUNK_SEAL:
            seal = json.loads(raw)
            seal['counts']['bytes'] = len(out)
            raw = json.dumps(seal,separators=(',',':')).encode()
            if section == 'seal':
                raw = b'{"outcome":{"unreviewed":true},'+raw[1:]
                touched = True
        stored = zlib.compress(raw)
        head[2],head[5],head[6] = 1,len(raw),len(stored)
        packed = struct.pack('<4sBBHIIIII',*head)
        chain = hashlib.sha256(chain+packed+stored).digest()
        out.extend(packed+chain+stored)
        at += 60+struct.unpack_from('<I',data,at+16)[0]
    assert touched
    return bytes(out)


class Preparation(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        K.B.gate()
        cls.baseline = K.baseline_guard()
        cls.route = K.routes()[0]
        cls.directory = K.BASELINE/cls.route['name']/'old'
        cls.records = K.ordered_records(cls.directory)
        cls.finish = next(r for r in cls.records if r.seal['outcome']['kind'] == 'finish')
        cls.policy = K.identity_policy()
        # this is an actual-data comparator fixture, deliberately not a usable reviewed contract.
        cls.contract = {'identity_policy':cls.policy, 'new_metadata':{'build':'test-r21', 'build_label':'Spillway R21'}}
        cls.workspace = tempfile.TemporaryDirectory(prefix='r21-pure-',dir='/tmp')
        cls.scratch = Path(cls.workspace.name)
        cls.mutations = []

    @classmethod
    def tearDownClass(cls):
        K.exact(K.baseline_guard(), cls.baseline, 'after all pure tests')
        size = sum(p.stat().st_size for p in cls.scratch.rglob('*') if p.is_file())
        assert size <= K.PREP_CAP
        print('actual-data mutations:',len(cls.mutations),'; final owned temporary bytes:',size)
        cls.workspace.cleanup()

    def refuses(self, function):
        with self.assertRaises((ValueError,AssertionError,KeyError,TypeError,RuntimeError)):
            function()

    def test_01_baseline_provenance_and_source_equivalence(self):
        self.assertEqual(self.baseline['selected_files'],410)
        self.assertEqual(self.baseline['selected_bytes'],115983321)
        self.assertEqual(self.baseline['capture_commit'],K.CAPTURE)
        self.assertNotEqual(K.CAPTURE,K.BASE)
        for field in ('restore_sha256','archive_sha256','archive_inventory_sha256','source_equivalence_sha256'):
            self.assertEqual(len(self.baseline[field]),64)
        self.refuses(lambda:K.checked(K.BASELINE/'R21-RESTORE.json','0'*64))

    def test_02_exact_all_original_tapes(self):
        self.assertEqual(len(K.routes()),16)
        for route in K.routes():
            plan,data = K.route_plan(route)
            self.assertEqual(plan['physics_hz'],128)
            self.assertGreater(plan['duration_ticks'],0)
            self.assertIn(route['preset'],('server128','server128_aa1000'))
            self.assertEqual(len(hashlib.sha256(data).hexdigest()),64)

    def test_03_adapter_preserves_observer_and_executor(self):
        old = (K.PROJECT/'tests/r20_candidate_parity.gd').read_text()
        new = (K.PROJECT/'tests/r21_parity.gd').read_text()
        self.assertTrue(new.startswith('extends "res://tests/r19_parity.gd"'))
        late = lambda text:text[text.index('func late_step('):].split('\nfunc ',1)[0].rstrip()
        self.assertEqual(late(old),late(new))
        preloads = __import__('re').findall(r'preload\("([^"]+)"\)',new)
        self.assertEqual(preloads,['res://tests/r20_candidate_reference.gd'])
        self.assertIn(K.SCENE,new)
        self.assertIn(K.SCRIPT,new)
        self.assertNotIn('r21_tether',new)

    def test_04_all_158_actual_recordings_and_binary_fields(self):
        count = 0
        for route in K.routes():
            directory = K.BASELINE/route['name']/'old'
            for row in K.load(directory/'readers.json'):
                rec = K.A.read(directory/'runs'/row['file'])
                self.assertTrue(rec.ok,rec.errors)
                self.assertEqual(K.C.packed_columns(rec.columns,True),row['columns_sha256'])
                self.assertEqual(K.C.packed_columns(rec.inputs),row['inputs_sha256'])
                self.assertEqual(list(rec.columns['tick']),list(range(len(rec.columns['tick']))))
                count += 1
        self.assertEqual(count,142)
        for route in K.routes():
            rec = K.A.read(K.BASELINE/route['name']/'old/runs/golden.r16run')
            self.assertTrue(rec.ok,rec.errors)
            count += 1
        self.assertEqual(count,158)

    def test_05_complete_and_incomplete_actual_observations(self):
        path = self.directory/'evaluator/observations.jsonl.gz'
        self.assertGreater(sum(1 for _ in K.coverage(K.stream(path),self.records)),0)
        def missing_first():
            yield from itertools.islice(K.stream(path),1,None)
        def missing_middle():
            for i,row in enumerate(K.stream(path)):
                if i != 10:
                    yield row
        def missing_final():
            rows = iter(K.stream(path))
            previous = next(rows)
            for row in rows:
                yield previous
                previous = row
            self.assertEqual(previous['style_events'],[],'test must remove an actual event-free final row')
        for name, rows in [('first',missing_first),('interior',missing_middle),('final event-free',missing_final)]:
            with self.subTest(name=name):
                self.refuses(lambda rows=rows:sum(1 for _ in K.coverage(rows(),self.records)))
                self.mutations.append('actual observations missing '+name)

    def test_06_duplicate_reordered_nontyped_ticks_and_run_ids(self):
        actual = list(itertools.islice(K.stream(self.directory/'evaluator/observations.jsonl.gz'),3))
        for name, edit in [('duplicate',lambda r:r.__setitem__(1,copy.deepcopy(r[0]))),
                           ('reorder',lambda r:r.reverse()),
                           ('float tick',lambda r:r[0]['sample'].update(tick=0.0)),
                           ('bool tick',lambda r:r[0]['sample'].update(tick=False)),
                           ('unknown run',lambda r:r[0].update(run_id='unknown'))]:
            rows = copy.deepcopy(actual)
            edit(rows)
            self.refuses(lambda rows=rows:sum(1 for _ in K.coverage(rows,self.records)))
            self.mutations.append('actual observations '+name)

    def test_07_all_binary_sample_and_input_mutations_with_valid_hash_chains(self):
        original = Path(self.finish.path).read_bytes()
        for group,names in [('columns',K.A.COLUMN_NAMES),('inputs',[n for n,_,_ in K.A.INPUT_LAYOUT])]:
            expected = K.C.packed_columns(getattr(self.finish,group),group == 'columns')
            for name in names:
                with self.subTest(group=group,name=name):
                    path = self.scratch/'mutant.r16run'
                    path.write_bytes(M.rewrite(original,M.column_edit(group,name)))
                    record = K.A.read(path)
                    self.assertTrue(not record.ok or K.C.packed_columns(getattr(record,group),group == 'columns') != expected)
                    self.mutations.append('valid-chain '+group+'.'+name)
        path.unlink()

    def test_08_every_header_metadata_and_motion_identity_mutation(self):
        original = Path(self.finish.path).read_bytes()
        expected = K.record_view(self.finish,self.contract,'old')
        for group,fields in [('metadata',K.META_KEYS),('identity',K.IDENTITY_KEYS)]:
            for field in fields:
                with self.subTest(group=group,field=field):
                    path = self.scratch/'mutant.r16run'
                    path.write_bytes(edit_header(original,lambda h,g=group,f=field:h[g].__setitem__(f,{'unreviewed':f})))
                    rec = K.A.read(path)
                    if rec.ok:
                        try:
                            got = K.record_view(rec,self.contract,'old')
                        except (ValueError,AssertionError,KeyError,TypeError):
                            pass
                        else:
                            self.assertIsNotNone(next(K.differences(expected,got),None))
                    self.mutations.append('valid-chain header '+group+'.'+field)
        path.unlink()

    def test_09_only_explicit_build_labels_can_change(self):
        path = self.scratch/'labels.r16run'
        path.write_bytes(edit_header(Path(self.finish.path).read_bytes(),
                         lambda h:h['metadata'].update(self.contract['new_metadata'])))
        rec = K.A.read(path)
        self.assertTrue(rec.ok,rec.errors)
        K.exact(K.record_view(self.finish,self.contract,'old'),K.record_view(rec,self.contract,'new'),'presentation-only labels')
        self.refuses(lambda:K.record_view(rec,self.contract,'old'))
        path.unlink()

    def test_10_actual_style_and_control_mutations_are_never_separated(self):
        summary = K.load(self.directory/'summary.json')
        mutations = [('style score',lambda s:s['tour'][0]['game']['style'].update(score=-1)),
                     ('control',lambda s:s['tour'][20]['game'].update(paused=False)),
                     ('hull',lambda s:s['tour'][0]['game']['live_hull'].update(unknown=True)),
                     ('identity',lambda s:s['tour'][0]['game']['identity'].update(geometry='unknown')),
                     ('ghost fade',lambda s:s['tour'][0]['ghost'].update(fade=-1.0)),
                     ('missing controls',lambda s:s.update(tour=[]))]
        for name,edit in mutations:
            bad = copy.deepcopy(summary)
            edit(bad)
            self.assertIsNotNone(next(K.differences(summary,bad),None),name)
            self.mutations.append('actual '+name)
        record = K.record_view(self.finish,self.contract,'old')
        for event in record['events']:
            if event['k'] in ('style','direction'):
                for field in event['d']:
                    bad = copy.deepcopy(record)
                    target = next(e for e in bad['events'] if e['q'] == event['q'])
                    target['d'][field] = {'unreviewed':field}
                    self.assertIsNotNone(next(K.differences(record,bad),None))
                    self.mutations.append('actual '+event['k']+'.'+field)

    def test_11_no_tolerances_float_sign_or_difference_cap(self):
        row = next(K.stream(self.directory/'evaluator/trace.jsonl.gz'))
        bad = copy.deepcopy(row)
        bad['p'][0] = math.nextafter(bad['p'][0],math.inf)
        self.assertIsNotNone(next(K.differences(row,bad),None))
        self.assertIsNotNone(next(K.differences(0.0,-0.0),None))
        bad = copy.deepcopy(row)
        for key in list(bad)[:10]:
            bad[key] = {'unreviewed':key}
        report = []
        result = K.compare_rows([row],[bad],report.append)
        self.assertFalse(result['ok'])
        self.assertGreaterEqual(len(report),10)
        for group in ('columns','inputs'):
            packed = K.C.packed_columns(getattr(self.finish,group),group == 'columns')
            for name,values in getattr(self.finish,group).items():
                if not any(type(v) is float for v in values):
                    continue
                for i,x in enumerate(values):
                    if x == 0.0:
                        changed = copy.deepcopy(getattr(self.finish,group))
                        changed[name][i] = math.copysign(0.0,-math.copysign(1.0,x))
                        self.assertNotEqual(K.C.packed_columns(changed,group == 'columns'),packed)
                        self.mutations.append('actual float sign '+group+'.'+name)
                        break

    def test_12_engine_alias_default_and_unknown_metadata_refuse(self):
        old = K.load(self.directory/'evaluator/engine.json')
        route = self.route
        command = K.route_command(route,'old',Path('/source'),Path('/out'),Path('/golden'),Path('/tape'))
        candidate = copy.deepcopy(old)
        candidate.update(cmdline=['--script','res://tests/r21_parity.gd'],executor_script='res://tests/r21_parity.gd',
                         user_args=command[command.index('--')+1:],
                         user_data_dir='/profile/xdg_data_home/godot/app_userdata/Spillway')
        candidate['game']['node_script'] = K.SCRIPT
        self.assertTrue(K.engine_guard(candidate,old,command,Path('/profile')))
        for name,edit in [('default preset',lambda d:d['settings'].update(autohop=False)),
                          ('input alias',lambda d:d.update(input_profile='unknown')),
                          ('unknown engine',lambda d:d.update(unknown=True)),
                          ('host fallback',lambda d:d['game'].update(node_script='res://fake.gd'))]:
            bad = copy.deepcopy(candidate)
            edit(bad)
            self.refuses(lambda bad=bad:K.engine_guard(bad,old,command,Path('/profile')))
            self.mutations.append('actual '+name)

    def test_13_unreviewed_incomplete_freezes_refuse_before_output(self):
        out = self.scratch/'never-created'
        result = DRIVER.main(['--preflight','--candidate',K.BASE,'--out',str(out)])
        self.assertEqual(result,1)
        self.assertFalse(out.exists())
        self.refuses(lambda:K.validate_contract({}, {}, K.BASE, {}, {}, '0'*64))
        for text in ('{"x":1,"x":2}','{"x":NaN}'):
            path = self.scratch/'bad.json'
            path.write_text(text)
            self.refuses(lambda:K.load(path))
        path.unlink()

    def test_14_inherited_self_tests_still_hold(self):
        result = K.module('r21_original_selftest', K.PROJECT/'tests/r20_parity_audit.py').self_test()
        self.assertTrue(result['ok'])
        self.assertGreaterEqual(len(result['checks']),91)

    def test_15_actual_summary_unknown_fields_and_dropped_checks_refuse(self):
        summary = K.load(self.directory/'summary.json')
        summary.update(host_scene=K.SCENE, host_script=K.SCRIPT,
                       r21_presentation={'window_title':'Spillway R21 · comparator fixture', 'menu_registry':{}})
        contract = dict(self.contract, window_titles={self.route['name']:'Spillway R21 · comparator fixture'}, menu_registry={})
        plan,_ = K.route_plan(self.route)
        self.assertTrue(K.summary_guard(summary,self.route,'old',plan,contract))
        for invalid in [True, float(summary['finish']['last_tick']), str(summary['finish']['last_tick']), None, float('nan'), float('inf'),
                        summary['finish']['last_tick'] + 0.5, summary['finish']['last_tick'] - 1]:
            bad = copy.deepcopy(summary)
            bad['finish']['last_tick'] = invalid
            self.refuses(lambda bad=bad:K.summary_guard(bad,self.route,'old',plan,contract))
            self.mutations.append('summary numeric finish tick refused ' + repr(invalid))
        for name,edit in [('unknown root',lambda s:s.update(unknown=True)),
                          ('unknown presentation',lambda s:s['r21_presentation'].update(unknown=True)),
                          ('drop original checks',lambda s:s.update(checks=[])),
                          ('window title',lambda s:s['r21_presentation'].update(window_title='unreviewed')),
                          ('menu identity',lambda s:s['r21_presentation']['menu_registry'].update(unknown=True))]:
            bad = copy.deepcopy(summary)
            edit(bad)
            self.refuses(lambda bad=bad:K.summary_guard(bad,self.route,'old',plan,contract))
            self.mutations.append('actual summary '+name)

    def test_16_actual_default_preset_registry_and_input_aliases(self):
        identity = K.r20_identity()
        self.assertTrue(K.original_identity_guard(identity))
        for field in identity['registry']:
            bad = copy.deepcopy(identity)
            bad['registry'][field] = {'unreviewed':field}
            self.refuses(lambda bad=bad:K.original_identity_guard(bad))
            self.mutations.append('actual registry '+field)
        record = K.record_view(self.finish,self.contract,'old')
        for kind in ('held_names','action_name'):
            bad = copy.deepcopy(record)
            event = next(e for e in bad['events'] if e['k'] == kind)
            event['d'] = {'unreviewed':kind}
            self.assertIsNotNone(next(K.differences(record,bad),None))
            self.mutations.append('actual recording alias '+kind)

    def test_17_frozen_source_import_metadata_modes_and_unknown_code(self):
        root, cache = self.scratch/'source', self.scratch/'import'
        root.mkdir()
        cache.mkdir()
        (root/'.godot').symlink_to(cache)
        name = 'tests/r19_parity.gd'
        code = root/name
        code.parent.mkdir()
        code.write_bytes((K.PROJECT/name).read_bytes())
        code.chmod(0o644)
        files = {name:K.sha(code)}
        inventory = {name:{'sha256':K.sha(code),'mode':'100644'}}
        self.assertEqual(DRIVER.imported_source(root,cache,files,inventory),{})
        cache_data = cache/'imported/texture.ctex'
        cache_data.parent.mkdir()
        cache_data.write_bytes(b'explicit synthetic import data')
        self.assertEqual(DRIVER.cache_state(cache)[str(cache_data.relative_to(cache))]['sha256'],K.sha(cache_data))
        for suffix in ('.gd','.gdshader','.py','.GD'):
            injected = cache/('unreviewed'+suffix)
            injected.write_text('extends Node\n')
            self.refuses(lambda:DRIVER.imported_source(root,cache,files,inventory))
            injected.unlink()
        cache_link = cache/'unreviewed-link'
        cache_link.symlink_to(code)
        self.refuses(lambda:DRIVER.imported_source(root,cache,files,inventory))
        cache_link.unlink()
        uid = root/(name+'.uid')
        uid.write_text('uid://abcdef123\n')
        self.assertEqual(DRIVER.imported_source(root,cache,files,inventory),{name+'.uid':K.sha(uid)})
        uid.write_text('unreviewed\n')
        self.refuses(lambda:DRIVER.imported_source(root,cache,files,inventory))
        uid.unlink()
        unknown = root/'unreviewed.gd'
        unknown.write_bytes(code.read_bytes())
        self.refuses(lambda:DRIVER.imported_source(root,cache,files,inventory))
        unknown.unlink()
        code.chmod(0o755)
        self.refuses(lambda:DRIVER.imported_source(root,cache,files,inventory))
        code.chmod(0o644)
        code.write_bytes(code.read_bytes()+b'\n')
        self.refuses(lambda:DRIVER.imported_source(root,cache,files,inventory))
        shutil.rmtree(root)
        shutil.rmtree(cache)

    def test_18_future_actual_byte_negative_driver_on_restored_data(self):
        auditor = K.module('r21_pure_negative_driver', K.PROJECT/'tests/r21_parity_audit.py')
        result = auditor.negative_seed(self.directory,self.scratch/'negative-driver',self.contract,'old')
        self.assertTrue(result['ok'])
        self.assertGreaterEqual(len(result['checks']),60)
        self.assertTrue(all(c['refused'] for c in result['checks']))
        self.mutations.extend('future negative driver '+c['name'] for c in result['checks'])

    def test_19_complete_shared_delivery_freeze_schema(self):
        delivery_tests = K.module('r21_shared_freeze_fixture', K.PROJECT/'tests/test_package_r21.py')
        _,_,freeze,_ = delivery_tests.fixture()
        freeze['runtime'].update(main_scene=K.SCENE, main_script=K.SCRIPT)
        freeze['delivery_components'] = {name:{'tests/fixture_'+name+'.py':'1'*64}
                                         for name in ('saltglass','tether','parity')}
        self.assertIs(K.freeze_schema(freeze,freeze['source_commit']),freeze)
        self.assertIs(K.D.validate_freeze(freeze,freeze['source_commit']),freeze)
        for edit in (lambda f:f.pop('delivery_components'),
                     lambda f:f['delivery_components'].update(unknown={}),
                     lambda f:f['delivery_components'].__setitem__('saltglass',{}),
                     lambda f:f['delivery_components'].__setitem__('tether',{'../escape.py':'1'*64}),
                     lambda f:f['delivery_components'].__setitem__('parity',{'tests/fixture.py':'bad'})):
            bad = copy.deepcopy(freeze)
            edit(bad)
            self.refuses(lambda:K.freeze_schema(bad,bad['source_commit']))

    def test_20_hash_valid_duplicate_recording_JSON_refused_everywhere(self):
        # the frozen reader accepts each hash-valid witness; only R21 adds duplicate-key refusal.
        path = self.scratch/'duplicate.r16run'
        for section in ('header','events','seal'):
            path.write_bytes(duplicate_record_json(self.finish.path.read_bytes(),section))
            self.assertTrue(K.K.A.read(path).ok,section)
            parsed = K.A.read(path)
            self.assertFalse(parsed.ok,section)
            self.assertTrue(any('duplicate recording JSON key' in error for error in parsed.errors),section)
            self.refuses(lambda:K.record_view(K.K.A.read(path),self.contract,'old'))
        path.unlink()

    def test_21_retained_cache_receipts_refuse_code_paths_and_invalid_inventory(self):
        valid = {'imported/texture.ctex':{'sha256':'1'*64,'bytes':10,'mode':0o644}}
        self.assertIs(K.cache_inventory_guard(valid),valid)
        for name in ('unreviewed.gd','nested/a.gdshader','unknown.py','nested/../a.ctex','/absolute.ctex','a\\b.ctex'):
            self.refuses(lambda name=name:K.cache_inventory_guard({name:next(iter(valid.values()))}))
        for field, value in (('sha256','bad'),('bytes',True),('bytes',-1),('mode',0o100644)):
            bad = copy.deepcopy(valid)
            bad['imported/texture.ctex'][field] = value
            self.refuses(lambda:K.cache_inventory_guard(bad))


def original_56():
    K.B.gate()
    before = K.baseline_guard()
    old_before = K.K.baseline_guard()
    with tempfile.TemporaryDirectory(prefix='r21-original-56-',dir='/tmp') as scratch:
        root = Path(scratch)
        out = root/'controls'
        command = [sys.executable,'-B',str(K.PROJECT/'tests/r20_parity_mutations.py'),
                   str(K.K.BASELINE),'--out',str(out)]
        with (root/'log').open('w') as log:
            process = subprocess.Popen(command,cwd=K.PROJECT,stdout=log,stderr=subprocess.STDOUT)
            peak = 0
            try:
                while process.poll() is None:
                    peak = max(peak,sum(p.stat().st_size for p in root.rglob('*') if p.is_file()))
                    K.need(peak <= K.PREP_CAP,'original 56 controls need more than authorized 60MiB; stopped')
                    K.B.gate()
                    time.sleep(.1)
                K.need(process.wait() == 0,(root/'log').read_text())
            finally:
                if process.poll() is None:
                    process.terminate()
                    process.wait()
        result = K.load(out/'SUMMARY.json')
        K.need(result['ok'] is True and len(result['checks']) == 56 and all(c['ok'] for c in result['checks']),
               'unchanged original controls failed')
        result['preparation_owned_peak_bytes'] = peak
        result['scope'] = 'unchanged 56 actual-data negatives on immutable R19 proof only; no R21 physical reference'
        print(json.dumps(result,indent=2))
    K.exact(K.K.baseline_guard(),old_before,'R19 negative-control source after')
    K.exact(K.baseline_guard(),before,'R20 physical reference after original controls')


if __name__ == '__main__':
    if sys.argv[1:] == ['--original-controls']:
        original_56()
    else:
        unittest.main(verbosity=2)
