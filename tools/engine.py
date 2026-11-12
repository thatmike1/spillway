"""Pinned Godot entry point shared by local development and verification."""
from contextlib import contextmanager
import fcntl
import hashlib
import os
from pathlib import Path
import subprocess

PROJECT = Path(__file__).resolve().parents[1]
VERSION = "4.7.2.stable.official.ed1daf0bf"
EDITOR_SHA256 = "8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e"
LOCK = Path("/tmp/spillway-r21-engine.lock")
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


@contextmanager
def locked():
    # all sibling capture and game processes share this lock on the build machine.
    with LOCK.open("a") as stream:
        fcntl.flock(stream, fcntl.LOCK_EX)
        yield


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
