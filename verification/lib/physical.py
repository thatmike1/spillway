import importlib.util,copy,gzip,hashlib,itertools,json,math,re,struct
from pathlib import Path
import legacy as OLD
sha,write,difference,stream = OLD.sha,OLD.write,OLD.difference,None
NEW_KINDS = {"backward_bhop","sideways_bhop"}
def module(path, name):
    import importlib.util
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result




def godot_number(text):
    """independent exact reference for Godot String.to_float's published built_in_strtod algorithm.

    JSON numbers use this parser, not correctly-rounded libc strtod. Reproduce the
    18-digit mantissa/powers-of-ten operations exactly, without a numeric tolerance.
    https://github.com/godotengine/godot/blob/master/core/string/ustring.cpp
    """
    mantissa, _, exponent_text = text.lower().partition('e')
    exponent = int(exponent_text or 0)
    sign = -1 if mantissa.startswith('-') else 1
    mantissa = mantissa.lstrip('+-')
    integer, _, fraction = mantissa.partition('.')
    digits = integer + fraction
    count = min(len(digits),18)
    exponent += len(integer) - count
    digits = digits[:count]
    value = 1e9 * int(digits[:-9] or 0) + int(digits[-9:] or 0)
    scale = 1.0
    remaining = min(abs(exponent),511)
    for power in [10.,100.,1e4,1e8,1e16,1e32,1e64,1e128,1e256]:
        if remaining & 1:
            scale *= power
        remaining >>= 1
    return sign * (value / scale if exponent < 0 else value * scale)


def godot_json_reader(analyzer):
    import types
    expected = module(Path(analyzer.__file__),'r19_godot_json_reference')
    expected.json = types.SimpleNamespace(loads=lambda data,**kwargs:json.loads(data,parse_float=godot_number,parse_int=godot_number,**kwargs))
    return expected


def reader_difference(a, b, path='$'):
    # godot's JSON parser represents all JSON numbers as doubles; retain exact values, not that parser's numeric tag.
    if type(a) in (int,float) and type(b) in (int,float):
        return None if a == b else {'path':path,'a':a,'b':b}
    if isinstance(a,dict) and isinstance(b,dict) and a.keys() == b.keys():
        for key in a:
            found = reader_difference(a[key],b[key],path+'.'+key)
            if found:
                return found
        return None
    if isinstance(a,list) and isinstance(b,list) and len(a) == len(b):
        for i,(x,y) in enumerate(zip(a,b)):
            found = reader_difference(x,y,path+f'[{i}]')
            if found:
                return found
        return None
    return difference(a,b,path)






def validate_record_identity(header, text):
    meta, identity = header['metadata'],header['identity']
    ordered = meta['record_identity']
    assert len(ordered) == 13 and len(ordered[1]) == 5, 'ordered record identity schema changed'
    assert reader_difference(json.loads(text),ordered) is None, 'identity text/header mismatch'
    assert hashlib.sha256(text.encode()).hexdigest()[:16] == identity['course_key'] == meta['course_key'], 'record identity course key hash mismatch'
    assert identity == meta['identity'], 'own header and metadata identities differ'
    for key,value in [('map',ordered[1][0]),('geometry',ordered[2]),('preset',ordered[4]),('motor',ordered[6]),
                      ('runner',ordered[7]),('physics_hz',ordered[8]),('timing',ordered[0]),('overlay',ordered[12])]:
        assert identity[key] == value, ('record identity/header relation',key)
    assert meta['map'] == ordered[1][0] and meta['map_kind'] == ordered[1][1] and meta['preset'] == ordered[4] and meta['family'] == ordered[5]
    for index,key in [(9,'fingerprint'),(10,'hull'),(11,'mechanics')]:
        assert reader_difference(json.loads(ordered[index]),meta['physics'][key]) is None, ('ordered physics/header relation',key)










def packed_columns(columns, vectors=False):
    codes = {'tick':'i','flags':'i','dt':'d','elapsed':'d','physics_hz':'i','checkpoint':'i','respawns':'i',
             'yaw':'d','pitch':'d','held':'q'} if vectors else {'tick':'i','kind':'i','flags':'i','code':'q','aux':'q','x':'f','y':'f','x2':'f','y2':'f'}
    result = {}
    for key, code in codes.items():
        result[key] = hashlib.sha256(struct.pack(f'<{len(columns[key])}{code}', *columns[key])).hexdigest()
    if vectors:
        for key in ['p','reference_p','v','actual_v']:
            values = [v for i in range(len(columns['tick'])) for v in [columns[key+'_'+a][i] for a in 'xyz']]
            result[key] = hashlib.sha256(struct.pack(f'<{len(values)}f', *values)).hexdigest()
    return result








def ordered_tape_audit(rec, plan, warmup):
    codes = {'w':87,'a':65,'s':83,'d':68,'space':32,'ctrl':4194326,'shift':4194325,'e':69}
    expected, observed = {}, {}
    f32 = lambda x: struct.unpack('<f',struct.pack('<f',x))[0]
    for e in plan['events']:
        if e['tick']+warmup >= len(rec.columns['tick']):
            continue
        event = ('key',codes[e['key']],e['edge']=='press') if 'key' in e else ('mouse',*[f32(v) for v in e['mouse']])
        expected.setdefault(e['tick'],[]).append(event)
    # the retained executor's contract is keys first in original order, then mouse, without reordering observed rows.
    expected = {tick:[e for e in events if e[0]=='key']+[e for e in events if e[0]=='mouse'] for tick,events in expected.items()}
    ins = rec.inputs
    for j,tick in enumerate(ins['tick']):
        if ins['kind'][j] == 1:
            observed.setdefault(tick-warmup,[]).append(('key',ins['aux'][j] or ins['code'][j],bool(ins['flags'][j]&1)))
        elif ins['kind'][j] == 3:
            observed.setdefault(tick-warmup,[]).append(('mouse',ins['x'][j],ins['y'][j]))
    found = difference({str(k):v for k,v in expected.items()},{str(k):v for k,v in observed.items()})
    return {'ok':found is None,'first_difference':found,'raw_rows':sum(map(len,observed.values()))}
