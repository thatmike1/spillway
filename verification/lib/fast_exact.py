"""Skip recursion only for byte-identical builtin values, without loading pickle data."""
import io
import pickle


class BuiltinPickler(pickle.Pickler):
    def reducer_override(self, value):
        # custom objects may compare by identity; let the original comparator decide.
        raise TypeError("custom value requires the original comparator")


def same(a, b):
    try:
        left, right = io.BytesIO(), io.BytesIO()
        BuiltinPickler(left, protocol=4).dump(a)
        BuiltinPickler(right, protocol=4).dump(b)
        return left.getvalue() == right.getvalue()
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
