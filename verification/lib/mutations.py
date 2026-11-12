import bisect,copy,gzip,hashlib,itertools,json,math,struct,zlib
from pathlib import Path
import parity_core as K
A=K.A
C=K.B
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


def edit_header(data, edit):
    length = struct.unpack_from('<I', data, 12)[0]
    header = json.loads(data[16:16+length])
    edit(header)
    raw = json.dumps(header, separators=(',',':')).encode()
    output = bytearray(data[:12]+struct.pack('<I',len(raw))+raw)
    chain = hashlib.sha256(output).digest()
    output.extend(chain)
    at = 16+length+32
    while at < len(data):
        h = list(struct.unpack_from('<4sBBHIIIII',data,at))
        stored = data[at+60:at+60+h[6]]
        if h[1] == K.A.CHUNK_SEAL:
            seal = json.loads(zlib.decompress(stored) if h[2] == 1 else stored)
            seal['counts']['bytes'] = len(output)
            raw = json.dumps(seal, separators=(',',':')).encode()
            stored = zlib.compress(raw)
            h[2], h[5], h[6] = 1, len(raw), len(stored)
        packed = struct.pack('<4sBBHIIIII', *h)
        chain = hashlib.sha256(chain+packed+stored).digest()
        output.extend(packed+chain+stored)
        at += 60+struct.unpack_from('<I',data,at+16)[0]
    return bytes(output)


def duplicate_record_json(data, section):
    # rebuild every digest/count so only the shadowed JSON key can cause refusal.
    length = struct.unpack_from('<I', data, 12)[0]
    header = data[16:16+length]
    touched = False
    if section == 'header':
        header = b'{"metadata":{"unreviewed":true},'+header[1:]
        touched = True
    out = bytearray(data[:12]+struct.pack('<I',len(header))+header)
    chain = hashlib.sha256(out).digest()
    out.extend(chain)
    at = 16+length+32
    while at < len(data):
        head = list(struct.unpack_from('<4sBBHIIIII',data,at))
        stored = data[at+60:at+60+head[6]]
        raw = zlib.decompress(stored) if head[2] == 1 else stored
        if section == 'events' and head[1] == K.A.CHUNK_TICKS and not touched:
            count = struct.unpack_from('<I',raw)[0]
            offset = 4+count*sum(size for _,_,size in K.A.TICK_LAYOUT)
            inputs = struct.unpack_from('<I',raw,offset)[0]
            offset += 4+inputs*K.A.INPUT_ROW
            events = raw[offset+4:]
            first = events.find(b'{')
            if first >= 0:
                events = events[:first+1]+b'"k":"unreviewed",'+events[first+1:]
                raw = raw[:offset]+struct.pack('<I',len(events))+events
                touched = True
        if head[1] == K.A.CHUNK_SEAL:
            seal = json.loads(raw)
            seal['counts']['bytes'] = len(out)
            raw = json.dumps(seal,separators=(',',':')).encode()
            if section == 'seal':
                raw = b'{"outcome":{"unreviewed":true},'+raw[1:]
                touched = True
        stored = zlib.compress(raw)
        head[2],head[5],head[6] = 1,len(raw),len(stored)
        packed = struct.pack('<4sBBHIIIII',*head)
        chain = hashlib.sha256(chain+packed+stored).digest()
        out.extend(packed+chain+stored)
        at += 60+struct.unpack_from('<I',data,at+16)[0]
    assert touched
    return bytes(out)


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
