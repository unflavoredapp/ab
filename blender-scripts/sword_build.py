#!/usr/bin/env python3
"""Builds Resources/airblade_sword.glb from the Sword01 texture set (BaseColor / Height / Metallic).
The texture is an atlas: blade (two faces, left strip), wooden grip, ridged guard band, round pommel.
The sword stands along +Y (pommel at y=0, tip up), metres.   usage: sword_build.py tex_dir out.glb"""
import sys, os, io, json, struct, math
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hero_build import Part, Node, nrm, euler_quat  # noqa: E402

# atlas regions (u, v in 0..1, v down)
BLADE_F = (0.036, 0.092, 0.035, 0.975)   # u0, u1, v_tip, v_base
BLADE_B = (0.103, 0.162, 0.035, 0.975)
GRIP = (0.21, 0.40, 0.69, 0.93)
GUARD = (0.46, 0.97, 0.44, 0.62)
POMMEL = (0.80, 0.77, 0.07)               # disc centre u, v, radius

def blade(part, y0, L, w0, t):
    """diamond-section blade from y0 to y0+L, tapering to a point over the last 14%"""
    n = 24
    def width(f): return w0 if f < 0.86 else w0 * max(0.0, (1 - f) / 0.14)
    for (u0, u1, vt, vb), zs in ((BLADE_F, 1), (BLADE_B, -1)):
        P, N, UV, I = [], [], [], []
        for k in range(n + 1):
            f = k / n; y = y0 + L * f; w = width(f)
            v = vb + (vt - vb) * f
            for sx in (-1, 0, 1):
                x = sx * w / 2; z = 0 if sx != 0 else zs * t / 2
                P.append((x, y, z))
                N.append(nrm((sx * 0.35, 0, zs * 1.0)))
                UV.append((u0 + (sx + 1) / 2 * (u1 - u0), v))
        for k in range(n):
            a = k * 3; b = a + 3
            for c in (0, 1):
                q = [a + c, a + c + 1, b + c, b + c, a + c + 1, b + c + 1]
                if zs < 0: q = [q[0], q[2], q[1], q[3], q[5], q[4]]
                I += q
        part.tri_list("steel", P, N, UV, I)

def wrap_cyl(part, m, y0, y1, r0, r1, region, seg=16):
    u0, u1, v0, v1 = region
    P, N, UV, I = [], [], [], []
    for k, (y, r) in enumerate(((y0, r0), (y1, r1))):
        for s in range(seg + 1):
            a = 2 * math.pi * s / seg
            P.append((math.cos(a) * r, y, math.sin(a) * r)); N.append((math.cos(a), 0, math.sin(a)))
            UV.append((u0 + (u1 - u0) * s / seg, v1 + (v0 - v1) * k))
    for s in range(seg):
        a, b = s, s + seg + 1
        I += [a, b, a + 1, a + 1, b, b + 1]
    part.tri_list(m, P, N, UV, I)

def guard(part, y, w, h, d):
    u0, u1, v0, v1 = GUARD
    hx, hy, hz = w / 2, h / 2, d / 2
    def quad(a, b, c, dd, n):
        part.tri_list("steel", [a, b, c, dd], [n] * 4, [(u0, v1), (u1, v1), (u1, v0), (u0, v0)], [0, 1, 2, 0, 2, 3])
    Y0, Y1 = y - hy, y + hy
    quad((-hx, Y0, hz), (hx, Y0, hz), (hx, Y1, hz), (-hx, Y1, hz), (0, 0, 1))
    quad((hx, Y0, -hz), (-hx, Y0, -hz), (-hx, Y1, -hz), (hx, Y1, -hz), (0, 0, -1))
    quad((-hx, Y1, hz), (hx, Y1, hz), (hx, Y1, -hz), (-hx, Y1, -hz), (0, 1, 0))
    quad((-hx, Y0, -hz), (hx, Y0, -hz), (hx, Y0, hz), (-hx, Y0, hz), (0, -1, 0))
    quad((hx, Y0, hz), (hx, Y0, -hz), (hx, Y1, -hz), (hx, Y1, hz), (1, 0, 0))
    quad((-hx, Y0, -hz), (-hx, Y0, hz), (-hx, Y1, hz), (-hx, Y1, -hz), (-1, 0, 0))

def pommel(part, c, r):
    cu, cv, cr = POMMEL
    lat, lon = 8, 14
    P, N, UV, I = [], [], [], []
    for i in range(lat + 1):
        th = math.pi * i / lat
        for j in range(lon + 1):
            ph = 2 * math.pi * j / lon
            d = (math.sin(th) * math.cos(ph), math.cos(th), math.sin(th) * math.sin(ph))
            P.append((c[0] + d[0] * r, c[1] + d[1] * r * 1.1, c[2] + d[2] * r)); N.append(d)
            UV.append((cu + math.sin(th) * math.cos(ph) * cr, cv + math.sin(th) * math.sin(ph) * cr))
    for i in range(lat):
        for j in range(lon):
            a = i * (lon + 1) + j; b = a + lon + 1
            I += [a, b, a + 1, a + 1, b, b + 1]
    part.tri_list("steel", P, N, UV, I)

def build():
    root = Node("airblade_sword"); p = root.part
    pommel(p, (0, 0.02, 0), 0.03)
    wrap_cyl(p, "wood", 0.035, 0.24, 0.019, 0.017, GRIP)
    guard(p, 0.26, 0.22, 0.035, 0.045)
    wrap_cyl(p, "steel", 0.275, 0.30, 0.022, 0.02, GUARD, seg=12)
    blade(p, 0.29, 0.86, 0.055, 0.012)
    return root

def jpg(path, size, mode="RGB"):
    im = Image.open(path).convert(mode).resize((size, size), Image.LANCZOS)
    b = io.BytesIO(); im.convert("RGB").save(b, "JPEG", quality=88); return b.getvalue()

def write(root, tex_dir, out):
    binbuf = bytearray(); views = []; accs = []; meshes = []; nodes = []
    mats_order = ["steel", "wood"]
    def view(data, target=None):
        while len(binbuf) % 4: binbuf.append(0)
        v = dict(buffer=0, byteOffset=len(binbuf), byteLength=len(data))
        if target: v["target"] = target
        views.append(v); binbuf.extend(data); return len(views) - 1
    def acc(arr, ctype, typ, target, mm=False):
        a = np.asarray(arr, dtype=np.float32 if ctype == 5126 else np.uint32)
        d = dict(bufferView=view(a.tobytes(), target), componentType=ctype, count=int(len(a)), type=typ)
        if mm: d["min"] = a.min(0).tolist(); d["max"] = a.max(0).tolist()
        accs.append(d); return len(accs) - 1
    prims = []
    for m, g in root.part.d.items():
        prims.append(dict(attributes=dict(POSITION=acc(g["p"], 5126, "VEC3", 34962, True), NORMAL=acc(g["n"], 5126, "VEC3", 34962),
                                          TEXCOORD_0=acc(g["uv"], 5126, "VEC2", 34962)),
                          indices=acc(g["i"], 5125, "SCALAR", 34963), material=mats_order.index(m)))
    meshes.append(dict(name="sword", primitives=prims))
    nodes.append(dict(name="airblade_sword", mesh=0))
    base = view(jpg(os.path.join(tex_dir, "Sword01_BaseColor.png"), 1024))
    height = view(jpg(os.path.join(tex_dir, "Sword01_Height.png"), 512, "L"))
    images = [dict(bufferView=base, mimeType="image/jpeg"), dict(bufferView=height, mimeType="image/jpeg")]
    textures = [dict(source=0), dict(source=1)]
    materials = [
        dict(name="steel", pbrMetallicRoughness=dict(baseColorFactor=[1, 1, 1, 1], baseColorTexture=dict(index=0), metallicFactor=0.85, roughnessFactor=0.35),
             normalTexture=dict(index=1, scale=0.4), doubleSided=True),
        dict(name="wood", pbrMetallicRoughness=dict(baseColorFactor=[1, 1, 1, 1], baseColorTexture=dict(index=0), metallicFactor=0.0, roughnessFactor=0.8),
             normalTexture=dict(index=1, scale=0.5)),
    ]
    js = dict(asset=dict(version="2.0", generator="airblade sword_build.py"), scene=0, scenes=[dict(nodes=[0])], nodes=nodes, meshes=meshes,
              materials=materials, accessors=accs, bufferViews=views, buffers=[dict(byteLength=len(binbuf))], images=images, textures=textures)
    j = json.dumps(js, separators=(",", ":")).encode()
    while len(j) % 4: j += b" "
    while len(binbuf) % 4: binbuf.append(0)
    with open(out, "wb") as f:
        f.write(b"glTF" + struct.pack("<II", 2, 28 + len(j) + len(binbuf)))
        f.write(struct.pack("<I", len(j)) + b"JSON" + j)
        f.write(struct.pack("<I", len(binbuf)) + b"BIN\0" + bytes(binbuf))
    return os.path.getsize(out)

if __name__ == "__main__":
    root = build()
    print("bytes", write(root, sys.argv[1], sys.argv[2]))
