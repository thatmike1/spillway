#!/usr/bin/env python3
"""bounded Line Drive component proof; parent owns native and final release checks.

python3 -I tests/r19_line_drive_audit.py --out /tmp/r19-line-drive/final
"""
import argparse
import gzip
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[1]
SCRATCH = Path('/tmp/r19-line-drive')
GODOT = Path.home() / '.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64'
BASE = '640d06e6539b53da752f03bfddb64fb46310abb7'
CAP = 250 * 2**20


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text())


def rows(folder):
    with gzip.open(folder/'trace.jsonl.gz', 'rt') as stream:
        return [json.loads(line) for line in stream]


def budget():
    free = shutil.disk_usage('/home').free
    used = sum(p.stat().st_size for p in SCRATCH.rglob('*') if p.is_file())
    if free < 15_000_000_000 or used > CAP:
        raise RuntimeError(f'storage limit: home={free} scratch={used}')
    return free, used


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    out = args.out.resolve()
    if not out.is_relative_to(SCRATCH) or out == SCRATCH:
        parser.error('use a fresh directory within /tmp/r19-line-drive')
    out.mkdir(parents=True, exist_ok=False)
    minimum_free, peak_used = budget()
    source_before = {str(p.relative_to(PROJECT)):sha(p) for p in list((PROJECT/'scripts').glob('*.gd'))+list((PROJECT/'tests').glob('r19_line_drive*')) if p.is_file()}
    env = dict(os.environ, XDG_DATA_HOME=str(SCRATCH/'data'))
    executions, checks = [], []

    def engine(name, script, *extra):
        nonlocal minimum_free, peak_used
        folder = out/name
        command = [str(GODOT), '--headless', '--fixed-fps', '128', '--path', str(PROJECT),
                   '--script', 'res://tests/'+script, '--', '--out='+str(folder), *extra]
        with (out/(name+'.log')).open('w') as log:
            process = subprocess.Popen(command, env=env, cwd=PROJECT, stdout=log, stderr=subprocess.STDOUT)
            start = time.monotonic()
            try:
                while process.poll() is None:
                    free, used = budget()
                    minimum_free, peak_used = min(minimum_free, free), max(peak_used, used)
                    if time.monotonic()-start > 100:
                        raise RuntimeError('engine exceeded 100s bound')
                    time.sleep(.2)
            finally:
                if process.poll() is None:
                    process.kill()
                code = process.wait()
        log = (out/(name+'.log')).read_text()
        executions.append({'command': command, 'exit': code, 'log': str(out/(name+'.log'))})
        if code or any(s in log for s in ['SCRIPT ERROR', 'ERROR:', 'WARNING:']):
            raise RuntimeError(name+' failed:\n'+log[-6000:])
        return folder

    def check(ok, label):
        checks.append({'ok': bool(ok), 'check': label})

    earned = engine('earned', 'r19_line_drive_route.gd')
    replay = engine('replay', 'r19_line_drive_route.gd', '--tape='+str(earned/'events.tape.json'))
    summary, repeated_summary = read(earned/'summary.json'), read(replay/'summary.json')
    trace, repeated = rows(earned), rows(replay)
    check(summary['ok'] and summary['finish'] == 'clean' and summary['respawns'] == 0, 'actual R19 host/session earns clean whole course')
    check(summary['actual_v_mismatches'] == summary['rate_mismatch_ticks'] == 0, 'travel and128Hz rate observations agree')
    # node is controller bookkeeping, absent from open-loop decisions; all gameplay fields compare exactly.
    for row in trace+repeated:
        row.pop('node', None)
    check(trace == repeated and len(trace) > 1500, 'saved-input replay matches every retained gameplay telemetry field')
    check(read(earned/'events.tape.json') == read(replay/'events.tape.json'), 'replay preserves every saved input including within-tick mouse/key order')
    check(summary['launches'] == repeated_summary['launches'], 'all launch events replay exactly')
    launches = summary['launches']
    check([x['pad'] for x in launches] == ['LaunchWest','LaunchEast','LaunchHome'], 'each of three pads launches exactly once')
    for launch in launches:
        before, after = launch['before_u'], launch['after_u']
        before_speed = (before[0]**2+before[2]**2)**.5
        after_speed = (after[0]**2+after[2]**2)**.5
        check(before_speed >= 300 and after[1] == 480 and after_speed <= max(900,before_speed)+.0001,
              'measured speed/up/cap law: '+launch['pad'])
        check(launch['support']['body'].startswith(launch['pad']+'_') and launch['support']['normal'][1] >= .7,
              'real hull support body and walkable normal: '+launch['pad'])
        at = next(r for r in trace if r['motion']['tick'] == launch['tick']-1)
        probes = [p for p in at['pad_probes'] if p['id'] == launch['pad']]
        check(any(p['grounded'] and p['support'] and p['speed_u'] >= 300 and p['alignment'] >= .94 and not p['used'] for p in probes),
              'prior supported sample independently qualifies launch: '+launch['pad'])
    unsupported = [(r,p) for r in trace for p in r['pad_probes'] if not p['used'] and p['speed_u']>=300 and p['alignment']>=.94 and not p['support']]
    check(bool(unsupported) and all(not r['motion']['line_drive']['used'] or p['id'] not in r['motion']['line_drive']['used'] for r,p in unsupported),
          'real route: aligned fast airborne feet within pad bounds do not launch without hull support')
    for mode in ['standing','walking','wrong-way','once','lifecycle']:
        controls = engine(mode, 'r19_line_drive_controls.gd', '--mode='+mode)
        result = read(controls/'controls.json')
        check(result['ok'], 'actual input/host controls: '+mode)
    recovery = engine('recovery', 'r19_line_drive_recovery.gd')
    check(read(recovery/'recovery.json')['ok'], 'ordinary input misses to lower court then walks physical return ramp to start')
    geometry = engine('geometry', 'r19_line_drive_geometry.gd', '--recording='+summary['recordings'][0]['path'])
    check(read(geometry/'geometry.json')['ok'], 'numeric collision identity and original ghost acceptance/rejection')
    spec = importlib.util.spec_from_file_location('original_reader', PROJECT/'tools/analyze-r16-runs.py')
    reader = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(reader)
    records, alignment = [], []
    for folder in [earned,replay]:
        current = read(folder/'summary.json')
        recording = reader.read(Path(current['recordings'][0]['path']))
        check(recording.ok and current['recordings'][0]['ok'] and current['recordings'][0]['clean']['ok'] and current['recordings'][0]['observation_offsets'] == [33], 'original Python and Godot readers accept '+folder.name)
        c, obs = recording.columns, rows(folder)
        offsets = [offset for offset in range(30,37) if len(c['p_x'])-offset >= len(obs) and all(
            r['p'] == [c['p_x'][i+offset],c['p_y'][i+offset],c['p_z'][i+offset]] and
            r['v'] == [c['v_x'][i+offset],c['v_y'][i+offset],c['v_z'][i+offset]] and
            r['elapsed'] == c['elapsed'][i+offset] and r['yaw'] == c['yaw'][i+offset] and r['pitch'] == c['pitch'][i+offset] and
            r['checkpoint'] == c['checkpoint'][i+offset] and r['respawns'] == c['respawns'][i+offset]
            for i,r in enumerate(obs))]
        check(bool(offsets), 'recorded position/velocity/view/time/progress exactly match observed '+folder.name)
        check(all(v == 128 for v in c['physics_hz']) and all(v == 1/128 for v in c['dt']), 'every recorded tick is128Hz '+folder.name)
        records.append({'path':str(recording.path),'sha256':sha(recording.path),'ticks':len(c['tick'])})
        alignment.append({'run':folder.name,'offsets':offsets})
    protected = ['scripts/r15_source_player.gd','scripts/r14_source_player.gd','scripts/r14_source_motion.gd','scripts/r15_presets.gd']
    for name in protected:
        old = subprocess.check_output(['git','show',BASE+':projects/foldrunner/'+name],cwd=PROJECT)
        check((PROJECT/name).read_bytes() == old, 'frozen R15/F2 bytes: '+name)
    no_writes = ['tests/r19_line_drive_route.gd','tests/r14_practice_driver.gd','scripts/r19_line_drive_level.gd']
    pattern = re.compile(r'\bplayer\.(?:position|global_position|velocity|yaw|pitch|transform|global_transform)\s*[+*/-]?=(?!=)|\bplayer\.(?:set|reset_to|apply_settings)\s*\(|\bgame\.(?:checkpoint_index|elapsed|finished|_started|stage_times)\s*[+*/-]?=(?!=)')
    hits = [f'{name}:{i}:{line}' for name in no_writes for i,line in enumerate((PROJECT/name).read_text().splitlines(),1)
            if not line.lstrip().startswith('#') and pattern.search(line)]
    check(not hits, 'earned driver and map write no body/view/progress/velocity after host spawn')
    check('style.' not in (PROJECT/'scripts/r19_line_drive_level.gd').read_text(), 'map makes no authored scoring calls')
    owned = ['scripts/r19_line_drive_player.gd','scripts/r19_line_drive_level.gd','tests/r19_line_drive_host.gd',
             'tests/r19_line_drive_route.gd','tests/r19_line_drive_recovery.gd','tests/r19_line_drive_controls.gd','tests/r19_line_drive_geometry.gd','tests/r19_line_drive_audit.py']
    sources = owned+protected+['scripts/r19_main.gd','scripts/r19_hud.gd','scripts/r19_course_geometry.gd','tests/r14_practice_driver.gd']
    check(all(sha(PROJECT/name) == digest for name,digest in source_before.items()), 'all executed source files remain unchanged during audit')
    report = {'ok':all(c['ok'] for c in checks),'checks':checks,'executions':executions,'seconds':summary['time'],
              'samples':len(trace),'launches':launches,'identity':summary['identity'],'records':records,'record_alignment':alignment,
              'write_hits':hits,'minimum_home_free_bytes':minimum_free,'peak_scratch_bytes':peak_used,
              'sources_sha256':{name:sha(PROJECT/name) for name in sources},
              'limits':['headless component only; parent owns native/release/GPT review',
                        'input controller proves a route, not discovery or human enjoyment',
                        'standing/walking use labelled checkpoint fixture on an actual pad; unit checks are pure response only',
                        'saved-input equality proven on this engine/platform only; native Windows untested']}
    (out/'AUDIT.json').write_text(json.dumps(report,indent=1)+'\n')
    for c in checks:
        print(('PASS ' if c['ok'] else 'FAIL ')+c['check'])
    return 0 if report['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
