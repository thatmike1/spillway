#!/usr/bin/env python3
"""independent R15 course challenge; isolated frozen source, bounded owned processes."""
from pathlib import Path
import argparse
import gzip
import hashlib
import importlib.util
import json
import os
import shutil
import subprocess
import tempfile
import sys
sys.dont_write_bytecode = True

P = Path(__file__).resolve().parents[1]
G = Path.home() / '.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64'
CASES = [
    ('sunken-court',case,'server128') for case in ['arch_return','east_cistern','causeway_hold','causeway_stand','causeway_release','practice_finish','restart','air_checkpoint','wrong_deck','side_contact','side_open','map_keys']
] + [
    ('rainline',case,'server128') for case in ['duct_release','duct_stand','reverse_duct','practice_finish','restart','air_checkpoint','wrong_deck','side_contact','side_open']
] + [
    ('night-shift',case,'server128') for case in ['throat_return','hatch_hold','hatch_release','hatch_stand','practice_finish','restart','air_checkpoint','wrong_deck','side_contact','side_open']
]

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    a = argparse.ArgumentParser(description=__doc__)
    a.add_argument('--out', type=Path, required=True)
    a.add_argument('--only', default='')
    args = a.parse_args()
    out = args.out.resolve()
    if out.is_relative_to(P):
        raise SystemExit('evidence must be outside source')
    if out.exists() and any(out.iterdir()):
        raise SystemExit('use a new empty output directory; retained trials are immutable')
    out.mkdir(parents=True, exist_ok=True)
    spec = importlib.util.spec_from_file_location('owner', P / 'tools/package-r15.py')
    owner = importlib.util.module_from_spec(spec)
    sys.path.insert(0, str(P/'tools'))
    spec.loader.exec_module(owner)
    spec = importlib.util.spec_from_file_location('trace_store', P / 'tests/r15_courses_review_store.py')
    trace_store = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(trace_store)
    tracked = [Path(os.fsdecode(r)) for r in subprocess.check_output(
        ['git', 'ls-files', '-z', '--', '.'], cwd=P).split(b'\0') if r]
    review = sorted(P.glob('tests/r15_courses_review*'))
    files = tracked + [p.relative_to(P) for p in review if p.relative_to(P) not in tracked]
    before = {str(r): digest(P/r) for r in tracked}
    result = {'base': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=P, text=True).strip(),
              'engine_sha256': digest(G), 'source_before': before, 'runs': [],
              'actors_before': {str(p.relative_to(P)):digest(p) for p in review},
              'helper_sha256': {name:digest(P/name) for name in ('tools/package-r15.py','tools/r14_native_display.py')}}
    work = Path(tempfile.mkdtemp(prefix='r15-courses-review-', dir='/home/thatmike1/foldrunner-build-2026-11-05'))
    src = work / 'source'
    src.mkdir()
    try:
        for rel in files:
            target = src/rel
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(P/rel, target)
        env = owner.engine_env(work/'profile')
        def run(name, cmd, budget=180):
            code, text = owner.run_engine(cmd, src, env, out/(name+'.log'), budget, cleanup_grace=10)
            if code or owner.ERRORS.search(text):
                raise RuntimeError((name, code, text[-3500:]))
            return text
        run('import', [str(G), '--headless', '--audio-driver', 'Dummy', '--path', str(src), '--import'])
        for uid in src.glob('tests/r15_courses_review*.gd.uid'):
            target = P / uid.relative_to(src)
            if not target.exists():
                shutil.copy2(uid, target)
        for map_id, case, preset in CASES:
            name = f'{map_id}-{case}-{preset}'
            if args.only and not any(part in name for part in args.only.split(',')):
                continue
            dest = out/name
            dest.mkdir(exist_ok=True)
            text = run(name, [str(G), '--headless', '--audio-driver', 'Dummy', '--fixed-fps', '128',
                              '--path', str(src), '--script', 'res://tests/r15_courses_review_routes.gd', '--',
                              '--out='+str(dest), '--map='+map_id, '--case='+case, '--preset='+preset])
            summary = json.loads((dest/'summary.json').read_text())
            with gzip.open(dest/'trace.jsonl.gz', 'rt') as f:
                rows = [json.loads(line) for line in f]
            assert len(rows) == summary['ticks']
            assert [r['t'] for r in rows] == list(range(len(rows)))
            assert all(r['rate_matches'] for r in rows)
            assert summary['actual_settings']['hull_width'] == 32
            assert summary['actual_settings']['hull_height'] == 72
            assert summary['actual_settings']['duck_hull_height'] == 54
            assert summary['actual_settings']['sv_airaccelerate'] == (1000 if preset.endswith('aa1000') else 100)
            assert summary['engine_hz'] == 128
            assert summary['runner'] == 'res://scripts/r15_source_player.gd'
            result['runs'].append({'name': name, 'ticks': len(rows), 'final': summary['final'],
                                   'side_ticks': summary['side_contact_ticks_abs_ny_lt_0_7'],
                                   'overlap_ticks': summary['interior_overlap_ticks'],
                                   'blocked_ticks': summary['stand_blocked_ticks'],
                                   'trace_sha256': digest(dest/'trace.jsonl.gz'),
                                   'summary_sha256': digest(dest/'summary.json')})
            (out/'PROGRESS.json').write_text(json.dumps(result, indent=2)+'\n')
            print(text.strip().splitlines()[-1], flush=True)
        result['ok'] = True
    finally:
        result['source_after'] = {str(r): digest(P/r) for r in tracked}
        result['sources_unchanged'] = result['source_before'] == result['source_after']
        result['review_sources'] = {str(p.relative_to(P)): digest(p) for p in review}
        result['profile_files'] = {}
        for cfg in out.rglob('review-profile.cfg'):
            result['profile_files'][str(cfg.relative_to(out))] = {'sha256':digest(cfg),'text':cfg.read_text()}
            cfg.unlink()
        shutil.rmtree(work)
        result['scratch_removed'] = not work.exists()
        trace_store.compact(out.parent)
        result['evidence_bytes'] = sum(p.stat().st_size for p in out.parent.rglob('*') if p.is_file())
        (out/'RESULTS.json').write_text(json.dumps(result, indent=2)+'\n')
    assert result['sources_unchanged']
    assert result['evidence_bytes'] < 15*1024*1024

if __name__ == '__main__':
    main()
