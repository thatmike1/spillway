# R19 item 1: style and interface

## Backwards and half-sideways bhops

These are P / game choices, not changes to the Source motor. The R15 runners, presets, maps, hulls, input law and recording format remain unchanged. The scoring identity is `r19-style-1`, plus the existing hash of the full rules table. Old style bests remain in their old sections. Time and ghost identities exclude style and remain comparable on unchanged geometry.

A qualifying flight starts with the motor's actual `jump` event from an observed grounded sample and ends on a real landing. Every sampled step must have horizontal actual speed of at least **300 u/s**. Actual velocity excludes duck-origin compensation. Facing uses the signed dot product of normalized horizontal velocity and `(-sin(yaw), 0, -cos(yaw))`:

- backwards: dot ≤ −0.75, within about 41° of directly backwards;
- half-sideways: absolute dot < 0.75, the broad sideways band between the forward and backwards cones;
- forward: no directional bonus.

Each complete flight needs 0.18–1.2 seconds, at least 3 m of actual horizontal travel, at least 25 cm rise and 20 cm descent from its peak. Net horizontal displacement must be at least 85% of travel. The next jump must leave within 60 ms of landing, keep the facing category, and its landing heading must stay within 60° of the previous qualifying hop. Speed or facing failure immediately clears the chain. A flight without an actual motor jump, a missed sample, teleport or discontinuity clears it too. Landing spots must be at least 4 m horizontally from every previous qualifying landing in the attempt. This history survives respawns and other discontinuities, so replaying a line cannot earn another chain. Reset starts a fresh attempt.

The first qualifying landing arms the chain without paying. The second and later pay a directional event and multiply all style events while the earned chain remains valid:

| travel | multiplier on hop 2 | growth per hop | cap | new event base |
|---|---:|---:|---:|---:|
| backwards | ×2 | +0.5 | ×4 at hop 6 | 80 |
| half-sideways | ×1.2 | +0.15 | ×1.8 at hop 6 | 40 |

The existing combo multiplies this factor. Directional events do not extend the existing combo, so a forward run keeps its existing event weights and combo behavior. For example, backwards hop 4 pays 80 × 3 = 240 before any existing combo factor. A chain can sustain on an earned fast coast with genuine jumps; it does not require a particular held movement key. The 300 u/s floor exceeds the fixture's observed 250 u/s straight-running speed.

Events use `backward_bhop` or `sideways_bhop`; existing event schema 1 has additive `direction_mult` and `combo_mult` fields. Direction events include hop count, flight seconds, travel, net progress, rise, descent and landing speed. `snapshot().direction` supplies live kind, hops and factor. The R18 panel shows a small orange live multiplier line above its cream callout and existing score. Backwards has gap/edge callout priority, sideways near-miss priority, and crouch saves retain highest priority.

## Verification

Run the pinned Godot editor with isolated XDG profiles and the existing RAM import cache. Reproduce exact forward score comparison by first extracting the R18 service outside the checkout:

```bash
git show 640d06e6539b53da752f03bfddb64fb46310abb7:projects/foldrunner/scripts/r16_style.gd > /tmp/r19-item1/r18_style.gd
```

The test entry points are `tests/r19_style_bhop.gd -- --out=/tmp/r19-item1/style --baseline=/tmp/r19-item1/r18_style.gd` and `tests/r19_style_ui.gd -- --out=/tmp/r19-item1/native/1280x720`. The latter also runs headless for scene assertions; screenshots require a native renderer. These are `--script res://...` arguments to the pinned editor, not standalone shell commands.

The bhop suite uses the unchanged R15 body on the existing real collision fixture, with key/mouse-earned acceleration, backwards/sideways jumps, idle/slow/walking controls, forged hop counters on actual walking samples, lifecycle breaks, a repeated line and reversal. Labelled teleports are negative fixture setup, never a gameplay mechanic. It compares every forward event and score against the extracted R18 service, checks the live R18 host's directional events and recording round trip, and checks separated scoring identity. The UI fixture stages scores through the actual R18 controls and tests visibility, rank holds and non-overlap. Screenshots of staged scores prove presentation, not a played score or enjoyment.

## Map cards

Penstock Yard is “Open yard for speed, strafes and gap practice”; Overflow is “Dam-top run through spillways and service decks”. The R17 presentation host overrides only the `theme` returned by `map_entry`; R18 legacy cards omit the developer kind subtitle. Map ids, `legacy` kinds, registry, physical level files, geometry hashes and time identities stay unchanged. `tests/r19_asks_ui.gd -- --asks=maps --out=/tmp/r19-item1/maps` checks actual card and tooltip controls and compares each loaded map against the frozen R16 host.
