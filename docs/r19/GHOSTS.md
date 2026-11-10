# Sharing a ghost in R19

Finish a clean run on the desired map and preset. In Esc, expand **Race a friend (ghost files)**, enter your player name and press **Export my clean best**. Send the resulting `.spillghost` file to your friend. They put that file in their **ghosts** folder, reopen Esc or press **Refresh**, then choose its player/time button. **Open ghosts folder** opens the exact folder printed in the menu. The printed folder path is a read-only selectable field, so it can be copied when the OS folder opener fails. There is no network or upload feature.

Release builds use `ghosts/` beside the executable, on Linux and Windows. Extract the whole release into a writable folder. An unwritable release folder reports a failure rather than silently moving files elsewhere. Source/editor runs use isolated `user://r19_ghosts/`; they never create a ghosts folder beside the Godot editor. Selection/name and a private replay cache live in `user://r19_ghost_share/`. These are separate from `r16_runs/` and the local-best profile.

Export uses the fastest verified clean recording for the exact current motion identity recorded by `spillway-2026.11.09-r19`. A faster older local PB does not block a new R19 export: the service searches the recordings folder for the fastest current-build finish without changing the local PB. The wrapper preserves the sealed `.r16run` bytes exactly. A local recording from R18 can still race on unchanged geometry under the original time identity, but cannot be exported as an R19 recording. Style/scoring identity remains separate from time/motion identity.

Imported rows show the player, validated time, map/preset and compatibility note. Different game builds, unsupported schemas, changed map revisions and different movement identities are disabled. Breakwater's new geometry retains the explicit older-ghost explanation from `map_revision_description()`. A different preset can be selected on its own matching course. An invalid neighboring file never prevents valid rows from appearing.

One friend is chosen at a time. The choice survives restarting a run or the app. Changing map/preset suspends an incompatible friend and restores the local best; returning to its exact identity restores the chosen friend. **Race my local best** clears that choice. G controls whichever ghost is racing. Imported runs never replace local bests, local recording pointers, or style records. HUD and pause text name the chosen friend. File controls start collapsed so the map chooser stays near the top; the selection and map-revision warning remain outside the disclosure.

## Data and bounds

The format is identical on Linux and Windows. All imported content is data: JSON metadata and fixed little-endian recording bytes. No resource, script, packed scene or Variant deserializer is used. Hashes detect damage, not cheating or authorship.

| bytes | content |
|---|---|
| 0–7 | ASCII `SWGHOST1` |
| 8–11 | little-endian unsigned metadata byte count |
| 12–15 | little-endian unsigned sealed recording byte count |
| next metadata bytes | UTF-8 JSON object: `format: "spillway-shared-ghost"`, `schema: 1`, `build`, `player` |
| remainder | exact sealed R16 recording bytes, no trailing data |

Names are 1–32 characters; control and directional override characters are refused on import. Metadata is at most 4 KiB. A recording is at most 4 MiB stored, 12 MiB cumulative decoded chunk payload, 80,000 ticks and 512 chunks. The existing strict reader then validates its format, complete hash chain, tick columns, seal counts and clean zero-respawn finish. The motion identity must carry every existing identity field, have the supported format, and agree with the actual tick rate. Export and selection validate against the current identity again.

A friend-folder scan visits at most 1,024 directory entries, lists at most 64 ghost files and reads at most 16 MiB. The explicit export fallback examines at most 512 local entries and 64 MiB of stored recordings; reaching a limit refuses export rather than calling a partial search the best. Scanning happens at startup, opening Esc, Refresh and export. Changed identities suspend immediately, with file loading deferred outside physics. The rendering path only uses already loaded poses. Selectable filenames come from that folder scan, never from metadata paths; symbolic-link files and arbitrary external selection paths are refused. A file changed after scanning needs Refresh. Export names use a random 96-bit suffix and refuse an existing target. Replay cache names are SHA-256 hashes; conflicting unknown bytes are refused instead of overwritten.

## Verification

The final input refresh passed 121 headless checks and 121 native AMD/X11 checks, including actual Unicode name typing, selection, Backspace, focused-field shortcut isolation, and the faster older local PB regression. Esc and F1–F12 remain global; letters and editing keys in the two ghost text fields reach the GUI before game shortcuts. The native renderer held `/dev/dri/renderD128` and accumulated hardware graphics time; the observed desktop socket/server baseline stayed identical. The multi-host fixture logs eight ObjectDB instances at shutdown; this is disclosed rather than called a clean normal-release Quit. Final release lifecycle checks remain separate.

From `projects/foldrunner`:

```sh
python3 -I tests/r19_ghost_share.py
python3 -I tests/r19_ghost_share.py --native
python3 -I tests/r19_ghost_share.py --native --desktop-unavailable
```

The runner verifies the pinned Godot 4.7.2 binary, copies source into `/tmp/r19-ghost-share/source`, isolates XDG state, imports there, runs the actual R19 host and drives its real menu buttons through Enter input events. Tests drop actual wrapper files into its canonical test folder. The folder opener is injected and records the requested path; tests never invoke the production `OS.shell_open` action. The runner checks source hashes after execution and keeps scratch below 350 MiB. It checks `/home` has at least 15,000,000,000 bytes free before launching. No release export is built by this runner.

Headless evidence is in `/tmp/r19-ghost-share/headless/`: `summary.json`, `suite.log`, `SOURCE.json`, `python-reader.json` and the exact extracted `cross-*.r16run` files. Synthetic sealed fixtures cover names, two motion identities, malformed/bounded files, compatibility, persistence and immutable raw bytes. They are explicitly **not genuine completed courses**. A separate route earns a finish on the labelled R16 loop fixture through W/Space input on the actual R19 host/session/runner. Its recording exports through the real menu. Repeating that earned route with the selected friend must produce exactly equal position, velocity, yaw, course clock and checkpoint traces, without sharing reads/scans during the route. Both the unchanged Godot and independent Python readers decode the extracted files.

The initial native attempt on 9 November stopped before launch because `xdpyinfo -display :0` already failed. The explicit `--desktop-unavailable` option instead preserves that observed baseline: it pins the existing Hyprland and desktop Xwayland process identities, reserved socket inodes, kernel listeners and answering status before and after. It never repairs, restarts or renames the desktop server or sockets. The original native helper still uses only verified free displays 190–199 and its AMD driver checks; GPU observation follows the actual game PID. Without the explicit option, unavailable `:0` remains a refusal. Native Windows execution and final packed-release/full-route gates are separate checks.

Framework facts were checked against current official Godot documentation: [OS.shell_open and executable path](https://docs.godotengine.org/en/stable/classes/class_os.html), [DirAccess.is_link and iteration](https://docs.godotengine.org/en/stable/classes/class_diraccess.html), [the template feature tag](https://docs.godotengine.org/en/stable/tutorials/export/feature_tags.html), and [TextServer autowrap modes](https://docs.godotengine.org/en/stable/classes/class_textserver.html). Runtime behavior above was tested with the project's pinned binary.
