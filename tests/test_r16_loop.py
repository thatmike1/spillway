#!/usr/bin/env python3
"""r16 product loop driver: the godot loop test, then the recordings it produced read back as a
copied folder by tools/analyze-r16-runs.py.

1. runs tests/test_r16_loop.gd headless on an imported copy of the project, with its own XDG
   directories, and reads its summary.
2. copies every recording the loop wrote (all groups, plus the persistence profile's folder that
   was moved away as if copied off a desktop) into a fresh folder and analyzes it there: each
   file reads complete, its outcome matches what the game sealed, the fall is a respawn
   teleport (never travel), nothing is unexplained, and the style totals equal the seals.
3. a mixed folder: the same copies plus a truncated file, a flipped byte, an empty file and a
   text file. damaged files are labelled, never complete, and every valid neighbour's report is
   identical to its report in the clean folder.

python3 -I tests/test_r16_loop.py --project SRC --out DIR [--only GROUPS]
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

GODOT = Path(os.environ.get('GODOT', Path.home() / '.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64'))


def engine_env(root):
    env = {'PATH': os.environ.get('PATH', '/usr/bin:/bin'), 'HOME': str(Path.home()), 'LANG': 'C.UTF-8'}
    for name in ['XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME', 'XDG_STATE_HOME', 'XDG_RUNTIME_DIR']:
        path = root / name.split('_')[1].lower()
        path.mkdir(parents=True, exist_ok=True, mode=0o700)
        env[name] = str(path)
    return env


def analyze(project, folder, out):
    done = subprocess.run([sys.executable, '-I', str(project / 'tools/analyze-r16-runs.py'), str(folder), '--json', str(out), '--quiet'],
                          capture_output=True, text=True, timeout=600)
    report = json.loads(out.read_text()) if out.is_file() else {}
    return done.returncode, report


def main(argv):
    parser = argparse.ArgumentParser()
    parser.add_argument('--project', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--only', default='')
    args = parser.parse_args(argv)
    project, out = args.project.resolve(), args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    checks = []

    def check(name, ok, detail=''):
        checks.append({'name': name, 'ok': bool(ok), 'detail': str(detail)[:900]})
        print('%s %s%s' % ('ok  ' if ok else 'FAIL', name, '' if ok else '  (%s)' % str(detail)[:300]), flush=True)

    godot_out = out / 'godot'
    cmd = [str(GODOT), '--headless', '--audio-driver', 'Dummy', '--fixed-fps', '128', '--path', str(project), '--script', 'res://tests/test_r16_loop.gd', '--', '--out=%s' % godot_out]
    if args.only:
        cmd.append('--only=' + args.only)
    done = subprocess.run(cmd, cwd=project, env=engine_env(out / 'profile'), capture_output=True, text=True, timeout=1800)
    (out / 'godot.log').write_text(done.stdout + '\n' + done.stderr)
    summary = json.loads((godot_out / 'summary.json').read_text()) if (godot_out / 'summary.json').is_file() else {}
    check('godot loop test ran every check green', done.returncode == 0 and summary.get('failed') == 0 and summary.get('checks', 0) > 0,
          [done.returncode, summary.get('checks'), summary.get('failed'), [r['name'] for r in summary.get('results', []) if not r['ok']][:5]])
    errors = [line for line in (done.stdout + done.stderr).splitlines() if 'ERROR' in line]
    check('no engine error in the loop test log', not errors, errors[:5])

    copied = out / 'copied'
    if copied.exists():
        shutil.rmtree(copied)
    copied.mkdir()
    sources = [godot_out / 'runs']
    folder = (summary.get('notes') or {}).get('copied_folder')
    if folder:
        sources.append(Path(folder))
    count = 0
    for source in sources:
        if source.is_dir():
            for path in sorted(source.rglob('*.r16run*')):
                target = copied / path.relative_to(source.parent)
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(path, target)
                count += 1
    check('recordings were produced and copied', count >= 20, count)
    code, report = analyze(project, copied, out / 'analysis.json')
    runs = report.get('runs', [])
    check('the analyzer read the copied folder (exit 0)', code == 0 and len(runs) == count, [code, len(runs), count])
    statuses = {}
    for r in runs:
        statuses[r['status']] = statuses.get(r['status'], 0) + 1
    check('every copied recording reads complete', statuses == {'complete': count}, statuses)
    unexplained = [r['name'] for r in runs if r['discontinuities'].get('unexplained')]
    check('no recording has an unexplained teleport', not unexplained, unexplained[:5])
    falls = [r for r in runs if r.get('falls')]
    respawn_teleports = [t for r in falls for t in r['discontinuities'].get('teleports', []) if t.get('cause', t.get('kind')) == 'respawn']
    check('the fall is a respawn teleport inside its attempt, never travel', len(falls) >= 1 and len(respawn_teleports) >= 1,
          [(r['name'], r['falls'], r['discontinuities'].get('teleports')) for r in falls][:3])
    styled = [r for r in runs if (r.get('outcome') or {}).get('style') is not None]
    mismatch = [r['name'] for r in styled if r['style'].get('points') != r['outcome']['style'].get('score')]
    check('each seal\'s style score equals the style events the analyzer summed', styled and not mismatch, mismatch[:5])
    clean = [r for r in runs if (r.get('outcome') or {}).get('kind') == 'finish' and r['outcome'].get('clean')]
    check('clean finishes analyze as finished, clean and timed', clean and all(r['finished'] and r['clean_at_end'] and r['timer_start_tick'] is not None and r['finish_tick'] == r['last_tick'] for r in clean),
          [(r['name'], r['finished'], r['timer_start_tick'], r['finish_tick'], r['last_tick']) for r in clean][:3])
    ended = sorted({r.get('ended_by') for r in runs})
    check('outcomes cover finish, restart, practice, preset, loadout, map-free quit', {'finish', 'restart', 'practice', 'preset', 'quit'} <= set(ended), ended)

    # a mixed folder: damaged copies beside the valid files.
    mixed = out / 'mixed'
    if mixed.exists():
        shutil.rmtree(mixed)
    shutil.copytree(copied, mixed)
    victim = sorted(mixed.rglob('*.r16run'), key=lambda p: p.stat().st_size)[-1]
    data = victim.read_bytes()
    (mixed / 'damaged-truncated.r16run').write_bytes(data[: len(data) * 2 // 3])
    flipped = bytearray(data)
    flipped[len(flipped) // 2] ^= 0x10
    (mixed / 'damaged-flipped.r16run').write_bytes(bytes(flipped))
    (mixed / 'empty.r16run').write_bytes(b'')
    (mixed / 'notes.txt').write_text('not a recording\n')
    code, mixed_report = analyze(project, mixed, out / 'mixed-analysis.json')
    by_name = {r['name']: r for r in mixed_report.get('runs', [])}
    damaged = {n: by_name.get(n, {}).get('status') for n in ['damaged-truncated.r16run', 'damaged-flipped.r16run', 'empty.r16run']}
    check('damaged files are labelled and never complete', all(s not in (None, 'complete') for s in damaged.values()), damaged)
    clean_by_file = {str(Path(r['file']).relative_to(copied)): r for r in runs}
    differs = []
    for r in mixed_report.get('runs', []):
        rel = str(Path(r['file']).relative_to(mixed))
        if rel in clean_by_file:
            a, b = dict(r), dict(clean_by_file[rel])
            for k in ('file',):
                a.pop(k, None)
                b.pop(k, None)
            if a != b:
                differs.append(rel)
    check('every valid neighbour reads exactly as in the clean folder', not differs and len(clean_by_file) == count, differs[:3])
    check('the text file is listed as ignored', any('notes.txt' in str(x) for x in mixed_report.get('ignored', [])), mixed_report.get('ignored'))

    failed = [c for c in checks if not c['ok']]
    result = {'checks': len(checks), 'failed': len(failed), 'results': checks, 'godot': {'checks': summary.get('checks'), 'failed': summary.get('failed'), 'seconds': summary.get('seconds')},
              'recordings': count, 'statuses': statuses}
    (out / 'result.json').write_text(json.dumps(result, indent=1))
    print('r16 loop driver: %d checks, %d failed (godot %s checks, %s failed)' % (len(checks), len(failed), summary.get('checks'), summary.get('failed')))
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
