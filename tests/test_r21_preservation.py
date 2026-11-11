"""adversarial checks for the r21 committed-source preservation gate."""
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('r21_preservation', ROOT / 'tools/check-r21-preservation.py')
P = importlib.util.module_from_spec(spec)
spec.loader.exec_module(P)


class Preservation(unittest.TestCase):
    def setUp(self):
        self.old = {name: {'sha256': 'a' * 64, 'mode': '100644'} for name in (
            'scripts/r15_breakwater_level.gd', 'scripts/r14_source_motion.gd',
            'scripts/r14_presets.gd', 'scripts/r16_style.gd', 'scripts/r16_style_panel.gd',
            'scripts/r18_style_panel.gd', 'scripts/r20_main.gd',
            'scripts/r20_through_level.gd', 'scripts/r20_through_player.gd',
            'scripts/r20_tether_player.gd', 'scripts/r19_tether_player.gd',
            'project.godot', 'scripts/r19_ghost_share.gd')}

    def test_protected_mutations_and_deletions(self):
        for name in self.old:
            if name in P.ALLOWED:
                continue
            with self.subTest(name=name):
                modified = dict(self.old, **{name: {'sha256': 'b' * 64, 'mode': '100644'}})
                self.assertFalse(P.compare(self.old, modified, {name: 'b' * 64})['ok'])
                removed = dict(self.old)
                del removed[name]
                self.assertFalse(P.compare(self.old, removed, {})['ok'])
        for name in P.ALLOWED:
            removed = dict(self.old)
            del removed[name]
            self.assertFalse(P.compare(self.old, removed, {name: 'a' * 64})['ok'])

    def test_exceptions_must_be_exact_current_and_allowlisted(self):
        for name in P.ALLOWED:
            changed = dict(self.old, **{name: {'sha256': 'b' * 64, 'mode': '100644'}})
            self.assertTrue(P.compare(self.old, changed, {name: 'b' * 64})['ok'])
            for approval in ({}, {name: 'a' * 64}, {name: 'b' * 64, 'unknown': 'c' * 64}):
                self.assertFalse(P.compare(self.old, changed, approval)['ok'])
            self.assertFalse(P.compare(self.old, self.old, {name: 'a' * 64})['ok'])
            changed[name] = {'sha256': 'b' * 64, 'mode': '100755'}
            self.assertFalse(P.compare(self.old, changed, {name: 'b' * 64})['ok'])
        for bad in ({'project.godot': 'B' * 64}, {'project.godot': 'b'}, [], {'project.godot': 1}):
            with self.assertRaises(ValueError):
                P.compare(self.old, self.old, bad)
        with self.assertRaises(ValueError):
            json.loads('{"project.godot":"a","project.godot":"b"}', object_pairs_hook=P.unique_object)

    def test_project_settings_only_allow_scene_and_version(self):
        old = b'[application]\nconfig/version="r20"\nrun/main_scene="old"\n[physics]\nrate=120\n'
        self.assertTrue(P.project_settings_preserved(old, old.replace(b'"r20"', b'"r21"').replace(b'"old"', b'"new"')))
        self.assertFalse(P.project_settings_preserved(old, old.replace(b'rate=120', b'rate=60')))
        with self.assertRaises(ValueError):
            P.project_settings_preserved(old, old + b'rate=60\n')

    def test_new_versioned_modules_allowed(self):
        candidate = dict(self.old, **{'scripts/r21_surf_level.gd': {'sha256': 'c' * 64, 'mode': '100644'},
                                     'scripts/r21_tether_player.gd': {'sha256': 'd' * 64, 'mode': '100644'}})
        self.assertTrue(P.compare(self.old, candidate, {})['ok'])

    def test_git_archive_uses_only_committed_correct_subtree(self):
        with tempfile.TemporaryDirectory(prefix='r21-test-') as directory:
            repo = Path(directory)
            def git(*args):
                return subprocess.check_output(['git', '-C', str(repo), *args], stderr=subprocess.DEVNULL).decode().strip()
            git('init', '-q')
            git('config', 'user.email', 'test@example.invalid')
            git('config', 'user.name', 'test')
            project = repo / 'projects/foldrunner'
            project.mkdir(parents=True)
            (project / 'motor').write_text('committed')
            (repo / 'outside').write_text('outside')
            git('add', '.')
            git('commit', '-qm', 'baseline')
            commit = git('rev-parse', 'HEAD')
            (project / 'motor').write_text('dirty')
            (project / 'untracked').write_text('untracked')
            original = P.REPO
            try:
                P.REPO = project
                inv = P.inventory(commit)
                self.assertEqual(set(inv['files']), {'motor'})
                self.assertEqual(inv['files']['motor']['sha256'], __import__('hashlib').sha256(b'committed').hexdigest())
                popen = subprocess.Popen
                with mock.patch.object(P.subprocess, 'Popen', wraps=popen) as calls:
                    repeated = P.inventory(commit)
                self.assertEqual(inv, repeated)
                archives = [call.args[0] for call in calls.call_args_list if 'archive' in call.args[0]]
                self.assertEqual(len(archives), 1)
                self.assertIn('--mtime=@' + git('show', '-s', '--format=%ct', commit), archives[0])
                with self.assertRaises(ValueError):
                    P.inventory(commit[:12])
                (project / '.gitattributes').write_text('motor export-ignore\n')
                git('add', 'projects/foldrunner/.gitattributes')
                git('commit', '-qm', 'filter')
                with self.assertRaises(ValueError):
                    P.inventory(git('rev-parse', 'HEAD'))
            finally:
                P.REPO = original


if __name__ == '__main__':
    unittest.main()
