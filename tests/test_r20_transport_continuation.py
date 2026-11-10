#!/usr/bin/env python3
"""compression-only tests; these never accept a gameplay capture."""
import gzip
import hashlib
import importlib.util
import contextlib
import copy
import io
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('r20_continuation_test', PROJECT / 'tools/finalize-r20-captured-parity.py')
T = importlib.util.module_from_spec(spec)
spec.loader.exec_module(T)


class TransportContinuation(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.source = self.root / 'source.gz'
        self.data = os.urandom(160_000)
        with gzip.open(self.source, 'wb') as stream:
            stream.write(self.data)
        self.final = patch.object(T.K, 'FINAL', self.root)
        self.final.start()
        self.gate = patch.object(T.B, 'gate', return_value=16_000_000_000)
        self.gate.start()

    def tearDown(self):
        self.gate.stop()
        self.final.stop()
        self.temp.cleanup()

    def test_exact_old_output_and_chunk_independence(self):
        old = T.K.transport(self.source, self.root / 'old.gz', 65536)
        first = T.bounded_transport(self.source, self.root / 'new.gz', 65536)
        other = T.bounded_transport(self.source, self.root / 'other.gz', 1021)
        self.assertEqual(old, first)
        self.assertEqual(first, other)
        self.assertEqual(first['raw_sha256'], hashlib.sha256(self.data).hexdigest())
        self.assertEqual(gzip.decompress((self.root / 'other.gz').read_bytes()), self.data)

    def test_only_two_tree_scans_independent_of_chunk_count(self):
        with patch.object(T, 'tree_state', wraps=T.tree_state) as scans:
            T.bounded_transport(self.source, self.root / 'new.gz', 1021)
        self.assertEqual(scans.call_count, 2)
        self.assertGreater(T.B.gate.call_count, 100)

    def test_preexisting_cap_refuses_without_creating_output(self):
        with patch.object(T.B, 'CAP', 0), self.assertRaises(T.K.Refused):
            T.bounded_transport(self.source, self.root / 'new.gz')
        self.assertFalse((self.root / 'new.gz').exists())

    def test_growing_output_refuses_and_preserves_source(self):
        sha = T.K.sha(self.source)
        initial = T.B.allocated_footprint(self.root)
        with patch.object(T.B, 'CAP', initial + 4096), self.assertRaises(T.K.Refused):
            T.bounded_transport(self.source, self.root / 'new.gz')
        self.assertEqual(T.K.sha(self.source), sha)
        self.assertTrue((self.root / 'new.gz').exists())

    def test_other_evidence_mutation_refuses(self):
        changed = self.root / 'other.json'
        changed.write_text('before')
        def gate():
            changed.write_text('changed')
            return 16_000_000_000
        with patch.object(T.B, 'gate', side_effect=gate), self.assertRaises(T.K.Refused):
            T.bounded_transport(self.source, self.root / 'new.gz')

    def test_existing_output_and_symlinks_refuse(self):
        target = self.root / 'new.gz'
        target.write_bytes(b'owned prior evidence')
        with self.assertRaises(T.K.Refused):
            T.bounded_transport(self.source, target)
        self.assertEqual(target.read_bytes(), b'owned prior evidence')
        target.unlink()
        target.symlink_to(self.root / 'missing')
        with self.assertRaises(T.K.Refused):
            T.bounded_transport(self.source, target)

    def test_invalid_chunk_refuses(self):
        for chunk in (0, -1, True, '1021'):
            with self.assertRaises(T.K.Refused):
                T.bounded_transport(self.source, self.root / 'new.gz', chunk)

    def fixture(self):
        report = {'ok': False, 'r20_final_gate': 'pending', 'routes': []}
        for number in range(16):
            name = 'breakwater-basic' if number == 0 else 'route-' + str(number)
            report['routes'].append({'name': name})
            value = {'runs': {}}
            for variant in ('old', 'new', 'toggle'):
                receipts = {}
                for stream in ('ghost.jsonl', 'trace.jsonl', 'observations.jsonl'):
                    path = self.root / name / variant / 'evaluator' / (stream + '.gz')
                    path.parent.mkdir(parents=True, exist_ok=True)
                    raw = (name + variant + stream).encode() * 16
                    path.write_bytes(gzip.compress(raw, compresslevel=6, mtime=123456))
                    receipts[stream] = {'gzip_sha256': T.K.sha(path), 'raw_sha256': hashlib.sha256(raw).hexdigest(),
                                        'raw_bytes': len(raw), 'lossless_verified': True}
                value['runs'][variant] = {'trace_compression': {'receipts': receipts}}
            T.D.write(self.root / name / 'result.json', value)
        T.D.write(self.root / 'REPORT-CAPTURE.json', report)
        T.D.write(self.root / 'REPORT.json', report)
        relative = 'breakwater-basic/old/evaluator/ghost.jsonl.gz'
        source = self.root / relative
        temp = source.with_suffix('.test-canonical')
        T.bounded_transport(source, temp)
        os.replace(temp, source)
        return report, {relative}

    def test_all_144_streams_and_prior_canonical_gzip_pass_original_guard(self):
        report, allowed = self.fixture()
        original = copy.deepcopy(report)
        with contextlib.redirect_stdout(io.StringIO()):
            T.finalize_capture(self.root, report, allowed, 'a' * 64, 'b' * 64)
        got = T.D.transport_guard(self.root, report)
        self.assertEqual(len(got['receipts']), 144)
        self.assertEqual(got['separate_processor_sha256'], 'a' * 64)
        self.assertEqual(T.K.load(self.root / 'REPORT-CAPTURE.json'), original)
        for row in got['receipts']:
            with gzip.open(self.root / row['path'], 'rb') as stream:
                raw = stream.read()
            self.assertEqual(hashlib.sha256(raw).hexdigest(), row['raw_sha256'])

    def test_changed_raw_stream_is_refused(self):
        report, allowed = self.fixture()
        path = self.root / next(iter(allowed))
        path.write_bytes(gzip.compress(b'different raw bytes', mtime=0))
        with contextlib.redirect_stdout(io.StringIO()), self.assertRaises(T.K.Refused):
            T.finalize_capture(self.root, report, allowed, 'a' * 64, 'b' * 64)

    def test_changed_unapproved_gzip_is_refused(self):
        report, allowed = self.fixture()
        path = self.root / 'breakwater-basic/old/evaluator/trace.jsonl.gz'
        with gzip.open(path, 'rb') as stream:
            raw = stream.read()
        path.write_bytes(gzip.compress(raw, mtime=0))
        with contextlib.redirect_stdout(io.StringIO()), self.assertRaises(T.K.Refused):
            T.finalize_capture(self.root, report, allowed, 'a' * 64, 'b' * 64)


if __name__ == '__main__':
    unittest.main()
