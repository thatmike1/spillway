#!/usr/bin/env python3
"""check Breakwater's process-owner adapter with disposable sleepers, without a display or Godot.

success, deadline and wrapper-only signals must release the owned process group. this is
cleanup evidence, not native-render or game acceptance.
"""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time

MODULE = Path(__file__).with_name("r15_breakwater_native.py")


def load():
    spec = importlib.util.spec_from_file_location("bw_cleanup", MODULE)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    mod.GODOT = Path(sys.executable)
    return mod


def alive(pid):
    try:
        return Path(f"/proc/{pid}/stat").read_text().split(")", 1)[1].split()[0] != "Z"
    except FileNotFoundError:
        return False


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=False)
    results = []
    mod = load()
    with tempfile.TemporaryDirectory(prefix="r15-native-owner-") as temp:
        scratch = Path(temp)
        _, code = mod.godot(["-c", "print('owned success')"], os.environ.copy(), scratch, args.out / "success.log", 5)
        assert code == 0 and "owned success" in (args.out / "success.log").read_text()
        results.append("successful process exits normally")
        pidfile = scratch / "timeout.pid"
        sleeper = "import os,time;from pathlib import Path;Path(%r).write_text(str(os.getpid()));time.sleep(30)" % str(pidfile)
        _, code = mod.godot(["-c", sleeper], os.environ.copy(), scratch, args.out / "timeout.log", 0.5)
        assert code == "timeout" and pidfile.exists() and not alive(int(pidfile.read_text()))
        results.append("deadline releases the owned process")
        for sig in (signal.SIGINT, signal.SIGTERM):
            sentinel = scratch / (sig.name + ".json")
            # both the fake engine and its child share the engine's owned process group.
            actor = ("import os,subprocess,sys,time,json;from pathlib import Path;"
                     "child=subprocess.Popen([sys.executable,'-c','import time;time.sleep(30)']);"
                     "Path(%r).write_text(json.dumps([os.getpid(),child.pid]));time.sleep(30)") % str(sentinel)
            wrapper = scratch / (sig.name + ".py")
            wrapper.write_text("import importlib.util,os,sys\nfrom pathlib import Path\n"
                               "spec=importlib.util.spec_from_file_location('probe',%r)\n" % str(MODULE)
                               + "m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)\nm.GODOT=Path(sys.executable)\n"
                               + "m.godot(['-c',%r],os.environ.copy(),Path(%r),Path(%r),20)\n" % (actor, str(scratch), str(args.out / (sig.name + ".log"))))
            process = subprocess.Popen([sys.executable, "-I", str(wrapper)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
            pids = []
            try:
                deadline = time.monotonic() + 10
                while not sentinel.exists() and time.monotonic() < deadline and process.poll() is None:
                    time.sleep(0.02)
                assert sentinel.exists(), sig.name
                pids = json.loads(sentinel.read_text())
                os.kill(process.pid, sig)
                process.wait(10)
                deadline = time.monotonic() + 3
                while any(alive(pid) for pid in pids) and time.monotonic() < deadline:
                    time.sleep(0.02)
                assert not any(alive(pid) for pid in pids), (sig.name, pids)
                results.append(sig.name + " sent only to wrapper releases engine and child")
            finally:
                if process.poll() is None:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait(5)
                for pid in pids:
                    if alive(pid):
                        os.kill(pid, signal.SIGKILL)
    (args.out / "RESULTS.json").write_text(json.dumps({"passed": len(results), "failed": 0, "checks": results,
                                                     "scope": "disposable process ownership; no display or game run"}, indent=2) + "\n")
    print("%d process-owner checks pass" % len(results))


if __name__ == "__main__":
    main()
