#!/usr/bin/env python3
"""checks for tools/r14_native_display.py, the optional private amd/x11 display.

    python3 -I tests/test_r14_native_display.py                       offline checks only
    R14_NATIVE_DISPLAY=1 python3 -I tests/test_r14_native_display.py  + live backend and negative paths
    R14_NATIVE_SOURCE=DIR ...                                         + the real r14 scene: os-level Escape and Quit click
    python3 -I tests/test_r14_native_display.py prepare COMMIT DIR    git archive + import a source copy outside git
    python3 -I tests/test_r14_native_display.py overflow --source DIR --tape T --game G --evidence E
                                                                      headless reference and native amd replay of one tape

live checks need /home above the 15 GiB floor and a desktop :0 that answers; they never use
the desktop display for anything but xdpyinfo. docs/r14/NATIVE-DISPLAY.md.
"""
import argparse
import gzip
import importlib.util
import io
import json
import os
from pathlib import Path
import re
import shutil
import signal
import socket
import subprocess
import sys
import tarfile
import tempfile
import time
import unittest
from unittest import mock

PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT / 'tools'))
import r14_native_display as nd  # noqa: E402

GODOT = Path.home() / '.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64'
LIVE = os.environ.get('R14_NATIVE_DISPLAY') == '1' or bool(os.environ.get('R14_NATIVE_SOURCE'))
SOURCE = Path(os.environ['R14_NATIVE_SOURCE']) if os.environ.get('R14_NATIVE_SOURCE') else None
KEEP = Path(os.environ['R14_NATIVE_KEEP']) if os.environ.get('R14_NATIVE_KEEP') else None
ERRORS = re.compile(r'SCRIPT ERROR:|(^|\s)ERROR:|Parse Error:|Failed to load', re.M)
AMD_LINE = 'OpenGL API 4.6 (Core Profile) Mesa 26.2.5-arch1.1 - Compatibility - Using Device: AMD - AMD Radeon Graphics (radeonsi, renoir, ACO, DRM 3.64, 7.2.8-9-omarchy)'
SOFT_LINE = 'OpenGL API 4.5 (Core Profile) Mesa 26.2.5-arch1.1 - Compatibility - Using Device: Mesa - llvmpipe (LLVM 21.1.6, 256 bits)'
# a minimal gl client project: draws a few frames and quits, nothing else.
TINY_PROJECT = '[application]\nconfig/name="native-display-check"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n'
TINY_SCRIPT = '''extends SceneTree
var frames := 0
func _initialize() -> void:
	var box := ColorRect.new()
	box.color = Color(0.8, 0.4, 0.1)
	box.size = Vector2(400, 300)
	root.add_child(box)
func _process(_delta: float) -> bool:
	frames += 1
	if frames == 1:
		print("tiny: display=%s adapter=%s" % [DisplayServer.get_name(), RenderingServer.get_video_adapter_name()])
	return frames >= 120
'''
# p / the real r14 scene under an observer that only reads: it reports when the game is up and
# where the pause menu's Quit button is in window pixels, so os-level input can press it.
OBSERVER = '''extends SceneTree
## native display check only: the real r14 scene, observed. it never writes game state.
var _frames := 0
var _told := false
func _initialize() -> void:
	change_scene_to_file("res://scenes/r14.tscn")
func _process(_delta: float) -> bool:
	_frames += 1
	var main := current_scene
	if _frames == 120 and main != null:
		print("native-observer: ready display=%s adapter=%s title=%s" % [DisplayServer.get_name(), RenderingServer.get_video_adapter_name(), root.title])
	if main != null and not _told and bool(main.get("paused")):
		var hud = main.get("hud")
		var button = hud.get("quit_button") if hud != null else null
		if button != null and button.is_visible_in_tree():
			_told = true
			var at: Vector2 = root.get_final_transform() * (button.get_global_transform_with_canvas() * (button.size / 2.0))
			print("native-observer: paused; quit_window=%d,%d" % [int(at.x), int(at.y)])
	return false
'''


_SCRATCH = []


def scratch(name):
    # per-check directories: under R14_NATIVE_KEEP when evidence is wanted, else removed at exit.
    if KEEP:
        path = KEEP / name
        if path.exists():
            shutil.rmtree(path)
        path.mkdir(parents=True)
        return path
    if not _SCRATCH:
        _SCRATCH.append(Path(tempfile.mkdtemp(prefix='r14nd-test-')))
    return Path(tempfile.mkdtemp(prefix=name + '-', dir=_SCRATCH[0]))


def tearDownModule():
    for path in _SCRATCH:
        shutil.rmtree(path, ignore_errors=True)


def x_paths(number):
    return [p for p in ['/tmp/.X%d-lock' % number, '/tmp/.X11-unix/X%d' % number] if os.path.lexists(p)]


def assert_released(case, display):
    record = json.loads((display.evidence / 'native-display.json').read_text())
    case.assertTrue(display.released, record['cleanup'])
    case.assertTrue(record['clean'])
    case.assertEqual(record['cleanup']['owned_processes_remaining'], [])
    for pid in record.get('pids', {}).values():
        case.assertFalse(nd._alive(pid), pid)
    if display.number is not None and record.get('owned_lock'):
        case.assertEqual(x_paths(display.number), [])
        case.assertNotIn('@/tmp/.X11-unix/X%d' % display.number, nd.unix_sockets())
    if record.get('runtime_dir'):
        case.assertFalse(Path(record['runtime_dir']).exists())
    if 'desktop_before' in record:
        case.assertTrue(record['desktop_after']['ok'])
    return record


def run_gl_client(display, out, cmd_tail, env_extra=None, input_steps=None, deadline=120):
    """launch one godot child on the private display (the caller's job in real use)."""
    profile = out / 'profile'
    base = dict(os.environ)
    for name in ['XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME', 'XDG_STATE_HOME']:
        (profile / name.lower()).mkdir(parents=True, exist_ok=True)
        base[name] = str(profile / name.lower())
    base.update(env_extra or {})
    env = display.child_env(base)
    watch = display.gpu_watch()
    log = out / 'game.log'
    with open(log, 'wb') as stream:
        game = subprocess.Popen([str(GODOT), *cmd_tail], env=env, cwd=out, stdout=stream, stderr=subprocess.STDOUT, start_new_session=True)
    watch.follow(game.pid)
    steps = {}
    try:
        if input_steps:
            steps = input_steps(game, log)
        code = game.wait(deadline)
    except BaseException:
        os.killpg(game.pid, signal.SIGKILL)
        game.wait(5)
        raise
    finally:
        watch.stop()
    return code, log.read_text(errors='replace'), watch, steps


def wait_for(path, pattern, process, timeout):
    limit = time.monotonic() + timeout
    while time.monotonic() < limit:
        match = re.search(pattern, Path(path).read_text(errors='replace')) if Path(path).exists() else None
        if match:
            return match
        if process.poll() is not None:
            raise AssertionError('process exited (%s) before %r' % (process.returncode, pattern))
        time.sleep(0.1)
    raise AssertionError('no %r within %.0f s' % (pattern, timeout))


def xdo(display, *args):
    return subprocess.run(['xdotool', *args], env=nd.minimal_env(DISPLAY=display.display), capture_output=True, text=True, timeout=15)


def screenshot(display, target):
    result = subprocess.run(['magick', 'import', '-display', display.display, '-window', 'root', str(target)],
                            env=nd.minimal_env(DISPLAY=display.display), capture_output=True, text=True, timeout=30)
    return {'path': str(target), 'exit': result.returncode, 'error': result.stderr[-200:],
            'sha256': nd.digest(target) if target.exists() else None}


# --- offline ------------------------------------------------------------------------------------

class LaunchCancellation(unittest.TestCase):
    def test_cancel_at_popen_return_keeps_the_child_owned(self):
        # no display or gpu is started: a disposable sleeping child stands in for weston.
        class LaunchOnly(nd.NativeDisplay):
            def _start(self):
                self.record['weston_package'] = {'module_map': ''}
                self._start_weston()

        real_popen = subprocess.Popen
        for sig in (signal.SIGINT, signal.SIGTERM):
            with self.subTest(signal=sig):
                spawned = []
                def cancel_after_spawn(_cmd, **options):
                    process = real_popen([sys.executable, '-c', 'import time; time.sleep(60)'], **options)
                    spawned.append(process)
                    os.kill(os.getpid(), sig)
                    return process
                display = LaunchOnly(scratch('launch-cancel-%d' % sig), desktop=None)
                try:
                    with mock.patch.object(nd.subprocess, 'Popen', side_effect=cancel_after_spawn):
                        with self.assertRaises(nd.Cancelled):
                            with display:
                                self.fail('cancellation must abort the launch')
                    self.assertEqual(len(spawned), 1)
                    self.assertFalse(nd._alive(spawned[0].pid), 'cancelled launch leaked its unassigned child')
                    assert_released(self, display)
                finally:
                    for process in spawned:
                        nd._stop_group(process)


class Offline(unittest.TestCase):
    def test_child_env_clears_forced_rendering_only_in_the_copy(self):
        base = {'LIBGL_ALWAYS_SOFTWARE': '1', 'GALLIUM_DRIVER': 'llvmpipe', 'MESA_LOADER_DRIVER_OVERRIDE': 'swrast', 'DISPLAY': ':0',
                'WAYLAND_DISPLAY': 'wayland-1', 'XAUTHORITY': '/x', 'EGL_PLATFORM': 'wayland', 'KEEP': 'yes'}
        before = dict(base)
        source = dict(os.environ)
        display = nd.NativeDisplay(scratch('env'), displays=(197,))
        display.env = {'DISPLAY': ':197'}
        env = display.child_env(base)
        self.assertEqual(base, before)
        self.assertEqual(dict(os.environ), source)
        self.assertEqual(env, {'DISPLAY': ':197', 'KEEP': 'yes'})

    def test_busy_display_checks_lock_socket_symlink_and_abstract(self):
        tmp = scratch('busy')
        (tmp / '.X11-unix').mkdir()
        self.assertEqual(nd.display_busy(196, tmp, sockets=set()), [])
        (tmp / '.X196-lock').write_text('      1\n')
        self.assertIn('lock file', nd.display_busy(196, tmp, sockets=set())[0])
        (tmp / '.X11-unix/X195').symlink_to(tmp / '.X11-unix/X195_')  # a dangling link, like X0 -> X0_
        self.assertIn('socket path', nd.display_busy(195, tmp, sockets=set())[0])
        self.assertIn('abstract', nd.display_busy(194, tmp, sockets={'@/tmp/.X11-unix/X194'})[0])
        self.assertIn('bound socket', nd.display_busy(194, tmp, sockets={'/tmp/.X11-unix/X194'})[0])

    def test_real_abstract_listener_is_seen(self):
        number = next(n for n in reversed(nd.DISPLAYS) if not nd.display_busy(n))
        listener = socket.socket(socket.AF_UNIX)
        try:
            listener.bind('\0/tmp/.X11-unix/X%d' % number)
            listener.listen(1)
            self.assertIn('abstract listener @/tmp/.X11-unix/X%d' % number, nd.display_busy(number))
        finally:
            listener.close()
        self.assertEqual(nd.display_busy(number), [])

    def test_claim_refuses_when_every_requested_number_is_held(self):
        tmp = scratch('claim')
        (tmp / '.X11-unix').mkdir()
        for n in (191, 192):
            (tmp / ('.X%d-lock' % n)).write_text('1\n')
        display = nd.NativeDisplay(scratch('claim-ev'), displays=(191, 192), _tmp=tmp)
        with self.assertRaises(nd.NativeDisplayError):
            display._claim_display()
        self.assertEqual([c['display'] for c in display.record['display_checks']], [191, 192])
        self.assertIsNone(display._weston)

    def test_two_sessions_never_claim_one_number(self):
        tmp = scratch('flock')
        (tmp / '.X11-unix').mkdir()
        first = nd.NativeDisplay(scratch('flock-a'), displays=(193, 194), _tmp=tmp)
        second = nd.NativeDisplay(scratch('flock-b'), displays=(193, 194), _tmp=tmp)
        self.assertEqual(first._claim_display(), 193)
        self.assertEqual(second._claim_display(), 194)
        first._flock.close()
        second._flock.close()

    def test_render_node_must_exist_and_be_amdgpu(self):
        with self.assertRaises(nd.NativeDisplayError):
            nd.render_node('/dev/dri/renderD199')
        with self.assertRaises(nd.NativeDisplayError):
            nd.render_node(nd.RENDER_NODE, driver='i915')
        self.assertEqual(nd.render_node()['driver'], 'amdgpu')

    def test_weston_files_are_checked_against_the_package_manifest(self):
        self.assertGreaterEqual(nd.verify_weston()['verified_files'], 29)
        copy = scratch('weston') / 'weston'
        shutil.copytree(nd.WESTON_ROOT, copy, symlinks=True)
        module = copy / 'usr/lib/libweston-15/headless-backend.so'
        data = bytearray(module.read_bytes())
        data[100] ^= 1
        module.write_bytes(bytes(data))
        with self.assertRaises(nd.NativeDisplayError):
            nd.verify_weston(copy)
        data[100] ^= 1
        module.write_bytes(bytes(data))
        nd.verify_weston(copy)
        mtree = copy / '.MTREE'
        original_manifest = mtree.read_bytes()
        mtree.write_bytes(gzip.compress(gzip.decompress(original_manifest) + b'\n# modified manifest\n'))
        with self.assertRaisesRegex(nd.NativeDisplayError, 'pinned package manifest'):
            nd.verify_weston(copy)
        mtree.write_bytes(original_manifest)
        (copy / 'usr/lib/libweston-15/extra.so').write_bytes(b'')
        with self.assertRaises(nd.NativeDisplayError):
            nd.verify_weston(copy)

    def test_engine_log_must_name_amd(self):
        self.assertIn('radeonsi', nd.require_amd_log('x\n' + AMD_LINE + '\n')['device'])
        for text in ['', SOFT_LINE]:
            with self.assertRaises(nd.NativeDisplayError):
                nd.require_amd_log(text)

    def test_gpu_watch_rejects_a_process_without_the_node(self):
        sleeper = subprocess.Popen(['sleep', '1'])
        watch = nd.GpuWatch(interval=0.1)
        watch(sleeper)
        self.assertFalse(watch.verdict()['ok'])
        self.assertGreater(watch.samples, 0)
        with self.assertRaises(nd.NativeDisplayError):
            watch.require()

    def test_refuses_an_evidence_directory_in_use(self):
        evidence = scratch('used')
        (evidence / 'weston.log').write_text('[0] GL renderer: AMD Radeon Graphics\n')
        with self.assertRaises(nd.NativeDisplayError):
            with nd.NativeDisplay(evidence):
                pass


# --- live backend -------------------------------------------------------------------------------

@unittest.skipUnless(LIVE, 'set R14_NATIVE_DISPLAY=1 for live private-display checks')
class Live(unittest.TestCase):
    def setUp(self):
        if shutil.disk_usage(Path.home()).free < nd.MIN_FREE_GIB * 2 ** 30:
            self.skipTest('below the 15 GiB /home floor')

    def test_session_gl_client_renders_on_amd_and_releases(self):
        evidence = scratch('live-gl')
        project = evidence / 'project'
        project.mkdir()
        (project / 'project.godot').write_text(TINY_PROJECT)
        (project / 'tiny.gd').write_text(TINY_SCRIPT)
        with nd.NativeDisplay(evidence / 'display') as display:
            self.assertIn(display.number, nd.DISPLAYS)
            self.assertNotIn(display.number, [0])
            self.assertEqual(display.record['private_x']['name'], display.display)
            code, text, watch, _ = run_gl_client(display, evidence, ['--path', str(project), '--audio-driver', 'Dummy', '--display-driver', 'x11',
                                                                     '--rendering-driver', 'opengl3', '--resolution', '640x480', '--script', 'res://tiny.gd'],
                                                 {'LIBGL_ALWAYS_SOFTWARE': '1', 'GALLIUM_DRIVER': 'llvmpipe'})
            self.assertEqual(code, 0, text[-800:])
            verdict = watch.require()
            self.assertIn('radeonsi', nd.require_amd_log(text)['device'])
            self.assertIn('tiny: display=X11', text)
        record = assert_released(self, display)
        (evidence / 'gpu.json').write_text(json.dumps(verdict, indent=1))
        self.assertIn('LIBGL_ALWAYS_SOFTWARE', record['child_env']['cleared'])

    def test_body_exception_releases_everything(self):
        evidence = scratch('live-raise')
        with self.assertRaises(ZeroDivisionError):
            with nd.NativeDisplay(evidence) as display:
                1 / 0
        record = assert_released(self, display)
        self.assertEqual(record['body_error']['type'], 'ZeroDivisionError')

    def test_sigterm_inside_the_block_cancels_and_restores_handlers(self):
        evidence = scratch('live-term')
        previous = signal.getsignal(signal.SIGTERM)
        with self.assertRaises(nd.Cancelled):
            with nd.NativeDisplay(evidence) as display:
                os.kill(os.getpid(), signal.SIGTERM)
                time.sleep(5)
        assert_released(self, display)
        self.assertIs(signal.getsignal(signal.SIGTERM), previous)

    def _wrapper(self, evidence, sig):
        code = ('import sys,time; sys.path.insert(0, %r); import r14_native_display as nd\n'
                'with nd.NativeDisplay(%r) as d:\n    print("READY", d.display, d.record["pids"]["weston"], d.record["pids"]["xwayland"], d.record["runtime_dir"], flush=True)\n'
                '    time.sleep(60)\n') % (str(PROJECT / 'tools'), str(evidence))
        child = subprocess.Popen([sys.executable, '-I', '-c', code], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        line = child.stdout.readline()
        self.assertTrue(line.startswith('READY'), line + child.stderr.read() if not line else line)
        fields = line.split()
        os.kill(child.pid, sig)
        child.wait(30)
        child.stdout.close()
        child.error = child.stderr.read()
        child.stderr.close()
        return child, int(fields[1][1:]), [int(fields[2]), int(fields[3])], Path(fields[4])

    def test_sigint_at_the_wrapper_boundary(self):
        evidence = scratch('live-int')
        child, number, _, _ = self._wrapper(evidence, signal.SIGINT)
        self.assertNotEqual(child.returncode, 0)
        self.assertIn('Cancelled', child.error)
        record = json.loads((evidence / 'native-display.json').read_text())
        self.assertTrue(record['clean'], record['cleanup'])
        self.assertEqual(x_paths(number), [])
        self.assertFalse(any(nd._alive(p) for p in record['pids'].values()))

    def test_sigkill_of_the_wrapper_still_stops_the_children(self):
        # not a cleanup path the wrapper can run: the children's parent-death signal does it.
        evidence = scratch('live-kill')
        child, number, pids, runtime = self._wrapper(evidence, signal.SIGKILL)
        limit = time.monotonic() + 10
        while time.monotonic() < limit and (x_paths(number) or any(nd._alive(p) for p in pids)):
            time.sleep(0.1)
        self.assertEqual([p for p in pids if nd._alive(p)], [])
        self.assertEqual(x_paths(number), [])
        self.assertNotIn('@/tmp/.X11-unix/X%d' % number, nd.unix_sockets())
        # what a killed wrapper cannot do itself: its private runtime directory stays behind.
        self.assertFalse((runtime / nd.SOCKET_NAME).exists())
        shutil.rmtree(runtime, ignore_errors=True)

    def test_weston_launch_failure(self):
        evidence = scratch('live-weston-fail')
        with self.assertRaises(nd.NativeDisplayError) as caught:
            with nd.NativeDisplay(evidence, _weston_args=('--backend=nonexistent-backend.so',)) as display:
                self.fail('entered')
        self.assertIn('weston', str(caught.exception))
        record = json.loads((evidence / 'native-display.json').read_text())
        self.assertTrue(record['clean'], record['cleanup'])
        self.assertEqual(record['error']['stage'], 'weston launch')
        self.assertFalse(nd._alive(record['pids']['weston']))
        self.assertFalse(Path(record['runtime_dir']).exists())

    def test_xwayland_launch_failure(self):
        evidence = scratch('live-xwayland-fail')
        with self.assertRaises(nd.NativeDisplayError) as caught:
            with nd.NativeDisplay(evidence, _xwayland_args=('-bogus-option',)):
                self.fail('entered')
        self.assertIn('exited early', str(caught.exception))
        record = json.loads((evidence / 'native-display.json').read_text())
        self.assertTrue(record['clean'], record['cleanup'])
        self.assertEqual(record['error']['stage'], 'xwayland launch')
        self.assertFalse(any(nd._alive(p) for p in record['pids'].values()))

    def test_missing_xwayland_starts_nothing(self):
        evidence = scratch('live-no-xwayland')
        with self.assertRaises(nd.NativeDisplayError):
            with nd.NativeDisplay(evidence, xwayland='/nonexistent/Xwayland'):
                self.fail('entered')
        record = json.loads((evidence / 'native-display.json').read_text())
        self.assertNotIn('pids', record)
        self.assertEqual(record['error']['stage'], 'xwayland binary')

    def test_software_weston_is_refused_not_used(self):
        evidence = scratch('live-software')
        with self.assertRaises(nd.NativeDisplayError) as caught:
            with nd.NativeDisplay(evidence, _weston_env={'LIBGL_ALWAYS_SOFTWARE': '1'}):
                self.fail('entered')
        self.assertIn('not rendering on amdgpu', str(caught.exception))
        record = json.loads((evidence / 'native-display.json').read_text())
        self.assertRegex(record['weston_gl']['GL renderer'], 'llvmpipe')
        self.assertTrue(record['clean'], record['cleanup'])

    def test_held_display_is_refused_without_launching(self):
        number = next(n for n in nd.DISPLAYS if not nd.display_busy(n))
        listener = socket.socket(socket.AF_UNIX)
        evidence = scratch('live-held')
        try:
            listener.bind('\0/tmp/.X11-unix/X%d' % number)
            listener.listen(1)
            with self.assertRaises(nd.NativeDisplayError):
                with nd.NativeDisplay(evidence, displays=(number,)):
                    self.fail('entered')
        finally:
            listener.close()
        record = json.loads((evidence / 'native-display.json').read_text())
        self.assertNotIn('pids', record)
        self.assertIn('abstract', record['display_checks'][0]['busy'][0])

    def test_two_live_sessions_get_different_numbers(self):
        evidence = scratch('live-two')
        with nd.NativeDisplay(evidence / 'a') as a, nd.NativeDisplay(evidence / 'b') as b:
            self.assertNotEqual(a.number, b.number)
            self.assertTrue(nd.x_answers(a.display, nd.minimal_env())['ok'] and nd.x_answers(b.display, nd.minimal_env())['ok'])
        assert_released(self, a)
        assert_released(self, b)


# --- the real r14 scene -------------------------------------------------------------------------

@unittest.skipUnless(SOURCE, 'set R14_NATIVE_SOURCE to an imported source copy (see prepare)')
class Game(unittest.TestCase):
    def test_r14_scene_quits_from_os_level_escape_and_click(self):
        evidence = scratch('game-quit')
        observer = evidence / 'observer.gd'
        observer.write_text(OBSERVER)
        report = {'source': str(SOURCE), 'observer_sha256': nd.digest(observer)}
        with nd.NativeDisplay(evidence / 'display') as display:
            def press_quit(game, log):
                steps = {'ready': wait_for(log, r'native-observer: ready.*', game, 60).group(0)}
                window = xdo(display, 'search', '--sync', '--onlyvisible', '--name', 'Spillway R14').stdout.split()
                self.assertTrue(window, 'no game window on the private display')
                steps['window'] = window[0]
                steps['geometry'] = xdo(display, 'getwindowgeometry', window[0]).stdout.strip()
                steps['title'] = xdo(display, 'getwindowname', window[0]).stdout.strip()
                xdo(display, 'mousemove', '--window', window[0], '640', '360')
                steps['pointer'] = xdo(display, 'getmouselocation').stdout.strip()
                time.sleep(0.5)
                steps['running_shot'] = screenshot(display, evidence / 'running.png')
                steps['escape'] = xdo(display, 'key', 'Escape').returncode
                at = wait_for(log, r'native-observer: paused; quit_window=(\d+),(\d+)', game, 20)
                steps['quit_window'] = [int(at.group(1)), int(at.group(2))]
                time.sleep(0.5)
                steps['paused_shot'] = screenshot(display, evidence / 'paused.png')
                xdo(display, 'mousemove', '--window', window[0], at.group(1), at.group(2))
                time.sleep(0.2)
                clicked = time.monotonic()
                steps['click'] = xdo(display, 'click', '1').returncode
                game.wait(30)
                steps['exit_after_click_s'] = time.monotonic() - clicked
                return steps
            code, text, watch, steps = run_gl_client(display, evidence, ['--path', str(SOURCE), '--audio-driver', 'Dummy', '--display-driver', 'x11',
                                                                         '--rendering-driver', 'opengl3', '--windowed', '--resolution', '1280x720',
                                                                         '--script', str(observer), '--', '--no-records'], input_steps=press_quit)
            report.update(exit=code, steps=steps, gpu=watch.verdict(), device=nd.godot_device(text), errors=ERRORS.findall(text)[:5])
        report['display'] = assert_released(self, display)
        (evidence / 'game-quit.json').write_text(json.dumps(report, indent=1, default=str))
        self.assertEqual(code, 0, text[-1500:])
        self.assertTrue(report['gpu']['ok'], report['gpu']['reasons'])
        nd.require_amd_log(text)
        self.assertFalse(report['errors'], report['errors'])
        self.assertLess(steps['exit_after_click_s'], 10)
        self.assertIn('Spillway R14', steps['title'])
        # the pause menu is visible in a capture of the private root: the display shows live frames.
        self.assertNotEqual(steps['running_shot']['sha256'], steps['paused_shot']['sha256'])


# --- source copies and the overflow smoke -------------------------------------------------------

def prepare(commit, target):
    """git archive one commit's project into target (outside git) and import it in a private profile."""
    target = Path(target).resolve()
    if target.exists():
        raise SystemExit('exists: %s' % target)
    prefix = subprocess.run(['git', '-C', str(PROJECT), 'rev-parse', '--show-prefix'], capture_output=True, text=True, check=True).stdout.strip()
    top = subprocess.run(['git', '-C', str(PROJECT), 'rev-parse', '--show-toplevel'], capture_output=True, text=True, check=True).stdout.strip()
    # from the top level: run inside the subdirectory, git archive also limits itself to that path.
    data = subprocess.run(['git', '-C', top, 'archive', '%s:%s' % (commit, prefix)], capture_output=True, check=True).stdout
    target.mkdir(parents=True)
    with tarfile.open(fileobj=io.BytesIO(data)) as archive:
        archive.extractall(target, filter='data')
    profile = Path(tempfile.mkdtemp(prefix='r14nd-import-'))
    env = dict(os.environ, **{n: str(profile / n.lower()) for n in ['XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME', 'XDG_STATE_HOME']})
    result = subprocess.run([str(GODOT), '--headless', '--audio-driver', 'Dummy', '--path', str(target), '--import'], env=env,
                            capture_output=True, text=True, timeout=300)
    shutil.rmtree(profile, ignore_errors=True)
    commit_id = subprocess.run(['git', '-C', str(PROJECT), 'rev-parse', commit], capture_output=True, text=True, check=True).stdout.strip()
    manifest = {'commit': commit_id, 'archive_sha256': nd.hashlib.sha256(data).hexdigest(), 'import_exit': result.returncode,
                'import_errors': [l for l in (result.stdout + result.stderr).splitlines() if ERRORS.search(l)][:20]}
    (target.parent / (target.name + '.source.json')).write_text(json.dumps(manifest, indent=1) + '\n')
    print(json.dumps(manifest, indent=1))
    return 0 if result.returncode == 0 else 1


def _tape_module(source):
    spec = importlib.util.spec_from_file_location('momentum_tape_copy', Path(source) / 'tools/momentum-tape.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _finish(run):
    rows = [json.loads(l) for l in gzip.open(run / 'evaluator/trace.jsonl.gz', 'rt')] if (run / 'evaluator/trace.jsonl.gz').exists() else \
        [json.loads(l) for l in open(run / 'evaluator/trace.jsonl')]
    tape = [r for r in rows if r.get('phase') == 'tape' and 'game' in r]
    stages = sorted({r['game'].get('checkpoint') for r in tape})
    last = tape[-1]['game'] if tape else {}
    return {k: last.get(k) for k in ['finished', 'finish_kind', 'elapsed', 'respawns', 'checkpoint']} | {'checkpoints_seen': stages}


def overflow(args):
    """the full tape twice on one source copy: the headless reference and a native amd replay
    at one draw per physics tick. native exactness is measured here, never assumed."""
    source, evidence = args.source.resolve(), args.evidence.resolve()
    if evidence.exists() and any(evidence.iterdir()):
        raise SystemExit('evidence %s is not empty' % evidence)
    evidence.mkdir(parents=True, exist_ok=True)
    mt = _tape_module(source)
    tape_bytes = args.tape.read_bytes()
    plan = mt.expand(json.loads(tape_bytes))
    hz = int(plan['physics_hz'])
    summary = {'scope': 'source-mode backend proof on one tape; not release-pack acceptance, performance, latency or feel',
               'source': str(source), 'source_manifest': json.loads((source.parent / (source.name + '.source.json')).read_text())
               if (source.parent / (source.name + '.source.json')).exists() else None,
               'tape': str(args.tape), 'tape_sha256': nd.hashlib.sha256(tape_bytes).hexdigest(), 'game': str(args.game),
               'game_sha256': nd.digest(args.game), 'engine_sha256': nd.digest(GODOT), 'physics_hz': hz, 'warmup': args.warmup,
               'render_fps': hz, 'motor': args.motor}
    reference = evidence / 'headless'
    common = ['--render-fps', str(hz), '--warmup', str(args.warmup), '--game-script', str(args.game), '--game-class', '', '--motor', args.motor]
    cmd = [sys.executable, '-I', str(source / 'tools/momentum-tape.py'), 'run', str(args.tape), '--out', str(reference), '--headless',
           '--wall-budget', '600', '--archive', *common]
    started = time.monotonic()
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=900)
    summary['headless'] = {'command': cmd, 'exit': result.returncode, 'wall_s': time.monotonic() - started,
                           'summary': json.loads(result.stdout) if result.stdout.strip().startswith('{') else result.stdout[-800:],
                           'finish': _finish(reference) if (reference / 'evaluator').exists() else None}
    native = evidence / 'native'
    for sub in ['evaluator', 'actor', 'control', 'profile', 'shots']:
        (native / sub).mkdir(parents=True)
    (native / 'evaluator/plan.json').write_text(json.dumps(plan, indent=1))
    run_id = 'native-%d' % os.getpid()
    # the tape executor's own arguments (tools/momentum-tape.py execute) with this display in
    # place of its private xvfb, and no movie or readback: one draw per fixed physics tick.
    gcmd = [str(GODOT), '--path', str(source), '--audio-driver', 'Dummy', '--display-driver', 'x11', '--rendering-driver', 'opengl3',
            '--windowed', '--resolution', '1280x720', '--fixed-fps', str(hz), '--script', str(source / 'tools/momentum-tape.gd'), '--',
            '--tape=%s' % (native / 'evaluator/plan.json'), '--out=%s' % native, '--motor=%s' % args.motor, '--fixture=',
            '--game-script=%s' % args.game, '--game-class=', '--sensitivity=1.0', '--inject=tick', '--warmup=%d' % args.warmup,
            '--frames=none', '--readback-every=4', '--wall-budget-s=900', '--run-id=%s' % run_id, '--physics-hz=%d' % hz]
    base = dict(os.environ, **{n: str(native / 'profile' / n.lower()) for n in ['XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME', 'XDG_STATE_HOME']})
    shots = []
    with nd.NativeDisplay(evidence / 'display') as display:
        watch = display.gpu_watch()
        started = time.monotonic()
        with open(native / 'evaluator/godot.log', 'wb') as log:
            game = subprocess.Popen(gcmd, env=display.child_env(base), cwd=native / 'profile', stdout=log, stderr=subprocess.STDOUT,
                                    start_new_session=True)
        watch.follow(game.pid)
        try:
            for at in args.shots:
                while game.poll() is None and time.monotonic() - started < at:
                    time.sleep(0.2)
                if game.poll() is None:
                    shots.append(dict(screenshot(display, native / 'shots' / ('wall-%03ds.png' % at)), wall_s=time.monotonic() - started))
            code = game.wait(900)
        except BaseException:
            os.killpg(game.pid, signal.SIGKILL)
            game.wait(5)
            raise
        finally:
            watch.stop()
        wall = time.monotonic() - started
    text = (native / 'evaluator/godot.log').read_text(errors='replace')
    report = mt.evaluate(native)
    (native / 'evaluator/report.json').write_text(json.dumps(report, indent=1))
    archived = mt.archive_run(native)
    end = json.loads((native / 'end.json').read_text())
    summary['native'] = {'command': gcmd, 'exit': code, 'wall_s': wall, 'end': end, 'gpu': watch.verdict(), 'device': nd.godot_device(text),
                         'errors': ERRORS.findall(text)[:5], 'shots': shots, 'delivery_ok': report.get('delivery', {}).get('ok'),
                         'order_ok': report.get('order', {}).get('ok'), 'rate_ok': report.get('rate', {}).get('ok'),
                         'movement_flags': report.get('movement_flags'), 'integrity_flags': report.get('integrity_flags'),
                         'finish': _finish(native), 'archived': bool(archived), 'draws_per_step': end.get('draws', 0) / max(1, end.get('steps', 1))}
    summary['display'] = display.record
    summary['comparison'] = mt.compare(reference, native)
    summary['tape_unchanged'] = nd.hashlib.sha256(args.tape.read_bytes()).hexdigest() == summary['tape_sha256']
    for run in (reference, native):
        shutil.rmtree(run / 'profile', ignore_errors=True)
    (evidence / 'OVERFLOW-NATIVE.json').write_text(json.dumps(summary, indent=1, default=str) + '\n')
    n = summary['native']
    print(json.dumps({'headless': summary['headless']['finish'], 'native': n['finish'], 'native_exit': code, 'native_wall_s': round(wall, 1),
                      'headless_wall_s': round(summary['headless']['wall_s'], 1), 'gpu_ok': n['gpu']['ok'], 'device': (n['device'] or {}).get('device'),
                      'delivery/order/rate': [n['delivery_ok'], n['order_ok'], n['rate_ok']], 'draws_per_step': n['draws_per_step'],
                      'max_position_m': summary['comparison']['max_position_m'], 'max_velocity_m_s': summary['comparison']['max_velocity_m_s'],
                      'first_position_difference_tick': summary['comparison']['first_position_difference_tick'],
                      'display_clean': display.released, 'tape_unchanged': summary['tape_unchanged']}, indent=1))
    return 0


def main():
    if len(sys.argv) > 1 and sys.argv[1] in ('prepare', 'overflow'):
        parser = argparse.ArgumentParser()
        sub = parser.add_subparsers(dest='command', required=True)
        p = sub.add_parser('prepare')
        p.add_argument('commit')
        p.add_argument('target', type=Path)
        p = sub.add_parser('overflow')
        p.add_argument('--source', type=Path, required=True)
        p.add_argument('--tape', type=Path, required=True)
        p.add_argument('--game', type=Path, required=True)
        p.add_argument('--evidence', type=Path, required=True)
        p.add_argument('--motor', default='server128')
        p.add_argument('--warmup', type=int, default=8)
        p.add_argument('--shots', type=float, nargs='*', default=[20, 60, 100])
        args = parser.parse_args()
        if shutil.disk_usage(Path.home()).free < nd.MIN_FREE_GIB * 2 ** 30:
            raise SystemExit('below the 15 GiB /home floor; nothing was started')
        return prepare(args.commit, args.target) if args.command == 'prepare' else overflow(args)
    unittest.main(verbosity=2)


if __name__ == '__main__':
    sys.exit(main())
