#!/usr/bin/env python3
"""Generate a PSD file with a HIDDEN group containing visible layers.

Tests that group visibility propagation works correctly:
children of a hidden group should NOT be rendered.

Usage:
    python3 web/tests/fixtures/generate_hidden_group_psd.py
"""

import struct
from pathlib import Path

OUT = Path(__file__).parent / "test-hidden-group.psd"

W, H = 64, 64

# PSD layers bottom-to-top:
#   [0] Blue (flat, visible)
#   [1] Section divider type 3 (end marker for Hidden group)
#   [2] Red (inside Hidden group, individually visible)
#   [3] Section divider type 1 (open marker for Hidden group) - FLAGS=2 (hidden)

LAYERS = [
    {"name": "Blue", "color": (0, 0, 255, 255), "x": 4, "y": 4, "w": 32, "h": 32, "opacity": 255,
     "divider": None, "hidden": False},
    {"name": "</Layer set>", "color": None, "x": 0, "y": 0, "w": 0, "h": 0, "opacity": 255,
     "divider": 3, "hidden": True},
    {"name": "Red", "color": (255, 0, 0, 255), "x": 16, "y": 16, "w": 32, "h": 32, "opacity": 255,
     "divider": None, "hidden": False},
    {"name": "HiddenGroup", "color": None, "x": 0, "y": 0, "w": 0, "h": 0, "opacity": 255,
     "divider": 1, "hidden": True},  # GROUP IS HIDDEN (flags bit 1 set)
]


def make_lsct(divider_type: int) -> bytes:
    data = struct.pack(">I", divider_type)
    return b"8BIM" + b"lsct" + struct.pack(">I", len(data)) + data


def main():
    buf = bytearray()

    # Header
    buf += b"8BPS"
    buf += struct.pack(">H", 1)
    buf += b"\x00" * 6
    buf += struct.pack(">H", 4)
    buf += struct.pack(">I", H)
    buf += struct.pack(">I", W)
    buf += struct.pack(">H", 8)
    buf += struct.pack(">H", 3)

    # Color Mode Data
    buf += struct.pack(">I", 0)

    # Image Resources
    buf += struct.pack(">I", 0)

    # Layer and Mask Information
    layer_section = bytearray()
    layer_section += struct.pack(">h", len(LAYERS))

    for layer in LAYERS:
        x, y, w, h_l = layer["x"], layer["y"], layer["w"], layer["h"]
        layer_section += struct.pack(">IIII", y, x, y + h_l, x + w)

        if layer["color"] is not None:
            layer_section += struct.pack(">H", 4)
            pixel_count = w * h_l
            for ch_id in [-1, 0, 1, 2]:
                layer_section += struct.pack(">hI", ch_id, pixel_count + 2)
        else:
            layer_section += struct.pack(">H", 4)
            for ch_id in [-1, 0, 1, 2]:
                layer_section += struct.pack(">hI", ch_id, 2)

        layer_section += b"8BIM"
        layer_section += b"norm"
        layer_section += struct.pack(">B", layer["opacity"])
        layer_section += struct.pack(">B", 0)
        flags = 2 if layer["hidden"] else 0
        layer_section += struct.pack(">B", flags)
        layer_section += b"\x00"

        name_bytes = layer["name"].encode("ascii")
        pascal_len = 1 + len(name_bytes)
        pascal_padded = pascal_len + (4 - pascal_len % 4) % 4

        ali_data = b""
        if layer["divider"] is not None:
            ali_data = make_lsct(layer["divider"])

        extra_len = 4 + 4 + pascal_padded + len(ali_data)
        layer_section += struct.pack(">I", extra_len)
        layer_section += struct.pack(">I", 0)
        layer_section += struct.pack(">I", 0)
        layer_section += struct.pack(">B", len(name_bytes))
        layer_section += name_bytes
        layer_section += b"\x00" * (pascal_padded - pascal_len)
        layer_section += ali_data

    # Channel image data
    for layer in LAYERS:
        w_l, h_l = layer["w"], layer["h"]
        if layer["color"] is not None:
            r, g, b, a = layer["color"]
            pixel_count = w_l * h_l
            for ch_val in [a, r, g, b]:
                layer_section += struct.pack(">H", 0)
                layer_section += bytes([ch_val] * pixel_count)
        else:
            for _ in range(4):
                layer_section += struct.pack(">H", 0)

    layer_info = struct.pack(">I", len(layer_section)) + layer_section
    if len(layer_info) % 2 != 0:
        layer_info += b"\x00"

    buf += struct.pack(">I", len(layer_info))
    buf += layer_info

    # Image Data - only Blue visible (group is hidden)
    composite = [[[255, 255, 255, 255] for _ in range(W)] for _ in range(H)]

    blue = LAYERS[0]
    x, y, w_l, h_l = blue["x"], blue["y"], blue["w"], blue["h"]
    r, g, b, a = blue["color"]
    for py in range(y, min(y + h_l, H)):
        for px in range(x, min(x + w_l, W)):
            composite[py][px] = [r, g, b, 255]

    buf += struct.pack(">H", 0)
    for ch in range(4):
        for y_i in range(H):
            for x_i in range(W):
                buf += bytes([composite[y_i][x_i][ch]])

    OUT.write_bytes(buf)
    print(f"Generated {OUT} ({len(buf)} bytes)")


if __name__ == "__main__":
    main()
