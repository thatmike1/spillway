# Poly Haven textures

The four texture sets under `assets/momentum/textures/` come from Poly Haven (https://polyhaven.com). On 7 November 2026 its licence page (https://polyhaven.com/license) said that every asset on the site is published under CC0 1.0. Under that licence they may be used for any purpose, including commercially, and redistributed inside a product, with no attribution required. The Creative Commons legal code is copied unchanged in `CC0-1.0-legalcode.txt`, retrieved from https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt.

The page text itself is Poly Haven's copyright, so this repository does not copy it. Snapshots of the licence page and the API terms page, with their SHA-256 hashes, are kept outside Git in the R13 material-kit evidence (`sources/licences/`).

Files were fetched through the public API (https://api.polyhaven.com) with a unique User-Agent, as its terms require. The game never calls that API. Credit is not required, but the kit records the authors anyway, as the API reports them, per set in `MANIFEST.json`: Rob Tuytel (Concrete Layers 02, Metal Plate 02, Red Brick), and Dimitrios Savva (photography) with Dario Barresi (processing) for Brushed Concrete.

The rail props in `props/` are original work for Spillway, made by `make_rail.py`, and are dedicated under CC0 1.0 as well.
