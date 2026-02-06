///|
test "LayerMaskData parse 20-byte variant" {
  // Build 20 bytes: rect(16) + default_color(1) + flags(1) + padding(2)
  let w = @binary.Writer::new()
  // Rect: top=10, left=20, bottom=100, right=200
  w.write_i32_be(10)
  w.write_i32_be(20)
  w.write_i32_be(100)
  w.write_i32_be(200)
  w.write_u8(b'\xFF') // default_color = 255
  w.write_u8(b'\x03') // flags = 3 (position_relative + disabled)
  w.write_u8(b'\x00') // padding
  w.write_u8(b'\x00')
  let data = w.to_bytes()
  match LayerMaskData::parse(data) {
    Some(mask) => {
      inspect(mask.rect.top, content="10")
      inspect(mask.rect.left, content="20")
      inspect(mask.rect.bottom, content="100")
      inspect(mask.rect.right, content="200")
      inspect(mask.default_color, content="255")
      inspect(mask.flags, content="3")
      inspect(mask.real_flags, content="None")
      inspect(mask.real_rect, content="None")
      inspect(mask.is_position_relative(), content="true")
      inspect(mask.is_disabled(), content="true")
      inspect(mask.is_invert_on_blend(), content="false")
    }
    None => panic()
  }
}

///|
test "LayerMaskData parse 36-byte variant" {
  let w = @binary.Writer::new()
  // Primary rect
  w.write_i32_be(0)
  w.write_i32_be(0)
  w.write_i32_be(50)
  w.write_i32_be(50)
  w.write_u8(b'\x00') // default_color = 0
  w.write_u8(b'\x01') // flags = 1
  // Extended: real_flags + real_background + real_rect
  w.write_u8(b'\x02') // real_flags
  w.write_u8(b'\xFF') // real_background
  w.write_i32_be(5)
  w.write_i32_be(5)
  w.write_i32_be(45)
  w.write_i32_be(45)
  let data = w.to_bytes()
  match LayerMaskData::parse(data) {
    Some(mask) => {
      inspect(mask.rect.top, content="0")
      inspect(mask.rect.bottom, content="50")
      inspect(mask.real_flags, content="Some(2)")
      inspect(mask.real_background, content="Some(255)")
      match mask.real_rect {
        Some(rr) => {
          inspect(rr.top, content="5")
          inspect(rr.bottom, content="45")
        }
        None => panic()
      }
    }
    None => panic()
  }
}

///|
test "LayerMaskData build round-trip 20-byte" {
  let mask : LayerMaskData = {
    rect: { top: 10, left: 20, bottom: 100, right: 200 },
    default_color: 0,
    flags: 2,
    real_flags: None,
    real_background: None,
    real_rect: None,
  }
  let built = mask.build()
  let parsed = LayerMaskData::parse(built)
  match parsed {
    Some(m) => {
      inspect(m.rect.top, content="10")
      inspect(m.default_color, content="0")
      inspect(m.flags, content="2")
    }
    None => panic()
  }
}

///|
test "LayerMaskData build round-trip 36-byte" {
  let mask : LayerMaskData = {
    rect: { top: 0, left: 0, bottom: 64, right: 64 },
    default_color: 255,
    flags: 1,
    real_flags: Some(3),
    real_background: Some(0),
    real_rect: Some({ top: 2, left: 2, bottom: 62, right: 62 }),
  }
  let built = mask.build()
  let parsed = LayerMaskData::parse(built)
  match parsed {
    Some(m) => {
      inspect(m.rect.bottom, content="64")
      inspect(m.real_flags, content="Some(3)")
      inspect(m.real_background, content="Some(0)")
      match m.real_rect {
        Some(rr) => inspect(rr.bottom, content="62")
        None => panic()
      }
    }
    None => panic()
  }
}

///|
test "LayerMaskData parse empty" {
  inspect(LayerMaskData::parse(b""), content="None")
}

///|
test "LayerMaskData flag accessors" {
  let mask : LayerMaskData = {
    rect: { top: 0, left: 0, bottom: 0, right: 0 },
    default_color: 0,
    flags: 0x1F, // all 5 bits set
    real_flags: None,
    real_background: None,
    real_rect: None,
  }
  inspect(mask.is_position_relative(), content="true")
  inspect(mask.is_disabled(), content="true")
  inspect(mask.is_invert_on_blend(), content="true")
  inspect(mask.is_from_render(), content="true")
  inspect(mask.has_parameters(), content="true")
}

///|
test "LayerBlendingRanges parse/build round-trip" {
  let w = @binary.Writer::new()
  // Composite gray: 4 bytes
  w.write_bytes(b"\x00\xFF\x00\xFF")
  // 2 channels, each 4 bytes
  w.write_bytes(b"\x10\xF0\x10\xF0")
  w.write_bytes(b"\x20\xE0\x20\xE0")
  let data = w.to_bytes()
  match LayerBlendingRanges::parse(data) {
    Some(br) => {
      inspect(br.composite_gray.length(), content="4")
      inspect(br.channels.length(), content="2")
      inspect(br.channels[0].length(), content="4")
      // Build and compare
      let built = br.build()
      inspect(built == data, content="true")
    }
    None => panic()
  }
}

///|
test "LayerBlendingRanges parse empty" {
  inspect(LayerBlendingRanges::parse(b""), content="None")
}

///|
test "GlobalLayerMaskInfo as_fields round-trip" {
  let fields : GlobalMaskFields = {
    overlay_color_space: 0,
    color_components: [65535, 0, 0, 0],
    opacity: 100,
    kind: 0,
  }
  let gm = GlobalLayerMaskInfo::from_fields(fields)
  match gm.as_fields() {
    Some(f) => {
      inspect(f.overlay_color_space, content="0")
      inspect(f.color_components[0], content="65535")
      inspect(f.color_components[1], content="0")
      inspect(f.opacity, content="100")
      inspect(f.kind, content="0")
    }
    None => panic()
  }
}

///|
test "GlobalLayerMaskInfo as_fields empty data" {
  let gm : GlobalLayerMaskInfo = { data: b"" }
  inspect(gm.as_fields(), content="None")
}

///|
test "LayerRecord flag accessors" {
  let record : LayerRecord = {
    rect: { top: 0, left: 0, bottom: 4, right: 4 },
    channels: [],
    blend_mode: @types.BlendMode::Normal,
    opacity: 255,
    clipping: 0,
    flags: 0x0A, // visible + has_useful_info
    mask_data: b"",
    blending_ranges: b"",
    name: "test",
    additional_info: [],
  }
  inspect(record.is_transparency_protected(), content="false")
  inspect(record.is_visible(), content="true")
  inspect(record.is_obsolete(), content="false")
  inspect(record.has_useful_info(), content="true")
  inspect(record.is_pixel_irrelevant(), content="false")
}

///|
test "LayerRecord as_mask_data and as_blending_ranges" {
  let w = @binary.Writer::new()
  w.write_i32_be(0)
  w.write_i32_be(0)
  w.write_i32_be(10)
  w.write_i32_be(10)
  w.write_u8(b'\x00')
  w.write_u8(b'\x02')
  w.write_u16_be(0U) // padding to make 20 bytes
  let mask_bytes = w.to_bytes()
  let record : LayerRecord = {
    rect: { top: 0, left: 0, bottom: 10, right: 10 },
    channels: [],
    blend_mode: @types.BlendMode::Normal,
    opacity: 255,
    clipping: 0,
    flags: 2,
    mask_data: mask_bytes,
    blending_ranges: b"\x00\xFF\x00\xFF\x10\xF0\x10\xF0",
    name: "test",
    additional_info: [],
  }
  match record.as_mask_data() {
    Some(md) => {
      inspect(md.rect.bottom, content="10")
      inspect(md.flags, content="2")
    }
    None => panic()
  }
  match record.as_blending_ranges() {
    Some(br) => {
      inspect(br.composite_gray.length(), content="4")
      inspect(br.channels.length(), content="1")
    }
    None => panic()
  }
}
