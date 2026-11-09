# R19 delivery gates

These helpers are preparation, not a delivered R19 candidate. No export or ZIP was made while preparing them. Runtime authors and final map registration must finish before the parent freezes the source. Full old-host parity has its own report; delivery does not imply it.

From `projects/foldrunner`:

```bash
python3 -B tests/test_package_r19.py
python3 -B tools/package-r19.py prepare
python3 -B tools/package-r19.py --help
python3 -B tools/package-r19.py package --help
```

`prepare` reads committed source and official engine/template hashes. It does not archive, import or export source. It can run while other authors work; its commit and hashes are a dated observation, not a final freeze. Its preservation check covers **all 1,203 pre-existing project files** from R18 commit `640d06e6539b53da752f03bfddb64fb46310abb7`. The exact allowed old paths are:

- `project.godot`
- `scripts/r16_style.gd`
- `scripts/r16_style_panel.gd`
- `scripts/r17_main.gd`
- `scripts/r18_hud.gd`
- `scripts/r18_style_panel.gd`

Deletions and other old-file byte changes fail. Freeze inputs must pin the actual SHA256 for every changed allowed file, with no extra entries. All six F2 source hashes must match outer `look/evidence/r19-baseline/SOURCE.json`, whose own SHA256 is pinned in the helper. New files do not waive preservation of any old file. The R18 delivery BUILD manifest is also hash-pinned.

## Parent freeze inputs

Commit the complete project, including these helpers and all final runtime/maps. `identity` and `package` refuse dirty project files, including untracked source.

After the commit, collect an identity without exporting a pack:

```bash
python3 -B tools/package-r19.py identity --evidence /tmp/r19-package-helpers/final-identity
```

That command extracts the committed source into temporary scratch, imports it with the pinned editor and runs the inherited map/preset identity observer. It writes `IDENTITY.json` and prints its canonical SHA256. It proves source identity only. The multi-map source fixture may log its known ObjectDB leak; it is not the clean release Quit check.

The parent writes an external JSON freeze with these fields:

| field | exact input |
| --- | --- |
| `schema` | integer `1` |
| `runtime_frozen` | boolean `true`, only after every runtime author is done |
| `source_commit` | full 40-character commit that identity examined |
| `new_maps` | explicit final new playable IDs, in intended order; an empty list is an explicit scope decision |
| `required_maps` | `breakwater`, `whiteout-relay`, `sunken-court`, `rainline`, `night-shift`, `practice`, `overflow`, `experiment`, then every `new_maps` ID |
| `experimental_maps` | explicit IDs whose titles must retain EXPERIMENTAL, including `experiment` and every new experiment |
| `intentional_changes` | exact path-to-SHA256 dictionary from final `prepare` preservation output |
| `identity_sha256` | reviewed canonical hash printed by `identity` |
| `breakwater_geometry` | exact revised `maps.breakwater.geometry` from that identity |
| `breakwater_overlay` | final element of JSON-decoded `keys.breakwater.server128.record_identity`; must start `r19-breakwater-flow-1:` |

Do not populate the required map list from discovery. The explicit list and observed catalog must agree exactly. Missing required maps, duplicate IDs, absent F2 or aliased map identities fail. Every original map and available preset remains equal to the R18 identity. Only Breakwater geometry and its overlay may differ; its motor, hull, runner, checkpoints, art, timing and preset identities remain fixed, and its record key must change. New maps receive separate identities.

Identity probes enumerate the catalog; they do not establish that a map is enjoyable or that full old-host parity passes. The surf and Experiments authors supply their own acceptance evidence.

## Exact candidate assembly after freeze

These commands are implemented but **have not been run for an R19 candidate**:

```bash
python3 -B tools/package-r19.py package \
  --freeze /tmp/r19-package-helpers/final-freeze.json \
  --output /home/thatmike1/foldrunner-build-2026-11-05/delivery/spillway-r19 \
  --scratch /tmp/r19-package-helpers \
  --home-reserve 500000000 \
  --desktop-unavailable

python3 -B tools/package-r19.py check \
  /home/thatmike1/foldrunner-build-2026-11-05/delivery/spillway-r19 \
  --evidence /tmp/r19-package-helpers/recheck \
  --scratch /tmp/r19-package-helpers \
  --desktop-unavailable
```

The explicit unavailable-desktop option is specific to the observed pre-existing unavailable `:0`. Ordinary default operation refuses that state. The unchanged `DesktopGuard` pins Hyprland and desktop Xwayland PID/start times, reserved socket inodes, kernel listeners and answering state before and after. NativeDisplay reserves a verified free display in 190–199. The inherited native runner's GPU watcher samples the **actual Godot process PID**, requires AMD render-node graphics time and rejects software rendering. No software fallback is accepted.

Preparation scratch, imports and probes stay under `/tmp/r19-package-helpers`, bounded to 350 MiB. Assembly needs at least 2.2 GB of scratch free before launch. HOME must retain 15,000,000,000 bytes plus the bounded output reserve. The default 500 MB reserve covers estimated ZIPs and evidence; final actual sizes are checked against it. Output must be new or empty and outside the repository. Existing deliveries and user data are never mutated. Failed verification can leave evidence in the requested output directory; inspect or choose another new output before retrying.

The helpers compose R16 process ownership, pinned runtimes, archive/source manifests, independent readers, raw-input/recording audits, controls, earned play, exact source trace matching, save/reload and actual local ghost checks. R18 supplies sky manifest/provenance, licence discovery, exact ZIP checks and the known clean Breakwater input tape. All invoked helper bytes are pinned in BUILD alongside the complete source manifest. The R19 audit retains R16's input/column/lifecycle/both-reader checks and uses the R19 direction/combo event schema, with live-event equality and exact totals. Unknown awards or malformed multipliers fail.

The final Linux executable runs outside loose source with the frozen source removed. Static checks require official Godot **4.7.2** Linux and both Windows runtime hashes, the common PCK hash, exact ZIP entry sets, CRC, executable modes, licences/provenance, embedded BUILD metadata and SHA256SUMS. Pack inspection rejects private `look/` concepts, docs, tests, tools, loose scripts and override configuration. Missing pack, malformed pack and missing critical sky must return nonzero. The sky negative also runs with `--look=old`; an error log followed by exit zero does not pass.

Normal uninstrumented startup must print the full R19 build identity. Instrumented startup and Quit run independently from the multi-map controls fixture and reject ObjectDB leak warnings. R19 scene identity requires `scenes/r19.tscn`, `persist = true`, `record_runs = true`, project version `2026.11.09-r19`, R19→R17→R16 host inheritance and R19→R18 HUD inheritance. The legacy behavioral BUILD_ID stays R16; every observed recording header must name `spillway-2026.11.09-r19`.

Native controls exercise the complete explicit catalog, available presets, restart/practice, stage picker and inherited lab controls. Every catalog map receives the paused L toggle/material/light restoration and unchanged collision/state check. Telemetry starts hidden, F9 reveals it, the Look label follows telemetry/pause visibility, and Advanced is clicked open and closed. Experimental titles retain the suffix.

A clean earned recorded route and a separate-process reload check default recordings, exact best payloads and the real local ghost. The packed R19 friend check clicks Open ghosts folder, Export, Refresh, the imported friend and Race my local best. It wraps the earned recording, drops same-version and wrong-version files in the portable folder beside the executable, requires visible names/times and a disabled version-mismatch row, checks the selected friend's interpolation and absence of collision, and restores local-best selection. Only the external file-manager launch is intercepted; the button and filesystem operations run. Exact preference/cache paths are audited separately; arbitrary user-data writes remain rejected.

Windows runtime/header/hash/CRC and common PCK checks are **static verification**. Reader and sharing checks on Linux prove shared-format behavior there. Native Windows execution remains **unverified** unless a later native Windows run supplies evidence. Linux success never upgrades that status.

## Preparation evidence

`python3 -B tests/test_package_r19.py` passes 16 focused tests: freeze refusal, required-map omission, preservation boundary and exact intentional hashes, disk/scratch/output refusal, original map/preset identity, manifest/reference rejection, ZIP CRC/modes/private entries, all four pack-negative cases, R19 style bounds, unchanged friend preferences/arbitrary-path refusal, unavailable-desktop refusal and honest Windows notes. Archive fixtures use in-memory bytes; no ZIP artifacts are written.

The pinned editor parsed `tools/r19-pack-probe.gd` in an isolated imported snapshot. The source identity smoke enumerated the current eight maps and passed the full original map/preset boundary with the explicit Breakwater revision. Logs and identity are under `/tmp/r19-package-helpers/`. Scratch was about 199 MB after identity. A later source-editor AMD controls fixture passed the new Advanced/F9/L checks, with GPU work and unchanged desktop receipts, but reported 33 failures around embedded stage pickers and dependent lab checks. This is not a passing release result. The release HUD forces native popups under `template_release`; whether that resolves these source-editor failures must be checked on the eventual exact pack. No acceptance checks have been removed. These observations precede surf/Experiments integration.

An earned headless source run passed **93 checks**, including the new friend-button probe, with explicitly isolated profile/recording arguments. Its 5,768 ticks and 5,118 input events passed both readers and the strict observation/profile audit (`/tmp/r19-package-helpers/source-play-r3/audit.json`). This verifies the source fixture, not default release persistence or native Windows. The first source fixture omitted the explicit headless write opt-ins and correctly had records off; that failed run is not used as passing evidence.

## Final inventory correction

The first assembled candidate was rejected by manifest verification before native acceptance. Its preflight used `git ls-tree HEAD:./` from the nested project directory without `--full-tree`, which returned zero files. R19 now inventories the explicit committed subtree from the repository root and refuses an empty inventory or missing configured scene. The same inventory function feeds preflight and manifest verification. A real temporary nested Git repository reproduces the zero-file command and verifies all expected project resources through the corrected function. The helper suite now passes 17 tests; the original 16-test preparation receipt remains historical. Earlier identity captures made with an empty committed-resource list do not prove resource coverage. A fresh full-inventory identity and candidate are required.

The second candidate passed exact packed startup (80 checks) and controls (1,574 checks), including the original stage-picker/Lab assertions that had failed in the earlier editor fixture. This proves the release controls; the reason for the editor-only difference remains unproven. Its play probe then failed four friend-button assertions because it tried hidden controls without opening the R19 disclosure. The probe now opens and closes **Race a friend** with actual GUI clicks, checks the default collapsed state and real preference output, and retains the physical-state and recording checks. No runtime change or acceptance waiver was made. This rejected attempt remains separate from any later complete release.

The delivery review also found that a freeze could omit the entire new Experiments wing. Validation now requires three to five distinct new experiments plus a separate regular course, retaining Movement Lab independently. Tests refuse zero, two, six, old-map substitutions and a missing regular course, and accept three and five. Exact packed controls additionally check every card's actual main/Experiments parent and the visible section heading. The helper suite now passes 18 tests. Final evidence must come from a new committed candidate with these checks.
