# Spillway R21

**R21 is published, and both release branches point to `dee210165`.** The exact verified Linux and Windows ZIPs, with `SHA256SUMS`, are in the spec's outer `delivery/spillway-r21/`. The final proof archive and ZIP companions are verified on the trusted backup. Windows verification covers startup under Wine on all eleven maps, not native Windows play. [Final release report](evidence/r21-final-publication/REPORT.md).

## Try first

1. **Saltglass, F2:** enter each fin high, then take a lower exit line onto the flat deck. Carry the surf speed across the pans. At the salt store, compare the inland route with the outside curve over water.
2. **Experiments → Tether Yard:** start with Elastic and assist on. Watch “Next” and the matching anchor ring before holding LMB. Release LMB to coast; RMB reels. Compare Soft, Firm and Arc from the pause sheet, then compare assist off.
3. Return to a familiar original map. Through Line and backwards-stack rules are unchanged.

## What changed

**Saltglass:** the two post-fin flat exits are now 7 m high, down from 14 m, with five metres of open water after the fin. The second fin moves farther away, with ascending pans leading to its high entry. The quay adds an inland route, a salt store and a harder outside receiving lip that must lead into another hop. Pumps, racks, moorings, louvres and a canopy fill out the place without decorative collision.

One configured-source F2 line finishes cleanly in **64.4765625 s**, with no respawn. It reaches the first flat supports at about **987 u/s**. Matched fixtures show that the lower deck makes a faster low line usable; taking the same high line changes speed little. This is one exercised line, not a fastest-human result. Both fin entries remain about 15.27 m high on 18 m fins. Bail and reverse probes fall; they do not prove every earned skip impossible. [Dimensions and checks](wt/projects/foldrunner/docs/r21/SALTGLASS.md).

**The outside-line pattern:** Mike’s Breakwater curve already earns **gap +2328** in one recording and **gap +2695** in another. It goes around the second crane-line container stack on the harbour side when travelling west. Neither recorded flight meets the existing near-miss distance. Breakwater and scoring stay unchanged.

Saltglass deliberately uses that landing → takeoff → outside curve → receiving landing pattern. A local fixture reaches the same downstream plane in **1.9921875 s outside versus 3.1875 s inland**, then lands, jumps and lands again. It earns existing generic gap/near-miss events. No location bonus was added. The full-course finish uses the inland route; the separate outside fixture starts at rest on a real quay pan. [Line and reward evidence](wt/projects/foldrunner/docs/r21/OUTSIDE-LINES.md).

**Tether Yard:** original Classic, Pendulum and Elastic force laws remain the references. Soft lowers outward damping from 10 to 6; Firm raises spring stiffness from 90 to 120; Arc slows reeling from 260 to 180 u/s. [Research and sources](GRAPPLE-RESEARCH.md) were published before implementation. The unequal playtest cohorts support measurements, not a conclusion about why Elastic feels better.

Elastic-family assist uses an 18° acquisition cone and 22° retention cone, with range and eye/hull visibility checks. It publishes one stable physics candidate. The HUD shows “Next” only when that candidate is ready. It does not steer the player or camera. Classic and Pendulum keep their original aim and mouse bindings.

Replaying three original human recordings reproduces all **3,807 position, velocity and view samples** and confirms front-face contacts at the first transfer and dispatch decks. Isolated component comparisons show the selected contacts disappearing when those decks are lowered. First transfer is now 3 m high and dispatch 2.25 m; spawn and the other transfer remain at 4 m. [Mechanics, clearance evidence and limits](wt/projects/foldrunner/docs/r21/TETHER.md).

**The rest:** Through Line, backwards-stack rules, F2 and the original eight maps remain inside the R20 preservation boundary. No requested gameplay item was dropped. Full source parity and every exact-package functional check pass on current `dee210165`. The package and eleven-map Wine startup checks pass, and the exact artifacts are published.

## Checks and limits

The [analysis](../playtest-r20/ANALYSIS.md) strictly reads all 33 new recordings. All 38 original recording/settings files were independently rehashed unchanged. Preservation covers all 1,404 R20 project files, with only the two approved project/build-label wiring changes.

Scoped native source-editor checks cover three Saltglass cases, six grapple routes and the pause sheet at actual 1280×720 and 1920×1080. **26,179 motion rows match exactly; 88 frames were retained.** [Native evidence](evidence/r21-native-final/SUMMARY.json). These are source-editor checks, not exact-package, desktop GPU, listening or human-feel proof.

The historical Tether packet used player `67953a7e` and contains 253 production checks and 373 dual-reader files. The later release-preview repair uses player `39e189c6`; it has 78 isolated component checks, six fresh native/headless route comparisons covering 8,937 rows and 54 pause checks. Those scopes are separate. [Verifier history and corrections](evidence/r21-verification-history.md).

Fresh source parity on `dee210165` passed **48 plays, 16 routes, eight maps, 144 streams and 288 exact comparisons with zero differences**, including 56 original and 77 candidate negatives. The package's mandatory full re-audit produced the same AUDIT bytes.

The exact candidate passed both ZIP static/CRC/SHA checks and four nonzero broken-pack controls. Native startup passed 81 checks and all-map controls passed **2,560 checks / zero failures**, including all ten Tether model/assist routes and strict recordings. Breakwater play/reload passed 211/100; Saltglass 218/100. Packed Saltglass/Tether/parity components passed 2/452/2. Uninstrumented startup and instrumented OS input/Quit passed; a separate uninstrumented input/Quit run was not performed. Private display 198 was released.

The terminal package command exits **0**, counting **733,517,276 bytes** against the approved850,000,000-byte cap. The first v8 Wine run failed when its prefix hit the tmpfs user quota. This continuation measured actual writable capacity:1,764,749,312 bytes on `/tmp` and at least2,411,724,800 on `/dev/shm`, deleting both probes. All6,048 prior raw hashes and both ZIP hashes matched before use.

A continuation preflight then refused the old prefix's standard Wine symlinks before launching Windows. A documented external guard adaptation counts only exact generated prefix mappings and internal links without traversal, keeps the same byte limits, and still refuses arbitrary candidate links. Seven synthetic guard checks pass. **The single subsequent Wine execution matrix passes all11maps, all commands exit0**, with matching stdout/engine logs, unchanged extracted bytes and no game-data writes. This proves Windows PE startup under Wine, not native Windows play.

Independent closure revalidated the static, parity, native, recording, component, negative-control and Wine evidence. The **356,825,685-byte** final proof archive has SHA256 `7a2c7f2ca69bb8381a765da387377ea1974a73da886b8c59ec5bf2f2809e0b99`. All **6,834 archived members and 230 ZIP references** passed full readback from the trusted backup. An additional restore recovered a stored file, a ZIP-reference file and a symlink with original metadata. Exact ZIP companions and archival metadata are also on the backup. [Archive and restore receipts](evidence/r21-final-publication/REMOTE-READBACK.json).

The capacity refusal in the earlier Wine packet is historical. The final continuation uploaded this same archive without recapturing source, repackaging or executing Wine. Guarded publication revalidated the sealed evidence and copied the same ZIPs to the original spec's outer `delivery/spillway-r21/`, rather than `look/delivery/spillway-r21/`. Native Windows, listening, physical latency, performance and enjoyment remain unverified by this automation.

`feat/spillway-r21` and `feat/foldrunner-me-build` are both pushed at `dee210165b6f169b2433b3043712c5855c37d3b6`. Gameplay advanced by a normal fast-forward after publication. No new source commit was made because the validators bind publication to the frozen HEAD; these results and release receipts remain outside Git. Main was untouched.

HOME stayed above 15,000,000,000 bytes. The two explicitly authorized Node and tracker3 caches were removed. Superseded R21 verifier/freeze/component intermediates were archived, fully read back and replaced with archive pointers while Markdown reports were retained. The required baseline RESTORE receipt was restored byte-for-byte. Current v8 packets, native views, source and original historical archive constituents remain local. All 38 original private input/settings files and the spec hash rechecked unchanged. Verified final raw `/tmp` work and archive copies were removed only after publication and branch promotion. [Cleanup receipt](evidence/r21-final-publication/CLEANUP.json).

## Five calls for Mike

1. Do the lower exits carry the speed you wanted into the next section?
2. Do the pans and landmarks make Saltglass feel populated without crowding the route?
3. Is the outside receiving lip a rewarding risk that sets up the next hop?
4. Which Elastic model is worth keeping, with assist on or off?
5. Does the anchor readout make fast attachment predictable, and do the lowered decks remove the clips you noticed?
