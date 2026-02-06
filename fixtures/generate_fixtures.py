#!/usr/bin/env python3
"""Generate PSD fixture files for testing.

Usage:
    uv run --with psd-tools python fixtures/generate_fixtures.py
"""

import struct
from pathlib import Path

FIXTURES_DIR = Path(__file__).parent


def make_header(channels=3, height=1, width=1, depth=8, color_mode=3, version=1):
    """Generate a PSD file header (26 bytes)."""
    buf = bytearray()
    buf += b"8BPS"
    buf += struct.pack(">H", version)
    buf += b"\x00" * 6
    buf += struct.pack(">H", channels)
    buf += struct.pack(">I", height)
    buf += struct.pack(">I", width)
    buf += struct.pack(">H", depth)
    buf += struct.pack(">H", color_mode)
    return buf


def packbits_encode(data: bytes) -> bytes:
    """Simple PackBits encoder for fixture generation."""
    result = bytearray()
    i = 0
    n = len(data)
    while i < n:
        # Check for run
        run_val = data[i]
        run_len = 1
        while i + run_len < n and data[i + run_len] == run_val and run_len < 128:
            run_len += 1
        if run_len >= 3:
            result.append((257 - run_len) & 0xFF)
            result.append(run_val)
            i += run_len
        else:
            # Literal
            lit_start = i
            lit_len = 0
            while i + lit_len < n and lit_len < 128:
                if lit_len > 0 and i + lit_len + 2 < n:
                    c = data[i + lit_len]
                    if data[i + lit_len + 1] == c and data[i + lit_len + 2] == c:
                        break
                lit_len += 1
            if lit_len == 0:
                lit_len = 1
            result.append(lit_len - 1)
            result.extend(data[lit_start : lit_start + lit_len])
            i = lit_start + lit_len
    return bytes(result)


def generate_phase0_minimal():
    """Generate minimal valid PSD: 1x1 RGB 8-bit, Raw compression, black pixel."""
    buf = bytearray()
    buf += make_header()
    buf += struct.pack(">I", 0)  # Color Mode Data length = 0
    buf += struct.pack(">I", 0)  # Image Resources length = 0
    buf += struct.pack(">I", 0)  # Layer and Mask length = 0
    buf += struct.pack(">H", 0)  # Compression = Raw
    buf += b"\x00" * 3  # 1px * 3 channels

    assert len(buf) == 43, f"Expected 43 bytes, got {len(buf)}"
    output = FIXTURES_DIR / "phase0_minimal.psd"
    output.write_bytes(bytes(buf))
    print(f"Generated {output} ({len(buf)} bytes)")


def generate_phase1_rle():
    """Generate 1x1 RGB 8-bit PSD with RLE compression."""
    buf = bytearray()
    buf += make_header()
    buf += struct.pack(">I", 0)  # Color Mode Data
    buf += struct.pack(">I", 0)  # Image Resources
    buf += struct.pack(">I", 0)  # Layer and Mask

    # Image Data: RLE compressed
    buf += struct.pack(">H", 1)  # Compression = RLE

    # Byte counts: 3 channels x 1 row = 3 entries
    # Each scanline (1 pixel = 1 byte) encodes to 2 bytes in PackBits
    for _ in range(3):
        buf += struct.pack(">H", 2)  # byte count = 2

    # PackBits data: literal 1 byte (control=0x00, data=0x00)
    for _ in range(3):
        buf += b"\x00\x00"

    output = FIXTURES_DIR / "phase1_rle.psd"
    output.write_bytes(bytes(buf))
    print(f"Generated {output} ({len(buf)} bytes)")


def generate_phase2_resources():
    """Generate 1x1 RGB with ResolutionInfo resource block."""
    buf = bytearray()
    buf += make_header()
    buf += struct.pack(">I", 0)  # Color Mode Data

    # Image Resources section
    res_buf = bytearray()
    # Resource block: ResolutionInfo (ID 1005)
    res_buf += b"8BIM"  # Signature
    res_buf += struct.pack(">H", 1005)  # Resource ID
    res_buf += b"\x00\x00"  # Name: empty Pascal string (2 bytes)
    # ResolutionInfo data: 16 bytes
    res_data = bytearray()
    res_data += struct.pack(">I", 0x00480000)  # hRes = 72.0 Fixed16.16
    res_data += struct.pack(">H", 1)  # hResUnit = pixels/inch
    res_data += struct.pack(">H", 1)  # widthUnit = inches
    res_data += struct.pack(">I", 0x00480000)  # vRes = 72.0
    res_data += struct.pack(">H", 1)  # vResUnit
    res_data += struct.pack(">H", 1)  # heightUnit
    res_buf += struct.pack(">I", len(res_data))  # Data length = 16
    res_buf += res_data

    buf += struct.pack(">I", len(res_buf))  # Resources section length
    buf += res_buf
    buf += struct.pack(">I", 0)  # Layer and Mask
    buf += struct.pack(">H", 0)  # Compression = Raw
    buf += b"\x00" * 3  # Pixel data

    output = FIXTURES_DIR / "phase2_resources.psd"
    output.write_bytes(bytes(buf))
    print(f"Generated {output} ({len(buf)} bytes)")


def generate_phase3_single_layer():
    """Generate 4x4 RGB with 1 layer (all red), normal blend, Raw channel data."""
    width, height, channels = 4, 4, 3
    buf = bytearray()
    buf += make_header(channels=channels, height=height, width=width)
    buf += struct.pack(">I", 0)  # Color Mode Data
    buf += struct.pack(">I", 0)  # Image Resources

    # Layer and Mask Information section
    lm_buf = bytearray()

    # Layer Info
    li_buf = bytearray()
    li_buf += struct.pack(">h", 1)  # Layer count = 1

    # Layer Record
    lr_buf = bytearray()
    lr_buf += struct.pack(">i", 0)  # top
    lr_buf += struct.pack(">i", 0)  # left
    lr_buf += struct.pack(">i", height)  # bottom
    lr_buf += struct.pack(">i", width)  # right
    lr_buf += struct.pack(">H", channels)  # channel count

    # Channel info: R, G, B
    pixel_bytes = width * height  # 16 bytes per channel
    data_length = 2 + pixel_bytes  # compression (2) + raw data
    for ch_id in range(channels):
        lr_buf += struct.pack(">h", ch_id)  # channel ID
        lr_buf += struct.pack(">I", data_length)  # data length

    lr_buf += b"8BIM"  # blend signature
    lr_buf += b"norm"  # blend mode
    lr_buf += struct.pack("B", 255)  # opacity
    lr_buf += struct.pack("B", 0)  # clipping
    lr_buf += struct.pack("B", 0x02)  # flags (visible)
    lr_buf += b"\x00"  # filler

    # Extra data
    extra_buf = bytearray()
    extra_buf += struct.pack(">I", 0)  # Layer Mask Data length = 0
    extra_buf += struct.pack(">I", 0)  # Blending Ranges length = 0
    # Layer name: "Layer 0" as Pascal string, padded to 4-byte boundary
    name = b"Layer 0"
    extra_buf += struct.pack("B", len(name))
    extra_buf += name
    # Pad to 4-byte boundary: 1 + 7 = 8, already aligned
    # No additional layer info

    lr_buf += struct.pack(">I", len(extra_buf))  # extra data length
    lr_buf += extra_buf

    li_buf += lr_buf

    # Channel Image Data (per layer, per channel)
    for ch in range(channels):
        li_buf += struct.pack(">H", 0)  # compression = Raw
        if ch == 0:
            li_buf += b"\xFF" * pixel_bytes  # R = 255
        else:
            li_buf += b"\x00" * pixel_bytes  # G=0, B=0

    # Layer Info length (rounded to even)
    li_length = len(li_buf)
    if li_length % 2 != 0:
        li_buf += b"\x00"
        li_length += 1

    lm_buf += struct.pack(">I", li_length)
    lm_buf += li_buf

    # Global Layer Mask Info
    lm_buf += struct.pack(">I", 0)  # length = 0

    buf += struct.pack(">I", len(lm_buf))  # Section length
    buf += lm_buf

    # Image Data: Raw, merged (same as layer since single layer)
    buf += struct.pack(">H", 0)  # Compression = Raw
    buf += b"\xFF" * pixel_bytes  # R
    buf += b"\x00" * pixel_bytes  # G
    buf += b"\x00" * pixel_bytes  # B

    output = FIXTURES_DIR / "phase3_single_layer.psd"
    output.write_bytes(bytes(buf))
    print(f"Generated {output} ({len(buf)} bytes)")


def make_layer_record(top, left, bottom, right, channels, blend_mode, opacity, name, channel_data_lengths):
    """Generate a layer record with given parameters."""
    lr = bytearray()
    lr += struct.pack(">i", top)
    lr += struct.pack(">i", left)
    lr += struct.pack(">i", bottom)
    lr += struct.pack(">i", right)
    lr += struct.pack(">H", len(channels))

    for ch_id, data_length in zip(channels, channel_data_lengths):
        lr += struct.pack(">h", ch_id)
        lr += struct.pack(">I", data_length)

    lr += b"8BIM"
    lr += blend_mode
    lr += struct.pack("B", opacity)
    lr += struct.pack("B", 0)  # clipping
    lr += struct.pack("B", 0x02)  # flags (visible)
    lr += b"\x00"  # filler

    extra = bytearray()
    extra += struct.pack(">I", 0)  # mask data length
    extra += struct.pack(">I", 0)  # blending ranges length
    name_bytes = name.encode("ascii")
    extra += struct.pack("B", len(name_bytes))
    extra += name_bytes
    # Pad to 4-byte boundary
    pad = (4 - ((1 + len(name_bytes)) % 4)) % 4
    extra += b"\x00" * pad

    lr += struct.pack(">I", len(extra))
    lr += extra
    return lr


def make_rle_channel_data(raw_data, height):
    """Encode raw channel data as RLE with byte counts."""
    ch = bytearray()
    ch += struct.pack(">H", 1)  # compression = RLE
    width = len(raw_data) // height
    encoded_rows = []
    for row in range(height):
        row_data = raw_data[row * width : (row + 1) * width]
        encoded_rows.append(packbits_encode(row_data))
    # Write byte counts first
    for enc in encoded_rows:
        ch += struct.pack(">H", len(enc))
    # Write compressed data
    for enc in encoded_rows:
        ch += enc
    return bytes(ch)


def generate_phase4_multi_layer():
    """Generate 8x8 RGB with 2 layers: blue (norm) and red (multiply, 50% opacity), RLE channels."""
    width, height, channels = 8, 8, 3
    pixel_bytes = width * height  # 64

    buf = bytearray()
    buf += make_header(channels=channels, height=height, width=width)
    buf += struct.pack(">I", 0)  # Color Mode Data
    buf += struct.pack(">I", 0)  # Image Resources

    lm_buf = bytearray()
    li_buf = bytearray()
    li_buf += struct.pack(">h", 2)  # Layer count = 2

    # Layer 0: 8x8, normal, opacity=255, blue (R=0, G=0, B=255)
    ch_data_0 = []
    for ch_id in range(3):
        if ch_id == 2:
            raw = b"\xFF" * pixel_bytes
        else:
            raw = b"\x00" * pixel_bytes
        ch_data_0.append(make_rle_channel_data(raw, height))

    lr0 = make_layer_record(
        0, 0, height, width, [0, 1, 2], b"norm", 255, "Layer 0",
        [len(d) for d in ch_data_0],
    )
    li_buf += lr0

    # Layer 1: 4x4 at (2,2)-(6,6), multiply, opacity=128, red (R=255, G=0, B=0)
    l1_w, l1_h = 4, 4
    l1_pixels = l1_w * l1_h  # 16
    ch_data_1 = []
    for ch_id in range(3):
        if ch_id == 0:
            raw = b"\xFF" * l1_pixels
        else:
            raw = b"\x00" * l1_pixels
        ch_data_1.append(make_rle_channel_data(raw, l1_h))

    lr1 = make_layer_record(
        2, 2, 6, 6, [0, 1, 2], b"mul ", 128, "Layer 1",
        [len(d) for d in ch_data_1],
    )
    li_buf += lr1

    # Channel Image Data
    for d in ch_data_0:
        li_buf += d
    for d in ch_data_1:
        li_buf += d

    # Layer Info length (rounded to even)
    li_length = len(li_buf)
    if li_length % 2 != 0:
        li_buf += b"\x00"
        li_length += 1

    lm_buf += struct.pack(">I", li_length)
    lm_buf += li_buf
    lm_buf += struct.pack(">I", 0)  # Global Layer Mask Info

    buf += struct.pack(">I", len(lm_buf))
    buf += lm_buf

    # Merged Image Data: Raw, all black
    buf += struct.pack(">H", 0)  # Compression = Raw
    buf += b"\x00" * pixel_bytes * channels

    output = FIXTURES_DIR / "phase4_multi_layer.psd"
    output.write_bytes(bytes(buf))
    print(f"Generated {output} ({len(buf)} bytes)")


def generate_phase5_psb_minimal():
    """Generate minimal valid PSB (version 2): 1x1 RGB 8-bit, Raw compression."""
    buf = bytearray()
    buf += b"8BPS"
    buf += struct.pack(">H", 2)   # Version = 2 (PSB)
    buf += b"\x00" * 6            # Reserved
    buf += struct.pack(">H", 3)   # Channels = 3
    buf += struct.pack(">I", 1)   # Height = 1
    buf += struct.pack(">I", 1)   # Width = 1
    buf += struct.pack(">H", 8)   # Depth = 8
    buf += struct.pack(">H", 3)   # ColorMode = RGB
    buf += struct.pack(">I", 0)   # Color Mode Data length = 0
    buf += struct.pack(">I", 0)   # Image Resources length = 0
    buf += struct.pack(">Q", 0)   # Layer and Mask length = 0 (UInt64 for PSB)
    buf += struct.pack(">H", 0)   # Compression = Raw
    buf += b"\x00" * 3            # Pixel data (1px × 3ch)

    assert len(buf) == 47, f"Expected 47 bytes, got {len(buf)}"
    output = FIXTURES_DIR / "phase5_psb_minimal.psb"
    output.write_bytes(bytes(buf))
    print(f"Generated {output} ({len(buf)} bytes)")


def generate_phase7_resources():
    """Generate 1x1 RGB with multiple resource blocks: ResolutionInfo + GlobalAngle + XMP."""
    buf = bytearray()
    buf += make_header()
    buf += struct.pack(">I", 0)  # Color Mode Data

    # Image Resources section
    res_buf = bytearray()

    # Resource 1: ResolutionInfo (ID 1005, 16 bytes)
    res_buf += b"8BIM"
    res_buf += struct.pack(">H", 1005)
    res_buf += b"\x00\x00"  # empty Pascal string
    res_data = bytearray()
    res_data += struct.pack(">I", 0x00480000)  # hRes = 72.0
    res_data += struct.pack(">H", 1)  # hResUnit
    res_data += struct.pack(">H", 1)  # widthUnit
    res_data += struct.pack(">I", 0x00480000)  # vRes = 72.0
    res_data += struct.pack(">H", 1)  # vResUnit
    res_data += struct.pack(">H", 1)  # heightUnit
    res_buf += struct.pack(">I", len(res_data))
    res_buf += res_data

    # Resource 2: Global Angle (ID 1037, 4 bytes)
    res_buf += b"8BIM"
    res_buf += struct.pack(">H", 1037)
    res_buf += b"\x00\x00"  # empty Pascal string
    angle_data = struct.pack(">i", 120)
    res_buf += struct.pack(">I", len(angle_data))
    res_buf += angle_data

    # Resource 3: XMP Metadata (ID 1060, variable)
    res_buf += b"8BIM"
    res_buf += struct.pack(">H", 1060)
    res_buf += b"\x00\x00"  # empty Pascal string
    xmp_data = b'<?xml version="1.0"?><x:xmpmeta xmlns:x="adobe:ns:meta/"/>'
    res_buf += struct.pack(">I", len(xmp_data))
    res_buf += xmp_data
    # Pad if odd
    if len(xmp_data) % 2 != 0:
        res_buf += b"\x00"

    # Resource 4: Global Altitude (ID 1049, 4 bytes)
    res_buf += b"8BIM"
    res_buf += struct.pack(">H", 1049)
    res_buf += b"\x00\x00"
    alt_data = struct.pack(">i", 30)
    res_buf += struct.pack(">I", len(alt_data))
    res_buf += alt_data

    buf += struct.pack(">I", len(res_buf))
    buf += res_buf
    buf += struct.pack(">I", 0)  # Layer and Mask
    buf += struct.pack(">H", 0)  # Compression = Raw
    buf += b"\x00" * 3  # Pixel data

    output = FIXTURES_DIR / "phase7_resources.psd"
    output.write_bytes(bytes(buf))
    print(f"Generated {output} ({len(buf)} bytes)")


def make_ali_block(key: bytes, data: bytes) -> bytes:
    """Create an Additional Layer Info block with '8BIM' signature."""
    buf = bytearray()
    buf += b"8BIM"
    buf += key
    buf += struct.pack(">I", len(data))
    buf += data
    # Pad to even
    if len(data) % 2 != 0:
        buf += b"\x00"
    return bytes(buf)


def make_luni_data(name: str) -> bytes:
    """Create 'luni' Unicode layer name data."""
    encoded = name.encode("utf-16-be")
    char_count = len(encoded) // 2
    buf = bytearray()
    buf += struct.pack(">I", char_count)
    buf += encoded
    return bytes(buf)


def make_lsct_data(divider_type: int, blend_mode: bytes = None, sub_type: int = None) -> bytes:
    """Create 'lsct' section divider data."""
    buf = bytearray()
    buf += struct.pack(">I", divider_type)
    if blend_mode is not None:
        buf += b"8BIM"
        buf += blend_mode
    if sub_type is not None:
        buf += struct.pack(">I", sub_type)
    return bytes(buf)


def generate_phase6_layer_group():
    """Generate 8x8 RGB with layer group structure using ALI blocks.

    3 layers:
    - Layer 0: bounding section divider (lsct type=3, hidden)
    - Layer 1: normal layer with luni "Layer 1"
    - Layer 2: open folder (lsct type=1) named "Group 1"
    """
    width, height, channels = 8, 8, 3
    pixel_bytes = width * height  # 64

    buf = bytearray()
    buf += make_header(channels=channels, height=height, width=width)
    buf += struct.pack(">I", 0)  # Color Mode Data
    buf += struct.pack(">I", 0)  # Image Resources

    lm_buf = bytearray()
    li_buf = bytearray()
    li_buf += struct.pack(">h", 3)  # Layer count = 3

    # Layer 0: bounding section divider (0x0 rect, hidden)
    # ALI: lsct type=3
    lsct_end = make_ali_block(b"lsct", make_lsct_data(3, b"pass"))
    lr0_ali = lsct_end

    ch_data_0 = []
    for ch_id in range(channels):
        # Empty channel (0x0 rect)
        raw = b""
        ch_buf = struct.pack(">H", 0)  # compression = Raw
        ch_data_0.append(ch_buf)

    lr0 = make_layer_record(
        0, 0, 0, 0, [0, 1, 2], b"pass", 255, "</Group 1>",
        [len(d) for d in ch_data_0],
    )
    # We need to insert ALI data into the extra data section
    # The make_layer_record builds extra data with no ALI,
    # so we need a custom approach

    # Custom layer record builder that includes ALI data
    def build_layer_record_with_ali(top, left, bottom, right, ch_ids, blend_mode, opacity, name, channel_data_lengths, ali_data):
        lr = bytearray()
        lr += struct.pack(">i", top)
        lr += struct.pack(">i", left)
        lr += struct.pack(">i", bottom)
        lr += struct.pack(">i", right)
        lr += struct.pack(">H", len(ch_ids))
        for ch_id, dl in zip(ch_ids, channel_data_lengths):
            lr += struct.pack(">h", ch_id)
            lr += struct.pack(">I", dl)
        lr += b"8BIM"
        lr += blend_mode
        lr += struct.pack("B", opacity)
        lr += struct.pack("B", 0)  # clipping
        lr += struct.pack("B", 0x02)  # flags (visible)
        lr += b"\x00"  # filler

        extra = bytearray()
        extra += struct.pack(">I", 0)  # mask data length
        extra += struct.pack(">I", 0)  # blending ranges length
        name_bytes = name.encode("ascii")
        extra += struct.pack("B", len(name_bytes))
        extra += name_bytes
        pad = (4 - ((1 + len(name_bytes)) % 4)) % 4
        extra += b"\x00" * pad
        # Append ALI data
        extra += ali_data

        lr += struct.pack(">I", len(extra))
        lr += extra
        return bytes(lr)

    # Layer 0: bounding section divider
    lr0 = build_layer_record_with_ali(
        0, 0, 0, 0, [0, 1, 2], b"pass", 255, "</Group 1>",
        [len(d) for d in ch_data_0], lr0_ali,
    )
    li_buf += lr0

    # Layer 1: normal layer with luni
    luni_data = make_ali_block(b"luni", make_luni_data("Layer 1"))
    ch_data_1 = []
    for ch_id in range(channels):
        raw = b"\x80" * pixel_bytes
        ch_buf = struct.pack(">H", 0) + raw  # compression = Raw + data
        ch_data_1.append(ch_buf)

    lr1 = build_layer_record_with_ali(
        0, 0, height, width, [0, 1, 2], b"norm", 255, "Layer 1",
        [len(d) for d in ch_data_1], luni_data,
    )
    li_buf += lr1

    # Layer 2: open folder "Group 1"
    lsct_open = make_ali_block(b"lsct", make_lsct_data(1, b"pass"))
    ch_data_2 = []
    for ch_id in range(channels):
        ch_buf = struct.pack(">H", 0)  # compression = Raw, no data (0x0 rect)
        ch_data_2.append(ch_buf)

    lr2 = build_layer_record_with_ali(
        0, 0, 0, 0, [0, 1, 2], b"pass", 255, "Group 1",
        [len(d) for d in ch_data_2], lsct_open,
    )
    li_buf += lr2

    # Channel Image Data
    for d in ch_data_0:
        li_buf += d
    for d in ch_data_1:
        li_buf += d
    for d in ch_data_2:
        li_buf += d

    # Layer Info length (rounded to even)
    li_length = len(li_buf)
    if li_length % 2 != 0:
        li_buf += b"\x00"
        li_length += 1

    lm_buf += struct.pack(">I", li_length)
    lm_buf += li_buf
    lm_buf += struct.pack(">I", 0)  # Global Layer Mask Info

    buf += struct.pack(">I", len(lm_buf))
    buf += lm_buf

    # Merged Image Data: Raw, all gray
    buf += struct.pack(">H", 0)  # Compression = Raw
    buf += b"\x80" * pixel_bytes * channels

    output = FIXTURES_DIR / "phase6_layer_group.psd"
    output.write_bytes(bytes(buf))
    print(f"Generated {output} ({len(buf)} bytes)")


if __name__ == "__main__":
    generate_phase0_minimal()
    generate_phase1_rle()
    generate_phase2_resources()
    generate_phase3_single_layer()
    generate_phase4_multi_layer()
    generate_phase5_psb_minimal()
    generate_phase6_layer_group()
    generate_phase7_resources()
    print("All fixtures generated.")
