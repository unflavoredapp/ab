#!/usr/bin/env python3
"""Builds Resources/airblade_hero.glb: the AIRBLADE hero (cleric / nun outfit) as a 3D model.

Pure python + numpy (no Blender needed). The body is static; the cloth is a set of chained panels
(coat back/sides, skirt flap, hood veil) whose node names the game animates with a wind sway:
    coat_back_0..2, coat_L_0..1, coat_R_0..1, flap_0..1, veil_0..1
Units: metres, +Y up, the hero faces +Z.   usage: hero_build.py out.glb face.png [preview.png]
"""
import sys, json, struct, math
import numpy as np
from PIL import Image

MATS = {}
def mat(name, rgb, metal=0.0, rough=0.7, tex=None, double=False):
    MATS[name] = dict(name=name, rgb=rgb, metal=metal, rough=rough, tex=tex, double=double)

mat("navy",   (0.12, 0.13, 0.22), 0.0, 0.8, double=True)
mat("coat",   (0.14, 0.15, 0.26), 0.0, 0.8, double=True)
mat("torso",  (0.16, 0.16, 0.21), 0.0, 0.7)
mat("white",  (0.86, 0.87, 0.91), 0.0, 0.6, double=True)
mat("gold",   (0.80, 0.57, 0.17), 0.7, 0.35)
mat("silver", (0.72, 0.74, 0.80), 0.7, 0.3)
mat("skin",   (0.78, 0.58, 0.46), 0.0, 0.7)
mat("legs",   (0.15, 0.09, 0.07), 0.0, 0.8)
mat("boot",   (0.17, 0.19, 0.29), 0.0, 0.7)
mat("red",    (0.55, 0.10, 0.08), 0.0, 0.7, double=True)
mat("pf", (1, 1, 1), 0.0, 0.85, tex=0)
mat("pb", (1, 1, 1), 0.0, 0.85, tex=1)


class Part:
    def __init__(self):
        self.d = {}   # mat -> dict(p, n, uv, i)
    def tri_list(self, m, P, N, UV, I):
        g = self.d.setdefault(m, dict(p=[], n=[], uv=[], i=[])); b = len(g["p"])
        g["p"] += [list(map(float, p)) for p in P]
        g["n"] += [list(map(float, n)) for n in N]
        g["uv"] += [list(map(float, u)) for u in UV]
        g["i"] += [b + k for k in I]


def nrm(v):
    v = np.asarray(v, float); l = np.linalg.norm(v)
    return v / l if l > 1e-9 else np.array([0, 1, 0.0])


def tube(part, m, pts, radii, seg=16, caps=True):
    pts = [np.array(p, float) for p in pts]
    P, N, UV, I = [], [], [], []
    xs = np.array([1.0, 0, 0])
    for k, c in enumerate(pts):
        d = nrm(pts[min(k + 1, len(pts) - 1)] - pts[max(k - 1, 0)])
        u = nrm(xs - d * np.dot(xs, d)); v = np.cross(d, u)
        rx, rz = radii[k]
        for s in range(seg + 1):
            a = 2 * math.pi * s / seg
            ca, sa = math.cos(a), math.sin(a)
            P.append(c + u * rx * ca + v * rz * sa)
            N.append(nrm(u * ca / max(rx, 1e-4) + v * sa / max(rz, 1e-4)))
            UV.append((s / seg, k / max(1, len(pts) - 1)))
    for k in range(len(pts) - 1):
        for s in range(seg):
            a = k * (seg + 1) + s; b = a + seg + 1
            I += [a, b, a + 1, a + 1, b, b + 1]
    part.tri_list(m, P, N, UV, I)
    if caps:
        for end, sign in ((0, -1), (len(pts) - 1, 1)):
            c = pts[end]; d = nrm(pts[min(end + 1, len(pts) - 1)] - pts[max(end - 1, 0)]) * sign
            u = nrm(xs - d * np.dot(xs, d)); v = np.cross(d, u)
            rx, rz = radii[end]
            CP = [c] + [c + u * rx * math.cos(2 * math.pi * s / seg) + v * rz * math.sin(2 * math.pi * s / seg) for s in range(seg)]
            CI = []
            for s in range(seg):
                CI += [0, 1 + s, 1 + (s + 1) % seg] if sign > 0 else [0, 1 + (s + 1) % seg, 1 + s]
            part.tri_list(m, CP, [d] * len(CP), [(0.5, 0.5)] * len(CP), CI)


def ellipsoid(part, m, c, r, lat=12, lon=20, keep=None, uvf=None, grow=1.0):
    c = np.array(c, float); r = np.array(r, float) * grow
    P, N, UV = [], [], []
    for i in range(lat + 1):
        th = math.pi * i / lat
        for j in range(lon + 1):
            ph = 2 * math.pi * j / lon
            d = np.array([math.sin(th) * math.sin(ph), math.cos(th), math.sin(th) * math.cos(ph)])
            P.append(c + d * r); N.append(nrm(d / r))
            UV.append(uvf(d) if uvf else (j / lon, i / lat))
    I = []
    for i in range(lat):
        for j in range(lon):
            a = i * (lon + 1) + j; b = a + lon + 1
            cen = (P[a] + P[a + 1] + P[b] + P[b + 1]) / 4 - c
            if keep and not keep(cen / r): continue
            I += [a, b, a + 1, a + 1, b, b + 1]
    part.tri_list(m, P, N, UV, I)


def rot_xz(ax, az):
    cx, sx = math.cos(math.radians(ax)), math.sin(math.radians(ax))
    cz, sz = math.cos(math.radians(az)), math.sin(math.radians(az))
    Rx = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]]); Rz = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
    return Rx @ Rz


def quad(part, m, a, b, c, d):
    a, b, c, d = [np.array(v, float) for v in (a, b, c, d)]
    n = nrm(np.cross(b - a, d - a))
    part.tri_list(m, [a, b, c, d], [n] * 4, ((0, 0), (1, 0), (1, 1), (0, 1)), [0, 1, 2, 0, 2, 3])


def box(part, m, c, s, ax=0, az=0):
    R = rot_xz(ax, az); c = np.array(c, float); h = np.array(s, float) / 2
    def V(x, y, z): return c + R @ (np.array([x, y, z]) * h)
    quad(part, m, V(-1, -1, 1), V(1, -1, 1), V(1, 1, 1), V(-1, 1, 1))
    quad(part, m, V(1, -1, -1), V(-1, -1, -1), V(-1, 1, -1), V(1, 1, -1))
    quad(part, m, V(1, -1, 1), V(1, -1, -1), V(1, 1, -1), V(1, 1, 1))
    quad(part, m, V(-1, -1, -1), V(-1, -1, 1), V(-1, 1, 1), V(-1, 1, -1))
    quad(part, m, V(-1, 1, 1), V(1, 1, 1), V(1, 1, -1), V(-1, 1, -1))
    quad(part, m, V(-1, -1, -1), V(1, -1, -1), V(1, -1, 1), V(-1, -1, 1))


def panel(part, m, wt, wb, h, t, trim=True, hem=False, ovl=0.012):
    """trapezoid cloth panel hanging from y=0 down to y=-h (pivot = top centre)."""
    H = h + ovl; ht = t / 2
    def V(sx, sz, bottom): return (sx * (wb if bottom else wt) / 2, -H if bottom else 0, sz * ht)
    quad(part, m, V(-1, 1, 1), V(1, 1, 1), V(1, 1, 0), V(-1, 1, 0))      # front  (+z)
    quad(part, m, V(1, -1, 1), V(-1, -1, 1), V(-1, -1, 0), V(1, -1, 0))  # back   (-z)
    quad(part, m, V(1, 1, 1), V(1, -1, 1), V(1, -1, 0), V(1, 1, 0))      # +x side
    quad(part, m, V(-1, -1, 1), V(-1, 1, 1), V(-1, 1, 0), V(-1, -1, 0))  # -x side
    quad(part, m, V(-1, -1, 1), V(1, -1, 1), V(1, 1, 1), V(-1, 1, 1))    # bottom edge
    if trim:
        for sx in (-1, 1):
            e0 = (sx * wt / 2, 0); e1 = (sx * wb / 2, -H)
            mid = ((e0[0] + e1[0]) / 2, -H / 2, 0)
            ang = math.degrees(math.atan2(e0[0] - e1[0], H))
            box(part, "white", mid, (0.011, H, t + 0.006), az=ang)
    if hem:
        box(part, "gold", (0, -H + 0.009, 0), (wb, 0.018, t + 0.008))


class Node:
    def __init__(self, name, t=(0, 0, 0), rot=(0, 0, 0)):
        self.name, self.t, self.rot, self.part, self.kids = name, t, rot, Part(), []
    def add(self, n):
        self.kids.append(n); return n


def chain(parent, base, pivot, specs, rot=(0, 0, 0), kind="coat", trimmed=True):
    """specs: [(wt, wb, h, hem)] stacked panels; each is a child pivoting at the bottom of the previous."""
    prev = parent
    for k, (wt, wb, h, hem) in enumerate(specs):
        n = Node(f"{base}_{k}", pivot if k == 0 else (0, -specs[k - 1][2], 0), rot if k == 0 else (0, 0, 0))
        panel(n.part, kind, wt, wb, h, 0.016, trim=trimmed, hem=hem)
        prev.add(n); prev = n


def build(game=False):
    """game=True: arms bent forward to hold a rifle (flat colours), used for the in-match character."""
    root = Node("hero")
    body = root.add(Node("body")); B = body.part
    # legs hang from the hip (own nodes so the game can swing them)
    for s, nm in ((-1, "leg_L"), (1, "leg_R")):
        leg = body.add(Node(nm, (0.085 * s, 1.0, 0.0))); L = leg.part
        tube(L, "legs", [(0, 0.0, 0), (0, -0.30, 0.005), (0, -0.54, 0.0), (0, -0.70, 0.012)], [(0.078, 0.078), (0.060, 0.060), (0.050, 0.050), (0.043, 0.043)], 14)
        tube(L, "boot", [(0, -0.97, 0.045), (0, -0.91, 0.03), (0, -0.70, 0.012)], [(0.047, 0.088), (0.052, 0.062), (0.052, 0.054)], 14)
        tube(L, "white", [(0, -1.0, 0.045), (0, -0.97, 0.045)], [(0.057, 0.098), (0.054, 0.093)], 14)
        tube(L, "white", [(0, -0.70, 0.012), (0, -0.665, 0.012)], [(0.060, 0.062), (0.058, 0.060)], 14)
        box(L, "gold", (0, -0.915, 0.108), (0.016, 0.012, 0.10))
        box(L, "gold", (0, -0.91, 0.085), (0.07, 0.012, 0.016))
    # skirt, belt
    tube(B, "navy", [(0, 0.82, 0), (0, 0.95, 0), (0, 1.08, 0)], [(0.185, 0.14), (0.17, 0.125), (0.15, 0.11)], 20, caps=False)
    tube(B, "gold", [(0, 0.815, 0), (0, 0.835, 0)], [(0.188, 0.143), (0.187, 0.142)], 20, caps=False)
    tube(B, "gold", [(0, 1.07, 0), (0, 1.135, 0)], [(0.158, 0.118), (0.152, 0.113)], 20)
    box(B, "silver", (0, 1.10, 0.122), (0.05, 0.05, 0.016))
    box(B, "red", (0.05, 1.035, 0.126), (0.07, 0.03, 0.01))
    # torso
    tube(B, "torso", [(0, 1.10, 0), (0, 1.20, 0), (0, 1.31, 0), (0, 1.40, 0)], [(0.140, 0.100), (0.128, 0.092), (0.150, 0.100), (0.150, 0.095)], 20)
    for s in (-1, 1):
        box(B, "white", (0.046 * s, 1.26, 0.0975), (0.008, 0.28, 0.012))
        box(B, "white", (0.03 * s, 1.37, 0.104), (0.008, 0.08, 0.012), az=-18 * s)
    tube(B, "skin", [(0, 1.40, 0), (0, 1.47, 0.005)], [(0.034, 0.034), (0.032, 0.032)], 12)
    tube(B, "silver", [(0, 1.405, 0), (0, 1.44, 0)], [(0.100, 0.082), (0.088, 0.072)], 20, caps=False)
    box(B, "silver", (0, 1.365, 0.108), (0.014, 0.06, 0.012)); box(B, "silver", (0, 1.375, 0.108), (0.04, 0.014, 0.012))
    # arms
    flat = game
    arms = body.add(Node("arms")); A = arms.part
    A_front = B if not game else A
    for s in (-1, 1):
        sh = (0.185 * s, 1.37, 0)
        if not game:
            el = (0.25 * s, 1.15, 0.02); wr = (0.30 * s, 0.92, 0.05); hand = (0.31 * s, 0.86, 0.055)
        elif s > 0:   # right hand under the rifle grip, left hand forward on the handguard
            el = (0.20 * s, 1.15, 0.17); wr = (0.12 * s, 1.14, 0.33); hand = (0.10 * s, 1.14, 0.38)
        else:
            el = (0.21 * s, 1.17, 0.20); wr = (0.06 * s, 1.15, 0.45); hand = (0.05 * s, 1.15, 0.50)
        tube(A, "torso", [sh, el, wr], [(0.050, 0.050), (0.045, 0.045), (0.043, 0.043)], 14)
        def at(t): return tuple(np.array(sh) + (np.array(el) - np.array(sh)) * t)
        def at2(t): return tuple(np.array(el) + (np.array(wr) - np.array(el)) * t)
        tube(A, "gold", [at(0.12), at(0.40)], [(0.056, 0.056), (0.054, 0.054)], 14, caps=False)
        tube(A, "gold", [at2(0.22), at2(0.42)], [(0.050, 0.050), (0.049, 0.049)], 14, caps=False)
        tube(A, "white", [at2(0.70), at2(1.0)], [(0.058, 0.058), (0.064, 0.064)], 14, caps=False)
        ellipsoid(A, "white", hand, (0.036, 0.055, 0.025) if not game else (0.04, 0.04, 0.04), 8, 12)
        box(B, "gold", (0.20 * s, 1.43, 0.0), (0.075, 0.02, 0.08), az=-14 * s)
    arms.flat = flat
    # head
    hc = (0, 1.57, 0.0); hr = (0.105, 0.122, 0.108)
    ellipsoid(B, "skin", hc, hr, 12, 20)
    ellipsoid(B, "navy", (0, 1.58, -0.015), hr, 12, 22, keep=lambda q: q[2] < 0.30 or (q[1] > 0.78 and q[2] < 0.45), grow=1.14)
    # animated cloth
    chain(body, "coat_back", (0, 1.37, -0.115), [(0.30, 0.36, 0.28, False), (0.36, 0.44, 0.28, False), (0.44, 0.52, 0.24, True)])
    for s, n in ((-1, "L"), (1, "R")):
        chain(body, f"coat_{n}", (0.155 * s, 1.10, 0.035), [(0.12, 0.16, 0.26, False), (0.16, 0.20, 0.26, True)], rot=(0, 0, 7 * s))
    chain(body, "flap", (0, 1.07, 0.128), [(0.17, 0.19, 0.12, False), (0.19, 0.20, 0.11, True)], kind="navy")
    chain(body, "veil", (0, 1.57, -0.105), [(0.15, 0.17, 0.13, False), (0.17, 0.15, 0.13, False)], kind="navy", trimmed=False)
    return root


# ---------------------------------------------------------------- texture projection
def load_tex(path, up):
    im = Image.open(path).convert("RGBA")
    im = im.resize((im.width * up, im.height * up), Image.LANCZOS)
    a = np.asarray(im).astype(np.float32)
    rgb, al = a[..., :3], a[..., 3] > 100
    # grow colours outwards so sampling just outside the silhouette never picks up the black background
    known = al.copy()
    for _ in range(40):
        pad = np.pad(rgb, ((1, 1), (1, 1), (0, 0)), mode="edge"); pk = np.pad(known, 1)
        acc = np.zeros_like(rgb); cnt = np.zeros(known.shape, np.float32)
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                if dx == 0 and dy == 0: continue
                k = pk[1 + dy:1 + dy + known.shape[0], 1 + dx:1 + dx + known.shape[1]]
                acc += pad[1 + dy:1 + dy + known.shape[0], 1 + dx:1 + dx + known.shape[1]] * k[..., None]
                cnt += k
        new = (~known) & (cnt > 0)
        rgb = np.where(new[..., None], acc / np.maximum(cnt, 1)[..., None], rgb)
        known = known | new
    return Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), "RGB")


FRONT_CENTER = [(0, 154), (300, 152), (440, 170), (500, 124), (560, 114), (665, 96)]   # centre line (px) down the front picture
S_FRONT = 1.70 / 662.0
S_BACK = 1.70 / 157.0
FRONT_W, FRONT_H, BACK_W, BACK_H = 331, 670, 85, 166
BACK_CX = 42.5
BACK_CENTER = [(0, 42.5), (100, 42.5), (112, 46), (120, 53), (165, 54)]


def project(root):
    """replace the flat materials on front / back facing triangles with the picture, projected onto the model."""
    def quat_to_R(q):
        x, y, z, w = q
        return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                         [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                         [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])
    def cen(py):
        xs = [p[0] for p in FRONT_CENTER]; ys = [p[1] for p in FRONT_CENTER]
        return float(np.interp(py, xs, ys))
    def walk(n, M):
        T = np.eye(4); T[:3, 3] = n.t
        if tuple(n.rot) != (0, 0, 0): T[:3, :3] = quat_to_R(euler_quat(*n.rot))
        M = M @ T
        if not getattr(n, "flat", False):
            newd = {}
            def put(m, P, N, UV, I):
                g = newd.setdefault(m, dict(p=[], n=[], uv=[], i=[])); b = len(g["p"])
                g["p"] += P; g["n"] += N; g["uv"] += UV; g["i"] += [b, b + 1, b + 2]
            for m, g in n.part.d.items():
                P = np.array(g["p"]); N = np.array(g["n"]); UV = g["uv"]; I = np.array(g["i"]).reshape(-1, 3)
                Pw = (M[:3, :3] @ P.T).T + M[:3, 3]
                for a, b, c in I:
                    fn = (M[:3, :3] @ (N[a] + N[b] + N[c])); ln = np.linalg.norm(fn)
                    nz = fn[2] / ln if ln > 1e-12 else 0.0
                    vs = [P[k].tolist() for k in (a, b, c)]; ns = [N[k].tolist() for k in (a, b, c)]
                    if abs(nz) < 0.35 or m in ("gold_flat",):
                        put(m, vs, ns, [UV[k] for k in (a, b, c)], None); continue
                    uvs = []
                    for k in (a, b, c):
                        x, y = Pw[k][0], Pw[k][1]
                        if nz > 0:
                            py = 4 + (1.70 - y) / S_FRONT
                            px = cen(py) + x / S_FRONT
                            uvs.append((px / FRONT_W, py / FRONT_H))
                        else:
                            py = 4 + (1.70 - y) / S_BACK
                            px = float(np.interp(py, [p[0] for p in BACK_CENTER], [p[1] for p in BACK_CENTER])) - x / S_BACK
                            uvs.append((px / BACK_W, py / BACK_H))
                    put("pf" if nz > 0 else "pb", vs, ns, uvs, None)
            n.part.d = newd
        for k in n.kids: walk(k, M)
    walk(root, np.eye(4))


def euler_quat(rx, ry, rz):
    cx, sx = math.cos(math.radians(rx) / 2), math.sin(math.radians(rx) / 2)
    cy, sy = math.cos(math.radians(ry) / 2), math.sin(math.radians(ry) / 2)
    cz, sz = math.cos(math.radians(rz) / 2), math.sin(math.radians(rz) / 2)
    return [sx * cy * cz - cx * sy * sz, cx * sy * cz + sx * cy * sz, cx * cy * sz - sx * sy * cz, cx * cy * cz + sx * sy * sz]


def write_glb(root, tex_pngs, out):
    binbuf = bytearray(); views = []; accs = []; meshes = []; nodes = []
    names = list(MATS)
    def view(data, target=None):
        while len(binbuf) % 4: binbuf.append(0)
        v = dict(buffer=0, byteOffset=len(binbuf), byteLength=len(data))
        if target: v["target"] = target
        views.append(v); binbuf.extend(data); return len(views) - 1
    def acc(arr, ctype, typ, target, minmax=False):
        a = np.asarray(arr, dtype=np.float32 if ctype == 5126 else np.uint32)
        d = dict(bufferView=view(a.tobytes(), target), componentType=ctype, count=int(len(a)), type=typ)
        if minmax: d["min"] = a.min(0).tolist(); d["max"] = a.max(0).tolist()
        accs.append(d); return len(accs) - 1
    def emit(n):
        mi = None
        prims = []
        for m, g in n.part.d.items():
            if not g["i"]: continue
            prims.append(dict(attributes=dict(POSITION=acc(g["p"], 5126, "VEC3", 34962, True), NORMAL=acc(g["n"], 5126, "VEC3", 34962),
                                              TEXCOORD_0=acc(g["uv"], 5126, "VEC2", 34962)),
                              indices=acc(g["i"], 5125, "SCALAR", 34963), material=names.index(m)))
        if prims: meshes.append(dict(name=n.name, primitives=prims)); mi = len(meshes) - 1
        idx = len(nodes); nd = dict(name=n.name); nodes.append(nd)
        if tuple(n.t) != (0, 0, 0): nd["translation"] = [float(x) for x in n.t]
        if tuple(n.rot) != (0, 0, 0): nd["rotation"] = euler_quat(*n.rot)
        if mi is not None: nd["mesh"] = mi
        kids = [emit(k) for k in n.kids]
        if kids: nd["children"] = kids
        return idx
    ri = emit(root)
    img_bvs = [view(open(p, "rb").read()) for p in tex_pngs]
    mats = []
    for nme in names:
        m = MATS[nme]
        pbr = dict(baseColorFactor=[*m["rgb"], 1.0], metallicFactor=m["metal"], roughnessFactor=m["rough"])
        if m["tex"] is not None: pbr["baseColorTexture"] = dict(index=m["tex"])
        mats.append(dict(name=nme, pbrMetallicRoughness=pbr, doubleSided=m["double"]))
    js = dict(asset=dict(version="2.0", generator="airblade hero_build.py"), scene=0, scenes=[dict(nodes=[ri])], nodes=nodes, meshes=meshes,
              materials=mats, accessors=accs, bufferViews=views, buffers=[dict(byteLength=len(binbuf))],
              images=[dict(bufferView=b, mimeType="image/png") for b in img_bvs], textures=[dict(source=i) for i in range(len(img_bvs))])
    j = json.dumps(js, separators=(",", ":")).encode()
    while len(j) % 4: j += b" "
    while len(binbuf) % 4: binbuf.append(0)
    total = 12 + 8 + len(j) + 8 + len(binbuf)
    with open(out, "wb") as f:
        f.write(b"glTF" + struct.pack("<II", 2, total))
        f.write(struct.pack("<I", len(j)) + b"JSON" + j)
        f.write(struct.pack("<I", len(binbuf)) + b"BIN\0" + bytes(binbuf))
    return total


def preview(root, out, tex_pngs, sway=0.0):
    import matplotlib; matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from matplotlib.collections import PolyCollection
    texs = [np.asarray(Image.open(p).convert("RGB")) / 255.0 for p in tex_pngs]
    tris = []
    def quat_to_R(q):
        x, y, z, w = q
        return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                         [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                         [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])
    def walk(n, M):
        T = np.eye(4); T[:3, 3] = n.t
        rot = n.rot
        if sway and n.name[-2:-1] == "_" and n.name[:-2] in ("coat_back", "flap", "veil", "coat_L", "coat_R"):
            rot = (rot[0] + sway * (int(n.name[-1]) + 1) * 6, rot[1], rot[2])
        if tuple(rot) != (0, 0, 0): T[:3, :3] = quat_to_R(euler_quat(*rot))
        M = M @ T
        for m, g in n.part.d.items():
            P = np.array(g["p"]); N = np.array(g["n"]); UV = np.array(g["uv"]); I = np.array(g["i"]).reshape(-1, 3)
            Pw = (M[:3, :3] @ P.T).T + M[:3, 3]; Nw = (M[:3, :3] @ N.T).T
            for a, b, c in I:
                col = np.array(MATS[m]["rgb"])
                if MATS[m]["tex"] is not None:
                    tex = texs[MATS[m]["tex"]]
                    uv = UV[[a, b, c]].mean(0)
                    col = tex[max(0, min(tex.shape[0] - 1, int(uv[1] * tex.shape[0]))), max(0, min(tex.shape[1] - 1, int(uv[0] * tex.shape[1])))]
                tris.append((Pw[[a, b, c]], Nw[[a, b, c]].mean(0), col))
        for k in n.kids: walk(k, M)
    walk(root, np.eye(4))
    fig, axs = plt.subplots(1, 2, figsize=(8, 7), facecolor="#202428")
    for ax, vw in zip(axs, (0, 180)):
        a = math.radians(vw); Ry = np.array([[math.cos(a), 0, math.sin(a)], [0, 1, 0], [-math.sin(a), 0, math.cos(a)]])
        polys, cols, depth = [], [], []
        L = nrm((0.4, 0.7, 0.8))
        for P, n, col in tris:
            Pv = (Ry @ P.T).T; nv = nrm(Ry @ n)
            sh = 0.45 + 0.55 * abs(float(nv @ L))
            polys.append(Pv[:, :2]); cols.append(np.clip(col * sh, 0, 1)); depth.append(Pv[:, 2].mean())
        o = np.argsort(depth)
        ax.add_collection(PolyCollection([polys[i] for i in o], facecolors=[cols[i] for i in o], edgecolors="none"))
        ax.set_xlim(-0.6, 0.6); ax.set_ylim(-0.05, 1.8); ax.set_aspect("equal"); ax.axis("off")
    fig.tight_layout(); fig.savefig(out, dpi=110, facecolor=fig.get_facecolor())


if __name__ == "__main__":
    # hero_build.py out_dir front_cutout.png back_cutout.png
    import os
    out_dir, fpng, bpng = sys.argv[1], sys.argv[2], sys.argv[3]
    tf, tb = os.path.join(out_dir, "_tex_front.png"), os.path.join(out_dir, "_tex_back.png")
    load_tex(fpng, 2).save(tf); load_tex(bpng, 6).save(tb)
    # texture coordinates are in 0..1 of the source pictures, so the original aspect is kept by the projection constants
    for game in (False, True):
        root = build(game)
        project(root)
        name = "airblade_hero_game.glb" if game else "airblade_hero.glb"
        print(name, write_glb(root, [tf, tb], os.path.join(out_dir, name)))
        preview(root, os.path.join(out_dir, "_preview_game.png" if game else "_preview.png"), [tf, tb])
    os.remove(tf); os.remove(tb)
