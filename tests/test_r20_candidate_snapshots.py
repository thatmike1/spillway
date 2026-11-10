#!/usr/bin/env python3
"""exercise the candidate auditor against actual captured observations and independent style identity."""
import copy
import gzip
import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
sys.dont_write_bytecode=True
PROJECT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(PROJECT/'tools'))
import r20_candidate_core as K

class ActualSnapshotContract(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.component=K.checked_json(K.COMPONENT,K.COMPONENT_SHA)
  path=K.FINAL/'breakwater-basic/old/evaluator/observations.jsonl.gz'
  first=next(K.C.stream(path))['run_id']
  cls.rows=[row for row in K.C.stream(path) if row['run_id']==first]
  assert cls.rows

 def test_identity_matches_accepted_component_and_godot_16_character_rule(self):
  self.assertEqual(K.STYLE_ID,self.component['identity'])
  self.assertEqual(K.STYLE_KEY,self.component['identity_key'])
  self.assertEqual(K.STYLE_KEY,K.STYLE_ID['version']+'/'+str(K.STYLE_ID['event_format'])+'/'+K.STYLE_ID['rules_sha256'][:16])

 def test_actual_full_attempt_snapshots_pass(self):
  K.style_snapshots(self.rows)

 def test_typo_key_and_changed_ordinary_verdict_refuse(self):
  for edit in [lambda r:r['actual']['style'].update(identity_key=self.component['identity_key']+'9'),lambda r:r['actual']['style']['diag']['verdicts'].update(unreviewed={'count':1})]:
   rows=copy.deepcopy(self.rows);edit(rows[-1])
   with self.assertRaises(K.Refused):K.style_snapshots(rows)

 def test_changed_direction_counter_refuses(self):
  rows=copy.deepcopy(self.rows)
  target=next(r for r in rows if r['actual']['style']['diag']['verdicts'].get('direction'))
  counts=target['actual']['style']['diag']['verdicts']['direction'];name=next(iter(counts));counts[name]+=1
  with self.assertRaises(K.Refused):K.style_snapshots(rows)

 def test_core_transport_avoids_per_chunk_tree_scan(self):
  with tempfile.TemporaryDirectory() as tmp:
   root=Path(tmp);source=root/'source.gz';source.write_bytes(gzip.compress(bytes(range(256))*1024,mtime=123))
   with patch.object(K,'FINAL',root),patch.object(K.B,'gate',return_value=16_000_000_000),patch.object(K.B,'allocated_footprint',wraps=K.B.allocated_footprint) as scans:
    got=K.transport(source,root/'out.gz',1021)
   self.assertEqual(gzip.decompress((root/'out.gz').read_bytes()),bytes(range(256))*1024)
   self.assertLessEqual(scans.call_count,2)



def snapshot(tick, verdict, counts):
    common = dict(score=0, combo=0, mult=1.0, combo_left_s=0.0, combo_window_s=2.0,
        last_combo={}, recent=[], last={}, by_kind={}, clean=True, finished=False,
        sealed=False, best_eligible=False, time_s=float(tick), context={})
    diag = dict(speed={}, sync={}, flight={}, gap={}, edge={}, near={}, crouch={},
        verdicts={}, farm_blocked={}, discontinuities=[], auto_breaks=0)
    ref = dict(copy.deepcopy(common), version='r19-style-1', identity_key='reference',
        direction={}, diag=copy.deepcopy(diag))
    diag['verdicts'] = {'direction': copy.deepcopy(counts)} if counts else {}
    diag['direction'] = dict(last=copy.deepcopy(verdict), visited_landings=0, flight={})
    direction = dict(kind='', hops=0, pending=0, unit=0, formula='unit*n*(n-1)/2', suspended=False, last={})
    actual = dict(copy.deepcopy(common), version=K.STYLE_ID['version'], identity_key=K.STYLE_KEY,
        direction=copy.deepcopy(direction), diag=diag)
    return dict(sample={'tick': tick}, actual={'style': actual}, ordinary_snapshot=ref,
        style_direction=direction, style_direction_verdict=copy.deepcopy(verdict),
        style_events=[], style_score=0)


class VerdictSchema(unittest.TestCase):
 def test_repeated_verdict_and_lifecycle_preserve_one_count(self):
  facing={'verdict':'facing','tick':0,'m':{}}
  rows=[snapshot(0,facing,{'facing':1}),snapshot(1,facing,{'facing':1}),
        snapshot(2,{'verdict':'stall','tick':2},{'facing':1})]
  K.style_snapshots(rows)

 def test_malformed_ticks_fields_measures_and_reasons_refuse(self):
  cases=[{'verdict':'facing','m':{}},
    {'verdict':'facing','tick':'0','m':{}}, {'verdict':'facing','tick':False,'m':{}},
    {'verdict':'facing','tick':999,'m':{}}, {'verdict':'facing','tick':-1,'m':{}},
    {'verdict':'facing','tick':0,'m':{},'unknown':True},
    {'verdict':'stall','tick':0,'unknown':True},
    {'verdict':'facing','tick':0,'m':[]}, {'verdict':'unknown','tick':0,'m':{}},
    {'verdict':'eligible','tick':0,'m':{}},
    {'verdict':'facing','tick':0,'m':{'fabricated':1}}]
  for verdict in cases:
   with self.subTest(verdict=verdict),self.assertRaises(K.Refused):
    K.style_snapshots([snapshot(0,verdict,{} if verdict.get('verdict')=='stall' else {verdict['verdict']:1})])

 def test_duplicate_and_stale_verdict_ticks_refuse(self):
  measures={name:1.0 for name in ('air_s','track_m','progress_m','rise_m','fall_m','heading_dot','landing_ups')}
  first={'verdict':'eligible','tick':0,'m':measures}
  second=copy.deepcopy(first);second['m']['track_m']=2.0
  for changed in (second,dict(verdict='facing',tick=0,m={})):
   rows=[snapshot(0,first,{'eligible':1}),snapshot(1,changed,{'eligible':2} if changed['verdict']=='eligible' else {'eligible':1,'facing':1})]
   with self.assertRaises(K.Refused):K.style_snapshots(rows)
  with self.assertRaises(K.Refused):K.style_snapshots([snapshot(1,first,{'eligible':1})])

 def test_nonfinite_and_boolean_measurements_refuse(self):
  measures={name:1.0 for name in ('air_s','track_m','progress_m','rise_m','fall_m','heading_dot','landing_ups')}
  for value in (True,float('nan'),float('inf'),'1'):
   bad=dict(measures,track_m=value)
   with self.subTest(value=value),self.assertRaises(K.Refused):
    K.style_snapshots([snapshot(0,{'verdict':'eligible','tick':0,'m':bad},{'eligible':1})])

 def test_actual_string_tick_mutation_refuses(self):
  rows=copy.deepcopy(ActualSnapshotContract.rows)
  target=next(row for row in rows if row['style_direction_verdict'].get('verdict')=='facing')
  tick=target['style_direction_verdict']['tick']
  target['style_direction_verdict']['tick']=str(tick)
  target['actual']['style']['diag']['direction']['last']['tick']=str(tick)
  with self.assertRaises(K.Refused):K.style_snapshots(rows)

if __name__=='__main__':unittest.main()
