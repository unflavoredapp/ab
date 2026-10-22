#!/usr/bin/env python3
"""Bakes the material textures for the 3D hideout (HideoutStage in Sources/HideoutScene3D.swift).
usage: hideout_textures.py out_dir
Writes hideout_wall.jpg (back wall: stained plaster, bare brick, wood wainscot), hideout_side.jpg (side walls),
hideout_floor.jpg (planks), hideout_board.jpg (cork evidence board), hideout_poster_target.jpg,
hideout_poster_wanted.jpg, hideout_rug.jpg, hideout_city.jpg (night city through the window),
hideout_crate.jpg, hideout_steel.jpg, hideout_wood.jpg, hideout_gauge.png, hideout_ceiling.jpg."""
import sys, os, math, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

rng = random.Random(11)
nrng = np.random.default_rng(5)
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

def fbm(w, h, octaves=5, base=8, seed=0, persist=0.55):
    r = np.random.default_rng(seed)
    out = np.zeros((h, w), np.float32); amp = 1.0; tot = 0.0
    for o in range(octaves):
        gw = max(2, int(base * 2 ** o * w / max(w, h))); gh = max(2, int(base * 2 ** o * h / max(w, h)))
        g = r.random((gh, gw)).astype(np.float32)
        out += np.asarray(Image.fromarray((g * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)).astype(np.float32) / 255 * amp
        tot += amp; amp *= persist
    return out / tot

def img(a): return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))

def plaster(w, h, seed, base=(150, 132, 108)):
    n = fbm(w, h, 6, 6, seed); stain = fbm(w, h, 4, 3, seed + 1)
    a = np.zeros((h, w, 3), np.float32) + np.array(base, np.float32)
    a *= (0.72 + 0.45 * n)[..., None]
    a *= (1 - 0.5 * np.clip(stain - 0.5, 0, 1) * 2.5)[..., None]
    streak = fbm(w, 8, 3, 6, seed + 5)
    a *= (0.88 + 0.22 * np.repeat(streak[:1, :], h, 0))[..., None]
    y = np.linspace(0, 1, h)[:, None]
    a *= (1 - 0.18 * y ** 2)[..., None]
    a += nrng.normal(0, 4, (h, w))[..., None]
    return a

def brick(w, h, seed, bw=96, bh=34):
    a = np.zeros((h, w, 3), np.float32) + np.array([96, 84, 74], np.float32)
    r = random.Random(seed); im = img(a); d = ImageDraw.Draw(im)
    for row in range(h // bh + 1):
        off = (row % 2) * bw // 2
        for col in range(-1, w // bw + 2):
            x0 = col * bw - off; y0 = row * bh; t = 0.7 + r.random() * 0.4
            d.rectangle([x0 + 4, y0 + 4, x0 + bw - 4, y0 + bh - 4], fill=(int(150 * t), int(78 * t), int(58 * t)))
    a = np.asarray(im).astype(np.float32) * (0.8 + 0.3 * fbm(w, h, 5, 10, seed + 3))[..., None]
    return a

def planks(w, h, seed, pw=120, base=(120, 84, 56), horizontal=False):
    if horizontal:
        return np.transpose(planks(h, w, seed, pw, base), (1, 0, 2))
    a = np.zeros((h, w, 3), np.float32); r = random.Random(seed); grain = fbm(w, h, 4, 4, seed + 1)
    for i in range(w // pw + 1):
        t = 0.75 + r.random() * 0.35; x0, x1 = i * pw, min(w, (i + 1) * pw)
        if x1 <= x0: continue
        seg = np.zeros((h, x1 - x0, 3), np.float32) + np.array(base, np.float32) * t
        xx = np.arange(x1 - x0)[None, :]
        g = np.sin(xx * 0.12 + grain[:, x0:x1] * 18 + r.random() * 9) * 0.5 + 0.5
        seg *= (0.82 + 0.25 * g)[..., None]
        a[:, x0:x1] = seg; a[:, x0:x0 + 3] *= 0.45
        for k in range(3):
            ye = r.randint(0, h - 1); a[ye:ye + 3, x0:x1] *= 0.5
    a *= (0.85 + 0.25 * fbm(w, h, 5, 6, seed + 2))[..., None]
    return a

def save(a_or_img, path, q=88):
    im = a_or_img if isinstance(a_or_img, Image.Image) else img(a_or_img)
    if path.endswith(".png"): im.save(path)
    else: im.convert("RGB").save(path, "JPEG", quality=q)

def back_wall(w=2048, h=820):
    a = plaster(w, h, 1)
    br = brick(w, h, 2)
    m = np.clip((fbm(w, h, 5, 3, 7) - 0.5) * 7, 0, 1) * np.clip((np.linspace(0, 1, h)[:, None] - 0.15) * 2, 0, 1)
    a = a * (1 - m[..., None]) + br * m[..., None]
    wy = int(h * 0.72)
    a[wy:] = planks(w, h - wy, 13, pw=160, base=(96, 66, 44))
    a[wy:wy + 14] = np.array([110, 80, 54]); a[wy + 14:wy + 20] *= 0.4
    return a

def city(w=2048, h=1200):
    t = np.linspace(0, 1, h)[:, None, None]
    a = np.zeros((h, w, 3), np.float32) + np.array([16, 22, 36]) * (1 - t) + np.array([60, 66, 80]) * t
    a += (fbm(w, h, 5, 3, 21) - 0.5)[..., None] * 30
    im = img(a); d = ImageDraw.Draw(im)
    for layer, (base, col, lit, dens) in enumerate([(0.62, (34, 40, 52), 70, 0.25), (0.80, (20, 24, 32), 120, 0.36)]):
        x = -20
        while x < w:
            bw = rng.randint(30, 90); bh = int(h * (0.15 + rng.random() * (0.4 if layer == 0 else 0.3)))
            top = int(h * base) - bh
            d.rectangle([x, top, x + bw, h], fill=col)
            for wy in range(top + 6, int(h * base) - 2, 9):
                for wx in range(x + 4, x + bw - 4, 8):
                    if rng.random() < dens:
                        v = rng.randint(lit - 20, lit + 60)
                        d.rectangle([wx, wy, wx + 3, wy + 4], fill=(min(255, v + 110), min(255, v + 80), v // 2 + 30))
            x += bw + rng.randint(2, 8)
    deck = int(h * 0.62)
    d.rectangle([0, deck, w, deck + 8], fill=(14, 16, 20))
    towers = [int(w * 0.3), int(w * 0.8)]
    for tx in towers:
        d.rectangle([tx - 10, int(h * 0.22), tx + 10, deck + 60], fill=(16, 18, 22))
    def cable(x):
        t0 = int(h * 0.22)
        if x < towers[0]: return t0 + (deck - 8 - t0) * (1 - x / towers[0]) ** 1.7
        if x < towers[1]:
            m = (x - towers[0]) / (towers[1] - towers[0]); return t0 + (deck - 26 - t0) * (1 - (2 * m - 1) ** 2)
        m = (x - towers[1]) / (w - towers[1]); return t0 + (deck - 8 - t0) * m ** 1.7
    d.line([(x, cable(x)) for x in range(0, w, 4)], fill=(12, 14, 18), width=4)
    for x in range(0, w, 28): d.line([(x, cable(x)), (x, deck)], fill=(20, 22, 26), width=1)
    for i in range(80):
        lx = int(w * i / 80); d.ellipse([lx - 4, deck - 5, lx + 4, deck + 3], fill=(255, 220, 150))
    im = im.filter(ImageFilter.GaussianBlur(2))
    a = np.asarray(im).astype(np.float32)
    gl = Image.new("L", im.size, 0); gd = ImageDraw.Draw(gl)
    for i in range(80):
        lx = int(w * i / 80); gd.ellipse([lx - 18, deck - 18, lx + 18, deck + 16], fill=70)
    a += (np.asarray(gl.filter(ImageFilter.GaussianBlur(14))).astype(np.float32) / 255)[..., None] * np.array([255, 190, 110])
    for i in range(1800):
        rx, ry = rng.randint(0, w - 2), rng.randint(0, h - 2); ln = rng.randint(10, 50); al = rng.uniform(0.05, 0.16)
        a[ry:ry + ln, rx:rx + 2] = a[ry:ry + ln, rx:rx + 2] * (1 - al) + 210 * al
    return a

def board(w=1600, h=1000):
    a = np.zeros((h, w, 3), np.float32) + np.array([150, 112, 72], np.float32)
    a *= (0.78 + 0.22 * nrng.random((h, w)) + 0.25 * (fbm(w, h, 5, 8, 31) - 0.5))[..., None]
    im = img(a); pins = []
    for i in range(46):
        pw = rng.randint(90, 170); ph = int(pw * rng.uniform(0.8, 1.35))
        px = rng.randint(10, w - pw - 10); py = rng.randint(10, h - ph - 10)
        photo = rng.random() < 0.45
        card = Image.new("RGBA", (pw, ph), (228, 222, 206, 255) if not photo else (232, 230, 224, 255))
        cd = ImageDraw.Draw(card)
        if photo:
            g = np.zeros((ph - 30, pw - 14, 3), np.float32) + rng.randint(60, 110)
            g *= (0.7 + 0.5 * fbm(pw - 14, ph - 30, 3, 3, i))[..., None]
            pi = img(g); pd = ImageDraw.Draw(pi); gw, gh = pi.size
            pd.ellipse([gw * 0.32, gh * 0.12, gw * 0.68, gh * 0.52], fill=(170, 160, 150))
            pd.polygon([(gw * 0.12, gh), (gw * 0.3, gh * 0.55), (gw * 0.7, gh * 0.55), (gw * 0.88, gh)], fill=(46, 44, 42))
            card.paste(pi.filter(ImageFilter.GaussianBlur(1.2)), (7, 7))
        else:
            for k in range(ph // 14):
                yy = 14 + k * 14
                if yy < ph - 10: cd.line([10, yy, pw - rng.randint(10, 50), yy], fill=(96, 90, 82), width=2)
        card = card.rotate(rng.uniform(-7, 7), expand=True, resample=Image.BICUBIC)
        sh = Image.new("RGBA", card.size, (0, 0, 0, 0)); sh.paste((0, 0, 0, 110), (0, 0), card.split()[3])
        im.paste(sh, (px + 6, py + 9), sh); im.paste(card, (px, py), card)
        pins.append((px + card.size[0] // 2, py + 10))
    d = ImageDraw.Draw(im)
    order = rng.sample(pins, 15)
    for p, q in zip(order, order[1:]): d.line([p, q], fill=(160, 26, 22), width=4)
    for (x, y) in pins:
        d.ellipse([x - 7, y - 7, x + 7, y + 7], fill=(190, 34, 28)); d.ellipse([x - 3, y - 5, x, y - 2], fill=(250, 170, 160))
    return im

def poster(kind, w=360, h=520):
    paper, ink = ((60, 104, 64), (24, 48, 30)) if kind == "target" else ((210, 196, 160), (74, 60, 46))
    p = Image.new("RGB", (w, h), paper); d = ImageDraw.Draw(p)
    if kind == "target":
        cx, cy, r = w / 2, h * 0.42, w * 0.38
        for k in range(5):
            rr = r * (1 - k * 0.2); d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], outline=ink, width=7)
        d.ellipse([cx - r * 0.15, cy - r * 0.15, cx + r * 0.15, cy + r * 0.15], fill=ink)
        d.line([cx, cy - r * 1.1, cx, cy + r * 1.1], fill=ink, width=3); d.line([cx - r * 1.1, cy, cx + r * 1.1, cy], fill=ink, width=3)
        for k in range(5):
            hx, hy = cx + rng.uniform(-r, r) * 0.6, cy + rng.uniform(-r, r) * 0.6; d.ellipse([hx - 7, hy - 7, hx + 7, hy + 7], fill=(18, 16, 14))
    else:
        try:
            f = ImageFont.truetype(FONT, 54); d.text((w / 2, 50), "WANTED", font=f, fill=ink, anchor="mm")
        except Exception:
            d.rectangle([20, 20, w - 20, 80], fill=ink)
        d.ellipse([w / 2 - 70, 110, w / 2 + 70, 270], fill=(120, 104, 84))
        d.rectangle([w / 2 - 100, 250, w / 2 + 100, 340], fill=(120, 104, 84))
        for k in range(6):
            yy = 370 + k * 24
            if yy < h - 20: d.line([30, yy, w - 30 - rng.randint(0, 80), yy], fill=ink, width=5)
    a = np.asarray(p).astype(np.float32) * (0.75 + 0.35 * fbm(w, h, 4, 4, len(kind)))[..., None]
    return a

def rug(w=1600, h=1000):
    a = np.zeros((h, w, 3), np.float32) + np.array([96, 30, 26], np.float32)
    im = img(a); d = ImageDraw.Draw(im); gold, dark = (168, 124, 64), (46, 18, 16)
    d.rectangle([20, 20, w - 20, h - 20], outline=gold, width=16); d.rectangle([64, 64, w - 64, h - 64], outline=dark, width=44)
    d.rectangle([118, 118, w - 118, h - 118], outline=gold, width=7)
    for i in range(22):
        xx = 90 + i * (w - 180) / 21
        for yy in (42, h - 42): d.polygon([(xx, yy - 16), (xx + 16, yy), (xx, yy + 16), (xx - 16, yy)], fill=gold)
    cx, cy = w / 2, h / 2
    for k in range(7):
        rr = 300 - k * 40; d.ellipse([cx - rr * 1.25, cy - rr, cx + rr * 1.25, cy + rr], outline=gold if k % 2 == 0 else dark, width=12)
    for i in range(24):
        an = i * math.pi / 12; ex, ey = cx + math.cos(an) * 370 * 1.25, cy + math.sin(an) * 370
        d.ellipse([ex - 24, ey - 16, ex + 24, ey + 16], fill=gold)
    for (qx, qy) in [(250, 250), (w - 250, 250), (250, h - 250), (w - 250, h - 250)]:
        for k in range(3):
            rr = 74 - k * 22; d.ellipse([qx - rr, qy - rr, qx + rr, qy + rr], outline=gold, width=7)
    a = np.asarray(im).astype(np.float32) * (0.78 + 0.35 * fbm(w, h, 6, 10, 81))[..., None]
    a += nrng.normal(0, 7, (h, w))[..., None]
    return a

def crate(w=900, h=500):
    a = np.zeros((h, w, 3), np.float32) + np.array([70, 84, 50], np.float32)
    a *= (0.8 + 0.3 * fbm(w, h, 5, 6, 61))[..., None]
    im = img(a); d = ImageDraw.Draw(im)
    for k in (0.16, 0.84):
        d.rectangle([int(w * k) - 18, 0, int(w * k) + 18, h], fill=(52, 64, 38))
    d.rectangle([0, 0, w - 1, h - 1], outline=(32, 40, 24), width=10)
    try:
        f = ImageFont.truetype(FONT, 120); d.text((w // 2, h // 2 + 8), "AMMO", font=f, fill=(170, 174, 136), anchor="mm")
    except Exception:
        pass
    a = np.asarray(im).astype(np.float32) * (0.85 + 0.25 * fbm(w, h, 4, 10, 62))[..., None]
    return a

def steel(w=1024, h=640):
    a = np.zeros((h, w, 3), np.float32) + np.array([88, 90, 96], np.float32)
    a *= (0.82 + 0.24 * fbm(w, h, 5, 8, 71))[..., None]
    a += (np.asarray(img(nrng.random((h, w)) * 255).filter(ImageFilter.BoxBlur(1))).astype(np.float32)[..., None] / 255 - 0.5) * 12
    im = img(a); d = ImageDraw.Draw(im)
    d.rectangle([0, 0, w - 1, h - 1], outline=(40, 40, 44), width=10)
    d.line([0, 120, w, 120], fill=(36, 36, 40), width=8)
    for xx in range(24, w, 70):
        for yy in (24, 140, h - 26):
            d.ellipse([xx - 8, yy - 8, xx + 8, yy + 8], fill=(130, 132, 138)); d.ellipse([xx - 4, yy - 6, xx, yy - 2], fill=(200, 202, 206))
    d.rectangle([90, 150, 160, 270], fill=(196, 102, 32)); d.rectangle([90, 150, 160, 270], outline=(96, 48, 16), width=4)
    return np.asarray(im).astype(np.float32)

def gauge(s=256):
    im = Image.new("RGBA", (s, s), (0, 0, 0, 0)); d = ImageDraw.Draw(im); c = s / 2; r = s * 0.46
    d.ellipse([c - r, c - r, c + r, c + r], fill=(150, 112, 56, 255)); r2 = r * 0.84
    d.ellipse([c - r2, c - r2, c + r2, c + r2], fill=(226, 216, 190, 255))
    for k in range(11):
        an = math.pi * (0.75 + k * 0.15)
        d.line([c + math.cos(an) * r2 * 0.72, c + math.sin(an) * r2 * 0.72, c + math.cos(an) * r2 * 0.92, c + math.sin(an) * r2 * 0.92], fill=(40, 36, 30, 255), width=4)
    an = math.pi * 1.6
    d.line([c, c, c + math.cos(an) * r2 * 0.8, c + math.sin(an) * r2 * 0.8], fill=(170, 30, 24, 255), width=7)
    d.ellipse([c - 9, c - 9, c + 9, c + 9], fill=(40, 36, 30, 255))
    return im

if __name__ == "__main__":
    out = sys.argv[1]; os.makedirs(out, exist_ok=True)
    save(back_wall(), os.path.join(out, "hideout_wall.jpg"))
    save(plaster(1400, 820, 3, base=(132, 116, 96)), os.path.join(out, "hideout_side.jpg"))
    save(planks(2048, 1400, 5, pw=120, base=(108, 76, 50)), os.path.join(out, "hideout_floor.jpg"))
    save(board(), os.path.join(out, "hideout_board.jpg"))
    save(poster("target"), os.path.join(out, "hideout_poster_target.jpg"))
    save(poster("wanted"), os.path.join(out, "hideout_poster_wanted.jpg"))
    save(rug(), os.path.join(out, "hideout_rug.jpg"))
    save(city(), os.path.join(out, "hideout_city.jpg"))
    save(crate(), os.path.join(out, "hideout_crate.jpg"))
    save(steel(), os.path.join(out, "hideout_steel.jpg"))
    save(planks(512, 512, 9, pw=512, base=(110, 74, 46)), os.path.join(out, "hideout_wood.jpg"))
    save(gauge(), os.path.join(out, "hideout_gauge.png"))
    save(planks(1024, 512, 15, pw=256, base=(46, 34, 26), horizontal=True), os.path.join(out, "hideout_ceiling.jpg"))
    print("ok")
