#!/usr/bin/env python3
"""non-rendering cancellation and refusal review; all children are disposable sleepers."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import shutil
import signal
import socket
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

PROJECT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('review_nd', PROJECT / 'tools/r14_native_display.py')
nd = importlib.util.module_from_spec(spec)
spec.loader.exec_module(nd)
EVIDENCE = None
REAL_POPEN = subprocess.Popen


class SleeperDisplay(nd.NativeDisplay):
    def _start(self):
        self._stage('review sleepers')
        self._runtime = Path(tempfile.mkdtemp(prefix='r14nd-review-'))
        self._weston = self._spawn([sys.executable, '-c', 'import time; time.sleep(60)'], owner='weston')
        self._xwayland = self._spawn([sys.executable, '-c', 'import time; time.sleep(60)'], owner='xwayland')


class Review(unittest.TestCase):
    def display(self, name, kind=SleeperDisplay):
        return kind(EVIDENCE / name, displays=(199,), desktop=None)

    def assert_clean(self, display, previous):
        self.assertTrue(display.released, display.record)
        self.assertEqual(display.record['cleanup']['owned_processes_remaining'], [])
        self.assertFalse(display._runtime.exists() if display._runtime else False)
        for pid in display.record.get('pids', {}).values():
            self.assertFalse(nd._alive(pid), pid)
        self.assertEqual({s: signal.getsignal(s) for s in previous}, previous)

    def test_launch_cancellation_on_each_owner_and_signal(self):
        for ordinal in (1, 2):
            for sig in (signal.SIGINT, signal.SIGTERM):
                with self.subTest(launch=ordinal, signal=sig):
                    display = self.display('launch-%d-%d' % (ordinal, sig))
                    previous = {s: signal.getsignal(s) for s in (signal.SIGINT, signal.SIGTERM)}
                    children = []
                    def spawn(cmd, **options):
                        process = REAL_POPEN(cmd, **options)
                        children.append(process)
                        if len(children) == ordinal:
                            os.kill(os.getpid(), sig)
                        return process
                    try:
                        with mock.patch.object(nd.subprocess, 'Popen', side_effect=spawn):
                            with self.assertRaises(nd.Cancelled):
                                with display:
                                    self.fail('body reached after cancellation')
                        self.assertEqual(len(children), ordinal)
                        self.assert_clean(display, previous)
                    finally:
                        for process in children:
                            nd._stop_group(process)

    def test_multiple_signals_during_cleanup_are_deferred(self):
        display = self.display('cleanup-signals')
        previous = {s: signal.getsignal(s) for s in (signal.SIGINT, signal.SIGTERM)}
        stop = nd._stop_group
        def signal_then_stop(process):
            os.kill(os.getpid(), signal.SIGINT)
            os.kill(os.getpid(), signal.SIGTERM)
            return stop(process)
        with mock.patch.object(nd, '_stop_group', side_effect=signal_then_stop):
            with self.assertRaises(nd.Cancelled):
                with display:
                    pass
        self.assert_clean(display, previous)

    def test_body_exception_retains_type_and_cleans(self):
        display = self.display('body-error')
        previous = {s: signal.getsignal(s) for s in (signal.SIGINT, signal.SIGTERM)}
        with self.assertRaisesRegex(ValueError, 'review body'):
            with display:
                raise ValueError('review body')
        self.assertEqual(display.record['body_error']['type'], 'ValueError')
        self.assert_clean(display, previous)

    def test_dead_leader_does_not_protect_child_in_its_session(self):
        class Forker(nd.NativeDisplay):
            def _start(self):
                self._runtime = Path(tempfile.mkdtemp(prefix='r14nd-review-'))
                cmd = [sys.executable, '-c',
                       'import os,time; p=os.fork(); '
                       'os._exit(0) if p else None; os.setpgrp(); time.sleep(60)']
                self._weston = self._spawn(cmd, owner='weston')
                self._weston.wait(5)
                # the child stays in the owned session but uses another process group.
                self.review_children = nd._session_members({self._weston.pid})
        display = self.display('leader-exits', Forker)
        previous = {s: signal.getsignal(s) for s in (signal.SIGINT, signal.SIGTERM)}
        try:
            with display:
                self.assertEqual(len(display.review_children), 1)
            self.assert_clean(display, previous)
            self.assertTrue(all(not nd._alive(p) for p in display.review_children))
        finally:
            for pid in getattr(display, 'review_children', []):
                if nd._alive(pid):
                    os.kill(pid, signal.SIGKILL)

    def test_foreign_lock_and_socket_survive_cleanup(self):
        fake = Path(tempfile.mkdtemp(prefix='r14nd-review-x-'))
        (fake / '.X11-unix').mkdir()
        lock = fake / '.X199-lock'
        path = fake / '.X11-unix/X199'
        lock.write_text(str(os.getpid()))
        sock = socket.socket(socket.AF_UNIX)
        sock.bind(str(path))
        display = self.display('foreign-cleanup')
        display._tmp = fake
        try:
            with display:
                display.number = 199
                display.record['owned_lock'] = True
            self.assertEqual(lock.read_text(), str(os.getpid()))
            self.assertTrue(path.is_socket())
            self.assertEqual(display.record['cleanup']['x']['left'], [])
            self.assertEqual(set(display.record['cleanup']['x']['foreign']), {str(lock), str(path)})
        finally:
            sock.close()
            lock.unlink(missing_ok=True)
            path.unlink(missing_ok=True)
            (fake / '.X11-unix').rmdir()
            fake.rmdir()

    def test_storage_refusal_starts_no_children(self):
        display = self.display('storage-refusal', nd.NativeDisplay)
        usage = shutil.disk_usage(Path.home())
        with mock.patch.object(nd.shutil, 'disk_usage', return_value=usage._replace(free=14 * 2**30)):
            with mock.patch.object(nd.subprocess, 'Popen', side_effect=AssertionError('must not launch')):
                with self.assertRaisesRegex(nd.NativeDisplayError, 'nothing was started'):
                    with display:
                        self.fail('body reached')
        self.assertNotIn('pids', display.record)
        self.assertTrue(display.released)

    def test_runtime_allocation_cancel_is_not_reported_clean_with_a_leak(self):
        class RuntimeOnly(nd.NativeDisplay):
            def _start(self):
                self.record['weston_package'] = {'module_map': ''}
                self._start_weston()
        display = self.display('runtime-allocation-cancel', RuntimeOnly)
        real_mkdtemp = tempfile.mkdtemp
        allocated = []
        def allocate_then_cancel(*args, **kwargs):
            path = real_mkdtemp(*args, **kwargs)
            allocated.append(path)
            os.kill(os.getpid(), signal.SIGTERM)
            return path
        try:
            with mock.patch.object(nd.tempfile, 'mkdtemp', side_effect=allocate_then_cancel):
                with self.assertRaises(nd.Cancelled):
                    with display:
                        self.fail('body reached')
            leaked = [p for p in allocated if Path(p).exists()]
            (EVIDENCE / 'runtime-allocation-observation.json').write_text(json.dumps({
                'allocated': allocated, 'leaked_before_reviewer_cleanup': leaked,
                'reported_clean': display.released, 'record': display.record}, indent=2) + '\n')
            self.assertEqual(leaked, [], 'cancel during mkdtemp return leaks an unrecorded runtime while reporting clean')
        finally:
            for path in allocated:
                shutil.rmtree(path, ignore_errors=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--evidence', type=Path, required=True)
    args, remaining = parser.parse_known_args()
    EVIDENCE = args.evidence.resolve()
    EVIDENCE.mkdir(parents=True, exist_ok=False)
    before = nd.x_answers(':0')
    assert before['ok'], before
    result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(Review))
    after = nd.x_answers(':0')
    (EVIDENCE / 'summary.json').write_text(json.dumps({
        'tests': result.testsRun, 'failures': len(result.failures), 'errors': len(result.errors),
        'desktop_before': before, 'desktop_after': after,
        'free_home_bytes': shutil.disk_usage(Path.home()).free,
        'native_processes_started': False,
        'tool_sha256': nd.MODULE_SHA256}, indent=2) + '\n')
    sys.exit(0 if result.wasSuccessful() and after['ok'] else 1)
