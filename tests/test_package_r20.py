#!/usr/bin/env python3
"""R20 preparation/refusal tests; in-memory archives, no engine or candidate execution.

Generic negative cases retain tests/test_package_r19.py provenance at 065f7b279.
Synthetic identity mutations test the gates only, never runtime acceptance.
"""
import ast
import copy
import contextlib
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from types import SimpleNamespace
from unittest.mock import patch
import zipfile

sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[1]


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


pkg = module('r20_packaging_test', PROJECT / 'tools/package-r20.py')


def freeze(commit='a'*40):
    return {'schema': 1, 'runtime_frozen': True, 'source_commit': commit,
        'new_maps': list(pkg.NEW_MAPS), 'required_maps': list(pkg.REQUIRED_MAPS),
        'experimental_maps': list(pkg.EXPERIMENTAL_MAPS), 'reached_items': [1,2,3,4,5,6],
        'intentional_changes': {}, 'identity_sha256': 'b'*64}


def stack_stream_fixture(terminal='bank'):
    """synthetic transport fixture; no gameplay or eligibility claim."""
    pending = lambda hop, at: {'record_kind': 'direction', 'v': 1, 'kind': 'direction_pending',
        'reason': 'eligible', 'serial': hop, 'tick': at, 'time_s': (at + 1) / 128,
        'direction': 'backward_bhop', 'hops': hop, 'pending': 160 * hop * (hop - 1) // 2,
        'unit': 160, 'formula': 'unit*n*(n-1)/2', 'm': {'air_s': 0.75, 'track_m': 6., 'progress_m': 5.8, 'rise_m': 0.75, 'fall_m': 0.75, 'heading_dot': 1., 'landing_ups': 350.}}
    ordinary = {'tick': 0, 'v': 1, 'kind': 'speed', 'base': 80, 'points': 80,
        'mult': 1, 'direction_mult': 1, 'combo_mult': 1, 'm': {}, 'geo': {}, 'label': 'Speed'}
    at = 11 if terminal == 'quit' else 9
    end = pending(3, at)
    end.update(kind='direction_banked' if terminal == 'bank' else 'direction_lost',
        reason={'bank': 'facing', 'stall': 'stall', 'queued': 'settings', 'quit': 'quit'}[terminal],
        serial=4, tick=8 if terminal == 'queued' else at, m={})
    if terminal == 'queued':
        end['time_s'] = 9 / 128
    bank = {'v': 2, 'kind': 'backward_bhop_bank', 'tick': at, 'time_s': (at + 1) / 128,
        'elapsed': at / 128, 'points': 480, 'base': 480, 'mult': 1, 'direction_mult': 1,
        'combo_mult': 1, 'combo': 0, 'label': 'Backwards banked', 'm': {'direction': 'backward_bhop',
            'hops': 3, 'unit': 160, 'formula': 'unit*n*(n-1)/2', 'reason': 'facing',
            'start_tick': 1, 'last_hop_tick': 7, 'end_ups': 350.0000135166439}, 'geo': {}, 'p': [0., 2., 30.], 'clean': True}
    events, rows = [], []
    active = {'kind': '', 'hops': 0, 'pending': 0, 'unit': 0}
    last, verdict, score = {}, {}, 0
    def emit(kind, data, tick, source='capture'):
        events.append({'q': len(events), 'k': kind, 's': source, 't': tick, 'd': copy.deepcopy(data)})
    for tick in range(12):
        scored = []
        if tick == 0:
            scored.append(ordinary); emit('style', ordinary, tick); score += 80
        if tick in (1, 4, 7):
            d = pending((tick + 2) // 3, tick); emit('direction', d, tick)
            active = {'kind': d['direction'], 'hops': d['hops'], 'pending': d['pending'], 'unit': d['unit']}
            verdict = {'verdict': 'eligible', 'tick': tick, 'm': copy.deepcopy(d['m'])}
        if terminal != 'quit' and tick == at:
            if terminal == 'bank':
                scored.append(bank); emit('style', bank, tick); score += 480
            emit('direction', end, tick)
            active = {'kind': '', 'hops': 0, 'pending': 0, 'unit': 0}; last = end
        rows.append({'tick': tick, 'style_score': score, 'style_events': copy.deepcopy(scored),
            'style_time_s': (tick + 1) / 128, 'style_direction_verdict': copy.deepcopy(verdict), 'style_direction': dict(active, formula=pkg.DIRECTION_FORMULA,
                suspended=False, last=copy.deepcopy(last))})
        if terminal == 'queued' and tick == 8:
            emit('settings', {'key': 'fov', 'value': 90}, tick, 'event')
        if terminal == 'quit' and tick == at:
            emit('direction', end, tick, 'event'); emit('quit', {}, tick, 'event')
    by_kind = {'speed': {'n': 1, 'points': 80}}
    if terminal == 'bank':
        by_kind['backward_bhop_bank'] = {'n': 1, 'points': 480}
    rec = SimpleNamespace(events=events, columns={'actual_v_x': [0.] * 12,
        'actual_v_z': [350 * 0.0254] * 12}, seal={'outcome': {'style': {'score': score, 'by_kind': by_kind}}})
    if terminal == 'stall':
        rec.columns['actual_v_z'][9] = 0
    return rec, rows


def identity_fixture():
    old = pkg.baseline_identity()
    current = copy.deepcopy(old)
    current['main_script'] = pkg.MAIN_SCRIPT
    current['registry']['maps'] = list(pkg.REQUIRED_MAPS)
    for name in pkg.SHELVED:
        del current['maps'][name]
        del current['keys'][name]
    for name in pkg.NEW_MAPS:
        current['maps'][name] = dict(old['maps']['saltglass'], level_id='fixture-'+name, geometry='fixture-geometry-'+name)
        current['keys'][name] = copy.deepcopy(old['keys'].get(name, old['keys']['saltglass']))
        for key in current['keys'][name].values():
            key['course_key'] = 'fixture-'+name+'-'+key['preset']
            record = json.loads(key['record_identity'])
            record[1][0], record[2] = name, 'fixture-geometry-'+name
            key['record_identity'] = json.dumps(record)
    return old, current


def seal(fr, identity):
    fr['identity_sha256'] = hashlib.sha256(pkg.canonical(identity)).hexdigest()


class ReleaseGates(unittest.TestCase):
    def refused(self, fn, *args):
        with self.assertRaises(pkg.Rejected):
            fn(*args)

    def test_release_routes_retain_breakwater_and_add_earned_saltglass(self):
        with patch.object(pkg.r18,'route_freeze',return_value=[{'route':'original-breakwater'}]) as original, \
             patch.object(pkg,'saltglass_route_freeze',return_value={'route':'earned-saltglass'}) as surf, \
             patch.object(pkg,'tether_feature_freeze',return_value={'tether':{'classic':'reader-derived'}}) as tether, \
             patch.object(pkg,'through_feature_freeze',return_value={'through':{'fast':'reader-derived'}}) as through:
            self.assertEqual(pkg.route_freeze('source','evidence','identity'),
                             [{'route':'original-breakwater','feature_tapes':{'tether':{'classic':'reader-derived'},'through':{'fast':'reader-derived'}}},
                              {'route':'earned-saltglass','feature_tapes':{'tether':{'classic':'reader-derived'},'through':{'fast':'reader-derived'}}}])
            original.assert_called_once_with('source','evidence','identity')
            surf.assert_called_once_with('source','evidence','identity')
            tether.assert_called_once_with('source','evidence','identity')
            through.assert_called_once_with('source','evidence','identity')

    def test_generator_closing_releases_are_executed_without_dropping_any_edge(self):
        plan = {'duration_ticks':2,'physics_hz':128,'events':[
            {'tick':0,'key':'w','edge':'press'}, {'tick':2,'key':'w','edge':'release'}]}
        original = copy.deepcopy(plan)
        result = pkg.include_cleanup_tick(plan)
        self.assertEqual(result['duration_ticks'],3)
        self.assertEqual(result['events'],plan['events'])
        self.assertEqual(original,plan)
        for tail in [{'tick':2,'key':'w','edge':'press'}, {'tick':2,'mouse':[1,0]},
                     {'tick':3,'key':'w','edge':'release'}]:
            bad=copy.deepcopy(plan); bad['events'][-1]=tail
            self.refused(pkg.include_cleanup_tick,bad)
        inside=copy.deepcopy(plan);inside['events'][-1]['tick']=1
        self.assertEqual(pkg.include_cleanup_tick(inside),inside)

    def test_raw_mouse_buttons_keep_press_release_double_click_and_factor(self):
        left = {'type':'mouse_button', 'button_index':1, 'pressed':True, 'double_click':False, 'factor':1.}
        right = dict(left, button_index=2)
        self.assertEqual(pkg.raw_motion_input(left), (2,1,0,1,1.,0.,0.,0.))
        self.assertEqual(pkg.raw_motion_input(dict(left, pressed=False)), (2,1,0,0,1.,0.,0.,0.))
        self.assertEqual(pkg.raw_motion_input(dict(right, double_click=True)), (2,2,0,5,1.,0.,0.,0.))
        wheel = dict(left, button_index=4, factor=.3)
        self.assertEqual(pkg.raw_motion_input(wheel), (2,4,0,1,0.30000001192092896,0.,0.,0.))
        held = [pkg.raw_motion_input(row) for row in [left,right,dict(left,pressed=False),dict(right,pressed=False)]]
        for mutation in [held[:-1],list(reversed(held)),held[:1]+held[2:], [held[1],held[0],*held[2:]]]:
            self.assertNotEqual(mutation, held)
        key = {'type':'key','keycode':87,'physical_keycode':87,'pressed':True,'echo':False}
        self.assertEqual(pkg.raw_motion_input(key),(1,87,87,1,0.,0.,0.,0.))
        self.assertIsNone(pkg.raw_motion_input(dict(key,keycode=4194305,physical_keycode=4194305)))
        self.assertEqual(pkg.raw_motion_input({'type':'mouse_motion','screen_relative':[.3,0.], 'relative':[.2,-.3]}),
                         (3,0,0,0,0.30000001192092896,0.,0.20000000298023224,-0.30000001192092896))

    def test_freeze_is_explicit_and_malformed_values_refuse(self):
        good = freeze()
        self.assertEqual(pkg.validate_freeze(good, 'a'*40), good)
        self.refused(pkg.validate_freeze, good, 'c'*40)
        self.refused(pkg.validate_freeze, {}, 'a'*40)
        for key in good:
            bad = freeze(); del bad[key]
            self.refused(pkg.validate_freeze, bad, 'a'*40)
        for key, value in [('schema',True), ('schema',2), ('runtime_frozen',False),
                           ('source_commit','a'*8), ('identity_sha256','stale'),
                           ('intentional_changes', {'project.godot':'short'}),
                           ('intentional_changes', {'scripts/r19_main.gd':'b'*64}),
                           ('reached_items',[]), ('reached_items',[1,3]), ('reached_items',[1,1]),
                           ('reached_items',[True]), ('reached_items',[1,2,3,4,5,6,7])]:
            bad = freeze(); bad[key] = value
            self.refused(pkg.validate_freeze, bad, 'a'*40)
        prefix = freeze(); prefix['reached_items'] = [1,2]
        pkg.validate_freeze(prefix, 'a'*40)
        self.refused(pkg.integration_ready, prefix)

    def test_final_eleven_and_two_new_experiments_cannot_be_discovered_away(self):
        for field in ['new_maps', 'required_maps', 'experimental_maps']:
            original = freeze()[field]
            for value in [None, {}, original[:-1], original+[original[-1]],
                          original+['line-drive'], original+['fall-line'], list(reversed(original))]:
                bad = freeze(); bad[field] = value
                self.refused(pkg.validate_freeze, bad, 'a'*40)
        bad = freeze(); bad['experimental_maps'] = ['tether-yard','through-line']
        self.refused(pkg.validate_freeze, bad, 'a'*40)
        for name in ['breakwater_geometry', 'breakwater_overlay']:
            bad = freeze(); bad[name] = 'b'*64
            self.refused(pkg.validate_freeze, bad, 'a'*40)

    def test_all_1309_old_paths_independently_protected(self):
        tracked = pkg.pinned_json(pkg.TRACKED, pkg.TRACKED_SHA)
        before = {name: entry['sha256'] for name, entry in tracked['files'].items()}
        self.assertEqual(len(before), 1309)
        self.assertEqual(pkg.preserved_changes(before, before, {}), {})
        parent = module('r20_parent_preservation', PROJECT/'tools/check-r20-preservation.py')
        self.assertEqual(pkg.OLD_CHANGES, parent.ALLOWED)
        self.assertEqual(pkg.BASE, parent.BASELINE)
        for path in before:
            after = dict(before); after[path] = 'c'*64
            if path in pkg.OLD_CHANGES:
                pkg.preserved_changes(before, after, {path:'c'*64})
                self.refused(pkg.preserved_changes, before, after, {})
                self.refused(pkg.preserved_changes, before, after, {path:'d'*64})
                self.assertTrue(parent.compare(before, after, {path:'c'*64})['ok'])
            else:
                self.refused(pkg.preserved_changes, before, after, {path:'c'*64})
                self.assertFalse(parent.compare(before, after, {path:'c'*64})['ok'])
            after = dict(before); del after[path]
            self.refused(pkg.preserved_changes, before, after, {})

    def test_exact_r19_git_baseline_and_six_F2_pins(self):
        top = Path(pkg.r16.git('rev-parse','--show-toplevel').strip())
        before = pkg.committed_manifest(pkg.BASE, 'projects/foldrunner', top)
        result = pkg.preservation(pkg.BASE, 'projects/foldrunner', {})
        self.assertEqual(result['old_files'], 1309)
        self.assertEqual(result['SOURCE_generated_imports_not_tracked'], 214)
        self.assertEqual(result['F2_pins'], {p:before[p] for p in pkg.F2_PATHS})
        for path in pkg.F2_PATHS:
            bad = dict(before); bad[path] = 'c'*64
            with patch.object(pkg,'committed_manifest',side_effect=[before,bad]):
                self.refused(pkg.preservation, 'a'*40, 'projects/foldrunner', {})
        source = pkg.pinned_json(pkg.BASELINE,pkg.BASELINE_SHA)
        bad = copy.deepcopy(source); bad['files'][pkg.F2_PATHS[0]] = 'c'*64
        with patch.object(pkg,'pinned_json',side_effect=[bad,pkg.pinned_json(pkg.TRACKED,pkg.TRACKED_SHA)]):
            self.refused(pkg.preservation, pkg.BASE, 'projects/foldrunner', {})

    def test_identity_all_original_maps_and_presets_are_exact_no_breakwater_exception(self):
        old, identity = identity_fixture(); fr = freeze(); seal(fr, identity)
        pkg.identity_boundary(identity,fr,old)
        for map_id in pkg.ORIGINAL_MAPS:
            for field in ['geometry','stages','art']:
                bad = copy.deepcopy(identity); bad['maps'][map_id][field] = 'changed'
                seal(fr,bad); self.refused(pkg.identity_boundary,bad,fr,old)
            for preset in old['keys'][map_id]:
                for field in ['physics_hz','fingerprint','record_identity','course_key','hull','mechanics','runner','family_version']:
                    bad = copy.deepcopy(identity); bad['keys'][map_id][preset][field] = 'changed'
                    seal(fr,bad); self.refused(pkg.identity_boundary,bad,fr,old)

    def test_identity_hash_catalog_alias_F2_and_physical_drift_refuse(self):
        old, identity = identity_fixture(); fr = freeze(); seal(fr,identity)
        bad = copy.deepcopy(identity); bad['keys']['saltglass'] = copy.deepcopy(old['keys']['saltglass'])
        seal(fr,bad); self.refused(pkg.identity_boundary,bad,fr,old)
        for map_id in ['saltglass','tether-yard']:
            for preset in identity['keys'][map_id]:
                for field in ['course_key','record_identity']:
                    bad = copy.deepcopy(identity)
                    bad['keys'][map_id][preset][field] = old['keys'][map_id][preset][field]
                    seal(fr,bad); self.refused(pkg.identity_boundary,bad,fr,old)
        for field in ['physics_hz','engine_hz','fingerprint','hull','preset','clean','pending']:
            bad = copy.deepcopy(identity); bad['keys']['through-line']['server128'][field] = 'wrong'
            seal(fr,bad); self.refused(pkg.identity_boundary,bad,fr,old)
        for mutator in [lambda i:i['keys']['through-line'].pop('server128'),
                        lambda i:i['maps'].update({'through-line':i['maps']['breakwater']}),
                        lambda i:i['registry']['maps'].append('line-drive'),
                        lambda i:i['registry']['maps'].append('fall-line'),
                        lambda i:i['registry']['presets']['server128'].update(rate=120)]:
            bad = copy.deepcopy(identity); mutator(bad); seal(fr,bad)
            self.refused(pkg.identity_boundary,bad,fr,old)
        fr['identity_sha256'] = '0'*64
        self.refused(pkg.identity_boundary,identity,fr,old)

    def test_dirty_or_untracked_source_refuses_before_any_export(self):
        for status in [' M project.godot', '?? scripts/uncommitted.gd', 'A  scenes/r20.tscn']:
            with patch.object(pkg.r16,'git',return_value=status), patch.object(pkg.r16,'checked') as engine:
                self.refused(pkg.clean_source)
                engine.assert_not_called()

    def test_pending_features_prevent_assembly_even_with_complete_parent_freeze(self):
        with tempfile.TemporaryDirectory(dir=pkg.SCRATCH) as td:
            path = Path(td)/'freeze.json'; path.write_text(json.dumps(freeze()))
            args = SimpleNamespace(freeze=path)
            with patch.object(pkg.r16,'git',side_effect=['a'*40,'']), patch.object(pkg.r16,'checked') as engine, patch.object(pkg,'frozen_source') as archive:
                self.refused(pkg.package,args)
                archive.assert_not_called(); engine.assert_not_called()
        self.refused(pkg.integration_ready,freeze())
        self.assertEqual(pkg.PENDING_FEATURES, ('saltglass-route','directional-stack','tether-controls','through-line','export-my-runs'))

    def test_imports_do_not_mutate_old_release_modules(self):
        old = module('r20_test_original_r19', PROJECT/'tools/package-r19.py')
        before = (old.BUILD, old.MAIN, old.r18.BUILD, old.r16.NAME, old.r16.PROBE, dict(old.r16.EXPECT))
        new = module('r20_test_separate_instance', PROJECT/'tools/package-r20.py')
        self.assertIsNot(new.r18,old.r18); self.assertIsNot(new.r16,old.r16)
        self.assertEqual(before,(old.BUILD,old.MAIN,old.r18.BUILD,old.r16.NAME,old.r16.PROBE,dict(old.r16.EXPECT)))
        self.assertEqual(new.r16.TEMPLATE_MEMBERS, old.r16.TEMPLATE_MEMBERS)
        self.assertEqual(new.r16.EDITOR_SHA256, old.r16.EDITOR_SHA256)

    def test_original_audit_and_legacy_strict_style_have_not_been_weakened(self):
        def normalized(path, name):
            source = path.read_text()
            if name == 'audit_profile' and path.name == 'package-r19.py':
                source = source.replace("if not engine['ok'] or not json_numbers_match(engine['seal'], rec.seal)", "if not engine['ok'] or not json_numbers_match(engine['header'], rec.header) or not json_numbers_match(engine['seal'], rec.seal)")
                # the only input extension moves canonicalization into the tested helper and
                # admits button rows to the existing exact order/tick/boundary comparison.
                start = source.index('            codes_set = {87,')
                stop = source.index('            wanted_inputs = ', start)
                source = source[:start] + source[stop:]
                source = source.replace("canonical(delivery['data'])", "raw_motion_input(delivery['data'])")
                source = source.replace("canonical(v) for v in boundary.get('inputs', [])", "raw_motion_input(v) for v in boundary.get('inputs', [])")
                source = source.replace("rec.inputs['kind'][j] == 3 or (rec.inputs['kind'][j] == 1 and (rec.inputs['aux'][j] or rec.inputs['code'][j]) in codes_set)",
                                        "rec.inputs['kind'][j] in (2, 3) or (rec.inputs['kind'][j] == 1 and (rec.inputs['aux'][j] or rec.inputs['code'][j]) in MOTION_KEYS)")
                # scored totals and the new non-scored stream move together into a
                # separately mutation-tested auditor; every other old check stays exact.
                start = source.index("            styled = [e for e in rec.events if e.get('s') == 'capture']")
                stop = source.index("            if outcome.get('kind') == 'finish':", start)
                source = source[:start] + '            total, by_kind = audit_style_stream(rec, rows)\n' + source[stop:]
            tree = ast.parse(source)
            actual_name = 'strict_legacy_style' if name == 'strict_style' and path.name == 'package-r20.py' else name
            node = next(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name==actual_name)
            node.name = name
            for item in ast.walk(node):
                if isinstance(item,ast.Constant) and isinstance(item.value,str):
                    item.value=item.value.replace('R20','R19')
            return ast.dump(node,include_attributes=False)
        for name in ['audit_profile','strict_style','friend_profile_audit']:
            self.assertEqual(normalized(PROJECT/'tools/package-r19.py',name),normalized(PROJECT/'tools/package-r20.py',name),name)

    def test_prepare_reads_real_git_without_archiving_or_starting_engine(self):
        with patch.object(pkg.r16,'source_archive') as archive, patch.object(pkg.r16,'checked') as engine, patch.object(pkg.subprocess,'check_output') as command, patch.object(pkg.r16.nd,'NativeDisplay') as display:
            facts = pkg.preflight()
            self.assertEqual(facts['preservation']['old_files'],1309)
            self.assertFalse(facts['runtime_checked'])
            self.assertEqual(facts['pending'],list(pkg.PENDING_FEATURES))
            archive.assert_not_called(); engine.assert_not_called(); command.assert_not_called(); display.assert_not_called()

    def test_missing_or_malformed_freeze_cli_has_no_engine_or_output_effect(self):
        with tempfile.TemporaryDirectory(dir=pkg.SCRATCH) as td:
            root = Path(td); output = root/'never-created'
            for content in [None, '{broken json', '[]', '{}']:
                path = root/'freeze.json'
                if content is not None:
                    path.write_text(content)
                with patch.object(pkg.r16,'checked') as engine, patch.object(pkg,'frozen_source') as archive, contextlib.redirect_stderr(io.StringIO()):
                    code = pkg.main(['package','--freeze',str(path),'--output',str(output)])
                    self.assertEqual(code,1)
                    self.assertFalse(output.exists())
                    archive.assert_not_called(); engine.assert_not_called()

    def test_only_new_r20_delivery_can_be_output(self):
        with tempfile.TemporaryDirectory(dir=pkg.SCRATCH) as td, patch.object(pkg,'OUTER',Path(td)):
            top = Path(td)/'source'; top.mkdir()
            new = Path(td)/'delivery/spillway-r20'
            self.assertEqual(pkg.output_ok(new,top)[0],new)
            for out in [Path(td)/'delivery/spillway-r19',top/'out',Path(td)/'other']:
                self.refused(pkg.output_ok,out,top)
            new.mkdir(parents=True); (new/'keep').write_text('previous')
            self.refused(pkg.output_ok,new,top)

    def test_nested_project_inventory_covers_committed_resources(self):
            with tempfile.TemporaryDirectory(dir=pkg.SCRATCH) as td:
                root = Path(td)
                project = root / 'projects/foldrunner'
                expected = ['assets/sky.png', 'project.godot', 'scenes/r20.tscn']
                for name in expected:
                    path = project / name
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_text('fixture')
                (root / 'unrelated.txt').write_text('not a game resource')
                subprocess.run(['git', 'init', '-q', root], check=True)
                subprocess.run(['git', '-C', root, 'add', '.'], check=True)
                subprocess.run(['git', '-C', root, '-c', 'user.name=fixture', '-c',
                    'user.email=fixture@example.invalid', 'commit', '-qm', 'fixture'], check=True)
                self.assertEqual(pkg.project_files('HEAD', 'projects/foldrunner', root), expected)
                # a nested cwd must never silently filter the subtree inventory to zero.
                self.assertEqual(pkg.r16.git('ls-tree', '-r', '--name-only', 'HEAD:./', cwd=project).splitlines(), [])
                self.refused(pkg.project_files, 'HEAD', '', root)

    def test_floor_and_output_reserve_are_both_required(self):
            Usage = shutil._ntuple_diskusage
            with patch.object(pkg.shutil,'disk_usage',return_value=Usage(50_000_000_000,0,pkg.FLOOR+99)):
                self.assertEqual(pkg.space(99),pkg.FLOOR+99)
                self.refused(pkg.space,100)
            self.refused(pkg.space,-1)
            with tempfile.TemporaryDirectory(dir=pkg.SCRATCH) as td:
                with patch.object(pkg.shutil,'disk_usage',side_effect=[Usage(50_000_000_000,0,pkg.FLOOR+10),Usage(1_000_000_000,0,pkg.PREP_LIMIT-1)]):
                    self.refused(pkg.space,0,Path(td))
            self.refused(pkg.space,0,Path('/tmp/wrong-r20-scratch'))

    def test_scratch_bound_counts_actual_file_bytes(self):
            with tempfile.TemporaryDirectory(dir=pkg.SCRATCH) as td:
                p=Path(td);(p/'sample').write_bytes(b'12345')
                self.assertEqual(pkg.bounded(p,5),5)
                self.refused(pkg.bounded,p,4)

    def test_catalog_requires_every_declared_map_and_distinct_identity(self):
            maps=list(pkg.ORIGINAL_MAPS)+['surf']
            identity={'registry':{'maps':maps},'maps':{m:{'level_id':m,'geometry':m+'-geo'} for m in maps},'keys':{m:{'server128':{}} for m in maps}}
            pkg.catalog(identity,maps)
            bad=copy.deepcopy(identity);bad['registry']['maps'].remove('surf');bad['maps'].pop('surf');bad['keys'].pop('surf')
            self.refused(pkg.catalog,bad,maps)
            bad=copy.deepcopy(identity);bad['maps']['surf']=bad['maps']['breakwater']
            self.refused(pkg.catalog,bad,maps)
            bad=copy.deepcopy(identity);bad['keys']['surf']={}
            self.refused(pkg.catalog,bad,maps)

    def test_rejects_changed_reference_bytes(self):
            with tempfile.TemporaryDirectory(dir=pkg.SCRATCH) as td:
                path=Path(td)/'reference.json';path.write_text('{}')
                self.refused(pkg.pinned_json,path,'0'*64)

    def test_zip_entries_modes_and_crc(self):
            def archive(entries):
                stream=io.BytesIO()
                with zipfile.ZipFile(stream,'w',compression=zipfile.ZIP_STORED) as z:
                    for name,mode,data in entries:
                        info=zipfile.ZipInfo(name);info.external_attr=mode<<16;z.writestr(info,data)
                return stream.getvalue()
            good=archive([('release/game',0o100755,b'ELF-fixture')])
            with zipfile.ZipFile(io.BytesIO(good)) as z:
                pkg.validate_archive(z,['release/game'],'release/game')
            for entries in [[('../game',0o100755,b'x')],[('release/game',0o120777,b'target')],[('release/game',0o104755,b'x')],[('release/game',0o100644,b'x')],[('release/game',0o100755,b'x'),('release/private.png',0o100644,b'private concept')]]:
                with zipfile.ZipFile(io.BytesIO(archive(entries))) as z:
                    self.refused(pkg.validate_archive,z,['release/game'],'release/game')
            corrupt=good.replace(b'ELF-fixture',b'BAD-fixture',1)
            with zipfile.ZipFile(io.BytesIO(corrupt)) as z:
                self.refused(pkg.validate_archive,z,['release/game'],'release/game')

    def test_missing_and_malformed_and_critical_sky_both_looks_refuse(self):
            with tempfile.TemporaryDirectory(dir=pkg.SCRATCH) as td:
                root=Path(td);folder=root/'folder';folder.mkdir();work=root/'work';work.mkdir()
                (folder/(pkg.NAME+'.x86_64')).write_bytes(b'private executable fixture')
                (folder/(pkg.NAME+'.pck')).write_bytes(b'whiteout-sky.png original pack')
                seen=[]
                def refuse(case,out,extra):
                    out.mkdir(parents=True);seen.append(extra)
                    return 3,'failed fixture'
                with patch.object(pkg.r18,'normal_start',side_effect=refuse):
                    results=pkg.pack_negatives(folder,work,root/'evidence')
                self.assertEqual(len(results),4);self.assertTrue(all(r['refused'] for r in results))
                self.assertIn('--look=old',seen[-1])
                self.assertEqual((folder/(pkg.NAME+'.pck')).read_bytes(),b'whiteout-sky.png original pack')
                def accepts(case,out,extra):
                    out.mkdir(parents=True)
                    return 0,'logged error but accepted'
                with patch.object(pkg.r18,'normal_start',side_effect=accepts):
                    self.refused(pkg.pack_negatives,folder,work,root/'bad-evidence')

    def test_new_direction_style_schema_keeps_totals_bounded(self):
            value={'tick':1,'v':1,'kind':'backward_bhop','base':80,'points':960,'mult':12,'direction_mult':4,'combo_mult':3,'m':{},'geo':{},'label':'Backwards'}
            pkg.strict_legacy_style(value,1)
            self.refused(pkg.strict_style,value,1)
            for key,bad_value in [('kind','unknown'),('points',9610),('mult',float('nan')),('direction_mult',5),('combo_mult',4),('tick',2)]:
                bad=dict(value);bad[key]=bad_value
                self.refused(pkg.strict_legacy_style,bad,1)

    def test_stack_bank_can_exceed_legacy_ceiling_without_combo_amplification(self):
        value = {'v': 2, 'kind': 'backward_bhop_bank', 'tick': 1300, 'time_s': 10.15625,
            'elapsed': 10.15625, 'points': 30400, 'base': 30400, 'mult': 1.,
            'direction_mult': 1., 'combo_mult': 1., 'combo': 0, 'label': 'Backwards banked',
            'm': {'direction': 'backward_bhop', 'hops': 20, 'unit': 160,
                'formula': 'unit*n*(n-1)/2', 'reason': 'facing', 'start_tick': 50,
                'last_hop_tick': 1290, 'end_ups': 350.}, 'geo': {}, 'p': [0., 2., 30.], 'clean': True}
        pkg.strict_stack_style(value, 1300)
        self.refused(pkg.strict_legacy_style, value, 1300)
        pkg.strict_style(value, 1300)
        for key, wrong in [('points', 30401), ('base', 30401), ('mult', 2), ('combo_mult', 2),
                ('direction_mult', 2), ('combo', 1), ('tick', 1301), ('v', True),
                ('clean', 1), ('p', [0., float('nan'), 30.]), ('record_kind', 'direction'), ('label', 'Speed')]:
            bad = copy.deepcopy(value); bad[key] = wrong
            self.refused(pkg.strict_stack_style, bad, 1300)
        for key, wrong in [('hops', 19), ('hops', True), ('unit', 50), ('formula', 'unit*n'),
                ('direction', 'sideways_bhop'), ('start_tick', 1291), ('last_hop_tick', 1301),
                ('end_ups', 299.999), ('end_ups', float('inf')), ('reason', 'quit')]:
            bad = copy.deepcopy(value); bad['m'][key] = wrong
            self.refused(pkg.strict_stack_style, bad, 1300)
        side = copy.deepcopy(value)
        side.update(kind='sideways_bhop_bank', points=9500, base=9500, label='Half-sideways banked')
        side['m'].update(direction='sideways_bhop', unit=50)
        pkg.strict_stack_style(side, 1300)

    def test_pending_and_lost_diagnostics_never_carry_scored_points(self):
        value = {'record_kind': 'direction', 'v': 1, 'kind': 'direction_pending',
            'reason': 'eligible', 'serial': 20, 'tick': 1290, 'time_s': 10.078125,
            'direction': 'backward_bhop', 'hops': 20, 'pending': 30400, 'unit': 160,
            'formula': 'unit*n*(n-1)/2', 'm': {'air_s': 0.75, 'track_m': 6., 'progress_m': 5.8, 'rise_m': 0.75, 'fall_m': 0.75, 'heading_dot': 1., 'landing_ups': 350.}}
        pkg.strict_direction(value, 1290)
        for key, wrong in [('pending', 30401), ('hops', 19), ('unit', 50), ('tick', 1291),
                ('v', True), ('serial', 0), ('serial', True), ('time_s', float('nan')),
                ('reason', 'quit'), ('points', 30400), ('base', 30400), ('mult', 1)]:
            bad = copy.deepcopy(value); bad[key] = wrong
            self.refused(pkg.strict_direction, bad, 1290)
        for kind, reason in [('direction_banked', 'facing'), ('direction_lost', 'stall'),
                ('direction_lost', 'quit'), ('direction_lost', 'settings')]:
            terminal = dict(value, kind=kind, reason=reason, serial=21, m={})
            pkg.strict_direction(terminal, 1290)
        for reason in ['pause', 'resume']:
            self.refused(pkg.strict_direction, dict(value, kind='direction_lost', reason=reason, m={}), 1290)
        self.refused(pkg.strict_direction, dict(value, kind='direction_banked', reason='quit', m={}), 1290)
        armed = dict(value, serial=1, hops=1, pending=0)
        pkg.strict_direction(armed, 1290)

    def test_scored_and_non_scored_streams_match_independent_pending_and_score(self):
        for terminal in ['bank', 'stall', 'queued', 'quit']:
            rec, rows = stack_stream_fixture(terminal)
            total, by_kind = pkg.audit_style_stream(rec, rows)
            self.assertEqual(total, 560 if terminal == 'bank' else 80)
            self.assertEqual(by_kind, rec.seal['outcome']['style']['by_kind'])
        rec, rows = stack_stream_fixture('bank')
        rows[0]['style_direction'].update(kind='backward_bhop', unit=160)
        rows[10]['style_direction'].update(kind='sideways_bhop', unit=50)
        pkg.audit_style_stream(rec, rows)
        for mutation in [
            lambda r,s: r.events[1]['d'].update(points=0),
            lambda r,s: r.events[2]['d'].update(serial=1),
            lambda r,s: r.events[2]['d'].update(tick=5),
            lambda r,s: r.events[2]['d'].update(time_s=100),
            lambda r,s: r.events[4]['d'].update(points=481),
            lambda r,s: r.events[4]['d']['m'].update(start_tick=2),
            lambda r,s: r.events[4]['d']['m'].update(end_ups=351),
            lambda r,s: r.events[5]['d'].update(kind='direction_lost', reason='stall'),
            lambda r,s: r.events[4].update(s='event'),
            lambda r,s: r.events[1].update(k='unknown'),
            lambda r,s: s[4]['style_direction'].update(pending=0),
            lambda r,s: s[4]['style_direction_verdict']['m'].update(heading_dot=0.6),
            lambda r,s: r.events[0].update(t=-1),
            lambda r,s: s[9]['style_direction'].update(last={}),
            lambda r,s: s[9].update(style_score=80),
            lambda r,s: s[9].update(style_events=[]),
            lambda r,s: r.seal['outcome']['style'].update(score=80),
            lambda r,s: r.seal['outcome']['style']['by_kind'].update(backward_bhop_bank={'n': 2, 'points': 480}),
            lambda r,s: r.columns['actual_v_z'].__setitem__(9, 299 * 0.0254),
        ]:
            bad, observed = copy.deepcopy(rec), copy.deepcopy(rows)
            mutation(bad, observed)
            self.refused(pkg.audit_style_stream, bad, observed)
        for terminal in ['queued', 'quit']:
            rec, rows = stack_stream_fixture(terminal)
            if terminal == 'queued':
                rec.events[-1]['d']['tick'] = 10
            else:
                rec.events[-1]['k'] = 'pause'
            self.refused(pkg.audit_style_stream, rec, rows)

    def test_bank_speed_uses_the_pinned_float32_vector_magnitude(self):
        self.assertEqual(pkg.source_horizontal_ups(5., 12.), 13. / 0.0254)

    def test_tether_stack_loss_requires_its_actual_typed_loadout_boundary(self):
        rec, rows = stack_stream_fixture('quit')
        rec.header = {'metadata': {'map': 'tether-yard'}}
        rec.events[-2]['d']['reason'] = 'tether_settings'
        rec.events[-1].update(k='loadout', d={'key':'tether_auto_reel','from':False,'to':True})
        pkg.audit_style_stream(rec, rows)
        model = copy.deepcopy(rec)
        model.events[-1]['d'] = {'key':'tether_model','from':'classic','to':'elastic'}
        pkg.audit_style_stream(model, rows)
        for mutation in [
            lambda r: r.header['metadata'].update(map='breakwater'),
            lambda r: r.events[-1].update(k='tether_settings'),
            lambda r: r.events[-1].update(s='capture'),
            lambda r: r.events[-1].update(t=10),
            lambda r: r.events[-1]['d'].update(key='volume'),
            lambda r: r.events[-1]['d'].update(to=False),
            lambda r: r.events[-1]['d'].update(to=1),
            lambda r: r.events[-1]['d'].update(key='tether_model', **{'from':'classic','to':'zip'}),
        ]:
            bad = copy.deepcopy(rec)
            mutation(bad)
            self.refused(pkg.audit_style_stream, bad, rows)

    def test_controls_config_permission_keeps_startup_and_reload_readonly(self):
        for mode, allowed in [('controls',True),('play',True),('startup',False),('reload',False),('identity',False),('unknown',False)]:
            self.assertEqual(pkg.profile_config_allowed(mode), allowed)
            with patch.object(pkg,'audit_profile',return_value={'ok':True}) as audit:
                pkg.run_export_profile_audit(Path('/tmp/profile'), {}, {}, {}, {}, pkg.profile_config_allowed(mode), Path('/tmp/unused-export-evidence'), Path('/tmp/unused-export-work'))
                self.assertIs(audit.call_args.args[-1], allowed)
        tree = ast.parse((PROJECT/'tools/package-r20.py').read_text())
        native = next(node for node in tree.body if isinstance(node,ast.FunctionDef) and node.name == 'native_checks')
        calls = [node for node in ast.walk(native) if isinstance(node,ast.Call) and isinstance(node.func,ast.Name) and node.func.id == 'run_export_profile_audit']
        self.assertEqual(len(calls),1)
        self.assertEqual(ast.dump(calls[0].args[5]), ast.dump(ast.parse('profile_config_allowed(mode)', mode='eval').body))
        self.assertEqual(pkg.source_horizontal_ups(0., 8.89), 350.0000135166439)
        self.assertNotEqual(pkg.source_horizontal_ups(0., 8.89), 350.)

    def test_native_default_preserves_unavailable_desktop_refusal(self):
            # the real guard is used unchanged; no display server is launched.
            module=sys.modules[pkg.DesktopGuard.__module__]
            snapshot={'sockets':{},'servers':{},'listeners':[],'answering':False}
            with tempfile.TemporaryDirectory(dir=pkg.SCRATCH) as td, patch.object(module,'desktop_snapshot',return_value=snapshot):
                with self.assertRaises(RuntimeError):
                    with pkg.DesktopGuard(Path(td)/'default'):
                        self.fail('unavailable desktop silently accepted')
                with pkg.DesktopGuard(Path(td)/'explicit',allow_unavailable=True) as guard:
                    self.assertIsNone(guard.desktop)

    def test_friend_receipts_allow_unchanged_preferences_but_no_arbitrary_paths(self):
            with tempfile.TemporaryDirectory(dir=pkg.SCRATCH) as td:
                profile=Path(td);root=pkg.r16.profile_root(profile)
                prefs=root/'r19_ghost_share/selection.json';prefs.parent.mkdir(parents=True)
                prefs.write_text(json.dumps({'player':'Release probe','selected':''}))
                name='Spillway/r19_ghost_share/selection.json';files={name:pkg.digest(prefs)}
                with patch.object(pkg,'audit_profile',return_value={'ok':True}):
                    result=pkg.friend_profile_audit(profile,files,files,{'friend_profile_files':files},{},True)
                    self.assertTrue(result['ok'])
                self.refused(pkg.friend_profile_audit,profile,{},files,{'friend_profile_files':{'Spillway/unknown':'x'}},{},True)
                prefs.write_text(json.dumps({'player':'wrong','selected':''}));bad={name:pkg.digest(prefs)}
                self.refused(pkg.friend_profile_audit,profile,{},bad,{'friend_profile_files':bad},{},True)

    def test_windows_scope_is_explicit_in_release_notes(self):
            text=pkg.readme('windows-x86_64',{'commit':'a'*40},{},['launch'],'userdata','\n')
            for phrase in ['Native Windows execution is unverified','ghosts/ next to','R16 build identifier','F9','L compares']:
                self.assertIn(phrase,text)

    def test_windows_readme_manual_all_runs_and_separate_ghosts(self):
        text = pkg.readme('windows-x86_64',{'commit':'a'*40},{},['launch'],'userdata','\n')
        for phrase in ['%APPDATA%\\Godot\\app_userdata\\Spillway\\r16_runs\\',
                       'Export my runs', 'manually', 'ghosts are separate', 'settings', 'left mouse', 'right mouse']:
            self.assertIn(phrase,text)


if __name__ == '__main__':
    pkg.SCRATCH.mkdir(exist_ok=True)
    unittest.main(verbosity=2)
