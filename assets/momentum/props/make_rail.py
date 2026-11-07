"""original edge railing for the momentum kit, written as self-contained gltf 2.0.

run: python3 -I assets/momentum/props/make_rail.py assets/momentum/props
origin is the foot of the first post on the deck surface; the section runs along +x,
+y is up, metres throughout. faces are flat shaded with uvs in metres.
"""
import base64
import json
import math
import pathlib
import struct
import sys

SECTION = 2.0  # post spacing
POST = 0.06  # square hollow section width
POST_TOP = 1.07
TOP_RAIL_R = 0.024  # 48 mm handrail, top at about 1.094
KNEE_Y = 0.55
KNEE_R = 0.021
PLATE = 0.16
PLATE_T = 0.012
# srgb d39a2e as linear, matching the kit's ochre paint.
OCHRE = [0.651, 0.323, 0.027, 1.0]


def quad(out, a, b, c, d):
    normal = cross(sub(b, a), sub(c, a))
    length = math.sqrt(dot(normal, normal))
    normal = [n / length for n in normal]
    # uv in metres on the dominant plane of the face.
    axis = max(range(3), key=lambda i: abs(normal[i]))
    u_axis, v_axis = [(2, 1), (0, 2), (0, 1)][axis]
    for tri in ((a, b, c), (a, c, d)):
        for p in tri:
            out.append((p, normal, (p[u_axis], -p[v_axis])))


def box(out, lo, hi):
    x0, y0, z0 = lo
    x1, y1, z1 = hi
    quad(out, (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1))  # +z
    quad(out, (x1, y0, z0), (x0, y0, z0), (x0, y1, z0), (x1, y1, z0))  # -z
    quad(out, (x1, y0, z1), (x1, y0, z0), (x1, y1, z0), (x1, y1, z1))  # +x
    quad(out, (x0, y0, z0), (x0, y0, z1), (x0, y1, z1), (x0, y1, z0))  # -x
    quad(out, (x0, y1, z1), (x1, y1, z1), (x1, y1, z0), (x0, y1, z0))  # +y
    quad(out, (x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1))  # -y


def tube(out, x0, x1, y, radius, sides=8):
    ring = [(math.cos(2 * math.pi * (i + 0.5) / sides) * radius,
             math.sin(2 * math.pi * (i + 0.5) / sides) * radius) for i in range(sides)]
    for i in range(sides):
        (ya, za), (yb, zb) = ring[i], ring[(i + 1) % sides]
        quad(out, (x0, y + ya, za), (x0, y + yb, zb), (x1, y + yb, zb), (x1, y + ya, za))
    # end caps as fans.
    for x, flip in ((x0, True), (x1, False)):
        for i in range(1, sides - 1):
            tri = [(x, y + ring[0][0], ring[0][1]), (x, y + ring[i][0], ring[i][1]),
                   (x, y + ring[i + 1][0], ring[i + 1][1])]
            if flip:
                tri.reverse()
            normal = (-1.0 if flip else 1.0, 0.0, 0.0)
            for p in tri:
                out.append((p, normal, (p[2], -p[1])))


def post(out):
    h = POST / 2
    box(out, (-h, PLATE_T, -h), (h, POST_TOP, h))
    p = PLATE / 2
    box(out, (-p, 0.0, -p), (p, PLATE_T, p))


def sub(a, b):
    return [a[i] - b[i] for i in range(3)]


def dot(a, b):
    return sum(a[i] * b[i] for i in range(3))


def cross(a, b):
    return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]


def write(path, name, vertices):
    positions = b"".join(struct.pack("<3f", *v[0]) for v in vertices)
    normals = b"".join(struct.pack("<3f", *v[1]) for v in vertices)
    uvs = b"".join(struct.pack("<2f", *v[2]) for v in vertices)
    blob = positions + normals + uvs
    lo = [min(v[0][i] for v in vertices) for i in range(3)]
    hi = [max(v[0][i] for v in vertices) for i in range(3)]
    count = len(vertices)
    gltf = {
        "asset": {"version": "2.0", "generator": "spillway make_rail.py",
                  "copyright": "original work for Spillway, CC0 1.0"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"name": name, "mesh": 0}],
        "meshes": [{"name": name, "primitives": [{
            "attributes": {"POSITION": 0, "NORMAL": 1, "TEXCOORD_0": 2}, "material": 0}]}],
        "materials": [{"name": "momentum_ochre", "pbrMetallicRoughness": {
            "baseColorFactor": OCHRE, "metallicFactor": 0.1, "roughnessFactor": 0.55}}],
        "buffers": [{"byteLength": len(blob),
                     "uri": "data:application/octet-stream;base64," + base64.b64encode(blob).decode()}],
        "bufferViews": [
            {"buffer": 0, "byteOffset": 0, "byteLength": len(positions), "target": 34962},
            {"buffer": 0, "byteOffset": len(positions), "byteLength": len(normals), "target": 34962},
            {"buffer": 0, "byteOffset": len(positions) + len(normals), "byteLength": len(uvs), "target": 34962}],
        "accessors": [
            {"bufferView": 0, "componentType": 5126, "count": count, "type": "VEC3", "min": lo, "max": hi},
            {"bufferView": 1, "componentType": 5126, "count": count, "type": "VEC3"},
            {"bufferView": 2, "componentType": 5126, "count": count, "type": "VEC2"}],
    }
    path.write_text(json.dumps(gltf, indent=1) + "\n")
    print(path, count // 3, "triangles", "bounds", lo, hi)


def main():
    folder = pathlib.Path(sys.argv[1])
    section = []
    post(section)
    tube(section, 0.0, SECTION, POST_TOP, TOP_RAIL_R)
    tube(section, POST / 2, SECTION - POST / 2, KNEE_Y, KNEE_R)
    write(folder / "rail_section.gltf", "rail_section", section)
    end = []
    post(end)
    write(folder / "rail_post.gltf", "rail_post", end)


main()
