# Spillway R17: Opus visual and trail review

Reviewer: Opus 5.5, the single R17 Opus pass, 9 Nov 2026. Read-only. Runtime under review: `9170857f1` (stills from `7c82e0877`, with no world-art change since). This review doesn't judge Mike's taste and doesn't say the result looks good.

Inputs I actually opened:
- all 17 native old/new still pairs in `evidence/r17-views-final/*/`, compared side by side, with pixel zooms where noted;
- the private targets `blend-c-breakwater.png` and `sunbleached-sunken.png`, plus `round2-NOTES.md`;
- four frames from each of the eight `r17-*.mp4` clips, extracted with ffmpeg (not from the contact sheets), plus consecutive frames on Sunken Court;
- `scripts/r17_{main,look,palettes,contours}.gd`, `shaders/look/{ink,r17_prop}.gdshader`, `scripts/r14_practice_readability.gd`, and the R15 level `_paint_*` calls;
- `decisions.tsv`, `RESULTS-R17.md`, `evidence/r17-trail-self-audit-checkpoint.json`, and the parent transcript (`rollout-2026-11-09T10-28-44-...jsonl`, 3391 lines, searched at the source lines cited below).

## Verdict in one paragraph

The shared language does reach every map. Breakwater, Night Shift and Overflow carry blend C most clearly, and the new painted skies are calm and static in motion. Two things fall short of the R17 goal's own bar ("readability wins"):

1. R17 recolours the earlier rounds' functional edge and take-off markings to deck cream, and adds back only a 10 cm flat orange strip at declared gaps. On several maps the jump edge is now less visible than in the old look.
2. The ink is built from collision prisms, not visible meshes. On Sunken Court it floats over trees and draws seam lines across the curved landing deck.

Both are fixable in the presentation layer without touching movement. The rest is Mike's taste call or already-labelled pending gates.

## A. Actionable defects (fix before shipping, or disclose in RESULTS)

**A1. Functional readability markings are flattened (readability regression, high).**
- `r17_look.gd` `material_for()` sends every `Mesh_paint*`/`Art_paint*` kind (`paint_yellow`, `paint_hazard`, `paint_white`) and `ReadabilityPads/Bars/Nosing` to `flat(palette.top)`, or to `side` for "dark". The source comment says "old floor pads become quiet cream".
- These were not decoration:
  - `r14_practice_readability.gd:1-11` documents the red-oxide take-off pad as the 250 u/s jump window, and the pale nosing (0.14 m vertical face) as the landing lip;
  - the R15 levels paint 0.25–0.35 m yellow lips on real gap edges (`r15_rainline_level.gd:182,216,218`, `r15_breakwater_level.gd:177-204`, `r15_experiment_level.gd:147,166-167,184`).
- Visible results:
  - Rainline route: the old bright yellow edge strip becomes a pale band almost the deck's value, and the near and far decks are separated only by a 1 px line (`r17-views-final/rainline/route-{old,new}.png`, crop x180–660, y500–640);
  - Penstock Yard route: the red take-off pads are gone (`practice/route-new.png`);
  - Movement Lab: the threshold and hazard stripes turn cream or white (`experiment/spawn-new.png`, y≈340).
- RESULTS-R17 calls this "fewer decorative orange surfaces", which is misleading. No `decisions.tsv` row records removing them; the change appears only inside a patch at transcript line 1598 (14:10Z).
- Fix options:
  - keep R14/R15 functional markings in a desaturated but distinct value; or
  - map `paint_yellow`/`paint_hazard`/`ReadabilityNosing` to the orange lip colour at their original widths, and keep the take-off pad as a muted warm tone.

**A2. Jump lips are too thin to read at speed (high, with A1).**
- `r17_contours.gd` `gap_lip()` lays a flat 0.10 m strip 1.2 cm above the edge, with no vertical face.
- My estimate from source constants: 1.74 m eye height, 73.74° vertical FOV (`views.json`), so about 480 px focal at 720p, ignoring MSAA. The strip projects to about 84/d² px: 1 px at ≈9 m and 0.2 px at 20 m.
- For comparison, the old 0.3 m paint reaches 1 px at ≈16 m, and the R14 nosing's 0.14 m face is still 1 px at ≈67 m.
- At 350 u/s (8.9 m/s, from the HUD) the R17 lip appears about one second before the edge. On Penstock at 934 u/s it is about 0.4 s.
- In the clips the lips do read up close (Breakwater t=9.92, Night Shift t=9.92 and 13.92, Penstock t=1.92 and 5.92), but are absent at mid-distance in every route still.
- Both private targets use much broader orange bands, including a vertical face (`blend-c-breakwater.png` along the right quay; `sunbleached-sunken.png` throughout).
- Fix option: a 0.25–0.35 m top band plus a 0.12–0.15 m face, reusing the R14 nosing geometry approach.

**A3. Ink from collision outlines floats and crosses decks (medium).**
- `r17_contours.gd` builds ink from `level.manifest` prism tops and drops only exact-match shared edges (`edge_key`, 1 mm snap).
- Sunken spawn: an ink line floats over the trees above the crenellated wall. The trees show between the line and the visible wall (`sunken-court/spawn-new.png`, x0–300, y100–260, 3× zoom).
- Sunken clip: a web of thin lines crosses the curved cream deck at segment joints. This is visible in four consecutive frames (`r17-sunken-court.mp4` from t=1.90 s, crop x420–980, y400–580) and in my t=5.92 frame. These are internal route seams, not silhouettes, and they sit where the player looks for the landing.
- The parent noticed the floating arch contours at 14:19Z (transcript line 1767) and reported them restricted. The final still still shows one.
- Fix options: skip edges whose neighbour sits within a tolerance (T-junctions and overlapping curve segments); or derive caps from visual meshes on imported castle art.

**A4. Indoor spaces collapse to one flat navy (medium).**
- Movement Lab spawn and route stills, Whiteout hangar (`whiteout-relay/spawn-new.png`) and the Whiteout clip at t=9.92 and 13.92 (Cable Works): walls, ceiling, back wall and wall-jump housings take the same side colour under flat ambient. Corners and room depth vanish.
- In the lab, walls are a movement surface (wall jump), so this is a readability issue, not only a look issue.
- Fix options: a value step between `ceiling`/`wall`/`housing` roles, ink on vertical silhouettes indoors, or more fill light indoors.

**A5. Night Shift clip opens on 4.3 s of the Godot splash (evidence defect, low).**
- `r17-night-shift.mp4` frames from t=0 to t≈4.3 are a constant splash (mean luma 40.46 until t=4.0, then 80 at t=4.5). That is 27% of the clip.
- The parent trimmed the splash from Overflow (transcript line 2801) but didn't check the other clips. Only Night Shift is affected; I measured opening luma on all eight.
- `RESULTS-R17.md` and the comparison page present it as a run excerpt. Trim or recapture.

**A6. The stills are 1296×736, not 1280×720 (evidence accuracy, low).**
- Every PNG in `r17-views-final` is 1296×736 (ffprobe). The corner crops show rendered pixels, not window borders.
- `RESULTS-R17.md` says "Seventeen matched native 1280×720 before/after pairs".
- The FOV and pose match, so the comparison holds, but the stated size is wrong. The clips are a true 1280×720.

**A7. Small label placement (cosmetic).**
- In the lab clip (`r17-experiment.mp4` t≈1.7 s) the R17 label sits at about y=195 px. It collides transiently with the world-space sign "hold E grapple"; there is no HUD overlap.
- The other seven clips show the label top-right, clear of HUD panels.
- The practice-banner case is source-asserted and left to the pending packed-frame check, which I did not verify.

## B. What carries blend C and the map themes (evidence, not a taste verdict)

- **Breakwater:** the concept camera reproduces the target structure: cream deck, teal wall with sparse warm wear, painted cumulus, lighthouse. It loses the concept's orange wall coping, which became cream on purpose, and the container yard becomes one monochrome teal (`breakwater/route-new.png`, `spawn-new.png`). The port's colour variety is gone.
- **Night Shift:** keeps its identity best. Window grids, indigo sky, pale platforms against dark trains; orange lips visible near. The trains lose their red livery and the neon is cream (`night-shift/spawn-{old,new}.png`).
- **Overflow:** a strong warm-deck and dark-side read, and sea-glass water. The sky is the busiest of the eight: orange and blue blotches directly above the route (`overflow/*-new.png`).
- **Penstock Yard:** clean deck versus side contrast at 934 u/s. The distance signs are more legible than in the old look (`practice/route-*`, zoom on the "16 m / 630 u" sign).
- **Rainline:** changes from night city to overcast dusk. The lit windows and city-lights identity largely disappear (`rainline/spawn-*`). The gantry canopy underside renders as bright radial stripes above the route in motion (clip t=5.92, 13.92).
- **Sunken Court:** the biggest identity shift. Warm sandstone ruins become near-black bottle green (`sunken-court/spawn-*`), the reverse of `sunbleached-sunken.png`'s pale grey sides and broad orange bands.
- **Whiteout:** the cream road against cool snow works outdoors. The yellow barrier blocks and lane dashes go navy or grey.
- **Skies:** static and calm in every clip I sampled. No visible motion. They read behind the route, except Overflow's saturation.

## C. Artistic gaps that belong in RESULTS (Mike's call, not defects)

- Sides use one dark value per map, so on Sunken, Breakwater's yard and the lab, sides read near-black rather than the concepts' weathered mid-tones.
- The orange is far thinner than in either concept (see A2). Even after a readability fix, the band width is an art choice.
- The concepts' painted wear and brushwork is mostly absent beyond Breakwater's wall blots.
- RESULTS already lists the rest: no landmark reauthoring, panorama resolution, water glints, characters or hands.
- Mike should judge Rainline and Sunken Court in particular in motion, because their themes changed most.

## D. Trail and evidence risks

1. **The self-audit milestone search is a substring grep.** `r17-trail-self-audit-checkpoint.json` lists `"0.012"` hits at transcript lines 1459, 1494 and 1598 as decision milestones. They are an ink radius, a shader seam constant and the lip lift (checked at those lines, 14:02–14:10Z), not the Rainline +0.012 ms GPU result, which came later. `"1838"` at line 1713 is inside base64. So that section shows only that the strings occur, not where the decisions were made.
2. **No logged decision covers removing R14/R15 readability markings, and no logged native readability judgement at 300+ u/s exists.** The plan step "review readability" (transcript lines 1432 and 1671) was carried forward and handed to this review. RESULTS states the readability choices as done.
3. **A claimed fix didn't hold:** the Sunken floating ink (A3, transcript line 1767 against the final still).
4. **The splash check ran on one clip only** (A5).
5. **The comparison page links absolute local paths.** That's fine for Mike's machines but not portable. It also links this review, which didn't exist until now.
6. **Untracked parity tooling.** The worktree had untracked `tests/r17_parity.gd`, `tests/r17_parity_README.md`, `tests/r17_parity_audit.py` and `tools/check-r17-parity.py` at review time, from `git status`. Their owner is presumably the parity worker (a guess). If they produced the "verified" parity evidence, they need committing or archiving with hashes before promotion. I didn't touch them.
7. **HOME margin is thin:** 15,178,448,896 bytes free at review time, about 178 MB above the floor. My scratch used tmpfs only.
8. Already labelled as pending and not counted here: final 917 packages, the 8-map refresh in `r17-final-parity/`, the final-PCK desktop GPU run, and the branch fast-forward. Windows runtime is unexecuted, and the Linux and Windows ZIP scopes are kept distinct in RESULTS. I treated none of these as passed.

Checked and fine:
- No private concept PNG hash appears among the project's PNGs over 100 KB, and no source or doc references `look/concepts`.
- L was unbound in R16 (`grep KEY_L` finds only the slice's `look_main.gd`), so R17's `_input` intercept shadows nothing.
- The renderer is Compatibility (`project.godot:20`), which matches the opengl3 captures.

## Attention list

1. Rainline route jump edge: old yellow 0.3 m strip, new pale band (`r17-views-final/rainline/route-{old,new}.png` y≈540–560).
2. Penstock take-off pads removed (`practice/route-new.png`; `r17_look.gd` `material_for`, Readability* branch).
3. Lip geometry 0.10 m flat, no face (`r17_contours.gd` `gap_lip`, `inward*0.10`).
4. Floating ink over trees (`sunken-court/spawn-new.png` x0–300, y140–160).
5. Seam ink across the curved deck (`r17-sunken-court.mp4` t=1.90–1.95, x420–980, y400–580).
6. Navy collapse indoors (`experiment/{spawn,route}-new.png`; `r17-whiteout-relay.mp4` t=9.9, 13.9).
7. Splash in the clip (`r17-night-shift.mp4` t=0–4.3).
8. Wrong still-size claim (`RESULTS-R17.md` "native 1280×720 before/after pairs", actual 1296×736).
9. Self-audit false milestones (`r17-trail-self-audit-checkpoint.json` `"0.012"`, `"1838"`).
10. Misleading wording (`RESULTS-R17.md` "fewer decorative orange surfaces").
