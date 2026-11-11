#!/usr/bin/env python3
"""Extract a private recorded-input clip fixture; this does not simulate a contact."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import sys

sys.dont_write_bytecode = True
READER = Path(__file__).with_name('analyze-r16-runs.py')
FLOOR = 15_000_000_000


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def reader_module():
    spec = importlib.util.spec_from_file_location('r21_clip_strict_reader', READER)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def destination(output, recording):
    output = Path(output)
    if not output.is_absolute() or output.exists():
        raise ValueError('output must be a new absolute directory under /tmp')
    for path in (output, *output.parents):
        if path.is_symlink():
            raise ValueError('output symlink refused')
    resolved = output.resolve()
    input_path = Path(recording).resolve()
    if (Path('/tmp') not in resolved.parents or resolved in input_path.parents
            or input_path.parent in resolved.parents):
        raise ValueError('private fixtures must stay under /tmp and outside the input tree')
    return resolved


def extract(recording, output, first, last):
    recording = Path(recording).resolve(strict=True)
    output = destination(output, recording)
    if type(first) is not int or type(last) is not int or first < 0 or last < first:
        raise ValueError('window must be an ordered nonnegative inclusive tick pair')
    if shutil.disk_usage('/home').free < FLOOR:
        raise ValueError('HOME free space is below 15 GB')
    before = sha(recording)
    reader = reader_module()
    rec = reader.read(recording)
    if not rec.ok or not rec.seal:
        raise ValueError('strict reader refused a complete sealed recording: ' + str(rec.errors))
    metadata = rec.header['metadata']
    if metadata['map'] != 'tether-yard' or metadata['preset'] != 'server128':
        raise ValueError('fixture requires recorded Tether Yard F2')
    if metadata['build'] != 'spillway-2026.11.10-r20' or rec.header['identity']['physics_hz'] != 128:
        raise ValueError('fixture requires the delivered R20 recording identity at 128 Hz')
    columns, inputs = rec.columns, rec.inputs
    selected = [i for i, tick in enumerate(columns['tick']) if first <= tick <= last]
    if [columns['tick'][i] for i in selected] != list(range(first, last + 1)):
        raise ValueError('requested observation window is incomplete')
    if not set(inputs['kind']) <= {1, 2, 3, 4}:
        raise ValueError('unhandled recorded input kind')
    raw = [{'tick': inputs['tick'][i], 'raw': {key: values[i] for key, values in inputs.items()}}
           for i, kind in enumerate(inputs['kind']) if kind in {1, 2, 3}]
    tape = {'format': 'spillway-momentum-tape', 'version': 2, 'physics_hz': 128,
            'duration_ticks': columns['tick'][-1] + 1, 'events': raw}
    expected = {'tick_columns': {key: [values[i] for i in selected] for key, values in columns.items()},
                'all_input_columns': inputs,
                'window_events': [row for row in rec.events if first <= row['t'] <= last]}
    provenance = {'schema': 1, 'source_recording': str(recording), 'source_sha256': before,
                  'extractor_sha256': sha(__file__),
                  'reader_sha256': sha(READER), 'header': rec.header, 'seal': rec.seal,
                  'window_inclusive': [first, last], 'window_samples': len(selected),
                  'raw_input_rows': len(raw), 'all_input_rows': len(inputs['tick']),
                  'source_sample_count': len(columns['tick']),
                  'ordering': 'inject raw rows in their stored order before the physics step whose post-step sample has that tick; action rows are derived by the unchanged host',
                  'initial_sample': {key: values[0] for key, values in columns.items()},
                  'limits': ['extraction only; not an engine replay or collider diagnosis',
                             'use normal authored R20 spawn and recorded model/reel/look settings; the first post-step sample is an expectation, never a placement',
                             'private human input/positions; do not commit or ship fixture payloads',
                             'full source trace must match before a changed-geometry comparison proves the reported approach']}
    blobs = {'inputs.tape.json': tape, 'expected.json': expected, 'provenance.json': provenance}
    encoded = {key: (json.dumps(value, ensure_ascii=False, separators=(',', ':')) + '\n').encode()
               for key, value in blobs.items()}
    if sum(map(len, encoded.values())) > 8 * 2**20:
        raise ValueError('fixture exceeds the 8 MiB extraction bound')
    if sha(recording) != before:
        raise ValueError('recording changed while reading')
    output.mkdir(parents=True)
    try:
        for name, data in encoded.items():
            (output / name).write_bytes(data)
        receipt = {'ok': True, 'source_sha256': before, 'extractor_sha256': sha(__file__),
                   'source_unchanged': sha(recording) == before,
                   'files': {name: {'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}
                             for name, data in encoded.items()}, 'window': [first, last],
                   'engine_run': False, 'raw_rows': len(raw), 'all_rows': len(inputs['tick'])}
        if not receipt['source_unchanged']:
            raise ValueError('recording changed while writing fixture')
        (output / 'EXTRACTION.json').write_text(json.dumps(receipt, indent=2) + '\n')
        return receipt
    except BaseException:
        shutil.rmtree(output)
        raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('recording', type=Path)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--first', type=int, required=True)
    parser.add_argument('--last', type=int, required=True)
    args = parser.parse_args()
    try:
        print(json.dumps(extract(args.recording, args.out, args.first, args.last), indent=2))
        return 0
    except (ValueError, OSError, KeyError) as error:
        print('r21-clip-fixture: ' + str(error), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
