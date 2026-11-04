#!/usr/bin/env python3
"""Recolour a picture to the Wharf icon's two colours (#14120D to #EBBB66).

Usage:
  python3 duotone.py IN.jpg OUT.jpg [--crop L,T,R,B] [--curve 1.2] [--width 1920]

--crop   pixel box in the source image, to cut away scan borders and colour charts
--curve  >1 darkens the midtones (1.1 to 1.3 suits most archival scans)
--width  longest width kept; larger images are scaled down
Needs Pillow (pip install pillow).
"""
import argparse
from PIL import Image, ImageOps

LO = (0x14, 0x12, 0x0D)  # --color-paper
HI = (0xEB, 0xBB, 0x66)  # --color-accent


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("src")
    p.add_argument("dst")
    p.add_argument("--crop", help="L,T,R,B in source pixels")
    p.add_argument("--curve", type=float, default=1.2)
    p.add_argument("--width", type=int, default=1920)
    a = p.parse_args()

    im = Image.open(a.src).convert("L")
    if a.crop:
        im = im.crop(tuple(int(v) for v in a.crop.split(",")))
    im = ImageOps.autocontrast(im, cutoff=1)
    if im.width > a.width:
        im = im.resize((a.width, round(im.height * a.width / im.width)), Image.LANCZOS)

    lut = []
    for c in range(3):
        lut += [int(LO[c] + (HI[c] - LO[c]) * ((i / 255) ** a.curve)) for i in range(256)]
    im.convert("RGB").point(lut).save(a.dst, quality=84, optimize=True, progressive=True)
    print(f"{a.dst} {im.width}x{im.height}")


if __name__ == "__main__":
    main()
