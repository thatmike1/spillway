# Every local attempt, sent manually

Pause and use **Export my runs**, directly under the recording note and above the map/settings sections. Enter a player label, then send the clearly named `Spillway-runs-<player>-<UTC>-<random>.zip` yourself. Nothing uploads. The game opens its export folder after a successful export. If opening fails, the saved ZIP path is a read-only **selectable LineEdit** with normal Ctrl+C support and an **Open folder** retry. R/F/L editing keys cannot trigger game actions while either export text field has focus; Escape and function keys keep their inherited behavior.

Windows recordings live at `%APPDATA%\Godot\app_userdata\Spillway\r16_runs\`. Settings sit beside `r16_runs` in that same `Spillway` folder. Exports normally live in its `run_exports` folder. Friends need only the game: Godot's built-in ZIPPacker writes the ZIP, without Python, a zip executable, credentials, or a network call.

## What the ZIP contains

- Every recognized recording in the **actual session recording directory**, recursively: `.r16run`, `.part`, `.aborted`, including older copies, empty attempts, restarts, quits, damaged files and unsupported versions. No recording is parsed, fixed, renamed, moved, sealed or deleted during collection.
- Exact bytes of existing `spillway_r12.cfg`, `spillway_r13.cfg`, `spillway_r15.cfg`, `spillway_r16.cfg`, and `spillway_v1.cfg` from the current user-data directory. A different active profile is included as `settings/current-profile.cfg`. `current_profile` names the actual persisted profile member, or is empty when no persisted file exists.
- `settings/effective-settings.json`, a data-only snapshot of the live game's current settings, including unsaved effective values. Export does not force a settings save. Old configs can contain old records and absolute ghost paths; they are preserved as supplied, not evaluated.
- `manifest.json`: format `spillway-run-bundle`, schema `1`, human player claim, application build, UTC creation timestamp, current profile member, and relative filename, size and SHA256 for every data member. Recordings and settings have separate roots. JSON keys and inventory order are stable; timestamp and contents describe this particular snapshot. Player labels are not authenticated identity.

Logs, shader/import caches, ghost caches, exports and unrelated files outside these recording/settings sources are excluded. Non-recording suffixes inside the recording directory are not collected. Nothing reads arbitrary paths from a bundle or evaluates ConfigFile, Resource, expression, code or Godot Variant contents during ingest.

## An open attempt remains open

`export_my_runs(label)` accepts only a paused game. The new service's `flush_open_attempt(recorder)` explicitly calls the frozen recorder's existing `_flush_ticks()` method. That method writes and flushes buffered samples, input rows and events without sealing or closing the attempt. The recorder source, original readers, motor, session, scorer and map sources remain unchanged by this item.

Collection is synchronous while gameplay is paused, without an engine-frame yield. The `.part` snapshot is genuinely partial. Pending session inputs and directional stacks stay in place; export does not create a restart, score, finish, pause or resume boundary. The ordinary pause/resume lifecycle still belongs to the game. A failed recorder flush reports the existing recording error and leaves its partial file intact.

## Bounds and I/O

Writer and ingester allow **4,096 data files, 64 MiB per data file, 512 MiB total data, 1 MiB manifest, and 240 UTF-8 bytes per portable relative name**. Recording-tree scanning also caps entries at 4,096 and nesting at 12 levels. Case-colliding, unsafe and linked sources fail collection. Limits cause an explicit failure; there is no first-N export or silent list truncation.

Shipping export checks the **destination volume**, using a conservative full-data/header estimate plus **16 MiB safety margin**. Friends do not need 15 GB free on HOME or their Windows user volume. The component verification harness separately maintains this build machine's HOME floor of **15,000,000,000 bytes** and 350 MiB per proof directory. Its receipt records resource readings; it runs one engine at a time.

Sources are streamed and hashed in **64 KiB chunks**, checked again while writing, and inventoried and hashed again before publication. The ZIP uses level-zero stored Deflate blocks; the recording payloads already contain compressed chunks. An independent bounded streaming pass reads those RFC1951 stored blocks from the actual closed archive, verifies every payload SHA256, and checks matching local headers, central directory and end record. This extra pass is necessary: pinned Godot 4.7.2 reported `OK` under an actual OS file-size limit despite a truncated ZIP. No full recording or archive is buffered by the export service. Metadata/manifest allocation is bounded separately. All ZIPPacker operations are checked. A failure removes only this operation's `.zip.partial`; a completed file is published by rename only after verification.

The ingester also caps the ZIP at **520 MiB**, central directory at **4 MiB**, and member count at **8,193**, including structural directories. It accepts only exact manifested files and optional parent directory entries implied by them. Before publishing it rejects extra/missing members, duplicate/colliding names, traversal, absolute/drive/backslash/control names, symlinks and other special files, encrypted or unsupported compression, malformed/duplicate-key/nonfinite manifests, CRC failures and size/SHA disagreement. Extraction uses bounded reads and exclusive file creation, never `extractall`. Its developer-only HOME floor and an import-volume estimate are explicit preconditions.

## Manual ingest and analysis

Verified CLI surface, from this project:

```bash
python3 -I tools/ingest-r20-runs.py --help
```

Pass the received ZIP as the positional argument, `--player` as the collector's explicit player label, and `--output` as the collection directory. The actual positive command is recorded in the component evidence's `COMMANDS.json` and `CLI.json`.

Each player gets a label-plus-hash folder, each distinct ZIP a SHA256-named session folder. Exact duplicate ingest revalidates all supplied member bytes and CRCs, checks the existing imported originals, and overwrites nothing. A changed existing session is refused. `import.json` preserves bundle hash, raw manifest hash, every original hash, analysis hash and a canonical import-receipt hash. Different sessions stay separate even when some old recordings were copied between them; per-attempt hashes expose that overlap. Identical payloads inside one bundle get `duplicate_of` links and count once in group exposure/outcomes; every original filename, byte and per-file classification remains preserved.

The existing **original strict R16 Python reader and analyzer** process each recording. `analysis.json` keeps per-attempt status/classification, errors, outcome, timing, exposure, input/style totals, spatial summaries and the original analyzer's useful speed-loss sections. `ANALYSIS.md` summarizes each **source build + full recorded motion/map identity + preset** group. There is no cross-version leaderboard.

Classifications are separate: `complete` (sealed, including valid zero-sample data), `partial` (honest recovered prefix), `aborted`, `corrupt`, and `unsupported`. A sealed restart/quit is not a successful finish. Invalid recordings remain exact original files. Missing tails, true outcomes of partial attempts, player intent, causes of speed loss and enjoyment remain unknown. Stall means observed horizontal actual speed below 1 m/s, including idle spawn; paused wall time is unobserved. Speed-loss summaries explicitly retain the original analyzer's top-12-per-attempt limit. Per-map summaries show observed exposure, outcomes/restarts, respawns, low-speed time, style kinds/points and reported loss sections.

Before invoking the old analyzer, an envelope scan bounds decoded recording data at **64 MiB per attempt / 512 MiB per bundle**, **131,072 sample ticks**, **524,288 input rows**, and **8,192 chunks**. Unsupported analysis expansion is reported while original bytes remain preserved. Invalid/nonmonotonic or excessively wide tick domains cannot drive the old analyzer's tick-range loops. Nonfinite/malformed recording data is reported, never evaluated.

## Reproduce and parent integration

The complete sequential component command is:

```bash
python3 -I tests/r20_run_export_check.py --out /tmp/r20-run-export/recheck --private-source /home/thatmike1/foldrunner-build-2026-11-05/playtest-r19/userdata-spillway
```

Use a fresh output directory. Omitting `--private-source` runs only disposable autoplay/generated fixtures. Private proof uses a collection-source seam, never constructs a live recorder on Mike's directory, compares every source hash before/after, and removes its private ZIP/import duplicates in `finally`. Only hash/classification receipts survive. Generated fixtures are safe to retain. The accepted attempt and any rejected predecessors are explicitly identified in the outer component contract.

Production API in `scripts/r20_main.gd`:

- `run_export`: service instance; construction performs no writes.
- `run_export_directory`: default `user://run_exports`; test override before scene startup is allowed.
- `run_export_folder_opener: Callable`: injectable `(absolute_folder: String) -> Error`; absent in production means `OS.shell_open`. Every component fixture injects it.
- `export_my_runs(label: String) -> Dictionary`: paused-only flush, collection and folder-open result; also updates `last_run_export`. Successful fields include `ok`, `path`, `folder`, `files`, `bytes`, `manifest`, `folder_opened`, `message`; failure includes `ok=false`, `error`.

HUD fields: `export_button` (`ExportMyRuns`), `export_name`, `export_status`, `export_path`, `export_open`. `RunExport` sits directly after `recording_line`. Both export fields extend the inherited text-focus safeguard. Existing Tether/Through controls, R18 cream/ink sheet, L/F9 and gameplay remain inherited.

For parent native/Wine verification, `tests/r20_run_export_native.gd` drives the same earned Through route, clicks the actual export button with a synthetic GUI event, checks all results with an injected opener, takes a naturally rendered paused-result frame only with a native display, then resumes and finishes. Run with the parent's verified private graphics environment using the same engine arguments as the headless command in evidence, replacing the script with this native seam and omitting `--headless`. `--out` must name a disposable absolute directory. On Windows use its pinned Godot 4.7.2 executable and Windows absolute output path. No file-manager window or clipboard operation is required. Native rendering/feel and final packed Linux/Windows release acceptance belong to the parent.
