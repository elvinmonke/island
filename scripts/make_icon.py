#!/usr/bin/env python3
"""Generate Island.icns — a minimalist macOS app icon.

A soft-gradient rounded square (Big Sur style) with a black Dynamic
Island pill centered inside it."""

import os
import subprocess
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
ICONSET = ROOT / "build" / "Island.iconset"
ICNS = ROOT / "App" / "Assets.xcassets" / "AppIcon.appiconset"


def make_icon(size: int) -> Image.Image:
    scale = size / 1024
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))

    # Rounded-square background with a subtle vertical gradient.
    bg = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    top = (245, 245, 247)
    bot = (210, 212, 218)
    grad = Image.new("RGBA", (1, size))
    for y in range(size):
        t = y / (size - 1)
        r = int(top[0] * (1 - t) + bot[0] * t)
        g = int(top[1] * (1 - t) + bot[1] * t)
        b = int(top[2] * (1 - t) + bot[2] * t)
        grad.putpixel((0, y), (r, g, b, 255))
    grad = grad.resize((size, size))

    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, size, size), radius=int(225 * scale), fill=255
    )
    bg.paste(grad, (0, 0), mask)
    img = Image.alpha_composite(img, bg)

    # Inner soft shadow inside the pill area.
    pill_w = int(560 * scale)
    pill_h = int(180 * scale)
    px = (size - pill_w) // 2
    py = (size - pill_h) // 2 + int(20 * scale)
    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle(
        (px, py + int(14 * scale), px + pill_w, py + pill_h + int(14 * scale)),
        radius=pill_h // 2,
        fill=(0, 0, 0, 90),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=int(28 * scale)))
    img = Image.alpha_composite(img, shadow)

    # The black pill itself.
    pill = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    pd = ImageDraw.Draw(pill)
    pd.rounded_rectangle(
        (px, py, px + pill_w, py + pill_h),
        radius=pill_h // 2,
        fill=(10, 10, 12, 255),
    )
    img = Image.alpha_composite(img, pill)

    # Tiny green dot (waveform indicator) to hint at the media UI.
    dot_r = int(24 * scale)
    dx = px + int(44 * scale)
    dy = py + pill_h // 2
    dot_shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(dot_shadow).ellipse(
        (dx - dot_r, dy - dot_r, dx + dot_r, dy + dot_r),
        fill=(52, 199, 89, 255),
    )
    img = Image.alpha_composite(img, dot_shadow)

    return img


def main():
    ICONSET.mkdir(parents=True, exist_ok=True)
    sizes = [
        (16, 1), (16, 2),
        (32, 1), (32, 2),
        (128, 1), (128, 2),
        (256, 1), (256, 2),
        (512, 1), (512, 2),
    ]
    master = make_icon(1024)
    for base, scale in sizes:
        px = base * scale
        img = master.resize((px, px), Image.LANCZOS)
        suffix = "" if scale == 1 else "@2x"
        name = f"icon_{base}x{base}{suffix}.png"
        img.save(ICONSET / name)

    icns_out = ROOT / "App" / "AppIcon.icns"
    subprocess.run(
        ["iconutil", "-c", "icns", str(ICONSET), "-o", str(icns_out)],
        check=True,
    )
    print(f"Wrote {icns_out}")
    preview = ROOT / "build" / "icon_preview.png"
    master.save(preview)
    print(f"Preview: {preview}")


if __name__ == "__main__":
    main()
