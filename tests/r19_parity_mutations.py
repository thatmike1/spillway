#!/usr/bin/env python3
"""challenge actual captured parity evidence without changing source, captures or userdata."""
import argparse
import copy
import gzip
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import shutil
import struct
import sys
import zlib

sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('r19_checker', PROJECT/'tools/check-r19-parity.py')
C = importlib.util.module_from_spec(spec)
spec.loader.exec_module(C)
A = C.module(PROJECT/'tools/analyze-r16-runs.py','r19_mutation_reader')


def rewrite(data, edit):
    """rebuild the real hash chain and physical pre-seal count, so corruption alone cannot reject a mutation."""
    length = struct.unpack_from('<I',data,12)[0]
    at = 16+length
    out = bytearray(data[:at])
    chain = hashlib.sha256(out).digest()
    out.extend(chain)
    at += 32
    while at < len(data):
        head = list(struct.unpack_from('<4sBBHIIIII',data,at))
        stored = data[at+60:at+60+head[6]]
        raw = zlib.decompress(stored) if head[2] == 1 else stored
        raw = edit(head[1],head[4],raw)
        if head[1] == A.CHUNK_SEAL:
            seal = json.loads(raw)
            seal['counts']['bytes'] = len(out)
            raw = json.dumps(seal,separators=(',',':')).encode()
        stored = zlib.compress(raw)
        head[2],head[5],head[6] = 1,len(raw),len(stored)
        packed = struct.pack('<4sBBHIIIII',*head)
        chain = hashlib.sha256(chain+packed+stored).digest()
        out.extend(packed+chain+stored)
        at += 60+struct.unpack_from('<I',data,at+16)[0]
    return bytes(out)


def column_edit(group, column):
    def edit(kind,seq,raw):
        if kind != A.CHUNK_TICKS or seq != 0:
            return raw
        data = bytearray(raw)
        n = struct.unpack_from('<I',data)[0]
        offset = 4
        layout = A.TICK_LAYOUT if group == 'columns' else A.INPUT_LAYOUT
        if group == 'inputs':
            offset += n*sum(size for _,_,size in A.TICK_LAYOUT)
            n = struct.unpack_from('<I',data,offset)[0]
            offset += 4
        for name,code,size in layout:
            axis = column[len(name)+1:] if column.startswith(name+'_') else ''
            if name == column or name in A.VECTORS and axis in 'xyz' and len(axis)==1:
                offset += min(10,n-1)*size
                if axis:
                    offset += 'xyz'.index(axis)*4
                    code = 'f'
                value = struct.unpack_from('<'+code,data,offset)[0]
                value = value+1 if code in ['i','q'] else value+0.125
                struct.pack_into('<'+code,data,offset,value)
                return bytes(data)
            offset += n*size
        raise AssertionError((group,column))
    return edit


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('folder',type=Path)
    parser.add_argument('--out',type=Path,required=True)
    args=parser.parse_args()
    out=args.out.resolve();out.mkdir()
    report=json.loads((args.folder/'REPORT.json').read_text())
    route_dir=args.folder/'breakwater-basic'
    result=json.loads((route_dir/'result.json').read_text())
    variant='new' if report['mode']=='candidate' else 'r18'
    seed=route_dir/variant
    summary=result['runs'][variant]['summary']
    record_path=Path(summary['finish']['record_path'])
    rec,_=C.OLD.recording(record_path,A)
    plan=json.loads((route_dir/'expanded.json').read_text())
    checks=[]
    def check(ok,name,detail=None):
        checks.append({'ok':bool(ok),'name':name,'detail':detail})
    original=record_path.read_bytes()
    copies=out/'working';copies.mkdir()
    (copies/'runs').mkdir();(copies/'evaluator').mkdir()
    for p in (seed/'runs').glob('*'):
        shutil.copy2(p,copies/'runs'/p.name)
    shutil.copy2(seed/'readers.json',copies/'readers.json')
    shutil.copy2(seed/'evaluator/observations.jsonl.gz',copies/'evaluator/observations.jsonl.gz')
    check(C.observation_audit(copies,A)[0]['ok'],'unmodified actual evidence passes observation audit')
    trace=seed/'evaluator/trace.jsonl.gz'
    mutations={
        'position ULP':lambda r:r['p'].__setitem__(0,math.nextafter(r['p'][0],math.inf)),
        'velocity':lambda r:r['v'].__setitem__(0,r['v'][0]+0.125),
        'actual collision box':lambda r:r['live_hull']['box_size_m'].__setitem__(1,1.31),
        'actual camera FOV':lambda r:r['view'].__setitem__('fov',101.),
        'hull metadata':lambda r:r['physics']['hull'].__setitem__('unknown',1),
        'held delivery':lambda r:r['held'].__setitem__('jump',not r['held'].get('jump',False)),
        'progress':lambda r:r.__setitem__('checkpoint',99),
        'time':lambda r:r.__setitem__('elapsed',r['elapsed']+0.125),
        'motion compatibility version':lambda r:r['identity'].__setitem__('format','different'),
        'map revision':lambda r:r['identity'].__setitem__('geometry','different'),
        'unknown identity':lambda r:r['identity'].__setitem__('unknown',1),
    }
    for index,(name,edit) in enumerate(mutations.items()):
        target=out/f'trace-{index}.jsonl.gz'
        with gzip.open(target,'wt') as dest:
            for i,row in enumerate(C.stream(trace)):
                if i==10:edit(row)
                dest.write(json.dumps(row,separators=(',',':'))+'\n')
        check(not C.compare_traces(trace,target,True)['ok'],'actual trace rejects '+name)
    retained=out/'records';retained.mkdir()
    for group,names in [('columns',A.COLUMN_NAMES),('inputs',[name for name,_,_ in A.INPUT_LAYOUT])]:
        for name in names:
            path=retained/(group+'-'+name+'.r16run')
            path.write_bytes(rewrite(original,column_edit(group,name)))
            parsed=A.read(path)
            # a schema/semantic rejection by the original reader is already a valid rejection.
            if parsed.ok:
                dumped=next(row for row in json.loads((seed/'readers.json').read_text()) if row['file']==record_path.name)
                got=C.packed_columns(parsed.columns,True) if group=='columns' else C.packed_columns(parsed.inputs)
                wanted=dumped['columns_sha256'] if group=='columns' else dumped['inputs_sha256']
                observed={'all_column_hash_difference':C.difference(wanted,got)}
                rejected=observed['all_column_hash_difference'] is not None
            else:observed={'original_reader_errors':parsed.errors};rejected=True
            check(rejected,'actual all-column evidence rejects '+group+'.'+name,observed)
    shutil.copy2(record_path,copies/'runs'/record_path.name)
    for name,edit in [('pose',lambda r:r.columns['p_x'].__setitem__(result['route']['warmup'],42.)),
                      ('view',lambda r:r.columns['yaw'].__setitem__(result['route']['warmup'],1.)),
                      ('progress',lambda r:r.columns['checkpoint'].__setitem__(result['route']['warmup'],99)),
                      ('style event',lambda r:next(e['d'] for e in r.events if e.get('s')=='capture').__setitem__('points',99999)),
                      ('logical key',lambda r:r.inputs['code'].__setitem__(0,999))]:
        bad=copy.deepcopy(rec);edit(bad)
        check(not C.OLD.recording_alignment(bad,trace,result['route']['warmup'])['ok'],'actual recording alignment rejects '+name)
    bad=copy.deepcopy(rec);bad.inputs['aux'][0]=999
    check(not C.ordered_tape_audit(bad,plan,result['route']['warmup'])['ok'],'ordered retained tape rejects changed physical key')
    bad=copy.deepcopy(rec)
    pair=next((i,j) for i in range(len(bad.inputs['tick'])) if bad.inputs['kind'][i]==1
              for j in range(i+1,min(i+8,len(bad.inputs['tick'])))
              if bad.inputs['tick'][i]>=result['route']['warmup'] and bad.inputs['tick'][i]==bad.inputs['tick'][j] and bad.inputs['kind'][j]==3)
    for values in bad.inputs.values():values[pair[0]],values[pair[1]]=values[pair[1]],values[pair[0]]
    check(not C.ordered_tape_audit(bad,plan,result['route']['warmup'])['ok'],'retained tape rejects reordered same-tick key and mouse')
    _,canonical=C.OLD.recording(record_path,A)
    altered=copy.deepcopy(canonical);altered['header']['identity']['format']='different'
    check(C.difference(C.record_compare_view(canonical)[0],C.record_compare_view(altered)[0]) is not None,
          'record comparison preserves motion compatibility version')
    altered=copy.deepcopy(canonical);altered['header']['metadata']['scoring']['style_key']='different'
    before,score_before,_=C.record_compare_view(canonical);after,score_after,_=C.record_compare_view(altered)
    check(C.difference(before,after) is None and C.difference(score_before,score_after) is not None,
          'score version is separately retained without changing motion identity')
    # force a valid reader result with a wrong pre-seal physical count to challenge the inherited offset check directly.
    bad=copy.deepcopy(rec);bad.seal['counts']['bytes']+=1
    class ForcedReader:
        @staticmethod
        def read(_):return bad
    try:C.OLD.recording(record_path,ForcedReader);rejected=False
    except AssertionError:rejected=True
    check(rejected,'inherited physical pre-seal offset rejects wrong bookkeeping')
    corrupted=out/'bad-hash.r16run';data=bytearray(original);data[-1]^=1;corrupted.write_bytes(data)
    check(not A.read(corrupted).ok,'original strict reader rejects damaged hash chain')
    dump=json.loads((copies/'readers.json').read_text());dump[0]['columns_sha256']['tick']='0'*64
    C.write(copies/'readers.json',dump)
    check(not C.observation_audit(copies,A)[0]['ok'],'cross-reader all-column hash guard rejects changed Godot dump')
    shutil.copy2(seed/'readers.json',copies/'readers.json')
    target=copies/'evaluator/observations.jsonl.gz'
    with gzip.open(target,'wt') as dest:
        for i,row in enumerate(C.stream(seed/'evaluator/observations.jsonl.gz')):
            if i==10:row['actual']['p'][0]+=0.125
            dest.write(json.dumps(row,separators=(',',':'))+'\n')
    check(not C.observation_audit(copies,A)[0]['ok'],'actual source observation rejects altered post-step body')
    shutil.rmtree(copies)
    output={'ok':all(c['ok'] for c in checks),'checks':checks,'seed_record_sha256':C.sha(record_path),'seed_report_sha256':C.sha(args.folder/'REPORT.json'),
            'verification_source_sha256':report['verification_source_sha256'],'mutation_script_sha256':C.sha(Path(__file__)),
            'cleanup':{'working_copy_removed':not copies.exists()},'scope':'negative controls on copied actual evidence; no runtime/native claim'}
    C.write(out/'SUMMARY.json',output)
    C.write(out/'MANIFEST.json',{str(p.relative_to(out)):C.sha(p) for p in sorted(out.rglob('*')) if p.is_file()})
    print(json.dumps({'ok':output['ok'],'checks':len(checks),'failures':[c for c in checks if not c['ok']]}))
    return 0 if output['ok'] else 1


if __name__=='__main__':raise SystemExit(main())
