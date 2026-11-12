# Repository origin and private references

This private repository preserves the Foldrunner/Spillway project history extracted from `ccChat-general` at source commit `dee210165b6f169b2433b3043712c5855c37d3b6`. The project is the repository root. Old source commit IDs in historical material refer to that source repository; they are not hashes in the rewritten history.

Before the first push, every reachable commit tree and every unique blob was checked. Four retired reconstruction-note paths were stripped from all history: `docs/CONTRACT.md`, `docs/FEEL-CONTRACT.md`, `docs/FEEL-RESULTS.md`, `docs/VERIFICATION.md`. They describe the superseded reconstruction's derived movement and camera contracts or their measured results. No current Spillway runtime file was removed by this privacy pass.

The private-reference tree available on the build laptop was hash-compared against the extracted blobs. The only match was an empty file. The concept-art reference directory was unavailable there, so its bytes could not be hash-compared. All historical image paths were enumerated and reviewed against the asset manifests and provenance: generated game skies and mathematical wear, Poly Haven CC0 kits, and licensed Kenney kits. No personal photo, moodboard, concept image, Mirror's Edge package or decompiled source was found. Mentioning an inspiration or prohibiting private content does not make the referenced content part of the repository.

Gitleaks 8.30.1's full history scan produced 78 generic-key alerts. Each was reviewed: 64 upstream public asset MD5 checksums, eight synthetic course identities, three build/pack identity checksums, two source-file SHA256 entries and one Godot key/preset list. None is a credential. The raw audit and review receipts stay outside the repository, with the handover results.

Keep personal photos, moodboards, private concept art, game files, decompiled source, private reverse-engineering specifications/notes and credentials outside this repository and its history. Only original game assets or assets with recorded redistribution rights belong here. See each `assets/` kit's manifest and licence.

Large release binaries belong in GitHub releases. The historical asset blobs and frozen parity fixtures fit ordinary Git: no individual blob approaches GitHub's 100 MiB limit, and these fixtures are immutable rather than frequently edited binary work files. Git LFS is not needed.
