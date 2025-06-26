#!/usr/bin/env python3
"""Build the macOS app icon from the generated logo and car art."""
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
ART = ROOT / "CarSpeedtrack" / "Resources" / "Art"
ICONSET = ROOT / "CarSpeedtrack" / "Resources" / "Assets.xcassets" / "AppIcon.appiconset"
SIZE = 1024


def gradient(w: int, h: int, top, bottom) -> Image.Image:
    img = Image.new("RGBA", (w, h))
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / max(1, h - 1)
        color = tuple(int(top[i] * (1 - t) + bottom[i] * t) for i in range(3)) + (255,)
        d.line((0, y, w, y), fill=color)
    return img


def star(draw: ImageDraw.ImageDraw, x: int, y: int, r: int, color) -> None:
    points = []
    for i in range(10):
        angle = -1.5708 + i * 3.14159 / 5
        radius = r if i % 2 == 0 else r * 0.44
        points.append((x + radius * __import__("math").cos(angle),
                       y + radius * __import__("math").sin(angle)))
    draw.polygon(points, fill=color)


def main() -> None:
    ICONSET.mkdir(parents=True, exist_ok=True)
    base = gradient(SIZE, SIZE, (127, 214, 255), (255, 220, 232))

    mask = Image.new("L", (SIZE, SIZE), 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle((36, 36, SIZE - 36, SIZE - 36), radius=210, fill=255)
    base.putalpha(mask)

    d = ImageDraw.Draw(base)
    # Sun and clouds.
    d.ellipse((700, 92, 920, 312), fill=(255, 227, 100, 255))
    d.ellipse((742, 134, 878, 270), fill=(255, 252, 196, 255))
    for x, y, s in [(90, 160, 1.2), (260, 100, 0.8), (520, 160, 1.0)]:
        for cx, cy, r in [(0, 0, 62), (58, -18, 72), (120, 0, 54), (58, 16, 66)]:
            d.ellipse((x + cx * s - r * s, y + cy * s - r * s,
                       x + cx * s + r * s, y + cy * s + r * s),
                      fill=(255, 255, 255, 235))

    # Rolling hills.
    d.ellipse((-200, 560, 700, 1060), fill=(126, 221, 156, 255))
    d.ellipse((420, 600, 1240, 1120), fill=(102, 209, 146, 255))
    d.ellipse((100, 760, 950, 1180), fill=(151, 233, 170, 255))

    # Cheerful road.
    d.polygon([(360, 1024), (664, 1024), (594, 500), (430, 500)],
              fill=(91, 66, 104, 255))
    d.polygon([(382, 1024), (642, 1024), (580, 520), (444, 520)],
              fill=(255, 197, 122, 255))
    for i in range(5):
        t = i / 4.0
        y = 540 + t * 440
        width = 10 + t * 18
        d.rounded_rectangle((SIZE // 2 - width // 2, y, SIZE // 2 + width // 2, y + 34 + t * 30),
                           radius=8, fill=(255, 247, 213, 255))

    # Car hero.
    car = Image.open(ART / "car_rainbow-rocket_0.png").convert("RGBA")
    car = car.resize((car.width * 5, car.height * 5), Image.Resampling.NEAREST)
    shadow = Image.new("RGBA", car.size, (54, 34, 62, 90))
    shadow.putalpha(car.getchannel("A").point(lambda p: int(p * 0.45)))
    base.alpha_composite(shadow, ((SIZE - car.width) // 2 + 18, 530 + 20))
    base.alpha_composite(car, ((SIZE - car.width) // 2, 530))

    # Confetti + stars.
    for x, y, r in [(170, 410, 34), (850, 330, 26), (760, 122, 20), (130, 700, 22)]:
        star(d, x, y, r, (255, 244, 146, 255))
    confetti = [(255, 139, 173), (255, 215, 103), (127, 220, 185),
                (145, 183, 255), (180, 150, 255)]
    for i in range(34):
        x = 90 + ((i * 137) % 820)
        y = 120 + ((i * 223) % 700)
        if 300 < x < 760 and 460 < y:
            continue
        color = confetti[i % len(confetti)] + (255,)
        d.rectangle((x, y, x + 14, y + 8), fill=color)

    # Title card in the sky, above the hero car.
    title_panel = Image.new("RGBA", (SIZE, 230), (0, 0, 0, 0))
    td = ImageDraw.Draw(title_panel)
    td.rounded_rectangle((104, 18, SIZE - 104, 212), radius=52,
                         fill=(255, 250, 229, 238), outline=(54, 34, 62, 255), width=10)
    logo = Image.open(ART / "logo_title.png").convert("RGBA")
    logo = logo.resize((logo.width * 2, logo.height * 2), Image.Resampling.NEAREST)
    logo.thumbnail((650, 190), Image.Resampling.LANCZOS)
    title_panel.alpha_composite(logo, ((SIZE - logo.width) // 2,
                                       20 + (192 - logo.height) // 2))
    base.alpha_composite(title_panel, (0, 238))

    # Soft vignette on the corners to feel like a real app icon.
    edge = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ed = ImageDraw.Draw(edge)
    ed.rounded_rectangle((36, 36, SIZE - 36, SIZE - 36), radius=210,
                         outline=(54, 34, 62, 90), width=10)
    base.alpha_composite(edge)

    sizes = {
        "icon_16x16.png": 16, "icon_16x16@2x.png": 32,
        "icon_32x32.png": 32, "icon_32x32@2x.png": 64,
        "icon_128x128.png": 128, "icon_128x128@2x.png": 256,
        "icon_256x256.png": 256, "icon_256x256@2x.png": 512,
        "icon_512x512.png": 512, "icon_512x512@2x.png": 1024,
    }
    for name, px in sizes.items():
        image = base.resize((px, px), Image.Resampling.LANCZOS)
        image.save(ICONSET / name, "PNG")
    base.save(ROOT / "build" / "app_icon_preview.png", "PNG")

    images = []
    for name, px in sizes.items():
        scale = 2 if "@2x" in name else 1
        point = px // scale
        images.append({"filename": name, "idiom": "mac",
                       "scale": f"{scale}x", "size": f"{point}x{point}"})
    contents = {"images": images, "info": {"author": "xcode", "version": 1}}
    (ICONSET / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")
    print(f"Wrote {len(sizes)} app icon sizes to {ICONSET}")


if __name__ == "__main__":
    main()
