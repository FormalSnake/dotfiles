#!/usr/bin/env python3
"""Side-by-side preview strip of finished App Store screenshots."""

import argparse
from pathlib import Path

from PIL import Image, ImageDraw


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("images", nargs="+")
    ap.add_argument("-o", "--out", required=True)
    ap.add_argument("--height", type=int, default=760)
    ap.add_argument("--gap", type=int, default=28)
    ap.add_argument("--bg", default="#101014")
    ap.add_argument("--radius", type=int, default=22)
    args = ap.parse_args()

    panels = []
    for p in args.images:
        im = Image.open(p).convert("RGB")
        w = round(im.width * args.height / im.height)
        panels.append(im.resize((w, args.height), Image.LANCZOS))

    total_w = sum(p.width for p in panels) + args.gap * (len(panels) + 1)
    strip = Image.new("RGB", (total_w, args.height + 2 * args.gap), args.bg)
    x = args.gap
    for p in panels:
        mask = Image.new("L", p.size, 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, p.width - 1, p.height - 1], radius=args.radius, fill=255)
        strip.paste(p, (x, args.gap), mask)
        x += p.width + args.gap
    strip.save(args.out, "PNG")
    print(f"{args.out} ({strip.width}x{strip.height}, {len(panels)} panels)")


if __name__ == "__main__":
    main()
