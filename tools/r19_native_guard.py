"""preserve the observed desktop even when its X endpoint was already unavailable.

the existing native renderer still owns only an explicitly free display in 190..199.
an unavailable desktop requires an explicit caller flag and additional socket/process proof.
"""
import json
from pathlib import Path
import subprocess


def desktop_snapshot():
    sockets = {}
    for path in [Path('/tmp/.X11-unix/X0'), Path('/tmp/.X11-unix/X0_'), Path('/tmp/.X0-lock')]:
        try:
            stat = path.lstat()
            sockets[str(path)] = [stat.st_dev, stat.st_ino, stat.st_mode]
        except FileNotFoundError:
            sockets[str(path)] = None
    servers = {}
    for proc in Path('/proc').glob('[0-9]*'):
        try:
            name = (proc / 'comm').read_text().strip()
            args = (proc / 'cmdline').read_bytes().split(b'\0')
            if name != 'Hyprland' and not (name == 'Xwayland' and b':0' in args):
                continue
            stat = (proc / 'stat').read_text().rsplit(')', 1)[1].split()
            servers[proc.name] = {'name': name, 'start_ticks': stat[19]}
        except (FileNotFoundError, PermissionError, ProcessLookupError):
            continue
    listeners = []
    for line in Path('/proc/net/unix').read_text().splitlines()[1:]:
        fields = line.split()
        if len(fields) >= 8 and fields[3] == '00010000' and fields[7] in (
                '/tmp/.X11-unix/X0', '/tmp/.X11-unix/X0_', '@/tmp/.X11-unix/X0'):
            listeners.append(fields[3:8])
    try:
        probe = subprocess.run(['xdpyinfo', '-display', ':0'], capture_output=True, timeout=5)
        answering = probe.returncode == 0
    except subprocess.TimeoutExpired:
        answering = False
    return {'sockets': sockets, 'servers': servers, 'listeners': sorted(listeners), 'answering': answering}


class DesktopGuard:
    def __init__(self, evidence, allow_unavailable=False):
        self.evidence = Path(evidence)
        self.allow_unavailable = allow_unavailable
        self.desktop = ':0'

    def __enter__(self):
        self.evidence.mkdir(parents=True, exist_ok=True)
        self.before = desktop_snapshot()
        (self.evidence / 'before.json').write_text(json.dumps(self.before, indent=1))
        if not self.before['answering']:
            if not self.allow_unavailable:
                raise RuntimeError('desktop :0 was unavailable before launch; explicit --desktop-unavailable requires preserving its observed sockets and server processes')
            self.desktop = None
        return self

    def __exit__(self, exc_type, exc, tb):
        after = desktop_snapshot()
        same = after == self.before
        (self.evidence / 'after.json').write_text(json.dumps({'snapshot': after, 'unchanged': same,
            'explicit_unavailable': self.allow_unavailable, 'original_exception': str(exc) if exc else None}, indent=1))
        if not same:
            raise RuntimeError('desktop baseline changed during private rendering; see desktop guard receipts') from exc
        return False
