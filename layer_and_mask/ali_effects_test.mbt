///|
test "ALI legacy effects round-trip" {
  let effects : LegacyEffects = {
    version: 0,
    effects: [
      {
        signature: b"\x38\x42\x49\x4D",
        effect_type: b"cmnS",
        data: b"\x00\x00\x00\x07\x01\x00\x00",
      },
    ],
  }
  let ali = AdditionalLayerInfo::from_legacy_effects(effects)
  match ali.as_legacy_effects() {
    Some(parsed) => {
      inspect(parsed.version, content="0")
      inspect(parsed.effects.length(), content="1")
      inspect(parsed.effects[0].effect_type == b"cmnS", content="true")
      inspect(parsed.effects[0].data.length(), content="7")
    }
    None => panic()
  }
}

///|
test "ALI legacy effects empty" {
  let effects : LegacyEffects = { version: 0, effects: [] }
  let ali = AdditionalLayerInfo::from_legacy_effects(effects)
  match ali.as_legacy_effects() {
    Some(parsed) => {
      inspect(parsed.version, content="0")
      inspect(parsed.effects.length(), content="0")
    }
    None => panic()
  }
}

///|
test "ALI object effects round-trip" {
  let desc : @descriptor.Descriptor = {
    class_id_name: "",
    class_id: "null",
    items: [{ key: "enab", value: @descriptor.DescriptorValue::Boolean(true) }],
  }
  let ali = AdditionalLayerInfo::from_object_effects(0, desc)
  match ali.as_object_effects() {
    Some((ver, d)) => {
      inspect(ver, content="0")
      inspect(d.items.length(), content="1")
    }
    None => panic()
  }
}

///|
test "ALI filter mask round-trip" {
  let mask : FilterMask = {
    color_space: 0,
    color_components: [0, 0, 0, 0],
    opacity: 100,
  }
  let ali = AdditionalLayerInfo::from_filter_mask(mask)
  match ali.as_filter_mask() {
    Some(parsed) => {
      inspect(parsed.color_space, content="0")
      inspect(parsed.opacity, content="100")
      inspect(parsed.color_components[0], content="0")
    }
    None => panic()
  }
}

///|
test "ALI filter mask wrong key" {
  let ali : AdditionalLayerInfo = {
    signature: b"\x38\x42\x49\x4D",
    key: b"test",
    data: b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x64",
  }
  inspect(ali.as_filter_mask(), content="None")
}

///|
test "ALI type tool round-trip" {
  let desc : @descriptor.Descriptor = {
    class_id_name: "",
    class_id: "TxLr",
    items: [
      { key: "Txt ", value: @descriptor.DescriptorValue::String("Hello") },
    ],
  }
  let info : TypeToolInfo = {
    version: 1,
    transform: [1.0, 0.0, 0.0, 1.0, 100.0, 200.0],
    text_version: 50,
    descriptor_version: 16,
    text_data: desc,
  }
  let ali = AdditionalLayerInfo::from_type_tool(info)
  match ali.as_type_tool() {
    Some(parsed) => {
      inspect(parsed.version, content="1")
      inspect(parsed.transform.length(), content="6")
      inspect(
        parsed.transform[0] > 0.99 && parsed.transform[0] < 1.01,
        content="true",
      )
      inspect(
        parsed.transform[4] > 99.9 && parsed.transform[4] < 100.1,
        content="true",
      )
      inspect(parsed.text_version, content="50")
      inspect(parsed.descriptor_version, content="16")
      inspect(parsed.text_data.class_id, content="TxLr")
    }
    None => panic()
  }
}

///|
test "ALI vector mask round-trip" {
  let mask : VectorMask = {
    version: 3,
    flags: 0x03,
    path_records: b"\x00\x01\x02\x03\x04\x05\x06\x07",
  }
  let ali = AdditionalLayerInfo::from_vector_mask(b"vmsk", mask)
  match ali.as_vector_mask() {
    Some(parsed) => {
      inspect(parsed.version, content="3")
      inspect(parsed.flags, content="3")
      inspect(parsed.path_records.length(), content="8")
    }
    None => panic()
  }
}

///|
test "ALI metadata setting round-trip" {
  let item : MetadataItem = {
    signature: b"\x38\x42\x49\x4D",
    key: b"mlst",
    copy_on_sheet: true,
    data: b"\x00\x01\x02\x03",
  }
  let ali = AdditionalLayerInfo::from_metadata_setting([item])
  match ali.as_metadata_setting() {
    Some(items) => {
      inspect(items.length(), content="1")
      inspect(items[0].key == b"mlst", content="true")
      inspect(items[0].copy_on_sheet, content="true")
      inspect(items[0].data.length(), content="4")
    }
    None => panic()
  }
}

///|
test "ALI placed layer round-trip" {
  let desc : @descriptor.Descriptor = {
    class_id_name: "",
    class_id: "null",
    items: [],
  }
  let ali = AdditionalLayerInfo::from_placed_layer(b"SoLd", 4, desc)
  match ali.as_placed_layer() {
    Some((ver, _)) => inspect(ver, content="4")
    None => panic()
  }
}

///|
test "ALI vector origination round-trip" {
  let desc : @descriptor.Descriptor = {
    class_id_name: "",
    class_id: "null",
    items: [{ key: "enab", value: @descriptor.DescriptorValue::Boolean(true) }],
  }
  let ali = AdditionalLayerInfo::from_vector_origination(1, desc)
  match ali.as_vector_origination() {
    Some((ver, d)) => {
      inspect(ver, content="1")
      inspect(d.items.length(), content="1")
    }
    None => panic()
  }
}

///|
test "ALI adjustment descriptor round-trip" {
  let desc : @descriptor.Descriptor = {
    class_id_name: "",
    class_id: "null",
    items: [{ key: "Rd  ", value: @descriptor.DescriptorValue::Integer(50) }],
  }
  let ali = AdditionalLayerInfo::from_adjustment_descriptor(b"SoCo", 16, desc)
  match ali.as_adjustment_descriptor() {
    Some((ver, d)) => {
      inspect(ver, content="16")
      inspect(d.items.length(), content="1")
    }
    None => panic()
  }
}

///|
test "ALI adjustment key detection" {
  inspect(is_adjustment_key(b"SoCo"), content="true")
  inspect(is_adjustment_key(b"levl"), content="true")
  inspect(is_adjustment_key(b"curv"), content="true")
  inspect(is_adjustment_key(b"brit"), content="true")
  inspect(is_adjustment_key(b"test"), content="false")
  inspect(is_adjustment_key(b"luni"), content="false")
}
