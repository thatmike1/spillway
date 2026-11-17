import gzip,hashlib,json,math,os,struct,shutil
from pathlib import Path
MIN_FREE = 2_000_000_000
def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda: f.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def write(path, value):
    path.write_text(json.dumps(value, indent=1) + '\n')




def canonical(value):
    # preserve every gameplay field; recording labels are normalized separately.
    if isinstance(value, dict):
        return {k: canonical(v) for k, v in value.items()}
    if isinstance(value, list):
        return [canonical(v) for v in value]
    return value


def difference(a, b, path='$'):
    if type(a) is not type(b):
        return {'path': path, 'a': a, 'b': b}
    if isinstance(a, dict):
        if a.keys() != b.keys():
            return {'path': path, 'keys_a': list(a), 'keys_b': list(b)}
        for key in a:
            found = difference(a[key], b[key], path+'.'+key)
            if found:
                return found
    elif isinstance(a, list):
        if len(a) != len(b):
            return {'path': path, 'length_a': len(a), 'length_b': len(b)}
        for i, (x,y) in enumerate(zip(a,b)):
            found = difference(x,y,path+f'[{i}]')
            if found:
                return found
    elif a != b:
        return {'path': path, 'a': a, 'b': b}
    return None




def recording(path, analyzer):
    rec = analyzer.read(path)
    assert rec.ok, (str(path),rec.errors)
    header = dict(rec.header)
    # docs/r16/RECORDINGS.md: wall clock/run id are labels, never gameplay.
    for key in ['run_id','created_utc','created_unix']:
        header.pop(key, None)
    seal = {k:v for k,v in rec.seal.items() if k != 'ended_unix'}
    seal['counts'] = dict(seal['counts'])
    data = path.read_bytes()
    header_bytes = struct.unpack_from('<I',data,12)[0]
    at = 16+header_bytes+32
    while data[at+4] != 2:
        at += 60+struct.unpack_from('<I',data,at+16)[0]
    assert rec.seal['counts']['bytes']==at, 'pre-seal byte bookkeeping must match actual validated stream offset'
    # docs/r16/RECORDINGS.md: counts.bytes includes the variable-sized label/time header.
    # remove its physical size contribution only; compare every compressed gameplay payload byte count.
    seal['counts']['bytes'] -= header_bytes
    return rec, {'header':header,'columns':rec.columns,'inputs':rec.inputs,'events':rec.events,'seal':seal}




def recording_alignment(rec, trace, offset):
    import struct
    def f32(v):
        return struct.unpack('<f',struct.pack('<f',v))[0]
    c=rec.columns
    names=[]
    for event in rec.events:
        if event['k']=='held_names':
            names=event['d']['names']
            break
    actions={e['d']['index']:e['d']['name'] for e in rec.events if e['k']=='action_name'}
    actual_inputs={}
    ins=rec.inputs
    for j,tick in enumerate(ins['tick']):
        kind=ins['kind'][j]
        if kind==1:
            event={'type':'key','keycode':ins['code'][j],'physical_keycode':ins['aux'][j],
                   'pressed':bool(ins['flags'][j]&1),'echo':bool(ins['flags'][j]&2)}
        elif kind==3:
            event={'type':'mouse_motion','screen_relative':[ins['x'][j],ins['y'][j]],'relative':[ins['x2'][j],ins['y2'][j]]}
        elif kind==4:
            event={'type':'action','action':actions[ins['code'][j]],'pressed':bool(ins['flags'][j]&1)}
        else:
            raise AssertionError(('unexpected input kind in retained keyboard/mouse route',kind))
        actual_inputs.setdefault(tick,[]).append(event)
    bad=[]
    compared=0
    input_count=0
    for row in stream(trace):
        i=offset+row['tick']
        if i>=len(c['tick']):
            break
        fields={k:row[k] for k in ['dt','physics_hz','elapsed','checkpoint','respawns','yaw','pitch']}
        fields['flags']=sum(int(row[k])<<bit for bit,k in enumerate(['started','finished','clean','grounded','ducked']))
        fields['held']=sum(int(bool(row['held'].get(name,False)))<<bit for bit,name in enumerate(names))
        for group in ['p','reference_p','v','actual_v']:
            for axis,value in zip('xyz',row[group]):
                fields[group+'_'+axis]=f32(value)
        for key,want in fields.items():
            if c[key][i]!=want and len(bad)<4:
                bad.append({'tick':row['tick'],'column':key,'want':want,'actual':c[key][i]})
        want_inputs=row['input']
        for event in want_inputs:
            if event['type']=='mouse_motion':
                for key in ['relative','screen_relative']:
                    event[key]=[f32(v) for v in event[key]]
        got_inputs=actual_inputs.get(i,[])
        found=difference(want_inputs,got_inputs)
        if found and len(bad)<4:
            bad.append({'tick':row['tick'],'inputs':found})
        input_count+=len(got_inputs)
        compared+=1
    if input_count != len(ins['tick']):
        bad.append({'unmatched_inputs':len(ins['tick'])-input_count})
    style=[e for e in rec.events if e.get('s')=='capture']
    points=sum(int(e.get('d',{}).get('points',0)) for e in style)
    style_ok=points==rec.seal['outcome']['style']['score'] and not any(e['t']>rec.seal['finish_tick'] for e in style)
    return {'ok':not bad and compared==len(c['tick'])-offset and style_ok,
            'offset':offset,'compared':compared,'recorded_ticks':len(c['tick']),'first_differences':bad,'input_rows_checked':input_count,
            'independent_style_total':points,'style_seal_ok':style_ok}


def stream(path):
 from parity_core import stream as read
 return read(path)
