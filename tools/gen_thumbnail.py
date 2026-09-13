#!/usr/bin/env python3
"""Generate thumbnail.png, the Steam Workshop cover image.

Steam wants a square PNG under 1 MB; Millennium Dawn ships 500x500, so we match it.
The palette is sampled from MD's own thumbnail (navy #131B40 -> #020409 with a
#0083B7 accent) so the patch reads as part of that family on a Workshop page.

Drawn programmatically rather than stored as a binary blob: the wordmark is the mod
name, so a rename means re-running this rather than hunting for the source file.

    python3 tools/gen_thumbnail.py [-o PATH] [--size N]

Everything is drawn at 4x and downsampled, which is what gives the text and the bar
tops clean edges - PIL has no antialiasing of its own.
"""
import argparse, os, sys

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    sys.exit("error: needs Pillow (pip install Pillow)")

SS = 4  # supersampling factor

NAVY = (26, 36, 80)
EDGE = (2, 4, 9)
ACCENT = (0, 131, 183)
ACCENT_LIGHT = (53, 182, 232)
WHITE = (255, 255, 255)
MUTED = (126, 138, 168)
RULE = (42, 53, 96)

FONTS = "/usr/share/fonts/noto"
BLACK_F = FONTS + "/NotoSans-Black.ttf"
BOLD_F = FONTS + "/NotoSans-Bold.ttf"
REG_F = FONTS + "/NotoSans-Regular.ttf"


def lerp(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def background(size):
    """Radial navy->black, built small and scaled up so it costs nothing to smooth."""
    n = 96
    g = Image.new("RGB", (n, n))
    px = g.load()
    cx, cy = n / 2, n * 0.40  # centre of light sits above middle, like MD's
    far = ((n / 2) ** 2 + (n * 0.75) ** 2) ** 0.5
    for y in range(n):
        for x in range(n):
            d = min(1.0, (((x - cx) ** 2 + (y - cy) ** 2) ** 0.5) / far)
            px[x, y] = lerp(NAVY, EDGE, d ** 0.85)
    return g.resize((size, size), Image.LANCZOS)


def spaced(draw, text, font, cx, y, fill, tracking):
    """Centred text with letter-spacing; PIL has no tracking of its own."""
    widths = [draw.textlength(c, font=font) for c in text]
    total = sum(widths) + tracking * (len(text) - 1)
    x = cx - total / 2
    for c, w in zip(text, widths):
        draw.text((x, y), c, font=font, fill=fill)
        x += w + tracking


def centred(draw, text, font, cx, y, fill):
    draw.text((cx - draw.textlength(text, font=font) / 2, y), text, font=font, fill=fill)


def render(size):
    S = size * SS
    img = background(S)
    d = ImageDraw.Draw(img)
    u = S / 500.0  # design in 500px units, draw at SS

    # Bar chart mark: five rising bars, one per system plus the trend.
    heights = [34, 58, 82, 110, 145]
    bw, gap = 30, 14
    total = len(heights) * bw + (len(heights) - 1) * gap
    x = (500 - total) / 2
    base = 214
    for i, h in enumerate(heights):
        col = lerp(ACCENT, ACCENT_LIGHT, i / (len(heights) - 1))
        d.rounded_rectangle(
            [x * u, (base - h) * u, (x + bw) * u, base * u],
            radius=5 * u, fill=col)
        x += bw + gap

    # Baseline the bars sit on.
    d.rectangle([(500 - total) / 2 * u, base * u, ((500 - total) / 2 + total) * u,
                 (base + 3) * u], fill=RULE)

    f_name = ImageFont.truetype(BLACK_F, int(60 * u))
    f_sub = ImageFont.truetype(BOLD_F, int(40 * u))
    f_tag = ImageFont.truetype(REG_F, int(14 * u))

    centred(d, "+EASYBUFF", f_name, S / 2, 250 * u, WHITE)
    spaced(d, "MD SYSTEMS", f_sub, S / 2, 320 * u, ACCENT_LIGHT, 3 * u)

    d.rectangle([150 * u, 385 * u, 350 * u, (385 + 1) * u], fill=RULE)

    spaced(d, "ECONOMY · POLITICS · COUNTER-TERROR · ENERGY",
           f_tag, S / 2, 401 * u, MUTED, 0.6 * u)
    spaced(d, "A PATCH FOR MILLENNIUM DAWN + EASYBUFF",
           f_tag, S / 2, 427 * u, MUTED, 0.6 * u)

    return img.resize((size, size), Image.LANCZOS)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-o", "--out", default="thumbnail.png")
    ap.add_argument("--size", type=int, default=500)
    a = ap.parse_args()

    for f in (BLACK_F, BOLD_F, REG_F):
        if not os.path.exists(f):
            sys.exit("error: missing font %s" % f)

    render(a.size).save(a.out, "PNG", optimize=True)
    n = os.path.getsize(a.out)
    print("wrote %s: %dx%d, %d bytes" % (a.out, a.size, a.size, n))
    if n > 1048576:
        sys.exit("error: over Steam's 1 MB limit")


if __name__ == "__main__":
    main()
