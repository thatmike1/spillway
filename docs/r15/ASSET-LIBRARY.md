# R15 has an imported source palette

Root acquired all eight shortlisted Kenney ZIPs from fresh publisher links. Full archives match the sizes previously observed, all members pass ZIP CRC, and each contains its own CC0 notice. Seven packs contribute selected source files to the shared library; the Watercraft archive was inspected but its selection stays with the Breakwater author. Three full Snow 02 files match Poly Haven's published MD5s. Space and Nature archive notices identify versions 2.0 and 2.1; the manifest keeps the research's earlier 1.0 labels separately rather than treating those as acquired versions.

The library is `assets/r15/library/`: 126 selected GLB models, required textures, original notices and the snow maps. Its 152 original-source files total 7,657,993 bytes, plus small metadata. No FBX/OBJ alternatives, complete packs, isometric previews or sample scenes are shipped in this library. All selected source bytes are unchanged. The choice of which models a course actually uses remains with that course's author.

- [Source and derived-file manifest](../../assets/r15/library/MANIFEST.json)
- [Measured model bounds and material costs](../../assets/r15/library/BOUNDS.json)
- [Notices](../../assets/r15/library/NOTICE.md)
- [Initial sourcing research](ASSET-RESEARCH.md)

All 126 selected GLBs load through pinned Godot 4.7.2 with zero import/measurement errors or warnings and no missing material surfaces. Their meshes contain 44,656 triangles in total, counting one unscaled instance of each source model. That sum is an inventory figure, not a frame-rate claim or final map cost. The probe does not prove collision or visual quality.

## Placement facts that change the maps

The accessible Space Kit includes `satelliteDish`, `satelliteDish_large` and `satelliteDish_detailed`. The initial research's radar sourcing gap is therefore resolved by a real acquired/imported model, not an original stand-in. Whiteout can use a dish while keeping its course layout original.

Several Space Kit scenes retain offset pivots. For example, `hangar_smallA` has an unscaled bounds minimum (1, 0, 0.5) and size (2, 1, 2); `satelliteDish_large` begins around x 1.576/z 1.032. Translate the visual inside a wrapper using BOUNDS.json's centered-foot suggestion before placing/scaling that wrapper. Other packs have negative wheel/catwalk/rock extents too. Never infer feet or dimensions from filenames. These measured source coordinates are not a publisher guarantee of metres.

Many Nature/Space models use flat material colours without an albedo texture; most other selected packs reference their own `Textures/` images. Those relative dependencies are preserved. A few urban scaffold surfaces are transparent, and the hangar has 9 material surfaces across 3 mesh instances. Preserve intended multi-material distinctions and budget repeated props by measured surfaces, not archive size.

A source bounds box is for placement, not automatic collision: it would close an arch or fill an open shed. Each map owns accurate simple route proxies, meaningful barriers and reachable prop collision. Long colliders should respect the documented engine cast limitations. Snow changes appearance only; the approved movement remains unchanged.

## Evidence and retention

Outer `checkpoints/spillway/r15/asset-acquisition/` keeps full-archive hashes and inventories, all acquired licence notices, selected-file hashes, measurement JSON, exact probe/acquisition scripts and error-free import logs. The original staging ZIPs were removed after all 152 retained source-file hashes were verified. CLEANUP.json records the removal. Reacquisition uses fresh signed publisher URLs. Native views, actual map usage, final collisions and packed dependencies remain later acceptance steps.

## Shared placement

`r15_assets.gd` places the acquired scenes using a separate pivot node. Original meshes, root transforms, materials and texture paths stay unchanged. Feet and yaw are in the parent's coordinates; scale is an explicit authored choice.

```gdscript
const ASSETS := preload("res://scripts/r15_assets.gd")
var model := "kenney-space/models/satelliteDish_large.glb"
var dish := ASSETS.place(self, model, Vector3(18, 8, -12), ASSETS.scale_for_height(model, 6.0), deg_to_rad(35))
```

The helper adds no collision. Place the route's intentional proxy separately, especially for arches and open buildings. Each visual stores its source-model identity for inspection. The 20-gate placement check traverses actual imported meshes under a transformed parent: the offset dish, compound hangar, open arch and subway all reach their requested foot, centre and height with materials intact and no implicit physics. This is a transform/dependency check, not native visual acceptance.

The new non-default `R15 Pack` export preset includes JSON explicitly because the placement helper reads measured bounds with FileAccess. The R14 presets and game default are unchanged. Final R15 packaging also needs recursive source-licence collection: R14's one-kit-level licence selector does not cover `assets/r15/library/licences/` or future per-map nested sources. Keeping licences inside the source tree alone is insufficient for the portable ZIP notices.

The same 20 placement gates pass when the helper, measured bounds and models load from a diagnostic PCK in an empty directory outside the checkout. This uses the pinned headless editor as the pack host, not the official release runtime; it is dependency/transform evidence, not final delivery acceptance. Logs and pack hash remain in outer `checkpoints/spillway/r15/asset-placement/`; the diagnostic pack, imports and profile were removed after checking. The explicit JSON filter follows [Godot's export documentation](https://docs.godotengine.org/en/stable/tutorials/export/exporting_projects.html#resource-options).
