#!/usr/bin/env python3
"""bounded Windows PE ghost-sharing proof; Wine is never native Windows evidence.

prepare from --commit using exact committed services, or --release an existing
extracted Windows release with BUILD.json and PCK. release mode never substitutes
source services or builds/exports a game. release mode checks startup only:
official Windows templates disable external --script overrides. supply Wine64.
"""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import struct
import sys
import time

sys.dont_write_bytecode = True

PROJECT = Path(__file__).resolve().parents[1]
EDITOR_SHA = '8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e'
TEMPLATE_SHA = 'd34d36f3be1a6c49c56525ae86469b92e4f417ddf0b43cf00dd80c385c4b0562'
CONSOLE_SHA = '52bdcae9068e8d23b840e5c63b0c1798ffe2cb66144e5c4bc7af11fb8c8600df'
CAP = 750 * 1024**2
SERVICES = ('scripts/r19_ghost_share.gd', 'scripts/r16_run_reader.gd', 'scripts/r16_ghost.gd')


def digest(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as f:
        for block in iter(lambda: f.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + '\n')


def budget(root):
    # symlinks count as links, never follow them outside the owned scratch.
    total = sum(p.lstat().st_size for p in root.rglob('*') if not p.is_dir() or p.is_symlink())
    available = int(next(x.split()[1] for x in Path('/proc/meminfo').read_text().splitlines() if x.startswith('MemAvailable:'))) * 1024
    facts = {'scratch_bytes': total, 'home_free': shutil.disk_usage(Path.home()).free,
             'tmp_free': shutil.disk_usage(root).free, 'memory_available': available}
    if total > CAP or facts['home_free'] < 15000000000 or facts['tmp_free'] < 128 * 1024**2 or available < 512 * 1024**2:
        raise RuntimeError('resource guard refused: ' + str(facts))
    return facts


def win(path):
    return 'Z:' + str(Path(path).absolute()).replace('/', '\\')


def execute(cmd, env, cwd, log, root, seconds=45):
    budget(root)
    started = time.monotonic()
    write_json(log.with_suffix('.command.json'), {'argv': list(map(str, cmd)), 'cwd': str(cwd), 'display': env.get('DISPLAY'), 'wayland': env.get('WAYLAND_DISPLAY'), 'wineprefix': env.get('WINEPREFIX')})
    with log.open('wb') as output:
        process = subprocess.Popen(list(map(str, cmd)), cwd=cwd, env=env, stdout=output,
                                   stderr=subprocess.STDOUT, start_new_session=True)
        try:
            while process.poll() is None:
                budget(root)
                if re.search(r'SCRIPT ERROR:|Parse Error:|Failed to load script|^ERROR:', log.read_text(errors='replace'), re.M):
                    raise RuntimeError('Godot error in ' + str(log))
                if time.monotonic() - started > seconds or log.stat().st_size > 8 * 1024**2:
                    raise RuntimeError('bounded process time/log limit: ' + str(log))
                time.sleep(0.25)
            if process.returncode:
                raise RuntimeError(f'exit {process.returncode}: {log}')
        finally:
            # kill only the new process group, including any descendants that survived exit.
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
    content = log.read_text(errors='replace')
    if re.search(r'SCRIPT ERROR:|Parse Error:|Failed to load script|^ERROR:', content, re.M):
        raise RuntimeError('Godot error in ' + str(log))
    return {'argv': list(map(str, cmd)), 'log': str(log), 'exit': process.returncode}


def committed(project, commit, relative):
    top = subprocess.check_output(['git', 'rev-parse', '--show-toplevel'], cwd=project, text=True).strip()
    prefix = project.relative_to(top).as_posix()
    return subprocess.check_output(['git', 'show', f'{commit}:{prefix}/{relative}'], cwd=project)


def prepare(args, run, env, root, commands):
    source = run / 'fixture-source'
    source.mkdir()
    manifest = {}
    for name in SERVICES:
        data = committed(PROJECT, args.commit, name)
        target = source / name
        target.parent.mkdir(exist_ok=True, parents=True)
        target.write_bytes(data)
        manifest[name] = hashlib.sha256(data).hexdigest()
        # refuse additional resource dependencies rather than silently use worktree files.
        for dep in re.findall(rb'(?:preload|load)\("res://([^"\n]+)"\)', data):
            if dep.decode() not in SERVICES:
                raise RuntimeError('fixture dependency not explicitly pinned: ' + dep.decode())
    project = source / 'project.godot'
    project.write_text('config_version=5\n[application]\nconfig/name="R19 Windows DATA FIXTURE"\nrun/main_scene="res://proof.tscn"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
    test = source / 'tests/r19_windows_wine.gd'
    test.parent.mkdir()
    shutil.copyfile(PROJECT / 'tests/r19_windows_wine.gd', test)
    manifest['tests/r19_windows_wine.gd'] = digest(test)
    (source / 'proof.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://tests/r19_windows_wine.gd" id="1"]\n[node name="DataProof" type="Node"]\nscript = ExtResource("1")\n')
    (source / '.godot').mkdir(exist_ok=True)
    (source / '.godot/global_script_class_cache.cfg').write_text('list=[]\n')
    pack = run / 'fixture.pck'
    packer = run / 'pack.gd'
    packer.write_text('extends SceneTree\nfunc _initialize() -> void:\n\tvar p := PCKPacker.new()\n'
                      + '\tassert(p.pck_start(' + json.dumps(str(pack)) + ') == OK)\n'
                      + ''.join('\tassert(p.add_file(' + json.dumps('res://' + str(p.relative_to(source))) + ', '
                                + json.dumps(str(p)) + ') == OK)\n' for p in sorted(source.rglob('*')) if p.is_file())
                      + '\tassert(p.flush() == OK)\n\tquit()\n')
    commands.append(execute([args.editor, '--headless', '--path', source, '--script', packer], env, run, run / 'pack.log', root))
    write_json(run / 'fixture-manifest.json', {'commit': args.commit, 'sources_sha256': manifest,
               'pack_sha256': digest(pack), 'label': 'DATA FIXTURE PCK; not a full game export'})
    return source, pack


def independent(args, run):
    reader_path = PROJECT / 'tools/analyze-r16-runs.py'
    if not args.release and reader_path.read_bytes() != committed(PROJECT, args.commit, 'tools/analyze-r16-runs.py'):
        raise RuntimeError('independent reader differs from preparation commit')
    spec = importlib.util.spec_from_file_location('r19_independent_reader', reader_path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    reports = []
    for path in args.recording:
        if path.stat().st_size > 4 * 1024**2:
            raise RuntimeError('input recording exceeds service bound')
        raw = path.read_bytes()
        if len(raw) < 48 or raw[:8] != b'FRR16RUN':
            raise RuntimeError('invalid bounded recording prefix')
        header_size = struct.unpack_from('<I', raw, 12)[0]
        if header_size > 65536:
            raise RuntimeError('recording header bound exceeded')
        at, decoded_total, ticks, chunks = 48 + header_size, 0, 0, 0
        while at < len(raw):
            if at + 60 > len(raw):
                raise RuntimeError('truncated bounded recording chunk')
            decoded, stored = struct.unpack_from('<II', raw, at + 12)
            decoded_total += decoded
            ticks += struct.unpack_from('<I', raw, at + 24)[0]
            chunks += 1
            if decoded_total > 12 * 1024**2 or ticks > 80000 or chunks > 512 or decoded > 8 * 1024**2 or stored > 4 * 1024**2:
                raise RuntimeError('recording decode budget exceeded')
            at += 60 + stored
        if at != len(raw):
            raise RuntimeError('truncated bounded recording payload')
        rec = module.read(path)
        if not rec.ok:
            raise RuntimeError('independent reader rejects: ' + str(rec.errors))
        def columns_hash(columns, layout):
            h = hashlib.sha256()
            for name, code, _ in layout:
                values = [v for row in zip(*(columns[name + '_' + axis] for axis in 'xyz')) for v in row] if name in module.VECTORS else columns[name]
                h.update(struct.pack('<' + code[0] * len(values), *values))
            return h.hexdigest()
        reports.append({'columns_sha256': columns_hash(rec.columns, module.TICK_LAYOUT),
                        'inputs_sha256': columns_hash(rec.inputs, module.INPUT_LAYOUT), 'path': str(path), 'sha256': digest(path), 'identity': rec.header['identity'],
                        'time': rec.seal['outcome']['time'], 'ticks': len(rec.columns['tick']),
                        'run_id': rec.header['run_id'], 'reader_sha256': digest(reader_path)})
    write_json(run / 'independent.json', reports)
    return reports


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--wine', required=True, type=Path)
    parser.add_argument('--editor', type=Path, default=Path.home() / '.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64')
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--commit', help='preparation source commit, never an uncommitted source fallback')
    mode.add_argument('--release', type=Path, help='existing extracted Windows release directory; no export or source fallback')
    parser.add_argument('--recording', action='append', type=Path, default=[])
    parser.add_argument('--scratch', type=Path, default=Path('/tmp/r19-windows-proof'))
    parser.add_argument('--name', default='proof')
    args = parser.parse_args()
    args.wine = args.wine.absolute()
    args.editor = args.editor.absolute()
    args.recording = [p.absolute() for p in args.recording]
    if args.release and args.recording:
        parser.error('--release is startup-only; recordings belong to --commit mode')
    if not args.release and not args.recording:
        parser.error('--commit requires at least one --recording')
    root = args.scratch.absolute()
    if root != Path('/tmp/r19-windows-proof') or not re.fullmatch(r'[a-zA-Z0-9_-]+', args.name):
        parser.error('scratch must be /tmp/r19-windows-proof; name must be a simple new basename')
    if root.is_symlink():
        parser.error('scratch must not be a symlink')
    root.mkdir(exist_ok=True)
    if (root / 'prefix').is_symlink():
        parser.error('prefix must not be a symlink')
    budget(root)
    run = root / args.name
    run.mkdir()  # an existing evidence directory is never overwritten.
    env = dict(os.environ)
    for key in ('DISPLAY', 'WAYLAND_DISPLAY', 'DBUS_SESSION_BUS_ADDRESS', 'SESSION_MANAGER', 'WINEPREFIX', 'WINESERVER', 'WINELOADER'):
        env.pop(key, None)
    for key in ('HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME', 'XDG_DATA_HOME', 'XDG_RUNTIME_DIR', 'TMPDIR'):
        value = run / key.lower()
        value.mkdir()
        env[key] = str(value)
    env.update(WINEPREFIX=str(root / 'prefix'), WINEARCH='win64', WINEDEBUG='-all',
               WINEDLLOVERRIDES='winemenubuilder.exe=d;mscoree,mshtml,winegstreamer=')
    commands = []
    result = {'ok': False, 'mode': 'exact-release-startup-only' if args.release else 'committed-service-fixture',
              'native_windows': False, 'resources_before': budget(root), 'commands': commands}
    try:
        if args.commit:
            args.commit = subprocess.check_output(['git', 'rev-parse', args.commit + '^{commit}'], cwd=PROJECT, text=True).strip()
            result['source_commit'] = args.commit
        result['wine'] = {'path': str(args.wine), 'sha256': digest(args.wine)}
        if not args.release and digest(args.editor) != EDITOR_SHA:
            raise RuntimeError('Linux editor pin differs')
        commands.append(execute([args.wine, '--version'], env, run, run / 'wine-version.log', root))
        oracle = independent(args, run) if not args.release else []
        binary = run / 'windows'
        binary.mkdir()
        if args.release:
            release = args.release.resolve()
            metadata = json.loads((release / 'BUILD.json').read_text())
            packs = list(release.glob('*.pck'))
            exes = [p for p in release.glob('*.exe') if not p.name.endswith('.console.exe')]
            if len(packs) != 1 or len(exes) != 1:
                raise RuntimeError('release must contain exactly one game PCK and one normal EXE')
            pack, exe = packs[0], exes[0]
            if digest(pack) != metadata['pack_sha256'] or digest(exe) != TEMPLATE_SHA:
                raise RuntimeError('release PCK/official runtime pin differs')
            members = metadata['runtime']['members_sha256']
            if members.get('windows_release_x86_64.exe') != TEMPLATE_SHA or members.get('windows_release_x86_64_console.exe') != CONSOLE_SHA:
                raise RuntimeError('BUILD.json official runtime pins differ')
            consoles = list(release.glob('*.console.exe'))
            if len(consoles) != 1 or digest(consoles[0]) != CONSOLE_SHA:
                raise RuntimeError('release console wrapper pin differs')
            result['release'] = {'build_sha256': digest(release / 'BUILD.json'), 'source_commit': metadata['source_commit'],
                                 'pack_sha256': digest(pack), 'exe_sha256': digest(exe)}
            # no scripts are loaded from the source checkout in this mode.
        else:
            source, pack = prepare(args, run, env, root, commands)
            exe = Path.home() / '.local/share/foldrunner/godot-4.7.2-templates/windows_release_x86_64.exe'
            console = exe.with_name('windows_release_x86_64_console.exe')
            if digest(exe) != TEMPLATE_SHA or digest(console) != CONSOLE_SHA:
                raise RuntimeError('official Windows template pin differs')
        # links avoid duplicating the 105 MiB immutable executable; Windows sees the scratch path.
        target_exe = binary / 'Proof.exe'
        target_exe.symlink_to(exe)
        target_pack = binary / 'Proof.pck'
        target_pack.symlink_to(pack)
        result['executed_exe_sha256'] = digest(target_exe)
        result['pack_sha256'] = digest(pack)
        if args.release:
            commands.append(execute([args.wine, target_exe, '--headless', '--quit-after', '12', '--', '--no-records', '--no-run-recordings', '--verify-startup'], env, binary, run / 'release-startup.log', root, seconds=45))
            startup = (run / 'release-startup.log').read_text(errors='replace')
            if not re.search(r'^r16: build=.*; records=off; recordings=off; runner=.*; standin=false; renderer=\S+', startup, re.M) or 'r19: spillway-2026.11.09-r19;' not in startup or 'startup_error=' in startup:
                raise RuntimeError('exact release did not report normal headless game startup')
            result.update(ok=True, sharing_executed=False, resources_after=budget(root),
                          limits=['exact Windows EXE/PCK startup under Wine only', 'official release template disables external script overrides; fixture sharing is a separate preparation run', 'no native Windows, renderer, feel or menu interaction proof'])
        test = run / 'r19_windows_wine.gd'
        if not args.release:
            shutil.copyfile(PROJECT / 'tests/r19_windows_wine.gd', test)
            result['test_sha256'] = digest(test)
        for i, record in enumerate([] if args.release else args.recording):
            case = run / f'case-{i}'
            case.mkdir()
            local = case / 'input.r16run'
            shutil.copyfile(record, local)
            stages = [('linux-export', 'Linux', None), ('windows', 'Windows', case / 'linux-export/export.spillghost'),
                      ('linux-import', 'Linux', case / 'windows/export.spillghost')]
            summaries = []
            for stage, expected_os, incoming in stages:
                out = case / stage
                out.mkdir()
                user_args = ['--out=' + (win(out) if expected_os == 'Windows' else str(out)),
                             '--input=' + (win(local) if expected_os == 'Windows' else str(local)), '--expect-os=' + expected_os]
                if incoming:
                    user_args.append('--incoming=' + (win(incoming) if expected_os == 'Windows' else str(incoming)))
                if expected_os == 'Windows':
                    cmd = [args.wine, target_exe, '--headless', '--'] + user_args
                else:
                    base = ['--path', source]
                    cmd = [args.editor, '--headless'] + base + ['--'] + user_args
                commands.append(execute(cmd, env, binary, out / 'execution.log', root, seconds=60))
                report = json.loads((out / 'report.json').read_text())
                if not report['ok']:
                    raise RuntimeError('fixture checks failed: ' + str(out))
                for key in ('sha256', 'identity', 'time', 'ticks', 'run_id', 'columns_sha256', 'inputs_sha256'):
                    if report['recording'][key] != oracle[i][key]:
                        raise RuntimeError('independent reader mismatch: ' + key)
                summaries.append(report['recording'])
            if summaries[0] != summaries[1] or summaries[1] != summaries[2]:
                raise RuntimeError('Linux/Windows decoded columns or recording summaries differ')
        if not args.release:
            result.update(ok=True, sharing_executed=True, cases=len(args.recording), resources_after=budget(root),
                      limits=['Wine PE execution is not native Windows or feel proof', 'service fixture host; no full game/menu interaction',
                              'preparation fixture is not final Windows ZIP/PCK'])
    except Exception as exc:
        result['failure'] = str(exc)
    finally:
        # wineserver selection is scoped by this explicit scratch prefix; never kill global Wine.
        server = args.wine.parent / 'wineserver'
        if server.exists():
            try:
                subprocess.run([str(server), '-k'], env=env, timeout=5, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            except subprocess.TimeoutExpired:
                result['cleanup_failure'] = 'prefix wineserver did not stop within 5 seconds'
        write_json(run / 'summary.json', result)
    print(json.dumps({'ok': result['ok'], 'summary': str(run / 'summary.json'), 'failure': result.get('failure')}))
    return 0 if result['ok'] else 1


if __name__ == '__main__':
    sys.exit(main())
