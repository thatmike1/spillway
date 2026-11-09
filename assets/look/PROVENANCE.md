# Original look-C assets

`cloud-sky.png` was generated for this experiment on 9 November 2026 using OpenAI's built-in image generation tool. No external image was supplied to that generation call. The local concept images informed the written direction only; they are private references and are not packed into the game. No named artist, copyrighted character or borrowed texture was requested. The generated image is an original project asset, not a downloaded stock asset. Its generation prompt is in `sky-prompt.txt`.

`painted-wear.png` is original deterministic mathematical texture work. `tools/generate-look-wear.py` regenerates its periodic multiscale value-noise mask using seed 431 and only the Python standard library. The red channel controls broad paint chips; the green channel supplies restrained top-plane variation. It has no photographic or third-party input.

The three shaders and structural-ink mesh generator are original code. They preserve the existing collision meshes. The sky is a static panorama and does not require cloud simulation or continuously refreshed radiance maps.

All original R15 assets remain in the portable package for the old-look toggle and other maps, with their existing licences and manifests. Breakwater's Poly Haven kit is CC0; see `assets/r15/breakwater/MANIFEST.json` and its included licence. The original material kit, Kenney assets and runtime have their own bundled notices. This document does not relicense them.
