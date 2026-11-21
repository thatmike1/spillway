# Spillway cloud sheet prompts

All three sheets were generated with the built-in image_gen.imagegen tool on 2026-11-21. The tool did not report its model. Each selected source was generated from text alone with `transparent_background: true` at 1536 × 1024.

For the RGB PNG export, alpha values below 8 out of 255 were cleared to remove faint pixels in the background. The remaining edges were composited over sRGB `#00FF00`. The two clouds on cumulus-a were placed on a wider canvas without resampling so the bank fits inside the right half.

## cumulus-a.png

Tool `image_gen.imagegen`. Model undisclosed. Date 2026-11-21. No input image was supplied.

```text
Asset sheet with a true transparent alpha channel. The visible artwork consists solely of gouache cloud pigment. Supply real RGBA transparency around and between every painted formation, all the way to the image borders. Leave fully clear space wherever there is no cloud, including all four corners. No colored backdrop and no drawn checkerboard. This is a landscape 3:2 texture with target native dimensions 1536 × 1024 or larger. Leave the central 10% of the canvas width completely transparent. Place each cloud inside its respective half with a generous inset from the left and right edges. Use solid opaque cloud pigment so the silhouettes are clearly defined, with a minimal soft edge.

Generate a brand-new original game texture sheet, a landscape PNG at the largest native landscape size available, at least 1536 by 1024. Paint exactly two sculpted summer cumulus formations seen from the ground. On the left, paint an impressive tall, narrow cumulus tower with an uneven crown of stacked round lobes and a nearly level base. On the right, paint a distinctly wide, low cumulus bank with a row of varied low lobes, an extended flatter base, and gently tapered ends. Each cloud is fully inside its own half and fills much of that half with a generous fully transparent space margin on every side. Leave a clear, uninterrupted vertical strip at least 100 pixels wide centered in the image, and keep all clouds at least 75 pixels from every outer edge. No stray cloud fragments outside the two formations.
Hand-painted gouache with big readable lobes, a few crisp painted edges and soft brushy interiors. Restrained and naturalistic. Light from the upper left, warm ivory lit tops and clear cool soft grey-blue shadows across the lower right. Define the light and shadow planes even on the low bank. No heavy outlines or cartoon styling.

No green pigment, sky color, sun, ground, sea, birds, text, frames, signature, watermark, or other subjects.
```

## cumulus-b.png

Tool `image_gen.imagegen`. Model undisclosed. Date 2026-11-21. No input image was supplied.

```text
Asset sheet with a true transparent alpha channel. The visible artwork consists solely of gouache cloud pigment. Supply real RGBA transparency around and between every painted formation, all the way to the image borders. Leave fully clear space wherever there is no cloud, including all four corners. No colored backdrop and no drawn checkerboard. This is a landscape 3:2 texture with target native dimensions 1536 × 1024 or larger. Leave the central 10% of the canvas width completely transparent. Place each cloud inside its respective half with a generous inset from the left and right edges. Use solid opaque cloud pigment so the silhouettes are clearly defined, with a minimal soft edge.

Generate a brand-new original game texture sheet, a landscape PNG at the largest native landscape size available, at least 1536 by 1024. Paint exactly two clearly isolated summer cumulus formations seen from the ground. On the left, paint a medium-height asymmetric cluster with a broad flat-ish base and three substantial interlocking lobes. On the right, paint a compact small pair of puffs with one modest hump stepping down to a lower hump. Their bases join very slightly so the right half reads as a single silhouette with two crowns that can be cut out as one card. Make the silhouette of the left cloud quite different from the right. Each formation stays fully inside its own half, surrounded by fully transparent space. Leave a clear uninterrupted vertical transparent column at least 100 pixels wide centered in the image, with at least 75 pixels of clear space around the outer borders. No stray fragments.
Hand-painted gouache, restrained and naturalistic, with readable rounded sculptural masses, a few crisp painted lobe edges and soft brushy interiors. Sunlight from upper left. Use warm ivory for the lit tops and clearly distinct soft cool grey-blue shadow planes on the lower right. No heavy outlines or cartoon styling.

No green pigment, sky color, sun, ground, sea, birds, text, frames, signature, watermark, or other subjects.
```

## wisps.png

Tool `image_gen.imagegen`. Model undisclosed. Date 2026-11-21. No input image was supplied.

```text
Asset sheet with a true transparent alpha channel. The visible artwork consists solely of gouache cloud pigment. Supply real RGBA transparency around and between every painted formation, all the way to the image borders. Leave fully clear space wherever there is no cloud, including all four corners. No colored backdrop and no drawn checkerboard. This is a landscape 3:2 texture with target native dimensions 1536 × 1024 or larger. Keep four generous horizontal gaps including outer margins. Use opaque white and grey-blue painted marks with broken brush tips, avoiding broad low-opacity airbrushed halos.

Generate a brand-new original game texture sheet, a landscape PNG at the largest native landscape size available, at least 1536 by 1024. Paint exactly FOUR horizontal rows of high clouds arranged as four independent strips, stacked from top to bottom. Each row is one crop region. In the first row paint a thin swept filament of cirrus. In the second row paint tapered parallel cirrus streaks. In the third row paint broken small altocumulus flecks arranged in a thin horizontal band. In the fourth row paint a low feathery wisp with a few thin detached fragments within that row. Keep all four rows clearly distinct with large, uninterrupted strips of fully transparent space at least 70 pixels high across the full width between successive rows. Keep every visible brush mark at least 75 pixels from the outer borders. The clouds spread horizontally, with no streaks or fragments crossing into other rows.
Hand-painted gouache with warm ivory lit surfaces coming from the upper left and faint soft cool grey-blue undersides. Use slender natural shapes, selectively crisp edges and broken brush tips. Keep the visible brushwork inside the silhouettes. No dense cumulus banks, heavy lines or cartoon styling.

No green pigment, sky color, sun, ground, sea, birds, text, frames, signature, watermark, or other subjects.
```

## cumulus-c.png and cumulus-c-rgba.png

Tool `image_gen.imagegen`. Model undisclosed. Date 2026-11-21. No input image was supplied. The tool was called with `transparent_background: true`.

The RGBA file preserves the original 1536 × 1024 tool output byte for byte. The 1840 × 1024 RGB export clears alpha values below 8/255, composites over flat sRGB `#00FF00`, and adds canvas space between the halves and at the side edges without resampling.

```text
Paint an original game sky texture sheet, a 3:2 landscape PNG at native 1536 × 1024 or larger, with real transparent RGBA. Exactly two cloud formations viewed from slightly below, one centered in each half. Leave the central 12% of the entire canvas fully transparent from top to bottom and inset every brush mark at least 90 pixels from the frame. Only cloud pigment is visible. Use fully clear alpha in the gaps and around the artwork, including all four corners. No colored background, checkerboard, sky, sun, ground, green pigment, or lettering.

Hand-painted opaque gouache with fine dry-brush texture, restrained and naturalistic. Build a few big, readable rounded lobes with selectively crisp lobe edges and soft brushy interiors. Sunlight from upper left, pale warm ivory peaks and clearly darker cool slate grey-blue shadow planes spreading across roughly the lower-right third of each formation. Give the shadow planes real depth and shape. No outlines, cartoon styling, photographic haze, or airbrush halo.

Make every underside organic and uneven. Give each base a changing height and broken contours, with some rounded pendant lobes, scooped gaps, and a few thin tapered wisps that dissolve into transparency. Absolutely no level cut, straight bottom edge, common baseline, or horizon. Keep wisps close to their own formation.

Left half: a broad anvil-free cumulus congestus, slightly wider than tall, with a high rounded crown displaced slightly to the right of its center, several large sculpted lobes, and a deep, visibly shadowed underside. Shape the underside as an uneven sagging belly with a taper at each end.

Right half: a long, thin ragged procession of about five small fair-weather cumulus puffs, arranged on a shallow downward diagonal from left to right and growing smaller toward the tip. Keep the overall formation very low and narrow, with little torn bridges and gaps between the puffs. Each puff has its own darker underside at a different height.
```

## cumulus-d.png and cumulus-d-rgba.png

Tool `image_gen.imagegen`. Model undisclosed. Date 2026-11-21. No input image was supplied. The tool was called with `transparent_background: true`.

The RGBA file preserves the original 1536 × 1024 tool output byte for byte. The 1840 × 1024 RGB export clears alpha values below 8/255, composites over flat sRGB `#00FF00`, and adds canvas space between the halves and at the side edges without resampling.

```text
Paint an original game sky texture sheet, a 3:2 landscape PNG at native 1536 × 1024 or larger, with real transparent RGBA. Exactly two cloud formations viewed from slightly below, one centered in each half. Leave the central 12% of the entire canvas fully transparent from top to bottom and inset every brush mark at least 90 pixels from the frame. Only cloud pigment is visible. Use fully clear alpha in the gaps and around the artwork, including all four corners. No colored background, checkerboard, sky, sun, ground, green pigment, or lettering.

Hand-painted opaque gouache with fine dry-brush texture, restrained and naturalistic. Build a few big, readable rounded lobes with selectively crisp lobe edges and soft brushy interiors. Sunlight from upper left, pale warm ivory peaks and clearly darker cool slate grey-blue shadow planes spreading across roughly the lower-right third of each formation. Give the shadow planes real depth and shape. No outlines, cartoon styling, photographic haze, or airbrush halo.

Make every underside organic and uneven. Give each base a changing height and broken contours, with some rounded pendant lobes, scooped gaps, and a few thin tapered wisps that dissolve into transparency. Absolutely no level cut, straight bottom edge, common baseline, or horizon. Keep wisps close to their own formation.

Left half: a medium rounded, full-bodied cumulus cloud, wider than tall, with an almost hemispherical mass of rounded lobes. The lower contour is lifted into an irregular arch with breaks and a few short torn wisps trailing below it. Keep those wisps close enough to read as part of that cloud.

Right half: a heavy wide cumulus with two tall crowned masses rooted in one deep body. The right crown is clearly taller than the left and a deep saddle separates them. Give each crown several billowing lobes. The underside hangs in a broad irregular arc with a low shadowed lobe under the taller crown, scooped gaps, and thin torn tips. The two crowns should feel substantial and tall, not like a small pair of puffs.
```
