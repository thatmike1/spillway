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


if __name__ == "__main__":
    unittest.main()
