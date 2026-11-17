#!/usr/bin/env python3
"""p / writes MANIFEST.json for the breakwater kit from the files on disk and the poly haven api
records saved at download time (files/<asset> and info/<asset>, plus the download log with the
url, md5 and sha256 of every byte fetched). every shipped file is byte-identical to its
upstream download; this checks that and records the use and the in-game modifications.

the original download records are not retained in the repository. --api explicitly
selects caller-supplied public api records; this optional provenance rebuild is not
required to run, test or export the game.

python3 -I assets/r15/breakwater/build_manifest.py --api DIR
"""
import argparse
import hashlib
import json
from pathlib import Path

KIT = Path(__file__).resolve().parent
RETRIEVED = "2026-11-08"

# what each asset is for on the map and what the game does to it (never to the file).
USE = {
    "container_side": ("every shipping container: walls, roofs and door ends of the route blocks, yard stacks and wall stacks",
                       "1.94 m repeat from the api dimensions; desaturated and re-tinted per container colour in the kit surface shader (no file edit)"),
    "box_profile_metal_sheet": ("gatehouse, warehouse and terminal office cladding", "2.0 m repeat; desaturated and tinted steel blue or warm brown in the shader"),
    "rusty_painted_metal": ("crane legs, portal beams and booms, the ship, container frames, the gatehouse canopy, light posts, the gangway parapet and lamp poles", "2.2 m repeat; desaturated and tinted crane red, steel grey, hull dark or white in the shader"),
    "asphalt_02": ("terminal roads: the box-row alleys, the crane line, both bends and the land apron", "3.0 m repeat; tinted lighter on the route, darker on the apron"),
    "square_concrete_pavers": ("gate deck, breakwater runway and lighthouse roundhead", "1.8 m repeat; desaturated and tinted to a pale precast tone"),
    "white_plaster_rough_02": ("lighthouse tower and plinth", "1.0 m repeat used at 2.0 m; desaturated and brightened to weathered white, red band by tint"),
    "lateral_sea_marker": ("navigation markers in the harbour mouth beside the breakwater", "placed and uniformly scaled 1.0; not reachable from the route; no collision"),
    "ocean_buoy": ("buoys in the harbour, lit at dusk", "placed, uniformly scaled 1.0; not reachable; no collision"),
    "lifebuoy": ("lifebuoys on the gatehouse face behind the spawn and on alternate crown-wall lamp poles", "placed flush, 2.6 m or more above the deck they face; no collision"),
    "old_tyre": ("quay fenders hung on the quay faces below deck level", "placed on faces below the deck edge, rotated upright; inside the respawn band; no collision"),
    "street_lamp_02": ("wall lamps on the gatehouse corners and on five lamp poles along the crown wall", "placed 3.6 m and higher; the poles are untextured kit boxes; an omni light beside three of them; no collision"),
    "Barrel_01": ("a barrel cluster on the apron outside the yard's right-hand wall", "placed outside reach; random yaw from a fixed seed; no collision"),
    "rollershutter_door": ("four doors in the gatehouse face behind the spawn", "only the plain node is shown (the graffiti node is hidden); doors sit inside the gatehouse collision face"),
    "concrete_road_barrier": ("a row of road barriers on the apron behind bend two's outer wall", "placed outside reach; no collision"),
    "industrial_sunset_02_puresky": ("the dusk sky and its ambient light", "panorama sky, rotated in the environment so its sun matches the scene's sun"),
}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--api", type=Path, required=True)
    args = p.parse_args()
    log = {Path(e["file"]).as_posix(): e for e in json.loads((args.api / "download-log.json").read_text())}
    assets = []
    total = 0
    for asset, (use, mods) in USE.items():
        record = json.loads((args.api / f"{asset}.api.json").read_text())
        info = record["info"]
        kind = {0: "hdri", 1: "texture", 2: "model"}[info["type"]]
        folder = {"hdri": "sky", "texture": f"textures/{asset}", "model": f"models/{asset}"}[kind]
        files = []
        for path in sorted((KIT / folder).rglob("*")):
            if not path.is_file() or path.suffix == ".import":
                continue
            rel = path.relative_to(KIT).as_posix()
            # the download log keys files by the path inside the download folder.
            key = f"{asset}/{path.relative_to(KIT / folder).as_posix()}"
            up = log[key]
            assert up["sha256"] == sha(path), f"{rel} differs from its download"
            total += path.stat().st_size
            files.append({"file": rel, "upstream_url": up["url"], "upstream_md5_api": up["md5"], "sha256": up["sha256"],
                          "bytes": up["bytes"], "modified": False})
        assets.append({
            "id": asset, "name": info["name"], "kind": kind, "authors": info["authors"],
            "source_page": f"https://polyhaven.com/a/{asset}", "api_files": f"https://api.polyhaven.com/files/{asset}",
            "licence": "CC0-1.0", "licence_page": "https://polyhaven.com/license", "retrieved": RETRIEVED,
            "physical_size_mm": info.get("dimensions"), "resolution": "1k jpg (textures, model textures) / 2k hdr (sky); larger upstream sizes not downloaded",
            "use": use, "in_game_modifications": mods, "files": files,
        })
    manifest = {
        "kit": "Spillway R15 Breakwater kit",
        "publisher": "Poly Haven (polyhaven.com), primary publisher; every asset CC0-1.0",
        "verification": "each file's md5 matched the poly haven api at download; sha256 recorded then and re-checked here; files are unmodified upstream bytes",
        "licence_text": "licences/CC0-1.0-legalcode.txt",
        "shipped_bytes": total, "shipped_mib": round(total / 2 ** 20, 2),
        "assets": assets,
    }
    (KIT / "MANIFEST.json").write_text(json.dumps(manifest, indent=1) + "\n")
    print(f"{len(assets)} assets, {sum(len(a['files']) for a in assets)} files, {total / 2 ** 20:.2f} MiB")


if __name__ == "__main__":
    main()
