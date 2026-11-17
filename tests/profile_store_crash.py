#!/usr/bin/env python3
"""prove failed replacement never exposes the primary to a truncating write."""
import argparse
import ctypes
import json
import os
from pathlib import Path
import select
import signal
import subprocess
import sys
import time

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import engine


def interrupted(_number, _frame):
    raise KeyboardInterrupt


def run_case(out, original, legacy=None):
    data = out / "data"
    data.mkdir(parents=True)
    target = data / "profile.cfg"
    target.write_bytes(original)
    (data / "profile.cfg.tmp").touch()
    library = ctypes.CDLL(None, use_errno=True)
    library.inotify_init1.argtypes = [ctypes.c_int]
    library.inotify_init1.restype = ctypes.c_int
    library.inotify_add_watch.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_uint32]
    library.inotify_add_watch.restype = ctypes.c_int
    fd = library.inotify_init1(os.O_NONBLOCK | os.O_CLOEXEC)
    if fd < 0:
        raise OSError(ctypes.get_errno(), "inotify_init1")
    killed = False
    try:
        # inotify IN_MODIFY is 0x2 in linux/inotify.h; watch only this private fixture's primary.
        if library.inotify_add_watch(fd, os.fsencode(target), 2) < 0:
            raise OSError(ctypes.get_errno(), "inotify_add_watch")
        data.chmod(0o555)
        command = [str(engine.GODOT), "--headless", "--audio-driver", "Dummy", "--path", str(engine.PROJECT), "--script", "res://tests/profile_store_replace.gd", "--", str(target)]
        if legacy:
            command.append("--test-host=" + str(legacy))
        print(out.name + ": waiting for pinned engine slot", flush=True)
        with engine.locked():
            process = subprocess.Popen(command, cwd=engine.PROJECT, env=engine.environment(out / "private"), stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            try:
                deadline = time.monotonic() + 180
                while process.poll() is None:
                    if select.select([fd], [], [], 0.01)[0]:
                        os.read(fd, 4096)
                        process.kill()
                        killed = True
                        break
                    if time.monotonic() > deadline:
                        raise TimeoutError("crash fixture deadline")
                stdout, _ = process.communicate(timeout=10)
            finally:
                if process.poll() is None:
                    process.kill()
                    process.wait()
    finally:
        os.close(fd)
        data.chmod(0o755)
    after = target.read_bytes()
    log = stdout.decode(errors="replace")
    (out / "engine.log").write_text(log)
    result = {"killed_on_primary_modification": killed, "exit": process.returncode, "before_bytes": len(original), "after_bytes": len(after), "primary_bytes_intact": after == original}
    if legacy:
        if not killed or len(after) >= len(original):
            raise RuntimeError("Legacy writer did not reproduce interrupted direct overwrite: " + str(result))
    elif killed or process.returncode or after != original or "failed rename refuses direct overwrite: true" not in log:
        raise RuntimeError("Patched writer failed preservation: " + str(result))
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", required=True, type=Path, help="new external evidence directory")
    parser.add_argument("--baseline-ref", help="optionally demonstrate the unsafe historical host, such as 231b6d2")
    args = parser.parse_args()
    if sys.platform != "linux" or os.geteuid() == 0:
        raise RuntimeError("The real permission/crash fixture requires Linux and a non-root user")
    out = args.out.resolve()
    if out.is_relative_to(engine.PROJECT):
        raise ValueError("Evidence must be outside the checkout")
    out.mkdir(parents=True, exist_ok=False)
    signal.signal(signal.SIGTERM, interrupted)
    engine.check_pin()
    original = "".join(f"[other-{i:05d}]\nclean_best_ticks={1000+i}\nclean_split_ticks=[250,500,750]\nclean_segment_ticks=[250,250,250,250]\n" for i in range(20000)).encode()
    results = {"ok": False, "checks": {}}
    try:
        if args.baseline_ref:
            body = subprocess.check_output(["git", "show", args.baseline_ref + ":scripts/r16_main.gd"], cwd=engine.PROJECT)
            legacy = out / "legacy_host.gd"
            legacy.write_bytes(body)
            results["baseline_ref"] = args.baseline_ref
            results["checks"]["legacy"] = run_case(out / "legacy", original, legacy)
        results["checks"]["current"] = run_case(out / "current", original)
        results["ok"] = True
    finally:
        (out / "RESULT.json").write_text(json.dumps(results, indent=2) + "\n")
    print("PASS " + str(out / "RESULT.json"), flush=True)


if __name__ == "__main__":
    main()
