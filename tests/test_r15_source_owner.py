#!/usr/bin/env python3
"""cancel the real source wrapper during import; verify the fake engine and its child stop.

these are subprocess ownership controls, not game, display or completed-suite evidence.
"""
import argparse
import json
import os
import re
from pathlib import Path
import signal
import subprocess
import tempfile
import time

PROJECT = Path(__file__).resolve().parents[1]
WRAPPER = PROJECT / "tools/check-r15.sh"


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
    with tempfile.TemporaryDirectory(prefix="r15-source-owner-") as temporary:
        scratch = Path(temporary)
        checker = re.search(r"^clean_log\(\) \{.*?^\}", WRAPPER.read_text(), re.M | re.S).group()
        for name, contents, expected in [("absent", None, 1), ("empty", "", 1),
                                         ("engine-error", "ERROR: deliberately broken\n", 1),
                                         ("clean", "Godot Engine\ncompleted\n", 0)]:
            log_fixture = scratch / (name + ".log")
            if contents is not None:
                log_fixture.write_text(contents)
            result = subprocess.run(["bash", "-c", checker + '\nclean_log "$1"', "log-check", str(log_fixture)],
                                    stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            assert result.returncode == expected, (name, result.returncode, expected)
            results.append({"log_fixture": name, "exit": result.returncode})
        engine = scratch / "fake-godot"
        engine.write_text("#!/usr/bin/env python3\n"
                          "import json,os,subprocess,sys,time\nfrom pathlib import Path\n"
                          "Path('.godot').mkdir(exist_ok=True);Path(os.environ['XDG_CACHE_HOME']).mkdir(parents=True,exist_ok=True)\n"
                          "child=subprocess.Popen([sys.executable,'-c','import time;time.sleep(45)'])\n"
                          "Path(os.environ['R15_OWNER_PIDS']).write_text(json.dumps([os.getpid(),child.pid]))\n"
                          "time.sleep(45)\n")
        engine.chmod(0o755)
        for sig in (signal.SIGINT, signal.SIGTERM):
            sentinel = scratch / (sig.name + ".json")
            output = scratch / sig.name
            log = args.out / (sig.name + ".log")
            env = dict(os.environ, GODOT=str(engine), R15_OWNER_PIDS=str(sentinel))
            pids = []
            with log.open("w") as stream:
                proc = subprocess.Popen([str(WRAPPER), "--source", "worktree", "--core-only", "--out", str(output)],
                                        cwd=PROJECT, env=env, stdout=stream, stderr=subprocess.STDOUT,
                                        start_new_session=True)
                try:
                    deadline = time.monotonic() + 20
                    while not sentinel.exists() and proc.poll() is None and time.monotonic() < deadline:
                        time.sleep(0.02)
                    assert sentinel.exists(), (sig.name, "fake engine did not start", log.read_text())
                    pids = json.loads(sentinel.read_text())
                    os.kill(proc.pid, sig)
                    code = proc.wait(10)
                    deadline = time.monotonic() + 3
                    while any(alive(pid) for pid in pids) and time.monotonic() < deadline:
                        time.sleep(0.02)
                    assert code == 130 and not any(alive(pid) for pid in pids), (sig.name, code, pids)
                    assert not (output / "source/.godot").exists() and not (output / "profile/cache").exists()
                    results.append({"signal": sig.name, "wrapper_exit": code, "engine_and_child_gone": True, "owned_caches_removed": True})
                finally:
                    if proc.poll() is None:
                        os.killpg(proc.pid, signal.SIGKILL)
                        proc.wait(5)
                    for pid in pids:
                        if alive(pid):
                            os.kill(pid, signal.SIGKILL)
    (args.out / "RESULTS.json").write_text(json.dumps({"passed": len(results), "checks": results,
                                                      "scope": "actual wrapper cancellation with fake engine, no game"}, indent=2) + "\n")
    print("both wrapper-only cancellation signals release engine and child")


if __name__ == "__main__":
    main()
