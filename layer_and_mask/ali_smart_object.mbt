// Additional Layer Information: Smart Object / Placed Layer keys
//
// PSD File Format Specification, "Additional Layer Information" section.

///|
/// Smart Object Placed Layer (keys 'SoLd', 'SoLE').
///
/// Spec: "Placed Layer (replaced by SoLd in Photoshop CS3)"
///   "Key is 'SoLd'. Also 'SoLE' for exterior data."
///   | Length | Description                  |
///   |--------|------------------------------|
///   | 4      | Identifier ('soLD')          |
///   | 4      | Version (= 4 for PS CS3)     |
///   | var    | Descriptor (smart object)    |
pub fn AdditionalLayerInfo::as_placed_layer(
  self : AdditionalLayerInfo,
) -> (Int, @descriptor.Descriptor)? {
  if self.key != b"SoLd" && self.key != b"SoLE" {
    return None
  }
  if self.data.length() < 8 {
    return None
  }
  let reader = @binary.Reader::new(self.data)
  try {
    // Read identifier string (4 bytes like 'soLD')
    let _id = reader.read_bytes(4)
    let version = reader.read_u32_be().reinterpret_as_int()
    let desc = @descriptor.Descriptor::parse(reader)
    Some((version, desc))
  } catch {
    _ => None
  }
}

///|
pub fn AdditionalLayerInfo::from_placed_layer(
  key : Bytes,
  version : Int,
  desc : @descriptor.Descriptor,
) -> AdditionalLayerInfo {
  let w = @binary.Writer::new()
  w.write_bytes(b"soLD") // identifier
  w.write_u32_be(version.reinterpret_as_uint())
  desc.build(w)
  { signature: b"\x38\x42\x49\x4D", key, data: w.to_bytes() }
}

///|
/// Placed Layer - obsolete (key 'plLd').
///
/// Spec: "Placed Layer (Photoshop CS). Key is 'plLd'."
///   | Length | Description                                          |
///   |--------|------------------------------------------------------|
///   | 4      | Type ('plcL')                                        |
///   | 4      | Version                                              |
///   | var    | Unique ID (Pascal string)                            |
///   | 4      | Page number                                          |
///   | 4      | Total pages                                          |
///   | 4      | Anti alias policy                                    |
///   | 4      | Placed layer type (0=unknown, 1=vector, 2=raster, 3=image stack) |
///   | 64     | Transform (8 doubles: xx, xy, yx, yy, tx, ty, w, h)  |
///   | 4      | Warp version                                         |
///   | 4      | Warp descriptor version                              |
///   | var    | Warp descriptor                                      |
pub(all) struct PlacedLayerData {
  place_type : Bytes // 'plcL'
  version : Int
  unique_id : String
  page_number : Int
  total_pages : Int
  anti_alias_policy : Int
  layer_type : Int // 0=unknown, 1=vector, 2=raster, 3=image stack
  transform : Array[Double] // 8 doubles
  warp_version : Int
  warp_descriptor_version : Int
  warp_descriptor : @descriptor.Descriptor
} derive(Eq, Show)

///|
pub fn AdditionalLayerInfo::as_placed_layer_obsolete(
  self : AdditionalLayerInfo,
) -> PlacedLayerData? {
  if self.key != b"plLd" || self.data.length() < 88 {
    return None
  }
  let reader = @binary.Reader::new(self.data)
  try {
    let place_type = reader.read_bytes(4)
    let version = reader.read_u32_be().reinterpret_as_int()
    // Pascal string for unique ID
    let id_len = reader.read_u8().to_int()
    let id_bytes = if id_len > 0 { reader.read_bytes(id_len) } else { b"" }
    let id_buf = @buffer.new(size_hint=id_len)
    for i = 0; i < id_bytes.length(); i = i + 1 {
      id_buf.write_char(id_bytes[i].to_int().unsafe_to_char())
    }
    let unique_id = id_buf.to_string()
    let page_number = reader.read_u32_be().reinterpret_as_int()
    let total_pages = reader.read_u32_be().reinterpret_as_int()
    let anti_alias_policy = reader.read_u32_be().reinterpret_as_int()
    let layer_type = reader.read_u32_be().reinterpret_as_int()
    // 8 doubles for transform
    let transform : Array[Double] = []
    for _i = 0; _i < 8; _i = _i + 1 {
      let bits = reader.read_u64_be()
      transform.push(bits.reinterpret_as_double())
    }
    let warp_version = reader.read_u32_be().reinterpret_as_int()
    let warp_descriptor_version = reader.read_u32_be().reinterpret_as_int()
    let warp_descriptor = @descriptor.Descriptor::parse(reader)
    Some({
      place_type,
      version,
      unique_id,
      page_number,
      total_pages,
      anti_alias_policy,
      layer_type,
      transform,
      warp_version,
      warp_descriptor_version,
      warp_descriptor,
    })
  } catch {
    _ => None
  }
}

///|
pub fn AdditionalLayerInfo::from_placed_layer_obsolete(
  info : PlacedLayerData,
) -> AdditionalLayerInfo {
  let w = @binary.Writer::new()
  w.write_bytes(info.place_type)
  w.write_u32_be(info.version.reinterpret_as_uint())
  // Pascal string
  w.write_u8(info.unique_id.length().to_byte())
  for i = 0; i < info.unique_id.length(); i = i + 1 {
    w.write_u8(info.unique_id[i].to_int().to_byte())
  }
  w.write_u32_be(info.page_number.reinterpret_as_uint())
  w.write_u32_be(info.total_pages.reinterpret_as_uint())
  w.write_u32_be(info.anti_alias_policy.reinterpret_as_uint())
  w.write_u32_be(info.layer_type.reinterpret_as_uint())
  for i = 0; i < 8; i = i + 1 {
    let v = if i < info.transform.length() { info.transform[i] } else { 0.0 }
    w.write_u64_be(v.reinterpret_as_uint64())
  }
  w.write_u32_be(info.warp_version.reinterpret_as_uint())
  w.write_u32_be(info.warp_descriptor_version.reinterpret_as_uint())
  info.warp_descriptor.build(w)
  { signature: b"\x38\x42\x49\x4D", key: b"plLd", data: w.to_bytes() }
}

///|
/// Vector Origination Data (key 'vogk').
///
/// Spec: "Key is 'vogk'. (Photoshop CC)"
///   | Length | Description           |
///   |--------|-----------------------|
///   | 4      | Version (= 1)         |
///   | var    | Descriptor            |
pub fn AdditionalLayerInfo::as_vector_origination(
  self : AdditionalLayerInfo,
) -> (Int, @descriptor.Descriptor)? {
  if self.key != b"vogk" || self.data.length() < 8 {
    return None
  }
  let reader = @binary.Reader::new(self.data)
  try {
    let version = reader.read_u32_be().reinterpret_as_int()
    let desc = @descriptor.Descriptor::parse(reader)
    Some((version, desc))
  } catch {
    _ => None
  }
}

///|
pub fn AdditionalLayerInfo::from_vector_origination(
  version : Int,
  desc : @descriptor.Descriptor,
) -> AdditionalLayerInfo {
  let w = @binary.Writer::new()
  w.write_u32_be(version.reinterpret_as_uint())
  desc.build(w)
  { signature: b"\x38\x42\x49\x4D", key: b"vogk", data: w.to_bytes() }
}
