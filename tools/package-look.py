#!/usr/bin/env python3
"""package this committed experimental source with the pinned Linux release runtime."""
import argparse
import hashlib
import json
import shutil
import stat
import subprocess
import tempfile
import zipfile
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[1]
CACHE = Path.home() / '.local/share/foldrunner'
ENGINE = CACHE / 'godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64'
RUNTIME = CACHE / 'godot-4.7.2-templates/linux_release.x86_64'
NAME = 'SpillwayLookC-linux-x86_64'
RESERVE = 15_000_000_000


def digest(path):
    return hashlib.file_digest(path.open('rb'), 'sha256').hexdigest()


def git(*args):
    return subprocess.check_output(['git', *args], cwd=PROJECT, text=True).strip()


def reserve(extra=0):
    available = shutil.disk_usage(Path.home()).free
    if available < RESERVE + extra:
        raise RuntimeError('15 GB HOME reserve would be crossed')
    return available


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    if git('status', '--porcelain', '--', '.'):
        raise RuntimeError('commit the project before packaging')
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    target = out / (NAME + '.zip')
    if target.exists():
        raise RuntimeError('refusing to overwrite an existing delivery')
    source = git('rev-parse', 'HEAD')
    provenance = json.loads((CACHE / 'godot-4.7.2-templates/PROVENANCE.json').read_text())
    source_manifest = {name: digest(PROJECT / name) for name in git('ls-files').splitlines()}
    free_before = reserve(150_000_000)
    # staging lives in RAM; only the final compressed package consumes HOME space.
    with tempfile.TemporaryDirectory(prefix='spillway-look-package-') as scratch:
        root = Path(scratch)
        folder = root / NAME
        folder.mkdir()
        pack = folder / 'SpillwayLookC.pck'
        command = [str(ENGINE), '--headless', '--path', str(PROJECT), '--export-pack', 'Look Pack', str(pack)]
        export = subprocess.run(command, capture_output=True, text=True, timeout=180)
        (out / 'export.log').write_text(export.stdout + export.stderr)
        if export.returncode or not pack.is_file() or pack.stat().st_size < 1000:
            raise RuntimeError('pack export failed; see export.log')
        shutil.copy2(RUNTIME, folder / 'SpillwayLookC.x86_64')
        (folder / 'SpillwayLookC.x86_64').chmod(0o755)
        launcher = folder / 'play.sh'
        launcher.write_text('#!/usr/bin/env bash\nset -euo pipefail\ncd "$(dirname "$0")"\nexec ./SpillwayLookC.x86_64 "$@"\n')
        launcher.chmod(0o755)
        (folder / 'README.txt').write_text(
            'SPILLWAY / LOOK C / SLICE 1\n\nExtract the entire folder, then run ./play.sh.\n'
            'Starts on Breakwater with the paint-and-ink experiment. L switches to the original look and back during a run.\n'
            'WASD move, mouse look, Space jump/hold to bhop, Ctrl/C crouch, R restart, F checkpoint practice, Esc maps/settings.\n'
            'F2 bhop server; F5 AA1000. Release W in the air, hold A or D and turn the mouse the same way.\n'
            'This is a look experiment on the R15 course runner. R16 work is separate. Other maps keep their original look.\n'
            'Records and settings are session-only. No old profiles are read or written.\n'
            'The portable executable requires an x86_64 Linux desktop with working OpenGL 3.3 support.\n'
            'This package has been checked on the laptop AMD GPU; the desktop GPU and your subjective readability are separate checks.\n'
        )
        licenses = folder / 'licenses'
        licenses.mkdir()
        for item in (CACHE / 'godot-4.7.2/licenses').iterdir():
            if item.is_file():
                shutil.copy2(item, licenses / item.name)
        for item in (PROJECT / 'assets').rglob('*'):
            if item.is_file() and ('license' in item.name.lower() or 'licence' in item.name.lower() or item.name in {'MANIFEST.json', 'PROVENANCE.md', 'sky-prompt.txt'}):
                destination = licenses / item.relative_to(PROJECT)
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(item, destination)
        manifest = {'build': 'spillway-look-c-1', 'source_commit': source,
                    'base_commit': '1fe1d7a8c', 'branch': 'feat/spillway-look-c',
                    'runtime_sha256': digest(RUNTIME), 'pack_sha256': digest(pack),
                    'runtime_provenance': provenance, 'source_files': source_manifest}
        (folder / 'BUILD.json').write_text(json.dumps(manifest, indent=2) + '\n')
        # run outside source, using the exact release executable that will be zipped.
        empty = root / 'empty'
        empty.mkdir()
        with (out / 'packed-startup.log').open('w') as log:
            checked = subprocess.run([str(folder / 'SpillwayLookC.x86_64'), '--headless', '--audio-driver', 'Dummy', '--', '--verify-startup', '--no-records'], cwd=empty, stdout=log, stderr=subprocess.STDOUT, timeout=90)
        text = (out / 'packed-startup.log').read_text()
        if checked.returncode or 'look-c: spillway-look-c-1' not in text or 'ERROR' in text:
            raise RuntimeError('exact packed startup failed outside source')
        reserve(100_000_000)
        pending = out / (NAME + '.zip.partial')
        try:
            with zipfile.ZipFile(pending, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
                for item in sorted(folder.rglob('*')):
                    if item.is_file():
                        archive.write(item, item.relative_to(root))
            pending.rename(target)
        finally:
            pending.unlink(missing_ok=True)
        receipt = {'source_commit': source, 'zip': str(target), 'zip_sha256': digest(target),
                   'pack_sha256': manifest['pack_sha256'], 'runtime_sha256': manifest['runtime_sha256'],
                   'bytes': target.stat().st_size, 'startup_exit': checked.returncode,
                   'free_home_before': free_before, 'free_home_after': reserve()}
        (out / 'delivery.json').write_text(json.dumps(receipt, indent=2) + '\n')
        print(json.dumps(receipt, indent=2))


if __name__ == '__main__':
    main()
