#!/usr/bin/env python3
"""App Store screenshot scaffold generator.

Renders one panel from a JSON spec: background (solid, gradient or image),
headline block, optional subheadline, device with the app screenshot inside.
The scaffold is the geometry contract for the AI enhance pass (canaryllm.py):
text content, placement, colours and device pose must survive enhancement, so
everything here is deterministic.

Usage:
  python3 compose.py panel.json -o scaffold.png
  python3 compose.py --style styles/x-dark.json panel.json -o scaffold.png

panel.json is deep-merged over the style file (panel wins). Unknown keys are
ignored, so styles may carry extra metadata like enhancePrompt.
"""

import argparse
import json
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

DEFAULTS = {
    "canvas": {"width": 1290, "height": 2796},
    "background": {"type": "solid", "color": "#101014"},
    "headline": {
        "font": [
            "/Library/Fonts/SF-Pro-Display-Bold.otf",
            "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        ],
        "size": "auto",
        "maxSize": 170,
        "minSize": 84,
        "color": "#FFFFFF",
        "uppercase": False,
        "tracking": 0.0,
        "lineHeight": 1.06,
        "stretch": 1.0,
        "align": "center",
        "y": 150,
        "maxWidth": 0.88,
    },
    "subheadline": None,
    "device": {
        "mode": "framed",
        "widthFrac": 0.80,
        "x": 0.5,
        "y": 0.30,
        "rotation": 0,
        "bezelWidth": 20,
        "bezelColor": "#0A0A0C",
        "cornerRadiusFrac": 0.105,
        "island": True,
        "shadow": True,
    },
}


def deep_merge(base, over):
    if not isinstance(base, dict) or not isinstance(over, dict):
        return over
    out = dict(base)
    for k, v in over.items():
        out[k] = deep_merge(out[k], v) if k in out else v
    return out


def hex_rgb(h):
    h = h.lstrip("#")
    if len(h) == 3:
        h = "".join(c * 2 for c in h)
    return tuple(int(h[i : i + 2], 16) for i in (0, 2, 4))


def resolve_font(spec):
    cands = spec if isinstance(spec, list) else [spec]
    for c in cands:
        p = Path(c).expanduser()
        if p.exists():
            return str(p)
    sys.exit(f"compose: no font found, tried: {', '.join(map(str, cands))}")


def make_background(w, h, spec):
    kind = spec.get("type", "solid")
    if kind == "solid":
        return Image.new("RGB", (w, h), hex_rgb(spec["color"]))
    if kind == "image":
        return Image.open(Path(spec["path"]).expanduser()).convert("RGB").resize((w, h), Image.LANCZOS)
    if kind == "gradient":
        c0, c1 = hex_rgb(spec["from"]), hex_rgb(spec["to"])
        ang = math.radians(spec.get("angle", 0))  # 0 = top to bottom
        dx, dy = math.sin(ang), math.cos(ang)
        # per-pixel on a small grid, upscaled: gradients survive bilinear resize
        sw, sh = max(2, w // 10), max(2, h // 10)
        span = abs(dx) * (sw - 1) + abs(dy) * (sh - 1) or 1
        x0 = (sw - 1) if dx < 0 else 0
        y0 = (sh - 1) if dy < 0 else 0
        px = []
        for y in range(sh):
            for x in range(sw):
                t = (abs(dx) * abs(x - x0) + abs(dy) * abs(y - y0)) / span
                px.append(tuple(round(a + (b - a) * t) for a, b in zip(c0, c1)))
        small = Image.new("RGB", (sw, sh))
        small.putdata(px)
        return small.resize((w, h), Image.BILINEAR)
    sys.exit(f"compose: unknown background type {kind!r}")


def wrap_lines(text, font, tracking_px, max_w):
    lines = []
    for para in text.split("\n"):
        words, cur = para.split(), ""
        for word in words:
            test = f"{cur} {word}".strip()
            if line_width(test, font, tracking_px) <= max_w or not cur:
                cur = test
            else:
                lines.append(cur)
                cur = word
        lines.append(cur)
    return lines


def line_width(line, font, tracking_px):
    if not line:
        return 0
    return sum(font.getlength(ch) for ch in line) + tracking_px * (len(line) - 1)


def render_text_block(spec, canvas_w):
    """Render a text block to an RGBA layer. Returns (layer, x, y)."""
    text = spec["text"]
    if spec.get("uppercase"):
        text = text.upper()
    font_path = resolve_font(spec["font"])
    stretch = spec.get("stretch", 1.0)
    max_w = int(spec.get("maxWidth", 0.88) * canvas_w / stretch)

    size = spec.get("size", "auto")
    if size == "auto":
        size = spec.get("maxSize", 170)
        while size > spec.get("minSize", 84):
            font = ImageFont.truetype(font_path, size)
            tr = spec.get("tracking", 0.0) * size
            if all(line_width(l, font, tr) <= max_w for l in wrap_lines(text, font, tr, max_w)):
                break
            size -= 4
    font = ImageFont.truetype(font_path, size)
    tracking_px = spec.get("tracking", 0.0) * size
    lines = wrap_lines(text, font, tracking_px, max_w)

    ascent, descent = font.getmetrics()
    line_h = round(size * spec.get("lineHeight", 1.06))
    block_w = max(1, round(max(line_width(l, font, tracking_px) for l in lines)))
    block_h = line_h * (len(lines) - 1) + ascent + descent

    layer = Image.new("RGBA", (block_w, block_h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    fill = hex_rgb(spec["color"])
    align = spec.get("align", "center")
    for i, line in enumerate(lines):
        lw = line_width(line, font, tracking_px)
        x = 0 if align == "left" else (block_w - lw) if align == "right" else (block_w - lw) / 2
        y = i * line_h
        for ch in line:
            draw.text((x, y), ch, font=font, fill=fill)
            x += font.getlength(ch) + tracking_px
    if stretch != 1.0:
        layer = layer.resize((round(block_w * stretch), block_h), Image.LANCZOS)

    bx = (canvas_w - layer.width) // 2 if align == "center" else round(0.06 * canvas_w)
    return layer, bx, round(spec.get("y", 150))


def render_device(spec, canvas_w, canvas_h):
    """Render the device layer. Returns (layer, x, y) for alpha_composite."""
    shot = Image.open(Path(spec["screenshot"]).expanduser()).convert("RGBA")
    mode = spec.get("mode", "framed")
    dev_w = round(spec.get("widthFrac", 0.80) * canvas_w)

    if mode == "fullbleed":
        bezel, radius = 0, round(spec.get("cornerRadiusFrac", 0.105) * dev_w)
    else:
        bezel = round(spec.get("bezelWidth", 20))
        radius = round(spec.get("cornerRadiusFrac", 0.105) * dev_w)

    screen_w = dev_w - 2 * bezel
    screen_h = round(shot.height * screen_w / shot.width)
    dev_h = screen_h + 2 * bezel
    dev = Image.new("RGBA", (dev_w, dev_h), (0, 0, 0, 0))
    ddraw = ImageDraw.Draw(dev)
    if bezel:
        ddraw.rounded_rectangle([0, 0, dev_w - 1, dev_h - 1], radius=radius, fill=hex_rgb(spec.get("bezelColor", "#0A0A0C")))

    shot = shot.resize((screen_w, screen_h), Image.LANCZOS)
    mask = Image.new("L", (screen_w, screen_h), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, screen_w - 1, screen_h - 1], radius=max(1, radius - bezel), fill=255
    )
    dev.paste(shot, (bezel, bezel), mask)

    if spec.get("island", True) and mode == "framed":
        iw, ih = round(screen_w * 0.26), round(screen_w * 0.055)
        ix, iy = (dev_w - iw) // 2, bezel + round(screen_w * 0.035)
        ddraw = ImageDraw.Draw(dev)
        ddraw.rounded_rectangle([ix, iy, ix + iw, iy + ih], radius=ih // 2, fill=(5, 5, 7, 255))

    rot = spec.get("rotation", 0)
    if rot:
        dev = dev.rotate(rot, expand=True, resample=Image.BICUBIC)

    x = round(spec.get("x", 0.5) * canvas_w - dev.width / 2)
    y = round(spec.get("y", 0.30) * canvas_h)

    if spec.get("shadow", True):
        pad = 120
        sh_layer = Image.new("RGBA", (dev.width + 2 * pad, dev.height + 2 * pad), (0, 0, 0, 0))
        alpha = dev.split()[3].point(lambda a: min(a, 140))
        sh_layer.paste((0, 0, 0, 140), (pad, pad + 30), alpha)
        sh_layer = sh_layer.filter(ImageFilter.GaussianBlur(40))
        sh_layer.alpha_composite(dev, (pad, pad))
        return sh_layer, x - pad, y - pad
    return dev, x, y


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("panel", help="panel JSON spec")
    ap.add_argument("--style", help="style preset JSON merged under the panel")
    ap.add_argument("-o", "--out", required=True)
    args = ap.parse_args()

    spec = DEFAULTS
    if args.style:
        spec = deep_merge(spec, json.loads(Path(args.style).read_text()))
    spec = deep_merge(spec, json.loads(Path(args.panel).read_text()))

    w, h = spec["canvas"]["width"], spec["canvas"]["height"]
    canvas = make_background(w, h, spec["background"]).convert("RGBA")

    if spec.get("device", {}).get("screenshot"):
        layer, x, y = render_device(spec["device"], w, h)
        full = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        # clamp paste into canvas, allowing overflow off any edge
        full.alpha_composite(layer, (max(-layer.width, x), max(-layer.height, y)))
        canvas = Image.alpha_composite(canvas, full)

    y_cursor = None
    for key in ("headline", "subheadline"):
        block = spec.get(key)
        if not block or not block.get("text"):
            continue
        layer, x, y = render_text_block(block, w)
        if key == "subheadline" and "y" not in block and y_cursor is not None:
            y = y_cursor + 36
        canvas.alpha_composite(layer, (x, y))
        y_cursor = y + layer.height

    canvas.convert("RGB").save(args.out, "PNG")
    print(f"{args.out} ({w}x{h})")


if __name__ == "__main__":
    main()
