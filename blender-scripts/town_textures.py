#!/usr/bin/env python3
"""Bakes the Town map textures (GunZ-style European town): building facades, cobble paving, roof tiles.
usage: town_textures.py out_dir      -> town_facade_0..2.png, town_cobble.png, town_roof.png
A facade texture is one window bay: 512 px wide = 220 game units, 608 px tall = the full 260-unit wall."""
import sys, os, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

def noise(w, h, amp, seed, blur=1.2):
    rng = np.random.default_rng(seed)
    n = rng.normal(0, 1, (h, w)).astype(np.float32)
    im = Image.fromarray(np.clip(128 + n * 40, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(blur))
    return (np.asarray(im).astype(np.float32) - 128) / 40 * amp

def finish(img, seed, amp=7, grime=True):
    a = np.asarray(img).astype(np.float32)
    h, w = a.shape[:2]
    a += noise(w, h, amp, seed)[..., None]
    a += noise(w, h, amp * 1.6, seed + 1, blur=14)[..., None]
    if grime:   # dirt creeping up from the street and down from the cornice
        y = np.linspace(0, 1, h)[:, None, None]
        a *= 1 - 0.18 * np.clip((y - 0.8) / 0.2, 0, 1)
        a *= 1 - 0.08 * np.clip((0.12 - y) / 0.12, 0, 1)
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))

W, H = 512, 608

def window(d, x0, y0, ww, wh, frame, glass, shutter, arch=False, shutters=True, sill=(200, 196, 186)):
    if shutters:
        sw = ww * 0.42
        for sx in (x0 - sw - 4, x0 + ww + 4):
            d.rectangle([sx, y0, sx + sw, y0 + wh], fill=shutter)
            for ly in range(int(y0) + 6, int(y0 + wh) - 4, 7):   # louvres
                d.line([sx + 4, ly, sx + sw - 4, ly], fill=tuple(int(c * 0.7) for c in shutter), width=2)
            d.rectangle([sx, y0, sx + sw, y0 + wh], outline=tuple(int(c * 0.55) for c in shutter), width=2)
    d.rectangle([x0 - 6, y0 - 6, x0 + ww + 6, y0 + wh + 4], fill=frame)
    if arch:
        d.pieslice([x0 - 6, y0 - ww * 0.5 - 6, x0 + ww + 6, y0 + ww * 0.5 + 6], 180, 360, fill=frame)
        d.pieslice([x0, y0 - ww * 0.5, x0 + ww, y0 + ww * 0.5], 180, 360, fill=glass)
    d.rectangle([x0, y0, x0 + ww, y0 + wh], fill=glass)
    # curtains and reflections
    d.rectangle([x0 + 4, y0 + 4, x0 + ww * 0.3, y0 + wh - 4], fill=tuple(min(255, c + 40) for c in glass))
    d.rectangle([x0 + ww * 0.7, y0 + 4, x0 + ww - 4, y0 + wh - 4], fill=tuple(min(255, c + 40) for c in glass))
    d.polygon([(x0 + ww * 0.15, y0 + wh), (x0 + ww * 0.55, y0), (x0 + ww * 0.75, y0), (x0 + ww * 0.35, y0 + wh)], fill=tuple(min(255, c + 22) for c in glass))
    d.line([x0 + ww / 2, y0, x0 + ww / 2, y0 + wh], fill=frame, width=5)
    d.line([x0, y0 + wh * 0.38, x0 + ww, y0 + wh * 0.38], fill=frame, width=5)
    d.rectangle([x0 - 12, y0 + wh + 4, x0 + ww + 12, y0 + wh + 13], fill=sill)
    d.rectangle([x0 - 12, y0 + wh + 13, x0 + ww + 12, y0 + wh + 16], fill=tuple(int(c * 0.6) for c in sill))

def band(d, y, h, col):
    d.rectangle([0, y, W, y + h], fill=col)
    d.rectangle([0, y + h, W, y + h + 4], fill=tuple(int(c * 0.6) for c in col))
    d.rectangle([0, y, W, y + 2], fill=tuple(min(255, int(c * 1.1)) for c in col))

def plinth(d, y, col):
    d.rectangle([0, y, W, H], fill=col)
    for row, yy in enumerate(range(y, H, 18)):
        d.line([0, yy, W, yy], fill=tuple(int(c * 0.7) for c in col), width=2)
        off = 0 if row % 2 == 0 else 48
        for xx in range(off, W, 96):
            d.line([xx, yy, xx, yy + 18], fill=tuple(int(c * 0.7) for c in col), width=2)

def roof_edge(d, col):
    d.rectangle([0, 0, W, 16], fill=col)
    for xx in range(0, W, 22):
        d.ellipse([xx - 3, 8, xx + 19, 24], fill=tuple(int(c * 0.82) for c in col))

def facade(kind, seed):
    random.seed(seed)
    if kind == 0:   # cream plaster, grey-green shutters (the white houses)
        wall, shutter, frame, glass = (222, 218, 205), (64, 72, 70), (236, 234, 228), (40, 46, 52)
    elif kind == 1: # warm peach plaster, brown shutters
        wall, shutter, frame, glass = (214, 176, 140), (92, 64, 44), (232, 222, 206), (44, 46, 50)
    else:           # sandstone ashlar with arched windows
        wall, shutter, frame, glass = (196, 172, 128), (70, 60, 50), (214, 196, 160), (48, 54, 60)
    img = Image.new("RGB", (W, H), wall)
    d = ImageDraw.Draw(img)
    if kind == 2:   # stone courses
        for row, yy in enumerate(range(0, H, 34)):
            d.line([0, yy, W, yy], fill=tuple(int(c * 0.8) for c in wall), width=2)
            off = 0 if row % 2 == 0 else 64
            for xx in range(off, W, 128):
                d.line([xx, yy, xx, yy + 34], fill=tuple(int(c * 0.8) for c in wall), width=2)
    roof_edge(d, (150, 74, 50))
    band(d, 18, 14, tuple(min(255, int(c * 1.06)) for c in wall))
    ww, wh = 112, 128
    x0 = (W - ww) / 2
    arch = kind == 2
    window(d, x0, 70 + (20 if arch else 0), ww, wh - (20 if arch else 0), frame, glass, shutter, arch=arch, shutters=not arch)
    band(d, 222, 10, tuple(min(255, int(c * 1.06)) for c in wall))
    window(d, x0, 262 + (20 if arch else 0), ww, wh - (20 if arch else 0), frame, glass, shutter, arch=arch, shutters=not arch)
    band(d, 414, 10, tuple(min(255, int(c * 1.06)) for c in wall))
    # ground floor: a door on some bays, a window on others (alternates by variant)
    if kind == 1:
        dw, dh = 104, 140
        dx = (W - dw) / 2
        d.rectangle([dx - 10, 438 - 10, dx + dw + 10, 438 + dh], fill=frame)
        d.rectangle([dx, 438, dx + dw, 438 + dh], fill=(92, 52, 34))
        for k in range(4):
            d.rectangle([dx + 8 + k * 24, 448, dx + 24 + k * 24, 438 + dh - 10], outline=(70, 38, 24), width=2)
    else:
        window(d, x0, 452, ww, 110, frame, glass, shutter, arch=kind == 2, shutters=kind == 0)
    plinth(d, H - 34, (150, 146, 138) if kind != 2 else (150, 132, 100))
    return finish(img, seed)

def cobble(seed):
    s = 512
    img = Image.new("RGB", (s, s), (92, 92, 94))
    d = ImageDraw.Draw(img)
    rng = random.Random(seed)
    n = 8
    t = s // n
    for j in range(n):
        for i in range(n):
            base = 146 + rng.randint(-7, 7) + (5 if (i + j) % 2 == 0 else -4)
            c = (base, base, base + 3)
            d.rectangle([i * t + 3, j * t + 3, (i + 1) * t - 3, (j + 1) * t - 3], fill=c)
            d.line([i * t + 3, (j + 1) * t - 4, (i + 1) * t - 3, (j + 1) * t - 4], fill=tuple(int(x * 0.8) for x in c), width=2)
            d.line([(i + 1) * t - 4, j * t + 3, (i + 1) * t - 4, (j + 1) * t - 3], fill=tuple(int(x * 0.8) for x in c), width=2)
            d.line([i * t + 3, j * t + 3, (i + 1) * t - 3, j * t + 3], fill=tuple(min(255, int(x * 1.1)) for x in c), width=1)
    return finish(img, seed, amp=8, grime=False)

def roof(seed):
    s = 256
    img = Image.new("RGB", (s, s), (120, 56, 38))
    d = ImageDraw.Draw(img)
    for row, yy in enumerate(range(0, s, 16)):
        off = 0 if row % 2 == 0 else 12
        for xx in range(-24 + off, s, 24):
            d.ellipse([xx, yy, xx + 24, yy + 22], fill=(160 + (xx * 7 + yy) % 20, 78, 52))
            d.arc([xx, yy, xx + 24, yy + 22], 0, 180, fill=(96, 44, 30), width=2)
    return finish(img, seed, amp=6, grime=False)

if __name__ == "__main__":
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    for k in range(3):
        facade(k, 10 + k).save(os.path.join(out, f"town_facade_{k}.png"))
    cobble(5).save(os.path.join(out, "town_cobble.png"))
    roof(7).save(os.path.join(out, "town_roof.png"))
    print("ok")
