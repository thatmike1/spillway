#!/usr/bin/env python3
"""finish compression of an already closed R20 capture, then run the unchanged full audit."""
import argparse
import copy
import gzip
import hashlib
import json
import os
from pathlib import Path
import stat
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
import r20_candidate_core as K
D = K.module('r20_transport_continuation_driver', K.PROJECT / 'tools/check-r20-candidate-parity.py')
B = K.B


def tree_state(root, exclude=None):
    result = {}
    for path in root.rglob('*'):
        if path == exclude or not path.is_file():
            continue
        info = path.stat()
        K.need(not path.is_symlink() and stat.S_ISREG(info.st_mode), 'transport requires regular evidence files')
        result[str(path.relative_to(root))] = (info.st_ino, info.st_size, info.st_mtime_ns, info.st_blocks)
    return result


def bounded_transport(source, target, chunk=65536):
    K.need(type(chunk) is int and chunk > 0, 'positive transport chunk required')
    K.need(not target.exists() and not target.is_symlink(), 'transport scratch already exists')
    K.need(source.is_relative_to(K.FINAL) and target.is_relative_to(K.FINAL), 'transport outside final evidence')
    K.need(source.is_file() and not source.is_symlink(), 'transport source is not regular')
    before = tree_state(K.FINAL)
    initial = sum(info[3] * 512 for info in before.values())
    K.need(initial <= B.CAP, 'final scratch cap before compression')
    digest = hashlib.sha256()
    length = 0
    with gzip.open(source, 'rb') as incoming, target.open('xb') as packed:
        with gzip.GzipFile(filename='', mode='wb', fileobj=packed, mtime=0, compresslevel=6) as outgoing:
            for block in iter(lambda: incoming.read(chunk), b''):
                outgoing.write(block)
                digest.update(block)
                length += len(block)
                B.gate()
                K.need(initial + target.stat().st_blocks * 512 <= B.CAP, 'final scratch cap during compression')
    K.need(tree_state(K.FINAL, target) == before, 'other evidence changed during compression')
    K.need(initial + target.stat().st_blocks * 512 <= B.CAP, 'final scratch cap after compression flush')
    return {'raw_sha256': digest.hexdigest(), 'raw_bytes': length, 'gzip_sha256': K.sha(target)}


def finalize_capture(folder, report, allowed, processor_sha, stopped_sha):
    receipts = []
    for route in report['routes']:
        path = folder / route['name'] / 'result.json'
        result = K.load(path)
        backup = path.with_name('result-capture.json')
        if backup.exists():
            K.exact(result, K.load(backup), 'original result changed')
        else:
            D.write(backup, result)
        for variant, run in result['runs'].items():
            for name, receipt in run['trace_compression']['receipts'].items():
                source = path.parent / variant / 'evaluator' / (name + '.gz')
                relative = str(source.relative_to(folder))
                observed = K.sha(source)
                K.need(observed == receipt['gzip_sha256'] or relative in allowed, 'unreviewed changed gzip')
                temp = source.with_suffix('.canonicalizing')
                got = bounded_transport(source, temp)
                K.exact({k: got[k] for k in ('raw_sha256', 'raw_bytes')},
                        {k: receipt[k] for k in ('raw_sha256', 'raw_bytes')}, 'raw compression changed')
                test = source.with_suffix('.determinism')
                alternate = bounded_transport(temp, test, 1021)
                K.exact(got, alternate, 'chunk-size-dependent transport')
                if relative in allowed:
                    K.need(observed == got['gzip_sha256'], 'previously replaced stream is not canonical')
                test.unlink()
                receipt['streamed_gzip_sha256'] = receipt['gzip_sha256']
                receipt['gzip_sha256'] = got['gzip_sha256']
                os.replace(temp, source)
                receipts.append({'path': relative, **copy.deepcopy(receipt)})
        D.write(path, result)
        print(json.dumps({'transport_route_complete': route['name']}), flush=True)
    K.need(len(receipts) == 144, 'all 144 streams required')
    transport = {'ok': True, 'determinism_different_chunk_sizes': True, 'receipts': receipts,
                 'capture_report_sha256': K.sha(folder / 'REPORT-CAPTURE.json'),
                 'helper_sha256': K.sha(K.PROJECT / 'tools/check-r20-candidate-parity.py'),
                 'separate_processor_sha256': processor_sha, 'stopped_inventory_sha256': stopped_sha}
    D.write(folder / 'TRANSPORT.json', transport)
    report['transport'] = {'sha256': K.sha(folder / 'TRANSPORT.json')}
    D.write(folder / 'REPORT.json', report)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('candidate', 'scoring-contract-sha256', 'identity-contract-sha256', 'processor-sha256', 'stopped-inventory-sha256'):
        parser.add_argument('--' + name, required=True)
    for name in ('baseline-dir', 'runtime-freeze', 'runtime-identity', 'scoring-contract', 'identity-contract', 'out'):
        parser.add_argument('--' + name, type=Path, required=True)
    args = parser.parse_args(argv)
    K.need(K.sha(Path(__file__)) == args.processor_sha256, 'unreviewed compression processor')
    prepared = D.preflight(args)
    folder = args.out.resolve()
    K.need(folder == K.FINAL, 'wrong capture folder')
    report = K.load(folder / 'REPORT.json')
    K.matrix_guard(report)
    K.need(report['candidate_commit'] == args.candidate and report['capture_complete'] is True,
           'all 48 actual capture plays must already be complete')
    K.need(report['source_postflight']['ok'] is True and report['cleanup']['source_import_profile_removed'] is True,
           'source postflight and cleanup required')
    K.need(all(not (folder / name).exists() for name in ('source', 'profile', 'import')), 'capture engines must be closed')
    K.exact(report['inputs'], prepared[-1], 'capture inputs or helpers changed')
    K.need('transport' not in report and not (folder / 'TRANSPORT.json').exists(), 'transport already finalized')
    original = folder / 'REPORT-CAPTURE.json'
    K.need(original.is_file(), 'retained original capture report required')
    K.exact(report, K.load(original), 'capture report changed after stopped finalization')
    stopped_path = folder / 'stopped-transport/STOPPED-INVENTORY.json'
    stopped = K.checked_json(stopped_path, args.stopped_inventory_sha256)
    K.need(stopped['candidate_commit'] == args.candidate and stopped['stream_count'] == 144
           and stopped['raw_stream_hashes_and_lengths_match'] is True, 'stopped raw inventory incomplete')
    K.need(stopped['capture_report_sha256'] == K.sha(original), 'stopped capture report changed')
    stopped_streams = {row['path']: row for row in stopped['streams']}
    K.need(len(stopped_streams) == 144, 'stopped stream inventory has duplicates')
    # only this explicitly reviewed stream was replaced by the original finalizer before it stopped.
    allowed = {'breakwater-basic/old/evaluator/ghost.jsonl.gz'}
    changed = set()
    inputs = {}
    for route in report['routes']:
        path = folder / route['name'] / 'result.json'
        value = K.load(path)
        backup = path.with_name('result-capture.json')
        if backup.exists():
            K.exact(value, K.load(backup), 'partially replaced route result requires separate recovery')
        for variant, run in value['runs'].items():
            for name, receipt in run['trace_compression']['receipts'].items():
                stream = path.parent / variant / 'evaluator' / (name + '.gz')
                relative = str(stream.relative_to(folder))
                observed = K.sha(stream)
                row = stopped_streams[relative]
                K.need(row['gzip_sha256_expected'] == receipt['gzip_sha256'] and row['gzip_sha256_actual'] == observed,
                       'stopped compressed receipt changed')
                K.need(row['raw_sha256_expected'] == row['raw_sha256_actual'] == receipt['raw_sha256']
                       and row['raw_bytes_expected'] == row['raw_bytes_actual'] == receipt['raw_bytes'],
                       'stopped decompressed receipt changed')
                if observed != receipt['gzip_sha256']:
                    changed.add(relative)
                K.need(not stream.with_suffix('.canonicalizing').exists()
                       and not stream.with_suffix('.determinism').exists(), 'retain stopped scratch under a labelled path first')
                inputs[str(stream.relative_to(folder))] = dict(receipt)
    K.need(len(inputs) == 144, 'all original 144 compressed streams required')
    K.exact(changed, allowed, 'unreviewed already replaced gzip set')
    receipt = folder / 'TRANSPORT-PROCESSOR.json'
    K.need(not receipt.exists(), 'continuation receipt already exists; inspect before retrying')
    entry = {'schema': 1, 'status': 'started', 'processor_sha256': args.processor_sha256,
             'capture_commit': args.candidate, 'capture_report_sha256': K.sha(original),
             'original_driver_sha256': K.sha(K.PROJECT / 'tools/check-r20-candidate-parity.py'),
             'original_core_sha256': K.sha(K.PROJECT / 'tools/r20_candidate_core.py'),
             'stopped_inventory_sha256': args.stopped_inventory_sha256,
             'already_canonicalized_streams': sorted(allowed),
             'capture_helpers': K.helpers(), 'original_streams': inputs,
             'scope': 'compression-only continuation; all original 48 plays and postflight retained; no engine or physical/scoring/input comparator replacement',
             'resource_accounting': 'closed evidence tree before/after each stream, initial allocated blocks plus only growing target checked each chunk, unchanged HOME gate each chunk'}
    D.write(receipt, entry)
    finalize_capture(folder, report, allowed, args.processor_sha256, args.stopped_inventory_sha256)
    entry['status'] = 'transport_complete'
    entry['transport_sha256'] = K.sha(folder / 'TRANSPORT.json')
    D.write(receipt, entry)
    # the original verifier rehashes all gzip and decompressed bytes, then applies every original comparison and negative control.
    result = D.verify(args, prepared)
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
