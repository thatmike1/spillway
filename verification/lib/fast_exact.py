"""Skip recursion only for byte-identical builtin values, without loading pickle data."""
import io
import pickle
import re


class BuiltinPickler(pickle.Pickler):
    def reducer_override(self, value):
        # custom objects may compare by identity; let the original comparator decide.
        raise TypeError("custom value requires the original comparator")


def same(a, b):
    try:
        left, right = io.BytesIO(), io.BytesIO()
        BuiltinPickler(left, protocol=4).dump(a)
        BuiltinPickler(right, protocol=4).dump(b)
        encoded = left.getvalue()
        # nonfinite floats retain each original comparator's distinct refusal semantics.
        # a conservative byte match may skip the shortcut; it cannot skip a difference.
        if re.search(rb"G[\x7f\xff][\xf0-\xff]", encoded):
            return False
        return encoded == right.getvalue()
    except (TypeError, pickle.PickleError):
        return False


def install(core):
    original = core.differences

    def differences(a, b, path="$"):
        if same(a, b):
            return
        yield from original(a, b, path)

    core.differences = differences
    old = core.C.difference

    def difference(a, b, path="$"):
        if same(a, b):
            return None
        return old(a, b, path)

    core.C.difference = difference
    core.C.OLD.difference = difference
    core.O.difference = difference
