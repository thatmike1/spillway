#!/usr/bin/env python3
"""an optional private amd/x11 display for r14's native and packed checks.

NativeDisplay is a context manager. it owns one headless weston (gl renderer on the real
render node) and one rootful xwayland client of it, on an explicit display number from
:190-199 that no lock file, socket file or abstract listener holds. it yields the display
number and the environment changes a game child needs; the caller owns the game process,
and GpuWatch proves that the game's process tree holds the amd render node and did gfx work
on it. it never lets xwayland choose a display (-displayfd once took the desktop's :0),
never falls back to software rendering and never touches the desktop's x socket, its
configuration or system policy: every one of those cases raises NativeDisplayError
instead. cleanup runs on success, on an exception, on SIGINT/SIGTERM inside the with block
and on an early launch failure, and is recorded in <evidence>/native-display.json.

    with NativeDisplay(evidence) as display:
        env = display.child_env(engine_env(profile))     # forced-software mesa settings cleared
        watch = GpuWatch()
        code, text = run_engine(cmd, cwd, env, log, deadline, watch)
        watch.require()                                   # the game held renderD128 on amdgpu
        require_amd_log(text)                             # godot's own device line agrees

docs/r14/NATIVE-DISPLAY.md. `probe` and `status` below are the command-line checks.
"""
import argparse
import ctypes
import fcntl
import gzip
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import signal
import stat
import subprocess
import sys
import tempfile
import threading
import time

OUTER = Path('/home/thatmike1/foldrunner-build-2026-11-05')
# the official arch weston 15.0.1-3 package verified in r14/hardware-render (download.json):
# its archive digest, and the .MTREE inside it that names every extracted file's digest.
WESTON_ROOT = OUTER / 'checkpoints/spillway/r14/hardware-render/weston'
WESTON_ARCHIVE = WESTON_ROOT.parent / 'weston-15.0.1-3-x86_64.pkg.tar.zst'
WESTON_ARCHIVE_SHA256 = '92fe0bfe2cf1ae02105b0e6573f6695c6bbd4637c9a6b20299a6fea8c3d23b4d'
WESTON_MTREE_SHA256 = '105370de8c102a1125b03944e061aa25de66c2e40b9e2de655817d4cadcb52db'
XWAYLAND = Path('/usr/bin/Xwayland')
RENDER_NODE = Path('/dev/dri/renderD128')
RENDER_DRIVER = 'amdgpu'
# p / the private range. nothing else here should pick these, but other tools scan up to :199,
# so every number is checked for a lock, a socket file and an abstract listener before use.
DISPLAYS = tuple(range(190, 200))
DESKTOP = ':0'
X_SOCKETS = Path('/tmp/.X11-unix')
MIN_FREE_GIB = 15.0
SOCKET_NAME = 'r14-native'
# p / the root is 16 px larger than the 1280x720 game window. at exactly the window's size
# xwayland flips the game's buffers straight to weston and an x root capture keeps showing a
# stale frame (measured 8 november); one size up keeps captures live. the game is unaffected.
ROOT_SIZE = (1296, 736)
# set only in this process's private child environments, never in the source environment.
FORCED_RENDERING = ('LIBGL_ALWAYS_SOFTWARE', 'LIBGL_ALWAYS_INDIRECT', 'GALLIUM_DRIVER', 'MESA_LOADER_DRIVER_OVERRIDE',
                    '__GLX_VENDOR_LIBRARY_NAME', '__EGL_VENDOR_LIBRARY_FILENAMES', '__EGL_VENDOR_LIBRARY_DIRS',
                    'LIBGL_DRIVERS_PATH', 'DRI_PRIME', 'EGL_PLATFORM')
DISPLAY_ROUTING = ('DISPLAY', 'WAYLAND_DISPLAY', 'WAYLAND_SOCKET', 'XAUTHORITY')
SOFTWARE = re.compile(r'llvmpipe|softpipe|swrast|lavapipe|software', re.I)
GODOT_DEVICE = re.compile(r'^OpenGL API (?P<api>.+?) - (?P<method>Compatibility|Forward\+|Mobile) - Using Device: (?P<device>.+)$', re.M)
PR_SET_PDEATHSIG = 1
MODULE_SHA256 = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()


class NativeDisplayError(RuntimeError):
    """the requested private amd/x11 backend could not be established or released."""


class Cancelled(KeyboardInterrupt):
    """SIGINT or SIGTERM reached the process while a private display was owned."""


def digest(path):
    value = hashlib.sha256()
    with open(path, 'rb') as stream:
        for block in iter(lambda: stream.read(1 << 20), b''):
            value.update(block)
    return value.hexdigest()


def minimal_env(**extra):
    env = {'PATH': os.environ.get('PATH', '/usr/bin:/bin'), 'HOME': str(Path.home()), 'LANG': 'C.UTF-8'}
    env.update(extra)
    return env


# --- checks before anything starts --------------------------------------------------------------

def render_node(node=RENDER_NODE, driver=RENDER_DRIVER):
    """the render node's kernel driver and pci identity; raises unless it is the wanted driver."""
    node = Path(node)
    try:
        info = os.stat(node)
    except OSError as error:
        raise NativeDisplayError('render node %s is not available: %s' % (node, error.strerror))
    if not stat.S_ISCHR(info.st_mode):
        raise NativeDisplayError('%s is not a character device' % node)
    sysfs = Path('/sys/class/drm') / node.name / 'device'
    found = Path(os.path.realpath(sysfs / 'driver')).name if (sysfs / 'driver').exists() else None
    uevent = dict(line.split('=', 1) for line in (sysfs / 'uevent').read_text().split() if '=' in line) if (sysfs / 'uevent').exists() else {}
    result = {'node': str(node), 'rdev': [os.major(info.st_rdev), os.minor(info.st_rdev)], 'driver': found,
              'pci_id': uevent.get('PCI_ID'), 'pci_slot': uevent.get('PCI_SLOT_NAME'), 'access': os.access(node, os.R_OK | os.W_OK)}
    if found != driver:
        raise NativeDisplayError('render node %s is driven by %s, not %s' % (node, found, driver))
    if not result['access']:
        raise NativeDisplayError('render node %s is not readable and writable by this user' % node)
    return result


def verify_weston(root=WESTON_ROOT, archive=WESTON_ARCHIVE):
    """every extracted weston binary and library against the package's own .MTREE digests."""
    root = Path(root)
    result = {'root': str(root)}
    if Path(archive).is_file():
        result['archive_sha256'] = digest(archive)
        if result['archive_sha256'] != WESTON_ARCHIVE_SHA256:
            raise NativeDisplayError('weston package %s does not match its recorded sha256' % archive)
    mtree = root / '.MTREE'
    if not mtree.is_file() or not (root / 'usr/bin/weston').is_file():
        raise NativeDisplayError('no extracted weston package at %s' % root)
    result['mtree_sha256'] = digest(mtree)
    if result['mtree_sha256'] != WESTON_MTREE_SHA256:
        raise NativeDisplayError('weston manifest differs from the independently pinned package manifest')
    expected = {}
    for line in gzip.decompress(mtree.read_bytes()).decode().splitlines():
        fields = line.split()
        if fields and fields[0].startswith('./usr/') and 'sha256digest=' in line:
            name = fields[0][2:].encode().decode('unicode_escape')
            expected[name] = next(f.split('=', 1)[1] for f in fields if f.startswith('sha256digest='))
    used = [n for n in expected if n == 'usr/bin/weston' or n.startswith('usr/lib/')]
    bad = [n for n in used if not (root / n).is_file() or digest(root / n) != expected[n]]
    if bad:
        raise NativeDisplayError('weston files differ from the package manifest: %s' % bad[:5])
    modules = sorted(p for p in (root / 'usr/lib/libweston-15').glob('*.so'))
    stray = [str(p.relative_to(root)) for p in modules if str(p.relative_to(root)) not in expected]
    if stray:
        raise NativeDisplayError('weston module directory holds files outside the package: %s' % stray)
    result.update(verified_files=len(used), weston_sha256=expected['usr/bin/weston'],
                  module_map=';'.join('%s=%s' % (p.name, p) for p in modules))
    return result


def unix_sockets():
    """every unix socket path the kernel knows in this namespace, abstract ones with '@'."""
    paths = set()
    with open('/proc/net/unix') as table:
        next(table)
        for line in table:
            fields = line.split()
            if len(fields) >= 8:
                paths.add(fields[7])
    return paths


def display_busy(number, tmp=Path('/tmp'), sockets=None):
    """why display :number is taken, or [] if nothing holds it. a stale lock still counts."""
    sockets = unix_sockets() if sockets is None else sockets
    lock = Path(tmp) / ('.X%d-lock' % number)
    path = Path(tmp) / '.X11-unix' / ('X%d' % number)
    reasons = []
    if os.path.lexists(lock):
        reasons.append('lock file %s' % lock)
    if os.path.lexists(path):
        reasons.append('socket path %s' % path)
    if '@/tmp/.X11-unix/X%d' % number in sockets:
        reasons.append('abstract listener @/tmp/.X11-unix/X%d' % number)
    if '/tmp/.X11-unix/X%d' % number in sockets:
        reasons.append('bound socket /tmp/.X11-unix/X%d' % number)
    return reasons


def x_answers(display, env=None, timeout=10):
    """xdpyinfo's own answer for a display: ok, name, vendor and dimensions."""
    env = dict(os.environ if env is None else env, DISPLAY=display)
    try:
        result = subprocess.run(['xdpyinfo', '-display', display], env=env, capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired) as error:
        return {'display': display, 'ok': False, 'error': repr(error)}
    found = {k: (re.search(r'^\s*%s:\s*(.+)$' % k, result.stdout, re.M) or [None, None])[1]
             for k in ['name of display', 'vendor string', 'dimensions']}
    return {'display': display, 'ok': result.returncode == 0 and found['name of display'] is not None, 'exit': result.returncode,
            'name': found['name of display'], 'vendor': found['vendor string'], 'dimensions': found['dimensions'],
            'error': result.stderr.strip()[-300:] if result.returncode else ''}


# --- render-node evidence for any process ------------------------------------------------------

def _descendants(pid):
    children = {}
    for entry in os.listdir('/proc'):
        if entry.isdigit():
            try:
                parent = int(Path('/proc/%s/stat' % entry).read_text().rsplit(')', 1)[1].split()[1])
            except (OSError, IndexError, ValueError):
                continue
            children.setdefault(parent, []).append(int(entry))
    found, todo = [], [pid]
    while todo:
        current = todo.pop()
        found.append(current)
        todo.extend(children.get(current, []))
    return found


def render_fds(pid, node=RENDER_NODE):
    """the render-node fds one process holds, with the kernel's drm fdinfo for each client."""
    rdev = os.stat(node).st_rdev
    found = []
    try:
        fds = os.listdir('/proc/%d/fd' % pid)
    except OSError:
        return found
    for fd in fds:
        try:
            info = os.stat('/proc/%d/fd/%s' % (pid, fd))
            text = Path('/proc/%d/fdinfo/%s' % (pid, fd)).read_text()
        except OSError:
            continue
        if not stat.S_ISCHR(info.st_mode) or info.st_rdev != rdev:
            continue
        row = {'fd': int(fd)}
        for line in text.splitlines():
            key, _, value = line.partition(':')
            if key in ('drm-driver', 'drm-pdev', 'drm-client-id', 'drm-engine-gfx', 'drm-total-vram', 'drm-resident-vram'):
                value = value.strip()
                row[key[4:]] = int(value.split()[0]) if key == 'drm-engine-gfx' else value
        found.append(row)
    return found


class GpuWatch:
    """samples a process tree's render-node fds while it runs; package-r14's run_engine watch shape.

    ok means some process in the tree held the node on the wanted driver and the kernel counted
    gfx engine time for that drm client: the gpu drew for it, not only opened."""

    def __init__(self, node=RENDER_NODE, driver=RENDER_DRIVER, interval=0.25, tree=True):
        self.node, self.driver, self.interval, self.tree = Path(node), driver, interval, tree
        self.samples = self.holding = 0
        self.clients = {}
        self.first = self.last = None
        self._thread = None
        self._stop = threading.Event()

    def sample(self, pid):
        rows = []
        for member in (_descendants(pid) if self.tree else [pid]):
            for row in render_fds(member, self.node):
                rows.append(dict(row, pid=member))
                key = (member, row.get('client-id'))
                seen = self.clients.setdefault(key, {'pid': member, 'client_id': row.get('client-id'), 'driver': row.get('driver'),
                                                     'pdev': row.get('pdev'), 'gfx_ns_first': row.get('engine-gfx')})
                seen['gfx_ns_last'] = row.get('engine-gfx')
                seen['vram'] = row.get('total-vram')
        self.samples += 1
        self.holding += bool(rows)
        moment = {'t': time.time(), 'pid': pid, 'fds': rows}
        if rows and self.first is None:
            self.first = moment
        self.last = moment if rows else self.last
        return rows

    def __call__(self, process):
        while process.poll() is None and not self._stop.is_set():
            self.sample(process.pid)
            time.sleep(self.interval)

    def follow(self, pid):
        """sample a pid the caller launched some other way, until stop() or it exits."""
        def loop():
            while not self._stop.is_set() and Path('/proc/%d' % pid).exists():
                self.sample(pid)
                self._stop.wait(self.interval)
        self._thread = threading.Thread(target=loop, daemon=True)
        self._thread.start()
        return self

    def stop(self):
        self._stop.set()
        if self._thread:
            self._thread.join(5)

    def verdict(self):
        clients = list(self.clients.values())
        drew = [c for c in clients if c['driver'] == self.driver and (c.get('gfx_ns_last') or 0) > 0]
        reasons = []
        if not clients:
            reasons.append('no sampled process held %s' % self.node)
        elif not drew:
            reasons.append('no %s client on %s recorded gfx engine time' % (self.driver, self.node))
        return {'ok': not reasons, 'node': str(self.node), 'driver': self.driver, 'samples': self.samples, 'holding_samples': self.holding,
                'clients': clients, 'first': self.first, 'last': self.last, 'reasons': reasons}

    def require(self):
        result = self.verdict()
        if not result['ok']:
            raise NativeDisplayError('game did not render on %s: %s' % (self.node, '; '.join(result['reasons'])))
        return result


def combine(*watches):
    """several run_engine watches on one process, each in its own thread."""
    def watch(process):
        threads = [threading.Thread(target=w, args=(process,), daemon=True) for w in watches]
        for t in threads:
            t.start()
        for t in threads:
            t.join()
    return watch


def godot_device(text):
    """godot's own renderer line from an engine log, or None."""
    match = GODOT_DEVICE.search(text)
    return match.groupdict() if match else None


def require_amd_log(text):
    found = godot_device(text)
    if found is None or SOFTWARE.search(found['device']) or 'AMD' not in found['device']:
        raise NativeDisplayError('engine log does not report an amd device: %r' % (found,))
    return found


# --- owned processes ---------------------------------------------------------------------------

_libc = ctypes.CDLL(None, use_errno=True)


def _owned_child(parent):
    # its own session, and SIGTERM if this process dies without unwinding (a SIGKILL included).
    def prepare():
        _libc.prctl(PR_SET_PDEATHSIG, signal.SIGTERM, 0, 0, 0)
        if os.getppid() != parent:
            os._exit(98)
    return prepare


def _alive(pid):
    try:
        state = Path('/proc/%d/stat' % pid).read_text().rsplit(')', 1)[1].split()[0]
    except (OSError, IndexError):
        return False
    return state != 'Z'


def _session_members(sessions):
    found = []
    for entry in os.listdir('/proc'):
        if entry.isdigit():
            try:
                fields = Path('/proc/%s/stat' % entry).read_text().rsplit(')', 1)[1].split()
            except (OSError, IndexError):
                continue
            if int(fields[3]) in sessions and fields[0] != 'Z':
                found.append(int(entry))
    return found


def _stop_group(process, grace=5):
    if process is None:
        return None
    if process.poll() is not None:
        outcome = {'exit': process.returncode, 'signal': None}
    else:
        try:
            os.killpg(process.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        try:
            process.wait(grace)
            outcome = {'exit': process.returncode, 'signal': 'SIGTERM'}
        except subprocess.TimeoutExpired:
            outcome = {'signal': 'SIGKILL'}
    try:
        # any child it left in its group goes too, even when the leader already exited.
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    try:
        process.wait(5)
    except subprocess.TimeoutExpired:
        pass
    outcome['exit'] = process.returncode
    return outcome


class NativeDisplay:
    """a private headless weston plus rootful xwayland on the amd render node, as a context.

    evidence: a directory for the compositor logs and native-display.json. displays: explicit
    numbers to try in order; each must be free by every check, never auto-selected. desktop:
    the desktop display that must answer before and after, or None where there is none. the
    underscored arguments exist only for negative tests."""

    def __init__(self, evidence, displays=DISPLAYS, width=ROOT_SIZE[0], height=ROOT_SIZE[1], refresh_mhz=60000, node=RENDER_NODE,
                 driver=RENDER_DRIVER, weston_root=WESTON_ROOT, xwayland=XWAYLAND, desktop=DESKTOP, min_free_gib=MIN_FREE_GIB,
                 timeout=15.0, _weston_args=(), _weston_env=None, _xwayland_args=(), _tmp=Path('/tmp')):
        self.evidence = Path(evidence)
        self.displays = tuple(int(n) for n in displays)
        if not self.displays or any(n < 1 for n in self.displays):
            raise ValueError('explicit display numbers above 0 are required')
        self.width, self.height, self.refresh_mhz = int(width), int(height), int(refresh_mhz)
        self.node, self.driver = Path(node), driver
        self.weston_root, self.xwayland = Path(weston_root), Path(xwayland)
        self.desktop, self.min_free_gib, self.timeout = desktop, float(min_free_gib), float(timeout)
        self._weston_args, self._weston_env, self._xwayland_args, self._tmp = tuple(_weston_args), dict(_weston_env or {}), tuple(_xwayland_args), Path(_tmp)
        self.number = self.display = None
        self.env = {}
        self.unset = FORCED_RENDERING + DISPLAY_ROUTING
        self.record = {}
        self.released = False
        self._weston = self._xwayland = self._runtime = self._flock = None
        self._logs = []
        self._previous = {}
        self._deferred = []
        self._entered = False

    # --- what the caller uses

    def child_env(self, base=None):
        """a copy of base (default os.environ) with forced rendering and display routing cleared
        and DISPLAY set to the private server; base itself is never changed."""
        env = dict(os.environ if base is None else base)
        for name in self.unset:
            env.pop(name, None)
        env.update(self.env)
        return env

    def gpu_watch(self, **options):
        return GpuWatch(self.node, self.driver, **options)

    # --- lifecycle

    def __enter__(self):
        if self._entered:
            raise NativeDisplayError('a NativeDisplay is entered once')
        self._entered = True
        self.evidence.mkdir(parents=True, exist_ok=True)
        # weston appends to --log: an old session's renderer line must never pass for this one.
        if any(self.evidence.iterdir()):
            raise NativeDisplayError('evidence directory %s is not empty' % self.evidence)
        self.record = {'tool': str(Path(__file__).resolve()), 'tool_sha256': MODULE_SHA256, 'pid': os.getpid(), 'started': time.time(),
                       'requested_displays': list(self.displays), 'stage': 'signals'}
        self._install_signals()
        try:
            self._start()
        except BaseException as error:
            self.record['error'] = {'stage': self.record['stage'], 'type': type(error).__name__, 'message': str(error)}
            self._release(raise_on_unclean=False)
            raise
        return self

    def __exit__(self, kind, error, _trace):
        if kind is not None:
            self.record['body_error'] = {'type': kind.__name__, 'message': str(error)}
        self._release(raise_on_unclean=kind is None)
        return False

    def _install_signals(self):
        if threading.current_thread() is not threading.main_thread():
            self.record['signals'] = 'not installed: not the main thread'
            return
        def cancel(sig, _frame):
            raise Cancelled('cancelled by signal %d' % sig)
        for sig in (signal.SIGINT, signal.SIGTERM):
            self._previous[sig] = signal.signal(sig, cancel)
        self.record['signals'] = 'SIGINT and SIGTERM raise Cancelled while the display is owned'

    def _defer_signals(self):
        if not self._previous:
            return
        def later(sig, _frame):
            self._deferred.append(sig)
        for sig in self._previous:
            signal.signal(sig, later)

    def _spawn(self, cmd, *, owner, **options):
        # a signal is held while Popen runs, so a child is never started without being recorded.
        cancelling = {sig: signal.getsignal(sig) for sig in self._previous}
        self._defer_signals()
        try:
            process = subprocess.Popen(cmd, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL, start_new_session=True,
                                       preexec_fn=_owned_child(os.getpid()), **options)
            # keep ownership before a deferred signal can abort the caller's assignment.
            setattr(self, '_' + owner, process)
            self.record.setdefault('pids', {})[owner] = process.pid
            return process
        finally:
            for sig, handler in cancelling.items():
                signal.signal(sig, handler)
            if self._deferred:
                raise Cancelled('cancelled by signal %d during a launch' % self._deferred.pop())

    def _restore_signals(self):
        for sig, handler in self._previous.items():
            signal.signal(sig, handler)
        self._previous = {}

    def _stage(self, name):
        self.record['stage'] = name

    def _log(self, name):
        stream = open(self.evidence / name, 'wb')
        self._logs.append(stream)
        return stream

    def _start(self):
        record = self.record
        self._stage('storage')
        free = shutil.disk_usage(Path.home()).free
        record['free_home_bytes_before'] = free
        if free < self.min_free_gib * 2 ** 30:
            raise NativeDisplayError('%.2f GiB free on /home, below the %.0f GiB native floor; nothing was started' % (free / 2 ** 30, self.min_free_gib))
        self._stage('render node')
        record['render_node'] = render_node(self.node, self.driver)
        self._stage('weston package')
        record['weston_package'] = verify_weston(self.weston_root)
        self._stage('xwayland binary')
        if not os.access(self.xwayland, os.X_OK):
            raise NativeDisplayError('%s is not an executable xwayland' % self.xwayland)
        version = subprocess.run([str(self.xwayland), '-version'], capture_output=True, text=True, timeout=10)
        record['xwayland'] = {'path': str(self.xwayland), 'sha256': digest(self.xwayland),
                              'version': ((version.stdout + version.stderr).strip().splitlines() or [''])[0]}
        self._stage('desktop before')
        if self.desktop:
            record['desktop_before'] = x_answers(self.desktop)
            if not record['desktop_before']['ok']:
                raise NativeDisplayError('desktop %s does not answer before the private session; nothing was started' % self.desktop)
        self._stage('display choice')
        self.number = self._claim_display()
        self.display = ':%d' % self.number
        self._stage('weston launch')
        self._start_weston()
        self._stage('xwayland launch')
        self._start_xwayland()
        self._stage('ready')
        self.env = {'DISPLAY': self.display}
        present = sorted(n for n in self.unset if n in os.environ)
        record['child_env'] = {'set': dict(self.env), 'cleared': list(self.unset), 'cleared_present_in_source': present}
        record['display'] = self.display

    def _claim_display(self):
        # p / a private flock per number keeps two of these sessions apart; files and sockets keep
        # it off every other server. the first number free by all checks is taken, none other.
        locks = Path(tempfile.gettempdir()) / ('r14-native-display-%d' % os.getuid())
        locks.mkdir(mode=0o700, exist_ok=True)
        sockets = unix_sockets()
        checked = []
        for number in self.displays:
            busy = display_busy(number, self._tmp, sockets)
            if busy:
                checked.append({'display': number, 'busy': busy})
                continue
            handle = open(locks / ('X%d.flock' % number), 'w')
            try:
                fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                handle.close()
                checked.append({'display': number, 'busy': ['another NativeDisplay in this account holds it']})
                continue
            # rechecked under the flock: a server may have started between the scan and the flock.
            busy = display_busy(number, self._tmp)
            if busy:
                handle.close()
                checked.append({'display': number, 'busy': busy})
                continue
            self._flock = handle
            checked.append({'display': number, 'busy': []})
            self.record['display_checks'] = checked
            return number
        self.record['display_checks'] = checked
        raise NativeDisplayError('no requested private display is free: %s' % checked)

    def _start_weston(self):
        self._runtime = Path(tempfile.mkdtemp(prefix='r14nd-', dir='/tmp'))
        os.chmod(self._runtime, 0o700)
        package = self.record['weston_package']
        lib = self.weston_root / 'usr/lib'
        cmd = [str(self.weston_root / 'usr/bin/weston'), '--backend=headless', '--fake-seat', '--renderer=gl',
               '--shell=%s' % (lib / 'weston/kiosk-shell.so'), '--no-config', '--width=%d' % self.width, '--height=%d' % self.height,
               '--refresh-rate=%d' % self.refresh_mhz, '--socket=' + SOCKET_NAME, '--log=%s' % (self.evidence / 'weston.log'),
               *self._weston_args]
        env = minimal_env(XDG_RUNTIME_DIR=str(self._runtime), LD_LIBRARY_PATH='%s:%s' % (lib, lib / 'weston'),
                          WESTON_MODULE_MAP=package['module_map'])
        env.update(self._weston_env)
        self.record.setdefault('commands', {})['weston'] = cmd
        self.record['runtime_dir'] = str(self._runtime)
        self._weston = self._spawn(cmd, owner='weston', env=env, stdout=self._log('weston-console.log'))
        self.record.setdefault('pids', {})['weston'] = self._weston.pid
        socket_path = self._runtime / SOCKET_NAME
        log = self.evidence / 'weston.log'
        limit = time.monotonic() + self.timeout
        renderer = None
        while time.monotonic() < limit:
            if self._weston.poll() is not None:
                raise NativeDisplayError('weston exited early with %s; see %s' % (self._weston.returncode, self.evidence / 'weston-console.log'))
            text = log.read_text(errors='replace') if log.exists() else ''
            renderer = re.search(r'(?<![A-Z])GL renderer: (.+)', text)
            if socket_path.exists() and renderer:
                break
            time.sleep(0.05)
        else:
            raise NativeDisplayError('weston did not offer %s with a gl renderer within %.0f s' % (SOCKET_NAME, self.timeout))
        text = log.read_text(errors='replace')
        gl = {k: (re.search(r'(?<![A-Z])%s: (.+)' % k, text) or [None, None])[1] for k in ['GL renderer', 'GL vendor', 'GL version', 'EGL vendor']}
        gl['render_fds'] = render_fds(self._weston.pid, self.node)
        self.record['weston_gl'] = gl
        if SOFTWARE.search(gl['GL renderer'] or '') or not [f for f in gl['render_fds'] if f.get('driver') == self.driver]:
            raise NativeDisplayError('weston is not rendering on %s %s: renderer %r' % (self.driver, self.node, gl['GL renderer']))

    def _start_xwayland(self):
        cmd = [str(self.xwayland), self.display, '-geometry', '%dx%d' % (self.width, self.height), '-nolisten', 'tcp', '-noreset',
               *self._xwayland_args]
        env = minimal_env(XDG_RUNTIME_DIR=str(self._runtime), WAYLAND_DISPLAY=SOCKET_NAME)
        self.record['commands']['xwayland'] = cmd
        self._xwayland = self._spawn(cmd, owner='xwayland', env=env, stdout=self._log('xwayland.log'))
        self.record['pids']['xwayland'] = self._xwayland.pid
        lock = self._tmp / ('.X%d-lock' % self.number)
        path = self._tmp / '.X11-unix' / ('X%d' % self.number)
        limit = time.monotonic() + self.timeout
        while time.monotonic() < limit:
            if self._xwayland.poll() is not None:
                raise NativeDisplayError('xwayland %s exited early with %s; see %s' % (self.display, self._xwayland.returncode, self.evidence / 'xwayland.log'))
            try:
                owner = int(lock.read_text().strip())
            except (OSError, ValueError):
                owner = None
            if owner is not None and owner != self._xwayland.pid:
                raise NativeDisplayError('%s lock belongs to pid %d, not this xwayland' % (self.display, owner))
            if owner == self._xwayland.pid and path.is_socket() and '@/tmp/.X11-unix/X%d' % self.number in unix_sockets():
                break
            time.sleep(0.05)
        else:
            raise NativeDisplayError('xwayland %s was not ready within %.0f s' % (self.display, self.timeout))
        self.record['owned_lock'] = True
        answer = x_answers(self.display, minimal_env())
        self.record['private_x'] = answer
        if not answer['ok']:
            raise NativeDisplayError('private %s does not answer xdpyinfo: %s' % (self.display, answer.get('error')))
        # glamor opens the render node at startup; without it the game's glx would be software.
        limit = time.monotonic() + 3
        while time.monotonic() < limit and not render_fds(self._xwayland.pid, self.node):
            time.sleep(0.1)
        fds = render_fds(self._xwayland.pid, self.node)
        self.record['xwayland_render_fds'] = fds
        if not [f for f in fds if f.get('driver') == self.driver]:
            raise NativeDisplayError('xwayland %s holds no %s render node; glamor is not on the gpu' % (self.display, self.driver))

    def _release(self, raise_on_unclean):
        self._defer_signals()
        cleanup = self.record.setdefault('cleanup', {})
        problems = []
        try:
            cleanup['xwayland'] = _stop_group(self._xwayland)
            cleanup['weston'] = _stop_group(self._weston)
            sessions = {p.pid for p in (self._xwayland, self._weston) if p is not None}
            left = _session_members(sessions) if sessions else []
            for pid in left:
                try:
                    os.kill(pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
            cleanup['session_members_killed'] = left
            time.sleep(0.2 if left else 0)
            cleanup['owned_processes_remaining'] = [p.pid for p in (self._xwayland, self._weston) if p is not None and _alive(p.pid)] + \
                (_session_members(sessions) if sessions else [])
            if cleanup['owned_processes_remaining']:
                problems.append('owned processes remain: %s' % cleanup['owned_processes_remaining'])
            if self.number is not None and self._xwayland is not None:
                cleanup['x'] = self._release_x_files()
                if cleanup['x']['left']:
                    problems.append('x files remain: %s' % cleanup['x']['left'])
            if self._runtime is not None:
                cleanup['wayland_socket_left'] = (self._runtime / SOCKET_NAME).exists()
                shutil.rmtree(self._runtime, ignore_errors=True)
                cleanup['runtime_removed'] = not self._runtime.exists()
                if not cleanup['runtime_removed']:
                    problems.append('runtime directory remains: %s' % self._runtime)
            for stream in self._logs:
                stream.close()
            if self._flock is not None:
                self._flock.close()
                self._flock = None
            if self.desktop and 'desktop_before' in self.record:
                self.record['desktop_after'] = x_answers(self.desktop)
                if not self.record['desktop_after']['ok']:
                    problems.append('desktop %s stopped answering' % self.desktop)
            cleanup['free_home_bytes_after'] = shutil.disk_usage(Path.home()).free
        except BaseException as error:
            problems.append('cleanup raised %r' % error)
        finally:
            cleanup['problems'] = problems
            cleanup['deferred_signals'] = list(self._deferred)
            self.released = not problems
            self.record['clean'] = self.released
            self.record['ended'] = time.time()
            self.evidence.mkdir(parents=True, exist_ok=True)
            (self.evidence / 'native-display.json').write_text(json.dumps(self.record, indent=1) + '\n')
            self._restore_signals()
        if problems and raise_on_unclean:
            raise NativeDisplayError('private display cleanup incomplete: %s' % '; '.join(problems))
        if self._deferred and raise_on_unclean:
            raise Cancelled('cancelled by signal %d during cleanup' % self._deferred[0])

    def _release_x_files(self):
        lock = self._tmp / ('.X%d-lock' % self.number)
        path = self._tmp / '.X11-unix' / ('X%d' % self.number)
        result = {'removed': [], 'left': [], 'foreign': []}
        time.sleep(0.2)
        owner = None
        if os.path.lexists(lock):
            try:
                owner = int(lock.read_text().strip())
            except (OSError, ValueError):
                pass
            # only a lock this session's xwayland wrote, after it is gone: never anyone else's.
            if owner == self._xwayland.pid and not _alive(owner):
                lock.unlink()
                result['removed'].append(str(lock))
                if path.is_socket() and not path.is_symlink():
                    path.unlink()
                    result['removed'].append(str(path))
        sockets = unix_sockets()
        held = [p for p in [str(lock), str(path)] if os.path.lexists(p)] + \
            [s for s in ['@/tmp/.X11-unix/X%d' % self.number, '/tmp/.X11-unix/X%d' % self.number] if s in sockets]
        # another server that won the number after the checks: reported, never counted as ours.
        foreign = owner is not None and owner != self._xwayland.pid or owner is None and not self.record.get('owned_lock')
        result['foreign' if foreign else 'left'] = held
        return result


# --- command line ------------------------------------------------------------------------------

def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest='command', required=True)
    p = sub.add_parser('status', help='report the private range and the desktop display; starts nothing')
    p.add_argument('--display', type=int, action='append')
    p = sub.add_parser('probe', help='start the private display, verify it and release it')
    p.add_argument('--evidence', type=Path, required=True)
    p.add_argument('--display', type=int, action='append')
    p.add_argument('--hold', type=float, default=0.0, help='seconds to keep it up (DISPLAY is printed)')
    args = parser.parse_args(argv)
    displays = tuple(args.display) if args.display else DISPLAYS
    if args.command == 'status':
        sockets = unix_sockets()
        print(json.dumps({'free_home_gib': shutil.disk_usage(Path.home()).free / 2 ** 30, 'desktop': x_answers(DESKTOP),
                          'displays': {n: display_busy(n, sockets=sockets) for n in displays}}, indent=1))
        return 0
    try:
        with NativeDisplay(args.evidence, displays) as display:
            print('private display %s ready; weston %s' % (display.display, display.record['weston_gl']['GL renderer']), flush=True)
            time.sleep(args.hold)
    except (NativeDisplayError, Cancelled) as error:
        print('FAIL: %s' % error, file=sys.stderr)
        return 1
    print('released clean: %s' % display.released)
    return 0


if __name__ == '__main__':
    sys.exit(main())
