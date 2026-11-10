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
            tree = ast.parse(source)
            node = next(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name==name)
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
            pkg.strict_style(value,1)
            for key,bad_value in [('kind','unknown'),('points',9610),('mult',float('nan')),('direction_mult',5),('combo_mult',4),('tick',2)]:
                bad=dict(value);bad[key]=bad_value
                self.refused(pkg.strict_style,bad,1)

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
