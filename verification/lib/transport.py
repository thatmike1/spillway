import ctypes,gzip,hashlib,os,shutil,subprocess,threading,time
from pathlib import Path
import physical as C
OLD=C.OLD
sha,write,difference=C.sha,C.write,C.difference
CAP=600*2**20
MIN_FREE=2_000_000_000
GODOT = Path(os.environ.get("GODOT", Path.home()/".local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64"))
def gate():
    free = shutil.disk_usage('/home').free
    if free < MIN_FREE:
        raise RuntimeError(f'HOME free space {free} < {MIN_FREE}')
    return free


def bounded(command, env, cwd, log, ram, timeout=180):
    """cap owned RAM evidence/source/import/profile scratch; report engine memory separately."""
    gate()
    with log.open('w') as output:
        process = subprocess.Popen(command, env=env, cwd=cwd, stdout=output, stderr=subprocess.STDOUT)
        start = time.monotonic()
        peak = rss_peak = anon_peak = combined_peak = 0
        minimum_free = gate()
        try:
            while process.poll() is None:
                size = allocated_footprint(ram)
                rss = anonymous = 0
                try:
                    for line in Path(f'/proc/{process.pid}/status').read_text().splitlines():
                        if line.startswith('VmRSS:'):
                            rss = int(line.split()[1]) * 1024
                        elif line.startswith('RssAnon:'):
                            anonymous = int(line.split()[1]) * 1024
                except FileNotFoundError:
                    pass
                peak = max(peak, size)
                rss_peak = max(rss_peak, rss)
                anon_peak = max(anon_peak, anonymous)
                combined_peak = max(combined_peak, size + anonymous)
                minimum_free = min(minimum_free, gate())
                if size > CAP or time.monotonic() - start > timeout:
                    raise RuntimeError(f'600 MiB owned RAM scratch or time bound exceeded: scratch={size}, anonymous={anonymous}, rss={rss}')
                time.sleep(.25)
            code = process.wait()
        finally:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
    return {'command': command, 'exit': code, 'seconds': round(time.monotonic()-start, 3),
            'owned_scratch_peak_bytes': peak, 'engine_rss_peak_bytes': rss_peak, 'engine_anonymous_peak_bytes':anon_peak, 'combined_owned_peak_bytes':combined_peak, 'minimum_home_free_bytes': minimum_free}


def host_guard(summary, scene='res://scenes/r19.tscn', script='res://scripts/r19_main.gd'):
    assert summary['host_scene'] == scene and summary['host_script'] == script, 'wrong actual configured host'
    assert summary['checks'] and all(c['ok'] for c in summary['checks']), 'host assertions failed'


def allocated_footprint(path):
    # sparse consumed trace blocks do not occupy tmpfs RAM; include ordinary files at allocated size.
    return sum(p.stat().st_blocks*512 for p in path.rglob('*') if p.is_file())


def start_trace_streams(dest):
    """compress regular-file output continuously and reclaim only already-compressed tmpfs blocks."""
    directory = dest/'evaluator'
    directory.mkdir()
    stopped = threading.Event()
    errors,threads,paths,receipts = [],[],[],{}
    libc = ctypes.CDLL(None,use_errno=True)
    punch = libc.fallocate
    punch.argtypes = [ctypes.c_int,ctypes.c_int,ctypes.c_longlong,ctypes.c_longlong]
    punch.restype = ctypes.c_int
    def drain(path):
        fd = os.open(path,os.O_RDWR)
        digest = hashlib.sha256()
        length = reclaimed = 0
        try:
            with Path(str(path)+'.gz').open('wb') as packed, gzip.GzipFile(filename='',mode='wb',compresslevel=6,fileobj=packed,mtime=0) as target:
                while True:
                    data = os.read(fd,65536)
                    if data:
                        target.write(data)
                        digest.update(data)
                        length += len(data)
                        boundary = length // (1024*1024) * (1024*1024)
                        if boundary > reclaimed:
                            target.flush()
                            if punch(fd,3,reclaimed,boundary-reclaimed) != 0:
                                raise OSError(ctypes.get_errno(),'cannot reclaim compressed trace blocks')
                            reclaimed = boundary
                    elif stopped.is_set():
                        break
                    else:
                        stopped.wait(.02)
            # verify the lossless output independently before removing the sparse transport file.
            observed = hashlib.sha256()
            decoded = 0
            with gzip.open(Path(str(path)+'.gz'),'rb') as verify:
                for block in iter(lambda:verify.read(65536),b''):
                    observed.update(block)
                    decoded += len(block)
            assert observed.hexdigest() == digest.hexdigest() and decoded == length
            receipts[path.name] = {'raw_sha256':digest.hexdigest(),'raw_bytes':length,'reclaimed_bytes':reclaimed,
                                   'gzip_sha256':sha(Path(str(path)+'.gz')),'lossless_verified':True}
        except BaseException as exc:
            errors.append(repr(exc))
        finally:
            os.close(fd)
    for name in ['trace','ghost','observations']:
        path = directory/(name+'.jsonl')
        path.touch()
        paths.append(path)
        thread = threading.Thread(target=drain,args=(path,),daemon=False)
        thread.start()
        threads.append(thread)
    return stopped,threads,paths,errors,receipts
