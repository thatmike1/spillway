"""build the painted cloud atlases from original chroma-green paintings.

usage: python3 build_cloud_atlas.py SOURCE_DIR OUT_DIR   (needs pillow and numpy)

cumulus-a.png, cumulus-b.png (and cumulus-c.png, cumulus-d.png when present) each hold two clouds
(left and right half), packed into a 4x2 grid of cells; wisps.png holds four horizontal strips. each cloud is keyed off its #00FF00 ground, its painted value is kept as one
grey channel (shadow dark, lit side bright) with coverage in alpha, and it is packed bottom-aligned
into a cell so a card's bottom edge is the cloud's flat base. outputs are grey+alpha PNGs.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

CELL = (768, 512)
STRIP = (1536, 256)


def key(rgb):
    f = rgb.astype(np.float32) / 255.0
    r, g, b = f[..., 0], f[..., 1], f[..., 2]
    excess = g - np.maximum(r, b)
    alpha = np.clip(1.0 - excess * 1.08, 0.0, 1.0)
    alpha = np.where(alpha < 0.04, 0.0, alpha)
    # unmix the green ground from soft edges, then drop any remaining green spill.
    safe = np.maximum(alpha, 1e-3)[..., None]
    green = np.array([0.0, 1.0, 0.0], np.float32)
    colour = (f - (1.0 - alpha)[..., None] * green) / safe
    colour = np.clip(colour, 0.0, 1.0)
    colour[..., 1] = np.minimum(colour[..., 1], np.maximum(colour[..., 0], colour[..., 2]))
    value = colour @ np.array([0.2126, 0.7152, 0.0722], np.float32)
    return value, alpha


def normalise(value, alpha):
    solid = value[alpha > 0.9]
    lo, hi = np.percentile(solid, 1.5), np.percentile(solid, 99.7)
    return np.clip((value - lo) / max(hi - lo, 1e-3), 0.0, 1.0)


def crop(value, alpha, box):
    x0, y0, x1, y1 = box
    v, a = value[y0:y1, x0:x1], alpha[y0:y1, x0:x1]
    ys, xs = np.nonzero(a > 0.02)
    return v[ys.min():ys.max() + 1, xs.min():xs.max() + 1], a[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def place(v, a, size, bottom_margin=6, side_margin=8):
    w, h = size
    scale = min((w - 2 * side_margin) / v.shape[1], (h - bottom_margin - side_margin) / v.shape[0])
    nw, nh = max(1, int(v.shape[1] * scale)), max(1, int(v.shape[0] * scale))
    vi = Image.fromarray((v * 255).astype(np.uint8)).resize((nw, nh), Image.LANCZOS)
    ai = Image.fromarray((a * 255).astype(np.uint8)).resize((nw, nh), Image.LANCZOS)
    cell = Image.new("LA", size, (0, 0))
    ox, oy = (w - nw) // 2, h - bottom_margin - nh
    cell.paste(Image.merge("LA", (vi, ai)), (ox, oy))
    return cell


def main(source, out):
    source, out = Path(source), Path(out)
    sheets = [n for n in ["cumulus-a.png", "cumulus-b.png", "cumulus-c.png", "cumulus-d.png"] if (source / n).exists()]
    columns = 4 if len(sheets) > 2 else 2
    atlas = Image.new("LA", (CELL[0] * columns, CELL[1] * 2), (0, 0))
    index = 0
    for name in sheets:
        rgb = np.asarray(Image.open(source / name).convert("RGB"))
        value, alpha = key(rgb)
        value = normalise(value, alpha)
        h, w = alpha.shape
        for box in [(0, 0, w // 2, h), (w // 2, 0, w, h)]:
            v, a = crop(value, alpha, box)
            atlas.paste(place(v, a, CELL), ((index % columns) * CELL[0], (index // columns) * CELL[1]))
            index += 1
    atlas.save(out / "cloud-atlas.png", optimize=True)
    rgb = np.asarray(Image.open(source / "wisps.png").convert("RGB"))
    value, alpha = key(rgb)
    value = normalise(value, alpha)
    h, w = alpha.shape
    strips = Image.new("LA", (STRIP[0], STRIP[1] * 4), (0, 0))
    # strips are found as row bands separated by fully keyed rows.
    rows = alpha.max(axis=1) > 0.05
    bands, start = [], None
    for y, filled in enumerate(rows):
        if filled and start is None:
            start = y
        elif not filled and start is not None:
            if y - start > 8:
                bands.append((start, y))
            start = None
    if start is not None:
        bands.append((start, h))
    bands = sorted(bands, key=lambda b: b[1] - b[0], reverse=True)[:4]
    bands.sort()
    for i, (y0, y1) in enumerate(bands):
        v, a = crop(value, alpha, (0, y0, w, y1))
        strips.paste(place(v, a, STRIP, 4, 4), (0, i * STRIP[1]))
    strips.save(out / "wisp-atlas.png", optimize=True)
    print("bands", bands)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
