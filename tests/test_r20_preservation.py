#!/usr/bin/env python3
"""challenge the immutable-map/source boundary independently of gameplay tests."""
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("preservation", Path(__file__).parents[1] / "tools/check-r20-preservation.py")
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)


class Preservation(unittest.TestCase):
    def setUp(self):
        self.base = {"scripts/r15_source_player.gd": "a", "scripts/r15_maps.gd": "b",
                     "scripts/r19_surf_level.gd": "c", "scripts/r16_style.gd": "d"}

    def test_new_versioned_course_is_allowed(self):
        candidate = dict(self.base, **{"scripts/r20_surf_level.gd": "new"})
        self.assertTrue(gate.compare(self.base, candidate, {})["ok"])

    def test_even_hash_authorization_cannot_change_physics(self):
        candidate = dict(self.base, **{"scripts/r15_source_player.gd": "drift"})
        self.assertFalse(gate.compare(self.base, candidate, {"scripts/r15_source_player.gd": "drift"})["ok"])

    def test_original_map_catalog_is_immutable(self):
        candidate = dict(self.base, **{"scripts/r15_maps.gd": "drift"})
        self.assertFalse(gate.compare(self.base, candidate, {})["ok"])

    def test_old_course_remains_as_comparison(self):
        candidate = dict(self.base, **{"scripts/r19_surf_level.gd": "rewrite"})
        self.assertFalse(gate.compare(self.base, candidate, {})["ok"])

    def test_style_change_requires_exact_reviewed_hash(self):
        candidate = dict(self.base, **{"scripts/r16_style.gd": "stack"})
        self.assertFalse(gate.compare(self.base, candidate, {})["ok"])
        self.assertFalse(gate.compare(self.base, candidate, {"scripts/r16_style.gd": "wrong"})["ok"])
        self.assertTrue(gate.compare(self.base, candidate, {"scripts/r16_style.gd": "stack"})["ok"])

    def test_deletion_never_authorized(self):
        candidate = self.base.copy()
        del candidate["scripts/r16_style.gd"]
        self.assertFalse(gate.compare(self.base, candidate, {"scripts/r16_style.gd": None})["ok"])

    def test_stale_and_unknown_exceptions_refused(self):
        self.assertFalse(gate.compare(self.base, self.base, {"scripts/r16_style.gd": "d"})["ok"])
        self.assertFalse(gate.compare(self.base, self.base, {"new": "d"})["ok"])


if __name__ == "__main__":
    unittest.main()
