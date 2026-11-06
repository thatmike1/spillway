#!/usr/bin/env python3
"""Verify portable Spillway archives, then exercise their exact Linux pack in isolation."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import struct
import subprocess
import zipfile

PROJECT = Path(__file__).resolve().parents[1]
SUITES = ['test_spillway_audio.gd', 'test_spillway.gd', 'test_spillway_surf.gd',
          'test_surf_course.gd', 'test_surf_geometry.gd', 'test_spillway_flow.gd',
          'test_spillway_access.gd', 'test_spillway_boundaries.gd']
ROUTES = ['safe', 'fast', 'recovery', 'brake', 'safe_corner', 'wet']


def digest(data):
    return hashlib.sha256(data).hexdigest()


def git(*args):
    return subprocess.check_output(['git', *args], cwd=PROJECT)


def stage_fixtures(commit, destination):
    """Keep fixtures from the packaged source revision; runtime loads still use the PCK."""
    files = git('ls-tree', '-r', '--full-tree', '--name-only', commit, 'projects/foldrunner/tests').decode().splitlines()
    assert set(SUITES + ['surf_motor_driver.gd']) <= {Path(name).name for name in files}, 'required fixture source missing'
    needed = set(SUITES + ['surf_motor_driver.gd', 'test_spillway_recovery.gd'])
    files = [name for name in files if Path(name).name in needed]
    originals = destination / 'fixture-originals'
    staged = destination / 'fixture-runners'
    originals.mkdir()
    staged.mkdir()
    hashes = {}
    # only test-to-test preloads need an external path because tests are excluded from delivery.
    # game/script/shader paths stay res:// and must resolve from the delivered pack.
    for name in files:
        if not name.endswith('.gd'):
            continue
        data = git('show', commit + ':' + name)
        leaf = Path(name).name
        (originals / leaf).write_bytes(data)
        rewritten = data.decode().replace('res://tests/', str(staged) + '/')
        (staged / leaf).write_text(rewritten)
        hashes[leaf] = {'original_sha256': digest(data),
                        'runner_sha256': digest(rewritten.encode())}
    (destination / 'fixture-provenance.json').write_text(json.dumps({
        'source_commit': commit, 'method': 'test helper paths only; game paths unchanged',
        'files': hashes}, indent=2) + '\n')
    return staged


def run_checked(command, folder, profile=None):
    environment = dict(os.environ)
    if profile:
        environment['XDG_DATA_HOME'] = str(profile)
    try:
        result = subprocess.run([str(x) for x in command], cwd=folder, env=environment,
                                text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                timeout=60)
        code, output = result.returncode, result.stdout
    except subprocess.TimeoutExpired as error:
        output = error.stdout or ''
        if isinstance(output, bytes):
            output = output.decode(errors='replace')
        code, output = 124, output + '\nHOST TIMEOUT after60seconds\n'
    (folder / 'engine.log').write_text(output)
    (folder / 'command.json').write_text(json.dumps([str(x) for x in command], indent=2) + '\n')
    passed = code == 0 and not re.search(r'SCRIPT ERROR:|(^|\s)ERROR:|Parse Error:', output)
    print(folder.name, 'PASS' if passed else 'FAIL', flush=True)
    return {'passed': bool(passed), 'exit': code, 'log': str(folder / 'engine.log')}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--delivery', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    delivery = args.delivery.expanduser().resolve()
    output = args.output.expanduser().resolve()
    repository = Path(git('rev-parse', '--show-toplevel').decode().strip())
    if output == repository or repository in output.parents:
        parser.error('verification must run outside Git')
    if output.exists() and any(output.iterdir()):
        parser.error('use a fresh output directory; failed evidence is retained')
    output.mkdir(parents=True, exist_ok=True)
    common = json.loads((delivery / 'BUILD.json').read_text())
    assert common['build'] == 'spillway-2026.11.06-r12', 'this verifier expects r12'
    assert re.fullmatch(r'[0-9a-f]{40}', common['source_commit'])
    archives = sorted(delivery.glob('*.zip'))
    assert len(archives) == 2, 'one Linux and one Windows archive are required'
    expected = {name: checksum for checksum, name in
                (line.split('  ', 1) for line in (delivery / 'SHA256SUMS').read_text().splitlines())}
    assert set(expected) == {path.name for path in archives}
    checks = []
    platforms = set()
    linux = None
    for path in archives:
        actual_hash = digest(path.read_bytes())
        assert actual_hash == expected[path.name], 'archive checksum mismatch'
        with zipfile.ZipFile(path) as archive:
            assert archive.testzip() is None, 'archive CRC failure'
            prefixes = {Path(name).parts[0] for name in archive.namelist()}
            assert len(prefixes) == 1
            prefix = prefixes.pop()
            assert all(not name.startswith('/') and '..' not in Path(name).parts
                       for name in archive.namelist())
            manifest = json.loads(archive.read(prefix + '/BUILD.json'))
            for key in ['game', 'build', 'source_commit', 'engine', 'pack_sha256']:
                assert manifest[key] == common[key], 'platform manifest differs: ' + key
            platforms.add(manifest['platform'])
            assert digest(archive.read(prefix + '/spillway.pck')) == common['pack_sha256']
            for name, expected_hash in manifest['runtime_sha256'].items():
                data = archive.read(prefix + '/runtime/' + name)
                assert digest(data) == expected_hash, 'runtime checksum mismatch'
                if name.endswith('.exe'):
                    offset = struct.unpack_from('<I', data, 60)[0]
                    assert data[:2] == b'MZ' and data[offset:offset + 4] == b'PE\0\0'
                    assert struct.unpack_from('<H', data, offset + 4)[0] == 0x8664
                else:
                    assert data[:5] == b'\x7fELF\x02' and struct.unpack_from('<H', data, 18)[0] == 62
            for name in ['GODOT-LICENSE.txt', 'GODOT-COPYRIGHT.txt']:
                assert len(archive.read(prefix + '/' + name)) > 1000
            if manifest['platform'] == 'linux-x86_64':
                extraction = output / 'Linux play test with spaces'
                archive.extractall(extraction)
                for member in archive.infolist():
                    mode = member.external_attr >> 16
                    if mode and not member.is_dir():
                        (extraction / member.filename).chmod(mode & 0o777)
                linux = extraction / prefix
                assert os.access(linux / 'play.sh', os.X_OK)
                assert os.access(linux / 'runtime/godot', os.X_OK)
            checks.append({'archive': str(path), 'sha256': actual_hash,
                           'manifest': manifest, 'checks': ['CRC', 'archive/pack/runtime hashes',
                             'x86-64 executable headers', 'licences', 'matching source/build']})
    assert platforms == {'linux-x86_64', 'windows-x86_64'} and linux
    (output / 'archive-audit.json').write_text(json.dumps(checks, indent=2) + '\n')
    fixtures = stage_fixtures(common['source_commit'], output)
    suites = SUITES + (['test_spillway_recovery.gd'] if (fixtures / 'test_spillway_recovery.gd').exists() else [])
    rows = []
    for suite in suites:
        folder = output / suite.removesuffix('.gd')
        folder.mkdir()
        command = [linux / 'play.sh', '--headless', '--fixed-fps', '120', '--script', fixtures / suite,
                   '--', '--evidence-dir=' + str(folder)]
        row = {'suite': suite, **run_checked(command, folder, folder / 'profile')}
        totals = re.findall(r'(\d+)/(\d+) checks passed', (folder / 'engine.log').read_text())
        row['totals'] = totals
        row['passed'] = bool(row['passed'] and totals and all(int(a) == int(b) > 0 for a, b in totals))
        rows.append(row)
    for route in ROUTES:
        folder = output / ('route-' + route)
        folder.mkdir()
        command = [linux / 'play.sh', '--headless', '--fixed-fps', '120', '--', '--bot',
                   '--bot-quit', '--route=' + route, '--seed=0', '--evidence-dir=' + str(folder)]
        row = {'route': route, **run_checked(command, folder, folder / 'profile')}
        traces = list(folder.glob('route-*.jsonl'))
        finals = [json.loads(line) for trace in traces for line in trace.read_text().splitlines()
                  if json.loads(line).get('event') == 'result']
        final = finals[0] if len(finals) == 1 and len(traces) == 1 else {}
        row['result'] = final
        row['passed'] = bool(row['passed'] and final.get('success') and final.get('respawns') == 0
                             and final.get('ordered_checkpoints') == [0, 1, 2]
                             and final.get('finish_kind') == 'clean' and final.get('clean_eligible'))
        rows.append(row)
    unchanged = digest((linux / 'spillway.pck').read_bytes()) == common['pack_sha256']
    passed = unchanged and all(row['passed'] for row in rows)
    (output / 'verification.json').write_text(json.dumps({'passed': passed, 'runtime_unchanged': unchanged,
        'build': common, 'linux_folder': str(linux), 'checks': rows,
        'limits': ['native Windows execution and desktop GPU performance are not tested']}, indent=2) + '\n')
    raise SystemExit(0 if passed else 1)


if __name__ == '__main__':
    main()
