#!/usr/bin/env python3
"""run bounded, headless Fall Line component gates on the actual R19 host.

python3 -I tests/r19_fall_line_verify.py --out /tmp/r19-fall-line/check
"""
import argparse
import gzip
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[1]
SCRATCH = Path('/tmp/r19-fall-line')
CAP = 250 * 2**20
BASE = '640d06e6539b53da752f03bfddb64fb46310abb7'
GODOT = Path.home() / '.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64'


def budget():
    free = shutil.disk_usage('/home').free
    size = sum(p.stat().st_size for p in SCRATCH.rglob('*') if p.is_file())
    if free < 15_000_000_000 or size > CAP:
        raise RuntimeError(f'budget failed: /home free={free}, scratch={size}')
    return free, size


def read_json(path):
    return json.loads(path.read_text())


def rows(path):
    with gzip.open(path / 'trace.jsonl.gz', 'rt') as stream:
        return [json.loads(line) for line in stream]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    out = args.out.resolve()
    if not out.is_relative_to(SCRATCH) or out == SCRATCH:
        parser.error('output must be a fresh subdirectory under /tmp/r19-fall-line')
    out.mkdir(parents=True, exist_ok=False)
    minimum_free, peak_scratch = budget()
    runs = []

    def engine(name, script, *extra):
        nonlocal minimum_free, peak_scratch
        dest = out / name
        command = [str(GODOT), '--headless', '--fixed-fps', '128', '--path', str(PROJECT),
                   '--script', 'res://tests/' + script, '--', '--out=' + str(dest), *extra]
        with (out / (name + '.log')).open('w') as log:
            child = subprocess.Popen(command, cwd=PROJECT, stdout=log, stderr=subprocess.STDOUT)
            start = time.monotonic()
            try:
                while child.poll() is None:
                    free, used = budget()
                    minimum_free, peak_scratch = min(minimum_free, free), max(peak_scratch, used)
                    if time.monotonic() - start > 100:
                        raise RuntimeError('engine exceeded100s bound')
                    time.sleep(.2)
            finally:
                if child.poll() is None:
                    child.kill()
                code = child.wait()
        log_text = (out / (name + '.log')).read_text()
        runs.append({'name': name, 'command': command, 'exit': code, 'log': str(out / (name+'.log'))})
        if code or any(s in log_text for s in ['SCRIPT ERROR', 'ERROR:', 'WARNING: ObjectDB']):
            raise RuntimeError(f'{name} failed: {log_text[-3000:]}')
        return dest

    run = engine('earned', 'r19_fall_line_route.gd', '--max-ticks=6000')
    replay = engine('replay', 'r19_fall_line_route.gd', '--tape=' + str(run/'events.tape.json'))
    laws = engine('laws', 'r19_fall_line_laws.gd', '--max-ticks=3000')
    checkpoint = engine('checkpoint', 'r19_fall_line_laws.gd', '--checkpoint=yes', '--max-ticks=3000')
    physical_return = engine('return', 'r19_fall_line_laws.gd', '--return=yes', '--max-ticks=3000')
    recovery = engine('recovery', 'r19_fall_line_route.gd', '--route=recovery', '--max-ticks=6000')
    summary = read_json(run/'summary.json')
    samples, repeated = rows(run), rows(replay)
    checks = []

    def check(ok, label):
        checks.append({'ok': bool(ok), 'check': label})

    check(summary['pass'] and summary['finish_kind'] == 'clean' and 12 <= summary['elapsed'] <= 35,
          'actual R19 host/session earned clean route within design target')
    check(summary['runner'] == 'res://scripts/r15_source_player.gd' and summary['identity']['preset'] == 'server128',
          'pure frozen F2 source runner')
    check(summary['actual_v_mismatches'] == summary['rate_mismatch_ticks'] == 0, 'body travel and physics rate observations agree')
    check(samples == repeated and len(samples) > 2500, 'every saved-input replay field equals earned trace including platform states and clock')
    check(summary['transitions'] == read_json(replay/'summary.json')['transitions'], 'saved-input replay preserves every support/drop event')
    transitions = summary['transitions']
    supports = [r for r in transitions if r['event'] == 'support']
    drops = [r for r in transitions if r['event'] == 'drop']
    check(len(supports) == len(drops) == 7 and all(r['player_grounded'] and r['normal_y'] >= .7 for r in supports),
          'all seven falling decks armed by grounded real support hull contact')
    check(all(r['tick'] - r['armed'] == 256 for r in drops), 'collision drops exactly256 physics steps after support, two seconds at128Hz')
    check(all(bool(p[5]) == (not p[3]) and int(p[4]) == (0 if p[3] else 1) for r in samples for p in r['platforms']),
          'actual space ray queries confirm advertised collision presence on every sample')
    for support in supports:
        at = next(r for r in samples if r['clock'] == support['tick'])
        check(at['grounded'], 'support starts on grounded sample for '+support['id'])
    geometry = read_json(run/'geometry.json')
    check(geometry['ok'] and geometry['max_extent_m'] <= 32 and len(geometry['pieces']) > 20,
          'every collision prism matches full hashed geometry, bounded32m, no Area triggers')
    check(read_json(laws/'laws.json')['pass'], 'pause/fall/F/R/original-map lifecycle gates pass')
    check(read_json(physical_return/'laws.json')['pass'], 'earned physical return ramp reaches start and R restores collision')
    check(read_json(checkpoint/'laws.json')['pass'], 'earned nonzero checkpoint practice restores dropped collision')
    recovery_summary = read_json(recovery/'summary.json')
    check(recovery_summary['pass'] and recovery_summary['elapsed'] > summary['elapsed'], 'wider lower recovery line earns slower clean finish')
    spec = importlib.util.spec_from_file_location('original_reader', PROJECT/'tools/analyze-r16-runs.py')
    reader = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(reader)
    offsets = []
    records = []
    for folder in [run, replay, recovery]:
        current = read_json(folder/'summary.json')
        recording = reader.read(Path(current['recordings'][0]['path']))
        check(recording.ok and current['recordings'][0]['ok'] and current['recordings'][0]['clean_finish']['ok'],
              'original Godot and Python readers accept clean finish for '+folder.name)
        records.append({'path': str(recording.path), 'sha256': sha(recording.path), 'ticks':len(recording.columns['tick'])})
        trace = rows(folder)
        c = recording.columns
        align = [offset for offset in range(30,37) if len(c['p_x'])-offset >= len(trace) and all(
            r['p'] == [c['p_x'][i+offset],c['p_y'][i+offset],c['p_z'][i+offset]] and
            r['v'] == [c['v_x'][i+offset],c['v_y'][i+offset],c['v_z'][i+offset]] and
            r['elapsed'] == c['elapsed'][i+offset] and r['checkpoint'] == c['checkpoint'][i+offset]
            for i,r in enumerate(trace))]
        offsets.append({'run':folder.name,'offsets':align})
        check(bool(align), 'recording position/velocity/clock/checkpoint exactly align with retained trace for '+folder.name)
        check(all(x == 128 for x in c['physics_hz']) and all(x == 1/128 for x in c['dt']), 'recorded128Hz per-tick law for '+folder.name)
    protected = ['scripts/r15_source_player.gd','scripts/r14_source_player.gd','scripts/r14_source_motion.gd','scripts/r15_presets.gd']
    for name in protected:
        frozen = subprocess.check_output(['git','show',f'{BASE}:projects/foldrunner/{name}'],cwd=PROJECT)
        check((PROJECT/name).read_bytes() == frozen, 'frozen F2 dependency byte-identical: '+name)
    owned = ['scripts/r19_fall_line_level.gd','tests/r19_fall_line_host.gd','tests/r19_fall_line_route.gd',
             'tests/r19_fall_line_laws.gd','tests/r19_fall_line_geometry.gd','tests/r14_practice_driver.gd']
    pattern = re.compile(r'\bplayer\.(?:position|global_position|velocity|yaw|pitch|transform|global_transform)\s*[+*/-]?=(?!=)|\bplayer\.(?:set|reset_to|apply_settings)\s*\(|\bgame\.(?:checkpoint_index|elapsed|finished|_started|stage_times)\s*[+*/-]?=(?!=)')
    hits = [f'{name}:{i}:{line}' for name in owned for i,line in enumerate((PROJECT/name).read_text().splitlines(),1)
            if not line.lstrip().startswith('#') and pattern.search(line)]
    check(not hits, 'controller and level perform no pose/velocity/view/progress writes')
    check('style.' not in (PROJECT/owned[0]).read_text(), 'level awards no authored style points')
    report = {'ok':all(c['ok'] for c in checks),'checks':checks,'earned_seconds':summary['elapsed'],
              'recovery_seconds':recovery_summary['elapsed'],'geometry_hash':summary['geometry'],'records':records,
              'samples':len(samples),'recording_alignment':offsets,'runs':runs,'write_hits':hits,
              'minimum_home_free_bytes':minimum_free,'peak_owned_scratch_bytes':peak_scratch,
              'sources_sha256':{name:sha(PROJECT/name) for name in owned+protected+['scripts/r19_main.gd','tests/r19_fall_line_verify.py']},
              'limits':['headless component evidence; parent owns native rendering and release gates',
                        'coordinate-aware input controller proves one route; no human enjoyment verdict',
                        'exact saved-input replay tested on this engine/platform only']}
    (out/'AUDIT.json').write_text(json.dumps(report,indent=1)+'\n')
    for c in checks:
        print(('PASS ' if c['ok'] else 'FAIL ')+c['check'])
    return 0 if report['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
