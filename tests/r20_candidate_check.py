#!/usr/bin/env python3
"""engine-free candidate checker preparation tests; synthetic contracts are never acceptance."""
import ast
import contextlib
import copy
import gzip
import io
import json
import math
from pathlib import Path
import struct
import sys
import tempfile
import unittest
from unittest.mock import patch
sys.dont_write_bytecode=True
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
import r20_candidate_core as K
D=K.module('r20_candidate_driver_test',K.PROJECT/'tools/check-r20-candidate-parity.py')


class CandidatePreparation(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        K.PREP.mkdir(exist_ok=True)
        cls.policy=K.identity_policy()
        cls.baseline_report=K.load(K.BASELINE/'REPORT.json')
        cls.route=K.routes()[0]
        cls.original=K.load(K.BASELINE/cls.route['name']/'result.json')
        cls.old_path=Path(cls.original['runs']['r19']['summary']['finish']['record_path'])
        cls.rec,cls.old=K.C.OLD.recording(cls.old_path,K.A)
        seed=cls.rec.header['metadata']
        cls.scoring={'old_metadata':{k:seed[k] for k in ('scoring','build','build_label')},
            'new_metadata':{'build':'spillway-2026.11.10-r20','build_label':'Spillway R20',
                'scoring':{'style':K.STYLE_ID,'style_key':K.STYLE_KEY,'timing':'r16-timing-1'}}}

    def refuse(self,fn,*args):
        with self.assertRaises((K.Refused,K.P.Rejected,AssertionError,KeyError,ValueError,TypeError)):
            fn(*args)

    def test_complete_immutable_baseline_inventory(self):
        result=K.baseline_guard()
        self.assertGreater(result['members'],600)
        self.assertEqual(K.sha(K.BASELINE/'MANIFEST.json'),K.BASELINE_MANIFEST_SHA)

    def test_policy_comes_from_both_baseline_plays_all_original_maps(self):
        self.assertEqual(set(k.split('/')[0] for k in self.policy['identities']),set(K.P.ORIGINAL_MAPS))
        self.assertEqual(set(self.policy['metadata_fields']),K.META_KEYS)
        self.assertEqual(set(self.policy['header_fields']),K.HEADER_KEYS)
        self.assertEqual(set(self.policy['original_identity']['maps']) & set(K.P.ORIGINAL_MAPS),set(K.P.ORIGINAL_MAPS))

    def test_review_required_and_baseline_cannot_be_substituted(self):
        contract={'schema':1,'kind':'example','status':'REVIEWED','reviewed_by':'parent','baseline_manifest_sha256':K.BASELINE_MANIFEST_SHA}
        K.reviewed(contract,'example')
        for field,value in [('schema',True),('schema',2),('kind','unknown'),('status','UNFINALIZED'),('reviewed_by',''),('baseline_manifest_sha256','0'*64)]:
            bad=dict(contract);bad[field]=value
            self.refuse(K.reviewed,bad,'example')

    def test_freeze_exact_fields_versions_full_commit_and_all_six(self):
        f={'schema':1,'runtime_frozen':True,'source_commit':'a'*40,'identity_sha256':'b'*64,
            'new_maps':list(K.P.NEW_MAPS),'required_maps':list(K.P.REQUIRED_MAPS),
            'experimental_maps':list(K.P.EXPERIMENTAL_MAPS),'reached_items':[1,2,3,4,5,6],'intentional_changes':{}}
        K.freeze_guard(f,'a'*40)
        for field,value in [('schema',True),('runtime_frozen',False),('source_commit','HEAD'),('identity_sha256','short'),
            ('new_maps',[]),('required_maps',['breakwater']),('experimental_maps',[]),('reached_items',[1,2]),
            ('intentional_changes',{'scripts/r14_source_motion.gd':'f'*64}),('unknown',True),('breakwater_geometry','exception')]:
            bad=copy.deepcopy(f);bad[field]=value
            self.refuse(K.freeze_guard,bad,'a'*40)
        for key in f:
            bad=copy.deepcopy(f);del bad[key];self.refuse(K.freeze_guard,bad,'a'*40)

    def test_duplicate_nonfinite_and_wrong_hash_json_refuse(self):
        with tempfile.TemporaryDirectory(dir=K.PREP) as td:
            p=Path(td)/'contract.json'
            for text in ['{"schema":1,"schema":2}','{"n":NaN}','{"n":Infinity}']:
                p.write_text(text);self.refuse(K.load,p)
            p.write_text('{}');self.refuse(K.checked_json,p,'0'*64)

    def test_no_candidate_defaults_or_engine_on_missing_inputs(self):
        existed=K.FINAL.exists()
        with patch.object(D,'run_route') as run,patch.object(D,'snapshot') as snapshot:
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(D.main(['--preflight']),1)
                self.assertEqual(D.main(['--execute','--candidate','7b19d255e47115fa278616b5d29fc0177b76d2b2']),1)
            run.assert_not_called();snapshot.assert_not_called()
        self.assertEqual(K.FINAL.exists(),existed)

    def test_matrix_requires_exact_sixteen_tapes_three_variants(self):
        report={'mode':'candidate','baseline_commit':K.B.BASE,'routes':[
            {'name':r['name'],'map':r['map'],'preset':r['preset'],'variants':list(K.VARIANTS)} for r in K.routes()]}
        K.matrix_guard(report)
        mutations=[lambda r:r['routes'].pop(),lambda r:r['routes'].reverse(),
            lambda r:r['routes'][0]['variants'].pop(),lambda r:r['routes'][0].update(map='saltglass'),
            lambda r:r['routes'].__setitem__(1,r['routes'][0])]
        for edit in mutations:
            bad=copy.deepcopy(report);edit(bad);self.refuse(K.matrix_guard,bad)

    def test_every_raw_mismatch_is_retained_not_first_four(self):
        a=[{'p':[float(i),0.,0.],'style':{'score':i}} for i in range(12)]
        b=copy.deepcopy(a)
        for row in b:row['p'][0]=math.nextafter(row['p'][0],math.inf);row['style']['score']+=1
        out=[];got=K.compare_rows(iter(a),iter(b),out.append,True)
        self.assertFalse(got['ok']);self.assertEqual(got['raw_mismatches'],12)
        self.assertEqual(len(out),24)
        self.assertEqual(sum(r['section']=='scoring' for r in out),12)

    def test_actual_physical_schema_every_key_and_ulp_remains_exact(self):
        path=K.BASELINE/'breakwater-basic/r19/evaluator/trace.jsonl.gz'
        row=next(K.C.stream(path))
        for field in row:
            if field=='style':continue
            bad=copy.deepcopy(row);bad[field]={'unreviewed':field};out=[]
            self.assertFalse(K.compare_rows([row],[bad],out.append,True)['ok'],field)
        for edit in [lambda r:r.update(unknown=1),lambda r:r['p'].__setitem__(0,math.nextafter(r['p'][0],math.inf)),
            lambda r:r['physics']['fingerprint'].update(unknown=1),lambda r:r['identity'].update(unknown=1)]:
            bad=copy.deepcopy(row);edit(bad)
            self.assertFalse(K.compare_rows([row],[bad],lambda _:None,True)['ok'])

    def test_existing_record_is_not_accepted_as_candidate(self):
        self.assertFalse(K.record_compare(self.old,self.old,self.scoring)['ok'])
        candidate=copy.deepcopy(self.old);candidate['header']['metadata'].update(self.scoring['new_metadata'])
        self.assertTrue(K.record_compare(self.old,candidate,self.scoring)['ok'])
        # this positive exercises a pure comparator with synthetic label substitution, not an R20 play.
        for key in K.META_KEYS:
            bad=copy.deepcopy(candidate);bad['header']['metadata'][key]={'changed':True}
            self.assertFalse(K.record_compare(self.old,bad,self.scoring)['ok'],key)
        for key in K.IDENTITY_KEYS:
            bad=copy.deepcopy(candidate);bad['header']['identity'][key]='unknown'
            self.assertFalse(K.record_compare(self.old,bad,self.scoring)['ok'],key)
        bad=copy.deepcopy(candidate);bad['header']['metadata']['unknown']=1
        self.assertFalse(K.record_compare(self.old,bad,self.scoring)['ok'])

    def test_ordinary_detectors_full_schema_geometry_combo_and_points(self):
        events=[e for e in self.rec.events if e['k']=='style']
        self.assertTrue(events)
        K.detector_compare(events,events)
        for field in K.STYLE_FIELDS:
            bad=copy.deepcopy(events)
            bad[0]['d'][field]={'unreviewed':True}
            self.refuse(K.detector_compare,events,bad)
        bad=copy.deepcopy(events);bad[0]['d']['unknown']=1;self.refuse(K.detector_compare,events,bad)
        self.refuse(K.detector_compare,events,events[1:])
        bad=copy.deepcopy(events);bad[0]['d']['points']+=1;self.refuse(K.detector_compare,events,bad)

    def test_changed_direction_points_need_independent_reference(self):
        old=copy.deepcopy(next(e for e in self.rec.events if e['k']=='style'))
        old['d'].update(base=80,points=160,mult=2.,combo_mult=1.,direction_mult=2.)
        new=copy.deepcopy(old);new['d'].update(points=80,mult=1.,direction_mult=1.)
        got=K.detector_compare([old],[new]);self.assertEqual(len(got['ordinary_changes']),1)
        bad=copy.deepcopy(new);bad['d']['combo']=999
        self.refuse(K.detector_compare,[old],[bad])
        # the live ordinary-reference equality is separately mandatory in observation_audit.
        text=(K.PROJECT/'tests/r20_candidate_observations.py').read_text()
        self.assertIn("K.exact(ordinary, row['ordinary_reference']",text)

    def test_preserved_physical_audit_body_and_input_decoder(self):
        old=(K.PROJECT/'tools/check-r19-parity.py').read_text()
        new=(K.PROJECT/'tests/r20_candidate_observations.py').read_text()
        for start,end in [('        ins = rec.inputs','        style_tables[run_id] = {}'),
            ('        c = rec.columns','        if found'),('        wanted = {','        found = ')]:
            a=old[old.index(start,old.index('def observation_audit')):old.index(end,old.index(start,old.index('def observation_audit')))]
            b=new[new.index(start):new.index(end,new.index(start))]
            self.assertEqual(ast.dump(ast.parse(__import__('textwrap').dedent(a))),ast.dump(ast.parse(__import__('textwrap').dedent(b))))

    def test_adapter_inherits_full_executor_and_never_writes_player(self):
        adapter=(K.PROJECT/'tests/r20_candidate_parity.gd').read_text()
        reference=(K.PROJECT/'tests/r20_candidate_reference.gd').read_text()
        self.assertTrue(adapter.startswith('extends "res://tests/r19_parity.gd"'))
        self.assertIn('super.late_step(delta)',adapter)
        for token in ['player.velocity =','player.global_position =','game.elapsed =','game.session.style =','_deliver_keys(', 'func _tour_step','func _finish']:
            self.assertNotIn(token,adapter)
        self.assertIn('super._award(kind, sample, base, label, measures, geo, out)',reference)
        self.assertEqual(reference.count('_direction_mult = 1.0'),1)
        self.assertEqual(K.sha(K.PROJECT/'tests/r20_candidate_r19_style.gd'),K.load(K.BASELINE/'source-r19.json')['archive_files']['scripts/r16_style.gd'])

    def test_inherited_adversarial_self_tests_unchanged(self):
        result=K.module('r20_candidate_prior_selftest',K.PROJECT/'tests/r20_parity_audit.py').self_test()
        self.assertTrue(result['ok']);self.assertGreater(len(result['checks']),50)

    def test_tagged_stream_bank_loss_queued_and_quit(self):
        fixtures=K.module('r20_candidate_package_fixtures',K.PROJECT/'tests/test_package_r20.py')
        for terminal in ('bank','stall','queued','quit'):
            rec,rows=fixtures.stack_stream_fixture(terminal)
            K.P.audit_style_stream(rec,rows)
            for name,edit in [('seal',lambda r,s:r.seal['outcome']['style'].update(score=-1)),
                ('diagnostic scored',lambda r,s:next(e['d'] for e in r.events if e['k']=='direction').update(points=1)),
                ('diagnostic serial',lambda r,s:next(e['d'] for e in r.events if e['k']=='direction').update(serial=100)),
                ('pending total',lambda r,s:s[4].update(style_score=99999))]:
                r,s=copy.deepcopy((rec,rows));edit(r,s)
                self.refuse(K.P.audit_style_stream,r,s)

    def test_float32_speed_reference_is_not_double_hypot(self):
        x,z=-3.685291051864624,-8.374980926513672
        self.assertNotEqual(K.P.source_horizontal_ups(x,z),math.hypot(x,z)/.0254)

    def test_actual_reader_inventory_is_closed_and_duplicate_ids_refuse(self):
        directory=K.BASELINE/'breakwater-basic/r19-ghost'
        readers=K.load(directory/'readers.json')
        self.assertTrue(D.O.reader_inventory(directory,readers))
        self.refuse(D.O.reader_inventory,directory,readers+readers[:1])
        bad=copy.deepcopy(readers);bad[0]['file']='../escape.r16run'
        self.refuse(D.O.reader_inventory,directory,bad)
        bad=copy.deepcopy(readers);bad[0]['unknown']=1
        self.refuse(D.O.reader_inventory,directory,bad)
        self.refuse(D.O.reader_inventory,directory,readers[1:])

    def test_actual_host_full_tape_startup_golden_and_every_identity_refusal(self):
        run=copy.deepcopy(self.original['runs']['r19-ghost'])
        run['summary'].update(host_scene='res://scenes/r20.tscn',host_script='res://scripts/r20_main.gd',variant='new')
        plan=K.load(K.BASELINE/self.route['name']/'expanded.json')
        K.complete_guard(run,plan,self.route,'new')
        edits=[lambda r:r['summary'].update(host_scene='res://scenes/r19.tscn'),
            lambda r:r['summary'].update(host_script='res://scripts/r19_main.gd'),
            lambda r:r['summary']['finish'].update(last_tick=10),
            lambda r:r['summary']['finish'].update(finished=False),
            lambda r:r['summary']['finish'].update(map='saltglass'),
            lambda r:r['summary']['finish']['identity'].update(format='unknown'),
            lambda r:r['summary']['identity_rejections'].pop(),
            lambda r:r['summary']['checks'].__setitem__(0,{'ok':False,'name':'failed'}),
            lambda r:r.update(engine_errors=['ERROR'])]
        for edit in edits:
            bad=copy.deepcopy(run);edit(bad);self.refuse(K.complete_guard,bad,plan,self.route,'new')
        self.refuse(K.complete_guard,run,plan,self.route,'toggle')

    def test_original_lab_slide_hop_ad_wall_without_w_and_grapple(self):
        path=K.BASELINE/'r16-lab-flow/r19/evaluator/trace.jsonl.gz'
        self.assertTrue(K.lab_guard(K.C.stream(path))['ok'])
        def wrong():
            for row in K.C.stream(path):
                if 'wall_jump' in row['motion'].get('experiment',{}).get('events',[]):row['held']['move_forward']=True
                yield row
        self.refuse(K.lab_guard,wrong())

    def test_contracts_bind_full_final_host_helpers_labels_and_original_identity(self):
        shared={'schema':1,'kind':'r20-direction-stack-parity','status':'REVIEWED','reviewed_by':'parent',
            'baseline_manifest_sha256':K.BASELINE_MANIFEST_SHA}
        component=K.checked_json(K.COMPONENT,K.COMPONENT_SHA)
        files=dict(K.load(K.BASELINE/'source-r19.json')['archive_files'])
        files.update({n:component['source_sha256'][n] for n in ('scripts/r16_style.gd','scripts/r16_style_panel.gd','scripts/r18_style_panel.gd')})
        files.update({'scripts/r20_main.gd':'f'*64,'scenes/r20.tscn':'e'*64})
        pins=K.helpers();files.update(pins)
        score=dict(shared,candidate_commit='a'*40,component_sha256=K.COMPONENT_SHA,runtime_sources=K.runtime_files(files),
            verification_helpers=pins,**self.scoring)
        identity=dict(shared,kind='r20-original-map-identity',policy=self.policy)
        freeze={'schema':1,'runtime_frozen':True,'source_commit':'a'*40,'identity_sha256':'b'*64,
            'new_maps':list(K.P.NEW_MAPS),'required_maps':list(K.P.REQUIRED_MAPS),
            'experimental_maps':list(K.P.EXPERIMENTAL_MAPS),'reached_items':[1,2,3,4,5,6],'intentional_changes':{}}
        # isolate the contract seam; preservation and live identity have their own independently exercised suites.
        with patch.object(K.P,'preservation'),patch.object(K.P,'identity_boundary'), \
             patch.object(K.subprocess,'check_output',return_value='run/main_scene="res://scenes/r20.tscn"'):
            self.assertTrue(K.contracts(freeze,score,identity,'a'*40,{},files))
            for field,value in [('candidate_commit','b'*40),('component_sha256','0'*64),('runtime_sources',{}),
                ('verification_helpers',{}),('old_metadata',{}),('new_metadata',{}),('unknown',1),('schema',2),('status','UNFINALIZED')]:
                bad=copy.deepcopy(score);bad[field]=value
                self.refuse(K.contracts,freeze,bad,identity,'a'*40,{},files)
            bad=copy.deepcopy(identity);bad['policy']['identities'].pop(next(iter(bad['policy']['identities'])))
            self.refuse(K.contracts,freeze,score,bad,'a'*40,{},files)
            bad=copy.deepcopy(files);bad['scripts/r20_main.gd']='0'*64
            self.refuse(K.contracts,freeze,score,identity,'a'*40,{},bad)
            bad=copy.deepcopy(files);bad['scripts/r16_style.gd']='0'*64
            self.refuse(K.contracts,freeze,score,identity,'a'*40,{},bad)

    def test_template_status_cannot_be_used_as_review(self):
        self.refuse(K.reviewed,{'schema':1,'kind':'r20-original-map-identity','status':'UNFINALIZED',
            'reviewed_by':'','baseline_manifest_sha256':K.BASELINE_MANIFEST_SHA},'r20-original-map-identity')

    def test_helper_inventory_contains_full_executor_reader_and_new_files(self):
        helpers=K.helpers()
        for name in ['tools/check-r20-parity.py','tools/check-r19-parity.py','tools/check-r17-parity.py',
            'tools/package-r20.py','tools/package-r18.py','tools/package-r16.py','tools/analyze-r16-runs.py',
            'tests/r17_parity.gd','tests/r19_parity.gd','tools/momentum-tape.gd','tests/r20_candidate_reference.gd','tests/r20_candidate_r19_style.gd']:
            self.assertIn(name,helpers)


if __name__=='__main__':unittest.main(verbosity=2)
