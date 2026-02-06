///|
test "LayerRecord flag: transparency protected" {
  let layer = make_test_layer(0x01) // bit 0 set
  inspect(layer.is_transparency_protected(), content="true")
  inspect(layer.is_visible(), content="false")
  inspect(layer.is_obsolete(), content="false")
  inspect(layer.has_useful_info(), content="false")
  inspect(layer.is_pixel_irrelevant(), content="false")
}

///|
test "LayerRecord flag: visible" {
  let layer = make_test_layer(0x02) // bit 1 set
  inspect(layer.is_transparency_protected(), content="false")
  inspect(layer.is_visible(), content="true")
}

///|
test "LayerRecord flag: obsolete" {
  let layer = make_test_layer(0x04) // bit 2 set
  inspect(layer.is_obsolete(), content="true")
}

///|
test "LayerRecord flag: has useful info (PS5+)" {
  let layer = make_test_layer(0x08) // bit 3 set
  inspect(layer.has_useful_info(), content="true")
}

///|
test "LayerRecord flag: pixel irrelevant" {
  let layer = make_test_layer(0x10) // bit 4 set
  inspect(layer.is_pixel_irrelevant(), content="true")
}

///|
test "LayerRecord flag: combined flags" {
  let layer = make_test_layer(0x1B) // bits 0,1,3,4 set (0x01|0x02|0x08|0x10)
  inspect(layer.is_transparency_protected(), content="true")
  inspect(layer.is_visible(), content="true")
  inspect(layer.is_obsolete(), content="false")
  inspect(layer.has_useful_info(), content="true")
  inspect(layer.is_pixel_irrelevant(), content="true")
}

///|
test "LayerRecord flag: no flags" {
  let layer = make_test_layer(0x00)
  inspect(layer.is_transparency_protected(), content="false")
  inspect(layer.is_visible(), content="false")
  inspect(layer.is_obsolete(), content="false")
  inspect(layer.has_useful_info(), content="false")
  inspect(layer.is_pixel_irrelevant(), content="false")
}

///|
test "ChannelInfo: is_transparency" {
  let ch : ChannelInfo = { channel_id: -1, data_length: 100 }
  inspect(ch.is_transparency(), content="true")
  inspect(ch.is_user_mask(), content="false")
  inspect(ch.is_real_mask(), content="false")
}

///|
test "ChannelInfo: is_user_mask" {
  let ch : ChannelInfo = { channel_id: -2, data_length: 100 }
  inspect(ch.is_transparency(), content="false")
  inspect(ch.is_user_mask(), content="true")
  inspect(ch.is_real_mask(), content="false")
}

///|
test "ChannelInfo: is_real_mask" {
  let ch : ChannelInfo = { channel_id: -3, data_length: 100 }
  inspect(ch.is_transparency(), content="false")
  inspect(ch.is_user_mask(), content="false")
  inspect(ch.is_real_mask(), content="true")
}

///|
test "ChannelInfo: regular channel (id=0)" {
  let ch : ChannelInfo = { channel_id: 0, data_length: 100 }
  inspect(ch.is_transparency(), content="false")
  inspect(ch.is_user_mask(), content="false")
  inspect(ch.is_real_mask(), content="false")
}

///|
test "LayerInfo: has_merged_transparency" {
  let info : LayerInfo = { layer_count: -2, layers: [], channel_data: [] }
  inspect(info.has_merged_transparency(), content="true")
  inspect(info.actual_layer_count(), content="2")
}

///|
test "LayerInfo: positive layer count" {
  let info : LayerInfo = { layer_count: 3, layers: [], channel_data: [] }
  inspect(info.has_merged_transparency(), content="false")
  inspect(info.actual_layer_count(), content="3")
}

///|
test "LayerBlendingRanges: parse and build round-trip" {
  // Composite gray (4 bytes) + 2 channels (8 bytes) = 12 bytes
  let data = b"\x00\x40\x80\xFF\x10\x20\x30\x40\xA0\xB0\xC0\xD0"
  match LayerBlendingRanges::parse(data) {
    Some(ranges) => {
      inspect(ranges.composite_gray.length(), content="4")
      inspect(ranges.channels.length(), content="2")
      let rebuilt = ranges.build()
      inspect(rebuilt == data, content="true")
    }
    None => panic()
  }
}

///|
test "LayerBlendingRanges: empty data" {
  inspect(LayerBlendingRanges::parse(b""), content="None")
}

///|
test "LayerBlendingRanges: too short" {
  inspect(LayerBlendingRanges::parse(b"\x00\x01"), content="None")
}

///|
test "LayerBlendingRanges: composite only (no channels)" {
  let data = b"\x00\x40\x80\xFF"
  match LayerBlendingRanges::parse(data) {
    Some(ranges) => {
      inspect(ranges.composite_gray.length(), content="4")
      inspect(ranges.channels.length(), content="0")
    }
    None => panic()
  }
}

///|
test "GlobalLayerMaskInfo: typed fields round-trip" {
  let fields : GlobalMaskFields = {
    overlay_color_space: 0,
    color_components: [65535, 0, 0, 0],
    opacity: 100,
    kind: 0,
  }
  let gm = GlobalLayerMaskInfo::from_fields(fields)
  match gm.as_fields() {
    Some(parsed) => {
      inspect(parsed.overlay_color_space, content="0")
      inspect(parsed.color_components.length(), content="4")
      inspect(parsed.color_components[0], content="65535")
      inspect(parsed.opacity, content="100")
      inspect(parsed.kind, content="0")
    }
    None => panic()
  }
}

///|
test "GlobalLayerMaskInfo: kind values" {
  // kind=0: color selected, kind=1: color protected, kind=128: use value
  let fields0 : GlobalMaskFields = {
    overlay_color_space: 0,
    color_components: [0, 0, 0, 0],
    opacity: 50,
    kind: 0,
  }
  let fields1 : GlobalMaskFields = {
    overlay_color_space: 0,
    color_components: [0, 0, 0, 0],
    opacity: 50,
    kind: 1,
  }
  let fields128 : GlobalMaskFields = {
    overlay_color_space: 0,
    color_components: [0, 0, 0, 0],
    opacity: 50,
    kind: 128,
  }
  let gm0 = GlobalLayerMaskInfo::from_fields(fields0)
  let gm1 = GlobalLayerMaskInfo::from_fields(fields1)
  let gm128 = GlobalLayerMaskInfo::from_fields(fields128)
  match gm0.as_fields() {
    Some(f) => inspect(f.kind, content="0")
    None => panic()
  }
  match gm1.as_fields() {
    Some(f) => inspect(f.kind, content="1")
    None => panic()
  }
  match gm128.as_fields() {
    Some(f) => inspect(f.kind, content="128")
    None => panic()
  }
}

///|
test "GlobalLayerMaskInfo: empty data returns None" {
  let gm : GlobalLayerMaskInfo = { data: b"" }
  inspect(gm.as_fields(), content="None")
}

///|
/// Helper to create a minimal LayerRecord with given flags for testing.
fn make_test_layer(flags : Int) -> LayerRecord {
  {
    rect: { top: 0, left: 0, bottom: 10, right: 10 },
    channels: [],
    blend_mode: @types.Normal,
    opacity: 255,
    clipping: 0,
    flags,
    name: "test",
    mask_data: b"",
    blending_ranges: b"",
    additional_info: [],
  }
}
