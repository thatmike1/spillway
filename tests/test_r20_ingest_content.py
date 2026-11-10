#!/usr/bin/env python3
"""exercise actual recording envelopes and mixed bundles through the offline ingester."""
import hashlib
import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile
import zlib

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
import r20_run_bundle as bundle


def recording(outcome, compressed=False, zero_declared=False, metadata=None):
    meta = {'map': 'generated-review-fixture', 'preset': 'server128', 'build': 'generated'}
    if metadata is not None:
        meta.update(metadata)
    header = json.dumps({'format': 'foldrunner-r16-run', 'version': 1,
        'metadata': meta,
        'identity': {}}).encode()
    prefix = b'FRR16RUN' + struct.pack('<HHI', 1, 0, len(header))
    chain = hashlib.sha256(prefix + header).digest()
    raw = json.dumps({'counts': {'ticks': 0, 'inputs': 0, 'events': 0}, 'outcome': outcome}).encode()
    if zero_declared:
        stored = zlib.compress(b'x' * 1048576)
        kind, codec, declared = 1, 1, 0
    else:
        stored = zlib.compress(raw) if compressed else raw
        kind, codec, declared = 2, int(compressed), len(raw)
    head = struct.pack('<4sBBHIIIII', b'CHNK', kind, codec, 0, 0, declared, len(stored), 0, 0)
    return prefix + header + chain + head + hashlib.sha256(chain + head + stored).digest() + stored


class ImportedContent(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='r20-ingest-content-')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)

    def ingest(self, payloads):
        path = self.root / 'received.zip'
        manifest = {'format': bundle.FORMAT, 'schema': 1, 'player': 'Generated fixture',
            'build': 'generated', 'created_utc': '2026-11-10T00:00:00Z', 'current_profile': '',
            'entries': [{'path': 'recordings/' + name, 'size': len(data),
                'sha256': hashlib.sha256(data).hexdigest()} for name, data in payloads.items()]}
        with zipfile.ZipFile(path, 'w', compression=zipfile.ZIP_STORED) as archive:
            for name, data in payloads.items():
                archive.writestr('recordings/' + name, data)
            archive.writestr('manifest.json', json.dumps(manifest))
        result = bundle.ingest(path, self.root / 'players', 'Generated collector')
        self.assertTrue(result['ok'])
        target = Path(result['path'])
        for name, data in payloads.items():
            self.assertEqual((target / 'recordings' / name).read_bytes(), data)
        self.assertTrue((target / 'ANALYSIS.md').is_file())
        return {row['name']: row for row in json.loads((target / 'analysis.json').read_text())['attempts']}

    def test_zero_declared_compressed_chunk_never_reaches_inflater(self):
        payloads = {'good.r16run': recording({'kind': 'quit'}),
            'zero.r16run': recording({'kind': 'quit'}, zero_declared=True)}
        with patch.object(zlib, 'decompressobj', side_effect=AssertionError('unbounded inflater called')) as inflater:
            rows = self.ingest(payloads)
        inflater.assert_not_called()
        self.assertEqual(rows['good.r16run']['classification'], 'complete')
        self.assertEqual(rows['zero.r16run']['classification'], 'corrupt')
        self.assertIn('zero decoded length', rows['zero.r16run']['errors'][0])

    def test_positive_declared_compressed_seal_remains_supported(self):
        original = zlib.decompressobj
        calls = []
        class Observe:
            def __init__(self, *args, **kwargs):
                self.inner = original(*args, **kwargs)
            def decompress(self, data, max_length=0):
                calls.append(max_length)
                return self.inner.decompress(data, max_length)
            def __getattr__(self, key):
                return getattr(self.inner, key)
        with patch.object(zlib, 'decompressobj', Observe):
            rows = self.ingest({'good.r16run': recording({'kind': 'quit'}, compressed=True)})
        self.assertEqual(rows['good.r16run']['classification'], 'complete')
        self.assertTrue(calls and all(n > 0 for n in calls))

    def test_malformed_outcome_kinds_do_not_abort_valid_neighbor(self):
        values = [[], {}, 7, None, '', 'bad\nkind', 'x' * 129]
        payloads = {'good.r16run': recording({'kind': 'quit'})}
        payloads.update({f'bad-{i}.r16run': recording({'kind': value}) for i, value in enumerate(values)})
        rows = self.ingest(payloads)
        self.assertEqual(rows['good.r16run']['classification'], 'complete')
        self.assertTrue(all(rows[f'bad-{i}.r16run']['classification'] == 'corrupt' for i in range(len(values))))

    def test_non_dictionary_outcome_is_preserved_as_corrupt(self):
        rows = self.ingest({'good.r16run': recording({'kind': 'quit'}), 'bad.r16run': recording([])})
        self.assertEqual(rows['good.r16run']['classification'], 'complete')
        self.assertEqual(rows['bad.r16run']['classification'], 'corrupt')

    def test_unfamiliar_typed_outcome_is_reported_without_a_finish_claim(self):
        rows = self.ingest({'custom.r16run': recording({'kind': 'custom-boundary'})})
        self.assertEqual(rows['custom.r16run']['classification'], 'complete')
        self.assertEqual(rows['custom.r16run']['outcome']['kind'], 'custom-boundary')

    def test_invalid_unicode_values_and_keys_stay_with_the_bad_attempt(self):
        variants = [{'map': '\ud800'}, {'preset': '\udfff'}, {'extra': {'\ud800': 'value'}},
            {'extra': {'label': '\ud800'}}, {'build_label': '\udfff'}]
        payloads = {'good.r16run': recording({'kind': 'quit'}, compressed=True)}
        payloads.update({f'bad-{i}.r16run': recording({'kind': 'quit'}, compressed=True, metadata=meta)
            for i, meta in enumerate(variants)})
        payloads['bad-outcome.r16run'] = recording({'kind': '\ud800'}, compressed=True)
        rows = self.ingest(payloads)
        self.assertEqual(rows['good.r16run']['classification'], 'complete')
        for name in payloads:
            if name != 'good.r16run':
                self.assertEqual(rows[name]['classification'], 'corrupt')
                self.assertIn('Unicode', rows[name]['errors'][0])

    def test_valid_unicode_metadata_remains_complete_and_readable(self):
        rows = self.ingest({'unicode.r16run': recording({'kind': 'quit'}, compressed=True,
            metadata={'map': 'Žluťoučký dvůr 東京', 'preset': 'přítel'})})
        self.assertEqual(rows['unicode.r16run']['classification'], 'complete')


if __name__ == '__main__':
    unittest.main(verbosity=2)
