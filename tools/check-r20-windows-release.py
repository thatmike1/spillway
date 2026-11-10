#!/usr/bin/env python3
"""boot every map from an exact Windows ZIP under Wine, without source fallback."""
import argparse
import importlib.util
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import subprocess
import sys
import zipfile

sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('r20_windows_inherited_runner', PROJECT / 'tools/r19-windows-wine.py')
W = importlib.util.module_from_spec(spec)
spec.loader.exec_module(W)
MAPS = ['breakwater', 'whiteout-relay', 'sunken-court', 'rainline', 'night-shift', 'practice', 'overflow', 'experiment', 'saltglass', 'tether-yard', 'through-line']


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--zip', type=Path, required=True)
    parser.add_argument('--build', type=Path, required=True)
    parser.add_argument('--checksums', type=Path, required=True)
    parser.add_argument('--wine', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    out = args.out.resolve()
    assert out.is_relative_to(Path('/tmp')) and not out.exists(), 'new RAM evidence directory required'
    assert args.zip.is_file() and args.zip.suffix == '.zip'
    assert W.digest(args.wine) == '91dfdd714f2c9078f010341346196d426e81c633ca0865cf7cc678e2825562db', 'portable Wine loader pin differs'
    build = json.loads(args.build.read_text())
    assert build['round'] == 'R20' and build['build'] == 'spillway-2026.11.10-r20'
    assert re.fullmatch('[0-9a-f]{40}', build['source_commit'])
    assert build['freeze']['required_maps'] == MAPS and build['freeze']['source_commit'] == build['source_commit']
    sums = {}
    for line in args.checksums.read_text().splitlines():
        digest, name = line.split('  ', 1)
        assert name not in sums and re.fullmatch('[0-9a-f]{64}', digest)
        sums[name] = digest
    assert args.zip.name in build['platforms'] and sums[args.zip.name] == W.digest(args.zip)
    helpers = {}
    for name in ['tools/check-r20-windows-release.py', 'tools/r19-windows-wine.py']:
        blob = subprocess.check_output(['git', 'show', build['source_commit'] + ':projects/foldrunner/' + name], cwd=PROJECT)
        assert blob == (PROJECT / name).read_bytes(), 'verification helper differs from release commit: ' + name
        helpers[name] = W.digest(PROJECT / name)
    out.mkdir()
    release = out / 'release'
    release.mkdir()
    env = dict(os.environ)
    for key in ['DISPLAY', 'WAYLAND_DISPLAY', 'DBUS_SESSION_BUS_ADDRESS', 'SESSION_MANAGER', 'WINEPREFIX', 'WINESERVER', 'WINELOADER']:
        env.pop(key, None)
    for key in ['HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME', 'XDG_DATA_HOME', 'XDG_RUNTIME_DIR', 'TMPDIR']:
        env[key] = str(out / 'profile' / key.lower())
        Path(env[key]).mkdir(parents=True)
    env.update(WINEPREFIX=str(out / 'prefix'), WINEARCH='win64', WINEDEBUG='-all',
               WINEDLLOVERRIDES='winemenubuilder.exe=d;mscoree,mshtml,winegstreamer=')
    receipt = {'ok': False, 'native_windows': False, 'zip_sha256': sums[args.zip.name],
               'build_sha256': W.digest(args.build), 'source_commit': build['source_commit'],
               'wine_sha256': W.digest(args.wine), 'commands': [], 'maps': [],
               'helpers_sha256': helpers,
               'limits': ['official Windows PE under Wine, not native Windows',
                          'exact-package startup on every map, no menu, export, sharing, rendering or feel proof']}
    W.budget(out)
    try:
        with zipfile.ZipFile(args.zip) as packed:
            names = set()
            assert sum(entry.file_size for entry in packed.infolist()) <= 256 * 2**20
            for entry in packed.infolist():
                path = PurePosixPath(entry.filename)
                assert entry.filename not in names and not path.is_absolute() and '..' not in path.parts
                assert path.as_posix() == entry.filename.rstrip('/') and '\\' not in entry.filename
                assert not entry.flag_bits & 1 and stat.S_IFMT(entry.external_attr >> 16) in (0, stat.S_IFREG, stat.S_IFDIR)
                names.add(entry.filename)
                target = release.joinpath(*path.parts)
                if entry.is_dir():
                    target.mkdir(parents=True, exist_ok=True)
                else:
                    target.parent.mkdir(parents=True, exist_ok=True)
                    with packed.open(entry) as incoming, target.open('wb') as outgoing:
                        shutil.copyfileobj(incoming, outgoing)
            assert packed.testzip() is None
        metadata = list(release.rglob('BUILD.json'))
        assert len(metadata) == 1
        embedded = json.loads(metadata[0].read_text())
        assert all(embedded.get(key) == value for key, value in build.items() if key != 'platforms')
        folder = metadata[0].parent
        packs = list(folder.glob('*.pck'))
        exes = [p for p in folder.glob('*.exe') if not p.name.endswith('.console.exe')]
        consoles = list(folder.glob('*.console.exe'))
        assert len(packs) == len(exes) == len(consoles) == 1
        assert W.digest(packs[0]) == build['pack_sha256']
        assert W.digest(exes[0]) == W.TEMPLATE_SHA and W.digest(consoles[0]) == W.CONSOLE_SHA
        assert embedded['runtime_sha256'] == {exes[0].name: W.TEMPLATE_SHA, consoles[0].name: W.CONSOLE_SHA}
        assert build['runtime']['members_sha256']['windows_release_x86_64.exe'] == W.TEMPLATE_SHA
        assert build['runtime']['members_sha256']['windows_release_x86_64_console.exe'] == W.CONSOLE_SHA
        receipt.update(pack_sha256=W.digest(packs[0]), exe_sha256=W.digest(exes[0]), console_sha256=W.digest(consoles[0]))
        before = {str(p.relative_to(folder)): W.digest(p) for p in folder.rglob('*') if p.is_file()}
        for map_id in MAPS:
            log = out / (map_id + '.log')
            command = [args.wine.resolve(), exes[0], '--headless', '--audio-driver', 'Dummy', '--quit-after', '12', '--',
                       '--no-records', '--no-run-recordings', '--verify-startup', '--r16-map=' + map_id]
            result = W.execute(command, env, folder, log, out, seconds=60)
            text = log.read_text(errors='replace')
            startup = re.search(r'^r16: build=spillway-2026\.11\.09-r16; map=([^;]+); preset=server128; physics_hz=128;.*records=off; recordings=off; runner=.*; standin=false; renderer=\S+', text, re.M)
            assert startup and startup[1] == map_id and 'r20: spillway-2026.11.10-r20;' in text, map_id + ': wrong startup'
            assert 'startup_error=' not in text and 'ObjectDB instances leaked' not in text
            receipt['commands'].append(result)
            receipt['maps'].append({'map': map_id, 'ok': True, 'log_sha256': W.digest(log), 'startup': startup[0]})
            print(map_id + ': pass', flush=True)
        assert before == {str(p.relative_to(folder)): W.digest(p) for p in folder.rglob('*') if p.is_file()}
        game_writes = [str(p.relative_to(out)) for p in (out / 'prefix/drive_c/users').rglob('*')
                       if p.is_file() and '/godot/app_userdata/spillway/' in p.as_posix().lower()]
        assert not game_writes, 'no-records startup wrote game user data: ' + str(game_writes)
        receipt.update(ok=True, extracted_files=len(before), checks=len(receipt['maps']), resources_after=W.budget(out))
    except BaseException as error:
        receipt['failure'] = str(error)
        raise
    finally:
        try:
            subprocess.run([str(args.wine.parent / 'wineserver'), '-k'], env=env, timeout=5, check=False,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        finally:
            (out / 'RESULT.json').write_text(json.dumps(receipt, indent=2) + '\n')
            for name in ['release', 'profile', 'prefix']:
                shutil.rmtree(out / name, ignore_errors=True)


if __name__ == '__main__':
    main()
