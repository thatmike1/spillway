# Spillway R20

All six requested items are implemented. Verified Linux and Windows ZIPs are in `delivery/spillway-r20/`. Both `feat/spillway-r20` and `feat/foldrunner-me-build` now point to `e6baa995d`.

## Try first

1. **Saltglass, F2:** stay high on both fins and follow the climbing crescent. Failed surfs fall back to the last checkpoint.
2. **Backwards hops:** protect a long chain, watch pending style grow, then finish the chain while fast to bank it. A stall loses pending points.
3. **Experiments → Tether Yard:** hold left mouse to attach, add right mouse to reel, release left mouse to detach. Compare Classic, Pendulum and Elastic in the pause sheet.
4. **Experiments → Through Line:** carry speed through the raised fork, fly onto Second Run and keep moving.
5. **Pause → Export my runs:** send the resulting ZIP manually. Nothing uploads automatically.

Desktop review launcher (temporary RAM copy):

`/tmp/spillway-r20-review/playable/SpillwayR20-linux-x86_64/SpillwayR20.x86_64`

This copy disappears after reboot. Durable ZIPs remain in the laptop delivery above. The persistent desktop mirror was refused before copying because desktop `/home` was already below the 15 GB floor; no user files or earlier deliveries were removed. The RAM handoff is bounded to 600 MB, with its actual status in [the handoff receipt](evidence/r20-desktop-ram-copy.json).

## What changed

**1. Saltglass.** The free spawn-to-tail connection is physically removed. Both fin entries are above 15.2 m on 18 m fins, the crescent climbs, exits are flat decks, and the safety platforms below the fins are gone. An input-earned F2 line takes **62.046875 s**; a separate native line takes **63.25 s**. Their old/new and saved-input replays match. Controlled early departures fall and respawn. These are exercised routes, not a fastest-line result or proof against every possible skip. [Course notes](r20-player-reference/SALTGLASS.md).

**2. Directional stacks.** Backwards and sideways chains accumulate uncapped pending style. Twenty eligible hops earn **30,400 backwards** or **9,500 sideways** points. A normal fast ending banks once; stalls, restarts and attempt boundaries lose pending. Pause suspends the chain. R19's anti-farm rules remain. Mike's recordings showed repeated awards, with strict flight eligibility and re-arming interrupting specific chains, rather than a universal once-only bug. [Exact rules](r20-player-reference/STYLE.md).

**3. Mouse grapple.** Left mouse holds the rope, right mouse reels while attached, and both reproduce inherited Classic E behavior. The pause sheet persists manual/automatic reel and Classic/Pendulum/Elastic. Release left mouse to detach. Minimum rope length stops reeling, not attachment. Classic expires after three seconds, alternatives after five; range and sustained obstruction also release, with visible and generated sound cues. Automatic release requires a fresh press. Ground reel retains the pull-under-the-anchor behavior; jump to lift. Alternative laws apply only in Tether Yard. [Release and rope rules](r20-player-reference/TETHER.md).

**4. Shelving.** Line Drive and Fall Line are absent from selection; their code remains. [SHELVED.md](r20-player-reference/SHELVED.md) preserves Mike's feedback about pad feedback, unclear landings, collapse feedback/timing and a theme for any revival.

**5. Through Line.** Two authored segments remain physical in one scene. Crossing the raised fork forward at 230+ u/s adds upward speed while retaining exact horizontal velocity. Shape, generated sound, a screen cue and static trajectory examples mark the launch. Exercised entries at 243/504 u/s rise 5.53/9.48 m and travel 7.63/22.91 m before landing on the second segment. Scene, player, attempt and clock continue. Numeric continuity and landings pass; **human seamless feel and listening are untested**. [Launch notes](r20-player-reference/THROUGH-LINE.md).

**6. Friend-run collection.** Export packs every local attempt and settings into one named ZIP. It flushes buffered input without ending the current attempt or banking pending style. Folder opening has a selectable-path fallback. The standalone [collector kit](r20-collector-tools/README.txt) ingests ZIPs per player and analyses complete, partial, aborted, corrupt and unsupported attempts separately. Nothing uploads automatically. `.spillghost` racing remains separate. [Export notes](r20-player-reference/RUN-EXPORT.md).

Windows recordings: `%APPDATA%\Godot\app_userdata\Spillway\r16_runs\`. Settings are beside that folder. This path is also in both portable READMEs.

**No requested item was omitted.**

## Verification and limits

[The playtest analysis](../playtest-r19/ANALYSIS.md) strictly read 90 files, excluded 32 inherited copies by hash and analysed exactly 58 new F2 attempts. Input/settings integrity was preserved. Missing contact, rope and sensory information stays labelled unknown or inferred.

Original-map parity passes **48 fresh plays across sixteen routes and eight maps**, with two complete committed audits, 98 candidate controls, 56 original controls and ten actual-snapshot tests. Binary physics/input comparisons retain no tolerance exceptions. The interrupted capture wrapper's final exit is unknown; both subsequent full audits have zero-exit receipts. The parent rehashed all 1,601 inventory-listed evidence files before verified archival.

The final ZIPs pass **2,805 native AMD/X11 checks**, four nonzero broken-package refusals, CRC/hash/official-runtime checks and 33 licence/provenance checks per ZIP. Both contain the same verified PCK. Visual-state checks pass 2,068 assertions across eleven maps. The exact Windows ZIP starts all eleven maps under Wine. Separate Windows-PE export-service checks preserve bytes and Unicode across Linux ingestion.

**Native Windows play, physical latency, listening and human enjoyment remain unverified.** Wine startup is not a Windows GUI or full-game playtest. The selected native frames do not establish seamlessness.

Game artifacts are frozen at `7f8fb41b7`. The later `e6baa995d` commit repairs only the Windows verifier, its tests and delivery notes. All 564 game-runtime files and 26 parity helpers are byte-identical. The repaired gate redirects engine logs to evidence and still rejects all writes to game data. [Independent review](REVIEW-R20-WINDOWS-GATE.md) found no blocking issue. Artifact source and verifier revision remain separate in the receipts.

[SHA256SUMS](../delivery/spillway-r20/SHA256SUMS), [build metadata](../delivery/spillway-r20/BUILD.json), [native verification](../delivery/spillway-r20/VERIFICATION.json), [parent audit](evidence/r20-final-acceptance/PARENT-AUDIT.json), [Wine proof](evidence/r20-windows-gate-repair/windows-release/RESULT.json) and [promotion receipt](evidence/r20-final-acceptance/PROMOTION.json) record exact identities and limits. Earlier failures remain labelled. Owned generated proof was archived only after file-by-file and remote hash verification; deliveries and private playtest inputs were preserved. Decisions are in [decisions.tsv](decisions.tsv).

## Five calls for Mike

1. Does Saltglass reward staying high, and do remaining skips feel earned?
2. Is a long backwards stack worth protecting?
3. Are Classic's mouse controls and release rules predictable?
4. Which alternative grapple model is worth keeping?
5. Do Through Line's launch, landing and transition feel continuous?
