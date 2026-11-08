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
