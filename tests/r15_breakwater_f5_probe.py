#!/usr/bin/env python3
"""Audit retained input-only F5 breach evidence against frozen source resources."""
import argparse
import gzip
import hashlib
import json
from pathlib import Path


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load(path):
    if path.suffix == '.gz':
        return json.loads(gzip.decompress(path.read_bytes()))
    return json.loads(path.read_text())


def audit(evidence, source):
    baseline = load(evidence / 'frozen-resources.sha256.json.gz')
    changed = [name for name, digest in baseline.items() if sha(source / name) != digest]
    assert not changed, changed
    summaries = [load(evidence / run / 'summary.json') for run in ['attempt01', 'replay01']]
    probes = [load(evidence / run / 'probe.json') for run in ['attempt01', 'replay01']]
    tapes = [load(evidence / run / 'events.tape.json.gz') for run in ['attempt01', 'replay01']]
    traces = [[json.loads(line) for line in gzip.decompress((evidence / run / 'trace.jsonl.gz').read_bytes()).splitlines()]
              for run in ['attempt01', 'replay01']]
    for summary, probe in zip(summaries, probes):
        assert summary['finish_kind'] == 'clean' and summary['respawns'] == 0
        assert summary['finish_tick'] == 4374 and summary['finish_time_s'] == 33.9765625
        assert summary['preset'] == 'server128_aa1000' and summary['runner'] == 'res://scripts/r15_source_player.gd'
        assert summary['physics_hz'] == summary['engine_hz'] == 128
        assert summary['warmup_steps'] == 33 and summary['sensitivity_source_units'] == 2.5
        assert summary['record_key'] == '69631ffd4e89dcb1'
        assert summary['geometry_hash'] == '231b7675ad7dde95f4cf9afbf5a2a25eadf400fc08d232d522a6a7c8952058d3'
        assert [checkpoint['checkpoint'] for checkpoint in summary['checkpoints']] == list(range(5))
        assert all(a < b for a, b in zip(probe['actual_stage_times'], probe['actual_stage_times'][1:]))
        assert probe['actual_physics']['sv_airaccelerate'] == 1000.0
        assert probe['rate_ok'] and probe['clean_eligible']
        assert not any('gangway' in item['piece'] for item in summary['supports'])
        assert not summary['sinks']
        assert all(sha(source / path.removeprefix('res://')) == digest for path, digest in summary['sources_sha256'].items())
        assert sha(source / 'tests/r15_breakwater_f5_probe.gd') == probe['probe_sha256']
    assert probes[0]['actual_physics'] == probes[1]['actual_physics']
    assert probes[0]['probe_flights'] == probes[1]['probe_flights']
    breach = [flight for flight in probes[0]['probe_flights']
              if flight['last_ground'].get('piece') == 's4_runway_4' and flight['landing']['piece'] == 's4_head_nw']
    assert len(breach) == 1
    flight = breach[0]
    assert 'jump' in flight['first_air']['events']
    assert flight['first_air']['tick'] == 4085 and flight['landing']['tick'] == 4194
    assert all(not row['g'] for row in traces[0] if 4085 <= row['t'] < 4194)
    assert all(row['p'][0] < -71 for row in traces[0] if 4085 <= row['t'] <= 4194)
    def per_tick(events):
        ticks = {}
        for event in events:
            item = ticks.setdefault(event['tick'], {'keys': [], 'mouse': [0, 0]})
            if 'key' in event:
                item['keys'].append([event['key'], event['edge']])
            else:
                item['mouse'] = [a + b for a, b in zip(item['mouse'], event['mouse'])]
        return ticks
    assert per_tick(tapes[0]['events']) == per_tick(tapes[1]['events'])
    assert all(event.get('key') in [None, 'w', 'a', 's', 'd', 'space'] for event in tapes[0]['events'])
    assert all(event.get('mouse', [0, 0])[1] == 0 for event in tapes[0]['events'])
    assert len(traces[0]) == 4375 and len(traces[1]) == 4376
    for left, right in zip(*traces):
        assert {k: v for k, v in left.items() if k != 'n'} == {k: v for k, v in right.items() if k != 'n'}, left['t']
    for run in ['attempt01', 'replay01']:
        log = (evidence / run / 'run.log').read_text()
        assert 'ERROR' not in log and 'WARNING' not in log, log
    hashes = {str(path.relative_to(evidence)): sha(path) for path in sorted(evidence.rglob('*'))
              if path.is_file() and path.name != 'RESULTS.json'}
    return {
        'result': 'proven headless input-only controller line, replayed once open loop on actual r15 main',
        'full_attempts': 2, 'exploration_attempts': 1, 'failed_attempts': [],
        'finish_time_s': summaries[0]['finish_time_s'], 'finish_tick': 4374,
        'respawns': 0, 'stage_times_s': probes[0]['actual_stage_times'],
        'breach_flight': flight, 'physics': probes[0]['actual_physics'],
        'geometry_sha256': summaries[0]['geometry_hash'], 'course_key': summaries[0]['record_key'],
        'frozen_resource_files_verified': len(baseline), 'changed_frozen_resources': changed,
        'common_trace_ticks_equal_excluding_controller_node': 4375,
        'trace_precision': 'inherited rounded driver samples; full-precision flight endpoints equal',
        'input_comparison': 'exact key edges and summed relative mouse counts per tick; inherited replay groups keys before mouse within each tick',
        'replay_extra_tick': 'the tape includes a final neutral tick beyond the controller observation window',
        'limitations': ['state-aware controller, not human play or imperfect-input robustness',
                        'one exact open-loop replay, not a variation study',
                        'source headless proof only; no native rendering, packed acceptance or feel claim'],
        'sources_sha256': summaries[0]['sources_sha256'],
        'probe_sha256': probes[0]['probe_sha256'],
        'input_tape_uncompressed_sha256': hashlib.sha256(gzip.decompress((evidence / 'attempt01/events.tape.json.gz').read_bytes())).hexdigest(),
        'evidence_sha256': hashes,
    }


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--evidence', required=True, type=Path)
    parser.add_argument('--source', required=True, type=Path)
    args = parser.parse_args()
    print(json.dumps(audit(args.evidence, args.source), indent=2))
