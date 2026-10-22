#!/usr/bin/env python3
"""Paints Resources/hideout_bg.jpg: the AIRBLADE hideout (original art).

A perspective room: the left wall holds a tall arched steel window onto a rainy night city and bridge;
the back wall has pipes, gauges, posters, an evidence board and a rifle rack; a desk with books and a
lamp, an ammo crate and a steel chest stand on a plank floor with an ornate rug. Materials are procedural
(plaster, brick, wood grain, cork, steel), then lit (lamp, sconces, cool window light with the frame's
shadow on the floor), shadowed (contact shadows, ambient occlusion in the corners) and post-processed
(bloom, colour grade, grain, vignette).  usage: hideout_paint.py out.jpg
"""
import sys, math, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 2400, 1110
SS = 2
WS, HS = W * SS, H * SS
rng = random.Random(11)
nrng = np.random.default_rng(5)

# ------------------------------------------------------------------ helpers
def fbm(w, h, octaves=5, base=8, seed=0, persist=0.55):
    """fractal noise in [0,1]"""
    r = np.random.default_rng(seed)
    out = np.zeros((h, w), np.float32)
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        gw, gh = max(2, int(base * 2 ** o * w / max(w, h))), max(2, int(base * 2 ** o * h / max(w, h)))
        g = r.random((gh, gw)).astype(np.float32)
        im = Image.fromarray((g * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
        out += np.asarray(im).astype(np.float32) / 255 * amp
        tot += amp
        amp *= persist
    return out / tot

def to_img(a):
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))

def persp_coeffs(src, dst):
    """coefficients for Image.transform(PERSPECTIVE) mapping output dst quad -> input src quad"""
    A, B = [], []
    for (x, y), (u, v) in zip(dst, src):
        A.append([x, y, 1, 0, 0, 0, -u * x, -u * y]); B.append(u)
        A.append([0, 0, 0, x, y, 1, -v * x, -v * y]); B.append(v)
    return np.linalg.solve(np.array(A, np.float64), np.array(B, np.float64)).tolist()

def warp_onto(canvas, tex, quad):
    """paste texture `tex` (RGB or RGBA) onto the canvas quad (TL, TR, BR, BL) with true perspective"""
    tw, th = tex.size
    src = [(0, 0), (tw, 0), (tw, th), (0, th)]
    c = persp_coeffs(src, quad)
    t = tex.convert("RGBA").transform(canvas.size, Image.PERSPECTIVE, c, resample=Image.BICUBIC)
    m = Image.new("L", canvas.size, 0)
    ImageDraw.Draw(m).polygon(quad, fill=255)
    a = Image.fromarray(np.minimum(np.asarray(t.split()[3]), np.asarray(m)))
    canvas.paste(t, (0, 0), a)

def shade(c, k):
    return tuple(int(max(0, min(255, v * k))) for v in c)

# ------------------------------------------------------------------ room geometry (in supersampled px)
VP = (0.56 * WS, 0.40 * HS)               # vanishing point
BL, BR = 0.335 * WS, 0.965 * WS           # back wall left / right
BT, BB = 0.035 * HS, 0.745 * HS           # back wall top (ceiling line) / bottom (floor line)
def along(p, t):
    """point p moved toward the viewer: t=0 at the back wall plane, t=1 at the picture plane (scaled away from VP)"""
    s = 1 + t * 1.6
    return (VP[0] + (p[0] - VP[0]) * s, VP[1] + (p[1] - VP[1]) * s)

canvas = Image.new("RGB", (WS, HS), (20, 17, 14))

# ------------------------------------------------------------------ materials
def plaster(w, h, seed, base=(92, 80, 66)):
    n = fbm(w, h, 6, 6, seed)
    stain = fbm(w, h, 4, 3, seed + 1)
    a = np.zeros((h, w, 3), np.float32) + np.array(base, np.float32)
    a *= (0.7 + 0.5 * n)[..., None]
    a *= (1 - 0.55 * np.clip(stain - 0.5, 0, 1) * 2.5)[..., None]
    streak = fbm(w, h, 3, 2, seed + 5)
    a *= (0.9 + 0.2 * np.repeat(streak[:1, :], h, 0))[..., None]                 # water streaks running down
    y = np.linspace(0, 1, h)[:, None]
    a *= (1 - 0.25 * y ** 2)[..., None]                       # grime toward the floor
    fine = nrng.normal(0, 4, (h, w)).astype(np.float32)
    a += fine[..., None]
    return a

def brick(w, h, seed, bw=72, bh=26):
    a = np.zeros((h, w, 3), np.float32) + np.array([70, 58, 50], np.float32)   # mortar
    r = random.Random(seed)
    img = to_img(a); d = ImageDraw.Draw(img)
    for row in range(h // bh + 1):
        off = (row % 2) * bw // 2
        for col in range(-1, w // bw + 2):
            x0 = col * bw - off; y0 = row * bh
            t = 0.7 + r.random() * 0.4
            c = (int(118 * t), int(62 * t), int(46 * t))
            d.rectangle([x0 + 3, y0 + 3, x0 + bw - 3, y0 + bh - 3], fill=c)
    a = np.asarray(img).astype(np.float32)
    a *= (0.8 + 0.3 * fbm(w, h, 5, 10, seed + 3))[..., None]
    return a

def planks(w, h, seed, pw=120):
    a = np.zeros((h, w, 3), np.float32)
    r = random.Random(seed)
    grain = fbm(w, h, 4, 4, seed + 1)
    for i in range(w // pw + 1):
        t = 0.75 + r.random() * 0.35
        x0, x1 = i * pw, min(w, (i + 1) * pw)
        seg = np.zeros((h, x1 - x0, 3), np.float32) + np.array([86, 60, 40], np.float32) * t
        yy = np.arange(h)[:, None]; xx = np.arange(x1 - x0)[None, :]
        g = np.sin((xx * 0.12 + grain[:, x0:x1] * 18 + r.random() * 9)) * 0.5 + 0.5
        seg *= (0.82 + 0.25 * g)[..., None]
        a[:, x0:x1] = seg
        a[:, x0:x0 + 3] *= 0.45
        # plank ends
        for k in range(3):
            ye = r.randint(0, h - 1)
            a[ye:ye + 3, x0:x1] *= 0.5
    a *= (0.85 + 0.25 * fbm(w, h, 5, 6, seed + 2))[..., None]
    return a

def steel(w, h, seed, base=(70, 72, 76)):
    a = np.zeros((h, w, 3), np.float32) + np.array(base, np.float32)
    brushed = np.asarray(Image.fromarray((nrng.random((h, w)) * 255).astype(np.uint8)).filter(ImageFilter.BoxBlur(1)).resize((w, h))).astype(np.float32) / 255
    a *= (0.85 + 0.2 * fbm(w, h, 5, 8, seed))[..., None]
    a += (brushed[..., None] - 0.5) * 10
    return a

# ------------------------------------------------------------------ back wall
bw_, bh_ = int(BR - BL), int(BB - BT)
wall = plaster(bw_, bh_, 1)
# exposed brick where the plaster has fallen off
br_ = brick(bw_, bh_, 2)
holes = fbm(bw_, bh_, 5, 3, 7)
mask = np.clip((holes - 0.5) * 7, 0, 1)
yy = np.linspace(0, 1, bh_)[:, None]
mask *= np.clip((yy - 0.2) * 2, 0, 1)                         # mostly low on the wall
wall = wall * (1 - mask[..., None]) + br_ * mask[..., None]
wy = int(bh_ * 0.70)
wains = planks(bw_, bh_ - wy, 13, pw=140) * 0.55
wall[wy:] = wains
wall[wy:wy + 10] = np.array([60, 44, 30]) * 1.2
wall[wy + 10:wy + 14] *= 0.4
canvas.paste(to_img(wall), (int(BL), int(BT)))

# ------------------------------------------------------------------ left wall (with the window), right wall, floor, ceiling
lt = (0, -0.06 * HS); lb = (0, 1.12 * HS)
left_quad = [lt, (BL, BT), (BL, BB), lb]
lw, lh = 1400, 1000
ltex = plaster(lw, lh, 3, base=(104, 92, 78))
ltex_img = to_img(ltex)
ld = ImageDraw.Draw(ltex_img)
# window in left-wall texture space
wx0, wx1, wy0, wy1 = 80, 1330, 60, 760
win = Image.new("RGB", (wx1 - wx0, wy1 - wy0))
ww, wh = win.size
sky = np.zeros((wh, ww, 3), np.float32)
t = np.linspace(0, 1, wh)[:, None, None]
sky += np.array([18, 26, 40]) * (1 - t) + np.array([58, 64, 76]) * t
sky += (fbm(ww, wh, 5, 3, 21) - 0.5)[..., None] * 30          # clouds
win = to_img(sky); sd = ImageDraw.Draw(win)
for layer, (base, col, lit, dens) in enumerate([(0.72, (36, 42, 54), 60, 0.22), (0.86, (20, 24, 32), 110, 0.34)]):
    x = -20
    while x < ww:
        bwid = rng.randint(28, 80)
        bht = int(wh * (0.15 + rng.random() * (0.4 if layer == 0 else 0.28)))
        top = int(wh * base) - bht
        sd.rectangle([x, top, x + bwid, wh], fill=col)
        for wy in range(top + 6, int(wh * base) - 2, 8):
            for wxx in range(x + 4, x + bwid - 4, 7):
                if rng.random() < dens:
                    a = rng.randint(lit - 20, lit + 60)
                    sd.rectangle([wxx, wy, wxx + 2, wy + 3], fill=(min(255, a + 110), min(255, a + 80), a // 2 + 30))
        x += bwid + rng.randint(2, 8)
deck = int(wh * 0.68)
sd.rectangle([0, deck, ww, deck + 6], fill=(14, 16, 20))
towers = [int(ww * 0.3), int(ww * 0.8)]
for tx in towers:
    sd.rectangle([tx - 8, int(wh * 0.28), tx + 8, deck + 50], fill=(16, 18, 22))
def cable(x):
    t0 = int(wh * 0.28)
    if x < towers[0]:
        return t0 + (deck - 8 - t0) * (1 - x / towers[0]) ** 1.7
    if x < towers[1]:
        m = (x - towers[0]) / (towers[1] - towers[0])
        return t0 + (deck - 26 - t0) * (1 - (2 * m - 1) ** 2)
    m = (x - towers[1]) / (ww - towers[1])
    return t0 + (deck - 8 - t0) * m ** 1.7
sd.line([(x, cable(x)) for x in range(0, ww, 4)], fill=(12, 14, 18), width=3)
for x in range(0, ww, 26):
    sd.line([(x, cable(x)), (x, deck)], fill=(20, 22, 26), width=1)
for i in range(70):
    lx = int(ww * i / 70)
    sd.ellipse([lx - 3, deck - 4, lx + 3, deck + 2], fill=(255, 220, 150))
win = win.filter(ImageFilter.GaussianBlur(1.8))
wa = np.asarray(win).astype(np.float32)
glowl = Image.new("L", win.size, 0); gd = ImageDraw.Draw(glowl)
for i in range(70):
    lx = int(ww * i / 70)
    gd.ellipse([lx - 16, deck - 16, lx + 16, deck + 14], fill=70)
gl = np.asarray(glowl.filter(ImageFilter.GaussianBlur(12))).astype(np.float32) / 255
wa += gl[..., None] * np.array([255, 190, 110])
for i in range(1400):                                        # rain on the glass
    rx, ry = rng.randint(0, ww - 2), rng.randint(0, wh - 2)
    ln = rng.randint(8, 40); a = rng.uniform(0.05, 0.16)
    wa[ry:ry + ln, rx:rx + 1] = wa[ry:ry + ln, rx:rx + 1] * (1 - a) + 210 * a
win = to_img(wa)
wd = ImageDraw.Draw(win)
for i in range(500):
    rx, ry = rng.randint(0, ww), rng.randint(0, wh); r = rng.randint(1, 3)
    wd.ellipse([rx - r, ry - r, rx + r, ry + r], outline=(96, 104, 118))
ltex_img.paste(win, (wx0, wy0))
# steel frame (in texture space): outer, transom with two arches, mullions
st, sth, stl = (36, 34, 32), (86, 82, 76), (14, 13, 12)
ld.rectangle([wx0 - 26, wy0 - 26, wx1 + 26, wy0], fill=st)
ld.rectangle([wx0 - 26, wy1, wx1 + 26, wy1 + 40], fill=st)
ld.rectangle([wx0 - 26, wy0 - 26, wx0, wy1 + 40], fill=st)
ld.rectangle([wx1, wy0 - 26, wx1 + 26, wy1 + 40], fill=st)
tr = wy0 + 190
ld.rectangle([wx0, tr - 10, wx1, tr + 10], fill=st)
half = (wx1 - wx0) // 2
for k in range(2):
    a0 = wx0 + k * half
    ld.arc([a0 + 14, wy0 + 6, a0 + half - 14, tr + 170], 180, 360, fill=st, width=16)
    cx, cy, rr = a0 + half / 2, tr, half / 2 - 14
    for s in range(1, 6):
        ang = math.pi + s * math.pi / 6
        ld.line([cx, cy, cx + math.cos(ang) * rr, cy + math.sin(ang) * rr * 1.0], fill=st, width=6)
for i in range(1, 8):
    x = wx0 + i * (wx1 - wx0) // 8
    ld.rectangle([x - 7, tr, x + 7, wy1], fill=st)
    ld.line([x - 7, tr, x - 7, wy1], fill=sth, width=2)
ld.rectangle([wx0, wy0 + 440, wx1, wy0 + 452], fill=st)
for x in range(wx0, wx1, 34):
    ld.ellipse([x + 4, wy1 + 12, x + 10, wy1 + 18], fill=sth)
# wainscot under the window
ld.rectangle([0, wy1 + 40, lw, lh], fill=(48, 38, 30))
for x in range(0, lw, 110):
    ld.rectangle([x + 10, wy1 + 60, x + 100, lh - 30], outline=(34, 26, 20), width=4)
# left wall quad: near edge (x=0) to back wall edge
warp_onto(canvas, ltex_img, [lt, (BL, BT), (BL, BB), lb])

# right wall
rq = [(BR, BT), (WS, -0.05 * HS), (WS, 1.05 * HS), (BR, BB)]
rtex = to_img(plaster(400, 1000, 4, base=(96, 84, 70)))
warp_onto(canvas, rtex, rq)

# floor (perspective planks)
fq = [(BL, BB), (BR, BB), (WS * 1.25, HS * 1.25), (-WS * 0.25, HS * 1.25)]
ftex = to_img(planks(2400, 1600, 5, pw=110))
warp_onto(canvas, ftex, [(BL, BB), (BR, BB), (WS * 1.6, HS * 1.9), (-WS * 0.6, HS * 1.9)])

# ceiling with beams
cq = [(0, 0), (WS, 0), (BR, BT), (BL, BT)]
d = ImageDraw.Draw(canvas)
d.polygon([(0, 0), (WS, 0), (WS, -0.05 * HS), (BR, BT), (BL, BT), (0, -0.06 * HS)], fill=(26, 22, 18))
d.rectangle([0, 0, WS, BT], fill=(24, 20, 17))
for k in range(4):
    bx = BL + (BR - BL) * (k + 0.5) / 4
    d.polygon([(bx - 20, BT), (bx + 20, BT), along((bx + 20, BT), 1)[0:2] if False else (bx + 60, 0), (bx - 60, 0)], fill=(34, 26, 20))

# ------------------------------------------------------------------ back-wall fixtures (drawn straight on, they sit on the back plane)
def bx(f): return BL + (BR - BL) * f
def by(f): return BT + (BB - BT) * f

def pipe_v(x, y0, y1, r, col=(84, 70, 52)):
    for i in range(-r, r + 1):
        tt = 1 - abs(i) / (r + 1)
        hl = 0.42 + 0.85 * tt ** 0.8 + (0.35 if -r * 0.45 < i < -r * 0.2 else 0)
        d.line([x + i, y0, x + i, y1], fill=shade(col, hl))
def pipe_h(y, x0, x1, r, col=(84, 70, 52)):
    for i in range(-r, r + 1):
        tt = 1 - abs(i) / (r + 1)
        hl = 0.42 + 0.85 * tt ** 0.8 + (0.35 if -r * 0.45 < i < -r * 0.2 else 0)
        d.line([x0, y + i, x1, y + i], fill=shade(col, hl))
def collar(x, y, r, vertical=True):
    if vertical:
        d.rectangle([x - r - 6, y - 8, x + r + 6, y + 8], fill=(60, 50, 38)); d.line([x - r - 6, y - 8, x + r + 6, y - 8], fill=(110, 92, 70), width=2)
    else:
        d.rectangle([x - 8, y - r - 6, x + 8, y + r + 6], fill=(60, 50, 38))

# corner riser where the left wall meets the back wall
pipe_v(int(BL) + 34, int(BT), int(BB), 32)
for f in (0.15, 0.45, 0.8):
    collar(int(BL) + 26, int(by(f)), 24)
pipe_h(int(by(0.06)), int(BL) + 34, int(BR), 22)
for f in (0.25, 0.55, 0.85):
    collar(int(bx(f)), int(by(0.06)), 16, vertical=False)
pipe_v(int(bx(0.43)), int(by(0.06)), int(by(0.70)), 16)
pipe_h(int(by(0.70)), int(bx(0.43)), int(bx(0.47)), 16)
pipe_v(int(bx(0.99)), int(by(0.06)), int(BB), 18)

def gauge(cx, cy, r):
    d.ellipse([cx - r - 9, cy - r - 9, cx + r + 9, cy + r + 9], fill=(122, 90, 44))
    d.ellipse([cx - r - 9, cy - r - 9, cx + r + 9, cy + r + 9], outline=(176, 136, 70), width=3)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(222, 212, 186))
    for k in range(11):
        a = math.pi * (0.75 + k * 0.15)
        d.line([cx + math.cos(a) * r * 0.72, cy + math.sin(a) * r * 0.72, cx + math.cos(a) * r * 0.9, cy + math.sin(a) * r * 0.9], fill=(40, 36, 30), width=2)
    a = math.pi * (1.2 + rng.random() * 0.6)
    d.line([cx, cy, cx + math.cos(a) * r * 0.8, cy + math.sin(a) * r * 0.8], fill=(160, 30, 24), width=4)
    d.ellipse([cx - 5, cy - 5, cx + 5, cy + 5], fill=(40, 36, 30))
    d.ellipse([cx - r * 0.7, cy - r * 0.8, cx - r * 0.1, cy - r * 0.4], fill=(240, 236, 226))   # glass glint
gauge(int(BL) + 70, int(by(0.22)), 28)
gauge(int(bx(0.965)), int(by(0.32)), 38)
gauge(int(bx(0.965)), int(by(0.44)), 38)
# valve wheel
wc, wr = (int(BL) + 26, int(by(0.6))), 40
d.ellipse([wc[0] - wr, wc[1] - wr, wc[0] + wr, wc[1] + wr], outline=(128, 30, 22), width=9)
for k in range(5):
    a = k * 2 * math.pi / 5 + 0.3
    d.line([wc[0], wc[1], wc[0] + math.cos(a) * wr, wc[1] + math.sin(a) * wr], fill=(128, 30, 22), width=6)

shadow_layer = Image.new("L", canvas.size, 0)
sh = ImageDraw.Draw(shadow_layer)

def poster(x0, y0, x1, y1, paper, ink, kind):
    sh.rectangle([x0 + 10, y0 + 14, x1 + 10, y1 + 14], fill=150)
    p = Image.new("RGB", (int(x1 - x0), int(y1 - y0)), paper)
    pd = ImageDraw.Draw(p)
    pw, ph = p.size
    if kind == "target":
        cx, cy, r = pw / 2, ph * 0.42, pw * 0.36
        for k in range(5):
            rr = r * (1 - k * 0.2)
            pd.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], outline=ink, width=5)
        pd.ellipse([cx - r * 0.15, cy - r * 0.15, cx + r * 0.15, cy + r * 0.15], fill=ink)
        pd.line([cx, cy - r * 1.1, cx, cy + r * 1.1], fill=ink, width=2); pd.line([cx - r * 1.1, cy, cx + r * 1.1, cy], fill=ink, width=2)
        for k in range(4):
            hx, hy = cx + rng.uniform(-r, r) * 0.6, cy + rng.uniform(-r, r) * 0.6
            pd.ellipse([hx - 5, hy - 5, hx + 5, hy + 5], fill=(20, 18, 16))
    else:
        pd.rectangle([14, 14, pw - 14, 46], fill=ink)
        pd.ellipse([pw / 2 - 46, 70, pw / 2 + 46, 176], fill=shade(ink, 1.2))
        pd.rectangle([pw / 2 - 64, 160, pw / 2 + 64, 230], fill=shade(ink, 1.2))
        for k in range(6):
            yy = 248 + k * 22
            if yy < ph - 14:
                pd.line([20, yy, pw - 20 - rng.randint(0, 60), yy], fill=ink, width=4)
    a = np.asarray(p).astype(np.float32)
    a *= (0.75 + 0.35 * fbm(pw, ph, 4, 4, int(x0)))[..., None]       # foxing and dirt
    yy2 = np.linspace(0, 1, ph)[:, None]
    a *= (1 - 0.2 * yy2)[..., None]
    p = to_img(a)
    canvas.paste(p, (int(x0), int(y0)))
    d.ellipse([(x0 + x1) / 2 - 6, y0 + 4, (x0 + x1) / 2 + 6, y0 + 16], fill=(170, 160, 140))

d = ImageDraw.Draw(canvas)
poster(bx(0.08), by(0.25), bx(0.15), by(0.47), (60, 104, 64), (24, 48, 30), "target")
poster(bx(0.165), by(0.30), bx(0.245), by(0.62), (204, 190, 156), (74, 60, 46), "wanted")
poster(bx(0.075), by(0.52), bx(0.135), by(0.68), (194, 182, 152), (90, 78, 58), "wanted")

# evidence board
ex0, ey0, ex1, ey1 = int(bx(0.48)), int(by(0.10)), int(bx(0.935)), int(by(0.60))
sh.rectangle([ex0 + 14, ey0 + 22, ex1 + 30, ey1 + 34], fill=170)
frame = to_img(planks(ex1 - ex0 + 60, ey1 - ey0 + 60, 9, pw=400) * 0.6)
canvas.paste(frame, (ex0 - 30, ey0 - 30))
d = ImageDraw.Draw(canvas)
d.rectangle([ex0 - 30, ey0 - 30, ex1 + 30, ey1 + 30], outline=(24, 18, 13), width=6)
d.line([ex0 - 30, ey0 - 30, ex1 + 30, ey0 - 30], fill=(120, 90, 62), width=3)
cw, ch = ex1 - ex0, ey1 - ey0
cork = np.zeros((ch, cw, 3), np.float32) + np.array([142, 106, 68], np.float32)
spk = nrng.random((ch, cw)).astype(np.float32)
cork *= (0.78 + 0.22 * spk + 0.25 * (fbm(cw, ch, 5, 8, 31) - 0.5))[..., None]
canvas.paste(to_img(cork), (ex0, ey0))
pins = []
for i in range(40):
    pw = rng.randint(80, 150); ph = int(pw * rng.uniform(0.8, 1.35))
    px = rng.randint(ex0 + 8, ex1 - pw - 8); py = rng.randint(ey0 + 8, ey1 - ph - 8)
    photo = rng.random() < 0.45
    card = Image.new("RGBA", (pw, ph), (228, 222, 206, 255) if not photo else (232, 230, 224, 255))
    cd = ImageDraw.Draw(card)
    if photo:
        g = np.zeros((ph - 30, pw - 14, 3), np.float32) + rng.randint(60, 110)
        gh_, gw_ = g.shape[:2]
        g *= (0.7 + 0.5 * fbm(gw_, gh_, 3, 3, i))[..., None]
        pimg = to_img(g); pdd = ImageDraw.Draw(pimg)
        pdd.ellipse([gw_ * 0.32, gh_ * 0.12, gw_ * 0.68, gh_ * 0.52], fill=(170, 160, 150))
        pdd.polygon([(gw_ * 0.12, gh_), (gw_ * 0.3, gh_ * 0.55), (gw_ * 0.7, gh_ * 0.55), (gw_ * 0.88, gh_)], fill=(46, 44, 42))
        pimg = pimg.filter(ImageFilter.GaussianBlur(1.2))
        card.paste(pimg, (7, 7))
    else:
        for k in range(ph // 14):
            yy = 14 + k * 14
            if yy < ph - 10:
                cd.line([10, yy, pw - rng.randint(10, 50), yy], fill=(96, 90, 82), width=2)
    card = card.rotate(rng.uniform(-7, 7), expand=True, resample=Image.BICUBIC)
    sh.bitmap((px + 6, py + 10), card.split()[3], fill=140)
    canvas.paste(card, (px, py), card)
    pins.append((px + card.size[0] // 2, py + 10))
d = ImageDraw.Draw(canvas)
order = rng.sample(pins, 14)
for a, b in zip(order, order[1:]):
    d.line([a, b], fill=(160, 26, 22), width=3)
for (x, y) in pins:
    d.ellipse([x - 6, y - 6, x + 6, y + 6], fill=(190, 34, 28)); d.ellipse([x - 3, y - 4, x, y - 1], fill=(250, 170, 160))

# wall sconce lamps (light sources) above board corners
sconces = [(int(bx(0.43)) - 60, int(by(0.10))), (int(bx(0.97)), int(by(0.13)))]
for (sx, sy) in sconces:
    d.rectangle([sx - 6, sy, sx + 6, sy + 40], fill=(40, 34, 28))
    d.polygon([(sx - 22, sy + 40), (sx + 22, sy + 40), (sx + 14, sy + 66), (sx - 14, sy + 66)], fill=(250, 220, 160))

# rifle rack against the back wall
rk0, rk1 = int(bx(0.60)), int(bx(0.83))
rky0, rky1 = int(by(0.62)), int(BB) + 30
def wood_rect(x0, y0, x1, y1, seed, k=1.0):
    t = to_img(planks(max(2, x1 - x0), max(2, y1 - y0), seed, pw=max(4, x1 - x0)) * k)
    canvas.paste(t, (x0, y0))
sh.rectangle([rk0 + 10, rky0 + 30, rk1 + 30, rky1], fill=150)
wood_rect(rk0, rky1 - 40, rk1, rky1, 41, 0.8)
wood_rect(rk0, rky0 + 80, rk1, rky0 + 104, 42, 0.8)
wood_rect(rk0, rky0 + 40, rk0 + 26, rky1, 43, 0.7)
wood_rect(rk1 - 26, rky0 + 40, rk1, rky1, 44, 0.7)
d = ImageDraw.Draw(canvas)
def rifle(bxp, byp, L, lean, kind):
    body = [(-0.045, 0), (0.05, 0), (0.035, -0.25), (0.045, -0.26), (0.045, -0.55), (0.02, -0.6), (0.011, -1.0), (-0.011, -1.0), (-0.02, -0.6), (-0.045, -0.55), (-0.045, -0.26), (-0.03, -0.25)]
    parts = [(body, (24, 25, 27))]
    parts.append(([(0.04, -0.45), (0.12 if kind == 1 else 0.09, -0.44), (0.11 if kind == 1 else 0.085, -0.34), (0.04, -0.35)], (20, 20, 22)))
    parts.append(([(0.04, -0.31), (0.085, -0.3), (0.08, -0.25), (0.04, -0.26)], (30, 26, 22)))
    if kind == 0:
        parts.append(([(-0.04, -0.05), (0.045, -0.05), (0.04, -0.24), (-0.03, -0.24)], (92, 60, 36)))    # wooden stock
    if kind == 2:
        parts.append(([(-0.035, -0.72), (0.035, -0.72), (0.035, -0.63), (-0.035, -0.63)], (14, 14, 16)))
    ca, sa = math.cos(lean), math.sin(lean)
    for p, col in parts:
        q = [(bxp + (x * ca - y * sa) * L, byp + (x * sa + y * ca) * L) for x, y in p]
        d.polygon(q, fill=col)
        d.line(q[:2] + [q[-1]], fill=shade(col, 2.6), width=2)
    hx = [(bxp + (0.03 * ca + y * sa * -1) * L, byp + (0.03 * sa + y * ca) * L) for y in (-0.3, -0.95)]
    d.line(hx, fill=(110, 112, 118), width=2)                     # specular line along the barrel
for i in range(7):
    bxr = rk0 + 48 + i * (rk1 - rk0 - 80) // 7
    rifle(bxr, rky1 - 40, (rky1 - rky0) * (0.92 + (i % 3) * 0.05), -0.06 + (i % 2) * 0.05, i % 3)

# ------------------------------------------------------------------ foreground objects in perspective
def pbox(x0, y0, x1, y1, depth, cols, tex=None):
    """box whose front face is the rect; top and visible side recede toward VP by `depth` (0..1)"""
    def back(p):
        return (p[0] + (VP[0] - p[0]) * depth, p[1] + (VP[1] - p[1]) * depth)
    tl, tr_, br_, bl_ = (x0, y0), (x1, y0), (x1, y1), (x0, y1)
    top = [tl, tr_, back(tr_), back(tl)]
    if y0 > VP[1]:
        d.polygon(top, fill=cols[0])
    if x1 < VP[0]:
        d.polygon([tr_, br_, back(br_), back(tr_)], fill=cols[2])
    elif x0 > VP[0]:
        d.polygon([tl, bl_, back(bl_), back(tl)], fill=cols[2])
    if tex is not None:
        canvas.paste(tex.resize((int(x1 - x0), int(y1 - y0))), (int(x0), int(y0)))
    else:
        d.rectangle([x0, y0, x1, y1], fill=cols[1])
    return top

# contact shadows on the floor first
def floor_shadow(x0, x1, y, depth, spread=60):
    sh.polygon([(x0 - spread, y), (x1 + spread, y), (x1 + (VP[0] - x1) * depth, y + (VP[1] - y) * depth), (x0 + (VP[0] - x0) * depth, y + (VP[1] - y) * depth)], fill=200)

# desk (left foreground)
dk0, dk1, dkt, dkb = int(0.0 * WS), int(0.36 * WS), int(0.64 * HS), int(0.71 * HS)
floor_shadow(dk0, dk1, int(0.97 * HS), 0.22, 30)
woodtex = to_img(planks(800, 120, 51, pw=800) * 0.85)
top = pbox(dk0 - 40, dkt, dk1, dkb, 0.14, [(78, 54, 36), (50, 34, 24), (40, 28, 20)], woodtex)
d.line([dk0 - 40, dkt, dk1, dkt], fill=(130, 96, 64), width=4)
for lx in (dk0 + 30, dk1 - 60):
    d.rectangle([lx, dkb, lx + 34, int(0.98 * HS)], fill=(36, 25, 18))
    d.line([lx + 4, dkb, lx + 4, int(0.98 * HS)], fill=(66, 48, 34), width=3)
# books on the desk (perspective boxes, they stand on the desk top)
xb = dk0 + 40
for i in range(10):
    bwid = rng.randint(26, 44); bht = rng.randint(120, 180)
    col = rng.choice([(110, 40, 32), (70, 60, 46), (44, 58, 50), (124, 96, 58), (80, 30, 30), (40, 40, 58)])
    yb = dkt + 10
    pbox(xb, yb - bht, xb + bwid, yb, 0.03, [shade(col, 1.25), col, shade(col, 0.6)])
    d.line([xb + 5, yb - bht + 20, xb + bwid - 5, yb - bht + 20], fill=(190, 156, 90), width=3)
    d.line([xb + 5, yb - 26, xb + bwid - 5, yb - 26], fill=(190, 156, 90), width=3)
    xb += bwid + 3
for k in range(5):
    col = rng.choice([(96, 64, 42), (56, 48, 40), (130, 108, 76), (70, 40, 34)])
    pbox(int(0.155 * WS), dkt + 4 - (k + 1) * 26, int(0.225 * WS) - k * 6, dkt + 4 - k * 26, 0.05, [shade(col, 1.3), col, shade(col, 0.6)])
# open book, papers, a pistol
d.polygon([(int(0.235 * WS), dkt + 2), (int(0.28 * WS), dkt - 14), (int(0.325 * WS), dkt + 2), (int(0.28 * WS), dkt + 16)], fill=(222, 212, 184))
d.line([(int(0.28 * WS), dkt - 14), (int(0.28 * WS), dkt + 16)], fill=(150, 140, 120), width=2)
for k in range(6):
    d.line([(int(0.245 * WS) + k * 8, dkt + 2 - k * 1), (int(0.272 * WS) + k * 2, dkt - 8 + k * 3)], fill=(140, 132, 116), width=1)
gx, gy = int(0.205 * WS), dkt + 2
d.polygon([(gx, gy - 14), (gx + 110, gy - 14), (gx + 110, gy - 2), (gx + 40, gy - 2), (gx + 30, gy + 26), (gx + 12, gy + 26), (gx + 18, gy - 2), (gx, gy - 2)], fill=(18, 18, 20))
d.line([(gx, gy - 14), (gx + 110, gy - 14)], fill=(90, 92, 98), width=2)
# brass lamp with green shade
lx, ly = int(0.33 * WS), dkt
d.ellipse([lx - 46, ly - 14, lx + 46, ly + 6], fill=(150, 112, 52))
d.rectangle([lx - 5, ly - 190, lx + 5, ly - 8], fill=(170, 128, 60))
d.line([lx - 3, ly - 190, lx - 3, ly - 8], fill=(230, 200, 130), width=2)
d.polygon([(lx - 74, ly - 176), (lx + 74, ly - 176), (lx + 40, ly - 248), (lx - 40, ly - 248)], fill=(34, 92, 58))
d.line([(lx - 40, ly - 248), (lx - 74, ly - 176)], fill=(90, 170, 120), width=3)
d.ellipse([lx - 70, ly - 186, lx + 70, ly - 166], fill=(255, 236, 190))

# ammo crate under the desk
ck0, ck1, ckt, ckb = int(0.12 * WS), int(0.31 * WS), int(0.735 * HS), int(0.90 * HS)
floor_shadow(ck0, ck1, ckb, 0.12, 20)
ctex = np.zeros((ckb - ckt, ck1 - ck0, 3), np.float32) + np.array([62, 74, 44], np.float32)
ctex *= (0.8 + 0.3 * fbm(ck1 - ck0, ckb - ckt, 5, 6, 61))[..., None]
cimg = to_img(ctex); cd = ImageDraw.Draw(cimg)
cw_, ch_ = cimg.size
for k in (0.18, 0.82):
    cd.rectangle([int(cw_ * k) - 14, 0, int(cw_ * k) + 14, ch_], fill=(48, 58, 34))
cd.rectangle([0, 0, cw_ - 1, ch_ - 1], outline=(30, 36, 22), width=6)
try:
    fnt = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 80)
    cd.text((cw_ // 2, ch_ // 2 + 6), "AMMO", font=fnt, fill=(160, 164, 128), anchor="mm")
except Exception:
    pass
ca = np.asarray(cimg).astype(np.float32)
ca *= (0.85 + 0.25 * fbm(cw_, ch_, 4, 10, 62))[..., None]                     # worn paint
pbox(ck0, ckt, ck1, ckb, 0.1, [(80, 94, 56), (62, 74, 44), (40, 48, 28)], to_img(ca))
d.line([ck0, ckt, ck1, ckt], fill=(110, 124, 80), width=3)

# steel chest (right foreground)
sk0, sk1, skt, skb = int(0.845 * WS), int(1.02 * WS), int(0.76 * HS), int(1.02 * HS)
floor_shadow(sk0, sk1, skb, 0.1, 20)
stx = steel(sk1 - sk0, skb - skt, 71, base=(62, 64, 68))
simg = to_img(stx); sd2 = ImageDraw.Draw(simg)
sw2, shh = simg.size
sd2.rectangle([0, 0, sw2, 70], fill=(78, 80, 84))
sd2.line([0, 70, sw2, 70], fill=(30, 30, 32), width=5)
for xx in range(20, sw2, 60):
    for yy in (16, 90, shh - 22):
        sd2.ellipse([xx - 6, yy - 6, xx + 6, yy + 6], fill=(110, 112, 116)); sd2.ellipse([xx - 3, yy - 5, xx, yy - 2], fill=(180, 182, 186))
sd2.rectangle([70, 80, 120, 160], fill=(188, 96, 30)); sd2.rectangle([70, 80, 120, 160], outline=(90, 44, 14), width=3)
pbox(sk0, skt, sk1, skb, 0.08, [(88, 90, 94), (62, 64, 68), (38, 40, 42)], simg)

# papers on the floor
for i in range(9):
    px, py = rng.randint(int(0.58 * WS), int(0.84 * WS)), rng.randint(int(0.84 * HS), int(0.97 * HS))
    pw, ph = 90, 64; a = rng.uniform(-0.8, 0.8)
    c = [(-pw / 2, -ph / 2), (pw / 2, -ph / 2), (pw / 2, ph / 2), (-pw / 2, ph / 2)]
    q = [(px + x * math.cos(a) - y * math.sin(a), py + (x * math.sin(a) + y * math.cos(a)) * 0.38) for x, y in c]
    sh.polygon([(x + 6, y + 6) for x, y in q], fill=120)
    d.polygon(q, fill=(196, 188, 166))

# ------------------------------------------------------------------ rug on the floor (true perspective)
rw, rh = 1600, 1000
rug = np.zeros((rh, rw, 3), np.float32) + np.array([72, 26, 22], np.float32)
rimg = to_img(rug); rd = ImageDraw.Draw(rimg)
gold, dark = (132, 98, 52), (40, 16, 14)
rd.rectangle([20, 20, rw - 20, rh - 20], outline=gold, width=14)
rd.rectangle([60, 60, rw - 60, rh - 60], outline=dark, width=40)
rd.rectangle([110, 110, rw - 110, rh - 110], outline=gold, width=6)
for i in range(22):
    xx = 90 + i * (rw - 180) / 21
    for yy in (40, rh - 40):
        rd.polygon([(xx, yy - 14), (xx + 14, yy), (xx, yy + 14), (xx - 14, yy)], fill=gold)
cx, cy = rw / 2, rh / 2
for k in range(7):
    rr = 300 - k * 40
    rd.ellipse([cx - rr * 1.25, cy - rr, cx + rr * 1.25, cy + rr], outline=gold if k % 2 == 0 else dark, width=10)
for i in range(24):
    a = i * math.pi / 12
    ex, ey = cx + math.cos(a) * 360 * 1.25, cy + math.sin(a) * 360
    rd.ellipse([ex - 22, ey - 14, ex + 22, ey + 14], fill=gold)
for (qx, qy) in [(240, 240), (rw - 240, 240), (240, rh - 240), (rw - 240, rh - 240)]:
    for k in range(3):
        rr = 70 - k * 20
        rd.ellipse([qx - rr, qy - rr, qx + rr, qy + rr], outline=gold, width=6)
ra = np.asarray(rimg).astype(np.float32)
ra *= (0.78 + 0.35 * fbm(rw, rh, 6, 10, 81))[..., None]
ra += nrng.normal(0, 7, (rh, rw))[..., None]                     # pile
rimg = to_img(ra)
rq = [(0.33 * WS, 0.80 * HS), (0.79 * WS, 0.80 * HS), (0.92 * WS, 1.06 * HS), (0.20 * WS, 1.06 * HS)]
sh.polygon(rq, fill=60)
warp_onto(canvas, rimg, rq)

# ------------------------------------------------------------------ lighting
a = np.asarray(canvas).astype(np.float32) / 255
yy, xx = np.mgrid[0:HS, 0:WS].astype(np.float32)
light = np.zeros((HS, WS, 3), np.float32) + np.array([0.30, 0.30, 0.35])        # ambient (slightly cool)
def point(px, py, col, radius, power):
    dd = ((xx - px) ** 2 + (yy - py) ** 2) / radius ** 2
    return (power / (1 + dd * 3))[..., None] * np.array(col)
light += point(lx, ly - 180, (1.0, 0.72, 0.42), 560, 1.5)                         # desk lamp
for (sx, sy) in sconces:
    light += point(sx, sy + 70, (1.0, 0.75, 0.48), 460, 0.95)
    a[int(sy + 66):int(sy + 66) + 1, :] = a[int(sy + 66):int(sy + 66) + 1, :]
light += point(0.15 * WS, 0.4 * HS, (0.45, 0.55, 0.8), 900, 0.35)               # cool window light
# window light pattern on the floor (the frame's shadow)
wl = Image.new("L", canvas.size, 0); wld = ImageDraw.Draw(wl)
for i in range(8):
    x0 = 0.04 * WS + i * 0.055 * WS
    wld.polygon([(x0, 0.82 * HS), (x0 + 0.045 * WS, 0.82 * HS), (x0 + 0.12 * WS, 1.02 * HS), (x0 + 0.05 * WS, 1.02 * HS)], fill=60)
wl = np.asarray(wl.filter(ImageFilter.GaussianBlur(14))).astype(np.float32) / 255
light += wl[..., None] * np.array([0.5, 0.6, 0.85])
a *= light
# shadows: contact shadows and drop shadows, ambient occlusion in the room's corners
shd = np.asarray(shadow_layer.filter(ImageFilter.GaussianBlur(26))).astype(np.float32) / 255
a *= (1 - 0.55 * shd)[..., None]
ao = np.ones((HS, WS), np.float32)
ao *= 1 - 0.45 * np.exp(-np.clip(yy - BB, 0, None) / 40) * (yy > BB - 4) * ((xx > BL) & (xx < BR))   # floor/wall junction
ao *= 1 - 0.35 * np.exp(-np.abs(yy - BB) / 30) * ((xx > BL) & (xx < BR))
ao *= 1 - 0.4 * np.exp(-np.abs(xx - BL) / 60) * (yy > BT)
ao *= 1 - 0.4 * np.exp(-np.abs(xx - BR) / 60) * (yy > BT)
ao *= 1 - 0.5 * np.exp(-np.clip(yy - BT, 0, None) / 60)
a *= ao[..., None]
# bloom
img = to_img(a * 255)
bright = np.clip(np.asarray(img).astype(np.float32) - 170, 0, None)
bl = np.asarray(to_img(bright).filter(ImageFilter.GaussianBlur(40))).astype(np.float32)
bl2 = np.asarray(to_img(bright).filter(ImageFilter.GaussianBlur(12))).astype(np.float32)
a = np.asarray(img).astype(np.float32) + bl * 1.2 + bl2 * 0.8
# colour grade: teal shadows, warm highlights, gentle filmic curve
lum = (a[..., 0] * 0.3 + a[..., 1] * 0.59 + a[..., 2] * 0.11) / 255
a[..., 0] *= 0.94 + 0.12 * lum; a[..., 2] *= 1.06 - 0.12 * lum
a = 255 * (1 - np.exp(-a / 255 * 1.35)) / (1 - math.exp(-1.35))
# vignette and grain
v = 1 - 0.6 * np.clip(((xx / WS - 0.53) ** 2 * 1.3 + (yy / HS - 0.48) ** 2 * 1.6) - 0.06, 0, 1)
a *= v[..., None]
a += nrng.normal(0, 3.5, (HS, WS))[..., None]
img = to_img(a).resize((W, H), Image.LANCZOS)
img.save(sys.argv[1], "JPEG", quality=90)
print("ok", img.size)
