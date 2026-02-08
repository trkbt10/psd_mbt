#!/usr/bin/env python3
"""Generate a 16-bit PSD file with a group containing layers.

In 16-bit PSD files, Photoshop stores layer data in a Lr16 global ALI block
rather than the regular layer_info section. This tests that code path.

Usage:
    python3 web/tests/fixtures/generate_16bit_grouped_psd.py
"""

import struct
from pathlib import Path

OUT = Path(__file__).parent / "test-16bit-grouped.psd"

W, H = 64, 64
DEPTH = 16  # 16-bit

# PSD layers bottom-to-top:
#   [0] Blue (flat)
#   [1] Section divider type 3 (group end marker)
#   [2] Red (inside Shapes group)
#   [3] Green (inside Shapes group)
#   [4] Section divider type 1 (group open marker) = "Shapes"

LAYERS = [
    {"name": "Blue", "color": (255, 0, 0, 255), "x": 28, "y": 28, "w": 32, "h": 32, "opacity": 255,
     "divider": None},
    {"name": "</Layer set>", "color": None, "x": 0, "y": 0, "w": 0, "h": 0, "opacity": 255,
     "divider": 3},
    {"name": "Red", "color": (255, 0, 0, 255), "x": 4, "y": 4, "w": 32, "h": 32, "opacity": 255,
     "divider": None},
    {"name": "Green", "color": (0, 255, 0, 255), "x": 16, "y": 16, "w": 32, "h": 32, "opacity": 128,
     "divider": None},
    {"name": "Shapes", "color": None, "x": 0, "y": 0, "w": 0, "h": 0, "opacity": 255,
     "divider": 1},
]


def make_lsct(divider_type: int) -> bytes:
    """Build an lsct (Section Divider Setting) ALI block."""
    data = struct.pack(">I", divider_type)
    block = b"8BIM" + b"lsct" + struct.pack(">I", len(data)) + data
    return block


def build_layer_section(depth: int) -> bytes:
    """Build the layer info section (layer records + channel data)."""
    section = bytearray()
    section += struct.pack(">h", len(LAYERS))

    # Layer records
    for layer in LAYERS:
        x, y, w, h_l = layer["x"], layer["y"], layer["w"], layer["h"]
        section += struct.pack(">IIII", y, x, y + h_l, x + w)

        pixel_count = w * h_l
        bytes_per_sample = depth // 8  # 2 for 16-bit

        if layer["color"] is not None:
            section += struct.pack(">H", 4)
            for ch_id in [-1, 0, 1, 2]:
                # channel data length: 2 (compression) + pixel_count * bytes_per_sample
                ch_data_len = 2 + pixel_count * bytes_per_sample
                section += struct.pack(">hI", ch_id, ch_data_len)
        else:
            section += struct.pack(">H", 4)
            for ch_id in [-1, 0, 1, 2]:
                section += struct.pack(">hI", ch_id, 2)

        section += b"8BIM"
        section += b"norm"
        section += struct.pack(">B", layer["opacity"])
        section += struct.pack(">B", 0)
        flags = 2 if layer["divider"] == 3 else 0
        section += struct.pack(">B", flags)
        section += b"\x00"

        name_bytes = layer["name"].encode("ascii")
        pascal_len = 1 + len(name_bytes)
        pascal_padded = pascal_len + (4 - pascal_len % 4) % 4

        ali_data = b""
        if layer["divider"] is not None:
            ali_data = make_lsct(layer["divider"])

        extra_len = 4 + 4 + pascal_padded + len(ali_data)
        section += struct.pack(">I", extra_len)
        section += struct.pack(">I", 0)
        section += struct.pack(">I", 0)
        section += struct.pack(">B", len(name_bytes))
        section += name_bytes
        section += b"\x00" * (pascal_padded - pascal_len)
        section += ali_data

    # Channel image data (16-bit samples)
    for layer in LAYERS:
        w_l, h_l = layer["x"], layer["y"]  # Unused, get from dict
        w_l, h_l = layer["w"], layer["h"]

        if layer["color"] is not None:
            r, g, b, a = layer["color"]
            pixel_count = w_l * h_l
            for ch_val in [a, r, g, b]:
                section += struct.pack(">H", 0)  # Raw compression
                # 16-bit samples: scale 0-255 to 0-65535
                val16 = ch_val * 257  # e.g. 255 * 257 = 65535
                for _ in range(pixel_count):
                    section += struct.pack(">H", val16)
        else:
            for _ in range(4):
                section += struct.pack(">H", 0)

    return bytes(section)


def main():
    buf = bytearray()

    # === Header (26 bytes) ===
    buf += b"8BPS"
    buf += struct.pack(">H", 1)  # version
    buf += b"\x00" * 6
    buf += struct.pack(">H", 4)  # channels (RGBA)
    buf += struct.pack(">I", H)
    buf += struct.pack(">I", W)
    buf += struct.pack(">H", DEPTH)  # 16-bit
    buf += struct.pack(">H", 3)  # RGB

    # === Color Mode Data ===
    buf += struct.pack(">I", 0)

    # === Image Resources ===
    buf += struct.pack(">I", 0)

    # === Layer and Mask Information ===
    # For 16-bit PSD: layer_info section is EMPTY, layers are in Lr16 ALI block

    layer_data = build_layer_section(DEPTH)

    # Build Lr16 ALI block
    lr16_ali = b"8BIM" + b"Lr16" + struct.pack(">I", len(layer_data)) + layer_data
    # Pad to even
    if len(lr16_ali) % 2 != 0:
        lr16_ali += b"\x00"

    # Layer and mask section:
    #   layer_info_length (4 bytes) = 0 (empty)
    #   global_mask_info = none
    #   additional_layer_info = [Lr16 block]
    lam_content = bytearray()
    lam_content += struct.pack(">I", 0)  # layer_info_length = 0 (empty)
    # Global layer mask info (length = 0)
    lam_content += struct.pack(">I", 0)
    # Lr16 ALI block
    lam_content += lr16_ali

    buf += struct.pack(">I", len(lam_content))
    buf += lam_content

    # === Image Data (Section 5) - Composite (16-bit) ===
    composite = [[[255, 255, 255, 255] for _ in range(W)] for _ in range(H)]

    visual_order = [
        LAYERS[0],  # Blue (flat)
        LAYERS[2],  # Red
        LAYERS[3],  # Green
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
    for ch in range(4):  # R, G, B, A planar
        for y in range(H):
            for x in range(W):
                val = composite[y][x][ch]
                val16 = val * 257  # scale to 16-bit
                buf += struct.pack(">H", val16)

    OUT.write_bytes(buf)
    print(f"Generated {OUT} ({len(buf)} bytes)")


if __name__ == "__main__":
    main()
