#!/usr/bin/env python3
"""Capture an untouched native launch and OS-key pause/resume in a dedicated Xvfb display."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ['--'] else args.command
    if not command or any(arg in ['--script', '-s', '--bot', '--verify-startup'] for arg in command):
        parser.error('supply the ordinary launcher command without an engine fixture or bot')
    display = os.environ.get('DISPLAY', '')
    if not re.fullmatch(r':1[3-9][0-9](?:\.0)?', display):
        parser.error('run inside a dedicated Xvfb display130–199, never the desktop display')
    output = args.output.expanduser().resolve()
    repository = Path(subprocess.check_output(['git', 'rev-parse', '--show-toplevel'],
        cwd=Path(__file__).resolve().parents[1], text=True).strip())
    if output == repository or repository in output.parents:
        parser.error('evidence must be outside Git')
    if output.exists() and any(output.iterdir()):
        parser.error('use a fresh output directory')
    output.mkdir(parents=True, exist_ok=True)
    environment = dict(os.environ, XDG_DATA_HOME=str(output / 'profile'))
    actions = []
    result = {'command': command, 'display': display, 'capture_passed': False,
              'method': 'untouched launcher; OS keyboard pause/resume/menu quit; no engine fixture',
              'harness_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              'build_identity_verification': 'inspect pause.png', 'actions': actions}

    def control(*arguments):
        arguments = [str(item) for item in arguments]
        actions.append({'command': arguments, 'monotonic_s': time.monotonic()})
        return subprocess.check_output(arguments, env=environment, text=True, stderr=subprocess.STDOUT, timeout=10)

    with (output / 'engine.log').open('w') as log:
        game = subprocess.Popen(command, cwd=output, env=environment, stdout=log, stderr=subprocess.STDOUT)
        try:
            window = None
            deadline = time.monotonic() + 20
            while game.poll() is None and time.monotonic() < deadline and window is None:
                search = subprocess.run(['xdotool', 'search', '--onlyvisible', '--pid', str(game.pid)],
                                        env=environment, text=True, capture_output=True, timeout=5)
                for candidate in search.stdout.splitlines():
                    title = subprocess.run(['xdotool', 'getwindowname', candidate], env=environment,
                                           text=True, capture_output=True, timeout=5).stdout.strip()
                    if 'spillway' in title.lower():
                        window = candidate
                        result['window_title'] = title
                        break
                if window is None:
                    time.sleep(.05)
            if window is None:
                raise RuntimeError('ordinary launcher did not create a visible Spillway window')
            result['window_id'] = window
            control('xdotool', 'windowfocus', '--sync', window)
            # the title appears before shader compilation finishes. use brightness only to
            # stop capturing the dark engine splash; the actual build still needs visual review.
            ready = False
            for attempt in range(1, 31):
                time.sleep(.5)
                frame = output / ('boot-%02d.png' % attempt)
                control('magick', 'import', '-display', display, '-window', window, '-silent', frame)
                mean = float(control('magick', frame, '-format', '%[fx:mean]', 'info:').strip())
                if mean > .25:
                    shutil.copy2(frame, output / 'start.png')
                    ready = True
                    break
            if not ready:
                raise RuntimeError('no rendered sunlit course after the splash; inspect retained boot views')
            control('xdotool', 'key', '--window', window, 'Escape')
            time.sleep(1)
            control('magick', 'import', '-display', display, '-window', window, '-silent', output / 'pause.png')
            control('xdotool', 'key', '--window', window, 'Escape')
            time.sleep(1)
            control('magick', 'import', '-display', display, '-window', window, '-silent', output / 'resume.png')
            # there is no window manager in Xvfb. quit through the visible game menu.
            control('xdotool', 'key', '--window', window, 'Escape')
            time.sleep(.5)
            control('xdotool', 'key', '--window', window, 'Tab', 'Tab')
            time.sleep(.5)
            control('magick', 'import', '-display', display, '-window', window, '-silent', output / 'pre-quit.png')
            control('xdotool', 'key', '--window', window, 'Return')
            result['exit'] = game.wait(timeout=20)
            log.flush()
            engine_log = (output / 'engine.log').read_text()
            result['capture_passed'] = result['exit'] == 0 and not re.search(r'SCRIPT ERROR:|(^|\s)ERROR:|Parse Error:', engine_log)
        except Exception as error:
            result['error'] = str(error)
        finally:
            if game.poll() is None:
                game.terminate()
                try:
                    game.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    game.kill()
                    game.wait()
                result['forced_cleanup'] = True
            result['frame_hashes'] = {path.name: hashlib.sha256(path.read_bytes()).hexdigest()
                                     for path in output.glob('*.png')}
            (output / 'window-verification.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))
    raise SystemExit(0 if result['capture_passed'] else 1)


if __name__ == '__main__':
    main()
