#!/usr/bin/env python3
"""small fixture tests of release refusal gates; no exports, ZIP files or runtime edits."""
import copy
import importlib.util
import io
import json
from pathlib import Path
import shutil
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('r19_packaging_test', PROJECT / 'tools/package-r19.py')
pkg = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pkg)


def freeze():
    return {'schema':1, 'runtime_frozen':True, 'source_commit':'a'*40, 'new_maps':[],
        'required_maps':list(pkg.ORIGINAL_MAPS), 'experimental_maps':['experiment'], 'identity_sha256':'b'*64, 'intentional_changes':{},
        'breakwater_geometry':'c'*64, 'breakwater_overlay':'r19-breakwater-flow-1:'+'d'*64}


class ReleaseGates(unittest.TestCase):
    def refused(self, fn, *args):
        with self.assertRaises(pkg.Rejected):
            fn(*args)

    def test_freeze_requires_explicit_parent_commit(self):
        self.refused(pkg.validate_freeze, {}, 'a'*40)
        for key, value in [('runtime_frozen',False),('schema',2),('source_commit','a'*8),('identity_sha256','')]:
            bad = freeze(); bad[key] = value
            self.refused(pkg.validate_freeze,bad,'a'*40)
        self.assertEqual(pkg.validate_freeze(freeze(),'a'*40),freeze())
        self.refused(pkg.validate_freeze,freeze(),'e'*40)

    def test_explicit_new_map_requirements_cannot_be_discovered_away(self):
        good = freeze(); good['new_maps'] = ['surf', 'grapple']; good['required_maps'] += good['new_maps']
        self.assertEqual(pkg.validate_freeze(good,'a'*40),good)
        bad = copy.deepcopy(good); bad['required_maps'].remove('surf')
        self.refused(pkg.validate_freeze,bad,'a'*40)
        for value in [['surf','surf'], ['breakwater'], None]:
            bad=freeze();bad['new_maps']=value
            self.refused(pkg.validate_freeze,bad,'a'*40)

    def test_only_exact_old_files_may_change(self):
        before = {p:'a' for p in pkg.OLD_CHANGES}; before['scripts/r15_source_player.gd']='motor';before['assets/sky.png']='sky'
        after = dict(before);after['scripts/r18_hud.gd']='approved'
        self.assertEqual(pkg.preserved_changes(before,after,{'scripts/r18_hud.gd':'approved'}),{'scripts/r18_hud.gd':'approved'})
        for path in ['scripts/r15_source_player.gd','assets/sky.png']:
            bad=dict(after);bad[path]='unexpected'
            self.refused(pkg.preserved_changes,before,bad)
        self.refused(pkg.preserved_changes,before,after,{})
        self.refused(pkg.preserved_changes,before,after,{'scripts/r18_hud.gd':'stale'})
        del after['scripts/r18_hud.gd']
        self.refused(pkg.preserved_changes,before,after)

    def test_floor_and_output_reserve_are_both_required(self):
        Usage = shutil._ntuple_diskusage
        with patch.object(pkg.shutil,'disk_usage',return_value=Usage(50_000_000_000,0,pkg.FLOOR+99)):
            self.assertEqual(pkg.space(99),pkg.FLOOR+99)
            self.refused(pkg.space,100)
        self.refused(pkg.space,-1)
        with tempfile.TemporaryDirectory(dir=pkg.SCRATCH) as td:
            with patch.object(pkg.shutil,'disk_usage',side_effect=[Usage(50_000_000_000,0,pkg.FLOOR+10),Usage(1_000_000_000,0,pkg.PREP_LIMIT-1)]):
                self.refused(pkg.space,0,Path(td))
        self.refused(pkg.space,0,Path('/tmp/wrong-r19-scratch'))

    def test_scratch_bound_counts_actual_file_bytes(self):
        with tempfile.TemporaryDirectory(dir=pkg.SCRATCH) as td:
            p=Path(td);(p/'sample').write_bytes(b'12345')
            self.assertEqual(pkg.bounded(p,5),5)
            self.refused(pkg.bounded,p,4)

    def test_refuses_existing_delivery_or_source_output(self):
        with tempfile.TemporaryDirectory(dir=pkg.SCRATCH) as td:
            root=Path(td);source=root/'source';source.mkdir()
            self.refused(pkg.output_ok,source/'out',source)
            old=root/'old-delivery';old.mkdir();(old/'README').write_text('keep')
            self.refused(pkg.output_ok,old,source)
            self.assertEqual(pkg.output_ok(root/'new',source)[0],root/'new')

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

    def test_identity_boundary_preserves_all_original_presets(self):
        old=pkg.pinned_json(pkg.R18_BUILD,pkg.R18_BUILD_SHA)['identity']
        identity=copy.deepcopy(old);fr=freeze()
        identity['maps']['breakwater']['geometry']=fr['breakwater_geometry']
        for key in identity['keys']['breakwater'].values():
            rec=json.loads(key['record_identity']);rec[2]=fr['breakwater_geometry'];rec[-1]=fr['breakwater_overlay']
            key['record_identity']=json.dumps(rec);key['course_key']='changed-'+key['course_key']
        def seal(value):
            fr['identity_sha256']=pkg.hashlib.sha256(pkg.canonical(value)).hexdigest()
        seal(identity);pkg.identity_boundary(identity,fr,old)
        for mutator in [lambda i:i['keys']['rainline']['server128'].update(physics_hz=120),
                        lambda i:i['keys']['breakwater']['server128'].update(fingerprint='changed law'),
                        lambda i:i['maps']['breakwater'].update(practice_points=[]),
                        lambda i:i['registry']['presets']['server128'].update(rate=120)]:
            bad=copy.deepcopy(identity);mutator(bad);seal(bad)
            self.refused(pkg.identity_boundary,bad,fr,old)

    def test_manifest_rejects_wrong_round_before_archiving(self):
        with patch.object(pkg.r16,'source_archive') as archive:
            self.refused(pkg.verify_manifest,{'build':'spillway-2026.11.09-r18'})
            archive.assert_not_called()

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


if __name__=='__main__':
    pkg.SCRATCH.mkdir(exist_ok=True)
    unittest.main(verbosity=2)
