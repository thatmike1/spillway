#!/usr/bin/env python3
"""package the committed game with pinned native runtimes outside the checkout."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import zipfile

PROJECT = Path(__file__).resolve().parents[1]
ENGINE_DIR = Path.home() / '.local/share/foldrunner/godot-4.7.2'


def run(args, cwd=PROJECT):
    result = subprocess.run([str(a) for a in args], cwd=cwd, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if result.returncode or re.search(r'SCRIPT ERROR:|(^|\s)ERROR:|Parse Error:', result.stdout):
        raise RuntimeError(result.stdout)
    return result.stdout


def digest(path):
    value = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            value.update(block)
    return value.hexdigest()


def archive(folder, destination):
    temporary = destination.with_suffix('.zip.tmp')
    try:
        with zipfile.ZipFile(temporary, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as output:
            for path in sorted(folder.rglob('*')):
                if path.is_file():
                    output.write(path, Path(folder.name) / path.relative_to(folder))
        os.replace(temporary, destination)
    finally:
        temporary.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--godot', type=Path, default=ENGINE_DIR / 'Godot_v4.7.2-stable_linux.x86_64')
    parser.add_argument('--windows-runtime', type=Path, default=Path.home() / '.local/share/foldrunner/godot-4.7.2-windows')
    args = parser.parse_args()
    output = args.output.expanduser().resolve()
    repository = Path(run(['git', 'rev-parse', '--show-toplevel']).strip())
    if output == repository or repository in output.parents:
        parser.error('delivery output must be outside the Git checkout')
    if run(['git', 'status', '--porcelain', '--', '.']).strip():
        parser.error('commit the project before packaging for a reviewable source identity')
    engine = args.godot.expanduser().resolve()
    version = run([engine, '--headless', '--version']).strip()
    if not version.startswith('4.7.2.stable.official.'):
        parser.error('the package requires the pinned official Godot 4.7.2 runtime')
    windows = args.windows_runtime.expanduser().resolve()
    names = ['Godot_v4.7.2-stable_win64.exe', 'Godot_v4.7.2-stable_win64_console.exe']
    if not all((windows / name).is_file() for name in names):
        parser.error('download and extract the pinned official Windows runtime first')
    provenance = json.loads((windows / 'PROVENANCE.json').read_text())
    if provenance.get('official_digest') != 'sha256:' + digest(windows / 'Godot_v4.7.2-stable_win64.exe.zip'):
        parser.error('Windows archive does not match the recorded official release digest')
    with zipfile.ZipFile(windows / 'Godot_v4.7.2-stable_win64.exe.zip') as official:
        for name in names:
            expected = hashlib.sha256()
            with official.open(name) as stream:
                for block in iter(lambda: stream.read(1024 * 1024), b''):
                    expected.update(block)
            if digest(windows / name) != expected.hexdigest():
                parser.error('extracted Windows runtime differs from the verified archive: ' + name)
    licenses = ENGINE_DIR / 'licenses'
    for name in ['GODOT-LICENSE.txt', 'GODOT-COPYRIGHT.txt']:
        if not (licenses / name).is_file():
            parser.error('official Godot licence and third-party notices are required')
    source = run(['git', 'rev-parse', 'HEAD']).strip()
    match = re.search(r'const BUILD_ID\s*:?=\s*"([^"]+)"', (PROJECT / 'scripts/spillway_main.gd').read_text())
    if not match:
        parser.error('visible build identity missing')
    identity = match.group(1)
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.spillway-stage-', dir=output) as scratch:
        stage = Path(scratch)
        pack = stage / 'spillway.pck'
        log = run([engine, '--headless', '--path', PROJECT, '--export-pack', 'Spillway Pack', pack])
        (output / 'export-log.txt').write_text(log)
        preflight = run(['bash', PROJECT / 'tools/check-pack.sh', pack], cwd=stage)
        (output / 'packed-resources.txt').write_text(preflight)
        startup = run([engine, '--headless', '--main-pack', pack, '--', '--verify-startup'], cwd=stage)
        (output / 'packed-startup.txt').write_text(startup)
        if 'startup: Spillway; build=' + identity not in startup:
            raise RuntimeError('packed startup did not identify the intended build')
        common = {'game': 'Spillway', 'build': identity, 'source_commit': source, 'engine': version,
                  'pack_sha256': digest(pack), 'windows_release': provenance,
                  'native_windows_execution': 'not verified on this Linux host'}
        for platform in ['linux-x86_64', 'windows-x86_64']:
            folder = stage / ('Spillway-' + platform)
            runtime = folder / 'runtime'
            runtime.mkdir(parents=True)
            shutil.copy2(pack, folder / 'spillway.pck')
            manifest = dict(common, platform=platform)
            if platform.startswith('linux'):
                target = runtime / 'godot'
                shutil.copy2(engine, target)
                target.chmod(0o755)
                launcher = folder / 'play.sh'
                launcher.write_text('#!/usr/bin/env bash\nset -euo pipefail\ncd "$(dirname "$0")"\nexec ./runtime/godot --main-pack "$PWD/spillway.pck" "$@"\n')
                launcher.chmod(0o755)
                manifest['runtime_sha256'] = {'godot': digest(target)}
                launch = './play.sh'
            else:
                for name in names:
                    shutil.copy2(windows / name, runtime / name)
                (folder / 'Play Spillway.cmd').write_bytes(b'@echo off\r\ncd /d "%~dp0"\r\nstart "Spillway" "runtime\\Godot_v4.7.2-stable_win64.exe" --main-pack "%~dp0spillway.pck" %*\r\n')
                (folder / 'Debug Spillway.cmd').write_bytes(b'@echo off\r\ncd /d "%~dp0"\r\n"runtime\\Godot_v4.7.2-stable_win64_console.exe" --main-pack "%~dp0spillway.pck" %*\r\npause\r\n')
                manifest['runtime_sha256'] = {name: digest(runtime / name) for name in names}
                launch = 'double-click Play Spillway.cmd'
            for name in ['GODOT-LICENSE.txt', 'GODOT-COPYRIGHT.txt']:
                shutil.copy2(licenses / name, folder / name)
            (folder / 'BUILD.json').write_text(json.dumps(manifest, indent=2) + '\n')
            (folder / 'README.txt').write_text(
                'SPILLWAY / THE LONG WAY DOWN\n' + identity + '\n\nExtract the whole folder, then ' + launch + '.\n'
                'No source checkout or engine installation is needed. Keep runtime/ and spillway.pck together.\n'
                'WASD run; mouse look; Space jump (hold to bhop); Ctrl/C slide; R restart; F segment practice; Esc settings; F11 fullscreen.\n'
                'Run before your first hop. Air strafe: release W, hold A or D and turn the mouse the same way.\n'
                'Surf: strafe into the angled face; look along it, slightly away from the concrete.\n'
                'Autohop is on by default; toggle it in Esc settings. Slides and hops keep speed through shallow water.\n'
                'The visible build identity is in the pause menu. BUILD.json records this exact source and runtime.\n'
                'R12 settings and personal bests use spillway_r12.cfg in the OS Godot user data directory for Spillway. R11 records stay separate.\n'
                'Native Windows gameplay and physical gamepad hardware are unverified on the Linux build host.\n')
            destination = output / (identity + '-' + platform + '-' + source[:8] + '.zip')
            archive(folder, destination)
            print(destination)
        files = sorted(output.glob(identity + '-*.zip'))
        (output / 'SHA256SUMS').write_text(''.join(digest(path) + '  ' + path.name + '\n' for path in files))
        (output / 'BUILD.json').write_text(json.dumps(common, indent=2) + '\n')


if __name__ == '__main__':
    main()
