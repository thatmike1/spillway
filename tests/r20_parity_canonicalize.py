#!/usr/bin/env python3
"""finalize deterministic gzip transport without changing one decompressed observation byte."""
import argparse
import gzip
import hashlib
import importlib.util
import json
from pathlib import Path
import os
import shutil
import sys

sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('r20_transport_checker',PROJECT/'tools/check-r20-parity.py')
C = importlib.util.module_from_spec(spec)
spec.loader.exec_module(C)


def canonical(source,target,block_size=65536):
    assert not target.exists(), 'existing transport scratch requires inspection'
    initial_footprint = C.allocated_footprint(C.SCRATCH)
    digest = hashlib.sha256()
    length = 0
    with gzip.open(source,'rb') as incoming,target.open('wb') as packed:
        with gzip.GzipFile(filename='',mode='wb',fileobj=packed,mtime=0,compresslevel=6) as outgoing:
            for block in iter(lambda:incoming.read(block_size),b''):
                outgoing.write(block)
                digest.update(block)
                length += len(block)
                C.gate()
                assert initial_footprint + target.stat().st_blocks*512 <= C.CAP, 'canonical transport exceeds owned scratch cap'
    return {'raw_sha256':digest.hexdigest(),'raw_bytes':length,'gzip_sha256':C.sha(target)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('folder',type=Path)
    args = parser.parse_args()
    folder = args.folder.resolve()
    assert folder == C.SCRATCH
    report = json.loads((folder/'REPORT.json').read_text())
    assert report['ok'] and report['cleanup']['source_import_profile_removed'], 'capture must be complete and no engine source remains'
    assert 'transport_canonicalization' not in report, 'already canonicalized; never rewrite history'
    C.gate()
    shutil.copy2(folder/'REPORT.json',folder/'REPORT-CAPTURE.json')
    receipts = []
    for route in report['routes']:
        path = folder/route['name']/'result.json'
        result = json.loads(path.read_text())
        shutil.copy2(path,path.with_name('result-capture.json'))
        for variant,run in result['runs'].items():
            for name,receipt in run['trace_compression']['receipts'].items():
                source = path.parent/variant/'evaluator'/(name+'.gz')
                assert C.sha(source) == receipt['gzip_sha256'], 'streamed transport changed before finalization'
                target = source.with_name(source.name+'.canonicalizing')
                got = canonical(source,target)
                assert got['raw_sha256'] == receipt['raw_sha256'] and got['raw_bytes'] == receipt['raw_bytes'], 'canonicalization changed raw evidence'
                verified = hashlib.sha256()
                with gzip.open(target,'rb') as incoming:
                    for block in iter(lambda:incoming.read(65536),b''):
                        verified.update(block)
                assert verified.hexdigest() == receipt['raw_sha256'], 'canonical stream verification failed'
                receipt['streamed_gzip_sha256'] = receipt['gzip_sha256']
                receipt['gzip_sha256'] = got['gzip_sha256']
                receipt['canonical_transport'] = 'zero header time/name; no timing-dependent intermediate zlib flushes'
                os.replace(target,source)
                receipts.append({'path':str(source.relative_to(folder)),**receipt})
        C.write(path,result)
    # feed the same actual raw trace to the compressor with different chunk sizes.
    source = folder/receipts[0]['path']
    target = folder/'determinism-check.gz'
    alternate = canonical(source,target,1021)
    assert alternate['gzip_sha256'] == C.sha(source), 'gzip depends on input chunk timing'
    target.unlink()
    output = {'ok':True,'script_sha256':C.sha(Path(__file__)),
              'capture_report_sha256':C.sha(folder/'REPORT-CAPTURE.json'),
              'determinism_different_chunk_sizes':True,'receipts':receipts,
              'scope':'lossless compression transport only; original result/capture helper and streamed hashes preserved'}
    C.write(folder/'TRANSPORT.json',output)
    report['transport_canonicalization'] = {'path':str(folder/'TRANSPORT.json'),'sha256':C.sha(folder/'TRANSPORT.json')}
    C.write(folder/'REPORT.json',report)
    print(json.dumps({'ok':True,'streams':len(receipts),'determinism_different_chunk_sizes':True}))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
