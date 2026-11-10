#!/usr/bin/env python3
"""reconstruct source pins from Git and challenge real retained data without accepting R20."""
import argparse
import copy
import bisect
import gzip
import hashlib
import importlib.util
import io
import json
import math
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile

sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('r20_provenance_checker',PROJECT/'tools/check-r20-parity.py')
C = importlib.util.module_from_spec(spec)
spec.loader.exec_module(C)


def git_source():
    # only the small project archive is materialized in Python memory, never a second disk source tree.
    archive = subprocess.check_output(['git','archive','--format=tar',C.BASE,C.PREFIX],cwd=C.REPO)
    sources = {}
    with tarfile.open(fileobj=io.BytesIO(archive)) as packed:
        for entry in packed:
            if entry.isfile():
                sources[entry.name.removeprefix(C.PREFIX)] = hashlib.sha256(packed.extractfile(entry).read()).hexdigest()
    return hashlib.sha256(archive).hexdigest(),sources


def source_guard(manifest,expected):
    digest,sources = expected
    C.source_guard(manifest)
    assert manifest['archive']['sha256'] == digest, 'wrong committed archive hash'
    assert manifest['archive_files'] == sources, 'any committed source hash missing, added or changed'
    assert manifest['injected'] == {'tests/r20_parity.gd':C.sha(PROJECT/'tests/r20_parity.gd')}, 'wrong injected fixture'
    for name in ['tests/r19_parity_audit.py']:
        assert C.sha(PROJECT/name) == sources[name], ('executed historical self-test changed',name)
    return True


def trace_guard(path,duration):
    count = 0
    for count,row in enumerate(C.stream(path),1):
        assert row['tick'] == count-1, 'noncontiguous actual trace'
    assert count == duration, 'incomplete actual trace'
    return True


def route_identity_guard(summary,route):
    finish = summary['finish']
    identity = finish['identity']
    assert finish['map'] == identity['map'] == route['map'], 'wrong configured map'
    assert finish['preset'] == identity['preset'] == route['preset'], 'wrong configured preset'
    assert identity['format'] == 'r16-motion-1' and identity['timing'] == 'r16-timing-1', 'unknown baseline motion/time version'
    assert set(identity) == {'course_key','format','geometry','map','motor','overlay','physics_hz','preset','runner','timing'}, 'unknown baseline identity fields'
    assert identity['physics_hz'] == 128, 'wrong configured physics law rate'
    return True


def ghost_track(record):
    columns = record.columns
    start = next(i for i,flags in enumerate(columns['flags']) if flags & 1)
    end = next(i for i in range(start,len(columns['flags'])) if columns['flags'][i] & 2)
    first = max(start-1,0)
    times = [0.0 if i < start else columns['elapsed'][i] for i in range(first,end+1)]
    def pose(time):
        at = first if time <= times[0] else end if time >= times[-1] else first+bisect.bisect_right(times,time)-1
        # retained route clocks land exactly on recording samples. refuse an unreviewed interpolation rule.
        assert time <= times[0] or time >= times[-1] or columns['elapsed'][at] == time, 'ghost query between samples needs explicit interpolation reference'
        return {'feet':[columns['p_'+axis][at] for axis in 'xyz'],'yaw':columns['yaw'][at],
                'pitch':columns['pitch'][at],'ducked':bool(columns['flags'][at]&16)}
    return pose


def transport_guard(folder,report):
    path = folder/'TRANSPORT.json'
    transport = json.loads(path.read_text())
    assert transport['ok'] and transport['determinism_different_chunk_sizes']
    assert C.sha(path) == report['transport_canonicalization']['sha256']
    assert C.sha(PROJECT/'tests/r20_parity_canonicalize.py') == transport['script_sha256']
    assert C.sha(folder/'REPORT-CAPTURE.json') == transport['capture_report_sha256']
    capture = json.loads((folder/'REPORT-CAPTURE.json').read_text())
    current = copy.deepcopy(report)
    del current['transport_canonicalization']
    assert C.difference(capture,current) is None, 'transport finalization changed acceptance report'
    receipts = {}
    for route in report['routes']:
        directory = folder/route['name']
        original = json.loads((directory/'result-capture.json').read_text())
        current = json.loads((directory/'result.json').read_text())
        restored = copy.deepcopy(current)
        for variant,run in restored['runs'].items():
            for name,receipt in run['trace_compression']['receipts'].items():
                relative = str((directory/variant/'evaluator'/(name+'.gz')).relative_to(folder))
                receipts[relative] = {'path':relative,**copy.deepcopy(receipt)}
                assert receipt['lossless_verified']
                receipt['gzip_sha256'] = receipt.pop('streamed_gzip_sha256')
                del receipt['canonical_transport']
                with (folder/relative).open('rb') as packed:
                    header = packed.read(10)
                assert header[:4] == b'\x1f\x8b\x08\x00' and header[4:8] == bytes(4), 'noncanonical gzip header'
        assert C.difference(original,restored) is None, 'transport finalization changed a comparison or dropped a capture field'
    assert receipts == {r['path']:r for r in transport['receipts']}, 'transport receipt set mismatch'
    assert len(receipts) == 16*2*3
    return True


def baseline_guard(report,expected_routes):
    assert report['ok'] and report['baseline_commit'] == C.BASE and report['mode'] == 'baseline-only'
    assert report['r20_final_gate'] == 'pending'
    assert report['requested_routes'] == [r['name'] for r in expected_routes]
    assert [(r['name'],r['map'],r['preset']) for r in report['routes']] == [(r['name'],r['map'],r['preset']) for r in expected_routes], 'incomplete, substituted, duplicate or reordered routes'
    return True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('folder',type=Path)
    args = parser.parse_args()
    folder = args.folder.resolve()
    assert folder == C.SCRATCH
    C.gate()
    report = json.loads((folder/'REPORT.json').read_text())
    manifest = json.loads((folder/'source-r19.json').read_text())
    expected = git_source()
    route_manifest = json.loads((C.OUTER/'delivery/spillway-r16/VERIFICATION.json').read_text())
    routes = route_manifest['routes']
    checks = []
    def check(ok,name,detail=None):
        checks.append({'ok':bool(ok),'name':name,'detail':detail})
    def reject(call,name):
        try:
            value = call()
            rejected = isinstance(value,dict) and not value['ok']
        except (AssertionError,KeyError,ValueError,TypeError):
            rejected = True
        check(rejected,name)
    check(source_guard(manifest,expected),'complete exact committed R19 archive independently reconstructed')
    check(transport_guard(folder,report),'deterministic transport preserved original reports, raw hashes and all96stream receipts')
    check(baseline_guard(report,routes),'all requested original routes independently anchored')
    check(C.sha(C.OUTER/'delivery/spillway-r16/VERIFICATION.json') == report['retained_delivery_manifest_sha256'], 'retained delivery route manifest unchanged')
    expander = C.module(PROJECT/'tools/momentum-tape.py','r20_provenance_expander')
    reader = C.module(PROJECT/'tools/analyze-r16-runs.py','r20_provenance_reader')
    for route in routes:
        directory = folder/route['name']
        result = json.loads((directory/'result.json').read_text())
        plan = expander.expand(json.loads(Path(route['tape']).read_text()))
        check(result['route'] == route and json.loads((directory/'expanded.json').read_text()) == plan,
              'full established tape independently expanded '+route['name'])
        for variant in ['r19','r19-ghost']:
            check(route_identity_guard(result['runs'][variant]['summary'],route),'actual host map preset and known versions '+route['name']+'/'+variant)
            for kind in ['trace','ghost']:
                check(trace_guard(directory/variant/'evaluator'/(kind+'.jsonl.gz'),plan['duration_ticks']),
                      'every declared tick retained '+route['name']+'/'+variant+'/'+kind)
        record = reader.read(Path(result['runs']['r19']['summary']['finish']['record_path']))
        assert record.ok
        pose_at = ghost_track(record)
        pose_count = 0
        for actual,ghost in zip(C.stream(directory/'r19-ghost/evaluator/trace.jsonl.gz'),
                                C.stream(directory/'r19-ghost/evaluator/ghost.jsonl.gz')):
            assert ghost['loaded'] and ghost['shown'], 'startup clean ghost not live'
            assert C.difference(pose_at(actual['elapsed']),ghost['pose_at_clock']) is None, 'ghost pose differs from independent recording at actual clock'
            pose_count += 1
        check(pose_count == plan['duration_ticks'],'every ghost clock pose independently agrees with actual recording '+route['name'])

    for name,edit in [
        ('commit',lambda m:m.__setitem__('commit','5dcc94967c19cf1333797ce8fc26f36a8f860ce5')),
        ('archive digest',lambda m:m['archive'].__setitem__('sha256','0'*64)),
        ('law bytes',lambda m:[m[key].__setitem__('scripts/r14_source_motion.gd','0'*64) for key in ['archive_files','executed_files']]),
        ('map bytes',lambda m:[m[key].__setitem__('scripts/r15_breakwater_level.gd','0'*64) for key in ['archive_files','executed_files']]),
        ('fixture',lambda m:[m[key].__setitem__('tests/r20_parity.gd','0'*64) for key in ['injected','executed_files']]),
        ('added source',lambda m:[m[key].__setitem__('scripts/extra.gd','0'*64) for key in ['archive_files','executed_files']]),
    ]:
        other = copy.deepcopy(manifest); edit(other)
        reject(lambda:source_guard(other,expected),'reject wrong source '+name)
    for name,edit in [('missing play',lambda r:r['routes'].pop()),
                      ('duplicate play',lambda r:r['routes'].__setitem__(1,r['routes'][0])),
                      ('map substitution',lambda r:r['routes'][0].__setitem__('map','saltglass'))]:
        other = copy.deepcopy(report);edit(other)
        reject(lambda:baseline_guard(other,routes),'reject '+name)
    directory = folder/'breakwater-basic'
    result = json.loads((directory/'result.json').read_text())
    seed = directory/'r19-ghost'
    run = result['runs']['r19-ghost']
    plan = json.loads((directory/'expanded.json').read_text())
    for name,edit in [('short tape',lambda r:r['summary']['finish'].__setitem__('last_tick',plan['duration_ticks']-2)),
                      ('early finish',lambda r:r['summary']['finish'].__setitem__('finished',False)),
                      ('wrong host scene',lambda r:r['summary'].__setitem__('host_scene','res://scenes/r20.tscn')),
                      ('inherited candidate class',lambda r:r['summary'].__setitem__('host_script','res://scripts/r20_main.gd')),
                      ('failed engine check',lambda r:r['summary']['checks'][0].__setitem__('ok',False))]:
        other = copy.deepcopy(run);edit(other)
        reject(lambda:C.complete_guard(other,plan),'actual play rejects '+name)
    for name,edit in [('wrong map',lambda s:s['finish'].__setitem__('map','saltglass')),
                      ('wrong preset',lambda s:s['finish']['identity'].__setitem__('preset','server128_aa1000')),
                      ('unknown timing version',lambda s:s['finish']['identity'].__setitem__('timing','r20-timing-unknown')),
                      ('unknown motion version',lambda s:s['finish']['identity'].__setitem__('format','r20-motion-unknown'))]:
        other = copy.deepcopy(run['summary']);edit(other)
        reject(lambda:route_identity_guard(other,result['route']),'actual identity rejects '+name)
    scratch = folder/'provenance-working'
    scratch.mkdir()
    try:
        trace = seed/'evaluator/trace.jsonl.gz'
        first = next(C.stream(trace))
        mutations = {('identity '+key):lambda r,k=key:r['identity'].__setitem__(k,'unknown or mismatched') for key in first['identity']}
        mutations.update({
            'physical single bit':lambda r:r['p'].__setitem__(0,math.nextafter(r['p'][0],math.inf)),
            'preset laws':lambda r:r['physics']['fingerprint'].__setitem__('unknown',1),
            'hull':lambda r:r['live_hull']['box_size_m'].__setitem__(1,1.31),
            'unknown physical field':lambda r:r.__setitem__('unknown',1),
        })
        for name,edit in mutations.items():
            target = scratch/'trace.gz'
            with target.open('wb') as packed,gzip.GzipFile(filename='',mode='wb',fileobj=packed,mtime=0) as output:
                for i,row in enumerate(C.stream(trace)):
                    if i==10:
                        edit(row)
                    output.write((json.dumps(row)+'\n').encode())
            reject(lambda:C.compare_traces(trace,target,True),'actual full physical trace rejects '+name)
        target = scratch/'trace.gz'
        with gzip.open(target,'wt') as output:
            for i,row in enumerate(C.stream(trace)):
                if i != 10:
                    output.write(json.dumps(row)+'\n')
        reject(lambda:C.compare_traces(trace,target),'actual trace rejects omitted tick')
        reject(lambda:trace_guard(target,plan['duration_ticks']),'actual completeness guard rejects missing middle tick')
        ghost = seed/'evaluator/ghost.jsonl.gz'
        with gzip.open(target,'wt') as output:
            for i,row in enumerate(C.stream(ghost)):
                if i==10:
                    row['body_position'][0] = math.nextafter(row['body_position'][0],math.inf)
                output.write(json.dumps(row)+'\n')
        reject(lambda:C.OLD.compare_traces(ghost,target),'actual ghost trace rejects single-bit pose mismatch')
        probe = copy.deepcopy(run['summary']['finish']['ghost_probes'])
        probe[0]['body'][0] = math.nextafter(probe[0]['body'][0],math.inf)
        check(C.difference(probe,run['summary']['finish']['ghost_probes']) is not None,'actual ghost probes reject pose mismatch')
        C.gate()
        check(C.allocated_footprint(folder)<=C.CAP,'all owned retained scratch remains under 600 MiB')
    finally:
        shutil.rmtree(scratch)
    output = {'ok':all(c['ok'] for c in checks),'checks':checks,'r20_final_gate':'pending',
              'executed_script_sha256':C.sha(Path(__file__)),'source_manifest_sha256':C.sha(folder/'source-r19.json'),
              'report_sha256':C.sha(folder/'REPORT.json')}
    C.write(folder/'PROVENANCE.json',output)
    print(json.dumps({'ok':output['ok'],'checks':len(checks),'failures':[c for c in checks if not c['ok']]}))
    # exclude this manifest from itself; this is the transport inventory for parent archival.
    C.write(folder/'MANIFEST.json',{str(p.relative_to(folder)):C.sha(p) for p in sorted(folder.rglob('*')) if p.is_file() and p != folder/'MANIFEST.json'})
    return 0 if output['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
