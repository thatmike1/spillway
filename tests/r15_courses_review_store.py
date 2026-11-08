#!/usr/bin/env python3
"""losslessly share identical 512-row trace blocks within the bounded evidence directory."""
import argparse
import gzip
import hashlib
import json
from pathlib import Path


def sha(data):
    return hashlib.sha256(data).hexdigest()


def compact(root):
    root = Path(root).resolve()
    blocks = root/'trace-blocks'
    blocks.mkdir(exist_ok=True)
    for trace in sorted(root.glob('*/*/trace.jsonl.gz')):
        compressed = trace.read_bytes()
        raw = gzip.decompress(compressed)
        lines = raw.splitlines(keepends=True)
        if len(lines) < 512:
            continue
        names = []
        for start in range(0,len(lines),512):
            block = b''.join(lines[start:start+512])
            name = sha(block)+'.jsonl.gz'
            target = blocks/name
            if not target.exists():
                target.write_bytes(gzip.compress(block,compresslevel=9,mtime=0))
            names.append(name)
        index = {'format':'r15-courses-review-trace-blocks-1','rows':len(lines),'plain_sha256':sha(raw),'original_gzip_sha256':sha(compressed),'blocks':names}
        trace.with_name('trace-index.json').write_text(json.dumps(index,indent=2)+'\n')
        trace.unlink()
    for path in list(root.glob('*/*/input.json'))+list(root.glob('*/*/summary.json'))+list(root.glob('*/*.log')):
        path.with_name(path.name+'.gz').write_bytes(gzip.compress(path.read_bytes(),compresslevel=9,mtime=0))
        path.unlink()
    # every referenced block is checked before returning; no numerical re-encoding or sampling.
    for index in root.glob('*/*/trace-index.json'):
        read_trace(index.parent,root)
    return sum(p.stat().st_size for p in root.rglob('*') if p.is_file())


def read_trace(path, root=None):
    path = Path(path)
    if (path/'trace.jsonl.gz').exists():
        return gzip.decompress((path/'trace.jsonl.gz').read_bytes())
    root = Path(root) if root else path.parent.parent
    index = json.loads((path/'trace-index.json').read_text())
    data = b''
    for name in index['blocks']:
        block = gzip.decompress((root/'trace-blocks'/name).read_bytes())
        assert sha(block) == name.removesuffix('.jsonl.gz')
        data += block
    assert sha(data) == index['plain_sha256']
    assert len(data.splitlines()) == index['rows']
    return data


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--evidence',required=True,type=Path)
    args=parser.parse_args()
    print(json.dumps({'bytes':compact(args.evidence)}))
