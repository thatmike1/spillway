#!/usr/bin/env python3
"""write a small periodic brush-mask texture from original deterministic math."""
import math
import random
import struct
import zlib
from pathlib import Path
r = random.Random(431)
grids = {n: [[r.random() for x in range(n)] for y in range(n)] for n in (8,16,32,64)}
def noise(x, y, n):
    xx, yy = x*n/256, y*n/256
    ix, iy = int(xx), int(yy)
    u, v = xx-ix, yy-iy
    u, v = u*u*(3-2*u), v*v*(3-2*v)
    g = grids[n]
    return (g[iy%n][ix%n]*(1-u)+g[iy%n][(ix+1)%n]*u)*(1-v)+(g[(iy+1)%n][ix%n]*(1-u)+g[(iy+1)%n][(ix+1)%n]*u)*v
raw = bytearray()
for y in range(256):
    raw.append(0)
    for x in range(256):
        v = noise(x,y,8)*0.58+noise(x,y,16)*0.25+noise(x,y,32)*0.12+noise(x,y,64)*0.05
        q = max(0,min(255,int(v*255)))
        g = max(0,min(255,int(115+noise(x,y,32)*30)))
        raw.extend((q,g,q))
def chunk(tag, data):
    return struct.pack('>I',len(data))+tag+data+struct.pack('>I',zlib.crc32(tag+data)&0xffffffff)
png = b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',256,256,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(raw))+chunk(b'IEND',b'')
(Path(__file__).resolve().parents[1]/'assets/look/painted-wear.png').write_bytes(png)
