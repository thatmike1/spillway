#!/usr/bin/env python3
"""package the committed r15 game on official godot 4.7.2 release runtimes, and prove it.

package: freeze HEAD's project tree with git archive, import and export the R15 pack in that
copy, read the frozen identity (registry, maps, rates, record keys, drawn nodes, loaded
modules) from the copy with the probe, play each --route tape in source mode on the copy,
put the pack beside the official Linux and Windows release templates, then run `check` on
the zips before anything reaches --output. it refuses a dirty project, a default scene,
build id or records file other than r15's and a missing export preset; it never repairs
project config. check: verify published zips from empty directories with the shipped Linux
runtime (tools/check-r15-pack.sh wraps it). source: identity and routes on a source copy
(the source command uses it directly). docs/r15/DELIVERY.md.

R14 delivery tools remain unchanged; this is a separate R15 tool with a complete-map release gate.
"""
import argparse
from contextlib import contextmanager
import gzip
import hashlib
import io
import json
import math
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import tarfile
import tempfile
import threading
import time
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parent))
import r14_native_display as nd

PROJECT = Path(__file__).resolve().parents[1]
PROBE = PROJECT / 'tools/r15-pack-probe.gd'
CACHE = Path.home() / '.local/share/foldrunner'
EDITOR = CACHE / 'godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64'
TEMPLATES = CACHE / 'godot-4.7.2-templates'
LICENCES = CACHE / 'godot-4.7.2/licenses'
# official 4.7.2-stable release: the linux editor zip member and the export templates archive
# (github asset digest and SHA512-SUMS.txt agree), and LICENSE.txt / COPYRIGHT.txt at the tag.
ENGINE_VERSION = '4.7.2.stable.official.ed1daf0bf'
EDITOR_SHA256 = '8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e'
# member bytes verified when extracting the pinned official archive, independently of the cache manifest.
TEMPLATE_MEMBERS = {
    'linux_release.x86_64': 'd9f79ab89b5ae369aeed11c6052d402e8218cd503bf85b4a235f9c30c46a7c63',
    'windows_release_x86_64.exe': 'd34d36f3be1a6c49c56525ae86469b92e4f417ddf0b43cf00dd80c385c4b0562',
    'windows_release_x86_64_console.exe': '52bdcae9068e8d23b840e5c63b0c1798ffe2cb66144e5c4bc7af11fb8c8600df',
}
TEMPLATES_SHA256 = 'f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011'
LICENCE_SHA256 = {'GODOT-LICENSE.txt': 'b0435e3b3e4e55238f05f4b306f30524a1b2e20147810d436eaa554fa6855c80',
                  'GODOT-COPYRIGHT.txt': 'cb1980c88089573bcacd7221d777c689bb8bbd778799f24c27fca0fe5f774d6d'}

# p / what this tool ships. a later round changes these on purpose, not by inference. the
# preset registry, map identities, rates and record keys are read from the frozen source.
BUILD = 'spillway-2026.11.08-r15'
MAIN_SCENE = 'res://scenes/r15.tscn'
MAIN_SCRIPT = 'res://scripts/r15_main.gd'
SAVE_PATH = 'user://spillway_r15.cfg'
PROFILE_FORMAT = 1
PROJECT_NAME = 'Spillway'
DEFAULT_MAP = 'breakwater'
DEFAULT_PRESET = 'server128'
PRESET = 'R15 Pack'
NAME = 'SpillwayR15'
TITLE_PREFIX = 'Spillway R15 · '
# earlier rounds' records: seeded into every checked profile and required untouched.
OLD_PROFILES = {'spillway_v1.cfg': 'v1', 'spillway_r12.cfg': 'r12', 'spillway_r13.cfg': 'r13', 'spillway_r14.cfg': 'r14'}
STARTUP = re.compile(r'^r15: build=(?P<build>[^;]+); map=(?P<map>[^;]+); preset=(?P<preset>[^;]+); physics_hz=(?P<hz>\d+); '
                     r'course_key=(?P<key>[0-9a-f]+); records=(?P<records>[^;]+); runner=(?P<runner>[^;]+); '
                     r'standin=(?P<standin>false); renderer=(?P<renderer>\S+)$', re.M)
EXPECT = {'build': BUILD, 'main_scene': MAIN_SCENE, 'save_path': SAVE_PATH, 'profile_format': PROFILE_FORMAT,
          'project_name': PROJECT_NAME, 'title_prefix': TITLE_PREFIX,
          'hud_forbidden': ['R12', 'debug', 'surf'],
          'pack_forbidden_prefixes': ['res://tests/', 'res://tools/', 'res://docs/', 'res://builds/'],
          'asset_prefix': 'res://assets/'}
# committed files that must ship inside the pack: everything a game resource could be.
SHIPPED_DIRS = ('scripts/', 'scenes/', 'shaders/', 'assets/', 'data/')
SHIPPED_EXT = ('.gd', '.tscn', '.tres', '.gdshader', '.png', '.jpg', '.webp', '.gltf', '.glb', '.ogg', '.wav', '.json', '.hdr', '.jpeg')
WINDOWS = {NAME + '.exe': 'windows_release_x86_64.exe', NAME + '.console.exe': 'windows_release_x86_64_console.exe'}
LINUX = {NAME + '.x86_64': 'linux_release.x86_64'}
ERRORS = re.compile(r'SCRIPT ERROR:|ERROR:|Parse Error:|Failed to load', re.M)
HELPERS = ('tools/package-r15.py', 'tools/check-r15-pack.sh', 'tools/r15-pack-probe.gd', 'tools/r14_native_display.py',
           'tools/momentum-tape.py', 'tools/momentum-tape.gd')
EXECUTED_TOOL_SHA256 = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
# p / storage steering of 8 november: no export or native capture below this much free space.
MIN_FREE_GIB = 15.0
RATES = (120, 128)
REQUIRED_MAPS = ('breakwater', 'whiteout-relay', 'sunken-court', 'rainline', 'night-shift', 'practice', 'overflow', 'experiment')
REQUIRED_COURSES = REQUIRED_MAPS[:-1]



class Rejected(Exception):
    pass


def digest(path):
    value = hashlib.sha256()
    with open(path, 'rb') as stream:
        for block in iter(lambda: stream.read(1 << 20), b''):
            value.update(block)
    return value.hexdigest()


def git(*args, binary=False, cwd=PROJECT):
    result = subprocess.run(['git', '-C', str(cwd), *args], capture_output=True)
    if result.returncode:
        raise Rejected('git %s failed: %s' % (' '.join(args), result.stderr.decode(errors='replace')))
    return result.stdout if binary else result.stdout.decode()


def require_space(path, what):
    """the storage floor before an export or a native capture; returns the free bytes."""
    # the floor holds for /home, which the build tree shares, whatever disk the target is on;
    # a target on another disk (a ram disk) needs 1 GiB of its own.
    target = Path(path) if Path(path).exists() else Path(path).parent
    for where, floor in [(Path.home(), MIN_FREE_GIB), (target, MIN_FREE_GIB if target.stat().st_dev == Path.home().stat().st_dev else 1)]:
        free = shutil.disk_usage(where).free
        if free < floor * 2 ** 30:
            raise Rejected('%.2f GiB free on %s before %s, below the %.0f GiB floor; nothing was started' % (free / 2 ** 30, where, what, floor))
    return shutil.disk_usage(target).free


def engine_env(root, display=None):
    # a fresh environment: no parent display, wayland socket or desktop profile reaches the game.
    env = {'PATH': os.environ.get('PATH', '/usr/bin:/bin'), 'HOME': str(Path.home()), 'LANG': 'C.UTF-8'}
    for name in ['XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME', 'XDG_STATE_HOME', 'XDG_RUNTIME_DIR']:
        path = root / name.split('_')[1].lower()
        path.mkdir(parents=True, exist_ok=True, mode=0o700)
        env[name] = str(path)
    if display is not None:
        env['DISPLAY'] = ':%d' % display
    return env


@contextmanager
def cancellation_signals():
    """unwind ownership scopes on terminal signals, restoring the caller's handlers."""
    if threading.current_thread() is not threading.main_thread():
        yield
        return
    previous = {sig: signal.getsignal(sig) for sig in (signal.SIGINT, signal.SIGTERM)}
    def cancel(sig, _frame):
        raise KeyboardInterrupt('cancelled by signal %d' % sig)
    try:
        for sig in previous:
            signal.signal(sig, cancel)
        yield
    finally:
        for sig, handler in previous.items():
            signal.signal(sig, handler)


def stop_process(process, grace=5):
    """release an owned process group, including children if its leader already exited."""
    if process is None:
        return
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    try:
        process.wait(grace)
    except subprocess.TimeoutExpired:
        pass
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    process.wait(5)


@contextmanager
def deferred_signals():
    """record terminal signals while acquiring or releasing an owned resource."""
    pending = []
    previous = {}
    if threading.current_thread() is threading.main_thread():
        def defer(sig, _frame):
            pending.append(sig)
        previous = {sig: signal.signal(sig, defer) for sig in (signal.SIGINT, signal.SIGTERM)}
    try:
        yield pending
    finally:
        for sig, handler in previous.items():
            signal.signal(sig, handler)


def run_engine(cmd, cwd, env, log, deadline, watch=None, cleanup_grace=5):
    """run one owned engine process group to completion or deadline; returns (code, text)."""
    with cancellation_signals(), open(log, 'wb') as output:
        process = watcher = None
        try:
            with deferred_signals() as pending:
                process = subprocess.Popen([str(c) for c in cmd], cwd=cwd, env=env, stdout=output, stderr=subprocess.STDOUT,
                                           start_new_session=True)
            if pending:
                raise KeyboardInterrupt('cancelled during engine launch')
            watcher = threading.Thread(target=watch, args=(process,), daemon=True) if watch else None
            if watcher:
                watcher.start()
            code = process.wait(deadline)
        except subprocess.TimeoutExpired:
            code = 'timeout'
        finally:
            with deferred_signals() as pending:
                stop_process(process, cleanup_grace)
                if watcher:
                    watcher.join(5)
            if pending:
                raise KeyboardInterrupt('cancelled during engine cleanup')
    return code, Path(log).read_text(errors='replace')


def checked(cmd, cwd, env, log, deadline=600):
    code, text = run_engine(cmd, cwd, env, log, deadline)
    if code != 0 or ERRORS.search(text):
        raise Rejected('%s failed (exit %s); see %s' % (Path(str(cmd[0])).name, code, log))
    return text


class Display:
    """a private Xvfb owned by this process; refuses a display someone else holds."""

    def __init__(self, number, log):
        self.number, self.log, self.process = number, log, None
        self.output = self.cancel_scope = None
        self.released = False

    def __enter__(self):
        socket, lock = Path('/tmp/.X11-unix/X%d' % self.number), Path('/tmp/.X%d-lock' % self.number)
        if nd.display_busy(self.number):
            raise Rejected('display :%d is in use; pass another --display' % self.number)
        self.cancel_scope = cancellation_signals()
        self.cancel_scope.__enter__()
        try:
            self.output = open(self.log, 'wb')
            with deferred_signals() as pending:
                self.process = subprocess.Popen(['Xvfb', ':%d' % self.number, '-screen', '0', '1280x720x24', '-nolisten', 'tcp',
                                                 '-noreset'], stdout=self.output, stderr=subprocess.STDOUT, start_new_session=True)
            if pending:
                raise KeyboardInterrupt('cancelled during Xvfb launch')
            for _ in range(100):
                if socket.exists():
                    return self
                if self.process.poll() is not None:
                    break
                time.sleep(0.1)
            raise Rejected('Xvfb :%d did not start' % self.number)
        except BaseException:
            self.__exit__(*sys.exc_info())
            raise

    def __exit__(self, *_):
        try:
            with deferred_signals() as pending:
                stop_process(self.process)
                if self.output:
                    self.output.close()
                self.released = not nd.display_busy(self.number)
        finally:
            if self.cancel_scope:
                self.cancel_scope.__exit__(None, None, None)
                self.cancel_scope = None
        if pending:
            raise KeyboardInterrupt('cancelled during Xvfb cleanup')


def window_titles(display, found):
    # the os-level title of each window on the private display, while the game runs.
    def watch(process):
        env = {'PATH': os.environ.get('PATH', '/usr/bin:/bin'), 'DISPLAY': ':%d' % display}
        while process.poll() is None:
            ids = subprocess.run(['xdotool', 'search', '--name', '.'], env=env, capture_output=True, text=True).stdout.split()
            for window in ids:
                title = subprocess.run(['xprop', '-id', window, '_NET_WM_NAME'], env=env, capture_output=True, text=True).stdout
                match = re.search(r'= "(.*)"', title)
                if match:
                    found.add(match.group(1).encode('latin-1', 'backslashreplace').decode('unicode_escape').encode('latin-1').decode('utf-8', 'replace'))
            time.sleep(0.5)
    return watch


def _cmdline(pid):
    try:
        return Path('/proc/%s/cmdline' % pid).read_bytes()
    except OSError:
        return b''


def owned_leftovers(marker):
    return [pid for pid in os.listdir('/proc') if pid.isdigit() and str(marker).encode() in _cmdline(pid)]


# --- routes -----------------------------------------------------------------------------------

def parse_route(text):
    """map=ID,preset=ID,tape=PATH[,sensitivity=S][,name=N][,reference=TRACE][,fps=F][,warmup=W][,game_diff=A-B+C]: one input route.

    fps is the source executor's fixed render rate (default: the tape's rate, one physics step
    per frame, which the packed play also uses). an external reference recorded at another
    cadence is compared at that cadence: the warmup before tick 0 depends on it. warmup is the
    executor's neutral steps before tick 0 (default 8); the packed play arms after the same
    motor step count, read from the reference trace. game_diff names the exact ticks where a
    reference from another main is known to differ in progress or clock (retained, not waived):
    motion must still match exactly, and the differing ticks must be exactly those."""
    fields = dict(part.split('=', 1) for part in text.split(',') if '=' in part)
    unknown = set(fields) - {'map', 'preset', 'tape', 'sensitivity', 'name', 'reference', 'fps', 'warmup', 'game_diff'}
    if unknown or not {'map', 'preset', 'tape'} <= set(fields):
        raise argparse.ArgumentTypeError('route needs map=,preset=,tape= (optional sensitivity=,name=,reference=,fps=,warmup=,game_diff=); got %s' % text)
    route = {'map': fields['map'], 'preset': fields['preset'], 'tape': str(Path(fields['tape']).expanduser().resolve())}
    if 'sensitivity' in fields:
        route['sensitivity'] = float(fields['sensitivity'])
    if 'reference' in fields:
        route['reference'] = str(Path(fields['reference']).expanduser().resolve())
    for field in ('fps', 'warmup'):
        if field in fields:
            route[field] = int(fields[field])
    if 'game_diff' in fields:
        ticks = []
        for part in fields['game_diff'].split('+'):
            low, _, high = part.partition('-')
            ticks += list(range(int(low), int(high or low) + 1))
        route['game_diff'] = ticks
    route['name'] = fields.get('name') or '%s-%s' % (route['map'], route['preset'])
    if not re.fullmatch(r'[a-z0-9_.-]+', route['name']):
        raise argparse.ArgumentTypeError('route name must be lowercase letters, digits, ".", "_" or "-": ' + route['name'])
    return route


def packed_cadence(routes):
    # the packed play runs one physics step per rendered frame; its reference must too.
    for route in routes:
        if 'fps' in route:
            raise Rejected('route %s: fps= is for source comparisons only; a packed route renders one frame per tick' % route['name'])


def route_game(route, path):
    """the route's game for the tape executor: the r15 main, only its start map and sensitivity set."""
    lines = ['extends "%s"' % MAIN_SCRIPT,
             '## generated by tools/package-r15.py for route %s: normal spawn of the named map, records off.' % route['name'],
             '## no gameplay method, progress, input or movement is overridden.',
             'func _init() -> void:',
             '\tmap_id = %s' % json.dumps(route['map'])]
    if 'sensitivity' in route:
        lines.append('\tsource_sensitivity_override = %r' % route['sensitivity'])
    path.write_text('\n'.join(lines) + '\n')
    return path


def read_rows(path):
    opener = gzip.open if str(path).endswith('.gz') else open
    with opener(path, 'rt') as stream:
        values = [json.loads(line, parse_constant=lambda value: (_ for _ in ()).throw(ValueError('nonfinite JSON: ' + value)))
                  for line in stream if line.strip()]
    return [row for row in values if isinstance(row, dict) and row.get('phase') == 'tape']


def trace_error(rows, packed=False, expected=None):
    """validate evidence independently of its recorder before any numeric comparison."""
    def finite(value):
        return type(value) in (int, float) and math.isfinite(value)
    def vector(value):
        return isinstance(value, list) and len(value) == 3 and all(finite(n) for n in value)
    if not isinstance(rows, list) or not rows or expected is not None and len(rows) != expected:
        return 'empty trace or unexpected duration'
    for tick, row in enumerate(rows):
        if not isinstance(row, dict) or type(row.get('tick')) is not int or row['tick'] != tick:
            return 'ticks must be unique, ordered integers from zero through duration-1'
        motion, game = (row, row) if packed else (row.get('post'), row.get('game'))
        if not isinstance(motion, dict) or not vector(motion.get('p')) or not vector(motion.get('v')) or not finite(motion.get('yaw')):
            return 'position and velocity need three finite numbers; yaw must be finite'
        if not isinstance(game, dict) or any(k not in game for k in ('checkpoint', 'elapsed', 'finished', 'finish_kind', 'respawns')):
            return 'required game-state fields are missing'
        if (type(game['checkpoint']) is not int or game['checkpoint'] < 0 or type(game['respawns']) is not int or game['respawns'] < 0
                or not finite(game['elapsed']) or game['elapsed'] < 0 or type(game['finished']) is not bool or type(game['finish_kind']) is not str):
            return 'game-state fields have invalid types or values'
    return None


def source_route(route, source, evidence, identity=None):
    """expand the tape and play it in source mode on the frozen copy: the tick-for-tick reference.

    the executor runs headless at --render-fps equal to the tape's rate unless the route names
    another: the same one physics step per frame the packed play uses, so tick 0 opens on the
    same motor warmup. measured on 3b88472a: at 30 fps the executor arms after 11 motor steps
    (128 hz), at 128 fps after 8, and the two lines differ from tick 0 by up to 0.05 mm."""
    out = evidence / ('route-' + route['name'])
    out.mkdir(parents=True)
    tape = Path(route['tape'])
    env = engine_env(out / 'tool-profile')
    env['GODOT'] = str(EDITOR)
    code, text = run_engine([sys.executable, '-I', source / 'tools/momentum-tape.py', 'expand', tape], source, env, out / 'expand.log', 60)
    if code:
        raise Rejected('route %s: tape does not expand: %s' % (route['name'], text[-400:]))
    expanded = out / 'tape.expanded.json'
    expanded.write_text(text)
    plan = json.loads(text)
    hz = int(plan['physics_hz'])
    if identity is not None:
        key = identity['keys'].get(route['map'], {}).get(route['preset'])
        if key is None:
            raise Rejected('route %s: map %s / preset %s is not an available pair in the frozen registry' % (route['name'], route['map'], route['preset']))
        if int(key['physics_hz']) != hz:
            raise Rejected('route %s: tape declares %d Hz; preset %s runs at %s Hz' % (route['name'], hz, route['preset'], key['physics_hz']))
    game = route_game(route, out / 'route-game.gd')
    run = out / 'source-run'
    # the tape supervisor owns a separate engine group; allow its acknowledgement and forced
    # cleanup window to finish before escalating cancellation of that supervisor itself.
    code, text = run_engine([sys.executable, '-I', source / 'tools/momentum-tape.py', 'run', expanded, '--out', run, '--headless',
                             '--render-fps', str(route.get('fps', hz)), '--warmup', str(route.get('warmup', 8)), '--wall-budget', '400', '--game-script', game, '--game-class', '',
                             '--motor', route['preset']], source, env, out / 'source-run.log', 440, cleanup_grace=35)
    trace = run / 'evaluator/trace.jsonl'
    rows = read_rows(trace) if trace.is_file() else []
    invalid = trace_error(rows, expected=int(plan['duration_ticks']))
    if invalid:
        raise Rejected('route %s has invalid evidence: %s' % (route['name'], invalid))
    last = rows[-1]['game'] if rows else {}
    order = [r['game']['checkpoint'] for r in rows]
    ordered = all(b - a in (0, 1) for a, b in zip(order, order[1:]))
    report = json.loads((run / 'evaluator/report.json').read_text()) if (run / 'evaluator/report.json').is_file() else {}
    result = {'route': route, 'tape': str(expanded), 'tape_sha256': digest(tape), 'expanded_sha256': digest(expanded),
              'physics_hz': hz, 'tape_version': plan['version'], 'ticks': plan['duration_ticks'], 'trace': str(trace),
              'arm_motor_steps': rows[0]['pre']['tape_step_count'] if rows else None, 'source_finish': last,
              'ordered': ordered, 'rate_ok': (report.get('rate') or {}).get('ok'), 'delivery_ok': (report.get('delivery') or {}).get('ok'),
              'render_fps': route.get('fps', hz), 'warmup': route.get('warmup', 8), 'exit': code, 'route_game_sha256': digest(game)}
    result['order_ok'] = (report.get('order') or {}).get('ok')
    result['cleanup_ok'] = (report.get('cleanup') or {}).get('clean')
    result['integrity_flags'] = report.get('integrity_flags')
    engine_log = run / 'evaluator/godot.log'
    result['engine_log_present'] = engine_log.is_file()
    result['engine_log_sha256'] = digest(engine_log) if engine_log.is_file() else None
    result['engine_log_error'] = bool(ERRORS.search(engine_log.read_text(errors='replace'))) if engine_log.is_file() else None
    if (code or ERRORS.search(text) or result['engine_log_present'] is not True or result['engine_log_error'] is not False
            or not last.get('finished') or last.get('finish_kind') != 'clean' or last.get('respawns') or not ordered
            or result['rate_ok'] is not True or result['delivery_ok'] is not True or result['order_ok'] is not True
            or result['cleanup_ok'] is not True or report.get('neutral') is not True or report.get('end') != 'completed'
            or result['integrity_flags'] != []):
        raise Rejected('route %s does not finish clean, ordered and at its rate in source mode: %s' % (route['name'], json.dumps(result)[:600]))
    if route.get('reference'):
        result['external_reference'] = compare_traces(rows, read_rows(route['reference']), route.get('game_diff', []))
        if not result['external_reference']['ok']:
            raise Rejected('route %s disagrees with its requested external reference: %s' % (route['name'], result['external_reference']))
    return result


def shipped_trace_match(path, reference):
    """the probe's own trace against the source reference with python's correctly rounded reader."""
    if not path.is_file() or not reference:
        return {'ok': False, 'missing': str(path) if not path.is_file() else 'reference'}
    try:
        with open(path) as stream:
            rows = [json.loads(line, parse_constant=lambda value: (_ for _ in ()).throw(ValueError('nonfinite JSON: ' + value))) for line in stream if line.strip()]
        other = read_rows(reference)
    except (ValueError, OSError) as error:
        return {'ok': False, 'invalid': str(error)}
    invalid = trace_error(rows, packed=True) or trace_error(other) or ('duration differs' if len(rows) != len(other) else None)
    if invalid:
        return {'ok': False, 'invalid': invalid}
    by_tick = {r['tick']: r for r in other}
    worst, worst_velocity, worst_yaw, game_ticks = 0.0, 0.0, 0.0, []
    for row in rows:
        ref = by_tick.get(row['tick'])
        if ref is None:
            game_ticks.append(row['tick'])
            continue
        worst = max(worst, max(abs(a - b) for a, b in zip(row['p'], ref['post']['p'])))
        worst_velocity = max(worst_velocity, max(abs(a-b) for a,b in zip(row['v'], ref['post']['v'])))
        worst_yaw = max(worst_yaw, abs(row['yaw'] - ref['post']['yaw']))
        if any(row.get(k) != ref['game'].get(k) for k in ('checkpoint', 'elapsed', 'finished', 'finish_kind', 'respawns')):
            game_ticks.append(row['tick'])
    return {'ok': len(rows) == len(by_tick) and worst == 0.0 and worst_velocity == 0.0 and worst_yaw == 0.0 and not game_ticks, 'ticks': len(rows),
            'reference_ticks': len(by_tick), 'max_position_m': worst, 'max_velocity_m_s': worst_velocity, 'max_yaw_rad': worst_yaw, 'game_difference_ticks': game_ticks[:20]}


def compare_traces(rows, other, known_game_ticks=()):
    """two executor traces tick by tick: positions exactly, yaw to 1e-12, progress and clock.

    known_game_ticks: the exact ticks where progress or clock is known to differ (a reference
    from another main); any other differing tick, or a known one that agrees, fails."""
    invalid = trace_error(rows) or trace_error(other) or ('duration differs' if len(rows) != len(other) else None)
    if invalid:
        return {'ok': False, 'invalid': invalid, 'ticks': len(rows), 'reference_ticks': len(other)}
    by_tick = {r['tick']: r for r in other}
    worst, worst_velocity, worst_yaw, first, game_diff, game_ticks = 0.0, 0.0, 0.0, None, [], []
    for row in rows:
        ref = by_tick.get(row['tick'])
        if ref is None:
            continue
        a, b = row['post']['p'], ref['post']['p']
        gap = sum((x - y) ** 2 for x, y in zip(a, b)) ** 0.5
        if gap > 0 and first is None:
            first = row['tick']
        worst = max(worst, gap)
        worst_velocity = max(worst_velocity, max(abs(a-b) for a,b in zip(row['post']['v'], ref['post']['v'])))
        worst_yaw = max(worst_yaw, abs(row['post']['yaw'] - ref['post']['yaw']))
        mine, theirs = row.get('game', {}), ref.get('game', {})
        if any(mine.get(k) != theirs.get(k) for k in ('checkpoint', 'elapsed', 'finished', 'finish_kind', 'respawns')):
            game_ticks.append(row['tick'])
            if len(game_diff) < 5:
                game_diff.append({'tick': row['tick'], 'this': mine, 'reference': theirs})
    return {'ticks': len(rows), 'reference_ticks': len(other), 'max_position_m': worst, 'max_velocity_m_s': worst_velocity, 'max_yaw_rad': worst_yaw,
            'first_position_difference_tick': first, 'game_differences': game_diff, 'game_difference_ticks': game_ticks,
            'known_game_difference_ticks': list(known_game_ticks),
            'ok': len(rows) == len(other) and worst == 0.0 and worst_velocity == 0.0 and worst_yaw <= 1e-12 and game_ticks == list(known_game_ticks)}


def resources(files):
    # committed game resources, as res:// paths; the probe looks each up inside the pack.
    return ['res://' + p for p in files if p.startswith(SHIPPED_DIRS) and p.endswith(SHIPPED_EXT)
            and not p.endswith('MANIFEST.json')]


def source_identity(source, evidence, files, probe):
    """the frozen identity, read by the probe from the source copy under the pinned editor.

    the copy gets an override.cfg naming the probe for this run only; it is removed after."""
    out = evidence / 'identity'
    out.mkdir(parents=True)
    executed = out / 'executed-probe.gd'
    shutil.copy2(probe, executed)
    spec = {'mode': 'identity', 'out': str(out), 'committed_resources': resources(files), 'expect': {}}
    (out / 'spec.json').write_text(json.dumps(spec, indent=1))
    # a probe that does not parse leaves the game running without it; refuse that up front.
    checked([EDITOR, '--headless', '--path', source, '--check-only', '--script', executed], source, engine_env(out / 'parse-profile'),
            out / 'probe-parse.log', 60)
    override = source / 'override.cfg'
    if override.exists():
        raise Rejected('the source copy already has an override.cfg')
    try:
        override.write_text('[autoload]\nPackProbe="*%s"\n' % executed)
        code, text = run_engine([EDITOR, '--headless', '--audio-driver', 'Dummy', '--path', source, '--', '--pack-probe=%s' % (out / 'spec.json')],
                                source, engine_env(out / 'profile'), out / 'engine.log', 180)
    finally:
        override.unlink(missing_ok=True)
    report = json.loads((out / 'probe.json').read_text()) if (out / 'probe.json').is_file() else {}
    if code != 0 or ERRORS.search(text) or report.get('failures') != 0 or 'identity' not in report:
        raise Rejected('source identity probe failed (exit %s); see %s' % (code, out / 'engine.log'))
    identity = report['identity']
    identity['probe_sha256'] = digest(executed)
    start = identity['start']
    if start['map'] != DEFAULT_MAP or start['preset'] != DEFAULT_PRESET:
        raise Rejected('the source starts on %s / %s, not %s / %s' % (start['map'], start['preset'], DEFAULT_MAP, DEFAULT_PRESET))
    if identity['registry']['build'] != BUILD or identity['registry']['save_path'] != SAVE_PATH:
        raise Rejected('the running source names build %s and records %s' % (identity['registry']['build'], identity['registry']['save_path']))
    if identity['project_name'] != PROJECT_NAME:
        raise Rejected('the source profile identity is %s, not %s' % (identity['project_name'], PROJECT_NAME))
    if set(identity['registry']['maps']) != set(REQUIRED_MAPS) or set(identity['maps']) != set(REQUIRED_MAPS):
        raise Rejected('R15 requires all five new courses, both legacy maps and the lab; missing or extra: %s' %
                       sorted(set(REQUIRED_MAPS) ^ set(identity['maps'])))
    if identity['registry']['default_preset'] != DEFAULT_PRESET or 'vanilla64' in identity['registry']['order']:
        raise Rejected('R15 starts on F2 and excludes vanilla64')
    pending = [(m, p) for m, keys in identity['keys'].items() for p, k in keys.items() if k['pending'] or not k['clean'] or k['preset'] != p]
    if pending:
        raise Rejected('identity could not switch cleanly at the spawn: %s' % pending)
    return identity


# --- source -----------------------------------------------------------------------------------

def committed(path):
    return git('show', 'HEAD:./' + path)


def source_archive(commit, prefix, top):
    # subtree archives otherwise use wall time for tar entries, so their hashes cannot be rechecked.
    stamp = git('show', '-s', '--format=%ct', commit, cwd=top).strip()
    return git('archive', '--format=tar', '--mtime=@' + stamp, commit + ':' + prefix, binary=True, cwd=top)


def archive_manifest(archive):
    """sha256 of every regular file in a source archive, as 'hash  path' lines."""
    lines = []
    with tarfile.open(fileobj=io.BytesIO(archive)) as frozen:
        for member in frozen.getmembers():
            if member.isfile():
                lines.append('%s  %s' % (hashlib.sha256(frozen.extractfile(member).read()).hexdigest(), member.name))
    return ''.join(line + '\n' for line in sorted(lines, key=lambda line: line.split('  ', 1)[1]))


def preflight(args):
    """everything that must hold before any file is written; Rejected names the first failure."""
    facts = {}
    status = git('status', '--porcelain', '--untracked-files=all', '--', '.').strip()
    if status:
        raise Rejected('commit the project before packaging; uncommitted or untracked:\n' + status)
    facts['commit'] = git('rev-parse', 'HEAD').strip()
    top = Path(git('rev-parse', '--show-toplevel').strip())
    facts['prefix'] = str(PROJECT.relative_to(top))
    facts['tree'] = git('rev-parse', 'HEAD:./').strip()
    project = committed('project.godot')
    scene = re.search(r'^run/main_scene="([^"]*)"', project, re.M)
    if not scene or scene.group(1) != MAIN_SCENE:
        raise Rejected('committed default scene is %s, not %s' % (scene.group(1) if scene else 'unset', MAIN_SCENE))
    name = re.search(r'^config/name="([^"]*)"', project, re.M)
    if not name or name.group(1) != PROJECT_NAME or re.search(r'^config/use_custom_user_dir=true', project, re.M):
        raise Rejected('committed profile identity is %s, not the %s user data folder' % (name.group(1) if name else 'unset', PROJECT_NAME))
    facts['project_name'] = name.group(1)
    version = re.search(r'^config/version="([^"]*)"', project, re.M)
    facts['project_version'] = version.group(1) if version else ''
    scene_text = committed(MAIN_SCENE.removeprefix('res://'))
    if 'path="%s"' % MAIN_SCRIPT not in scene_text or not re.search(r'^persist = true$', scene_text, re.M):
        raise Rejected('%s must run %s with persist = true' % (MAIN_SCENE, MAIN_SCRIPT))
    main = committed(MAIN_SCRIPT.removeprefix('res://'))
    build = re.search(r'^const BUILD_ID := "([^"]+)"', main, re.M)
    if not build or build.group(1) != BUILD:
        raise Rejected('committed BUILD_ID is %s, not %s' % (build.group(1) if build else 'missing', BUILD))
    save = re.search(r'^const SAVE_PATH := "([^"]+)"', main, re.M)
    if not save or save.group(1) != SAVE_PATH:
        raise Rejected('committed records file is %s, not %s' % (save.group(1) if save else 'missing', SAVE_PATH))
    if 'print("r15: build=%s; map=%s; ' not in main:
        raise Rejected('the r15 startup line is missing from ' + MAIN_SCRIPT)
    presets = committed('export_presets.cfg')
    section = next((block for block in re.split(r'^(?=\[preset\.\d+\]$)', presets, flags=re.M)
                    if re.search(r'^name="%s"$' % re.escape(PRESET), block, re.M)), None)
    if section is None:
        raise Rejected('export_presets.cfg has no "%s" preset; see docs/r15/DELIVERY.md' % PRESET)
    excluded = re.search(r'^exclude_filter="([^"]*)"', section, re.M)
    if 'platform="Linux"' not in section or not excluded or not all(p in excluded.group(1) for p in ['tests/*', 'tools/*', 'docs/*']):
        raise Rejected('"%s" must be a Linux preset excluding tests/*, tools/* and docs/*' % PRESET)
    files = git('ls-tree', '-r', '--full-tree', 'HEAD:./')
    facts['files'] = [line.split('\t', 1)[1] for line in files.splitlines()]
    if 'override.cfg' in facts['files']:
        raise Rejected('the committed project carries an override.cfg')
    if not EDITOR.is_file() or digest(EDITOR) != EDITOR_SHA256:
        raise Rejected('the pinned official Godot 4.7.2 Linux editor is required at ' + str(EDITOR))
    facts['engine'] = subprocess.run([str(EDITOR), '--headless', '--version'], capture_output=True, text=True).stdout.strip()
    if not facts['engine'].startswith(ENGINE_VERSION):
        raise Rejected('engine reports %s, not %s' % (facts['engine'], ENGINE_VERSION))
    facts['templates'] = templates()
    for name, value in LICENCE_SHA256.items():
        if not (LICENCES / name).is_file() or digest(LICENCES / name) != value:
            raise Rejected('official Godot licence/notice missing or changed: ' + name)
    return facts


def templates():
    provenance = json.loads((TEMPLATES / 'PROVENANCE.json').read_text())
    if provenance.get('official_digest') != 'sha256:' + TEMPLATES_SHA256:
        raise Rejected('release templates were not extracted from the official 4.7.2 archive')
    for name in list(LINUX.values()) + list(WINDOWS.values()):
        if digest(TEMPLATES / name) != TEMPLATE_MEMBERS[name] or provenance['members'].get('templates/' + name) != TEMPLATE_MEMBERS[name]:
            raise Rejected('cached release template differs from the verified archive member: ' + name)
    if (TEMPLATES / 'version.txt').read_text().strip() != '4.7.2.stable':
        raise Rejected('release templates are not 4.7.2.stable')
    return provenance


def licence_files(files):
    """every licence the zips carry: {zip path: (origin, name)}. godot's two come from the
    pinned cache; each asset kit's licences and manifest from the committed source."""
    found = {('licenses/' + name): ('godot', name) for name in LICENCE_SHA256}
    for path in files:
        parts = Path(path).parts
        if not parts or parts[0] != 'assets':
            continue
        if ('licences' in parts or 'licenses' in parts or Path(path).name in ('MANIFEST.json', 'NOTICE.txt', 'NOTICE.md', 'LICENSE.txt', 'LICENSE.md', 'LICENCE', 'COPYING', 'COPYING.txt')):
            # preserve the full kit path: repeated CC0/MANIFEST names never overwrite one another.
            found['licenses/' + path] = ('source', path)
    return found


def readme(platform, facts, identity, launch, user_dir, newline):
    registry = identity['registry']
    maps = identity['maps']
    lines = ['SPILLWAY R15', 'build %s · source %s' % (BUILD, facts['commit'][:8]), '', *launch, '',
             'It starts on %s with the %s preset. The top-left line always names the map,' % (
                 maps[registry['default_map']]['name'], registry['presets'][registry['default_preset']]['label']),
             'the active preset and its key, the physics rate and the air acceleration.', '',
             'Movement presets (switch any time; your position, speed and view are kept)']
    for id in registry['order']:
        entry = registry['presets'][id]
        lines.append('  F%d  %s%s' % (entry['slot'], entry['label'], '' if entry['available'] else '  (not available yet)'))
        lines.append('      ' + entry['summary'])
        for control in str(entry.get('controls', '')).split('\n'):
            if control.strip():
                lines.append('      ' + control.strip())
    lines += ['  Switching preset during a run turns that attempt into practice. R starts a clean run.', '',
              'Maps (Esc, then pick one): ' + ', '.join(maps[m]['name'] for m in registry['maps'] if m in maps),
              '', 'Keys: ' + registry['hud_keys_line'], '  F11 fullscreen. The pause menu lists every preset with its air acceleration,',
              '  rate and jump policy, the map selector, look settings and Quit.', '',
              'Records and settings: spillway_r15.cfg in ' + user_dir + ', one record per',
              'map and preset. R14 look settings may seed the first launch; earlier records are never imported or changed.', '',
              'Licences: licenses/ (Godot Engine, its third-party notices, and the asset kits).',
              'BUILD.json records the exact source commit, runtime, pack and preset registry.',
              'Nothing here claims that a preset feels like CS:GO; that is for you to judge.']
    if platform.startswith('windows'):
        lines += ['', 'Not yet verified: running this Windows build on Windows itself. It was',
                  'packaged and checked on Linux. Please report what happens.']
    else:
        lines += ['', 'Linux launch and scripted input are checked on a private display.',
                  'VERIFICATION.json beside the download records the actual rendering backend.',
                  'Physical input latency and desktop frame pacing are not verified.']
    return newline.join(lines) + newline


def assemble(stage, pack, facts, identity, extra):
    """the two platform folders around one pack; returns {platform: folder}."""
    folders = {}
    licences = {target: (LICENCES / name if origin == 'godot' else stage / 'source' / name)
                for target, (origin, name) in licence_files(facts['files']).items()}
    for platform, runtimes in [('linux-x86_64', LINUX), ('windows-x86_64', WINDOWS)]:
        folder = stage / 'dist' / ('%s-%s' % (NAME, platform))
        folder.mkdir(parents=True)
        for target, template in runtimes.items():
            shutil.copy2(TEMPLATES / template, folder / target)
        if platform.startswith('linux'):
            (folder / (NAME + '.x86_64')).chmod(0o755)
        shutil.copy2(pack, folder / (NAME + '.pck'))
        for target, source in licences.items():
            (folder / target).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, folder / target)
        if platform.startswith('linux'):
            launch = ['Start: extract the whole folder, then run ./%s.x86_64' % NAME,
                      '(or double-click it; if it will not start, run: chmod +x %s.x86_64).' % NAME,
                      'Keep %s.pck beside it. No engine or source checkout is needed.' % NAME]
            text = readme(platform, facts, identity, launch, '~/.local/share/godot/app_userdata/%s/' % facts['project_name'], '\n')
        else:
            launch = ['Start: extract the whole folder, then double-click %s.exe.' % NAME,
                      'Windows may warn about an unknown publisher; the build is unsigned.',
                      '%s.console.exe starts the same game with a log window, for troubleshooting.' % NAME,
                      'Keep %s.pck beside the .exe files. No engine or source checkout is needed.' % NAME]
            text = readme(platform, facts, identity, launch, '%%APPDATA%%\\Godot\\app_userdata\\%s\\' % facts['project_name'], '\r\n')
        (folder / 'README.txt').write_bytes(text.encode())
        manifest = dict(extra, platform=platform, launch=launch[0],
                        runtime_sha256={target: digest(folder / target) for target in runtimes},
                        native_windows_execution='not verified' if platform.startswith('windows') else 'not applicable')
        (folder / 'BUILD.json').write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + '\n')
        folders[platform] = folder
    return folders


def archive(folder, destination, stamp):
    # fixed entry times (the source commit's) and stored unix modes, so the zip is rebuildable.
    when = time.gmtime(max(int(stamp), 315532800))[:6]
    with zipfile.ZipFile(destination, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as output:
        for path in sorted(folder.rglob('*')):
            if path.is_file():
                info = zipfile.ZipInfo(str(Path(folder.name) / path.relative_to(folder)), when)
                info.compress_type = zipfile.ZIP_DEFLATED
                info.external_attr = (0o100000 | (path.stat().st_mode & 0o777)) << 16
                with open(path, 'rb') as stream:
                    output.writestr(info, stream.read(), compresslevel=6)


def publish(dist, facts):
    zips = []
    for folder in sorted(p for p in dist.iterdir() if p.is_dir()):
        destination = dist / ('%s-%s-%s.zip' % (BUILD, folder.name.removeprefix(NAME + '-'), facts['commit'][:8]))
        archive(folder, destination, facts['stamp'])
        zips.append(destination)
    (dist / 'SHA256SUMS').write_text(''.join('%s  %s\n' % (digest(z), z.name) for z in zips))
    return zips


def package(args):
    output = args.output.expanduser().resolve()
    top = Path(git('rev-parse', '--show-toplevel').strip())
    if output == top or top in output.parents:
        raise Rejected('delivery output must be outside the Git checkout')
    if output.exists() and any(output.iterdir()):
        raise Rejected('output %s already has files; packages are never overwritten' % output)
    if args.diagnostic and 'spillway-r15' in output.parts and 'delivery' in output.parts:
        raise Rejected('a diagnostic package is never written to the final delivery folder')
    if not args.startup_only and not args.route:
        raise Rejected('pass --route for a packed play proof, or --startup-only to ship without one')
    if not args.diagnostic:
        if args.startup_only:
            raise Rejected('startup-only output is diagnostic, never an R15 release candidate')
        pairs = {(r['map'], r['preset']) for r in args.route}
        missing = [(m, DEFAULT_PRESET) for m in REQUIRED_COURSES if (m, DEFAULT_PRESET) not in pairs]
        if missing or not any(p == 'server128_aa1000' for _, p in pairs):
            raise Rejected('release play proofs need F2 on every course and an F5 comparison; missing %s' % missing)
    packed_cadence(args.route)
    facts = preflight(args)
    require_space(output.parent if not output.exists() else output, 'the export')
    output.mkdir(parents=True, exist_ok=True)
    evidence = output / 'evidence'
    evidence.mkdir()
    # transient bulk (source copy, pack, folders, extracted zips) lives in the scratch area.
    stage = Path(tempfile.mkdtemp(prefix='r15-package-', dir=args.scratch or output))
    args.work = stage / 'work'
    try:
        # freeze: exactly the committed tree, never the working checkout or its import cache.
        tar = source_archive(facts['commit'], facts['prefix'], top)
        facts['archive_sha256'] = hashlib.sha256(tar).hexdigest()
        facts['stamp'] = git('show', '-s', '--format=%ct', facts['commit'], cwd=top).strip()
        manifest_text = archive_manifest(tar)
        with tarfile.open(fileobj=io.BytesIO(tar)) as frozen:
            frozen.extractall(stage / 'source', filter='data')
        source = stage / 'source'
        if digest(source / 'tools/package-r15.py') != EXECUTED_TOOL_SHA256:
            raise Rejected('executing packager differs from its frozen committed source')
        listed = sorted(str(p.relative_to(source)) for p in source.rglob('*') if p.is_file() or p.is_symlink())
        if listed != sorted(facts['files']):
            raise Rejected('git archive output differs from the committed file list')
        (evidence / 'source-sha256.txt').write_text(manifest_text)
        env = engine_env(stage / 'profile')
        checked([EDITOR, '--headless', '--path', source, '--import'], source, env, evidence / 'import.log')
        pack = stage / 'pack' / (NAME + '.pck')
        pack.parent.mkdir()
        checked([EDITOR, '--headless', '--path', source, '--export-pack', PRESET, pack], source, env, evidence / 'export.log')
        startup = checked([EDITOR, '--headless', '--audio-driver', 'Dummy', '--path', source, '--', '--verify-startup'],
                          source, env, evidence / 'source-startup.log', 120)
        line = STARTUP.search(startup)
        if not line or line['build'] != BUILD or line['map'] != DEFAULT_MAP or line['preset'] != DEFAULT_PRESET:
            raise Rejected('source startup did not print the r15 identity on %s / %s' % (DEFAULT_MAP, DEFAULT_PRESET))
        facts['startup'] = line.group(0)
        identity = source_identity(source, evidence, facts['files'], source / 'tools/r15-pack-probe.gd')
        if identity['start']['course_key'] != line['key']:
            raise Rejected('the probe read record key %s; the startup line printed %s' % (identity['start']['course_key'], line['key']))
        routes = [source_route(route, source, evidence / 'source-routes', identity) for route in args.route]
        missing = [p for p in HELPERS if not (source / p).is_file()]
        if missing:
            raise Rejected('packaging helpers are not committed: %s' % missing)
        helpers = {p: digest(source / p) for p in HELPERS}
        extra = {'game': 'Spillway', 'round': 'R15', 'build': BUILD, 'project_version': facts['project_version'],
                 'release_candidate': not args.diagnostic,
                 'status': 'diagnostic package: not a release, never promote' if args.diagnostic else 'release candidate; promotion is root\'s',
                 'source_commit': facts['commit'], 'source_tree': facts['tree'], 'source_project_path': facts['prefix'],
                 'source_archive_sha256': facts['archive_sha256'], 'source_files': len(listed),
                 'source_manifest_sha256': hashlib.sha256(manifest_text.encode()).hexdigest(),
                 'engine': facts['engine'], 'export_editor_sha256': EDITOR_SHA256, 'export_preset': PRESET,
                 'runtime': {'kind': 'official Godot 4.7.2 release export templates', 'archive': facts['templates']['archive_url'],
                             'archive_sha256': TEMPLATES_SHA256, 'members_sha256': TEMPLATE_MEMBERS},
                 'pack_sha256': digest(pack), 'main_scene': MAIN_SCENE, 'records_file': SAVE_PATH,
                 'user_data_folder': facts['project_name'], 'startup_line': facts['startup'],
                 'default_map': DEFAULT_MAP, 'default_preset': DEFAULT_PRESET, 'identity': identity,
                 'requested_verification_backend': args.native_backend,
                 'routes': [{k: v for k, v in r.items() if k not in ('tape', 'trace')} for r in routes],
                 'helpers_sha256': helpers, 'helpers_committed': EXECUTED_TOOL_SHA256 == helpers.get('tools/package-r15.py'),
                 'verification': 'VERIFICATION.json beside the zips'}
        folders = assemble(stage, pack, facts, identity, extra)
        zips = publish(stage / 'dist', facts)
        for folder in folders.values():
            shutil.rmtree(folder)
        build = dict(extra, platforms=[z.name for z in zips])
        (stage / 'dist' / 'BUILD.json').write_text(json.dumps(build, indent=2, ensure_ascii=False) + '\n')
        args.probe = evidence / 'frozen-probe.gd'
        shutil.copy2(source / 'tools/r15-pack-probe.gd', args.probe)
        shutil.rmtree(source)
        args.pack_required = sorted(set(resources(facts['files'])) | set(args.require))
        result = check_package(stage / 'dist', args, evidence / 'check', routes, pack_expect=digest(pack))
        destination = output if result['ok'] else output / 'rejected'
        destination.mkdir(exist_ok=True)
        for path in zips + [stage / 'dist' / 'SHA256SUMS']:
            shutil.move(str(path), destination / path.name)
        (destination / 'BUILD.json').write_text(json.dumps(build, indent=2, ensure_ascii=False) + '\n')
        (destination / 'VERIFICATION.json').write_text(json.dumps(result, indent=2, ensure_ascii=False) + '\n')
        for platform in folders:
            print(destination / ('%s-%s-%s.zip' % (BUILD, platform, facts['commit'][:8])))
        if not result['ok']:
            raise Rejected('packed checks failed; zips kept under %s, see VERIFICATION.json' % destination)
    finally:
        shutil.rmtree(stage, ignore_errors=True)
        compress_evidence(evidence)


def compress_evidence(evidence):
    # raw traces become verified gzip files; the decompressed hash is kept beside each.
    for path in list(evidence.rglob('*.jsonl')):
        raw = path.read_bytes()
        target = path.with_suffix('.jsonl.gz')
        with gzip.open(target, 'wb', compresslevel=9) as stream:
            stream.write(raw)
        if gzip.decompress(target.read_bytes()) == raw:
            target.with_suffix('.sha256').write_text('%s  %s\n' % (hashlib.sha256(raw).hexdigest(), path.name))
            path.unlink()
    for path in list(evidence.rglob('*')):
        if path.is_dir() and path.name in ('profile', 'tool-profile', 'source') and (path / 'cache').exists():
            shutil.rmtree(path / 'cache', ignore_errors=True)
        elif path.is_dir() and path.name == 'shader_cache':
            # godot's compiled shader cache: rebuilt on every run and several megabytes per profile.
            shutil.rmtree(path, ignore_errors=True)


# --- check ------------------------------------------------------------------------------------

def extract(path, target):
    # like unzip and desktop extractors, restore the stored unix modes (the runtime's exec bit).
    with zipfile.ZipFile(path) as archive_file:
        for info in archive_file.infolist():
            written = Path(archive_file.extract(info, target))
            mode = info.external_attr >> 16 & 0o777
            if mode and not info.is_dir():
                written.chmod(mode)


def verify_source_manifest(build):
    """resolve recorded provenance against git, independently of package-supplied hashes."""
    fixed = {'build': BUILD, 'main_scene': MAIN_SCENE, 'records_file': SAVE_PATH, 'default_map': DEFAULT_MAP,
             'default_preset': DEFAULT_PRESET, 'user_data_folder': PROJECT_NAME,
             'helpers_committed': True, 'export_editor_sha256': EDITOR_SHA256, 'export_preset': PRESET}
    wrong = sorted(k for k, v in fixed.items() if build.get(k) != v)
    if wrong:
        raise Rejected('source manifest has an incorrect identity or uncommitted helpers: %s' % wrong)
    commit, prefix = build.get('source_commit', ''), build.get('source_project_path', '')
    if not re.fullmatch('[0-9a-f]{40}', commit):
        raise Rejected('source manifest needs the full source commit')
    top = Path(git('rev-parse', '--show-toplevel').strip())
    tree = git('rev-parse', commit + ':' + prefix, cwd=top).strip()
    archive_bytes = source_archive(commit, prefix, top)
    files = git('ls-tree', '-r', '--name-only', '--full-tree', commit + ':' + prefix, cwd=top).splitlines()
    helpers = {p: hashlib.sha256(git('show', commit + ':' + prefix + '/' + p, binary=True, cwd=top)).hexdigest()
               for p in HELPERS}
    if (build.get('source_tree') != tree or build.get('source_archive_sha256') != hashlib.sha256(archive_bytes).hexdigest()
            or build.get('source_files') != len(files) or build.get('helpers_sha256') != helpers
            or build.get('source_manifest_sha256') != hashlib.sha256(archive_manifest(archive_bytes).encode()).hexdigest()):
        raise Rejected('source tree, archive, file hashes, file count or helper hashes do not match the recorded commit')
    runtime = build.get('runtime', {})
    if runtime.get('archive_sha256') != TEMPLATES_SHA256 or runtime.get('members_sha256') != TEMPLATE_MEMBERS:
        raise Rejected('source manifest names a different runtime archive or members')
    identity = build.get('identity') or {}
    start = identity.get('start', {})
    if start.get('map') != DEFAULT_MAP or start.get('preset') != DEFAULT_PRESET or not re.fullmatch('[0-9a-f]{16}', str(start.get('course_key', ''))):
        raise Rejected('source manifest has no valid frozen identity')
    line = STARTUP.search(build.get('startup_line', ''))
    if not line or line['key'] != start['course_key'] or line['build'] != BUILD:
        raise Rejected('source manifest startup line and frozen identity disagree')
    return files, archive_bytes


def check_package(dist, args, evidence, routes, pack_expect=None):
    evidence.mkdir(parents=True, exist_ok=True)
    work = getattr(args, 'work', None) or evidence / 'work'
    work.mkdir(parents=True, exist_ok=True)
    checks = []

    def record(name, ok, detail=''):
        checks.append({'name': name, 'ok': bool(ok), 'detail': detail})
        print('%s %s%s' % ('PASS' if ok else 'FAIL', name, '' if detail in ('', None) else ' (%s)' % str(detail)[:400]))
        return ok

    sums_text = (dist / 'SHA256SUMS').read_text() if (dist / 'SHA256SUMS').is_file() else ''
    sums = dict(reversed(line.split('  ', 1)) for line in sums_text.splitlines() if '  ' in line)
    zips = sorted(dist.glob(BUILD + '-*.zip'))
    build = json.loads((dist / 'BUILD.json').read_text()) if (dist / 'BUILD.json').is_file() else {}
    files, archive_bytes = [], None
    try:
        files, archive_bytes = verify_source_manifest(build)
        record('source manifest matches its committed tree, file hashes and helpers', True, build['source_commit'])
    except (Rejected, KeyError) as error:
        record('source manifest matches its committed tree, file hashes and helpers', False, str(error))
    identity = build.get('identity') or {}
    args.identity = identity
    expected_zips = sorted('%s-%s-%s.zip' % (BUILD, platform, str(build.get('source_commit', ''))[:8])
                           for platform in ['linux-x86_64', 'windows-x86_64'])
    record('manifest names exactly the two packages', sorted(build.get('platforms', [])) == expected_zips == [z.name for z in zips], [z.name for z in zips])
    record('SHA256SUMS lists exactly the zips', sorted(sums) == [z.name for z in zips] and len(zips) == 2, sorted(sums))
    record('zip checksums match', len(zips) == 2 and all(digest(z) == sums.get(z.name) for z in zips))
    record('manifest status is labelled', build.get('release_candidate') in (True, False) and bool(build.get('status')), build.get('status'))
    provenance = templates()
    extracted = {}
    licences = licence_files(files) if files else {}
    expected_licences = sorted(licences)
    top = Path(git('rev-parse', '--show-toplevel').strip())
    for z in zips:
        platform = 'linux-x86_64' if '-linux-' in z.name else 'windows-x86_64'
        target = work / ('extract-' + platform)
        shutil.rmtree(target, ignore_errors=True)
        try:
            extract(z, target)
        except (zipfile.BadZipFile, OSError) as error:
            record(platform + ': zip opens', False, str(error))
            continue
        folder = target / ('%s-%s' % (NAME, platform))
        runtimes = LINUX if platform.startswith('linux') else WINDOWS
        found = sorted(str(p.relative_to(target)) for p in target.rglob('*') if p.is_file())
        found = [str(Path(n).relative_to(folder.name)) if n.startswith(folder.name + '/') else '../' + n for n in found]
        expected = sorted([*runtimes, NAME + '.pck', 'README.txt', 'BUILD.json'] + expected_licences)
        (evidence / ('files-%s.txt' % platform)).write_text(''.join('%s  %s\n' % (digest(folder / n), n) for n in found if not n.startswith('../')))
        record(platform + ': nothing but runtime, pack, readme, manifest and licences', folder.is_dir() and found == expected, sorted(set(found) ^ set(expected)))
        record(platform + ': runtime is the official release template, never the editor', all(
            (folder / t).is_file() and digest(folder / t) == TEMPLATE_MEMBERS[s] == provenance['members']['templates/' + s] for t, s in runtimes.items())
            and not any(digest(folder / n) == EDITOR_SHA256 for n in found if not n.startswith('../') and (folder / n).is_file()))
        if platform.startswith('linux'):
            with zipfile.ZipFile(z) as opened:
                modes = {Path(i.filename).name: i.external_attr >> 16 & 0o777 for i in opened.infolist()}
            record(platform + ': the runtime keeps its executable bit', modes.get(NAME + '.x86_64', 0) & 0o111 == 0o111
                   and os.access(folder / (NAME + '.x86_64'), os.X_OK), oct(modes.get(NAME + '.x86_64', 0)))
        licences_ok = bool(files)
        for name, (origin, source_name) in licences.items():
            if origin == 'godot':
                licences_ok = licences_ok and (folder / name).is_file() and digest(folder / name) == LICENCE_SHA256[source_name]
            else:
                blob = git('show', '%s:%s/%s' % (build['source_commit'], build['source_project_path'], source_name), binary=True, cwd=top)
                licences_ok = licences_ok and (folder / name).is_file() and (folder / name).read_bytes() == blob
        record(platform + ': licences and asset provenance equal the pinned and committed bytes', licences_ok, len(expected_licences))
        manifest = json.loads((folder / 'BUILD.json').read_text()) if (folder / 'BUILD.json').is_file() else {}
        common = {k: v for k, v in build.items() if k != 'platforms'}
        record(platform + ': embedded and external provenance agree', all(manifest.get(k) == v for k, v in common.items())
               and manifest.get('platform') == platform and manifest.get('runtime_sha256') ==
               {target: TEMPLATE_MEMBERS[source] for target, source in runtimes.items()})
        pack_sha = digest(folder / (NAME + '.pck')) if (folder / (NAME + '.pck')).is_file() else ''
        record(platform + ': manifest names this pack and build', manifest.get('pack_sha256') == pack_sha and manifest.get('build') == BUILD
               and (pack_expect is None or pack_sha == pack_expect), pack_sha)
        notes = (folder / 'README.txt').read_bytes() if (folder / 'README.txt').is_file() else b''
        registry = identity.get('registry', {})
        labels = [registry.get('presets', {}).get(i, {}).get('label', '?') for i in registry.get('order', [])]
        record(platform + ': readme names the build, every preset and the launch', BUILD.encode() in notes and labels and
               all(label.encode() in notes for label in labels) and (b'\r\n' in notes) == platform.startswith('windows'))
        extracted[platform] = (folder, pack_sha)
    if len(extracted) == 2:
        record('both platforms carry the same pack', extracted['linux-x86_64'][1] == extracted['windows-x86_64'][1])
    # windows is static only; its extracted copy is not needed for the runs.
    shutil.rmtree(work / 'extract-windows-x86_64', ignore_errors=True)
    static_ok = all(c['ok'] for c in checks)
    runs = {}
    try:
        if static_ok and 'linux-x86_64' in extracted:
            runs = check_runs(extracted['linux-x86_64'], args, evidence, identity, routes, record, work)
    finally:
        # the bulky runtimes stay in the zips; the evidence keeps their hashes.
        shutil.rmtree(work, ignore_errors=True)
    ok = all(c['ok'] for c in checks)
    result = {'ok': ok, 'build': BUILD, 'checks': checks, 'runs': runs,
              'routes': [r['route'] for r in routes] if routes else [],
              'play_proof': 'none: no route given' if not routes else '%d packed route(s) with reload' % len(routes),
              'scope': 'Linux release runtime from the zip, private %s, Dummy audio, isolated XDG; ' % args.native_backend +
                       'engine-injected key, relative-mouse and click events; Windows static only',
              'windows_native_execution': 'not verified: zip contents and runtime hashes only',
              'release_candidate': build.get('release_candidate'), 'status': build.get('status'),
              'probe_sha256': runs.get('probe_sha256') if isinstance(runs, dict) else None, 'tool_sha256': EXECUTED_TOOL_SHA256,
              'packaging_helpers_sha256': build.get('helpers_sha256'),
              'rechecker': 'current checker and probe hashes above; packaging helper hashes are verified separately against source'}
    if not static_ok:
        result['runs'] = 'skipped: static checks failed'
    (evidence / 'summary.json').write_text(json.dumps(result, indent=2, ensure_ascii=False) + '\n')
    return result


def profile_root(profile):
    return profile / 'data/godot/app_userdata' / PROJECT_NAME


def profile_files(profile):
    # files the game itself wrote under app_userdata, without godot's logs and shader cache.
    root = profile / 'data/godot/app_userdata'
    return {str(p.relative_to(root)): digest(p) for p in sorted(root.rglob('*')) if root.exists()
            and p.is_file() and 'shader_cache' not in p.parts and 'logs' not in p.parts}


def seed_old_profiles(profile):
    root = profile_root(profile)
    root.mkdir(parents=True, exist_ok=True)
    for name, label in OLD_PROFILES.items():
        (root / name).write_text('; seeded by tools/package-r15.py: %s records that r15 must never read or write\n[profile]\nround="%s"\n' % (label, label))
    return {name: digest(root / name) for name in OLD_PROFILES}


def spec_for(mode, folder, out, args, identity, extra, where=None):
    # a route starts on its own preset: the default start's runner chain is swapped for the route's.
    loaded = set(identity.get('loaded_at_start', []))
    if where:
        loaded -= set(identity.get('start', {}).get('runner_chain', []))
        loaded |= set(identity.get('keys', {}).get(where['map'], {}).get(where['preset'], {}).get('runner_chain', []))
    expect = dict(EXPECT, identity=identity, pack_sha256=digest(folder / (NAME + '.pck')), pack_required=args.pack_required,
                  loaded_required=sorted(loaded | set(args.require)), **extra)
    return {'mode': mode, 'out': str(out), 'pack': str(folder / (NAME + '.pck')), 'expect': expect, 'settle_frames': 45}


def native(harness, out, spec, args, profile, fps, user_args=()):
    """one probe run of the shipped runtime on the private display, from an empty directory."""
    (out / 'cwd').mkdir(parents=True)
    (out / 'spec.json').write_text(json.dumps(spec, indent=1, ensure_ascii=False))
    titles = set()
    require_space(out, 'a native capture')
    display = args._active_display
    env = engine_env(profile, display.number)
    watch = window_titles(display.number, titles)
    gpu = None
    if args.native_backend == 'amd':
        env = display.child_env(env)
        gpu = display.gpu_watch()
        watch = nd.combine(watch, gpu)
    code, text = run_engine([harness / (NAME + '.x86_64'), '--display-driver', 'x11', '--audio-driver', 'Dummy', '--fixed-fps', str(fps),
                             '--', '--pack-probe=%s' % (out / 'spec.json'), *user_args],
                            out / 'cwd', env, out / 'engine.log', args.deadline, watch)
    for cache in list(Path(profile).rglob('shader_cache')):
        shutil.rmtree(cache, ignore_errors=True)
    report = json.loads((out / 'probe.json').read_text()) if (out / 'probe.json').is_file() else {}
    backend = {'requested': args.native_backend, 'display': display.number, 'device': nd.godot_device(text), 'ok': True}
    if gpu is not None:
        backend['gpu'] = gpu.verdict()
        backend['ok'] = bool(backend['gpu']['ok'] and backend['device'] and 'AMD' in backend['device']['device']
                             and not nd.SOFTWARE.search(backend['device']['device']))
    (out / 'native-backend.json').write_text(json.dumps(backend, indent=1) + '\n')
    report['native_backend'] = backend
    if not backend['ok']:
        report.setdefault('checks', []).append({'name': 'requested AMD renderer actually drew', 'ok': False, 'detail': backend})
        report['failures'] = int(report.get('failures') or 0) + 1
    return code, text, report, titles


def route_args(route):
    args = ['--r15-map=' + route['map'], '--r15-preset=' + route['preset']]
    if 'sensitivity' in route:
        args.append('--r15-source-sensitivity=%r' % route['sensitivity'])
    return args


def sparse_movie(frames_dir, fps, target):
    """the play captures as an mp4; the pngs are removed except a few selected frames."""
    pngs = sorted(p for p in frames_dir.glob('*_tick_*.png'))
    if len(pngs) < 2:
        return {'frames': len(pngs), 'mp4': None}
    listing = frames_dir / 'frames.txt'
    listing.write_text(''.join("file '%s'\nduration %.6f\n" % (p, 1.0 / fps) for p in pngs))
    code = subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'concat', '-safe', '0', '-i', listing, '-vf', 'pad=ceil(iw/2)*2:ceil(ih/2)*2',
                           '-c:v', 'libx264', '-crf', '20', '-pix_fmt', 'yuv420p', target], capture_output=True, text=True)
    listing.unlink()
    probe = subprocess.run(['ffprobe', '-v', 'error', '-count_frames', '-select_streams', 'v:0', '-show_entries', 'stream=nb_read_frames',
                            '-of', 'csv=p=0', target], capture_output=True, text=True)
    decoded = probe.stdout.strip()
    ok = code.returncode == 0 and decoded.isdigit() and int(decoded) >= len(pngs) - 1
    keep = set(pngs[::max(1, len(pngs) // 6)][:6] + [pngs[-1]])
    if ok:
        for p in pngs:
            if p not in keep:
                p.unlink()
    return {'frames': len(pngs), 'mp4': str(target) if ok else None, 'decoded_frames': decoded, 'kept': sorted(str(p) for p in keep),
            'error': code.stderr[-300:] if code.returncode else ''}


def check_runs(extracted, args, evidence, identity, routes, record, work):
    folder, _ = extracted
    runs = {}
    start = identity.get('start', {})
    # 1. a player's launch path: the shipped binary finds its pack, from an empty directory.
    cwd = evidence / 'runs/startup-headless/cwd'
    cwd.mkdir(parents=True)
    profile = evidence / 'runs/startup-headless/profile'
    code, text = run_engine([folder / (NAME + '.x86_64'), '--headless', '--audio-driver', 'Dummy', '--', '--verify-startup'],
                            cwd, engine_env(profile), evidence / 'runs/startup-headless/engine.log', 120)
    line = STARTUP.search(text)
    runs['startup_headless'] = {'exit': code, 'line': line.group(0) if line else None}
    record('shipped binary starts r15 from its own pack on the default map and preset', code == 0 and line and line['build'] == BUILD
           and line['map'] == DEFAULT_MAP and line['preset'] == DEFAULT_PRESET and int(line['hz']) == int(start.get('physics_hz', -1))
           and line['key'] == start.get('course_key') and line['runner'] == (start.get('runner_chain') or ['?'])[0]
           and line['renderer'] == 'gl_compatibility' and line['records'] == 'off', line.group(0) if line else 'no startup line')
    record('headless startup is error-free', not ERRORS.search(text), ERRORS.findall(text)[:3])
    record('headless startup writes no records', not [p for p in profile_files(profile) if p.endswith('.cfg')])
    record('working directory stays empty', not any(cwd.iterdir()))
    # 2. native runs through a harness copy: the same bytes plus an override.cfg naming the probe.
    harness = work / 'harness'
    harness.mkdir()
    for name in [NAME + '.x86_64', NAME + '.pck']:
        # hard links: the same bytes as the extracted zip, without another copy on disk.
        os.link(folder / name, harness / name)
    executed_probe = evidence / 'runs/executed-probe.gd'
    shutil.copy2(getattr(args, 'probe', PROBE), executed_probe)
    runs['probe_sha256'] = digest(executed_probe)
    (harness / 'override.cfg').write_text('[autoload]\nPackProbe="*%s"\n' % executed_probe)
    record('harness runtime and pack are byte-identical to the zip', all(digest(harness / n) == digest(folder / n) for n in [NAME + '.x86_64', NAME + '.pck']))
    context = nd.NativeDisplay(evidence / 'runs/native-display') if args.native_backend == 'amd' else Display(args.display, evidence / 'runs/xvfb.log')
    with context as display:
        args._active_display = display
        # controls: every hotkey, the pause menu and both maps, on a fresh profile.
        out = evidence / 'runs/controls'
        profile = out / 'profile'
        seeded = seed_old_profiles(profile)
        before = profile_files(profile)
        code, text, report, titles = native(harness, out, spec_for('controls', harness, out, args, identity, {'profile_state': 'new'}),
                                            args, profile, args.controls_fps)
        after = profile_files(profile)
        runs['controls'] = {'exit': code, 'failures': report.get('failures'), 'titles': sorted(titles), 'frames': len(report.get('frames', [])),
                            'native_backend': report.get('native_backend'),
                            'failed': [c['name'] for c in report.get('checks', []) if not c['ok']] or report.get('abort')}
        record('controls: probe ran and found no failures', report.get('failures') == 0, runs['controls']['failed'])
        _common(record, 'controls', code, text, titles, out, identity, start)
        record('controls: no profile written without a finish or a setting change', after == before, sorted(set(after) ^ set(before)))
        record('controls: earlier rounds\' records untouched', all(after.get(PROJECT_NAME + '/' + n) == h for n, h in seeded.items()))
        controls_ok = report.get('failures') == 0 and code == 0 and not ERRORS.search(text)
        if not controls_ok:
            runs['routes_skipped'] = 'controls failed; repair before spending native runs on routes'
        for route in routes if controls_ok else []:
            name = route['route']['name']
            profile = evidence / 'runs' / name / 'profile'
            seeded = seed_old_profiles(profile)
            hz = int(route['physics_hz'])
            best = {}
            for mode in ['play', 'reload']:
                out = evidence / 'runs' / name / mode
                if mode == 'play':
                    extra = {'profile_state': 'new'}
                else:
                    extra = {'profile_state': 'loaded', 'records': best}
                spec = spec_for(mode, harness, out, args, identity, extra, route['route'])
                spec['route'] = route['route']
                if mode == 'play':
                    spec.update(tape=route['tape'], arm_motor_steps=route['arm_motor_steps'], reference_trace=route.get('trace', ''),
                                capture_ticks=list(range(0, int(route['ticks']), max(1, hz // 2))))
                before = profile_files(profile)
                code, text, report, titles = native(harness, out, spec, args, profile, hz, route_args(route['route']))
                after = profile_files(profile)
                failed = [c['name'] for c in report.get('checks', []) if not c['ok']] or report.get('abort')
                runs.setdefault(name, {})[mode] = {'exit': code, 'failures': report.get('failures'), 'failed': failed, 'titles': sorted(titles),
                                                   'native_backend': report.get('native_backend'),
                                                   'run': report.get('run'), 'reference': report.get('reference'), 'pause': report.get('pause'),
                                                   'tape': report.get('tape'), 'profile_after': after}
                record('%s %s: probe ran and found no failures' % (name, mode), report.get('failures') == 0, failed)
                _common(record, '%s %s' % (name, mode), code, text, titles, out, identity, {'map': route['route']['map'], 'preset': route['route']['preset']})
                written = sorted(set(after) - set(before)) if mode == 'play' else []
                if mode == 'play':
                    run = report.get('run') or {}
                    best = {key: run.get(key) for key in ['best_time', 'open_best_time', 'best_splits', 'best_segments', 'record_ticks']}
                    runs[name][mode]['record_text_loss_s'] = report.get('record_text_loss_s')
                    record('%s play: readable summary rounding measured; exact tick payload checked by probe' % name,
                           isinstance(report.get('record_text_loss_s'), (int, float)), report.get('record_text_loss_s'))
                    record('%s play: only the r15 records file was written' % name, written == [PROJECT_NAME + '/' + SAVE_PATH.removeprefix('user://')], written)
                    exact = shipped_trace_match(out / 'trace.jsonl', route.get('trace', ''))
                    runs[name][mode]['exact_reference'] = exact
                    record('%s play: shipped trace equals the source executor exactly' % name, exact.get('ok'), exact)
                    runs[name][mode]['movie'] = sparse_movie(out / 'frames', 2.0, out / 'play.mp4')
                    record('%s play: sparse movie encoded and decodes' % name, runs[name][mode]['movie'].get('mp4') is not None, runs[name][mode]['movie'])
                else:
                    record('%s reload: the profile is read, not rewritten' % name, after == before, sorted(set(after) ^ set(before)))
                record('%s %s: earlier rounds\' records untouched' % (name, mode), all(after.get(PROJECT_NAME + '/' + n) == h for n, h in seeded.items()))
    runs['display_released'] = display.released
    record('private display released', display.released)
    record('executed probe stayed unchanged', digest(executed_probe) == runs['probe_sha256'])
    leftovers = owned_leftovers(evidence / 'runs')
    record('no owned engine process remains', not leftovers, leftovers)
    return runs


def _common(record, label, code, text, titles, out, identity, where):
    record(label + ': Quit on the pause panel ended the game', code == 0, code)
    record(label + ': engine log is error-free', not ERRORS.search(text), ERRORS.findall(text)[:3])
    maps, presets = identity.get('maps', {}), identity.get('registry', {}).get('presets', {})
    wanted = '%s%s · %s · %s Hz' % (TITLE_PREFIX, maps.get(where['map'], {}).get('name', '?'), presets.get(where['preset'], {}).get('label', '?'),
                                    identity.get('keys', {}).get(where['map'], {}).get(where['preset'], {}).get('physics_hz', '?'))
    record(label + ': os window title', wanted in titles, sorted(titles))
    record(label + ': working directory stays empty', not any((out / 'cwd').iterdir()))


# --- source mode (tools/check-r15.sh) ----------------------------------------------------------

def source_mode(args):
    """identity and routes on an imported source copy outside Git, for the source wrapper."""
    source = args.source.resolve()
    evidence = args.evidence.resolve()
    if evidence.exists() and any(evidence.iterdir()):
        raise Rejected('evidence directory %s already has files' % evidence)
    evidence.mkdir(parents=True, exist_ok=True)
    files = sorted(str(p.relative_to(source)) for p in source.rglob('*') if p.is_file() and '.godot' not in p.parts)
    identity = source_identity(source, evidence, files, source / 'tools/r15-pack-probe.gd')
    results = {'identity': {k: identity[k] for k in ('start', 'registry', 'keys')}, 'routes': []}
    ok = True
    for route in args.route:
        try:
            result = source_route(route, source, evidence / 'routes', identity)
            external = result.get('external_reference')
            line_ok = external is None or external['ok']
            print('%s route %s: %s %.6f s, respawns %s, ordered %s, rate %s%s' % ('PASS' if line_ok else 'FAIL', route['name'],
                  result['source_finish']['finish_kind'], result['source_finish']['elapsed'], result['source_finish']['respawns'],
                  result['ordered'], result['rate_ok'], '' if external is None else ', external reference: %d/%d ticks, max %.9f m, first difference %s, game state differs at %s (known %s)' % (
                      external['ticks'], external['reference_ticks'], external['max_position_m'], external['first_position_difference_tick'],
                      external['game_difference_ticks'] or 'no tick', external['known_game_difference_ticks'] or 'none')))
            ok = ok and line_ok
        except Rejected as error:
            result = {'route': route, 'error': str(error)}
            print('FAIL route %s: %s' % (route['name'], error))
            ok = False
        results['routes'].append(result)
    for preset, key in identity['keys'].get(identity['start']['map'], {}).items():
        print('PASS identity %s: key %s, %d Hz, runner %s' % (preset, key['course_key'], key['physics_hz'], key['runner_chain'][0]))
    (evidence / 'summary.json').write_text(json.dumps(results, indent=2, ensure_ascii=False) + '\n')
    compress_evidence(evidence)
    return ok


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest='command', required=True)
    for name in ['package', 'check', 'source']:
        p = sub.add_parser(name)
        p.add_argument('--route', action='append', default=[], type=parse_route,
                       help='map=ID,preset=ID,tape=PATH[,sensitivity=S][,name=N][,reference=TRACE] (repeatable)')
        if name == 'source':
            continue
        p.add_argument('--require', action='append', default=[], help='a res:// module the running game must load (repeatable)')
        p.add_argument('--display', type=int, default=181, help='private Xvfb display number')
        p.add_argument('--native-backend', choices=('xvfb', 'amd'), default='xvfb',
                       help='amd requires the verified private Weston/X11 backend; no software fallback')
        p.add_argument('--deadline', type=float, default=3600,
                       help='per native run, seconds; llvmpipe draws 3.5 to 4 frames a second, so a 46 s course at 128 hz takes ~1750 s')
        p.add_argument('--controls-fps', type=int, default=60, help='fixed render rate of the controls run')
        p.add_argument('--scratch', type=Path, help='where transient copies go (default: inside --output or --evidence); '
                       'a RAM disk keeps /home above the storage floor')
    package_parser, check_parser, source_parser = sub.choices['package'], sub.choices['check'], sub.choices['source']
    package_parser.add_argument('--output', type=Path, required=True, help='a new or empty directory outside Git')
    package_parser.add_argument('--startup-only', action='store_true', help='no packed play proof; says so in VERIFICATION.json')
    package_parser.add_argument('--diagnostic', action='store_true', help='label the package non-release (tools not yet committed upstream)')
    check_parser.add_argument('package_dir', type=Path, help='a directory holding the zips, BUILD.json and SHA256SUMS')
    check_parser.add_argument('--evidence', type=Path, required=True, help='a new directory for logs and frames')
    source_parser.add_argument('--source', type=Path, required=True, help='an imported source copy outside Git')
    source_parser.add_argument('--evidence', type=Path, required=True, help='a new directory for logs')
    engine_parser = sub.add_parser('engine', help='owned source-suite child with a deadline and cancellation cleanup')
    engine_parser.add_argument('--cwd', type=Path, required=True)
    engine_parser.add_argument('--log', type=Path, required=True)
    engine_parser.add_argument('--deadline', type=float, default=600)
    engine_parser.add_argument('argv', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    try:
        if args.command == 'engine':
            command = args.argv[1:] if args.argv[:1] == ['--'] else args.argv
            if not command:
                raise Rejected('engine needs a command after --')
            code, _ = run_engine(command, args.cwd, os.environ.copy(), args.log, args.deadline, cleanup_grace=35)
            sys.exit(code if type(code) is int else 124)
        elif args.command == 'package':
            package(args)
        elif args.command == 'source':
            sys.exit(0 if source_mode(args) else 1)
        else:
            evidence = args.evidence.expanduser().resolve()
            if evidence.exists() and any(evidence.iterdir()):
                raise Rejected('evidence directory %s already has files' % evidence)
            evidence.mkdir(parents=True, exist_ok=True)
            args.work = Path(tempfile.mkdtemp(prefix='r15-check-', dir=args.scratch or evidence))
            # the resources a package must hold come from its own source commit, not this checkout.
            build = json.loads((args.package_dir / 'BUILD.json').read_text())
            files = git('ls-tree', '-r', '--name-only', '--full-tree', build['source_commit'] + ':' + build['source_project_path']).split('\n')
            args.pack_required = sorted(set(resources(files)) | set(args.require))
            routes = []
            packed_cadence(args.route)
            if args.route:
                # a recheck replays each route in source mode on a fresh freeze of the package's commit.
                routes = recheck_routes(build, args, evidence)
            result = check_package(args.package_dir.resolve(), args, evidence, routes)
            compress_evidence(evidence)
            sys.exit(0 if result['ok'] else 1)
    except (Rejected, nd.NativeDisplayError) as error:
        print('package-r15: ' + str(error), file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        print('package-r15: cancelled; owned process scopes released', file=sys.stderr)
        sys.exit(130)


def recheck_routes(build, args, evidence):
    top = Path(git('rev-parse', '--show-toplevel').strip())
    stage = evidence / 'source-freeze'
    with tarfile.open(fileobj=io.BytesIO(source_archive(build['source_commit'], build['source_project_path'], top))) as frozen:
        frozen.extractall(stage, filter='data')
    checked([EDITOR, '--headless', '--path', stage, '--import'], stage, engine_env(evidence / 'freeze-profile'), evidence / 'freeze-import.log')
    routes = [source_route(route, stage, evidence / 'source-routes', build['identity']) for route in args.route]
    args.probe = stage / 'tools/r15-pack-probe.gd'
    shutil.copy2(args.probe, evidence / 'frozen-probe.gd')
    args.probe = evidence / 'frozen-probe.gd'
    shutil.rmtree(stage, ignore_errors=True)
    return routes


if __name__ == '__main__':
    main()
