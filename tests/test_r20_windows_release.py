#!/usr/bin/env python3
"""test Windows release refusal and coverage without executing Wine or a game."""
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('r20_windows_release_under_test', Path(__file__).resolve().parents[1] / 'tools/check-r20-windows-release.py')
M = importlib.util.module_from_spec(spec)
spec.loader.exec_module(M)


class WindowsRelease(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='r20-windows-gate-', dir='/tmp')
        self.root = Path(self.temp.name)
        self.out = self.root / 'evidence'
        self.zip = self.root / 'windows.zip'
        self.wine = self.root / 'wine64'
        self.wine.write_bytes(b'not an executable')
        self.files = {'SpillwayR20.exe': b'pe', 'SpillwayR20.console.exe': b'console', 'SpillwayR20.pck': b'pack'}
        self.digest = lambda data: hashlib.sha256(data).hexdigest()
        self.build = {'round': 'R20', 'build': 'spillway-2026.11.10-r20', 'source_commit': 'a' * 40,
                      'freeze': {'required_maps': M.MAPS, 'source_commit': 'a' * 40},
                      'platforms': [self.zip.name], 'pack_sha256': self.digest(b'pack'),
                      'runtime': {'members_sha256': {'windows_release_x86_64.exe': self.digest(b'pe'),
                                  'windows_release_x86_64_console.exe': self.digest(b'console')}}}
        self.original_digest = M.W.digest
        self.calls = []

    def tearDown(self):
        self.temp.cleanup()

    def fixture(self, mutation=None):
        embedded = {key: value for key, value in self.build.items() if key != 'platforms'}
        embedded['runtime_sha256'] = {'SpillwayR20.exe': self.digest(b'pe'), 'SpillwayR20.console.exe': self.digest(b'console')}
        files = dict(self.files, **{'BUILD.json': json.dumps(embedded).encode()})
        if mutation:
            mutation(files)
        with zipfile.ZipFile(self.zip, 'w') as packed:
            for name, data in files.items():
                packed.writestr(name, data)
        (self.root / 'BUILD.json').write_text(json.dumps(self.build))
        (self.root / 'SHA256SUMS').write_text(self.original_digest(self.zip) + '  ' + self.zip.name + '\n')

    def execute(self, command, env, cwd, log, root, seconds):
        map_id = command[-1].removeprefix('--r16-map=')
        self.calls.append(map_id)
        log.write_text('r16: build=spillway-2026.11.09-r16; map=' + map_id + '; preset=server128; physics_hz=128; records=off; recordings=off; runner=res://runner.gd; standin=false; renderer=gl_compatibility\nr20: spillway-2026.11.10-r20;\n')
        index = command.index('--log-file')
        self.assertLess(index, command.index('--'))
        self.assertEqual(command[index + 1], M.W.win(root / (map_id + '.engine.log')))
        (root / (map_id + '.engine.log')).write_text(log.read_text())
        return {'exit': 0}

    def invoke(self, execute=None, verification_commit=None, changed_paths=None):
        arguments = ['check', '--zip', str(self.zip), '--build', str(self.root / 'BUILD.json'),
                     '--checksums', str(self.root / 'SHA256SUMS'), '--wine', str(self.wine), '--out', str(self.out)]
        if verification_commit is not None:
            arguments += ['--verification-commit', verification_commit]
        def git_output(args, **kwargs):
            if args[1] == 'diff':
                return '\n'.join(changed_paths or [])
            return (M.PROJECT / args[2].split(':projects/foldrunner/', 1)[1]).read_bytes()
        def digest(path):
            return '91dfdd714f2c9078f010341346196d426e81c633ca0865cf7cc678e2825562db' if Path(path) == self.wine else self.original_digest(path)
        with patch.object(sys, 'argv', arguments), patch.object(M.W, 'digest', side_effect=digest), \
                patch.object(M.W, 'TEMPLATE_SHA', self.digest(b'pe')), patch.object(M.W, 'CONSOLE_SHA', self.digest(b'console')), \
                patch.object(M.W, 'budget', return_value={'synthetic': True}), \
                patch.object(M.W, 'execute', side_effect=execute or self.execute), \
                patch.object(M.subprocess, 'check_output', side_effect=git_output), \
                patch.object(M.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0)):
            M.main()

    def test_all_eleven_startups_and_cleanup(self):
        self.fixture()
        self.invoke()
        result = json.loads((self.out / 'RESULT.json').read_text())
        self.assertTrue(result['ok'])
        self.assertEqual(self.calls, M.MAPS)
        self.assertFalse(result['native_windows'])
        self.assertFalse((self.out / 'release').exists())
        self.assertFalse((self.out / 'prefix').exists())
        self.assertTrue(all(row['engine_log_sha256'] == self.original_digest(self.out / (row['map'] + '.engine.log'))
                            for row in result['maps']))

    def test_explicit_verifier_only_descendant_preserves_artifact_source(self):
        self.fixture()
        self.invoke(verification_commit='b' * 40, changed_paths=sorted(M.VERIFIER_ONLY))
        result = json.loads((self.out / 'RESULT.json').read_text())
        self.assertTrue(result['ok'])
        self.assertEqual(result['source_commit'], 'a' * 40)
        self.assertEqual(result['verification_commit'], 'b' * 40)
        self.assertEqual(result['verification_only_changes'], sorted(M.VERIFIER_ONLY))

    def test_verifier_commit_cannot_admit_runtime_or_other_changes(self):
        checker = 'projects/foldrunner/tools/check-r20-windows-release.py'
        for changed in [[checker, 'projects/foldrunner/scripts/r20_main.gd'],
                        [checker, 'projects/foldrunner/project.godot'],
                        [checker, 'other-project/file.py'], [checker, checker], [],
                        ['projects/foldrunner/docs/r20/DELIVERY.md']]:
            with self.subTest(changed=changed):
                self.fixture()
                with self.assertRaises(AssertionError):
                    self.invoke(verification_commit='b' * 40, changed_paths=changed)
                self.assertEqual(self.calls, [])
                self.assertFalse(self.out.exists())

    def test_verifier_commit_requires_full_hash_and_ancestry(self):
        with self.assertRaises(AssertionError):
            M.verification_binding('a' * 40, 'main')
        with patch.object(M.subprocess, 'run', side_effect=subprocess.CalledProcessError(1, ['git'])):
            with self.assertRaises(subprocess.CalledProcessError):
                M.verification_binding('a' * 40, 'b' * 40)

    def test_engine_log_is_required_and_errors_are_refused(self):
        for mutation in ['missing', 'error', 'wrong-map']:
            with self.subTest(mutation=mutation):
                self.fixture()
                def bad(*args, **kwargs):
                    result = self.execute(*args, **kwargs)
                    engine = args[4] / (self.calls[-1] + '.engine.log')
                    if mutation == 'missing':
                        engine.unlink()
                    elif mutation == 'error':
                        engine.write_text(engine.read_text() + 'ERROR: synthetic failure\n')
                    else:
                        engine.write_text(engine.read_text().replace('map=breakwater;', 'map=overflow;'))
                    return result
                with self.assertRaises(AssertionError):
                    self.invoke(bad)
                self.out.rename(self.root / mutation)
                self.calls.clear()

    def test_no_game_data_writes_remain_strict_including_default_engine_logs(self):
        self.fixture()
        def writes(*args, **kwargs):
            result = self.execute(*args, **kwargs)
            path = args[4] / 'prefix/drive_c/users/test/AppData/Roaming/Godot/app_userdata/Spillway/logs/godot.log'
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('unexpected default log')
            return result
        with self.assertRaisesRegex(AssertionError, 'no-records startup wrote game user data'):
            self.invoke(writes)

    def test_wrong_checksum_refuses_before_execution(self):
        self.fixture()
        (self.root / 'SHA256SUMS').write_text('0' * 64 + '  ' + self.zip.name + '\n')
        with self.assertRaises(AssertionError):
            self.invoke()
        self.assertEqual(self.calls, [])

    def test_traversal_refuses_without_escape(self):
        self.fixture(lambda files: files.update({'../escape': b'bad'}))
        with self.assertRaises(AssertionError):
            self.invoke()
        self.assertFalse((self.out / 'escape').exists())
        self.assertEqual(self.calls, [])

    def test_changed_pack_and_runtime_refuse(self):
        for name in ['SpillwayR20.pck', 'SpillwayR20.exe']:
            with self.subTest(name=name):
                self.fixture(lambda files: files.update({name: b'different'}))
                with self.assertRaises(AssertionError):
                    self.invoke()
                self.assertEqual(self.calls, [])
                self.out.rename(self.root / name)

    def test_wrong_embedded_source_refuses(self):
        def change(files):
            metadata = json.loads(files['BUILD.json'])
            metadata['source_commit'] = 'b' * 40
            files['BUILD.json'] = json.dumps(metadata).encode()
        self.fixture(change)
        with self.assertRaises(AssertionError):
            self.invoke()
        self.assertEqual(self.calls, [])

    def test_wrong_map_startup_is_failure_not_coverage(self):
        self.fixture()
        def wrong(*args, **kwargs):
            result = self.execute(*args, **kwargs)
            log = args[3]
            log.write_text(log.read_text().replace('map=breakwater;', 'map=overflow;'))
            return result
        with self.assertRaises(AssertionError):
            self.invoke(wrong)
        result = json.loads((self.out / 'RESULT.json').read_text())
        self.assertFalse(result['ok'])
        self.assertEqual(result['maps'], [])


if __name__ == '__main__':
    unittest.main(verbosity=2)
