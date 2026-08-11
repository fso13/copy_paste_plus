#!/usr/bin/env python3
"""Generate CopyPastePlus app icons matching in-app BrandClipboardIcon."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
ACCENT = (189, 147, 249, 255)  # #BD93F9
BG = (40, 42, 54, 255)  # #282A36
BG_DEEP = (33, 34, 44, 255)  # #21222C


def draw_brand_icon(size: int) -> Image.Image:
    """Draw clipboard + plus badge on dark rounded square."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    pad = int(size * 0.08)
    left = top = pad
    right = bottom = size - pad
    box = right - left
    corner = box * 0.22
    stroke = max(2, int(size * 0.038))

    draw.rounded_rectangle(
        (left, top, right, bottom),
        radius=corner,
        fill=BG,
    )

    # Clipboard body
    cx = (left + right) / 2
    clip_w = box * 0.40
    clip_h = box * 0.50
    clip_left = cx - clip_w / 2
    clip_top = top + box * 0.24
    clip_right = cx + clip_w / 2
    clip_bottom = clip_top + clip_h

    draw.rounded_rectangle(
        (clip_left, clip_top, clip_right, clip_bottom),
        radius=box * 0.06,
        outline=ACCENT,
        width=stroke,
    )

    # Clipboard clip tab
    tab_w = clip_w * 0.44
    tab_h = box * 0.085
    tab_left = cx - tab_w / 2
    tab_top = clip_top - tab_h * 0.65
    tab_right = cx + tab_w / 2
    tab_bottom = tab_top + tab_h
    draw.rounded_rectangle(
        (tab_left, tab_top, tab_right, tab_bottom),
        radius=tab_h * 0.35,
        fill=BG,
        outline=ACCENT,
        width=stroke,
    )

    # Text lines
    line_left = clip_left + clip_w * 0.20
    line_right = clip_right - clip_w * 0.20
    line_y0 = clip_top + clip_h * 0.30
    gap = clip_h * 0.155
    line_h = max(2, int(size * 0.022))
    for i in range(3):
        y = line_y0 + i * gap
        w = (line_right - line_left) * (1.0 - i * 0.14)
        draw.rounded_rectangle(
            (line_left, y, line_left + w, y + line_h),
            radius=line_h / 2,
            fill=ACCENT,
        )

    # Plus badge
    badge_r = box * 0.135
    bx = clip_right - badge_r * 0.05
    by = clip_bottom - badge_r * 0.05
    ring = box * 0.03
    draw.ellipse(
        (
            bx - badge_r - ring,
            by - badge_r - ring,
            bx + badge_r + ring,
            by + badge_r + ring,
        ),
        fill=BG,
    )
    draw.ellipse(
        (bx - badge_r, by - badge_r, bx + badge_r, by + badge_r),
        fill=ACCENT,
    )

    plus_w = badge_r * 1.05
    plus_t = max(2, int(size * 0.03))
    draw.rounded_rectangle(
        (bx - plus_w / 2, by - plus_t / 2, bx + plus_w / 2, by + plus_t / 2),
        radius=plus_t / 2,
        fill=BG_DEEP,
    )
    draw.rounded_rectangle(
        (bx - plus_t / 2, by - plus_w / 2, bx + plus_t / 2, by + plus_w / 2),
        radius=plus_t / 2,
        fill=BG_DEEP,
    )

    return img


def main() -> None:
    master = draw_brand_icon(1024)

    out_assets = ROOT / "assets" / "AppIcons"
    out_assets.mkdir(parents=True, exist_ok=True)
    master.save(out_assets / "appstore.png")

    docs = ROOT / "docs" / "screenshots"
    docs.mkdir(parents=True, exist_ok=True)
    master.save(docs / "app-icon.png")

    iconset = ROOT / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    for name, px in {
        "app_icon_16.png": 16,
        "app_icon_32.png": 32,
        "app_icon_64.png": 64,
        "app_icon_128.png": 128,
        "app_icon_256.png": 256,
        "app_icon_512.png": 512,
        "app_icon_1024.png": 1024,
    }.items():
        master.resize((px, px), Image.Resampling.LANCZOS).save(iconset / name)

    print(f"Wrote icons → {out_assets} and {iconset}")


if __name__ == "__main__":
    main()
