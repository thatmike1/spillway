#!/usr/bin/env python3
"""capture the collision baseline in exact R18, then compare in an isolated R19 tree."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys

sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('parity', PROJECT/'tools/check-r19-parity.py')
c = importlib.util.module_from_spec(spec)
spec.loader.exec_module(c)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--candidate', required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    out = args.out.resolve()
    assert out.is_relative_to('/tmp') and not out.exists()
    out.mkdir()
    commands = []
    manifests = {}
    baseline_style = subprocess.check_output(['git','show',c.BASE+':'+c.PREFIX+'scripts/r16_style.gd'], cwd=c.REPO)
    injected = {'tests/r19_course_contacts.gd': c.sha(PROJECT/'tests/r19_course_contacts.gd'),
                'tests/r19_style_bhop.gd': c.sha(PROJECT/'tests/r19_style_bhop.gd'),
                'tests/r19_baseline_style.gd': hashlib.sha256(baseline_style).hexdigest()}
    try:
        for side, commit in [('baseline', c.BASE), ('candidate', args.candidate)]:
            phase = out/side
            phase.mkdir()
            source = phase/'source'
            source.mkdir()
            profile = phase/'profile'
            profile.mkdir()
            cache = phase/'import'
            cache.mkdir()
            try:
                m = c.freeze(commit, source, phase)
                if side == 'candidate':
                    c.runtime_freeze_guard(m)
                for name in ['tests/r19_course_contacts.gd', 'tests/r19_style_bhop.gd']:
                    shutil.copy2(PROJECT/name, source/name)
                (source/'tests/r19_baseline_style.gd').write_bytes(baseline_style)
                m['executed_files'] = {str(f.relative_to(source)):c.sha(f) for f in source.rglob('*') if f.is_file()}
                m['injected'].update(injected)
                assert all(m['executed_files'][n] == h for n,h in m['archive_files'].items() if n not in m['injected'])
                manifest = phase/'SOURCE.json'
                c.write(manifest,m)
                manifests[side] = {'path':str(manifest),'sha256':c.sha(manifest)}
                (source/'.godot').symlink_to(cache)
                env = c.OLD.environment(profile)
                def run(label, command):
                    result = c.bounded(command, env, source, phase/(label+'.log'), out, 180)
                    commands.append(result)
                    c.write(out/'commands.json',commands)
                    assert result['exit'] == 0, (label,result)
                    assert 'SCRIPT ERROR:' not in (phase/(label+'.log')).read_text()
                run('import',[str(c.GODOT),'--headless','--editor','--path',str(source),'--import'])
                cli=[str(c.GODOT),'--headless','--audio-driver','Dummy','--path',str(source),'--fixed-fps','128']
                extra=['--capture-before'] if side == 'baseline' else ['--baseline='+str(out/'baseline.json.bin')]
                run('contacts',cli+['--script','res://tests/r19_course_contacts.gd','--','--out='+str(out/('baseline.json' if side=='baseline' else 'contacts.json')),*extra])
                if side == 'candidate':
                    style=out/'style'
                    style.mkdir()
                    run('style',cli+['--script','res://tests/r19_style_bhop.gd','--','--out='+str(style),'--baseline=res://tests/r19_baseline_style.gd'])
                assert all(c.sha(source/n)==h for n,h in m['executed_files'].items()), 'executed source changed'
            finally:
                for folder in [source,profile,cache]:
                    if folder.exists():shutil.rmtree(folder)
        binding={'manifests':manifests,'injected':injected,'godot_sha256':c.sha(c.GODOT),
                 'baseline_raw':{'path':str(out/'baseline.json'),'sha256':c.sha(out/'baseline.json')},
                 'baseline_transport':{'path':str(out/'baseline.json.bin'),'sha256':c.sha(out/'baseline.json.bin')},
                 'runner_sha256':c.sha(Path(__file__)), 'scope':'two separate full source trees; exact R18 before, frozen R19 after; only verification files injected'}
        c.write(out/'bindings.json',binding)
        raw=json.loads((out/'contacts.json').read_text())
        assert raw['failed']==0 and len(raw['checks'])==45 and all(x['ok'] for x in raw['checks'])
        before=json.loads((out/'baseline.json').read_text())
        assert before['capture_only'] and before['failed']==0 and len(before['maps'])==8
        assert all(a['map']==b['map'] and a['before']==b['before'] for a,b in zip(before['maps'],raw['maps']))
        reviewed={**raw,'ok':True,'source_binding':{'path':str(out/'bindings.json'),'sha256':c.sha(out/'bindings.json')}}
        c.write(out/'contacts-reviewed.json',reviewed)
        row=next(r for r in raw['maps'] if r['map']=='breakwater')
        revision={'baseline_identity':row['before']['identity'],'candidate_identity':row['after']['identity'],
                  'routes':['breakwater-basic','breakwater-return'],'off_line_routes':['breakwater-basic','breakwater-return'],
                  'presets':{s:row[w]['presets'] for s,w in [('baseline','before'),('candidate','after')]},
                  'evidence':{'path':str(out/'contacts-reviewed.json'),'sha256':c.sha(out/'contacts-reviewed.json')}}
        c.validate_revision(revision)
        c.write(out/'map-revisions.json',{'breakwater':revision})
        raw_style=json.loads((out/'style/summary.json').read_text())
        assert raw_style['failed']==0 and len(raw_style['checks'])==25 and all(x['pass'] for x in raw_style['checks'])
        proof={'ok':True,'checks':raw_style['checks'],'forward_exact_samples':int(next(x for x in raw_style['checks'] if x['name']=='forward_exact_r18_events_and_score')['detail'].split()[0]),
               'source_hashes':{'baseline_style_sha256':injected['tests/r19_baseline_style.gd'],'candidate_style_sha256':json.loads(Path(manifests['candidate']['path']).read_text())['archive_files']['scripts/r16_style.gd'],'test_sha256':injected['tests/r19_style_bhop.gd']},
               'raw_summary':{'path':str(out/'style/summary.json'),'sha256':c.sha(out/'style/summary.json')},
               'bindings':{'path':str(out/'bindings.json'),'sha256':c.sha(out/'bindings.json')},
               'raw_files':{str(f.relative_to(out)):c.sha(f) for f in (out/'style').rglob('*') if f.is_file()}}
        c.write(out/'style-reviewed.json',proof)
        contract={k:proof['source_hashes'][k] for k in ['baseline_style_sha256','candidate_style_sha256']}
        contract['fixture_evidence']={'path':str(out/'style-reviewed.json'),'sha256':c.sha(out/'style-reviewed.json')}
        c.validate_style_fixture(contract,contract['baseline_style_sha256'],contract['candidate_style_sha256'])
        c.write(out/'scoring-contract.json',contract)
        c.write(out/'SUMMARY.json',{'ok':True,'candidate_commit':args.candidate,'baseline_commit':c.BASE,'contact_checks':45,'style_checks':25,'forward_exact_samples':proof['forward_exact_samples'],'separate_exact_baseline':True,'manifests':manifests})
        print((out/'SUMMARY.json').read_text())
    finally:
        c.write(out/'cleanup.json',{'source_import_profile_removed':all(not (out/s/n).exists() for s in ['baseline','candidate'] for n in ['source','profile','import'])})


if __name__ == '__main__':
    main()
