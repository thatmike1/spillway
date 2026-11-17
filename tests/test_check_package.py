#!/usr/bin/env python3
"""negative package controls do not need Godot or a build."""
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import check_package as checker


class PackageChecks(unittest.TestCase):
    def test_zip_rejects_traversal(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "bad.zip"
            with zipfile.ZipFile(path, "w") as archive:
                archive.writestr("../escape", "oops")
            with self.assertRaisesRegex(ValueError, "Unsafe ZIP"):
                with checker.package_folder(path):
                    pass
            self.assertFalse((Path(tmp) / "escape").exists())

    def test_zip_rejects_symlink(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "bad.zip"
            with zipfile.ZipFile(path, "w") as archive:
                item = zipfile.ZipInfo("Spillway.pck")
                item.external_attr = 0o120777 << 16
                archive.writestr(item, "/etc/passwd")
            with self.assertRaisesRegex(ValueError, "Unsafe ZIP"):
                with checker.package_folder(path):
                    pass

    def test_windows_hashes_manifest_and_linux_resource_identity(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for name in ("Spillway.exe", "GODOT-LICENSE.txt", "GODOT-COPYRIGHT.txt"):
                (root / name).write_bytes(b"template")
            pack = root / "Spillway.pck"
            pack.write_bytes(b"GDPCresources")
            linux = root / "linux.pck"
            linux.write_bytes(pack.read_bytes())
            manifest = {"platform": "windows", "pack_sha256": checker.engine.sha(pack), "template_sha256": checker.engine.sha(root / "Spillway.exe")}
            (root / "BUILD.json").write_text(json.dumps(manifest))
            with patch.dict(checker.engine.TEMPLATE_HASHES, {"windows_release_x86_64.exe": manifest["template_sha256"]}):
                result = checker.static_check(root, "windows", linux)
                self.assertFalse(result["executed"])
                self.assertEqual(result["limitation"], "Windows was not executed")
                linux.write_bytes(b"GDPCdifferent")
                with self.assertRaisesRegex(ValueError, "byte-identical"):
                    checker.static_check(root, "windows", linux)
                pack.write_bytes(b"GDPCchanged")
                with self.assertRaisesRegex(ValueError, "BUILD.json"):
                    checker.static_check(root, "windows", linux)
            with self.assertRaisesRegex(ValueError, "template hash"):
                checker.static_check(root, "windows", linux)
            (root / "Spillway.exe").unlink()
            with self.assertRaisesRegex(ValueError, "Missing package file"):
                checker.static_check(root, "windows", linux)

    def test_nested_zip(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "build.zip"
            with zipfile.ZipFile(path, "w") as archive:
                archive.writestr("build/Spillway.pck", b"GDPC")
            with checker.package_folder(path) as folder:
                self.assertEqual((folder / "Spillway.pck").read_bytes(), b"GDPC")


if __name__ == "__main__":
    unittest.main()
