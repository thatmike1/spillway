# Overflow art pass

A visual pass over the actual Overflow course, applied after the level builds. It relights
the course, regroups the level's merged meshes by what each surface is for, gives water and
the valley a coherent look, and makes the finish's operating water visible. It adds no
collision, moves no solid and changes no progress data. Every value is a P choice. Nothing
here claims enjoyment, GPU pacing or Windows behaviour.

| File | Role |
| --- | --- |
| `scripts/momentum_overflow_art.gd` | `apply(level)`: light, re-skin, water, terrain, landmarks, finish runtime |
| `shaders/momentum_overflow_surface.gdshader` | the kit surface shader extended with per-vertex edge data, grooves, damp and a moving water film |
| `shaders/momentum_overflow_water.gdshader` | still water and foam sheets |
| `shaders/momentum_overflow_terrain.gdshader`, `_tree.gdshader`, `_sky.gdshader` | valley slopes, conifers, sky |

All shaders are original procedural work. The only textures are the licensed kit's four CC0
sets (`assets/momentum/MANIFEST.json`), loaded unchanged. No external asset was added, so
there is no `assets/overflow-art/`.

## Wiring

```gdscript
level.call("build")
OverflowArt.apply(level)   # const OverflowArt := preload("res://scripts/momentum_overflow_art.gd")
```

Call it once, after `build()` and with the level in the tree; a second call returns the first
report (stored as the level's `overflow_art` meta). It returns a Dictionary: meshes and
triangle counts per look, landmarks placed, water found, terrain clearance, tree count,
runtime parts and `apply_ms`. It dresses only `variant == "course"` with `material_mode ==
"kit"`; the block holdouts and `--overflow-neutral` are left untouched and say why.

What it touches on the level: the `WorldEnvironment`'s environment (replaced by a new
resource, reusing the existing Sky) and the `Sun` light's angle, colour and energy; every `Mesh_<kind>` child is
replaced by `Art_<look>` meshes holding the same triangles (`Mesh_hill` is dropped for the
terrain); water planes get new materials, and the spill plane is re-laid on the dam face.
It reads the level's `manifest`, `_release` and `_gate`. A kind it does not know is left as
built. It never edits `momentum_materials.gd`'s cached materials: every material is new.

The existing Sky is reused because releasing it before its first draw produces two
radiance-texture leaks in the pinned Compatibility renderer. Root's native before/after
Quit probe reproduces the two errors before this change and none after; the visual
parameters and game geometry are unchanged. Evidence: outer
`checkpoints/spillway/r13/delivery-review-sol/root-fix/quit/`.

## Choices

**Light.** A late-afternoon sun low on the left rear of the first leg (rotation −31°, −50°),
warm (`ffdcb0`, 2.1) against a cool sky fill (0.62). Shadows rake across the decks, the
right-hand wall faces and the sluice house front are lit, and the tail race turns toward the
light. The old light came from behind the runner, which flattened every face. A static sky
shader (no `TIME`, so its radiance is computed once), Filmic, light depth fog with aerial
perspective, and a little height fog in the valley.

**Surface hierarchy from the manifest.** Each triangle whose corners are all corners of one
manifest prism takes that prism's role. Sunlit run decks are mid-light neutral concrete;
landing decks a step lighter with finer 2 m bays; catch floors dark, damp and mossy with a
moving water film down their fall line; recovery ramps a mid value with grooves across the
fall line, so a ramp reads as something to climb; walls a step below the decks with lighter
copings. Steel is dark; ochre and brick are the warm accents.

**Edges and contact.** Every top edge of a walkable prism is classified against its
neighbours: *free* (nothing level or higher meets it: a drop), *contact* (a wall or higher
deck stands on it) or *joined*. Signed distances to each edge go into the vertex data, so
the shader draws exactly at the edge with no extra geometry:

- free edges get a 0.32 m trowelled margin with a tooled joint and a worn, lit arris, and the
  face below the lip gets weathering streaks, so a lip reads as light over dark at speed;
- contact edges get occlusion and grime along the wall's foot, and the wall's own face
  darkens toward the deck;
- joined edges get nothing, so continuous decks stay continuous.

**Water.** Still water is dark and takes its brightness from the sky's reflection. The
level's dam spill sheet was tilted the wrong way (high end downstream), cutting through the
dam face as the bright wedge in earlier captures; the pass lays it on the face, 0.25 m
proud, as aerated white water. Sloped catch floors (the plunge pool and the bay apron) get
standing water 0.35 m deep at their low edge, covering about 1.5 m of floor, short of where a
short jump lands. Each plunge-pool wall gets a culvert mouth and a falling foam sheet.

**Valley.** The three planar hill prisms are replaced by a heightfield (81×96 at 10 m) and
1,406 conifers in one MultiMesh, neither casting shadows. Every terrain vertex within 45 m (in
plan) of any walkable or wall piece (rails stand on those decks) is pulled under the
tailwater, so no slope sits within reach whatever the layout; the report states the highest terrain inside that
clearance (−9.5 m, below the −8.3 m respawn plane). Trees keep 75 m away.

**Landmarks and scale.** A 19 m brick stack on the sluice house roof is the route's goal
marker, visible from the crest. A steel gate-hoist portal with an ochre beam stands on the
outlet piers, 9 m above the deck. Windows, doors and string courses sit flush (6 cm or less)
on the sluice house, pump house and gatehouse. Nothing added is reachable, stands in a
landing or hides a gap.

**The working sluice.** The level's own finish still spins the wheel and lifts the gate. The
pass follows that state without driving it: two hoist cables track the gate, a spray plume
rises from the gate while the release runs, and white water pours over the lifted plate's top
edge into the channel. That overflow is a stylisation, not a hydraulic model.

## Proposal for root: a release you can see

The level releases water under the gate into the outflow channel at −5.0 m, 5.5 m below the
sluice deck's 1.1 m parapet, so the actual release is out of sight from the finish and the
arrival ramp. The visual overflow covers that at the stop. A physically consistent fix needs
geometry, so it is a proposal, not part of this pass: raise the outflow channel floor and
the gate sill to about deck −1.0 m (y −0.5) between the outlet piers for the first 25 m of the
channel, then step it down to its current level; give the channel's west side a 1.1 m
parapet that matches `sluice_deck_e`. The undershot release would then run at eye level
beside the finish. The gate plate would need to start 4.5 m higher. The channel stays
outside the route, so no progress or collision on the route changes.

## Evidence

Outside Git under `checkpoints/spillway/r13/overflow-art/` (`STATE.md` is the log). All
renders are llvmpipe on private Xvfb (`:166` for tape runs, `:167` for still views), Dummy
audio, isolated XDG, Godot 4.7.2 Compatibility at 1280×720. They are software frames, not a
GPU or frame-rate result.

**Frozen source.** `mirror/` is the checkout at `90e71e13` plus the then-uncommitted course,
whose level bytes are the committed `cc0147b6` level (sha256 `56aaa0cb…`, geometry
`3a04610b…`, 105 bodies). Every file is hashed in `SOURCE-SNAPSHOT.sha256`. Air candidate
`aceb14e5`, CARRY base `1c3a4f9d`, product main `b2ce44bd`. The mirror's `project.godot`
(`064ebff2`) predates root's default-scene change at `b7ab0ee1`; captures build the product
main directly and do not depend on the default scene.

**Native before/after on the product main.** `mirror/capture/game_before.gd` and
`game_after.gd` build `momentum_overflow_main.gd` with records off; the only difference is a
level subclass whose `build()` calls `apply(self)` after `super()`. Four recorded closed-loop
tapes from the course's final set (`overflow-revision/final-275c477b/driver/course.candidate.*`)
were replayed open loop through `tools/momentum-tape.py` at fixed 30 fps:

| Route | Ticks | Jumps | Respawns | End | Per-tick movement |
| --- | --- | --- | --- | --- | --- |
| ordinary | 3372 | 3 | 0 | sluice deck, clean finish 24.89 s | identical |
| mastery (bay shortcut) | 3082 | 7 | 0 | sluice deck | identical |
| slot_miss (slot recovery ramp) | 3823 | 1 | 0 | sluice deck | identical |
| pool_miss (plunge-pool recovery) | 3717 | 2 | 0 | sluice deck | identical |

"Identical" (`equality.py`, `runs/r1/equality.json`) compares every tick's pre/post position,
velocity, yaw, pitch, mode, grounding, motion ledger, applied key and mouse events and game
state, with only wall-clock stamps removed. Every run ended `completed` with no movement or
integrity flags. Each run keeps `movie.mp4` (complete, CRF 26), JPEG actor frames every 0.1 s
(PNG hashes in `frames-png.sha256`) and its source manifest. The after runs recorded the art
script at `652f667e`; the final file differs only in two comment lines.

Inspected paired frames (same tick, before | after): `inspect/ordinary-a.png` (crest, slot
hops, pier, bay), `ordinary-b.png` (chute, bucket lip, plunge pool, tail race),
`ordinary-c.png` (arrival, finish line, stop with the gate overflow running),
`inspect/recoveries.png` (bay shortcut, slot trench and ramp, pool apron). Iteration stills
and rejected variants are under `iter/`.

**Invariants** (`mirror/capture/check.gd`, `check.log`): 105 collision bodies and shapes with
identical paths and transforms before and after, geometry hash and progress data
unchanged, all six cached kit materials unchanged, a second `apply` returns the first
report, and the block variant is left alone.

**Cost** (`cost/before`, `cost/after`, the same 12 fixed views):

| | before | after |
| --- | --- | --- |
| draw calls per view | 89–136 | 84–138 |
| primitives per view | 9.4k–12.2k | 54k–58k |
| texture memory | 48.95 MB | 49.15 MB |
| video memory | 55.5 MB | 56.2 MB |
| `apply()` | — | 145–300 ms once, llvmpipe host |

The added primitives are the 1,406 trees (21 triangles each, about 30k) and the terrain
(about 14k). llvmpipe movie-writer render time per frame varied with host load across runs (the same
before ordinary tape took 189 ms per frame, the other before tapes 293–363 ms), so no frame-time
claim is made. GPU timing is root's hardware pass.

## Weaknesses

- The release itself still runs out of sight; the visible water at the stop is the
  stylised overflow plus spray, and it sits at the right edge of a view that faces the wheel.
  The geometry proposal above is the honest fix.
- The tail race is warmer and broken by damp patches but is still the plainest, broadest
  stretch; it has no foreground scale objects, because anything standing on it would be in
  a landing or need collision.
- Trees are faceted cones and the terrain is smooth; at running distance they read as
  forest and hills, close inspection shows low-poly shapes.
- The ochre nosings keep the kit's large paint-chip pattern, which reads blotchy when a lip
  fills the lower frame.
- Edge classification takes each edge's majority: a deck edge that is partly walled and
  partly open gets one treatment along its whole length.
- The sun-facing tail race carries a warm haze; whether that reads as atmosphere or glare
  on a real display is unverified.
- llvmpipe only. Anisotropic filtering, shadow quality and fog differ on GPU drivers; the
  first look on the AMD path is owed. No human has judged whether it is attractive.
