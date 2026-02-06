///|
/// Parse a Descriptor-based image resource.
/// Many modern PSD resources (Slices, LayerComps, etc.) store a version(4)
/// followed by a Descriptor.
fn parse_versioned_descriptor(data : Bytes) -> (Int, @descriptor.Descriptor)? {
  if data.length() < 8 {
    return None
  }
  let reader = @binary.Reader::new(data)
  try {
    let version = reader.read_u32_be().reinterpret_as_int()
    let desc = @descriptor.Descriptor::parse(reader)
    Some((version, desc))
  } catch {
    _ => None
  }
}

///|
/// Build a versioned descriptor resource.
fn build_versioned_descriptor(
  version : Int,
  desc : @descriptor.Descriptor,
) -> Bytes {
  let w = @binary.Writer::new()
  w.write_u32_be(version.reinterpret_as_uint())
  desc.build(w)
  w.to_bytes()
}

///|
/// Slices (ID 1050) - version 7-8 uses Descriptor.
/// For version >= 6, returns (version, Descriptor).
pub fn ImageResourceBlock::as_slices_descriptor(
  self : ImageResourceBlock,
) -> (Int, @descriptor.Descriptor)? {
  if self.resource_id != 1050 {
    return None
  }
  parse_versioned_descriptor(self.data)
}

///|
pub fn ImageResourceBlock::from_slices_descriptor(
  version : Int,
  desc : @descriptor.Descriptor,
) -> ImageResourceBlock {
  {
    resource_id: 1050,
    name: "",
    data: build_versioned_descriptor(version, desc),
  }
}

///|
/// LayerComps (ID 1065) - Descriptor.
pub fn ImageResourceBlock::as_layer_comps(
  self : ImageResourceBlock,
) -> (Int, @descriptor.Descriptor)? {
  if self.resource_id != 1065 {
    return None
  }
  parse_versioned_descriptor(self.data)
}

///|
pub fn ImageResourceBlock::from_layer_comps(
  version : Int,
  desc : @descriptor.Descriptor,
) -> ImageResourceBlock {
  {
    resource_id: 1065,
    name: "",
    data: build_versioned_descriptor(version, desc),
  }
}

///|
/// TimelineInfo (ID 1075) - Descriptor.
pub fn ImageResourceBlock::as_timeline_info(
  self : ImageResourceBlock,
) -> (Int, @descriptor.Descriptor)? {
  if self.resource_id != 1075 {
    return None
  }
  parse_versioned_descriptor(self.data)
}

///|
pub fn ImageResourceBlock::from_timeline_info(
  version : Int,
  desc : @descriptor.Descriptor,
) -> ImageResourceBlock {
  {
    resource_id: 1075,
    name: "",
    data: build_versioned_descriptor(version, desc),
  }
}

///|
/// SheetDisclosure (ID 1076) - Descriptor.
pub fn ImageResourceBlock::as_sheet_disclosure(
  self : ImageResourceBlock,
) -> (Int, @descriptor.Descriptor)? {
  if self.resource_id != 1076 {
    return None
  }
  parse_versioned_descriptor(self.data)
}

///|
pub fn ImageResourceBlock::from_sheet_disclosure(
  version : Int,
  desc : @descriptor.Descriptor,
) -> ImageResourceBlock {
  {
    resource_id: 1076,
    name: "",
    data: build_versioned_descriptor(version, desc),
  }
}

///|
/// PixelSourceData2 (ID 1077) - Descriptor.
pub fn ImageResourceBlock::as_pixel_source_data(
  self : ImageResourceBlock,
) -> (Int, @descriptor.Descriptor)? {
  if self.resource_id != 1077 {
    return None
  }
  parse_versioned_descriptor(self.data)
}

///|
pub fn ImageResourceBlock::from_pixel_source_data(
  version : Int,
  desc : @descriptor.Descriptor,
) -> ImageResourceBlock {
  {
    resource_id: 1077,
    name: "",
    data: build_versioned_descriptor(version, desc),
  }
}

///|
/// DisplayInfo (ID 1078) - Descriptor (PS7+).
pub fn ImageResourceBlock::as_display_info(
  self : ImageResourceBlock,
) -> (Int, @descriptor.Descriptor)? {
  if self.resource_id != 1078 {
    return None
  }
  parse_versioned_descriptor(self.data)
}

///|
pub fn ImageResourceBlock::from_display_info(
  version : Int,
  desc : @descriptor.Descriptor,
) -> ImageResourceBlock {
  {
    resource_id: 1078,
    name: "",
    data: build_versioned_descriptor(version, desc),
  }
}

///|
/// ColorSamplers (ID 1080) - Descriptor (PS CS3+).
pub fn ImageResourceBlock::as_color_samplers(
  self : ImageResourceBlock,
) -> (Int, @descriptor.Descriptor)? {
  if self.resource_id != 1080 {
    return None
  }
  parse_versioned_descriptor(self.data)
}

///|
pub fn ImageResourceBlock::from_color_samplers(
  version : Int,
  desc : @descriptor.Descriptor,
) -> ImageResourceBlock {
  {
    resource_id: 1080,
    name: "",
    data: build_versioned_descriptor(version, desc),
  }
}

///|
/// MeasurementScale (ID 1082) - Descriptor.
pub fn ImageResourceBlock::as_measurement_scale(
  self : ImageResourceBlock,
) -> (Int, @descriptor.Descriptor)? {
  if self.resource_id != 1082 {
    return None
  }
  parse_versioned_descriptor(self.data)
}

///|
pub fn ImageResourceBlock::from_measurement_scale(
  version : Int,
  desc : @descriptor.Descriptor,
) -> ImageResourceBlock {
  {
    resource_id: 1082,
    name: "",
    data: build_versioned_descriptor(version, desc),
  }
}

///|
/// Timeline (ID 1083) - Descriptor.
pub fn ImageResourceBlock::as_timeline(
  self : ImageResourceBlock,
) -> (Int, @descriptor.Descriptor)? {
  if self.resource_id != 1083 {
    return None
  }
  parse_versioned_descriptor(self.data)
}

///|
pub fn ImageResourceBlock::from_timeline(
  version : Int,
  desc : @descriptor.Descriptor,
) -> ImageResourceBlock {
  {
    resource_id: 1083,
    name: "",
    data: build_versioned_descriptor(version, desc),
  }
}

///|
/// CountInfo (ID 1088) - Descriptor.
pub fn ImageResourceBlock::as_count_info(
  self : ImageResourceBlock,
) -> (Int, @descriptor.Descriptor)? {
  if self.resource_id != 1088 {
    return None
  }
  parse_versioned_descriptor(self.data)
}

///|
pub fn ImageResourceBlock::from_count_info(
  version : Int,
  desc : @descriptor.Descriptor,
) -> ImageResourceBlock {
  {
    resource_id: 1088,
    name: "",
    data: build_versioned_descriptor(version, desc),
  }
}

///|
/// Generic descriptor resource accessor for any ID.
/// Parses data as version(4) + Descriptor.
pub fn ImageResourceBlock::as_descriptor(
  self : ImageResourceBlock,
) -> (Int, @descriptor.Descriptor)? {
  parse_versioned_descriptor(self.data)
}
