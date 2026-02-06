///|
test "ALI as_layer_id round-trip" {
  let ali = AdditionalLayerInfo::from_layer_id(42)
  inspect(ali.as_layer_id(), content="Some(42)")
}

///|
test "ALI as_blend_clipping round-trip" {
  let ali = AdditionalLayerInfo::from_blend_clipping(true)
  inspect(ali.as_blend_clipping(), content="Some(true)")
  let ali2 = AdditionalLayerInfo::from_blend_clipping(false)
  inspect(ali2.as_blend_clipping(), content="Some(false)")
}

///|
test "ALI as_interior_blend round-trip" {
  let ali = AdditionalLayerInfo::from_interior_blend(true)
  inspect(ali.as_interior_blend(), content="Some(true)")
}

///|
test "ALI as_knockout round-trip" {
  let ali = AdditionalLayerInfo::from_knockout(true)
  inspect(ali.as_knockout(), content="Some(true)")
  let ali2 = AdditionalLayerInfo::from_knockout(false)
  inspect(ali2.as_knockout(), content="Some(false)")
}

///|
test "ALI as_protection_settings round-trip" {
  let ali = AdditionalLayerInfo::from_protection_settings(7)
  inspect(ali.as_protection_settings(), content="Some(7)")
}

///|
test "ALI as_sheet_color round-trip" {
  let ali = AdditionalLayerInfo::from_sheet_color([1, 0, 0, 0])
  match ali.as_sheet_color() {
    Some(c) => {
      inspect(c.length(), content="4")
      inspect(c[0], content="1")
      inspect(c[1], content="0")
    }
    None => panic()
  }
}

///|
test "ALI as_reference_point round-trip" {
  let ali = AdditionalLayerInfo::from_reference_point(100.5, 200.25)
  match ali.as_reference_point() {
    Some(pt) => {
      inspect(pt.0, content="100.5")
      inspect(pt.1, content="200.25")
    }
    None => panic()
  }
}

///|
test "ALI as_layer_name_source round-trip" {
  let ali = AdditionalLayerInfo::from_layer_name_source(b"lnam")
  match ali.as_layer_name_source() {
    Some(src) => inspect(src == b"lnam", content="true")
    None => panic()
  }
}

///|
test "ALI as_layer_version round-trip" {
  let ali = AdditionalLayerInfo::from_layer_version(70)
  inspect(ali.as_layer_version(), content="Some(70)")
}

///|
test "ALI as_transparency_shapes_layer round-trip" {
  let ali = AdditionalLayerInfo::from_transparency_shapes_layer(true)
  inspect(ali.as_transparency_shapes_layer(), content="Some(true)")
}

///|
test "ALI as_fill_opacity round-trip" {
  let ali = AdditionalLayerInfo::from_fill_opacity(128)
  inspect(ali.as_fill_opacity(), content="Some(128)")
}

///|
test "ALI wrong key returns None" {
  let ali : AdditionalLayerInfo = {
    signature: b"\x38\x42\x49\x4D",
    key: b"test",
    data: b"\x00\x00\x00\x01",
  }
  inspect(ali.as_layer_id(), content="None")
  inspect(ali.as_blend_clipping(), content="None")
  inspect(ali.as_knockout(), content="None")
  inspect(ali.as_fill_opacity(), content="None")
}
