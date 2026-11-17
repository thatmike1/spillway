# Foundry assets

`concrete.gdshader` is original procedural shader code authored for Spillway r22.
It samples no image, scan or external data. `scripts/art/foundry_hall.gd` creates
original primitive geometry. Both inherit this repository's license.

Private generated concept art and Mike's moodboard are design references only,
kept in the external lane run folder. No reference pixels ship in this map.

The sky reuses the repository's existing `assets/look/r17/practice-sky.png`
through `shaders/look/sky.gdshader`; their existing provenance remains unchanged.

`outline.gdshader` is original inverted-hull ink code. The concrete shader uses
original procedural slab joints, per-slab warm variation, wet streaks and
localized joint chipping. No image or reference pixels are sampled for these
materials. The optional sky reuse is the only bitmap in this art treatment.

Procedural wear is confined to broken slab-joint edges, short seam runoff and
the lower waterline. Broad pale/dark mottles are deliberately absent.

`scripts/art/foundry_sea_gate.gd` builds original box/cylinder scenery and a
visual-only service trolley. It loads no external assets and creates no physics
bodies or grapple anchors. The private Wave 2 concept is not a shipped asset.

`sea.gdshader` and `steel.gdshader` are original procedural code, sampling no
images. The distant navigation light, breakwater, hoist detailing and cooling
main are original primitives with no added collision.

The offshore breakwater uses a deeper visible masonry base and a local
waterline parameter. Salt and paint loss remain limited to bases, joints and
exposed edges. `foundry_cable.gd` follows the repository Viaduct cable pattern:
it clones/restores only drawn resources and does not change the Arc solver.
