#!/usr/bin/env python3
"""p / rebuild MANIFEST.json for the Whiteout Relay kit from the saved poly haven api records.

each shipped file is hashed here and checked against the md5 the api published for it; a
mismatch stops the build. the api records (info_<id>.json, files_<id>.json) are kept with the
evidence, under checkpoints/spillway/r15/whiteout/provenance/.

python3 -I assets/r15/whiteout/build_manifest.py --api DIR
"""
import argparse
import hashlib
import json
from pathlib import Path

KIT = Path(__file__).resolve().parent
# id, kind, api resolution key, shipped files (relative to the kit), use, in-game modifications.
ASSETS = [
    ("corrugated_iron_02", "texture", "1k", [
        ("textures/corrugated_iron_02/corrugated_iron_02_diff_1k.jpg", "Diffuse", "jpg"),
        ("textures/corrugated_iron_02/corrugated_iron_02_nor_gl_1k.jpg", "nor_gl", "jpg"),
        ("textures/corrugated_iron_02/corrugated_iron_02_arm_1k.jpg", "arm", "jpg")],
     "cladding of the start hangar, the cable works shed, the checkpoint shelters and the relay house",
     "2.7 m repeat from the api dimensions; desaturated and tinted (warm oxide red, signal orange, slate) in the shared momentum surface shader (no file edit)"),
    ("metal_plate", "texture", "1k", [
        ("textures/metal_plate/metal_plate_diff_1k.jpg", "Diffuse", "jpg"),
        ("textures/metal_plate/metal_plate_nor_gl_1k.jpg", "nor_gl", "jpg"),
        ("textures/metal_plate/metal_plate_arm_1k.jpg", "arm", "jpg")],
     "dark tread-plate tops of every route deck: hangar floor, service road, pylon tops, saddle, catwalk, receiver deck, shed floor, gantry, terraces",
     "1.0 m repeat (the api's 500 mm scan doubled); desaturated and darkened to slate in the shared surface shader so the track reads against snow (no file edit)"),
    ("qwantani_late_afternoon_puresky", "hdri", "2k", [
        ("sky/qwantani_late_afternoon_puresky_2k.hdr", "hdri", "hdr")],
     "the sky panorama and ambient light",
     "energy 0.42, rotated so its sun sits behind the scene sun's bearing (no file edit)"),
]


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def md5(path):
    return hashlib.md5(path.read_bytes()).hexdigest()


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--api", type=Path, required=True)
    args = p.parse_args()
    out = []
    total = 0
    for asset_id, kind, res, files, use, mods in ASSETS:
        info = json.loads((args.api / ("info_%s.json" % asset_id)).read_text())
        api = json.loads((args.api / ("files_%s.json" % asset_id)).read_text())
        entries = []
        for rel, key, ext in files:
            path = KIT / rel
            if kind == "hdri":
                record = api["hdri"][res][ext]
            else:
                record = api[key][res][ext]
            digest = md5(path)
            if digest != record["md5"]:
                raise SystemExit("%s: md5 %s does not match the api's %s" % (rel, digest, record["md5"]))
            size = path.stat().st_size
            total += size
            entries.append({"file": rel, "upstream_url": record["url"], "upstream_md5_api": record["md5"], "sha256": sha256(path), "bytes": size, "modified": False})
        out.append({"id": asset_id, "name": info.get("name"), "kind": kind, "authors": info.get("authors"),
                    "source_page": "https://polyhaven.com/a/%s" % asset_id, "api_files": "https://api.polyhaven.com/files/%s" % asset_id,
                    "licence": "CC0-1.0", "licence_page": "https://polyhaven.com/license", "retrieved": "2026-11-08",
                    "physical_size_mm": info.get("dimensions"), "use": use, "in_game_modifications": mods, "files": entries})
    manifest = {"kit": "Spillway R15 Whiteout Relay kit",
                "publisher": "Poly Haven (polyhaven.com), primary publisher; every asset CC0-1.0",
                "verification": "each file's md5 matched the poly haven api at download and again here; files are unmodified upstream bytes",
                "licence_text": "licences/CC0-1.0-legalcode.txt",
                "shared_library_use": "models from assets/r15/library (Kenney Space Kit, Nature Kit; CC0-1.0) and its Poly Haven Snow 02 maps, placed through scripts/r15_assets.gd; their provenance is the library's MANIFEST.json",
                "shipped_bytes": total, "shipped_mib": round(total / 2 ** 20, 2), "assets": out}
    (KIT / "MANIFEST.json").write_text(json.dumps(manifest, indent=1) + "\n")
    print("manifest: %d assets, %d bytes" % (len(out), total))


if __name__ == "__main__":
    main()
