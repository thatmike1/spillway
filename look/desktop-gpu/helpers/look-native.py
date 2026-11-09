#!/usr/bin/env python3
"""capture privately on verified AMD hardware, preserving a 15 GB HOME reserve."""
import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import r14_native_display as nd

RESERVE = 15_000_000_000
PROJECT = Path(__file__).resolve().parents[1]
ENGINE = Path.home() / '.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--script', default='res://tools/look-views.gd')
    parser.add_argument('--movie', action='store_true')
    parser.add_argument('args', nargs='*')
    args = parser.parse_args()
    output = args.out.resolve()
    output.mkdir(parents=True, exist_ok=True)
    if shutil.disk_usage(Path.home()).free < RESERVE:
        raise RuntimeError('15 GB HOME reserve')
    with tempfile.TemporaryDirectory(prefix='spillway-look-profile-') as scratch:
        env = dict(os.environ)
        for name in ('data', 'cache', 'config', 'state', 'runtime'):
            path = Path(scratch) / name
            path.mkdir(mode=0o700)
            env['XDG_' + name.upper() + ('_DIR' if name == 'runtime' else '_HOME')] = str(path)
        # the look brief specifies 15 GB, expressed in this helper's GiB units.
        with nd.NativeDisplay(output, min_free_gib=RESERVE/2**30) as display:
            env = display.child_env(env)
            command = [str(ENGINE), '--path', str(PROJECT), '--display-driver', 'x11',
                       '--rendering-driver', 'opengl3', '--audio-driver', 'Dummy',
                       '--resolution', '1280x720', '--windowed', '--position', '0,0',
                       '--script', args.script, '--', '--out=' + str(output), *args.args]
            movie = process = None
            watch = nd.GpuWatch()
            with (output/'ffmpeg.log').open('w') as movie_log, (output/'engine.log').open('w') as engine_log:
                try:
                    if args.movie:
                        movie = subprocess.Popen(
                            ['ffmpeg', '-y', '-f', 'x11grab', '-framerate', '60', '-video_size', '1280x720',
                             '-draw_mouse', '0', '-i', env['DISPLAY']+'+0,0', '-an', '-c:v', 'libx264',
                             '-preset', 'veryfast', '-crf', '20', '-pix_fmt', 'yuv420p', '-movflags', '+faststart',
                             str(output/'native-run.mp4')], env=env, stdin=subprocess.PIPE,
                            stdout=subprocess.DEVNULL, stderr=movie_log)
                    process = subprocess.Popen(command, cwd=PROJECT, env=env,
                                               stdout=engine_log, stderr=subprocess.STDOUT)
                    watch.follow(process.pid)
                    code = process.wait(timeout=150)
                finally:
                    if process is not None and process.poll() is None:
                        process.kill()
                        process.wait()
                    watch.stop()
                    if movie is not None:
                        try:
                            movie.communicate(b'q', timeout=20)
                        finally:
                            if movie.poll() is None:
                                movie.kill()
                                movie.wait()
                        if movie.returncode:
                            raise RuntimeError('ffmpeg capture failed')
            text = (output/'engine.log').read_text()
            gpu = watch.require()
            nd.require_amd_log(text)
            sources = {str(p.relative_to(PROJECT)): nd.digest(p)
                       for parent in ('scripts', 'shaders', 'scenes', 'assets/look')
                       for p in sorted((PROJECT/parent).rglob('*')) if p.is_file() and p.suffix != '.import'}
            (output/'source-manifest.json').write_text(json.dumps(sources, indent=2)+'\n')
            (output/'run.json').write_text(json.dumps(
                {'command': command, 'exit': code, 'gpu': gpu, 'device': nd.godot_device(text),
                 'source_head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=PROJECT, text=True).strip(),
                 'free_home_bytes': shutil.disk_usage(Path.home()).free}, indent=2)+'\n')
            if code or 'ERROR' in text:
                raise RuntimeError(text[-2000:])


if __name__ == '__main__':
    main()
