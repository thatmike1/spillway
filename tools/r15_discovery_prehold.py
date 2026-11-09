#!/usr/bin/env python3
"""queue the current decision's OS keys before resuming the stopped native process."""
import json
import os
from pathlib import Path
import subprocess
import sys
import time

out = Path('/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r15/discovery/attempt-03')
display, decision, *keys = sys.argv[1:]
assert display in {':%d' % n for n in range(190, 200)}
commands = []
for key in keys:
    command = ['xdotool', 'keydown', key]
    subprocess.run(command, env=dict(os.environ, DISPLAY=display), check=True, timeout=3)
    commands.append(command)
with (out / 'preheld-input.jsonl').open('a') as stream:
    stream.write(json.dumps({'decision': int(decision), 'time': time.time(), 'display': display, 'commands': commands}) + '\n')
