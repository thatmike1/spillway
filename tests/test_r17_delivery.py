#!/usr/bin/env python3
"""focused delivery boundary tests; these are not native/export acceptance."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

PROJECT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('r17_delivery', PROJECT / 'tools/package-r17.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


class Delivery(unittest.TestCase):
    def test_other_worker_untracked_files_only(self):
        m.status_ok('?? tests/r17_parity.gd\n?? tools/check-r17-parity.py\n')
        m.status_ok('?? projects/foldrunner/tests/r17_parity.gd\n?? projects/foldrunner/tools/check-r17-parity.py\n')
        for status in [' M scripts/r17_main.gd\n', '?? scripts/other.gd\n', ' M tests/r17_parity.gd\n', '?? tools/package-r17.py\n']:
            with self.subTest(status=status), self.assertRaises(m.Rejected):
                m.status_ok(status)

    def test_decimal_home_floor_includes_output_budget(self):
        with patch.object(m.shutil, 'disk_usage') as usage:
            usage.return_value.free = m.FLOOR + 99
            with self.assertRaises(m.Rejected):
                m.space(100)
            usage.return_value.free = m.FLOOR + 100
            self.assertEqual(m.space(100), m.FLOOR + 100)

    def test_pins_and_behavior_are_deliberately_distinct(self):
        self.assertEqual(m.r16.BUILD, 'spillway-2026.11.09-r16')
        self.assertEqual(m.BUILD, 'spillway-2026.11.09-r17')
        self.assertEqual(m.r16.SAVE_PATH, 'user://spillway_r16.cfg')
        self.assertEqual(m.r16.MAIN_SCENE, 'res://scenes/r17.tscn')
        self.assertEqual(len(m.r16.TEMPLATE_MEMBERS), 3)
        self.assertIn('tools/r16-pack-probe.gd', m.HELPERS)
        self.assertIn('tools/r17-pack-probe.gd', m.HELPERS)

    def test_asset_provenance_includes_every_prompt(self):
        files = [str(p.relative_to(PROJECT)) for p in (PROJECT / 'assets').rglob('*') if p.is_file()]
        licences = m.licence_files(files)
        self.assertIn('licenses/assets/look/r17/PROVENANCE.md', licences)
        self.assertIn('licenses/assets/look/r17/MANIFEST.json', licences)
        self.assertEqual(len([p for p in licences if p.startswith('licenses/assets/look/r17/') and p.endswith('-sky-prompt.txt')]), 7)
        self.assertEqual(m.asset_manifest(PROJECT)['files'], 14)

    def test_corrupt_or_traversing_sky_manifest_refused(self):
        with tempfile.TemporaryDirectory(prefix='r17-delivery-test-') as tmp:
            root = Path(tmp)
            assets = root / 'assets/look/r17'
            assets.mkdir(parents=True)
            for name in ['../escape.png', 'whiteout-sky.png']:
                manifest = {'files': {name: '0' * 64, **{str(i): '0' * 64 for i in range(13)}}}
                (assets / 'MANIFEST.json').write_text(json.dumps(manifest))
                with self.assertRaises((m.Rejected, FileNotFoundError)):
                    m.asset_manifest(root)

    def test_wrong_manifest_identity_refused_before_git(self):
        for build in [{}, {'round': 'R17', 'build': m.r16.BUILD}]:
            with patch.object(m.r16, 'git') as git, self.assertRaises(m.Rejected):
                m.verify_manifest(build)
            git.assert_not_called()

    def test_delivered_r16_is_preserved_in_live_committed_source(self):
        self.assertEqual(m.preservation(m.r16.git('rev-parse', 'HEAD').strip(), 'projects/foldrunner')['files'], 475)

    def test_subtree_listing_is_complete_from_project_cwd(self):
        files = m.r16.git('ls-tree', '-r', '--name-only', '--full-tree', 'HEAD:./').splitlines()
        self.assertGreater(len(files), 1000)
        self.assertIn('scripts/r17_main.gd', files)
        self.assertIn('assets/look/r17/whiteout-sky.png', files)


if __name__ == '__main__':
    unittest.main()
