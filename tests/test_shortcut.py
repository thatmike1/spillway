"""Typed equality must keep both original comparators' behavior, including NaNs."""
import array
import math
from pathlib import Path
import sys
import unittest

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "verification/lib"))
import parity_core as core
from fast_exact import install

VALUES = [None, True, False, 0, 1, -1, 0.0, -0.0, 1.0,
          math.nextafter(1.0, math.inf), "x", [], {}, [1], (1,),
          array.array("f", [1]), array.array("d", [1]), object(),
          float("nan"), -float("nan"), math.inf, -math.inf]
PAIRS = [(x, y) for a in VALUES for b in VALUES
         for x, y in [(a, b), ({"sample": [a]}, {"sample": [b]})]]
EXPECTED = [(bool(list(core.differences(a, b))), core.C.difference(a, b) is not None)
            for a, b in PAIRS]
install(core)


class Shortcut(unittest.TestCase):
    def test_same_difference_decisions_as_both_original_comparators(self):
        for (a, b), (strict, legacy) in zip(PAIRS, EXPECTED):
            self.assertEqual(bool(list(core.differences(a, b))), strict)
            self.assertEqual(core.C.difference(a, b) is not None, legacy)
        print("typed comparator equivalence decisions:", len(PAIRS) * 2)

    def test_legacy_nan_refusal_survives_nested_identity(self):
        value = float("nan")
        self.assertIsNotNone(core.C.difference({"score": value}, {"score": value}))


if __name__ == "__main__":
    unittest.main()
