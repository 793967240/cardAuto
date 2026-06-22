from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
import math
import random


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "ui" / "themes" / "xianxia"


def lerp(a, b, t):
    return int(a + (b - a) * t)


def gradient(size, top, bottom):
    w, h = size
    img = Image.new("RGBA", size)
    px = img.load()
    for y in range(h):
        t = y / max(h - 1, 1)
        for x in range(w):
            px[x, y] = tuple(lerp(top[i], bottom[i], t) for i in range(4))
    return img


def poly_mountain(draw, w, h, base_y, amp, color, seed):
    rng = random.Random(seed)
    points = [(-120, h + 80), (-120, base_y)]
    x = -80
    while x < w + 160:
        peak = base_y - rng.uniform(amp * 0.35, amp)
        points.append((x + rng.uniform(20, 90), peak))
        points.append((x + rng.uniform(110, 190), base_y + rng.uniform(-18, 34)))
        x += rng.uniform(150, 230)
    points.extend([(w + 120, base_y), (w + 120, h + 80)])
    draw.polygon(points, fill=color)


def draw_clouds(layer, seed, count, tint):
    rng = random.Random(seed)
    draw = ImageDraw.Draw(layer, "RGBA")
    w, h = layer.size
    for _ in range(count):
        cx = rng.randint(-120, w + 120)
        cy = rng.randint(int(h * 0.12), int(h * 0.88))
        rx = rng.randint(120, 360)
        ry = rng.randint(22, 72)
        for i in range(10):
            ox = rng.randint(-rx, rx)
            oy = rng.randint(-ry, ry)
            rrx = rng.randint(int(rx * 0.16), int(rx * 0.38))
            rry = rng.randint(int(ry * 0.45), int(ry * 1.2))
            draw.ellipse((cx + ox - rrx, cy + oy - rry, cx + ox + rrx, cy + oy + rry), fill=tint)
    return layer.filter(ImageFilter.GaussianBlur(18))


def draw_pine(draw, x, y, scale, color):
    trunk = (x - 2 * scale, y - 52 * scale, x + 2 * scale, y + 4 * scale)
    draw.rounded_rectangle(trunk, radius=max(1, int(scale)), fill=color)
    for i in range(5):
        yy = y - (12 + i * 11) * scale
        half = (28 - i * 3) * scale
        draw.line((x, yy - 12 * scale, x - half, yy + 7 * scale), fill=color, width=max(1, int(3 * scale)))
        draw.line((x, yy - 12 * scale, x + half, yy + 7 * scale), fill=color, width=max(1, int(3 * scale)))


def draw_crane(draw, x, y, scale, color):
    draw.arc((x - 34 * scale, y - 18 * scale, x + 28 * scale, y + 28 * scale), 195, 330, fill=color, width=max(1, int(3 * scale)))
    draw.line((x + 22 * scale, y + 4 * scale, x + 48 * scale, y - 10 * scale), fill=color, width=max(1, int(2 * scale)))
    draw.line((x + 22 * scale, y + 4 * scale, x + 40 * scale, y + 18 * scale), fill=color, width=max(1, int(2 * scale)))
    draw.ellipse((x + 44 * scale, y - 15 * scale, x + 50 * scale, y - 9 * scale), fill=color)


def make_background(path, size=(1920, 1080), seed=7, variant=0):
    w, h = size
    img = gradient(size, (235, 248, 246, 255), (204, 230, 231, 255))
    mist = Image.new("RGBA", size, (0, 0, 0, 0))
    img.alpha_composite(draw_clouds(mist, seed + 1, 28, (255, 255, 255, 54)))
    draw = ImageDraw.Draw(img, "RGBA")
    poly_mountain(draw, w, h, int(h * 0.40), int(h * 0.19), (112, 160, 162, 38), seed + 2)
    poly_mountain(draw, w, h, int(h * 0.57), int(h * 0.28), (68, 126, 128, 52), seed + 3)
    poly_mountain(draw, w, h, int(h * 0.78), int(h * 0.30), (52, 111, 109, 58), seed + 4)
    for i in range(variant + 2):
        x = 180 + i * 470 + (seed % 80)
        y = int(h * (0.72 + 0.04 * (i % 2)))
        draw_pine(draw, x, y, 1.1 + i * 0.12, (40, 107, 96, 55))
    for i in range(4):
        draw_crane(draw, w - 360 + i * 90, 145 + (i % 2) * 32, 0.55, (51, 110, 112, 74))
    veil = Image.new("RGBA", size, (246, 252, 248, 90))
    img.alpha_composite(veil)
    img.save(path)


def rounded_panel(path, size=(360, 220), fill=(239, 249, 244, 214), border=(84, 149, 142, 160)):
    w, h = size
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    shadow = Image.new("RGBA", size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow, "RGBA")
    sd.rounded_rectangle((16, 18, w - 14, h - 12), radius=18, fill=(34, 88, 86, 46))
    shadow = shadow.filter(ImageFilter.GaussianBlur(10))
    img.alpha_composite(shadow)
    d = ImageDraw.Draw(img, "RGBA")
    d.rounded_rectangle((10, 8, w - 12, h - 16), radius=16, fill=fill, outline=border, width=3)
    d.rounded_rectangle((20, 18, w - 22, h - 26), radius=10, outline=(255, 255, 255, 118), width=2)
    for x, y, flip in [(22, 20, 1), (w - 42, 20, -1), (22, h - 48, 1), (w - 42, h - 48, -1)]:
        d.arc((x, y, x + 24, y + 24), 180 if flip > 0 else 270, 270 if flip > 0 else 360, fill=(75, 139, 132, 124), width=2)
    img.save(path)


def make_topbar(path, size=(1920, 96)):
    img = gradient(size, (235, 249, 246, 225), (205, 232, 229, 210))
    d = ImageDraw.Draw(img, "RGBA")
    w, h = size
    d.rectangle((0, h - 3, w, h), fill=(70, 139, 135, 138))
    d.line((0, 6, w, 6), fill=(255, 255, 255, 120), width=2)
    for i in range(28):
        x = i * 88
        d.line((x, h - 16, x + 34, h - 16), fill=(94, 155, 148, 56), width=1)
    img.save(path)


def make_button(path, size=(320, 80)):
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(img, "RGBA")
    w, h = size
    d.rounded_rectangle((8, 10, w - 8, h - 12), radius=24, fill=(229, 246, 239, 232), outline=(82, 148, 141, 176), width=3)
    d.rounded_rectangle((18, 18, w - 18, h - 20), radius=18, outline=(255, 255, 255, 128), width=2)
    d.line((44, h - 20, w - 44, h - 20), fill=(150, 190, 158, 112), width=2)
    img.save(path)


def main():
    for sub in ["backgrounds", "panels", "bars", "buttons"]:
        (OUT / sub).mkdir(parents=True, exist_ok=True)
    make_background(OUT / "backgrounds" / "fresh_mountain_battle.png", seed=12, variant=2)
    make_background(OUT / "backgrounds" / "fresh_mountain_menu.png", seed=33, variant=0)
    make_background(OUT / "backgrounds" / "fresh_mountain_map.png", seed=54, variant=1)
    rounded_panel(OUT / "panels" / "fresh_panel_frame.png")
    rounded_panel(OUT / "panels" / "fresh_panel_frame_large.png", (560, 360), (239, 250, 246, 206), (75, 145, 139, 150))
    make_topbar(OUT / "bars" / "fresh_topbar.png")
    make_button(OUT / "buttons" / "btn_fresh_jade.png")


if __name__ == "__main__":
    main()
