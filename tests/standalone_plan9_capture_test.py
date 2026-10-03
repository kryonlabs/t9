"""Check captures made by the real Terminal executable inside its private VM."""
from pathlib import Path
import sys


def main():
    # --geometry 64x20 sets the standalone host's owned offscreen viewport.
    width, height = 660, 478
    blank, rendered = (Path(path).read_bytes() for path in sys.argv[1:])
    expected = width * height * 4
    assert len(blank) == len(rendered) == expected, (len(blank), len(rendered), expected)
    assert all(rendered[index] == 255 for index in range(3, expected, 4)), "Non-opaque native capture"
    red = [index // 4 for index in range(0, expected, 4)
           if rendered[index:index + 4] == b"\xff\x00\x00\xff"]
    assert len(red) >= 300, ("ANSI truecolor background was not drawn", len(red))
    changed = sum(blank[index:index + 4] != rendered[index:index + 4]
                  for index in range(0, expected, 4))
    assert changed >= 1000, ("Child output did not reach native application rendering", changed)
    left, right = min(pixel % width for pixel in red), max(pixel % width for pixel in red)
    top, bottom = min(pixel // width for pixel in red), max(pixel // width for pixel in red)
    glyphs = sum(rendered[(row * width + col) * 4:(row * width + col) * 4 + 4]
                 == b"\xff\xff\xff\xff"
                 for row in range(top, bottom + 1) for col in range(left, right + 1))
    assert glyphs >= 25, ("Native glyphs were not drawn over the ANSI background", glyphs)
    print(f"Native Terminal capture: {len(red)} ANSI pixels, {glyphs} glyph pixels, {changed} changed pixels")


if __name__ == "__main__":
    main()
