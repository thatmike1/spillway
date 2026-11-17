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

Broad interpolated procedural weathering, broken coating and damp regions give
vertical concrete irregular wear without introducing a fine repeating texture.
