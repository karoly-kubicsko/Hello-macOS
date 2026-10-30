#!/usr/bin/env python3
"""Draws the Hello app icon and writes Resources/AppIcon.icns.

The artwork follows Apple's macOS icon grid: a 1024 x 1024 canvas with an
824 x 824 rounded-square ("squircle") body and a soft drop shadow. The palette
is taken from the app's time-of-day themes.

Requirements: Python 3, Pillow, NumPy.  Usage: python3 Icon/make_icon.py
"""

import io
import struct
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
PNG_OUT = ROOT / "Icon" / "AppIcon.png"
ICNS_OUT = ROOT / "Resources" / "AppIcon.icns"

SIZE = 1024           # final canvas
SS = 2                # supersampling factor for smooth edges
BODY = 824            # icon body edge on Apple's 1024 grid
MARGIN = (SIZE - BODY) // 2
HORIZON = 0.64        # horizon height, as a fraction of the body

NIGHT = "#0B1026"
EVENING = "#3B2350"
GLOW = "#F2874B"
SUN = "#F4D35E"
SUN_CORE = "#FFF1B8"
STAR = "#E4E0F5"


def rgb(hex_color):
    hex_color = hex_color.lstrip("#")
    return np.array([int(hex_color[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float64)


def gradient(t, stops):
    """Piecewise-linear colour ramp; t is an array in [0, 1]."""
    positions = [p for p, _ in stops]
    colours = np.stack([rgb(c) for _, c in stops])
    return np.stack([np.interp(t, positions, colours[:, ch]) for ch in range(3)], axis=-1)


def squircle_mask(n, size):
    """Superellipse |x|^5 + |y|^5 <= 1, a close match to Apple's continuous-corner shape."""
    c = (np.arange(n) + 0.5) / n * 2 - 1
    x, y = np.meshgrid(c, c)
    inside = (np.abs(x) ** 5 + np.abs(y) ** 5) <= 1
    return Image.fromarray((inside * 255).astype(np.uint8)).resize((size, size), Image.LANCZOS)


def draw_body():
    n = BODY * SS
    v, u = np.mgrid[0:n, 0:n] / n

    # Sky: night -> evening purple -> orange glow at the horizon; sea mirrors it darker.
    sky = gradient(v / HORIZON, [(0.0, NIGHT), (0.62, EVENING), (1.0, GLOW)])
    sea = gradient((v - HORIZON) / (1 - HORIZON), [(0.0, "#5A2F5E"), (0.35, EVENING), (1.0, NIGHT)])
    img = np.where((v < HORIZON)[..., None], sky, sea)

    # Warm halo around the sun (sky only).
    cx, cy = 0.5, HORIZON - 0.015
    d = np.hypot(u - cx, v - cy)
    halo = np.clip(1 - d / 0.46, 0, 1) ** 2.2 * 0.6 * (v < HORIZON)
    img = img * (1 - halo[..., None]) + rgb(SUN) * halo[..., None]

    # Sun disk, slightly risen above the horizon, lighter at the top.
    r = 0.2
    disk = (d <= r) & (v < HORIZON)
    sun = gradient(np.clip((v - (cy - r)) / r, 0, 1), [(0.0, SUN_CORE), (1.0, SUN)])
    img = np.where(disk[..., None], sun, img)

    body = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).convert("RGBA")

    # Sun reflection on the water and a few stars, drawn as vector shapes.
    overlay = Image.new("RGBA", body.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    bar_h = 0.019 * n
    for k, (width, alpha) in enumerate([(0.36, 230), (0.27, 200), (0.19, 165), (0.12, 130), (0.06, 95)]):
        y = (HORIZON + 0.04 + k * 0.052) * n
        x0, x1 = (0.5 - width / 2) * n, (0.5 + width / 2) * n
        draw.rounded_rectangle([x0, y, x1, y + bar_h], radius=bar_h / 2, fill=(*rgb(SUN).astype(int), alpha))
    for sx, sy, sr, alpha in [(0.17, 0.14, 0.011, 235), (0.31, 0.27, 0.007, 170), (0.80, 0.11, 0.009, 220),
                              (0.68, 0.24, 0.006, 150), (0.89, 0.30, 0.007, 140), (0.10, 0.36, 0.006, 120),
                              (0.47, 0.08, 0.007, 190)]:
        draw.ellipse([(sx - sr) * n, (sy - sr) * n, (sx + sr) * n, (sy + sr) * n],
                     fill=(*rgb(STAR).astype(int), alpha))
    body = Image.alpha_composite(body, overlay)

    body.putalpha(squircle_mask(n, n))
    return body.resize((BODY, BODY), Image.LANCZOS)


def draw_icon():
    body = draw_body()
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))

    # Drop shadow per Apple's template: offset downwards, soft blur, ~30% black.
    shadow_alpha = Image.new("L", (SIZE, SIZE), 0)
    shadow_alpha.paste(body.getchannel("A").point(lambda a: a * 0.3), (MARGIN, MARGIN + 10))
    shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    shadow.putalpha(shadow_alpha.filter(ImageFilter.GaussianBlur(14)))

    canvas = Image.alpha_composite(canvas, shadow)
    canvas.alpha_composite(body, (MARGIN, MARGIN))
    return canvas


# icns element types that hold PNG data, and their pixel sizes.
ICNS_TYPES = [
    (b"icp4", 16), (b"icp5", 32), (b"ic11", 32), (b"ic12", 64), (b"ic07", 128),
    (b"ic13", 256), (b"ic08", 256), (b"ic14", 512), (b"ic09", 512), (b"ic10", 1024),
]


def write_icns(master, path):
    elements = b""
    for ostype, px in ICNS_TYPES:
        buf = io.BytesIO()
        master.resize((px, px), Image.LANCZOS).save(buf, format="PNG", optimize=True)
        data = buf.getvalue()
        elements += ostype + struct.pack(">I", 8 + len(data)) + data
    path.write_bytes(b"icns" + struct.pack(">I", 8 + len(elements)) + elements)


if __name__ == "__main__":
    icon = draw_icon()
    icon.save(PNG_OUT, optimize=True)
    write_icns(icon, ICNS_OUT)
    print(f"wrote {PNG_OUT.relative_to(ROOT)} and {ICNS_OUT.relative_to(ROOT)}")
