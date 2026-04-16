#!/usr/bin/env python3
"""Generate DMG background image for Island app."""
from PIL import Image, ImageDraw, ImageFont
import math

W, H = 660, 400

img = Image.new("RGB", (W, H))
draw = ImageDraw.Draw(img)

# Dark gradient background (deep navy to dark purple)
for y in range(H):
    t = y / H
    r = int(15 + t * 25)
    g = int(15 + t * 10)
    b = int(40 + t * 30)
    draw.line([(0, y), (W, y)], fill=(r, g, b))

# Subtle radial glow in center
for radius in range(200, 0, -1):
    alpha = int(15 * (1 - radius / 200))
    cx, cy = W // 2, H // 2 - 20
    draw.ellipse(
        [cx - radius, cy - radius, cx + radius, cy + radius],
        fill=(80 + alpha, 60 + alpha, 120 + alpha),
    )

# Re-draw gradient with transparency effect (overlay)
overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
odraw = ImageDraw.Draw(overlay)

# Arrow from bottom-left area to top-right area
# App icon will be at ~130, 180 and Applications at ~530, 100
arrow_start = (220, 240)
arrow_end = (440, 140)

# Draw arrow shaft
for offset in range(-2, 3):
    odraw.line(
        [(arrow_start[0], arrow_start[1] + offset), (arrow_end[0], arrow_end[1] + offset)],
        fill=(255, 255, 255, 50),
        width=1,
    )

# Arrowhead
angle = math.atan2(arrow_end[1] - arrow_start[1], arrow_end[0] - arrow_start[0])
head_len = 25
for i in range(3):
    a1 = angle + math.pi + 0.4
    a2 = angle + math.pi - 0.4
    x1 = arrow_end[0] + head_len * math.cos(a1)
    y1 = arrow_end[1] + head_len * math.sin(a1)
    x2 = arrow_end[0] + head_len * math.cos(a2)
    y2 = arrow_end[1] + head_len * math.sin(a2)
    odraw.polygon(
        [arrow_end, (int(x1), int(y1)), (int(x2), int(y2))],
        fill=(255, 255, 255, 60),
    )

img = img.convert("RGBA")
img = Image.alpha_composite(img, overlay)

# Add text
draw = ImageDraw.Draw(img)

try:
    font_bold = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 18)
    font_small = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 14)
except:
    font_bold = ImageFont.load_default()
    font_small = ImageFont.load_default()

# Instruction text at bottom
text1 = "Drag Island to Applications to install"
bbox = draw.textbbox((0, 0), text1, font=font_bold)
tw = bbox[2] - bbox[0]
draw.text(((W - tw) // 2, 330), text1, fill=(255, 255, 255, 180), font=font_bold)

# Subtle dots pattern
for x in range(0, W, 30):
    for y in range(0, H, 30):
        draw.ellipse([x, y, x + 1, y + 1], fill=(255, 255, 255, 15))

img = img.convert("RGB")
img.save("scripts/dmg_background.png", "PNG")
img2x = img.resize((W * 2, H * 2), Image.LANCZOS)
img2x.save("scripts/dmg_background@2x.png", "PNG")
print("Generated dmg_background.png and dmg_background@2x.png")
