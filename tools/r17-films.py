#!/usr/bin/env python3
"""capture real R17 input-tape play; keep full scratch in RAM and retain an honest excerpt."""
import argparse
import gzip
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import sys
sys.dont_write_bytecode = True
import time

ROOT = Path('/home/thatmike1/foldrunner-build-2026-11-05')
PROJECT = Path(__file__).resolve().parents[1]
OUT = ROOT/'look/evidence/r17-movies'
FLOOR = 15_000_000_000

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def gate():
    free = shutil.disk_usage('/home').free
    if free < FLOOR:
        raise RuntimeError(f'HOME reserve crossed: {free}')
    return free

def speed(row):
    v = row.get('post',{}).get('v',[0,0,0])
    return math.hypot(v[0],v[2])/.0254

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('map')
    parser.add_argument('--preset',choices=['server128','server128_aa1000','quake3_inspired128'])
    parser.add_argument('--seconds',type=float)
    parser.add_argument('--evidence-root',type=Path,default=OUT)
    parser.add_argument('--movie-dir',type=Path,default=ROOT/'look')
    args=parser.parse_args()
    routes=json.loads((ROOT/'delivery/spillway-r16/VERIFICATION.json').read_text())['routes']
    route=next(r for r in routes if r['map']==args.map and (args.map!='night-shift' or r['name']=='night-f5-earned'))
    out=args.evidence_root.resolve()/args.map
    out.mkdir(parents=True,exist_ok=False)
    spec=importlib.util.spec_from_file_location('tape',PROJECT/'tools/momentum-tape.py')
    tape=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(tape)
    raw=json.loads(Path(route['tape']).read_text())
    expanded=tape.expand(raw)
    with gzip.open(route['reference'],'rt') as f:
        first=next((json.loads(line)['tick'] for line in f if speed(json.loads(line))>=300),None)
    target=int(args.seconds*128) if args.seconds else ((first or 1280)+1280)
    duration=min(expanded['duration_ticks'],target)
    expanded['duration_ticks']=duration
    expanded['duration_s']=duration/128
    expanded['events']=[e for e in expanded['events'] if e['tick']<duration]
    expanded['description']='R17 native excerpt: prefix of retained R16 input; no state-driven steering or physical state writes'
    (out/'input.expanded.json').write_text(json.dumps(expanded)+'\n')
    before=gate()
    head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=PROJECT,text=True).strip()
    with tempfile.TemporaryDirectory(prefix='r17-native-film-') as scratch:
        ram=Path(scratch)
        command=['python3',str(PROJECT/'tools/look-native.py'),'--movie','--out',str(ram),'--script','res://tools/momentum-tape.gd','--',
                 '--tape='+str(out/'input.expanded.json'),'--physics-hz=128','--warmup='+str(route['warmup']),
                 '--frames=none','--wall-budget-s=120','--game-script=res://scripts/r17_main.gd','--game-class=',
                 '--motor='+str(args.preset or route['preset']),'--r16-map='+args.map,
                 '--r16-source-sensitivity='+str(route.get('sensitivity',2.5)), '--no-records','--no-run-recordings']
        started=time.time()
        with (out/'capture-driver.log').open('w') as log:
            p=subprocess.Popen(command,cwd=PROJECT,stdout=log,stderr=subprocess.STDOUT)
            try:
                while p.poll() is None:
                    gate()
                    if time.time()-started>150:
                        raise RuntimeError('native capture timeout')
                    used=sum(f.stat().st_size for f in ram.rglob('*') if f.is_file())
                    if used>500*2**20:
                        raise RuntimeError('native capture RAM scratch exceeded 500 MiB')
                    time.sleep(.4)
                if p.wait():
                    raise RuntimeError((out/'capture-driver.log').read_text()[-4000:])
            finally:
                if p.poll() is None:
                    p.terminate()
                    p.wait(timeout=10)
        rows=[json.loads(line) for line in (ram/'evaluator/trace.jsonl').read_text().splitlines()]
        peak=max(rows,key=speed)
        end=json.loads((ram/'end.json').read_text())
        (out/'capture-end.json').write_text(json.dumps(end,indent=2)+'\n')
        assert end['reason']=='completed' and end['neutral'] and not end['undelivered'],end
        full=ram/'native-run.mp4'
        info=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_format','-show_streams','-of','json',str(full)],text=True))
        movie_duration=float(info['format']['duration'])
        # native capture begins before engine initialization. use a broad excerpt around the measured peak;
        # the HUD and contact sheet provide the direct visual speed evidence, rather than claiming frame-exact sync.
        lead=max(0,movie_duration-end['wall_s'])
        peak_wall=(peak.get('wall_us_post',peak.get('wall_us_pre',0)))/1e6+lead
        first_draw=json.loads((ram/'evaluator/frames.jsonl').read_text().splitlines()[0])
        play_start=first_draw['wall_us']/1e6+lead+0.5
        clip_s=min(16,max(1,movie_duration-play_start-0.1))
        clip_start=max(play_start,min(movie_duration-clip_s,peak_wall-8))
        movie=args.movie_dir.resolve()/f'r17-{args.map}.mp4'
        movie.parent.mkdir(parents=True,exist_ok=True)
        subprocess.run(['ffmpeg','-y','-v','error','-ss',str(clip_start),'-i',str(full),'-t',str(clip_s),'-an',
                        '-c:v','libx264','-crf','21','-preset','veryfast','-pix_fmt','yuv420p','-movflags','+faststart',str(movie)],check=True)
        for f in ram.rglob('*'):
            if not f.is_file() or f==full: continue
            relative=f.relative_to(ram)
            target=out/relative
            target.parent.mkdir(parents=True,exist_ok=True)
            if f.suffix=='.jsonl':
                target=Path(str(target)+'.gz')
                with f.open('rb') as a,gzip.open(target,'wb',compresslevel=6) as b: shutil.copyfileobj(a,b)
            else: shutil.copy2(f,target)
        frames=ram/'contact.jpg'
        subprocess.run(['ffmpeg','-y','-v','error','-i',str(movie),'-vf','fps=1/2,scale=480:-1,tile=4x2','-frames:v','1',str(frames)],check=True)
        shutil.copy2(frames,out/'contact.jpg')
        proof={'map':args.map,'route':route,'preset':args.preset or route['preset'],'source_head_before':head,
               'runtime_source_manifest':'source-manifest.json','input_sha256':digest(out/'input.expanded.json'),
               'native_full_duration_s':movie_duration,'native_full_sha256':digest(full),'full_scratch_deleted':True,
               'clip':str(movie),'clip_sha256':digest(movie),'clip_start_in_capture_s':clip_start,'clip_duration_s':clip_s,
               'speed_peak_u_s':speed(peak),'peak_tick':peak['tick'],'ticks_at_least_300':sum(speed(r)>=300 for r in rows),
               'no_physical_state_writes_after_authored_spawn':True,'camera':'actual player camera, inherited HUD and R17 label',
               'scope':'native real-time input prefix; not a complete clean finish; approximate trace/movie alignment, HUD confirms visual speed',
               'free_home_before':before,'free_home_after':gate(),'command':command,'end':end}
        (out/'movie.json').write_text(json.dumps(proof,indent=2)+'\n')
        print(json.dumps({k:proof[k] for k in ['map','preset','clip','speed_peak_u_s','ticks_at_least_300','free_home_after']}),flush=True)

if __name__=='__main__':main()
