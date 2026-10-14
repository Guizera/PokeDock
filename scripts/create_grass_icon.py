"""Draw a grass patch icon for the macOS app and its Dock tile."""

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "pokeTab" / "Assets.xcassets" / "AppIcon.appiconset"
SIZE = 1024


def quadratic(start, control, end, steps=20):
    return [
        (
            round((1 - t) ** 2 * start[0] + 2 * (1 - t) * t * control[0] + t**2 * end[0]),
            round((1 - t) ** 2 * start[1] + 2 * (1 - t) * t * control[1] + t**2 * end[1]),
        )
        for t in (index / steps for index in range(steps + 1))
    ]


def blade(draw, base, tip, width, color, bend):
    left = (base[0] - width, base[1])
    right = (base[0] + width, base[1])
    first = quadratic(left, (base[0] + bend - width * 0.6, tip[1] + 100), tip)
    second = quadratic(tip, (base[0] + bend + width * 0.6, tip[1] + 140), right)
    draw.polygon(first + second, fill=color)


def pokeball(canvas):
    """A bright, readable focal point that still works at Dock-icon sizes."""
    shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse((319, 432, 745, 858), fill=(15, 67, 53, 140))
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(32)))

    ball = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(ball)
    outer = (317, 354, 707, 744)
    draw.ellipse(outer, fill=(28, 49, 49, 255))
    draw.ellipse((334, 371, 690, 727), fill=(255, 250, 224, 255))

    top_mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(top_mask).ellipse((334, 371, 690, 727), fill=255)
    ImageDraw.Draw(top_mask).rectangle((0, 549, SIZE, SIZE), fill=0)
    top = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ImageDraw.Draw(top).rectangle((334, 371, 690, 548), fill=(227, 67, 65, 255))
    ball.paste(top, (0, 0), top_mask)
    draw = ImageDraw.Draw(ball)
    draw.ellipse((334, 371, 690, 727), outline=(31, 55, 53, 255), width=17)
    draw.rectangle((338, 528, 686, 558), fill=(28, 49, 49, 255))
    draw.ellipse((456, 486, 568, 598), fill=(28, 49, 49, 255))
    draw.ellipse((470, 500, 554, 584), fill=(255, 248, 218, 255))
    draw.ellipse((483, 513, 541, 571), fill=(190, 233, 213, 255))
    draw.arc((362, 398, 655, 688), 195, 264, fill=(255, 185, 151, 215), width=20)
    draw.arc((362, 398, 655, 688), 36, 80, fill=(255, 255, 255, 130), width=9)
    canvas.alpha_composite(ball)


def create_icon():
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    gradient = Image.new("RGBA", (SIZE, SIZE))
    pixels = gradient.load()
    for y in range(SIZE):
        ratio = y / (SIZE - 1)
        color = (
            round(194 - 105 * ratio),
            round(240 - 62 * ratio),
            round(220 - 90 * ratio),
            255,
        )
        for x in range(SIZE):
            pixels[x, y] = color
    mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).rounded_rectangle((12, 12, 1011, 1011), radius=225, fill=255)
    canvas.paste(gradient, (0, 0), mask)

    glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse((264, 150, 760, 646), fill=(255, 249, 190, 115))
    glow = glow.filter(ImageFilter.GaussianBlur(34))
    canvas.alpha_composite(glow)

    draw = ImageDraw.Draw(canvas)
    draw.ellipse((-100, 660, 520, 1080), fill=(63, 139, 104, 255))
    draw.ellipse((380, 635, 1120, 1090), fill=(50, 126, 91, 255))
    draw.ellipse((150, 715, 900, 1100), fill=(35, 112, 78, 255))

    back_blades = [
        ((235, 795), (135, 565), 38, (39, 129, 84, 255), -45),
        ((335, 811), (300, 445), 51, (57, 154, 91, 255), -20),
        ((440, 830), (412, 535), 45, (29, 122, 76, 255), -10),
        ((570, 832), (618, 433), 53, (54, 149, 79, 255), 30),
        ((675, 822), (746, 540), 46, (30, 117, 74, 255), 42),
        ((784, 794), (860, 560), 37, (42, 131, 75, 255), 48),
    ]
    for base, tip, width, color, bend in back_blades:
        blade(draw, base, tip, width, color, bend)

    pokeball(canvas)
    draw = ImageDraw.Draw(canvas)

    front_blades = [
        ((245, 896), (171, 582), 51, (87, 191, 82, 255), -46),
        ((346, 910), (308, 678), 56, (110, 207, 91, 255), -22),
        ((429, 928), (405, 735), 42, (85, 188, 76, 255), -8),
        ((576, 928), (612, 740), 43, (118, 214, 91, 255), 10),
        ((666, 910), (713, 654), 56, (89, 192, 76, 255), 28),
        ((781, 890), (856, 574), 51, (76, 181, 74, 255), 49),
    ]
    for base, tip, width, color, bend in front_blades:
        blade(draw, base, tip, width, color, bend)

    draw.ellipse((200, 832, 816, 1040), fill=(39, 141, 75, 255))
    draw.arc((230, 840, 790, 1020), start=192, end=336, fill=(140, 224, 125, 255), width=20)
    draw.ellipse((723, 340, 763, 380), fill=(255, 253, 212, 220))
    draw.ellipse((757, 401, 774, 418), fill=(255, 253, 212, 160))

    # Retain the rounded outer silhouette after drawing the grass.
    final = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    final.paste(canvas, (0, 0), mask)
    return final


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    icon = create_icon()
    for size in (16, 32, 64, 128, 256, 512, 1024):
        icon.resize((size, size), Image.Resampling.LANCZOS).save(
            OUTPUT / f"grass-{size}.png", optimize=True
        )
    images = []
    for size in (16, 32, 128, 256, 512):
        for scale in (1, 2):
            images.append(
                {
                    "filename": f"grass-{size * scale}.png",
                    "idiom": "mac",
                    "scale": f"{scale}x",
                    "size": f"{size}x{size}",
                }
            )
    (OUTPUT / "Contents.json").write_text(
        json.dumps({"images": images, "info": {"author": "xcode", "version": 1}}, indent=2)
        + "\n"
    )
    print(f"Created grass app icon in {OUTPUT}")


if __name__ == "__main__":
    main()
