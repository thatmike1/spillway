"""Exercise engine leases in bounded subprocesses with private lock files."""
from pathlib import Path
import subprocess
import sys
import tempfile
import textwrap
import unittest

sys.dont_write_bytecode = True
TOOLS = Path(__file__).resolve().parents[1] / "tools"


class EngineLock(unittest.TestCase):
    def run_case(self, body):
        with tempfile.TemporaryDirectory(prefix="spillway-lock-test-") as folder:
            setup = (f"import sys\nsys.path.insert(0, {str(TOOLS)!r})\n"
                     f"import engine\nfrom pathlib import Path\n"
                     f"engine.LOCK = Path({str(Path(folder) / 'private.lock')!r})\n")
            result = subprocess.run([sys.executable, "-B", "-c", setup + textwrap.dedent(body)],
                                    capture_output=True, text=True, timeout=8)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_nested_lease(self):
        self.run_case("""
            with engine.locked():
                with engine.locked():
                    with engine.locked():
                        pass
            with engine.locked():
                pass
        """)

    def test_thread_waits_for_outermost_exit(self):
        self.run_case("""
            import threading
            started, entered = threading.Event(), threading.Event()
            def contender():
                started.set()
                with engine.locked():
                    entered.set()
            with engine.locked():
                with engine.locked():
                    worker = threading.Thread(target=contender, daemon=True)
                    worker.start()
                    assert started.wait(2)
                    assert not entered.wait(0.15), 'thread entered nested lease'
                assert not entered.wait(0.15), 'inner exit released outer lease'
            assert entered.wait(2), 'outer exit did not release thread'
            worker.join(2)
            assert not worker.is_alive()
        """)

    def test_process_waits_for_outermost_exit(self):
        self.run_case("""
            import select
            import subprocess
            code = ("import sys; sys.path.insert(0, " + repr(str(Path(engine.__file__).parent)) + "); "
                    "import engine; from pathlib import Path; engine.LOCK = Path(" + repr(str(engine.LOCK)) + "); "
                    "print('ready', flush=True)\\nwith engine.locked():\\n print('entered', flush=True)\\n")
            worker = None
            try:
                with engine.locked():
                    with engine.locked():
                        worker = subprocess.Popen([sys.executable, '-B', '-c', code],
                                                  stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                        assert select.select([worker.stdout], [], [], 2)[0], 'process did not start'
                        assert worker.stdout.readline() == b'ready\\n'
                        assert not select.select([worker.stdout], [], [], 0.15)[0], 'process entered nested lease'
                    assert not select.select([worker.stdout], [], [], 0.15)[0], 'inner exit released process'
                stdout, stderr = worker.communicate(timeout=2)
                assert worker.returncode == 0, stderr
                assert stdout == b'entered\\n', stdout
            finally:
                if worker is not None and worker.poll() is None:
                    worker.kill()
                    worker.communicate(timeout=2)
        """)

    def test_exceptions_release_without_descriptor_or_depth_leaks(self):
        self.run_case("""
            import fcntl
            import threading
            before = len(list(Path('/proc/self/fd').iterdir()))
            for _ in range(100):
                try:
                    with engine.locked():
                        try:
                            with engine.locked():
                                raise ValueError('inner')
                        except ValueError:
                            pass
                        with engine.LOCK.open('a') as probe:
                            try:
                                fcntl.flock(probe, fcntl.LOCK_EX | fcntl.LOCK_NB)
                            except BlockingIOError:
                                pass
                            else:
                                raise AssertionError('caught inner exception released outer lease')
                        raise ValueError('outer')
                except ValueError:
                    pass
                with engine.LOCK.open('a') as probe:
                    fcntl.flock(probe, fcntl.LOCK_EX | fcntl.LOCK_NB)
                with engine.locked():
                    pass
            entered = threading.Event()
            def contender():
                with engine.locked():
                    entered.set()
            worker = threading.Thread(target=contender, daemon=True)
            worker.start()
            assert entered.wait(2), 'exception leaked thread guard'
            worker.join(2)
            assert not worker.is_alive()
            assert len(list(Path('/proc/self/fd').iterdir())) == before, 'descriptor leak'
        """)

    def test_failed_acquisition_releases_thread_guard_and_descriptor(self):
        self.run_case("""
            import threading
            from unittest.mock import patch
            before = len(list(Path('/proc/self/fd').iterdir()))
            with patch.object(engine.fcntl, 'flock', side_effect=OSError('probe')):
                try:
                    with engine.locked():
                        raise AssertionError('failed flock entered body')
                except OSError:
                    pass
            entered = threading.Event()
            def contender():
                with engine.locked():
                    entered.set()
            worker = threading.Thread(target=contender, daemon=True)
            worker.start()
            assert entered.wait(2), 'failed acquisition leaked thread guard'
            worker.join(2)
            assert not worker.is_alive()
            assert len(list(Path('/proc/self/fd').iterdir())) == before, 'failed acquisition leaked descriptor'
        """)

    def test_captures_share_up_to_the_slot_count(self):
        self.run_case("""
            import subprocess
            hold = ("import sys, time; sys.path.insert(0, " + repr(str(Path(engine.__file__).parent)) + "); "
                    "import engine; from pathlib import Path; engine.LOCK = Path(" + repr(str(engine.LOCK)) + "); "
                    "\\nwith engine.locked(shared=True):\\n print('in', flush=True); sys.stdin.readline()\\n")
            workers = [subprocess.Popen([sys.executable, '-B', '-c', hold], stdin=subprocess.PIPE,
                                        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL) for _ in range(engine.CAPTURE_SLOTS + 1)]
            try:
                import select, time
                deadline = time.time() + 4
                inside = set()
                while time.time() < deadline and len(inside) < engine.CAPTURE_SLOTS:
                    ready = select.select([w.stdout for w in workers], [], [], .2)[0]
                    for w in workers:
                        if w.stdout in ready and w.stdout.readline() == b'in\\n':
                            inside.add(w.pid)
                assert len(inside) == engine.CAPTURE_SLOTS, inside
                late = [w for w in workers if w.pid not in inside]
                assert not select.select([late[0].stdout], [], [], .4)[0], 'capture beyond the slot count entered'
                first = next(w for w in workers if w.pid in inside)
                first.stdin.write(b'\\n'); first.stdin.flush()
                assert select.select([late[0].stdout], [], [], 3)[0], 'freed slot was not reused'
            finally:
                for w in workers:
                    if w.poll() is None:
                        w.kill()
                    w.communicate(timeout=2)
        """)

    def test_exclusive_waits_for_captures_and_blocks_new_ones(self):
        self.run_case("""
            import subprocess, select
            prefix = ("import sys; sys.path.insert(0, " + repr(str(Path(engine.__file__).parent)) + "); "
                      "import engine; from pathlib import Path; engine.LOCK = Path(" + repr(str(engine.LOCK)) + ")\\n")
            def start(body):
                return subprocess.Popen([sys.executable, '-B', '-c', prefix + body], stdin=subprocess.PIPE,
                                        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
            hold = "with engine.locked(shared={}):\\n print('in', flush=True); sys.stdin.readline()\\n"
            capture = start(hold.format(True))
            workers = [capture]
            try:
                assert select.select([capture.stdout], [], [], 3)[0] and capture.stdout.readline() == b'in\\n'
                check = start(hold.format(False)); workers.append(check)
                assert not select.select([check.stdout], [], [], .4)[0], 'exclusive entered beside a capture'
                later = start(hold.format(True)); workers.append(later)
                assert not select.select([later.stdout], [], [], .4)[0], 'new capture overtook a waiting exclusive job'
                capture.stdin.write(b'\\n'); capture.stdin.flush()
                assert select.select([check.stdout], [], [], 3)[0], 'exclusive did not get the engine'
                assert not select.select([later.stdout], [], [], .3)[0], 'capture entered beside exclusive'
                check.stdin.write(b'\\n'); check.stdin.flush()
                assert select.select([later.stdout], [], [], 3)[0], 'capture did not follow the exclusive job'
                later.stdin.write(b'\\n'); later.stdin.flush()
            finally:
                for w in workers:
                    if w.poll() is None:
                        w.kill()
                    w.communicate(timeout=2)
        """)

    def test_capture_waiting_on_an_older_exclusive_job_leaves_the_gate_free(self):
        self.run_case("""
            import fcntl, subprocess, select, time
            prefix = ("import sys; sys.path.insert(0, " + repr(str(Path(engine.__file__).parent)) + "); "
                      "import engine; from pathlib import Path; engine.LOCK = Path(" + repr(str(engine.LOCK)) + ")\\n")
            old = engine.LOCK.open("a")
            fcntl.flock(old, fcntl.LOCK_EX)  # an exclusive holder from tools without the gate
            capture = subprocess.Popen([sys.executable, '-B', '-c', prefix + "with engine.locked(shared=True):\\n print('in', flush=True)\\n"],
                                       stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
            try:
                time.sleep(.5)
                assert not select.select([capture.stdout], [], [], 0)[0], 'capture entered beside an exclusive holder'
                with engine.lease_path(".gate").open("a") as gate:
                    deadline = time.time() + 2
                    while True:
                        try:
                            fcntl.flock(gate, fcntl.LOCK_EX | fcntl.LOCK_NB)
                            break
                        except BlockingIOError:
                            assert time.time() < deadline, 'waiting capture keeps the gate'
                            time.sleep(.02)
                    fcntl.flock(gate, fcntl.LOCK_UN)
                old.close()
                assert select.select([capture.stdout], [], [], 3)[0], 'capture did not follow the older job'
            finally:
                if capture.poll() is None:
                    capture.kill()
                capture.communicate(timeout=2)
        """)


if __name__ == "__main__":
    unittest.main()
