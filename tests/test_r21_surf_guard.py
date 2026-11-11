#!/usr/bin/env python3
"""engine-free regressions for the real Saltglass baseline source inventory."""
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('r21_surf_guard', PROJECT/'tests/r21_surf_check.py')
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)


class Preservation(unittest.TestCase):
    def test_real_nested_project_inventory_is_nonempty_and_checked(self):
        with tempfile.TemporaryDirectory(prefix='r21-surf-guard-',dir='/tmp') as scratch:
            root = Path(scratch)
            guard.preserved(PROJECT,root)
            result = json.loads((root/'PRESERVATION.json').read_text())
            self.assertTrue(result['ok'])
            self.assertGreater(len(result['files']),500)
            self.assertIn('scripts/r15_source_player.gd',result['files'])
            self.assertTrue(result['files']['scripts/r15_source_player.gd']['same'])

    def test_empty_git_pathspec_result_refuses_instead_of_vacuous_success(self):
        with tempfile.TemporaryDirectory(prefix='r21-surf-guard-',dir='/tmp') as scratch:
            with patch.object(guard.subprocess,'check_output',return_value=b''):
                with self.assertRaisesRegex(RuntimeError,'empty baseline runtime inventory'):
                    guard.preserved(PROJECT,Path(scratch))
            self.assertFalse((Path(scratch)/'PRESERVATION.json').exists())

    def test_explicit_final_parent_seam_needs_its_external_digest(self):
        with tempfile.TemporaryDirectory(prefix='r21-surf-guard-',dir='/tmp') as scratch:
            root = Path(scratch)
            seam = root/'reviewed.json'
            seam.write_text('{"files":{}}')
            with self.assertRaisesRegex(RuntimeError,'parent seam hash mismatch'):
                guard.preserved(PROJECT,root,seam,'0'*64)
            with self.assertRaisesRegex(RuntimeError,'all five integration files'):
                guard.preserved(PROJECT,root,seam,guard.digest(seam))


if __name__ == '__main__':
    unittest.main()
