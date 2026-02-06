// Image Resources: Descriptor-based resources
//
// PSD File Format Specification, "Image Resources" section.
// These resources store a version(4) followed by a Descriptor structure.

///|
/// Parse a Descriptor-based image resource.
/// Many modern PSD resources store a version(4) followed by a Descriptor.
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
/// Slices (ID 1050).
///
/// Spec: "0x041A (Photoshop 6.0)"
///   "Slices. See See Slices resource format."
///   For version 7-8 (Photoshop CS2+), data is version(4) + Descriptor.
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
/// Layer Comps (ID 1065).
///
/// Spec: "0x0429 (Photoshop CS)"
///   "Layer Comps. 4 bytes (descriptor version = 16),
///    Descriptor (see See Descriptor structure)."
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
/// Timeline Info (ID 1075).
///
/// Spec: "0x0433 (Photoshop CS3)"
///   "Timeline Information. 4 bytes (descriptor version = 16),
///    Descriptor (see See Descriptor structure)."
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
/// Sheet Disclosure (ID 1076).
///
/// Spec: "0x0434 (Photoshop CS3)"
///   "Sheet Disclosure. 4 bytes (descriptor version = 16),
///    Descriptor (see See Descriptor structure)."
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
/// Pixel Source Data #2 (ID 1077).
///
/// Spec: "0x0435 (Photoshop CS3)"
///   "DisplayInfo structure to support floating point colors. Also
///    see ID 1007. See Appendix A in Photoshop API Guide.pdf."
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
/// Display Info (ID 1078).
///
/// Spec: "0x0436 (Photoshop CS3)"
///   "Onion Skins. 4 bytes (descriptor version = 16),
///    Descriptor (see See Descriptor structure)."
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
/// Color Samplers Resource (ID 1080).
///
/// Spec: "0x0438 (Photoshop CS3)"
///   "Color Samplers Resource. Also see ID 1038 for old format.
///    See See Color samplers resource format."
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
/// Measurement Scale (ID 1082).
///
/// Spec: "0x043A (Photoshop CS3)"
///   "Measurement Scale. 4 bytes (descriptor version = 16),
///    Descriptor (see See Descriptor structure)."
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
/// Timeline (ID 1083).
///
/// Spec: "0x043B (Photoshop CS3)"
///   "Timeline. 4 bytes (descriptor version = 16),
///    Descriptor (see See Descriptor structure)."
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
/// Count Information (ID 1088).
///
/// Spec: "0x0440 (Photoshop CS4)"
///   "Count Information. 4 bytes (descriptor version = 16),
///    Descriptor (see See Descriptor structure)."
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
