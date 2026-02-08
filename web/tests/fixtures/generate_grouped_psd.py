#!/usr/bin/env python3
"""Generate a PSD file with a group containing layers, for group rendering tests.

Usage:
    python3 web/tests/fixtures/generate_grouped_psd.py
"""

import struct
from pathlib import Path

OUT = Path(__file__).parent / "test-grouped-layers.psd"

W, H = 64, 64

# PSD layers are stored bottom-to-top.
# For a group "Shapes" containing Red and Green, plus a flat Blue:
# Bottom-to-top in layers array:
#   [0] Blue (flat)
#   [1] Section divider type 3 (group end marker) - bounding layer
#   [2] Red (inside Shapes group)
#   [3] Green (inside Shapes group)
#   [4] Section divider type 1 (group open marker) - "Shapes"

LAYERS = [
    # [0] Blue - flat layer
    {"name": "Blue", "color": (0, 0, 255, 255), "x": 28, "y": 28, "w": 32, "h": 32, "opacity": 255,
     "divider": None},
    # [1] Group end marker (type 3)
    {"name": "</Layer set>", "color": None, "x": 0, "y": 0, "w": 0, "h": 0, "opacity": 255,
     "divider": 3},
    # [2] Red - inside group
    {"name": "Red", "color": (255, 0, 0, 255), "x": 4, "y": 4, "w": 32, "h": 32, "opacity": 255,
     "divider": None},
    # [3] Green - inside group
    {"name": "Green", "color": (0, 255, 0, 255), "x": 16, "y": 16, "w": 32, "h": 32, "opacity": 128,
     "divider": None},
    # [4] Group open marker (type 1)
    {"name": "Shapes", "color": None, "x": 0, "y": 0, "w": 0, "h": 0, "opacity": 255,
     "divider": 1},
]


def make_lsct(divider_type: int) -> bytes:
    """Build an lsct (Section Divider Setting) ALI block."""
    # 8BIM + lsct + length(4) + divider_type(4) = 16 bytes
    data = struct.pack(">I", divider_type)
    # Full ALI: signature(4) + key(4) + length(4) + data
    block = b"8BIM" + b"lsct" + struct.pack(">I", len(data)) + data
    return block


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

        if layer["color"] is not None:
            # Real layer: 4 channels
            layer_section += struct.pack(">H", 4)
            pixel_count = w * h_l
            for ch_id in [-1, 0, 1, 2]:
                layer_section += struct.pack(">hI", ch_id, pixel_count + 2)
        else:
            # Divider: 0 channels (empty rect)
            layer_section += struct.pack(">H", 4)
            for ch_id in [-1, 0, 1, 2]:
                layer_section += struct.pack(">hI", ch_id, 2)  # just compression marker

        layer_section += b"8BIM"
        layer_section += b"norm"
        layer_section += struct.pack(">B", layer["opacity"])
        layer_section += struct.pack(">B", 0)  # clipping
        # flags: bit 1 = not visible. Divider end markers are typically hidden.
        flags = 0
        if layer["divider"] == 3:
            flags = 2  # hidden
        layer_section += struct.pack(">B", flags)
        layer_section += b"\x00"  # filler

        # Extra data (includes name + optional ALI)
        name_bytes = layer["name"].encode("ascii")
        pascal_len = 1 + len(name_bytes)
        pascal_padded = pascal_len + (4 - pascal_len % 4) % 4

        ali_data = b""
        if layer["divider"] is not None:
            ali_data = make_lsct(layer["divider"])

        extra_len = 4 + 4 + pascal_padded + len(ali_data)
        layer_section += struct.pack(">I", extra_len)
        layer_section += struct.pack(">I", 0)  # mask data
        layer_section += struct.pack(">I", 0)  # blending ranges
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
            for ch_val in [a, r, g, b]:  # Alpha, R, G, B
                layer_section += struct.pack(">H", 0)  # Raw compression
                layer_section += bytes([ch_val] * pixel_count)
        else:
            # Empty channels for divider layers
            for _ in range(4):
                layer_section += struct.pack(">H", 0)  # Raw compression, 0 pixels

    # Wrap layer section
    layer_info = struct.pack(">I", len(layer_section)) + layer_section
    if len(layer_info) % 2 != 0:
        layer_info += b"\x00"

    buf += struct.pack(">I", len(layer_info))
    buf += layer_info

    # === Image Data (Section 5) - Composite ===
    # White background, then alpha-blend each visible layer bottom-to-top
    composite = [[[255, 255, 255, 255] for _ in range(W)] for _ in range(H)]

    # Bottom-to-top visual order: Blue, then Red, then Green
    visual_order = [
        LAYERS[0],  # Blue (flat)
        LAYERS[2],  # Red (inside Shapes)
        LAYERS[3],  # Green (inside Shapes)
    ]

    for layer in visual_order:
        if layer["color"] is None:
            continue
        x, y, w_l, h_l = layer["x"], layer["y"], layer["w"], layer["h"]
        r, g, b, a = layer["color"]
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
