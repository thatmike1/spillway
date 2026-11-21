"""Pinned Godot entry point shared by local development and verification."""
from contextlib import ExitStack, contextmanager
import fcntl
import hashlib
import os
from pathlib import Path
import subprocess
import sys
import threading
import time

PROJECT = Path(__file__).resolve().parents[1]
VERSION = "4.7.2.stable.official.ed1daf0bf"
EDITOR_SHA256 = "8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e"
LOCK = Path("/tmp/spillway-r21-engine.lock")
_THREAD_LOCK = threading.RLock()
_lock_depth = 0
DEFAULT_CACHE = Path.home() / ".local/share/foldrunner"
GODOT = Path(os.environ.get("GODOT", DEFAULT_CACHE / "godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64"))
TEMPLATES = Path(os.environ.get("GODOT_TEMPLATES", DEFAULT_CACHE / "godot-4.7.2-templates"))
TEMPLATE_HASHES = {
    "linux_release.x86_64": "d9f79ab89b5ae369aeed11c6052d402e8218cd503bf85b4a235f9c30c46a7c63",
    "windows_release_x86_64.exe": "d34d36f3be1a6c49c56525ae86469b92e4f417ddf0b43cf00dd80c385c4b0562",
}


def sha(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def check_pin():
    if not GODOT.is_file() or sha(GODOT) != EDITOR_SHA256:
        raise RuntimeError("Set GODOT to the pinned official Godot 4.7.2 Linux editor.")


CAPTURE_SLOTS = 3


def lease_path(suffix):
    # gate, slot and display leases live beside LOCK, so tests that move LOCK move them too.
    return LOCK.with_name(LOCK.stem + suffix)


def _flock(stream, mode, what):
    try:
        fcntl.flock(stream, mode | fcntl.LOCK_NB)
    except BlockingIOError:
        print(f"waiting for {what}", file=sys.stderr, flush=True)
        fcntl.flock(stream, mode)


def _enter_shared(lease):
    # a capture takes one of CAPTURE_SLOTS slots, then the lock shared. the gate keeps
    # exclusive jobs from starving: an exclusive waiter holds it, so new captures queue behind.
    told = False
    while True:
        for index in range(CAPTURE_SLOTS):
            # each stream is owned by a context from the moment it opens; a win moves to the lease.
            with ExitStack() as attempt:
                slot = attempt.enter_context(lease_path(f".slot{index}").open("a"))
                try:
                    fcntl.flock(slot, fcntl.LOCK_EX | fcntl.LOCK_NB)
                except BlockingIOError:
                    continue
                lease.enter_context(attempt.pop_all())
            break
        else:
            if not told:
                print(f"waiting for one of {CAPTURE_SLOTS} capture slots", file=sys.stderr, flush=True)
                told = True
            time.sleep(.25)
            continue
        break
    told = False
    while True:
        with lease_path(".gate").open("a") as gate:
            _flock(gate, fcntl.LOCK_SH, "the engine gate (a check or export is running or waiting)")
            with ExitStack() as attempt:
                stream = attempt.enter_context(LOCK.open("a"))
                try:
                    fcntl.flock(stream, fcntl.LOCK_SH | fcntl.LOCK_NB)
                except BlockingIOError:
                    pass
                else:
                    lease.enter_context(attempt.pop_all())
                    return
        # an exclusive holder that predates the gate: wait outside it, so waiting checks are not held up.
        if not told:
            print("waiting for the engine lock (an exclusive job is running)", file=sys.stderr, flush=True)
            told = True
        time.sleep(.25)


@contextmanager
def locked(shared=False):
    """Hold the engine lease. Exclusive by default; shared=True is for private-display captures.
    A nested lease reuses the outermost one, whatever it asks for."""
    global _lock_depth
    # serialize threads; only the owning thread can reuse the outer file lease.
    with _THREAD_LOCK, ExitStack() as lease:
        if _lock_depth == 0:
            if shared:
                _enter_shared(lease)
            else:
                # all sibling capture and game processes share this exact lock file.
                gate = lease.enter_context(lease_path(".gate").open("a"))
                _flock(gate, fcntl.LOCK_EX, "the engine gate (another check or export)")
                stream = lease.enter_context(LOCK.open("a"))
                _flock(stream, fcntl.LOCK_EX, "running captures to finish")
        _lock_depth += 1
        try:
            yield
        finally:
            _lock_depth -= 1


def environment(profile):
    env = {"PATH": os.environ["PATH"], "LANG": "C.UTF-8", "MALLOC_ARENA_MAX": "1"}
    for name in ("HOME", "XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME", "XDG_STATE_HOME", "XDG_RUNTIME_DIR"):
        target = profile / name.lower()
        target.mkdir(parents=True, exist_ok=True, mode=0o700)
        env[name] = str(target)
    return env


def run(arguments, *, cwd, profile, log, timeout=180):
    check_pin()
    with locked(), Path(log).open("w") as stream:
        result = subprocess.run([str(GODOT), *map(str, arguments)], cwd=cwd,
                                env=environment(profile), stdout=stream,
                                stderr=subprocess.STDOUT, timeout=timeout)
    text = Path(log).read_text(errors="replace")
    if result.returncode or any(token in text for token in ("ERROR:", "SCRIPT ERROR:", "Parse Error", "Assertion failed")):
        raise RuntimeError(f"Godot failed; read {log}\n{text[-2500:]}")
    return {"exit": result.returncode, "log_sha256": sha(log)}


def temporary_headroom():
    """Return the smaller of filesystem free bytes and this user's tmpfs quota."""
    import ctypes
    import shutil
    free = shutil.disk_usage("/tmp").free
    if os.uname().machine != "x86_64":
        return free
    class Quota(ctypes.Structure):
        _fields_ = [(name, ctypes.c_uint64) for name in (
            "hard", "soft", "used", "inode_hard", "inode_soft", "inodes", "block_time", "inode_time"
        )] + [("valid", ctypes.c_uint32)]
    library = ctypes.CDLL(None, use_errno=True)
    fd = os.open("/tmp", os.O_RDONLY | os.O_DIRECTORY)
    quota = Quota()
    try:
        # linux x86_64 quotactl_fd; Q_GETQUOTA, USRQUOTA, current uid.
        result = library.syscall(ctypes.c_long(443), ctypes.c_int(fd), ctypes.c_uint(0x80000700),
                                 ctypes.c_uint(os.getuid()), ctypes.byref(quota))
        if result == 0 and quota.hard:
            free = min(free, max(0, quota.hard * 1024 - quota.used))
    finally:
        os.close(fd)
    return free
