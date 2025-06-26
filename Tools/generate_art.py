#!/usr/bin/env python3
"""Deterministic pixel-art generator for CarSpeedtrack.

Everything is drawn from code with Pillow. No external art is used.
Outputs PNGs into CarSpeedtrack/Resources/Art and a font metrics JSON into
CarSpeedtrack/Resources/Data/font.json.

The art is intentionally authored at a small native resolution with a limited
palette, dark-plum outlines, and no anti-aliasing so it stays crisp at 2x/3x.
"""
from __future__ import annotations

import json
import math
import os
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
ART_DIR = ROOT / "CarSpeedtrack" / "Resources" / "Art"
DATA_DIR = ROOT / "CarSpeedtrack" / "Resources" / "Data"
BUILD_DIR = ROOT / "build"
OUTLINE = (54, 34, 62, 255)          # dark plum, friendlier than black
OUTLINE_SOFT = (75, 48, 82, 255)
SHADOW = (54, 34, 62, 90)
WHITE = (255, 252, 240, 255)
CREAM = (255, 244, 214, 255)
INK = (63, 42, 72, 255)

FONT_PATH = "/System/Library/Fonts/Monaco.ttf"
FONT_SIZE = 15
FONT_CELL_W = 12
FONT_CELL_H = 20
FONT_ADVANCE = 9
FONT_LINE_HEIGHT = 18
FIRST_CHAR = 32
LAST_CHAR = 126


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def ensure_dirs() -> None:
    ART_DIR.mkdir(parents=True, exist_ok=True)
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    BUILD_DIR.mkdir(parents=True, exist_ok=True)


def new_image(w: int, h: int) -> Image.Image:
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def rounded_rect(draw: ImageDraw.ImageDraw, box, radius, fill=None, outline=None, width=1):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def add_outline(img: Image.Image, color=OUTLINE, width: int = 1) -> Image.Image:
    """Add a crisp pixel outline around the alpha silhouette."""
    a = img.getchannel("A")
    w, h = img.size
    src = a.load()
    out = Image.new("RGBA", (w, h), color)
    dst = out.load()
    for y in range(h):
        for x in range(w):
            if src[x, y] > 0:
                dst[x, y] = (0, 0, 0, 0)
                continue
            hit = False
            for dy in range(-width, width + 1):
                for dx in range(-width, width + 1):
                    if dx == 0 and dy == 0:
                        continue
                    if 0 <= x + dx < w and 0 <= y + dy < h and src[x + dx, y + dy] > 0:
                        hit = True
                        break
                if hit:
                    break
            if not hit:
                dst[x, y] = (0, 0, 0, 0)
    out.alpha_composite(img)
    return out


def add_shadow(img: Image.Image, offset=(2, 3), color=SHADOW) -> Image.Image:
    pad = max(abs(offset[0]), abs(offset[1]))
    canvas = new_image(img.width + pad * 2, img.height + pad * 2)
    alpha = img.getchannel("A")
    shadow = Image.new("RGBA", img.size, color)
    shadow.putalpha(alpha.point(lambda p: min(color[3], p)))
    canvas.alpha_composite(shadow, (pad + offset[0], pad + offset[1]))
    canvas.alpha_composite(img, (pad, pad))
    return canvas


def save(img: Image.Image, name: str, shadow=False) -> None:
    if shadow:
        img = add_shadow(img)
    img.save(ART_DIR / f"{name}.png", "PNG")


def seeded_rng(world: int, salt: int = 0) -> random.Random:
    return random.Random(0xC0FFEE + world * 977 + salt * 131)


# Shared saturating palette. Individual worlds add their own colours.
PAL = {
    "plum": (74, 45, 85, 255),
    "ink": (52, 32, 62, 255),
    "cream": (255, 246, 219, 255),
    "white": (255, 255, 250, 255),
    "pink": (255, 116, 162, 255),
    "rose": (226, 74, 132, 255),
    "red": (243, 83, 104, 255),
    "orange": (255, 159, 69, 255),
    "yellow": (255, 216, 88, 255),
    "sun": (255, 184, 48, 255),
    "lime": (150, 225, 121, 255),
    "mint": (96, 218, 176, 255),
    "teal": (50, 184, 190, 255),
    "sky": (105, 197, 255, 255),
    "blue": (79, 130, 235, 255),
    "lavender": (187, 143, 255, 255),
    "purple": (137, 92, 214, 255),
    "sand": (246, 214, 154, 255),
    "brown": (174, 118, 81, 255),
    "grey": (143, 146, 172, 255),
    "dark": (61, 52, 85, 255),
    "ice": (206, 246, 255, 255),
    "navy": (29, 29, 61, 255),
}

CAR_SPECS = [
    # id, name, body, accent, roof, style, stats
    ("sunny-bug", "Sunny Bug", (255, 196, 64), (255, 247, 203), (245, 133, 62), "stripe"),
    ("mint-mini", "Mint Mini", (100, 223, 170), (255, 247, 203), (54, 166, 147), "dots"),
    ("coral-cruiser", "Coral Cruiser", (255, 126, 125), (255, 244, 214), (226, 77, 133), "twin"),
    ("tangerine-turbo", "Tangerine Turbo", (255, 143, 56), (255, 238, 174), (206, 74, 84), "stripe"),
    ("berry-bolt", "Berry Bolt", (187, 121, 238), (255, 236, 250), (115, 71, 193), "dots"),
    ("lemon-lightning", "Lemon Lightning", (255, 230, 86), (255, 255, 236), (230, 167, 53), "twin"),
    ("aqua-ace", "Aqua Ace", (77, 203, 235), (226, 255, 255), (51, 128, 203), "stripe"),
    ("rainbow-rocket", "Rainbow Rocket", (255, 111, 188), (255, 246, 219), (100, 97, 230), "rainbow"),
]

TRAFFIC_SPECS = [
    ("lilac", (185, 156, 230), (255, 236, 250), (128, 94, 183)),
    ("peach", (255, 175, 142), (255, 250, 230), (210, 96, 99)),
    ("minty", (141, 219, 190), (255, 250, 238), (66, 150, 135)),
    ("sky", (125, 194, 245), (250, 252, 255), (69, 115, 184)),
    ("butter", (250, 213, 110), (255, 250, 232), (190, 136, 56)),
]

HAZARD_FILES = [
    "cone", "spike", "pothole", "jelly", "puddle",
    "beachball_0", "beachball_1", "tumbleweed_0", "tumbleweed_1",
    "asteroid_0", "asteroid_1", "snowball_0", "snowball_1",
    "ember_0", "ember_1",
]

PICKUP_FILES = [
    "coin_0", "coin_1", "coin_2", "coin_3",
    "gem", "heart", "shield", "magnet", "star",
]

ICON_FILES = [
    "heart_full", "heart_empty", "star_full", "star_empty", "lock",
    "coin", "gem", "shield", "magnet", "boost", "gear", "trophy",
    "play", "pause", "back", "arrow_left", "arrow_right", "target",
    "check", "cross",
]

# ---------------------------------------------------------------------------
# Cars
# ---------------------------------------------------------------------------

def draw_car(body, accent, roof, style: str, steer: int = 0, brake: bool = False) -> Image.Image:
    """Draw a 36x58 top-down car. steer: -1 left, 0 straight, 1 right."""
    img = new_image(36, 58)
    d = ImageDraw.Draw(img)

    # Wheels (drawn first so the body overlaps them slightly).
    wheel = (47, 43, 68, 255)
    hub = (152, 143, 166, 255)
    wheel_boxes = [(3, 12, 9, 25), (27, 12, 33, 25), (3, 39, 9, 51), (27, 39, 33, 51)]
    if steer < 0:
        wheel_boxes[0] = (2, 11, 8, 24)
        wheel_boxes[1] = (26, 11, 32, 24)
    elif steer > 0:
        wheel_boxes[0] = (4, 11, 10, 24)
        wheel_boxes[1] = (28, 11, 34, 24)
    for box in wheel_boxes:
        d.rounded_rectangle(box, radius=2, fill=wheel, outline=None)
        x0, y0, x1, y1 = box
        d.rectangle((x0 + 1, (y0 + y1) // 2 - 2, x1 - 1, (y0 + y1) // 2 + 2), fill=hub)

    # Body silhouette: tapered nose, rounded rear.
    body_pts = [(12, 4), (24, 4), (29, 10), (31, 17), (32, 47),
                (27, 53), (9, 53), (4, 47), (5, 17), (7, 10)]
    d.polygon(body_pts, fill=body)
    # side highlight/shadow bands
    d.rectangle((6, 17, 8, 45), fill=tuple(min(255, c + 22) for c in body[:3]) + (255,))
    d.rectangle((28, 18, 30, 45), fill=tuple(max(0, c - 28) for c in body[:3]) + (255,))
    # roof / cabin
    d.rounded_rectangle((9, 17, 27, 40), radius=5, fill=roof)
    # windshield and rear window
    d.polygon([(11, 19), (25, 19), (27, 26), (9, 26)], fill=(173, 234, 242, 255))
    d.polygon([(10, 37), (26, 37), (24, 42), (12, 42)], fill=(151, 216, 232, 255))
    d.line((12, 22, 20, 22), fill=(255, 255, 255, 200), width=1)
    d.line((13, 39, 21, 39), fill=(255, 255, 255, 150), width=1)
    # accents down the hood
    if style == "stripe":
        d.rectangle((17, 5, 19, 17), fill=accent)
    elif style == "twin":
        d.rectangle((13, 5, 15, 17), fill=accent)
        d.rectangle((21, 5, 23, 17), fill=accent)
    elif style == "dots":
        for y in (6, 10, 14):
            d.rectangle((17, y, 19, y + 2), fill=accent)
    elif style == "rainbow":
        for i, color in enumerate([(255, 105, 120), (255, 206, 79), (116, 219, 154), (104, 183, 255)]):
            d.rectangle((13 + i * 3, 5, 15 + i * 3, 17), fill=color + (255,))
    # headlights / tail lights
    d.rectangle((8, 5, 11, 7), fill=(255, 245, 158, 255))
    d.rectangle((25, 5, 28, 7), fill=(255, 245, 158, 255))
    tail = (255, 85, 105, 255) if brake else (206, 54, 90, 255)
    d.rectangle((7, 51, 10, 53), fill=tail)
    d.rectangle((26, 51, 29, 53), fill=tail)
    # little spoiler on some cars
    if style in ("stripe", "twin", "rainbow"):
        d.rectangle((5, 49, 31, 51), fill=tuple(max(0, c - 24) for c in roof[:3]) + (255,))
    # mirror pixels
    d.rectangle((7, 28, 8, 30), fill=accent)
    d.rectangle((28, 28, 29, 30), fill=accent)

    img = add_outline(img, OUTLINE, 1)
    return img


def generate_cars() -> None:
    for cid, name, body, accent, roof, style in CAR_SPECS:
        for idx, steer in enumerate([0, -1, 1, 0]):
            brake = idx == 3
            img = draw_car(body, accent, roof, style, steer, brake)
            save(img, f"car_{cid}_{idx}")
    for i, (_, body, accent, roof) in enumerate(TRAFFIC_SPECS):
        save(draw_car(body, accent, roof, "dots"), f"traffic_{i}")


# ---------------------------------------------------------------------------
# Pickups, hazards, decorations
# ---------------------------------------------------------------------------

def star_polygon(cx, cy, outer, inner, points=5):
    result = []
    for i in range(points * 2):
        r = outer if i % 2 == 0 else inner
        a = -math.pi / 2 + i * math.pi / points
        result.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return result


def draw_coin(frame: int) -> Image.Image:
    widths = [12, 8, 4, 8]
    w = widths[frame]
    img = new_image(16, 16)
    d = ImageDraw.Draw(img)
    x0 = (16 - w) // 2
    d.ellipse((x0, 3, x0 + w - 1, 12), fill=PAL["yellow"], outline=PAL["sun"])
    if w >= 8:
        d.rectangle((x0 + 1, 5, x0 + 2, 9), fill=(255, 255, 210, 220))
        d.rectangle((x0 + w - 3, 6, x0 + w - 2, 9), fill=PAL["sun"])
    img = add_outline(img, OUTLINE, 1)
    return img


def draw_gem() -> Image.Image:
    img = new_image(18, 18)
    d = ImageDraw.Draw(img)
    d.polygon([(9, 1), (16, 7), (9, 17), (2, 7)], fill=(111, 231, 234, 255))
    d.polygon([(9, 1), (16, 7), (9, 9), (2, 7)], fill=(184, 255, 247, 255))
    d.polygon([(9, 9), (16, 7), (9, 17)], fill=(55, 191, 209, 255))
    d.line((4, 7, 14, 7), fill=(255, 255, 255, 220), width=1)
    return add_outline(img, OUTLINE, 1)


def draw_heart(size=16, full=True) -> Image.Image:
    img = new_image(size, size)
    d = ImageDraw.Draw(img)
    s = size
    col = PAL["pink"] if full else (106, 88, 113, 255)
    d.ellipse((1, 3, s // 2, s // 2 + 1), fill=col)
    d.ellipse((s // 2 - 1, 3, s - 2, s // 2 + 1), fill=col)
    d.polygon([(2, s // 2), (s // 2, s - 2), (s - 3, s // 2)], fill=col)
    if full:
        d.rectangle((4, 5, 6, 6), fill=(255, 220, 230, 220))
    return add_outline(img, OUTLINE, 1)


def draw_shield() -> Image.Image:
    img = new_image(18, 20)
    d = ImageDraw.Draw(img)
    d.polygon([(9, 1), (16, 4), (15, 12), (9, 18), (3, 12), (2, 4)],
              fill=(99, 190, 245, 255))
    d.polygon([(9, 4), (13, 6), (12, 11), (9, 14), (6, 11), (5, 6)],
              fill=(190, 242, 255, 255))
    return add_outline(img, OUTLINE, 1)


def draw_magnet() -> Image.Image:
    img = new_image(18, 18)
    d = ImageDraw.Draw(img)
    d.arc((2, 2, 16, 16), 180, 360, fill=PAL["red"], width=5)
    d.rectangle((2, 8, 6, 15), fill=PAL["red"])
    d.rectangle((12, 8, 16, 15), fill=PAL["red"])
    d.rectangle((2, 3, 6, 7), fill=PAL["sky"])
    d.rectangle((12, 3, 16, 7), fill=PAL["sky"])
    return add_outline(img, OUTLINE, 1)


def draw_star() -> Image.Image:
    img = new_image(20, 20)
    d = ImageDraw.Draw(img)
    d.polygon(star_polygon(10, 10, 9, 4), fill=PAL["yellow"])
    d.polygon(star_polygon(10, 9, 5, 2), fill=(255, 255, 213, 230))
    return add_outline(img, OUTLINE, 1)


def generate_pickups() -> None:
    for i in range(4):
        save(draw_coin(i), f"pickup_coin_{i}")
    save(draw_gem(), "pickup_gem")
    save(draw_heart(16, True), "pickup_heart")
    save(draw_shield(), "pickup_shield")
    save(draw_magnet(), "pickup_magnet")
    save(draw_star(), "pickup_star")

    # UI icons reuse some art with clearer silhouettes.
    save(draw_heart(20, True), "icon_heart_full")
    save(draw_heart(20, False), "icon_heart_empty")
    save(draw_star(), "icon_star_full")
    empty = draw_star().copy()
    # Desaturate for an empty star icon.
    px = empty.load()
    for y in range(empty.height):
        for x in range(empty.width):
            r, g, b, a = px[x, y]
            if a:
                if (r, g, b) == PAL["yellow"][:3] or (r, g, b) == (255, 255, 213):
                    px[x, y] = (122, 113, 139, 255)
                elif (r, g, b) == OUTLINE[:3]:
                    px[x, y] = OUTLINE
    save(empty, "icon_star_empty")
    save(draw_shield(), "icon_shield")
    save(draw_magnet(), "icon_magnet")
    save(draw_gem(), "icon_gem")
    save(draw_coin(0), "icon_coin")


def draw_cone() -> Image.Image:
    img = new_image(20, 26)
    d = ImageDraw.Draw(img)
    d.polygon([(10, 1), (17, 20), (3, 20)], fill=PAL["orange"])
    d.rectangle((2, 20, 18, 24), fill=(241, 120, 56, 255))
    d.rectangle((7, 8, 13, 11), fill=WHITE)
    d.rectangle((5, 14, 15, 17), fill=WHITE)
    d.rectangle((4, 22, 16, 23), fill=(188, 75, 55, 255))
    return add_outline(img, OUTLINE, 1)


def draw_spike() -> Image.Image:
    img = new_image(34, 18)
    d = ImageDraw.Draw(img)
    d.rectangle((1, 11, 32, 15), fill=PAL["grey"])
    for x in range(3, 33, 8):
        d.polygon([(x, 11), (x + 4, 1), (x + 7, 11)], fill=(230, 234, 241, 255))
        d.line((x + 2, 8, x + 4, 3), fill=WHITE, width=1)
    return add_outline(img, OUTLINE, 1)


def draw_pothole(soup=False, color=(97, 76, 113, 255)) -> Image.Image:
    img = new_image(32, 22)
    d = ImageDraw.Draw(img)
    d.ellipse((1, 4, 30, 19), fill=color)
    if not soup:
        d.ellipse((4, 6, 15, 12), fill=(76, 60, 91, 255))
        d.arc((2, 4, 30, 19), 15, 160, fill=(55, 43, 70, 255), width=2)
    else:
        d.ellipse((4, 6, 26, 16), fill=(255, 172, 206, 255))
        d.rectangle((7, 7, 9, 8), fill=(255, 245, 250, 230))
    return add_outline(img, OUTLINE, 1)


def draw_puddle() -> Image.Image:
    img = new_image(34, 20)
    d = ImageDraw.Draw(img)
    d.ellipse((1, 4, 32, 18), fill=(94, 200, 236, 200))
    d.ellipse((6, 6, 22, 12), fill=(186, 248, 255, 160))
    d.arc((4, 5, 29, 17), 200, 340, fill=(245, 255, 255, 230), width=1)
    return add_outline(img, OUTLINE, 1)


def draw_beachball(frame: int) -> Image.Image:
    img = new_image(28, 28)
    d = ImageDraw.Draw(img)
    d.ellipse((2, 2, 25, 25), fill=(255, 252, 240, 255))
    colors = [PAL["pink"], PAL["yellow"], PAL["sky"], PAL["mint"]]
    for i, col in enumerate(colors):
        start = i * 90 + frame * 15
        d.pieslice((2, 2, 25, 25), start, start + 90, fill=col)
    d.ellipse((10, 10, 17, 17), fill=(255, 252, 240, 255))
    d.ellipse((12, 12, 15, 15), fill=PAL["pink"])
    return add_outline(img, OUTLINE, 1)


def draw_tumbleweed(frame: int) -> Image.Image:
    img = new_image(28, 28)
    d = ImageDraw.Draw(img)
    rng = random.Random(42 + frame)
    for _ in range(11):
        a = rng.random() * math.pi * 2
        b = a + math.pi * (0.5 + rng.random() * 0.7)
        d.arc((3, 3, 24, 24), int(math.degrees(a)), int(math.degrees(b)),
              fill=(171, 125, 71, 255), width=2)
    for _ in range(5):
        x, y = rng.randint(5, 22), rng.randint(5, 22)
        d.point((x, y), fill=(226, 184, 116, 255))
    return add_outline(img, OUTLINE, 1)


def draw_asteroid(frame: int) -> Image.Image:
    img = new_image(30, 30)
    d = ImageDraw.Draw(img)
    d.ellipse((2, 3, 27, 27), fill=(142, 137, 170, 255))
    d.ellipse((5, 5, 17, 14), fill=(183, 176, 206, 255))
    craters = [(18, 15, 4), (9, 19, 3), (19, 23, 2)]
    for i, (x, y, r) in enumerate(craters):
        if (i + frame) % 3 != 0 or i == 0:
            d.ellipse((x - r, y - r, x + r, y + r), fill=(101, 94, 129, 255))
    d.point((8, 9), fill=(255, 255, 255, 220))
    return add_outline(img, OUTLINE, 1)


def draw_snowball(frame: int) -> Image.Image:
    img = new_image(26, 26)
    d = ImageDraw.Draw(img)
    d.ellipse((2, 2, 23, 23), fill=(228, 250, 255, 255))
    d.ellipse((5, 5, 16, 14), fill=(255, 255, 255, 255))
    d.ellipse((16, 15, 21, 20), fill=(169, 225, 246, 255))
    tilts = [0, 4, 9]
    for i in range(3):
        a = 20 + i * 60 + tilts[frame % 3]
        d.arc((2, 2, 23, 23), a, a + 38, fill=(156, 218, 242, 255), width=1)
    return add_outline(img, OUTLINE, 1)


def draw_ember(frame: int) -> Image.Image:
    img = new_image(24, 26)
    d = ImageDraw.Draw(img)
    d.polygon([(12, 1), (21, 12), (19, 22), (12, 25), (5, 22), (3, 12)],
              fill=(255, 119, 66, 255))
    inner = (255, 194, 60, 255) if frame == 0 else (255, 226, 111, 255)
    d.polygon([(12, 7), (17, 13), (15, 20), (9, 20), (7, 13)], fill=inner)
    d.rectangle((10, 15, 13, 18), fill=(255, 250, 196, 255))
    return add_outline(img, OUTLINE, 1)


def draw_jelly() -> Image.Image:
    img = draw_pothole(soup=True)
    return img


def generate_hazards() -> None:
    save(draw_cone(), "hazard_cone")
    save(draw_spike(), "hazard_spike")
    save(draw_pothole(), "hazard_pothole")
    save(draw_jelly(), "hazard_jelly")
    save(draw_puddle(), "hazard_puddle")
    for i in range(2):
        save(draw_beachball(i), f"hazard_beachball_{i}")
        save(draw_tumbleweed(i), f"hazard_tumbleweed_{i}")
        save(draw_asteroid(i), f"hazard_asteroid_{i}")
        save(draw_snowball(i), f"hazard_snowball_{i}")
        save(draw_ember(i), f"hazard_ember_{i}")

# ---------------------------------------------------------------------------
# Ground tiles, decorations, backgrounds
# ---------------------------------------------------------------------------

WORLD_STYLES = [
    # base, dark, light, style
    ((119, 211, 121, 255), (76, 169, 94, 255), (187, 246, 164, 255), "meadow"),
    ((255, 180, 211, 255), (235, 119, 168, 255), (255, 226, 240, 255), "candy"),
    ((241, 183, 104, 255), (211, 128, 74, 255), (255, 224, 156, 255), "canyon"),
    ((104, 220, 207, 255), (65, 165, 177, 255), (181, 252, 235, 255), "city"),
    ((193, 173, 255, 255), (146, 118, 218, 255), (242, 218, 255, 255), "rainbow"),
    ((92, 210, 232, 255), (47, 153, 193, 255), (174, 250, 255, 255), "ocean"),
    ((58, 48, 111, 255), (37, 31, 78, 255), (134, 113, 213, 255), "space"),
    ((214, 245, 255, 255), (151, 213, 235, 255), (255, 255, 255, 255), "snow"),
    ((255, 194, 154, 255), (232, 119, 104, 255), (255, 236, 190, 255), "volcano"),
    ((38, 43, 93, 255), (23, 27, 68, 255), (100, 231, 193, 255), "aurora"),
]


def wrap_circle(d, size, x, y, r, fill):
    for ox, oy in ((0, 0), (-size, 0), (size, 0), (0, -size), (0, size),
                   (-size, -size), (size, size), (-size, size), (size, -size)):
        d.ellipse((x + ox - r, y + oy - r, x + ox + r, y + oy + r), fill=fill)


def generate_ground() -> None:
    for wi, (base, dark, light, style) in enumerate(WORLD_STYLES, start=1):
        size = 64
        img = new_image(size, size)
        d = ImageDraw.Draw(img)
        d.rectangle((0, 0, size, size), fill=base)
        rng = seeded_rng(wi, 7)
        if style == "meadow":
            for _ in range(18):
                x, y = rng.randrange(size), rng.randrange(size)
                wrap_circle(d, size, x, y, rng.choice([1, 1, 2]), dark)
            for _ in range(8):
                x, y = rng.randrange(size), rng.randrange(size)
                wrap_circle(d, size, x, y, 2, light)
                wrap_circle(d, size, x, y, 1, (255, 240, 155, 255))
        elif style == "candy":
            for _ in range(14):
                x, y = rng.randrange(size), rng.randrange(size)
                wrap_circle(d, size, x, y, rng.choice([2, 3, 4]), light)
            for y in range(0, size, 16):
                d.line((0, y, size, y), fill=(255, 220, 233, 100), width=1)
        elif style == "canyon":
            for y in range(0, size, 9):
                d.line((0, y, size, y + 2), fill=dark, width=1)
            for _ in range(10):
                x, y = rng.randrange(size), rng.randrange(size)
                d.rectangle((x, y, x + 3, y + 2), fill=light)
        elif style == "city":
            d.rectangle((0, 0, size, size), fill=(78, 193, 194, 255))
            for x in range(0, size, 16):
                d.line((x, 0, x, size), fill=(49, 153, 169, 255), width=1)
            for y in range(0, size, 16):
                d.line((0, y, size, y), fill=(49, 153, 169, 255), width=1)
            for _ in range(7):
                x, y = rng.randrange(0, size, 16), rng.randrange(0, size, 16)
                d.rectangle((x + 3, y + 3, x + 8, y + 8), fill=light)
        elif style == "rainbow":
            colors = [(255, 176, 194, 255), (255, 218, 145, 255), (174, 234, 177, 255),
                      (152, 208, 255, 255)]
            for i in range(4):
                for y in range(i * 16, i * 16 + 5):
                    d.line((0, y, size, y), fill=colors[i])
            for _ in range(10):
                x, y = rng.randrange(size), rng.randrange(size)
                wrap_circle(d, size, x, y, 1, light)
        elif style == "ocean":
            d.rectangle((0, 0, size, size), fill=(80, 204, 224, 255))
            for _ in range(14):
                x, y = rng.randrange(size), rng.randrange(size)
                d.arc((x - 8, y - 3, x + 8, y + 3), 200, 340, fill=light, width=1)
            for _ in range(6):
                x, y = rng.randrange(size), rng.randrange(size)
                wrap_circle(d, size, x, y, 1, (255, 255, 255, 210))
        elif style == "space":
            d.rectangle((0, 0, size, size), fill=(33, 31, 75, 255))
            for _ in range(18):
                x, y = rng.randrange(size), rng.randrange(size)
                d.point((x, y), fill=rng.choice([(255, 255, 255, 230), light, (255, 202, 246, 230)]))
            wrap_circle(d, size, 45, 40, 8, (70, 57, 129, 255))
            wrap_circle(d, size, 45, 40, 6, (112, 88, 170, 255))
        elif style == "snow":
            for _ in range(16):
                x, y = rng.randrange(size), rng.randrange(size)
                wrap_circle(d, size, x, y, rng.choice([1, 2]), (255, 255, 255, 255))
            for _ in range(6):
                x, y = rng.randrange(size), rng.randrange(size)
                d.line((x - 2, y, x + 2, y), fill=(255, 255, 255, 255), width=1)
                d.line((x, y - 2, x, y + 2), fill=(255, 255, 255, 255), width=1)
        elif style == "volcano":
            for _ in range(14):
                x, y = rng.randrange(size), rng.randrange(size)
                wrap_circle(d, size, x, y, rng.choice([1, 2, 3]), dark)
            for _ in range(6):
                x, y = rng.randrange(size), rng.randrange(size)
                d.line((x - 4, y + 3, x, y, x + 5, y + 2), fill=(255, 238, 156, 220), width=1)
        elif style == "aurora":
            d.rectangle((0, 0, size, size), fill=(30, 36, 82, 255))
            for y in range(0, size, 3):
                d.line((0, y, size, y), fill=(38, 48, 100, 255), width=1)
            for _ in range(10):
                x = rng.randrange(size)
                d.line((x - 8, 8, x + 4, 20), fill=(81, 225, 185, 110), width=3)
                d.line((x + 3, 5, x + 13, 19), fill=(165, 128, 247, 90), width=2)
            for _ in range(12):
                d.point((rng.randrange(size), rng.randrange(size)), fill=(255, 255, 240, 230))
        img.save(ART_DIR / f"ground_{wi}.png", "PNG")


def decorate(img, shadow=True):
    img = add_outline(img, OUTLINE, 1)
    if shadow:
        img = add_shadow(img, (2, 2), (54, 34, 62, 70))
    return img


def decor_tree() -> Image.Image:
    img = new_image(40, 56)
    d = ImageDraw.Draw(img)
    d.rectangle((17, 32, 23, 49), fill=PAL["brown"])
    for (x, y, r, c) in [(20, 22, 16, (66, 177, 100, 255)),
                         (12, 28, 11, (91, 206, 118, 255)),
                         (28, 28, 11, (89, 195, 113, 255)),
                         (20, 16, 11, (134, 229, 134, 255))]:
        d.ellipse((x - r, y - r, x + r, y + r), fill=c)
    d.rectangle((17, 39, 19, 41), fill=(234, 185, 114, 255))
    return decorate(img)


def decor_flower() -> Image.Image:
    img = new_image(32, 32)
    d = ImageDraw.Draw(img)
    for i, (x, y) in enumerate([(9, 18), (22, 13), (17, 24)]):
        col = [(255, 119, 158, 255), (255, 214, 103, 255), (190, 141, 255, 255)][i]
        for dx, dy in [(-3, 0), (3, 0), (0, -3), (0, 3)]:
            d.ellipse((x + dx - 3, y + dy - 3, x + dx + 3, y + dy + 3), fill=col)
        d.ellipse((x - 2, y - 2, x + 2, y + 2), fill=(255, 244, 143, 255))
    return decorate(img)


def decor_bush() -> Image.Image:
    img = new_image(34, 26)
    d = ImageDraw.Draw(img)
    for x, y, r, c in [(11, 16, 9, (65, 167, 101, 255)), (22, 15, 10, (91, 202, 116, 255)),
                       (17, 11, 8, (121, 220, 128, 255))]:
        d.ellipse((x - r, y - r, x + r, y + r), fill=c)
    for x, y in [(12, 15), (23, 17)]:
        d.ellipse((x, y, x + 3, y + 3), fill=(255, 238, 148, 255))
    return decorate(img)


def decor_cane() -> Image.Image:
    img = new_image(26, 52)
    d = ImageDraw.Draw(img)
    d.rectangle((9, 11, 18, 49), fill=(255, 245, 245, 255))
    for y in range(14, 49, 9):
        d.rectangle((9, y, 18, y + 4), fill=(255, 104, 147, 255))
    d.arc((1, 1, 24, 26), 180, 360, fill=(255, 245, 245, 255), width=9)
    d.arc((1, 1, 24, 26), 180, 300, fill=(255, 104, 147, 255), width=3)
    return decorate(img)


def decor_lollipop() -> Image.Image:
    img = new_image(30, 54)
    d = ImageDraw.Draw(img)
    d.rectangle((13, 24, 17, 51), fill=(228, 190, 122, 255))
    d.ellipse((2, 2, 28, 27), fill=(255, 160, 199, 255))
    for i in range(3):
        r = 10 - i * 3
        d.arc((15 - r, 14 - r, 15 + r, 14 + r), 20 + i * 80, 200 + i * 80,
              fill=(255, 245, 204, 255), width=2)
    return decorate(img)


def decor_gumdrop() -> Image.Image:
    img = new_image(28, 26)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((2, 7, 26, 23), radius=7, fill=(132, 226, 209, 255))
    d.rectangle((4, 20, 24, 23), fill=(99, 193, 185, 255))
    d.rectangle((8, 9, 11, 12), fill=(243, 255, 232, 220))
    return decorate(img)


def decor_cactus() -> Image.Image:
    img = new_image(32, 52)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((12, 10, 21, 49), radius=5, fill=(73, 182, 122, 255))
    d.rounded_rectangle((4, 20, 13, 28), radius=4, fill=(73, 182, 122, 255))
    d.rectangle((6, 24, 12, 27), fill=(73, 182, 122, 255))
    d.rounded_rectangle((20, 16, 29, 24), radius=4, fill=(73, 182, 122, 255))
    d.rectangle((20, 20, 25, 23), fill=(73, 182, 122, 255))
    for y in (17, 30, 42):
        d.point((15, y), fill=(176, 244, 160, 255))
        d.point((18, y + 3), fill=(176, 244, 160, 255))
    return decorate(img)


def decor_rock() -> Image.Image:
    img = new_image(34, 26)
    d = ImageDraw.Draw(img)
    d.polygon([(4, 22), (9, 8), (19, 4), (28, 12), (30, 22)], fill=(203, 142, 116, 255))
    d.polygon([(9, 20), (14, 11), (22, 9), (25, 20)], fill=(232, 174, 139, 255))
    d.point((15, 12), fill=(255, 229, 180, 230))
    return decorate(img)


def decor_desert_flower() -> Image.Image:
    img = new_image(26, 32)
    d = ImageDraw.Draw(img)
    d.line((13, 30, 13, 17), fill=(69, 154, 102, 255), width=3)
    for dx, dy in [(-5, 0), (5, 0), (0, -5), (0, 5)]:
        d.ellipse((13 + dx - 4, 14 + dy - 4, 13 + dx + 4, 14 + dy + 4),
                  fill=(255, 137, 109, 255))
    d.ellipse((10, 11, 16, 17), fill=(255, 228, 127, 255))
    return decorate(img)


def decor_neon() -> Image.Image:
    img = new_image(28, 48)
    d = ImageDraw.Draw(img)
    d.rectangle((11, 24, 16, 46), fill=(87, 78, 126, 255))
    d.rounded_rectangle((2, 3, 25, 26), radius=5, fill=(55, 48, 100, 255))
    d.rectangle((5, 6, 22, 23), fill=(255, 111, 201, 255))
    d.rectangle((8, 9, 19, 12), fill=(190, 255, 239, 255))
    d.rectangle((8, 15, 16, 18), fill=(255, 230, 128, 255))
    return decorate(img)


def decor_planter() -> Image.Image:
    img = new_image(30, 34)
    d = ImageDraw.Draw(img)
    d.polygon([(5, 18), (25, 18), (22, 32), (8, 32)], fill=(219, 106, 112, 255))
    for x, y, r, c in [(11, 12, 8, (88, 197, 150, 255)), (20, 13, 8, (116, 220, 159, 255))]:
        d.ellipse((x - r, y - r, x + r, y + r), fill=c)
    d.ellipse((12, 5, 17, 10), fill=(255, 182, 221, 255))
    return decorate(img)


def decor_flowerbox() -> Image.Image:
    img = new_image(36, 26)
    d = ImageDraw.Draw(img)
    d.rectangle((2, 12, 33, 23), fill=(158, 103, 80, 255))
    d.rectangle((3, 14, 32, 15), fill=(230, 169, 118, 255))
    for i, col in enumerate([(255, 133, 161, 255), (255, 221, 103, 255), (182, 150, 255, 255)]):
        d.ellipse((4 + i * 10, 3, 14 + i * 10, 13), fill=col)
        d.ellipse((8 + i * 10, 7, 10 + i * 10, 9), fill=(255, 247, 191, 255))
    return decorate(img)


def decor_rainbow_tree() -> Image.Image:
    img = new_image(42, 54)
    d = ImageDraw.Draw(img)
    d.rectangle((18, 32, 23, 50), fill=(178, 121, 81, 255))
    for i, col in enumerate([(255, 131, 166, 255), (255, 194, 111, 255),
                             (144, 227, 149, 255), (147, 187, 255, 255)]):
        d.ellipse((4 + i * 2, 5 + i * 4, 22 + i * 4, 31 + i), fill=col)
    return decorate(img)


def decor_palm() -> Image.Image:
    img = new_image(40, 58)
    d = ImageDraw.Draw(img)
    d.line((20, 55, 24, 23), fill=(174, 118, 81, 255), width=4)
    for pts in [[(23, 20), (4, 17), (20, 17)], [(23, 20), (38, 9), (23, 16)],
                [(23, 20), (4, 34), (20, 21)], [(23, 20), (39, 31), (24, 22)]]:
        d.polygon(pts, fill=(61, 177, 120, 255))
    d.ellipse((17, 12, 28, 22), fill=(82, 207, 127, 255))
    return decorate(img)


def decor_umbrella() -> Image.Image:
    img = new_image(40, 48)
    d = ImageDraw.Draw(img)
    d.line((20, 20, 20, 46), fill=(229, 187, 121, 255), width=3)
    d.pieslice((2, 2, 38, 26), 180, 360, fill=(255, 126, 143, 255))
    for x in (8, 20, 32):
        d.line((20, 13, x, 5), fill=(255, 241, 168, 255), width=1)
    d.polygon([(2, 13), (38, 13), (35, 19), (5, 19)], fill=(255, 172, 124, 255))
    return decorate(img)


def decor_shell() -> Image.Image:
    img = new_image(30, 26)
    d = ImageDraw.Draw(img)
    d.pieslice((2, 2, 27, 26), 180, 360, fill=(255, 188, 199, 255))
    for x in (7, 12, 17, 22):
        d.line((15, 14, x, 4), fill=(255, 236, 225, 255), width=1)
    return decorate(img)


def decor_crystal() -> Image.Image:
    img = new_image(28, 46)
    d = ImageDraw.Draw(img)
    d.polygon([(14, 1), (25, 17), (20, 43), (8, 43), (3, 17)], fill=(136, 211, 255, 255))
    d.polygon([(14, 1), (25, 17), (14, 29), (3, 17)], fill=(206, 246, 255, 255))
    d.polygon([(14, 29), (20, 43), (8, 43)], fill=(98, 167, 227, 255))
    return decorate(img)


def decor_planet() -> Image.Image:
    img = new_image(42, 34)
    d = ImageDraw.Draw(img)
    d.ellipse((6, 2, 34, 30), fill=(255, 155, 195, 255))
    d.ellipse((11, 7, 22, 15), fill=(255, 214, 222, 255))
    d.arc((1, 11, 39, 25), 0, 360, fill=(177, 139, 255, 255), width=3)
    return decorate(img)


def decor_alien_flower() -> Image.Image:
    img = new_image(30, 36)
    d = ImageDraw.Draw(img)
    d.line((15, 34, 15, 16), fill=(115, 222, 176, 255), width=3)
    for i in range(6):
        a = i * math.pi / 3
        x, y = 15 + int(math.cos(a) * 7), 13 + int(math.sin(a) * 7)
        d.ellipse((x - 4, y - 4, x + 4, y + 4), fill=(180, 138, 255, 255))
    d.ellipse((12, 10, 18, 16), fill=(255, 244, 143, 255))
    return decorate(img)


def decor_pine() -> Image.Image:
    img = new_image(36, 56)
    d = ImageDraw.Draw(img)
    d.rectangle((16, 40, 20, 52), fill=(154, 109, 80, 255))
    for i, (y, w) in enumerate([(6, 11), (18, 15), (30, 18)]):
        d.polygon([(18, y), (18 - w, y + 18), (18 + w, y + 18)],
                  fill=[(73, 177, 143, 255), (88, 200, 159, 255), (104, 220, 170, 255)][i])
    d.polygon([(2, 49), (34, 49), (30, 53), (6, 53)], fill=(240, 252, 255, 255))
    return decorate(img)


def decor_iceberg() -> Image.Image:
    img = new_image(36, 30)
    d = ImageDraw.Draw(img)
    d.polygon([(3, 27), (10, 10), (18, 4), (28, 12), (34, 27)], fill=(164, 230, 249, 255))
    d.polygon([(10, 26), (15, 12), (21, 18), (27, 9), (30, 26)], fill=(231, 253, 255, 255))
    d.line((12, 24, 24, 24), fill=(141, 205, 239, 255), width=1)
    return decorate(img)


def decor_snowman() -> Image.Image:
    img = new_image(30, 48)
    d = ImageDraw.Draw(img)
    d.ellipse((4, 23, 25, 46), fill=(239, 254, 255, 255))
    d.ellipse((8, 10, 22, 27), fill=(255, 255, 255, 255))
    d.ellipse((10, 2, 20, 13), fill=(255, 255, 255, 255))
    d.rectangle((13, 5, 16, 7), fill=OUTLINE)
    d.rectangle((17, 5, 20, 7), fill=OUTLINE)
    d.polygon([(20, 8), (25, 10), (20, 11)], fill=(255, 171, 81, 255))
    d.rectangle((8, 18, 22, 21), fill=(255, 93, 137, 255))
    return decorate(img)


def decor_marshmallow() -> Image.Image:
    img = new_image(34, 46)
    d = ImageDraw.Draw(img)
    d.rectangle((14, 27, 20, 44), fill=(214, 159, 115, 255))
    for x, y, w, h, col in [(3, 14, 28, 18, (255, 248, 231, 255)),
                            (6, 7, 22, 16, (255, 255, 255, 255))]:
        d.rounded_rectangle((x, y, x + w, y + h), radius=7, fill=col)
    d.rounded_rectangle((7, 9, 27, 17), radius=6, fill=(255, 214, 228, 255))
    return decorate(img)


def decor_mushroom() -> Image.Image:
    img = new_image(32, 38)
    d = ImageDraw.Draw(img)
    d.rectangle((13, 18, 19, 35), fill=(255, 233, 194, 255))
    d.pieslice((1, 2, 31, 26), 180, 360, fill=(255, 112, 133, 255))
    for x, y in [(9, 11), (18, 8), (23, 14)]:
        d.ellipse((x, y, x + 4, y + 3), fill=(255, 247, 218, 255))
    return decorate(img)


def decor_campfire() -> Image.Image:
    img = new_image(32, 36)
    d = ImageDraw.Draw(img)
    d.line((3, 32, 28, 27), fill=(157, 105, 78, 255), width=4)
    d.line((5, 27, 27, 32), fill=(191, 131, 89, 255), width=4)
    d.polygon([(16, 5), (25, 18), (22, 28), (16, 31), (10, 27), (8, 18)],
              fill=(255, 133, 76, 255))
    d.polygon([(16, 12), (21, 20), (18, 26), (13, 23), (12, 18)],
              fill=(255, 224, 107, 255))
    return decorate(img)


def decor_aurora_lamp() -> Image.Image:
    img = new_image(32, 50)
    d = ImageDraw.Draw(img)
    d.rectangle((14, 25, 19, 47), fill=(72, 82, 126, 255))
    d.rounded_rectangle((4, 2, 29, 28), radius=7, fill=(49, 61, 103, 255))
    d.rectangle((7, 5, 26, 25), fill=(91, 228, 188, 255))
    d.rectangle((9, 7, 24, 12), fill=(193, 160, 255, 255))
    d.rectangle((11, 18, 18, 23), fill=(255, 240, 154, 255))
    return decorate(img)


def decor_lantern() -> Image.Image:
    img = new_image(28, 46)
    d = ImageDraw.Draw(img)
    d.rectangle((12, 28, 16, 44), fill=(83, 78, 132, 255))
    d.rounded_rectangle((4, 8, 24, 29), radius=5, fill=(255, 218, 111, 255))
    d.rectangle((8, 12, 20, 24), fill=(255, 248, 196, 255))
    d.rectangle((11, 2, 17, 8), fill=(96, 78, 139, 255))
    return decorate(img)


DECOR_FUNCS = [
    [decor_tree, decor_flower, decor_bush],
    [decor_cane, decor_lollipop, decor_gumdrop],
    [decor_cactus, decor_rock, decor_desert_flower],
    [decor_neon, decor_planter, decor_flowerbox],
    [decor_rainbow_tree, decor_flower, decor_flowerbox],
    [decor_palm, decor_umbrella, decor_shell],
    [decor_crystal, decor_planet, decor_alien_flower],
    [decor_pine, decor_iceberg, decor_snowman],
    [decor_marshmallow, decor_mushroom, decor_campfire],
    [decor_aurora_lamp, decor_crystal, decor_lantern],
]


def generate_decorations() -> None:
    for wi, funcs in enumerate(DECOR_FUNCS, start=1):
        for di, fn in enumerate(funcs):
            save(fn(), f"decor_{wi}_{di}")


def gradient(w: int, h: int, top, bottom) -> Image.Image:
    img = new_image(w, h)
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / max(1, h - 1)
        col = tuple(int(top[i] * (1 - t) + bottom[i] * t) for i in range(3)) + (255,)
        d.line((0, y, w, y), fill=col)
    return img


def draw_cloud(d, x, y, scale, color=(255, 255, 255, 210)):
    d.ellipse((x, y + 6 * scale, x + 28 * scale, y + 20 * scale), fill=color)
    d.ellipse((x + 14 * scale, y, x + 40 * scale, y + 20 * scale), fill=color)
    d.ellipse((x + 34 * scale, y + 7 * scale, x + 54 * scale, y + 20 * scale), fill=color)


def generate_backgrounds() -> None:
    # Menu: a cheerful sky, rolling hills, and a ribbon of road.
    w, h = 640, 360
    img = gradient(w, h, (132, 213, 255), (255, 217, 196))
    d = ImageDraw.Draw(img)
    d.ellipse((486, 18, 566, 98), fill=(255, 239, 138, 255))
    d.ellipse((500, 32, 552, 84), fill=(255, 251, 197, 255))
    cloud_layer = new_image(w, h)
    cd = ImageDraw.Draw(cloud_layer)
    for x, y, s in [(38, 44, 2), (190, 20, 1), (310, 53, 1), (560, 45, 1)]:
        draw_cloud(cd, x, y, s)
    img.alpha_composite(cloud_layer)
    d.polygon([(0, 214), (120, 120), (242, 206), (348, 120), (478, 206), (590, 140), (640, 175),
               (640, 360), (0, 360)], fill=(144, 225, 143, 255))
    d.polygon([(0, 244), (130, 185), (280, 242), (410, 177), (560, 238), (640, 204),
               (640, 360), (0, 360)], fill=(89, 199, 126, 255))
    d.polygon([(0, 292), (120, 252), (270, 292), (400, 250), (540, 292), (640, 267),
               (640, 360), (0, 360)], fill=(64, 169, 111, 255))
    # A playful road at the bottom.
    d.polygon([(250, 360), (390, 360), (346, 286), (294, 286)], fill=(91, 84, 125, 255))
    d.polygon([(275, 360), (365, 360), (333, 292), (307, 292)], fill=(255, 182, 117, 255))
    for y in range(302, 360, 20):
        d.rectangle((318, y, 323, y + 9), fill=(255, 245, 191, 255))
    for x, col in [(226, (255, 114, 161, 255)), (198, (255, 226, 99, 255)),
                   (408, (161, 138, 255, 255)), (438, (101, 211, 196, 255))]:
        d.ellipse((x, 300, x + 8, 308), fill=col)
    confetti_layer = new_image(w, h)
    fd = ImageDraw.Draw(confetti_layer)
    for i in range(44):
        rng = random.Random(i + 4)
        x, y = rng.randint(0, 639), rng.randint(0, 300)
        col = rng.choice([(255, 255, 255, 170), (255, 223, 116, 210),
                          (255, 151, 191, 190), (157, 232, 200, 180)])
        fd.rectangle((x, y, x + rng.choice([2, 3, 4]), y + 2), fill=col)
    img.alpha_composite(confetti_layer)
    img.save(ART_DIR / "bg_menu.png", "PNG")

    # Interior screens: a soft cream backdrop with confetti and pastel blobs.
    img = gradient(w, h, (255, 247, 222), (255, 225, 234))
    overlay = new_image(w, h)
    od = ImageDraw.Draw(overlay)
    for (x, y, r, col) in [(60, 50, 110, (255, 239, 166, 90)),
                           (580, 80, 128, (190, 238, 255, 90)),
                           (100, 330, 120, (255, 194, 219, 80)),
                           (540, 320, 95, (201, 255, 220, 85))]:
        od.ellipse((x - r, y - r, x + r, y + r), fill=col)
    rng = random.Random(112)
    confetti = [(255, 139, 173, 180), (255, 215, 103, 180), (127, 220, 185, 180),
                (145, 183, 255, 180), (180, 150, 255, 180)]
    for _ in range(65):
        x, y = rng.randint(0, w - 4), rng.randint(0, h - 4)
        c = rng.choice(confetti)
        od.rectangle((x, y, x + rng.choice([2, 3, 5]), y + 2), fill=c)
    for y in range(0, h, 18):
        od.line((0, y, w, y), fill=(255, 255, 255, 25), width=1)
    img.alpha_composite(overlay)
    img.save(ART_DIR / "bg_screen.png", "PNG")

    # A subtle world-preview strip for the briefing screen.
    for wi, (base, dark, light, style) in enumerate(WORLD_STYLES, start=1):
        img = new_image(w, 120)
        d = ImageDraw.Draw(img)
        d.rectangle((0, 0, w, 120), fill=base)
        for _ in range(80):
            x, y = random.Random(wi * 42 + _).randint(0, w), random.Random(_ * 3 + wi).randint(0, 120)
            d.point((x, y), fill=light)
        for x in range(0, w, 80):
            d.polygon([(x, 120), (x + 30, 52), (x + 42, 52), (x + 82, 120)], fill=dark)
        img.save(ART_DIR / f"bg_world_{wi}.png", "PNG")


def generate_ui() -> None:
    def panel(name, fill, border, highlight, shadow):
        img = new_image(32, 32)
        d = ImageDraw.Draw(img)
        d.rounded_rectangle((2, 2, 29, 29), radius=7, fill=shadow)
        d.rounded_rectangle((1, 1, 28, 27), radius=7, fill=fill, outline=border, width=2)
        d.line((5, 4, 24, 4), fill=highlight, width=2)
        d.line((5, 5, 9, 5), fill=highlight, width=1)
        img.save(ART_DIR / f"{name}.png", "PNG")

    panel("ui_panel", (255, 250, 229, 255), OUTLINE, (255, 255, 249, 255), (91, 62, 94, 200))
    panel("ui_panel_dark", (70, 54, 91, 245), (36, 24, 47, 255), (114, 89, 139, 255), (26, 18, 38, 220))
    panel("ui_panel_cream", (255, 239, 202, 255), OUTLINE, (255, 252, 234, 255), (133, 83, 92, 190))
    for name, fill, border, highlight, shadow in [
        ("ui_button_pink", (255, 138, 175, 255), OUTLINE, (255, 204, 221, 255), (166, 78, 119, 200)),
        ("ui_button_mint", (126, 228, 183, 255), OUTLINE, (209, 255, 231, 255), (62, 153, 133, 200)),
        ("ui_button_yellow", (255, 211, 92, 255), OUTLINE, (255, 243, 168, 255), (166, 122, 59, 200)),
        ("ui_button_sky", (130, 202, 255, 255), OUTLINE, (207, 242, 255, 255), (65, 120, 177, 200)),
        ("ui_button_lavender", (203, 164, 255, 255), OUTLINE, (237, 220, 255, 255), (112, 82, 165, 200)),
        ("ui_button_rose", (255, 113, 121, 255), OUTLINE, (255, 194, 182, 255), (168, 70, 86, 200)),
    ]:
        panel(name, fill, border, highlight, shadow)
    panel("ui_button_disabled", (210, 203, 209, 255), OUTLINE_SOFT, (235, 231, 235, 255), (128, 119, 135, 180))

    # slider and bars
    img = new_image(32, 10)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((0, 2, 31, 8), radius=3, fill=(77, 59, 99, 255), outline=OUTLINE, width=1)
    img.save(ART_DIR / "ui_slider_track.png", "PNG")
    img = new_image(18, 18)
    d = ImageDraw.Draw(img)
    d.ellipse((2, 2, 15, 15), fill=(255, 248, 213, 255), outline=OUTLINE, width=2)
    d.ellipse((6, 5, 9, 8), fill=(255, 255, 255, 255))
    img.save(ART_DIR / "ui_slider_knob.png", "PNG")
    img = new_image(32, 10)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((0, 2, 31, 8), radius=3, fill=(255, 141, 177, 255), outline=OUTLINE, width=1)
    img.save(ART_DIR / "ui_bar_pink.png", "PNG")
    img = new_image(32, 10)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((0, 2, 31, 8), radius=3, fill=(112, 219, 176, 255), outline=OUTLINE, width=1)
    img.save(ART_DIR / "ui_bar_mint.png", "PNG")

    # Small icons.
    def icon_lock():
        img = new_image(18, 20)
        d = ImageDraw.Draw(img)
        d.arc((3, 1, 14, 13), 180, 360, fill=PAL["grey"], width=3)
        d.rounded_rectangle((2, 8, 15, 19), radius=3, fill=PAL["yellow"], outline=OUTLINE, width=1)
        d.rectangle((8, 12, 10, 15), fill=OUTLINE)
        img.save(ART_DIR / "icon_lock.png", "PNG")

    icon_lock()

    def icon_play():
        img = new_image(20, 20)
        d = ImageDraw.Draw(img)
        d.polygon([(5, 3), (17, 10), (5, 17)], fill=(255, 248, 218, 255))
        img.save(ART_DIR / "icon_play.png", "PNG")

    icon_play()

    def icon_pause():
        img = new_image(20, 20)
        d = ImageDraw.Draw(img)
        d.rectangle((4, 3, 8, 17), fill=(255, 248, 218, 255))
        d.rectangle((12, 3, 16, 17), fill=(255, 248, 218, 255))
        img.save(ART_DIR / "icon_pause.png", "PNG")

    icon_pause()

    def icon_arrow(left=True):
        img = new_image(18, 18)
        d = ImageDraw.Draw(img)
        if left:
            d.polygon([(4, 9), (13, 3), (13, 15)], fill=(255, 248, 232, 255))
        else:
            d.polygon([(14, 9), (5, 3), (5, 15)], fill=(255, 248, 232, 255))
        img.save(ART_DIR / ("icon_arrow_left.png" if left else "icon_arrow_right.png"), "PNG")

    icon_arrow(True)
    icon_arrow(False)

    def icon_back():
        img = new_image(18, 18)
        d = ImageDraw.Draw(img)
        d.polygon([(2, 9), (11, 2), (11, 7), (16, 7), (16, 11), (11, 11), (11, 16)],
                  fill=(255, 248, 232, 255))
        img.save(ART_DIR / "icon_back.png", "PNG")

    icon_back()

    def icon_check(cross=False):
        img = new_image(18, 18)
        d = ImageDraw.Draw(img)
        if cross:
            d.line((4, 4, 14, 14), fill=(255, 111, 127, 255), width=4)
            d.line((14, 4, 4, 14), fill=(255, 111, 127, 255), width=4)
        else:
            d.line((3, 9, 7, 14), fill=(116, 220, 168, 255), width=4)
            d.line((7, 14, 15, 4), fill=(116, 220, 168, 255), width=4)
        img.save(ART_DIR / ("icon_cross.png" if cross else "icon_check.png"), "PNG")

    icon_check(False)
    icon_check(True)

    def icon_gear():
        img = new_image(20, 20)
        d = ImageDraw.Draw(img)
        for i in range(8):
            a = i * math.pi / 4
            x, y = 10 + math.cos(a) * 7, 10 + math.sin(a) * 7
            d.rectangle((x - 2, y - 2, x + 2, y + 2), fill=PAL["mint"])
        d.ellipse((3, 3, 16, 16), fill=PAL["mint"])
        d.ellipse((7, 7, 12, 12), fill=OUTLINE)
        img.save(ART_DIR / "icon_gear.png", "PNG")

    icon_gear()

    def icon_trophy():
        img = new_image(20, 22)
        d = ImageDraw.Draw(img)
        d.polygon([(4, 2), (16, 2), (15, 10), (12, 15), (8, 15), (5, 10)],
                  fill=PAL["yellow"])
        d.rectangle((8, 15, 12, 19), fill=PAL["sun"])
        d.rectangle((5, 19, 15, 21), fill=PAL["orange"])
        img.save(ART_DIR / "icon_trophy.png", "PNG")

    icon_trophy()

    def icon_boost():
        img = new_image(18, 18)
        d = ImageDraw.Draw(img)
        d.polygon([(9, 1), (3, 10), (8, 10), (5, 17), (15, 7), (10, 7)],
                  fill=(255, 226, 94, 255))
        img.save(ART_DIR / "icon_boost.png", "PNG")

    icon_boost()

    def icon_target():
        img = new_image(18, 14)
        d = ImageDraw.Draw(img)
        d.polygon([(9, 13), (2, 3), (16, 3)], fill=(255, 251, 224, 255))
        d.line((9, 6, 9, 10), fill=(255, 136, 174, 255), width=2)
        img.save(ART_DIR / "icon_target.png", "PNG")

    icon_target()


# ---------------------------------------------------------------------------
# Font and logo
# ---------------------------------------------------------------------------

def generate_font() -> None:
    font = ImageFont.truetype(FONT_PATH, FONT_SIZE)
    try:
        font.set_variation_by_axes([])
    except Exception:
        pass
    for code in range(FIRST_CHAR, LAST_CHAR + 1):
        ch = chr(code)
        img = new_image(FONT_CELL_W, FONT_CELL_H)
        d = ImageDraw.Draw(img)
        if ch != " ":
            # Draw at a fixed baseline with a thresholded 1-bit result.
            d.text((1, 15), ch, font=font, fill=(255, 255, 255, 255), anchor="ls")
            px = img.load()
            for y in range(FONT_CELL_H):
                for x in range(FONT_CELL_W):
                    r, g, b, a = px[x, y]
                    if a < 90:
                        px[x, y] = (0, 0, 0, 0)
                    else:
                        px[x, y] = (255, 255, 255, 255)
        img.save(ART_DIR / f"glyph_{code:03d}.png", "PNG")
    meta = {
        "cellW": FONT_CELL_W,
        "cellH": FONT_CELL_H,
        "advance": FONT_ADVANCE,
        "lineHeight": FONT_LINE_HEIGHT,
        "firstChar": FIRST_CHAR,
        "lastChar": LAST_CHAR,
        "font": "Monaco 15 rasterized",
    }
    (DATA_DIR / "font.json").write_text(json.dumps(meta, indent=2) + "\n")
    # Quick readable preview.
    preview = Image.new("RGBA", (760, 170), (48, 36, 62, 255))
    pd = ImageDraw.Draw(preview)
    sample = "CAR SPEEDTRACK 100 LEVELS  0123456789"
    x = 14
    for ch in sample:
        code = ord(ch)
        if FIRST_CHAR <= code <= LAST_CHAR:
            glyph = Image.open(ART_DIR / f"glyph_{code:03d}.png")
            preview.alpha_composite(glyph, (x, 26))
        x += FONT_ADVANCE
    x = 14
    for ch in "Sunny Meadows · 3 STARS · 12350":
        code = ord(ch)
        if FIRST_CHAR <= code <= LAST_CHAR:
            glyph = Image.open(ART_DIR / f"glyph_{code:03d}.png")
            preview.alpha_composite(glyph, (x, 66))
        x += FONT_ADVANCE
    preview.save(BUILD_DIR / "font_preview.png", "PNG")


def text_mask(text: str, font: ImageFont.FreeTypeFont, pad=6):
    bbox = font.getbbox(text)
    w, h = bbox[2] - bbox[0] + pad * 2, bbox[3] - bbox[1] + pad * 2
    img = new_image(w, h)
    d = ImageDraw.Draw(img)
    d.text((pad - bbox[0], pad - bbox[1]), text, font=font, fill=(255, 255, 255, 255))
    alpha = img.getchannel("A")
    # Threshold to keep the logo pixel-crisp.
    alpha = alpha.point(lambda p: 255 if p > 80 else 0)
    return alpha


def colored_mask(mask, colors):
    w, h = mask.size
    grad = new_image(w, h)
    d = ImageDraw.Draw(grad)
    for y in range(h):
        t = y / max(1, h - 1)
        idx = t * (len(colors) - 1)
        i0 = min(len(colors) - 1, int(idx))
        i1 = min(len(colors) - 1, i0 + 1)
        f = idx - i0
        col = tuple(int(colors[i0][i] * (1 - f) + colors[i1][i] * f) for i in range(3)) + (255,)
        d.line((0, y, w, y), fill=col)
    grad.putalpha(mask)
    return grad


def generate_logo() -> None:
    try:
        title_font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Andale Mono.ttf", 46)
    except Exception:
        title_font = ImageFont.truetype(FONT_PATH, 46)
    lines = [("CAR", title_font, (255, 228, 111), (255, 141, 175)),
             ("SPEEDTRACK", title_font, (142, 232, 181), (144, 188, 255))]
    masks = [text_mask(t, f) for t, f, _, _ in lines]
    w = max(m.width for m in masks) + 32
    h = sum(m.height for m in masks) + 34
    img = new_image(w, h)
    d = ImageDraw.Draw(img)
    # A clean 2px outline plus a short drop shadow keeps the wordmark legible
    # against the busy meadow background.
    y = 12
    for (text, f, c0, c1), mask in zip(lines, masks):
        colored = colored_mask(mask, [c0, c1])
        outline_mask = mask.filter(ImageFilter.MaxFilter(5))
        outline = Image.new("RGBA", colored.size, OUTLINE)
        outline.putalpha(outline_mask)
        x = 16 + (w - 32 - mask.width) // 2
        img.alpha_composite(outline, (x, y + 4))
        img.alpha_composite(outline, (x, y))
        img.alpha_composite(colored, (x, y))
        y += mask.height + 4
    # little stars
    for x, y in [(8, 8), (w - 20, 42), (18, h - 22)]:
        d.polygon(star_polygon(x, y, 5, 2), fill=(255, 247, 196, 255))
    img.save(ART_DIR / "logo_title.png", "PNG")


def contact_sheet() -> None:
    scale = 3
    items = []
    items.extend([f"car_{cid}_0" for cid, *_ in CAR_SPECS])
    items.extend(["pickup_coin_0", "pickup_gem", "pickup_heart", "pickup_shield",
                  "pickup_magnet", "pickup_star", "hazard_cone", "hazard_spike",
                  "hazard_jelly", "hazard_beachball_0", "hazard_snowball_0", "hazard_asteroid_0"])
    items.extend([f"decor_1_{i}" for i in range(3)] + [f"decor_4_{i}" for i in range(3)] +
                 [f"decor_8_{i}" for i in range(3)])
    cell_w, cell_h = 150, 170
    cols = 6
    rows = (len(items) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cell_w, rows * cell_h), (43, 33, 58, 255))
    for i, name in enumerate(items):
        path = ART_DIR / f"{name}.png"
        if not path.exists():
            continue
        im = Image.open(path).convert("RGBA")
        im = im.resize((im.width * scale, im.height * scale), Image.Resampling.NEAREST)
        x, y = (i % cols) * cell_w, (i // cols) * cell_h
        sheet.alpha_composite(im, (x + (cell_w - im.width) // 2, y + (cell_h - im.height) // 2))
    sheet.save(BUILD_DIR / "art_contact_sheet.png", "PNG")


def category_for(name: str) -> str:
    if name.startswith("car_"):
        return "car"
    if name.startswith("traffic_"):
        return "traffic"
    if name.startswith("pickup_"):
        return "pickup"
    if name.startswith("hazard_"):
        return "hazard"
    if name.startswith("ground_"):
        return "ground"
    if name.startswith("decor_"):
        return "decor"
    if name.startswith("bg_"):
        return "background"
    if name.startswith("ui_"):
        return "ui"
    if name.startswith("icon_"):
        return "icon"
    if name.startswith("glyph_"):
        return "glyph"
    if name.startswith("logo_"):
        return "logo"
    return "misc"


def write_manifest() -> None:
    entries = []
    for path in sorted(ART_DIR.glob("*.png")):
        with Image.open(path) as image:
            width, height = image.size
        entries.append({
            "name": path.stem,
            "file": path.name,
            "width": width,
            "height": height,
            "category": category_for(path.stem),
        })
    manifest = {
        "version": 1,
        "nearestFiltering": True,
        "assets": entries,
    }
    (ART_DIR / "art_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")


def main() -> None:
    ensure_dirs()
    generate_cars()
    generate_pickups()
    generate_hazards()
    generate_ground()
    generate_decorations()
    generate_backgrounds()
    generate_ui()
    generate_font()
    generate_logo()
    contact_sheet()
    write_manifest()
    count = len(list(ART_DIR.glob("*.png")))
    print(f"Generated {count} art files in {ART_DIR}")
    print(f"Contact sheet: {BUILD_DIR / 'art_contact_sheet.png'}")
    print(f"Font preview: {BUILD_DIR / 'font_preview.png'}")


if __name__ == "__main__":
    main()

