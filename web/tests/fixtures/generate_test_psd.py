#!/usr/bin/env python3
"""Generate a small multi-layer PSD file for visual regression tests.

Usage:
    python3 web/tests/fixtures/generate_test_psd.py
"""

import struct
from pathlib import Path

OUT = Path(__file__).parent / "test-layers.psd"

W, H = 64, 64

LAYERS = [
    {"name": "Red", "color": (255, 0, 0, 255), "x": 4, "y": 4, "w": 32, "h": 32, "opacity": 255},
    {"name": "Green", "color": (0, 255, 0, 255), "x": 16, "y": 16, "w": 32, "h": 32, "opacity": 255},
    {"name": "Blue", "color": (0, 0, 255, 255), "x": 28, "y": 28, "w": 32, "h": 32, "opacity": 128},
]


def main():
    buf = bytearray()

    # === Header (26 bytes) ===
    buf += b"8BPS"
    buf += struct.pack(">H", 1)  # version
    buf += b"\x00" * 6           # reserved
    buf += struct.pack(">H", 4)  # channels (RGBA)
    buf += struct.pack(">I", H)
    buf += struct.pack(">I", W)
    buf += struct.pack(">H", 8)  # depth
    buf += struct.pack(">H", 3)  # RGB color mode

    # === Color Mode Data ===
    buf += struct.pack(">I", 0)

    # === Image Resources ===
    buf += struct.pack(">I", 0)

    # === Layer and Mask Information ===
    layer_section = bytearray()
    layer_section += struct.pack(">h", len(LAYERS))

    # Layer records
    for layer in LAYERS:
        x, y, w, h_l = layer["x"], layer["y"], layer["w"], layer["h"]
        layer_section += struct.pack(">IIII", y, x, y + h_l, x + w)
        layer_section += struct.pack(">H", 4)  # 4 channels
        pixel_count = w * h_l
        for ch_id in [-1, 0, 1, 2]:
            layer_section += struct.pack(">hI", ch_id, pixel_count + 2)
        layer_section += b"8BIM"
        layer_section += b"norm"
        layer_section += struct.pack(">B", layer["opacity"])
        layer_section += struct.pack(">B", 0)  # clipping
        layer_section += struct.pack(">B", 0)  # flags (visible)
        layer_section += b"\x00"               # filler

        name_bytes = layer["name"].encode("ascii")
        pascal_len = 1 + len(name_bytes)
        pascal_padded = pascal_len + (4 - pascal_len % 4) % 4
        extra_len = 4 + 4 + pascal_padded
        layer_section += struct.pack(">I", extra_len)
        layer_section += struct.pack(">I", 0)  # mask data
        layer_section += struct.pack(">I", 0)  # blending ranges
        layer_section += struct.pack(">B", len(name_bytes))
        layer_section += name_bytes
        layer_section += b"\x00" * (pascal_padded - pascal_len)

    # Channel image data
    for layer in LAYERS:
        w, h_l = layer["w"], layer["h"]
        r, g, b, a = layer["color"]
        pixel_count = w * h_l

        for ch_val in [a, r, g, b]:  # Alpha, R, G, B
            layer_section += struct.pack(">H", 0)  # Raw compression
            layer_section += bytes([ch_val] * pixel_count)

    # Wrap layer section
    layer_info = struct.pack(">I", len(layer_section)) + layer_section
    if len(layer_info) % 2 != 0:
        layer_info += b"\x00"

    buf += struct.pack(">I", len(layer_info))
    buf += layer_info

    # === Image Data (Section 5) - Composite ===
    # White background, then alpha-blend each layer top-to-bottom
    composite = [[[255, 255, 255, 255] for _ in range(W)] for _ in range(H)]
    for layer in LAYERS:
        x, y, w_l, h_l = layer["x"], layer["y"], layer["w"], layer["h"]
        r, g, b, a = layer["color"]
        # Effective alpha = pixel alpha * layer opacity
        alpha = (a / 255.0) * (layer["opacity"] / 255.0)
        for py in range(y, min(y + h_l, H)):
            for px in range(x, min(x + w_l, W)):
                dst = composite[py][px]
                composite[py][px] = [
                    int(r * alpha + dst[0] * (1 - alpha)),
                    int(g * alpha + dst[1] * (1 - alpha)),
                    int(b * alpha + dst[2] * (1 - alpha)),
                    255,
                ]

    buf += struct.pack(">H", 0)  # Raw compression
    for ch in range(4):
        for y in range(H):
            for x in range(W):
                buf += bytes([composite[y][x][ch]])

    OUT.write_bytes(buf)
    print(f"Generated {OUT} ({len(buf)} bytes)")


if __name__ == "__main__":
    main()
