# Windows binary sharing proof

The official Godot 4.7.2 x86-64 Windows executable ran headlessly under portable Wine 10.0 on the laptop, with `OS.get_name() == "Windows"` and the release-template feature enabled. Both supplied recordings passed real sharing-service export/import in both directions with Linux. This is Windows PE execution under Wine, **not native Windows, gameplay, rendering or feel proof**.

## Verified preparation

Source services were frozen at `9d90885e9bacc6f3b17311545f845bc7b83f2de9`. The tiny data-fixture PCK contains byte-identical committed `r19_ghost_share.gd`, `r16_run_reader.gd` and `r16_ghost.gd`, plus a test host, boot scene and minimal project settings. It is not a full game export. The host supplies identity/session fields from the recording, not a replacement parser or a game completion.

Evidence root: `/tmp/r19-windows-proof/verified-final/`. `summary.json` records commands, runtime/PCK hashes, resource checks and limits; `fixture-manifest.json` records every source hash. `independent.json` holds the Python reader's results. Each `case-N/{linux-export,windows,linux-import}/` holds its `report.json`, execution log and actual exported `.spillghost`. These are local scratch artifacts, not shipped files.

| Input | Kind | Time | Ticks | SHA256 of sealed raw bytes |
| --- | --- | ---: | ---: | --- |
| `/tmp/r19-ghost-share/native/cross-earned.r16run` | earned R16 LOOP FIXTURE, not whole-map completion | 7.9375 s | 1058 | `14da1367fa4cfda3724a0545ce09bd38ebedf805e39b422c7ae2a4fc7a5885b0` |
| `/tmp/r19-tether-integration/final/recordings/tether-yard_server128_20261109-225859_113_a3c61251.r16run` | completed Tether Yard source-course recording; no new movement run in this test | 13.0390625 s | 1728 | `e3c3d126005fd8eb785b4c8222d243366534798282ab8ddfd5e68b0a11640026` |

The Windows stage passed 28 checks per input. Linux export and return-import stages passed 24 and 27 checks respectively. The harness compares each stage against the independent committed Python reader for raw SHA256, run ID, full motion identity, finish time, tick count and binary hashes of every decoded tick and input column. The Linux and Windows summaries also match each other exactly.

The actual service:

- exports `Jindra Žluťoučký` through `export_best`, preserving the sealed raw bytes, identity and time;
- imports the other platform's envelope through its scanner and selection service, loading the actual nonphysical ghost;
- restores the selected friend and Unicode player name from its saved preferences;
- refuses a different game build with `Different game version` and a changed expected geometry with `Different map revision`;
- rejects five malformed envelope cases, four truncated raw cases and a corrupted hash chain without crashing;
- resolves the default Windows release folder beside the actual executable and sends that canonical path to an injected opener. No file manager is launched.

No recording build/version was rewritten. This test does not drive the pause menu, race the ghost, validate an entire map's movement or establish native AMD behavior.

## Runtime and portable Wine provenance

`tools/package-r19.py` inherits these official pins from `tools/package-r16.py`; the runner constants were checked against those files with Python AST parsing:

| File | SHA256 |
| --- | --- |
| Linux editor `Godot_v4.7.2-stable_linux.x86_64` | `8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e` |
| Windows normal release template, the executed engine | `d34d36f3be1a6c49c56525ae86469b92e4f417ddf0b43cf00dd80c385c4b0562` |
| Windows console wrapper, hash-checked, not the engine itself | `52bdcae9068e8d23b840e5c63b0c1798ffe2cb66144e5c4bc7af11fb8c8600df` |

The final verified fixture PCK is `4899021df332de5f5d858c3c2b0e69a2a4e932d07f4e50a72dba353fcfcd1cfd`. Service source hashes are in `verified-final/fixture-manifest.json`; the test itself is also hashed there.

Primary sources read before execution:

- [Kron4ek Wine-Builds README](https://github.com/Kron4ek/Wine-Builds): standalone use, architectures, dependencies and compilation provenance.
- [Wine 10.0 release](https://github.com/Kron4ek/Wine-Builds/releases/tag/10.0) and its `sha256sums.txt`: `wine-10.0-amd64.tar.xz`, 65,094,660 bytes, SHA256 `a2b6ae3253736a13162c7c505f69b1c6076432c3ba64b54e1b923613ebdab698`.
- [Build-script MIT license](https://github.com/Kron4ek/Wine-Builds/blob/master/LICENSE) and [Wine 10.0 license](https://github.com/wine-mirror/wine/blob/wine-10.0/LICENSE): Wine binaries are LGPL 2.1 or later; the script repository's MIT license does not replace that.
- [Godot PCKPacker](https://docs.godotengine.org/en/stable/classes/class_pckpacker.html), [command-line documentation](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html), and [exact 4.7.2 startup source](https://github.com/godotengine/godot/blob/4.7.2-stable/main/main.cpp), especially the `OVERRIDE_PATH_ENABLED` gates.

The latest portable Wine release, 11.21, was inspected first. Its archive expands to 845,216,171 bytes, exceeding the 750 MiB cap before prefix creation. It was never unpacked or executed; its provenance/size rejection remains in `latest-footprint.json` and `wine-release.json`. Its downloaded archive was removed from this task's scratch. The 10.0 archive's x86-64 subset is 357,533,865 bytes. Only this subset was unpacked, excluding `i386-*` and the 32-bit `bin/wine`/preloader; it is a bounded 64-bit test setup, not a general-purpose Wine installation.

`wine64 --version` returned `wine-10.0`. The loader SHA256 is `91dfdd714f2c9078f010341346196d426e81c633ca0865cf7cc678e2825562db`. `ldd` found existing system libraries; no system package or desktop configuration was changed. Initialization reported the omitted 32-bit `rundll32.exe`; subsequent actual x86-64 Godot/service execution passed. No installer or user software ran.

## Repeat the preparation

Run from `projects/foldrunner`, with the existing portable Wine tree retained in scratch:

```bash
python3 tools/r19-windows-wine.py \
  --wine /tmp/r19-windows-proof/wine-10.0-amd64/bin/wine64 \
  --commit 9d90885e9 \
  --recording /tmp/r19-ghost-share/native/cross-earned.r16run \
  --recording /tmp/r19-tether-integration/final/recordings/tether-yard_server128_20261109-225859_113_a3c61251.r16run \
  --name repeat-proof
```

Use a fresh simple `--name`; existing evidence is never overwritten. The runner does not download Wine, install dependencies or export a game. To test changed committed service bytes, supply their actual commit and same-build recordings instead of rewriting older recordings.

If scratch was lost, reconstruct only this task's portable dependency after checking HOME free space, `/tmp` free space and memory. The following is the verified download/extraction method, consolidated with bounds checks. It must run before any prefix exists; otherwise reuse that tree. It writes only under `/tmp/r19-windows-proof`:

```bash
python3 - <<'PY'
import hashlib, pathlib, shutil, tarfile, urllib.request
root = pathlib.Path('/tmp/r19-windows-proof')
assert not root.is_symlink()
root.mkdir(exist_ok=True)
assert not (root / 'wine-10.0-amd64').exists()
assert not (root / 'prefix').exists()
assert shutil.disk_usage(pathlib.Path.home()).free >= 15000000000
assert shutil.disk_usage(root).free >= 1100000000
available = int(next(x.split()[1] for x in pathlib.Path('/proc/meminfo').read_text().splitlines() if x.startswith('MemAvailable:'))) * 1024
assert available >= 1024**3
url = 'https://github.com/Kron4ek/Wine-Builds/releases/download/10.0/'
archive = root / 'wine-10.0-amd64.tar.xz'
urllib.request.urlretrieve(url + 'sha256sums.txt', root / 'wine10-sha256sums.txt')
urllib.request.urlretrieve(url + archive.name, archive)
sha = hashlib.sha256(archive.read_bytes()).hexdigest()
assert sha == 'a2b6ae3253736a13162c7c505f69b1c6076432c3ba64b54e1b923613ebdab698'
assert sha in (root / 'wine10-sha256sums.txt').read_text()
with tarfile.open(archive) as tar:
    members = [m for m in tar.getmembers() if '/i386-' not in m.name
               and not m.name.endswith('/bin/wine')
               and not m.name.endswith('/bin/wine-preloader')]
    size = sum(m.size for m in members)
    used = sum(p.lstat().st_size for p in root.rglob('*') if p.is_file() or p.is_symlink())
    assert used + size < 750 * 1024**2
    tar.extractall(root, members=members, filter='data')
PY
```

Keep Wine, its archive, license/provenance and prefix outside every game ZIP. The full current dependency plus all attempts/evidence was about 755 MB (720 MiB), below 750 MiB. HOME remained above 15,000,000,000 bytes. The runner checks resource bounds before every process and during it, with a 60-second maximum per fixture stage and bounded logs. It unsets X11, Wayland and desktop-session addresses; HOME/XDG/TMPDIR and the Wine prefix stay under scratch. Owned process groups and the explicit prefix's wineserver are stopped. No private X server was needed and no desktop display was touched.

## Exact final Windows ZIP/PCK remains a separate check

No final R19 ZIP existed during this preparation; none was exported here. Once the parent has frozen and assembled the release, first verify the ZIP against its `SHA256SUMS`, extract the entire Windows ZIP to the parent's bounded release evidence directory, then set `r19_windows_release_dir` to that real extracted game folder and run:

```bash
python3 tools/r19-windows-wine.py \
  --wine /tmp/r19-windows-proof/wine-10.0-amd64/bin/wine64 \
  --release "$r19_windows_release_dir" \
  --name final-release
```

The `--release` argument is mutually exclusive with `--commit`; it accepts no recording arguments. It checks the existing PCK against `BUILD.json`, the normal EXE and console wrapper against the official pins, and BUILD.json's runtime member pins. It runs the unchanged Windows EXE with its unchanged adjacent PCK, headless startup verification, recording/persistence off and a private profile. It never creates a fixture or loads source service scripts in this mode. A missing release was tested and failed closed in `no-source-fallback/summary.json`. **Successful final-release startup is still unverified** until that actual artifact exists. Release mode reports `sharing_executed: false` even when startup passes.

Why the limit: the official Windows template rejects `--main-pack` and clears external `--script` when compiled without path overrides (`main.cpp` at the pinned tag). Changing to a custom engine or silently injecting the fixture into the final PCK would test different bytes. Full final-package friend-menu sharing and native Windows remain separate acceptance. The earlier verified fixture proves the committed data/service path on the official PE; it does not close those final-package checks.

Retained failed attempts:

- `attempt1`: actual PE rejected `--main-pack`; switched to an adjacent PCK.
- `attempt2`: external `--script` is disabled; the incomplete fixture lacked a packed boot scene/cache, was stopped at its 60-second bound, and retained its log. The completed fixture boots its own packed scene.
- `attempt3`: all service stages passed; text-serialized column hashes differed for Tether Yard. Replaced that comparison with little-endian decoded column hashes, also checked by Python. `attempt4`, `verified` and `verified-final` pass.

Major decisions are appended to `/home/thatmike1/foldrunner-build-2026-11-05/look/decisions.tsv`. No second agent reviewed them because this task explicitly forbids children; this report makes no independent-review claim.
