#!/usr/bin/env python3
"""Draw the rawin-launcher icon (ui/icon.png, 130 px) with no image libraries:
a dark rounded square with a rail of three tiles, the middle one focused."""
import struct
import zlib
from pathlib import Path

SIZE, SS = 130, 4  # output size, supersampling factor


def rounded(x, y, x0, y0, x1, y1, r):
    """Whether (x, y) lies inside the rounded rectangle."""
    if not (x0 <= x <= x1 and y0 <= y <= y1):
        return False
    cx = min(max(x, x0 + r), x1 - r)
    cy = min(max(y, y0 + r), y1 - r)
    return (x - cx) ** 2 + (y - cy) ** 2 <= r * r


def colour(x, y):
    # Background, then shapes on top (RGBA).
    c = (0, 0, 0, 0)
    if rounded(x, y, 0, 0, 130, 130, 30):
        c = (14, 15, 19, 255)
    tiles = [(17, 52, 45, 80), (51, 46, 79, 84), (85, 52, 113, 80)]
    for i, (x0, y0, x1, y1) in enumerate(tiles):
        if i == 1:
            if rounded(x, y, x0 - 6, y0 - 6, x1 + 6, y1 + 6, 12):
                c = (242, 243, 245, 255)
            if rounded(x, y, x0 - 3, y0 - 3, x1 + 3, y1 + 3, 10):
                c = (14, 15, 19, 255)
            if rounded(x, y, x0, y0, x1, y1, 8):
                c = (235, 48, 64, 255)
        elif rounded(x, y, x0, y0, x1, y1, 8):
            c = (58, 61, 70, 255)
    return c


def main():
    rows = []
    for py in range(SIZE):
        row = bytearray([0])
        for px in range(SIZE):
            acc = [0, 0, 0, 0]
            for sy in range(SS):
                for sx in range(SS):
                    c = colour(px + (sx + 0.5) / SS, py + (sy + 0.5) / SS)
                    for i in range(4):
                        acc[i] += c[i]
            n = SS * SS
            a = acc[3] / n
            row += bytes([min(255, int(acc[i] / n * 255 / a)) if a else 0 for i in range(3)] + [int(a)])
        rows.append(bytes(row))

    def chunk(kind, data):
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xffffffff)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(b"".join(rows), 9)) + chunk(b"IEND", b"")
    out = Path(__file__).resolve().parent.parent / "ui" / "icon.png"
    out.write_bytes(png)
    print(out)


if __name__ == "__main__":
    main()
