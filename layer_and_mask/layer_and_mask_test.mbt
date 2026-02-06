///|
test "LayerAndMaskInfo parse/build empty" {
  // section_length = 0
  let data = b"\x00\x00\x00\x00"
  let reader = @binary.Reader::new(data)
  let lm = LayerAndMaskInfo::parse(reader, @types.PsdVersion::Psd)
  inspect(lm.layer_info is None, content="true")
  inspect(lm.global_mask is None, content="true")
  // Build and compare
  let writer = @binary.Writer::new()
  lm.build(writer, @types.PsdVersion::Psd)
  inspect(writer.to_bytes() == data, content="true")
}

///|
test "LayerAndMaskInfo parse/build with layer info and global mask" {
  // Build a complete layer+mask section from scratch, then parse and round-trip
  let writer = @binary.Writer::new()
  let lm : LayerAndMaskInfo = {
    layer_info: Some({
      layer_count: 1,
      layers: [
        {
          rect: { top: 0, left: 0, bottom: 4, right: 4 },
          channels: [
            { channel_id: 0, data_length: 18 },
            { channel_id: 1, data_length: 18 },
            { channel_id: 2, data_length: 18 },
          ],
          blend_mode: @types.BlendMode::Normal,
          opacity: 255,
          clipping: 0,
          flags: 2,
          mask_data: b"",
          blending_ranges: b"",
          name: "Layer 0",
          additional_info: [],
        },
      ],
      channel_data: [
        [
          {
            compression: @types.Compression::Raw,
            data: Bytes::makei(16, fn(_i) { b'\xFF' }),
          },
          {
            compression: @types.Compression::Raw,
            data: Bytes::makei(16, fn(_i) { b'\x00' }),
          },
          {
            compression: @types.Compression::Raw,
            data: Bytes::makei(16, fn(_i) { b'\x00' }),
          },
        ],
      ],
    }),
    global_mask: None,
    additional_info: [],
  }
  lm.build(writer, @types.PsdVersion::Psd)
  let built = writer.to_bytes()
  // Parse it back
  let reader = @binary.Reader::new(built)
  let parsed = LayerAndMaskInfo::parse(reader, @types.PsdVersion::Psd)
  inspect(parsed.layer_info is Some(_), content="true")
  match parsed.layer_info {
    Some(li) => {
      inspect(li.layer_count, content="1")
      inspect(li.layers.length(), content="1")
      inspect(li.layers[0].name, content="Layer 0")
      inspect(li.layers[0].blend_mode, content="Normal")
      inspect(li.layers[0].opacity, content="255")
      inspect(li.layers[0].rect.top, content="0")
      inspect(li.layers[0].rect.bottom, content="4")
      inspect(li.layers[0].channels.length(), content="3")
      inspect(li.channel_data.length(), content="1")
      inspect(li.channel_data[0].length(), content="3")
      // First channel (R) should be all 0xFF
      inspect(li.channel_data[0][0].compression, content="Raw")
      inspect(li.channel_data[0][0].data.length(), content="16")
      inspect(li.channel_data[0][0].data[0], content="b'\\xFF'")
    }
    None => panic()
  }
  // Round-trip: rebuild and compare
  let writer2 = @binary.Writer::new()
  parsed.build(writer2, @types.PsdVersion::Psd)
  inspect(writer2.to_bytes() == built, content="true")
}

///|
test "GlobalLayerMaskInfo parse/build empty" {
  let data = b"\x00\x00\x00\x00"
  let reader = @binary.Reader::new(data)
  let gm = GlobalLayerMaskInfo::parse(reader)
  inspect(gm.data.length(), content="0")
  let writer = @binary.Writer::new()
  gm.build(writer)
  inspect(writer.to_bytes() == data, content="true")
}

///|
test "AdditionalLayerInfo parse/build round-trip" {
  // Build a simple ALI block: signature='8BIM', key='lsct', data=4 bytes (type=1)
  let w = @binary.Writer::new()
  let ali : AdditionalLayerInfo = {
    signature: b"\x38\x42\x49\x4D",
    key: b"lsct",
    data: b"\x00\x00\x00\x01",
  }
  ali.build(w, @types.PsdVersion::Psd)
  let built = w.to_bytes()
  // 4 (sig) + 4 (key) + 4 (length) + 4 (data) = 16 bytes
  inspect(built.length(), content="16")
  // Parse back
  let r = @binary.Reader::new(built)
  let parsed = AdditionalLayerInfo::parse(r, @types.PsdVersion::Psd)
  inspect(parsed.key == b"lsct", content="true")
  inspect(parsed.data.length(), content="4")
  inspect(parsed.data == b"\x00\x00\x00\x01", content="true")
}

///|
test "AdditionalLayerInfo odd data padding" {
  // Data of 3 bytes (odd) should get 1 byte padding
  let w = @binary.Writer::new()
  let ali : AdditionalLayerInfo = {
    signature: b"\x38\x42\x49\x4D",
    key: b"test",
    data: b"\x01\x02\x03",
  }
  ali.build(w, @types.PsdVersion::Psd)
  let built = w.to_bytes()
  // 4 + 4 + 4 + 3 + 1(padding) = 16
  inspect(built.length(), content="16")
  let r = @binary.Reader::new(built)
  let parsed = AdditionalLayerInfo::parse(r, @types.PsdVersion::Psd)
  inspect(parsed.data.length(), content="3")
  inspect(r.remaining(), content="0")
}

///|
test "AdditionalLayerInfo as_section_divider lsct" {
  let ali : AdditionalLayerInfo = {
    signature: b"\x38\x42\x49\x4D",
    key: b"lsct",
    data: b"\x00\x00\x00\x01",
  }
  match ali.as_section_divider() {
    Some(sd) => {
      inspect(sd.divider_type, content="1")
      inspect(sd.blend_mode, content="None")
      inspect(sd.sub_type, content="None")
    }
    None => panic()
  }
}

///|
test "AdditionalLayerInfo as_section_divider with blend mode" {
  // lsct with 12 bytes: type + signature + blend_mode
  let w = @binary.Writer::new()
  w.write_u32_be(3U) // type=3 (bounding section divider)
  w.write_bytes(b"\x38\x42\x49\x4D") // '8BIM'
  w.write_bytes(b"pass") // pass blend mode
  let ali : AdditionalLayerInfo = {
    signature: b"\x38\x42\x49\x4D",
    key: b"lsct",
    data: w.to_bytes(),
  }
  match ali.as_section_divider() {
    Some(sd) => {
      inspect(sd.divider_type, content="3")
      inspect(sd.blend_mode, content="Some(PassThrough)")
      inspect(sd.sub_type, content="None")
    }
    None => panic()
  }
}

///|
test "AdditionalLayerInfo as_unicode_name" {
  // luni: 4 bytes char count + UTF-16BE data
  let w = @binary.Writer::new()
  w.write_u32_be(5U) // 5 characters: "Hello"
  // UTF-16BE for "Hello"
  w.write_u16_be(0x0048U) // H
  w.write_u16_be(0x0065U) // e
  w.write_u16_be(0x006CU) // l
  w.write_u16_be(0x006CU) // l
  w.write_u16_be(0x006FU) // o
  let ali : AdditionalLayerInfo = {
    signature: b"\x38\x42\x49\x4D",
    key: b"luni",
    data: w.to_bytes(),
  }
  inspect(ali.as_unicode_name(), content="Some(\"Hello\")")
}

///|
test "AdditionalLayerInfo wrong key returns None" {
  let ali : AdditionalLayerInfo = {
    signature: b"\x38\x42\x49\x4D",
    key: b"norm",
    data: b"\x00\x00\x00\x01",
  }
  inspect(ali.as_section_divider(), content="None")
  inspect(ali.as_unicode_name(), content="None")
}

///|
test "BlendMode from_bytes/to_bytes round-trip" {
  inspect(@types.BlendMode::from_bytes(b"norm"), content="Normal")
  inspect(@types.BlendMode::from_bytes(b"mul "), content="Multiply")
  inspect(@types.BlendMode::Normal.to_bytes() == b"norm", content="true")
  inspect(@types.BlendMode::Multiply.to_bytes() == b"mul ", content="true")
}
