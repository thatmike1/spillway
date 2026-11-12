# R20: Higher surf entries, growing stacks and mouse grapple

**Date:** 10–11 November 2026; gameplay commits 10 November, final verifier/docs commit 11 November.

**What Mike asked for, agent summary:** Agent summary: remove the free Saltglass reverse-start skip, enter fins high, use flat exits without safety nets, grow directional stacks, move tether controls to mouse with alternative ropes, shelve weak experiments, prototype Through Line and export every local run.

**What was built, agent summary:** Saltglass was rebuilt with high fin entries and climbing links. Pending backwards/sideways stacks bank on a fast end and disappear on stall. Tether Yard adds Classic/Pendulum/Elastic and LMB attach/RMB reel. Through Line transfers momentum between two physical segments. Local run ZIP export/ingestion ships. Runtime 7f8fb41b7; e6baa995d repairs verification/docs only.

**His verdict and attribution:** Agent summary from R21-SPEC.md: Saltglass was fun but empty; high exits spent too much surf speed climbing. The backwards stack seemed about right but was not deeply tested. Mike liked the hard Breakwater outside-container line and preferred Elastic, while acquisition and platform clips still needed work. Through Line remained untested. No eligible direct quote is used.

**Key decisions, agent summary:** Shelve Line Drive/Fall Line while preserving code and reasons. Preserve original eight-map/F2 parity. Trials and replay counts must be separated from human feel.

**Original commit span:** `2f6249513fc81f187deee4f37595a35592f5c0c1^..e6baa995da84d380abc8b8d6a3769b33e771945e` (inclusive first `2f6249513`, last `e6baa995d`)

**Package/source identity:** `7f8fb41b741c01455682ae0c6ee612d5d6fd1fc4`.

**Sources:** /home/thatmike1/foldrunner-build-2026-11-05/R20-SPEC.md; /home/thatmike1/foldrunner-build-2026-11-05/look/RESULTS-R20.md; /home/thatmike1/foldrunner-build-2026-11-05/playtest-r19/ANALYSIS.md; /home/thatmike1/foldrunner-build-2026-11-05/playtest-r20/ANALYSIS.md; /home/thatmike1/foldrunner-build-2026-11-05/R21-SPEC.md; bead ccChat-general-epsz description/comments.

## Frame provenance and coverage

- [archive-check-000_tick_00000.webp](frames/archive-check-000_tick_00000.webp): R20 packaging-candidate Breakwater start. retained rejected R20 packaging candidate; final R20 ZIP identity is not claimed.
- [archive-check-083_pause-for-map_saltglass.webp](frames/archive-check-083_pause-for-map_saltglass.webp): R20 packaging-candidate pause menu before Saltglass selection. retained rejected R20 packaging candidate; final R20 ZIP identity is not claimed.
- [saltglass-frame-03900.webp](frames/saltglass-frame-03900.webp): R20 Saltglass high-entry surf route. retained R20 native source capture, not final ZIP proof.
- [tether-route-00900.webp](frames/tether-route-00900.webp): R20 Classic mouse-grapple Tether Yard route. retained R20 native source capture, not final ZIP proof.
- [through-line-landing.webp](frames/through-line-landing.webp): R20 Through Line receiving landing. retained R20 native source capture, not final ZIP proof.
- [through-line-launch.webp](frames/through-line-launch.webp): R20 Through Line launch. retained R20 native source capture, not final ZIP proof.

### Gaps

- Fresh capture from the historical delivered ZIP: Mike deliberately deleted R12–R20 deliveries during disk cleanup on 12 November. No deleted delivery folder was recreated. Retained evidence and explicitly labeled source rebuilds are used instead.
- Confirmed final-ZIP R20 menu and Breakwater start: The recovered packaged menu/start pair belongs to a rejected packaging candidate and is labeled accordingly; native source new-mechanic frames remain available.
