///|
test "Slices descriptor round-trip" {
  let desc : @descriptor.Descriptor = {
    class_id_name: "",
    class_id: "null",
    items: [
      { key: "Nm  ", value: @descriptor.DescriptorValue::String("Slice") },
    ],
  }
  let block = ImageResourceBlock::from_slices_descriptor(7, desc)
  inspect(block.resource_id, content="1050")
  match block.as_slices_descriptor() {
    Some((ver, d)) => {
      inspect(ver, content="7")
      inspect(d.items.length(), content="1")
    }
    None => panic()
  }
}

///|
test "LayerComps descriptor round-trip" {
  let desc : @descriptor.Descriptor = {
    class_id_name: "",
    class_id: "null",
    items: [{ key: "enab", value: @descriptor.DescriptorValue::Boolean(true) }],
  }
  let block = ImageResourceBlock::from_layer_comps(1, desc)
  inspect(block.resource_id, content="1065")
  match block.as_layer_comps() {
    Some((ver, d)) => {
      inspect(ver, content="1")
      inspect(d.items.length(), content="1")
    }
    None => panic()
  }
}

///|
test "TimelineInfo descriptor round-trip" {
  let desc : @descriptor.Descriptor = {
    class_id_name: "",
    class_id: "null",
    items: [],
  }
  let block = ImageResourceBlock::from_timeline_info(1, desc)
  inspect(block.resource_id, content="1075")
  match block.as_timeline_info() {
    Some((ver, _)) => inspect(ver, content="1")
    None => panic()
  }
}

///|
test "SheetDisclosure descriptor round-trip" {
  let desc : @descriptor.Descriptor = {
    class_id_name: "",
    class_id: "null",
    items: [],
  }
  let block = ImageResourceBlock::from_sheet_disclosure(1, desc)
  inspect(block.resource_id, content="1076")
  match block.as_sheet_disclosure() {
    Some((ver, _)) => inspect(ver, content="1")
    None => panic()
  }
}

///|
test "PixelSourceData descriptor round-trip" {
  let desc : @descriptor.Descriptor = {
    class_id_name: "",
    class_id: "null",
    items: [],
  }
  let block = ImageResourceBlock::from_pixel_source_data(1, desc)
  inspect(block.resource_id, content="1077")
  match block.as_pixel_source_data() {
    Some((ver, _)) => inspect(ver, content="1")
    None => panic()
  }
}

///|
test "DisplayInfo descriptor round-trip" {
  let desc : @descriptor.Descriptor = {
    class_id_name: "",
    class_id: "null",
    items: [],
  }
  let block = ImageResourceBlock::from_display_info(3, desc)
  inspect(block.resource_id, content="1078")
  match block.as_display_info() {
    Some((ver, _)) => inspect(ver, content="3")
    None => panic()
  }
}

///|
test "ColorSamplers descriptor round-trip" {
  let desc : @descriptor.Descriptor = {
    class_id_name: "",
    class_id: "null",
    items: [],
  }
  let block = ImageResourceBlock::from_color_samplers(3, desc)
  inspect(block.resource_id, content="1080")
  match block.as_color_samplers() {
    Some((ver, _)) => inspect(ver, content="3")
    None => panic()
  }
}

///|
test "Generic as_descriptor accessor" {
  let desc : @descriptor.Descriptor = {
    class_id_name: "",
    class_id: "null",
    items: [{ key: "test", value: @descriptor.DescriptorValue::Integer(42) }],
  }
  let block = ImageResourceBlock::from_measurement_scale(1, desc)
  match block.as_descriptor() {
    Some((ver, d)) => {
      inspect(ver, content="1")
      inspect(d.items.length(), content="1")
    }
    None => panic()
  }
}
