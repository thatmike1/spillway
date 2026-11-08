# R15 asset palette: eight small Kenney packs, one snow material

Checked 8 November 2026, approximately 19:40–20:00 UTC. **Use the access-verified Kenney palette below, selectively imported, with the existing concrete/metal kit.** Quaternius offers particularly good ruins and rooftop geometry, but its tested Drive file downloads return quota errors. Those are conditional alternatives, not ready dependencies. This recommendation does not supersede the Breakwater worker's first prop choices.

This is research only. No game files changed, no full packs downloaded, no assets imported, and no native render or collision compatibility claimed. The [machine-readable shortlist](research/palette.json) separates source facts, access results and proposed budgets. Private receipts are in `/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r15/asset-research/`.

## What is actually verified

- Publisher product pages explicitly identify the packs as **CC0** and link the Creative Commons deed. For six selected Kenney packs, the bounded ZIP prefix also yielded the pack's own `License.txt`; its ZIP CRC was checked. Nature Kit and Space Kit put isometric renders first, so their licence files were not reached within the prefix allowance. Their publisher licence declarations are retained; acquire their in-pack notices with the eventual full download.
- All eight selected Kenney endpoints returned `application/zip`, ZIP local-file magic and an exact `Content-Length`. Only the first **98,304 bytes per pack** were read, then the response was closed. This proves anonymous access to ZIP bytes, **not** a complete archive integrity check. HTTP Range was ignored, so no central-directory or full mesh inventory was obtained.
- Kenney's page script requests `/download-link/<hex asset id>`, then navigates to a short-lived signed URL. The service required the product page's same-origin `Referer`; an initial bare request returned 403. The working endpoint/referer and response sizes are recorded. Generate a fresh link at acquisition time; do not reuse an expired signed URL.
- Poly Haven's snow API exposes exact file sizes, checksums and physical repeat. Each selected file returned a genuine **206** image prefix with a matching total in `Content-Range`.
- Quaternius publisher pages and public Drive folder listings work. Four licence-file download tests and additional ruins-arch/antenna tests returned **HTTP 200 HTML titled “Google Drive - Quota exceeded”**, not asset bytes. Treating 200 alone as success would have been wrong. No Quaternius in-pack licence or mesh was acquired.

Primary licence sources: [Kenney example product declaration](https://kenney.nl/assets/factory-kit), [Quaternius example product declaration](https://quaternius.com/packs/ultimatemodularruins.html), [Poly Haven licence](https://polyhaven.com/license), [CC0 deed](https://creativecommons.org/publicdomain/zero/1.0/), [CC0 legal text](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt). CC0 supports modification and redistribution, including bundled source assets; preserve provenance and the notices anyway. The publisher's general website copyright footer does not override the asset-specific CC0 declaration.

## A bounded acquisition list

Sizes below are measured compressed full-download sizes, not installed size, VRAM or retained subset size. Counts are the publisher's “Files” counts, not audited unique meshes or triangle counts.

| Source and selected version | Published count | Verified ZIP bytes | Format evidence and intended use |
|---|---:|---:|---|
| [Kenney Watercraft Kit 2.1](https://kenney.nl/assets/watercraft-kit) | 45 | 1,870,991 (1.78 MiB) | FBX entries seen. Cargo/tug silhouettes, cargo containers and dock pieces visible in official gallery; port identity. |
| [Kenney City Kit (Industrial) 2.0](https://kenney.nl/assets/city-kit-industrial) | 40 | 5,045,077 (4.81 MiB) | FBX `building-a`, `building-b` seen. Gallery shows warehouses, rooftop hardware, tanks, containers and utility structures. |
| [Kenney Space Kit 1.0](https://kenney.nl/assets/space-kit) | 150 | 6,677,531 (6.37 MiB) | Publisher says 3D; prefix reaches only isometric PNGs. Gallery shows service buildings, pads and exterior modules. Per-pack mesh formats not independently reached. |
| [Kenney Nature Kit 1.0](https://kenney.nl/assets/nature-kit) | 330 | 10,537,521 (10.05 MiB) | Publisher says 3D; prefix reaches only isometric PNGs. Gallery shows cliffs, rocks, plants, conifers, logs and bridges. Mesh formats not independently reached. |
| [Kenney Castle Kit 2.0](https://kenney.nl/assets/castle-kit) | 75 | 2,232,589 (2.13 MiB) | FBX `bridge-straight`, `bridge-straight-pillar`, `bridge-draw`, `door` seen. Gallery shows open masonry modules, gates, towers and timber platforms. |
| [Kenney Retro Urban Kit 2.0](https://kenney.nl/assets/retro-urban-kit) | 120 | 2,161,463 (2.06 MiB) | FBX balconies, ladder pieces, awnings and barriers seen. Gallery shows modular brick facades, stairs and roof pieces. |
| [Kenney Factory Kit 3.0](https://kenney.nl/assets/factory-kit) | 140 | 4,511,890 (4.30 MiB) | FBX entries and box variants seen. Gallery shows pipes/elbows, service platforms, supports, barriers, belts and machinery. |
| [Kenney Train Kit 1.1](https://kenney.nl/assets/train-kit) | 100 | 5,266,588 (5.02 MiB) | FBX rail corners/ramps seen. Gallery shows passenger cars, locomotives, freight cars, containers and tracks. |

All eight are CC0 on their own publisher pages. **Deduplicated total: 38,303,650 bytes (36.53 MiB)** before the optional snow material. Acquire each once into bounded staging outside the game; select one mesh format and required dependencies. Never copy the complete pack, isometric renders, sample scenes or alternate exports into `assets/`.

Kenney's [current import guide](https://kenney.nl/knowledge-base/game-assets-3d/importing-3d-models-into-game-engines) recommends GLB for Godot and explains that its glTF is distributed as GLB. It also warns that each pack requires its own associated textures. **That general guidance is not a per-pack GLB inventory**: use GLB if the acquired archive actually supplies it; otherwise inspect/convert the verified FBX. Neither OBJ nor GLB was confirmed individually in these eight archive prefixes.

**Not published/verified for the selected meshes:** metre scale, bounds, pivots, triangle counts, LODs, collision, atlas dimensions and texture dependency counts. Product pages and the inspected gallery images do not establish these. Do not invent “1 m modules,” “under 500 triangles” or “one 256 px atlas.” Normalize against the current metre-based player/hull, measure representative mesh bounds and count triangles/material surfaces after acquisition. A gallery render is not a scale reference.

## One complementary texture, rather than another material library

Choose [Poly Haven Snow 02](https://polyhaven.com/a/snow_02), by Rob Tuytel, for Whiteout's snow surfaces. Its [info API](https://api.polyhaven.com/info/snow_02) reports a **2 × 2 m repeat** and maximum **8192 × 8192** resolution. Use the **1K** files below, whose actual access was checked against the [files API](https://api.polyhaven.com/files/snow_02). The API names the diffuse channel `Diffuse`, not `diff`.

| Selected file | Exact bytes | Upstream API MD5 |
|---|---:|---|
| [1K diffuse JPG](https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/snow_02/snow_02_diff_1k.jpg) | 325,497 | `fc54766c6b36ff298699115a619d440b` |
| [1K OpenGL normal PNG](https://dl.polyhaven.org/file/ph-assets/Textures/png/1k/snow_02/snow_02_nor_gl_1k.png) | 2,118,417 | `57d7f4e2501db746c862c6efee9fb38f` |
| [1K ARM PNG](https://dl.polyhaven.org/file/ph-assets/Textures/png/1k/snow_02/snow_02_arm_1k.png) | 1,050,377 | `4dc88ca22b319dc7ac5e1ae139be8ce8` |

Total **3,494,291 bytes (3.33 MiB)**; all chosen downloads together **41,797,941 bytes (39.86 MiB)**. These are API MD5s, not locally verified full-file hashes: only 128-byte prefixes were read. At acquisition, verify the full bytes/checksums, retain SHA-256s, and record any conversion. No displacement, tessellation, 4K material bundle or HDRI is needed. The current kit already has OpenGL normals and ARM conventions; adapt snow deliberately, without overwriting its existing material definitions. Snow appearance must not silently change traction.

## Five palettes that produce different routes

The mesh counts and compositions here are **design targets**, not measured inventories. Descriptions identify gallery-visible asset roles unless an exact filename is explicitly marked above. Match the actual filenames during acquisition. Reuse an imported source across worlds, but author each route around different structures.

### Breakwater: cargo handling, water and overlapping heights

**Palette:** Watercraft Kit plus City Kit (Industrial); reuse a few Factory Kit pipes/supports only if the harbor worker needs them. Select roughly **10–14 unique meshes**: two container forms, a cargo barge, a tug, two warehouse/utility silhouettes, dock modules, a tank, and restrained hardware. The galleries establish useful harbor content without requiring a ship-sized scan pack.

**Functional composition:** a sheltered warehouse loading apron becomes checkpoint one; staggered container roofs turn the strafe line across the water, rather than straight down a block lane. A barge deck is an actual lower catch/recovery route. A higher service crossing around tanks leads into an original crane-side catwalk and the lighthouse-side finish. Crane frame, lighthouse and connecting catwalks are original authored work where stock parts do not fit. Containers supply recognisable landing mass, not decorative shells surrounding invisible boxes elsewhere.

**Fit:** Kenney's mechanical silhouettes can sit on the current scanned concrete docks if their painted colours are muted and their scale is normalized. Keep saturated shipping colours to a few large patches. Avoid whole toy cruise ships, pirate galleons and all container colours at once. Do not force a second asset choice onto the first Breakwater slice; this is a menu for that worker to reconcile with its actual imported props.

### Whiteout Relay: service compound, exposed ridge, radar landmark

**Palette:** Space Kit exterior service buildings/pads, **3–4** Nature Kit cliff/rock/conifer forms, shared Factory Kit pipes/supports, and Snow 02. Target **10–14 unique meshes**. Exclude spaceships, astronauts, rockets, alien terrain and the pack's isometric PNGs.

**Functional composition:** start in a warm maintenance shelter, use a service-building roof to reach the ridge, and follow a long exposed curve around a radar plinth. A landing pad is a broad readable checkpoint, with a lower pipe gallery providing shelter and recovery. Cliff shoulders provide visible landings; snow caps cannot hide the edge or manufacture collision bumps. The ridge and plinth arrange space differently from the harbor's stacked cargo and water gaps.

**Missing hero, explicitly:** a specific ready-made radar dish/radome is **not verified in the accessible Kenney selection**. Plan one original radar crown, or replace it with a Quaternius Cyberpunk dish/antenna only after binary access works and the mesh is inspected. Do not buy/download a giant space pack on an assumption that “space” means “radar.” The proposed external buildings, pads, rocks and service hardware still establish the station around that hero.

**Fit:** white/off-white painted service modules and the existing steel/concrete suit the setting. Tune snow's tiny normal contrast down at running distance. Warm interiors and a dark ridge are visual navigation, not changes to movement settings.

### Sunken Court: open masonry and vegetation make the route

**Palette:** Castle Kit open gates/walls, bridge segments, tower/column forms and timber pieces, plus **4–5** Nature Kit plants/rocks/logs. Target **12–16 unique meshes**. Remove blue-roofed castle silhouettes, weapons, siege engines, flags and most intact towers. Use weathered stone-facing materials on appropriate structural surfaces; retain plants' intended material handling.

**Functional composition:** three connected sunken courtyards, a broken elevated aqueduct, and an open arch turn. Broad masonry capstones and column tops become landings. The easy route passes under the aqueduct into a courtyard checkpoint; an earned faster line stays on its top. A visibly low side passage can require crouch once the real hull is proven. Vegetation grows at route edges, in cracks and below the aqueduct, leaving readable landing centres.

**Fit:** this is the accessible fallback to Quaternius's stronger ready-made ruins. Castle Kit is visibly intact/stylized in its gallery; **broken silhouettes, missing spans and overgrowth are required authored changes**, not a green tint that gets called ruins. Use the current concrete only on quiet floor/cap surfaces, not as a universal override that erases the stone/plant distinction. No floating solid hedge masquerading as a traversable gap.

### Rainline: brick canyons, balconies and service ducts

**Palette:** Retro Urban Kit facades, balconies, awnings and stairs, plus a small Factory Kit selection for rooftop pipes, machinery and supports. Target **12–16 unique meshes**. Confirm a suitable stock duct/HVAC mesh at acquisition; otherwise author a few elbows/caps around the selected hardware instead of importing another whole city kit.

**Functional composition:** a roof edge carries the first turn, a balcony/scaffold catches failure, and a maintenance duct crosses into the next roof's checkpoint. Put a real low crossbeam above a clearly visible duct landing to reward an intentional crouch hop. A later S-shaped route crosses two streets and returns via service stairs. Facades create street depth and navigable height, rather than sitting behind a freestanding platform course.

**Fit:** Retro Urban is deliberately pixel-textured in the gallery, unlike the scanned kit. Keep those facades farther from the camera; give traversed roof caps a consistent existing concrete/metal treatment, and use only a small muted material family on near hardware. This needs a native moving-view check before multiplying the district. If the texture-scale difference stays obvious, prefer a coherent industrial roof district over mixing two incompatible near-field looks.

**Rain:** use bounded particles/streaks and small intentional wet patches. A “wet” surface is not automatically a mirror; preserve brighter landing edges. Broad transparent rain sheets, overdraw and dark reflective roofs can make a good route unreadable.

### Night Shift: trains, maintenance bays and station architecture

**Palette:** Train Kit passenger cars and tracks, Factory Kit supports/pipes/machinery, and one or two shared Industrial Kit utility buildings. Target **12–16 unique meshes**; choose one train family, not every locomotive era. Build an original open station canopy, beams and platform edges to join the sourced content.

**Functional composition:** train roofs carry a long speed line; maintenance pit crossings create a tight alternating rhythm; an overhead service gallery creates a broader second corner rhythm before the final platform. Station platforms are useful checkpoint islands and recovery routes. Static trains are reachable geometry with deliberate roof proxies. Roof vents, pantographs and couplings must not cause tiny collision catches along the approved fast line.

**Fit:** Train and Factory galleries share simplified mechanical forms more readily than a realistic rail scan would. Use a small blue-grey/metal palette, existing concrete platforms and a few original emissive signage strips. Night identity comes from transit layout, canopy rhythm and lighting. Large emissive strips can establish neon without depending on bloom; no untested renderer feature is needed.

## Better-looking alternatives that are not currently ready to acquire

| Candidate | Verified publisher facts / accessible listing | Decision |
|---|---|---|
| [Quaternius Ultimate Modular Ruins](https://quaternius.com/packs/ultimatemodularruins.html) | CC0, 90 models; FBX/OBJ/Blend. Linked Drive lists `Arch_Round.obj` (~138 kB), `BridgeSection.obj` (~100 kB), columns and bushes. Texture folder lists `Bark_Texture.jpg` (~235 kB) and `Leaf_Texture.png` (~116 kB). These displayed sizes are rounded. | Best thematic ruins alternative. Direct arch and licence downloads returned quota HTML. Use Castle/Nature fallback now; do not claim this is acquired. |
| [Quaternius Cyberpunk Game Kit](https://quaternius.com/packs/cyberpunkgamekit.html) | CC0, 71 models; FBX/OBJ/Blend/glTF. Publisher gallery shows platforms, trusses, dishes, signs and HVAC. Drive lists `AC_Side`, `AC_Stacked`, `Antenna_1`, `Antenna_2`, cables and computers. `AC_Side.gltf` ~43 kB, `AC_Stacked.gltf` ~462 kB; texture folder lists a ~314 kB sign PNG. | Strong rooftop/relay upgrade if access recovers. Antenna and licence download tests returned quota HTML. No assumption that standalone glTF includes all dependencies. |
| [Quaternius Ultimate Nature](https://quaternius.com/packs/ultimatenature.html) | CC0, 150 models; FBX/OBJ/Blend. Drive includes snowy birch variants. [Publisher-owned itch page](https://quaternius.itch.io/150-lowpoly-nature-models) advertises a ~21 MB ZIP, but its actual binary endpoint was not tested. | Keep Kenney Nature to avoid a second foliage style and another pack. Drive licence download blocked. Itch is an unverified alternate route, not an access success. |
| [Quaternius Modular Train](https://quaternius.com/packs/modulartrain.html) | CC0, 15 models; FBX/OBJ/Blend. Drive lists cargo containers, straight/curved track, high-speed front/wagon meshes. | Kenney Train supplies a verified download route and broader track variety. Quaternius licence test blocked; no full-pack size verified. |
| [Quaternius Downtown City MegaKit](https://quaternius.com/packs/downtowncitymegakit.html) | Page advertises 315 models, shared textures and a free portion; it distinguishes a fuller Source version with engine integrations and source files. | Reject for this pass: larger scope, tier boundaries and texture/material integration work. Do not infer that a free page grants the entire Source package. No binary endpoint tested. |
| [Kenney Modular Space Kit](https://kenney.nl/assets/modular-space-kit) | CC0, 40 files; ZIP response 6,966,606 bytes. FBX corridor/cable entries and in-pack CC0 notice verified. | Good sci-fi interior kit, but its gallery's rounded corridor panels would push Night Shift toward a spaceship. Not needed for open transit works. |
| [Kenney Building Kit](https://kenney.nl/assets/building-kit) | CC0, 80 files; ZIP response 1,598,905 bytes. FBX barricade/opening entries and notice verified. | Small, but no need to import another architectural family for generic walls. |

The Quaternius Drive HTML listings inspected here are **partial** where they stop at 50 entries. They do not establish the complete pack size, absence of a desired prop, total textures or actual mesh complexity. No triangles, dimensions or texture resolutions were published in the inspected older pack pages. The ZIP/Drive numbers above are not performance estimates.

## Compatibility and failure traps

The current kit is verified locally in [ART.md](../momentum/ART.md), [MANIFEST.json](../../assets/momentum/MANIFEST.json) and `scripts/momentum_materials.gd`: four 1K Poly Haven sets, metre-based mapping, concrete/brick/steel/ochre families, and original rail proxies. Publisher previews support the palette judgments above; they do not prove that an imported prop matches those materials under the actual game lighting.

1. **Keep imported material structure.** The existing `instance_prop` helper assigns a single override to its original rails. Applying that approach to a multi-material train/building can erase windows, signs or vegetation. Adapt selectively; don't overwrite everything with `steel` or the current top/side shader.
2. **Separate structural collisions from visual detail.** Container tops, barge decks, roof caps and platforms need simple stable proxies aligned with visible surfaces. Pipes/rails are only non-colliding if outside the reachable route and clearly dressing. An accessible solid must have intentional collision. Never auto-generate a box across an open arch or doorway.
3. **Do not trust decorative meshes as a course hull.** Rail sleepers, container ribs, roof vents, tiny bevels and train couplings can catch a bhop hull. Keep intentional barriers accurate, but use authored broad top surfaces for the actual run. Do not place invisible rescue floors or a collider beyond a visible landing edge.
4. **Check texture scale and pivots before repetition.** Miniature buildings scaled up can make doors absurdly tall and painted details huge. Imported scale transforms, origin offsets, normals and multi-surface draw calls need measurement, not guesses from “low poly.” Instancing saves submission overhead only when implemented; it does not remove triangle/material cost.
5. **Budget retained assets, not archive marketing counts.** Proposal: at most **8 MiB of selected mesh/dependency source per world**, shared assets counted once, and **12 MiB of additional texture source across R15**. These are adjustable targets, not measurements or acceptance requirements. Keep only required atlas images, use mipmaps, and measure imported size/material surfaces after conversion. Archive size is not VRAM size.
6. **Preserve materials appropriate to the renderer.** No imported high-end shader graphs, blanket transparent foliage, full-scene wet reflections or enormous HDRI downloads. Match the current renderer through a native moving-view sample before extending a style to the whole map. This research does not establish a frame-rate gain.
7. **Preserve provenance through adaptation.** Eventually record pack/version, publisher URL, local original SHA-256, selected filenames, conversion steps, derived hashes, scale changes and collision policy. Keep notices in the portable delivery. The research manifest is not a substitute for the final shipped asset manifest.

## Receipts and hashes

The private directory holds exact compressed publisher/licence HTML, selected original publisher preview images, Drive listing excerpts, API JSON, ZIP header/prefix summaries and the quota-error responses. `SHA256SUMS` hashes every retained receipt; `RECEIPTS.json` records byte count and method. `page-index.json` records **uncompressed original page SHA-256** separately from the compressed receipt hash. The manifest keeps essential publisher-page and licence hashes so the original licence evidence is identifiable even if a publisher changes its page.

Essential exact-text SHA-256s:

| Receipt | SHA-256 |
|---|---|
| `CC0-1.0-legalcode.txt` | `a2010f343487d3f7618affe54f789f5487602331c0a8d03f49e9a7c547cf0499` |
| `kenney-watercraft-License.txt` | `f5f520f81277128fb422aebe334d2f08e6d8e5f7face6008885d8ff920253724` |
| `kenney-industrial-License.txt` | `60a8c5c31191256ec9779dc18745dea6d69c46f4b29703459ce064c1765a59ea` |
| `kenney-castle-License.txt` | `aac944f18106b3a3e29c6fdeec02523d4cab4c735abc01f5a8fa88a79ae173ef` |
| `kenney-retro-urban-License.txt` | `83d0de4f34000323da12cf54bc542dbc24ba48cfad101510dccddaa69483ebeb` |
| `kenney-factory-License.txt` | `61e86565dd297e143ad631594980eda0a17fc81a4cd7c6d71acf2f5e0cad30b6` |
| `kenney-train-License.txt` | `8ad3a0453dc1416d54e9af692dafe875a24069d577fe64edb193d3c8d868881a` |
| Poly Haven licence page, uncompressed HTML | `6f4f617c936d14d5a80db6a2ebec145c79277a760672501eef51bff7a0d4cbba` |

Space/Nature's in-pack notices and every full archive hash remain to be captured by the actual importer. No licence hash in this table is a hash of a complete asset pack. No quota page is filed as a licence.
