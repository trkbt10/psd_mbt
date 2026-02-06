///|
/// Smart Object Placed Layer (keys 'SoLd', 'SoLE') - Descriptor-based.
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
/// Vector Origination (key 'vogk') - version + Descriptor.
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

///|
/// Compositor Used (key 'cinf') - version(4) + Descriptor.
pub fn AdditionalLayerInfo::as_compositor_used(
  self : AdditionalLayerInfo,
) -> (Int, @descriptor.Descriptor)? {
  if self.key != b"cinf" || self.data.length() < 4 {
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
pub fn AdditionalLayerInfo::from_compositor_used(
  version : Int,
  desc : @descriptor.Descriptor,
) -> AdditionalLayerInfo {
  let w = @binary.Writer::new()
  w.write_u32_be(version.reinterpret_as_uint())
  desc.build(w)
  { signature: b"\x38\x42\x49\x4D", key: b"cinf", data: w.to_bytes() }
}

///|
/// Vector Stroke Data (key 'vstk') - version(4) + Descriptor.
pub fn AdditionalLayerInfo::as_vector_stroke_data(
  self : AdditionalLayerInfo,
) -> (Int, @descriptor.Descriptor)? {
  if self.key != b"vstk" || self.data.length() < 4 {
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
pub fn AdditionalLayerInfo::from_vector_stroke_data(
  version : Int,
  desc : @descriptor.Descriptor,
) -> AdditionalLayerInfo {
  let w = @binary.Writer::new()
  w.write_u32_be(version.reinterpret_as_uint())
  desc.build(w)
  { signature: b"\x38\x42\x49\x4D", key: b"vstk", data: w.to_bytes() }
}

///|
/// Vector Stroke Content (key 'vscg') - key(4) + version(4) + Descriptor.
pub fn AdditionalLayerInfo::as_vector_stroke_content(
  self : AdditionalLayerInfo,
) -> (Bytes, Int, @descriptor.Descriptor)? {
  if self.key != b"vscg" || self.data.length() < 8 {
    return None
  }
  let reader = @binary.Reader::new(self.data)
  try {
    let key = reader.read_bytes(4)
    let version = reader.read_u32_be().reinterpret_as_int()
    let desc = @descriptor.Descriptor::parse(reader)
    Some((key, version, desc))
  } catch {
    _ => None
  }
}

///|
pub fn AdditionalLayerInfo::from_vector_stroke_content(
  key : Bytes,
  version : Int,
  desc : @descriptor.Descriptor,
) -> AdditionalLayerInfo {
  let w = @binary.Writer::new()
  w.write_bytes(key)
  w.write_u32_be(version.reinterpret_as_uint())
  desc.build(w)
  { signature: b"\x38\x42\x49\x4D", key: b"vscg", data: w.to_bytes() }
}

///|
/// Vector Mask (keys 'vmsk', 'vsms') - version + flags + path records.
pub(all) struct VectorMask {
  version : Int
  flags : Int
  path_records : Bytes // Raw path record data (opaque)
} derive(Eq, Show)

///|
pub fn AdditionalLayerInfo::as_vector_mask(
  self : AdditionalLayerInfo,
) -> VectorMask? {
  if self.key != b"vmsk" && self.key != b"vsms" {
    return None
  }
  if self.data.length() < 8 {
    return None
  }
  let reader = @binary.Reader::new(self.data)
  try {
    let version = reader.read_u32_be().reinterpret_as_int()
    let flags = reader.read_u32_be().reinterpret_as_int()
    let remaining = reader.remaining()
    let path_records = if remaining > 0 {
      reader.read_bytes(remaining)
    } else {
      b""
    }
    Some({ version, flags, path_records })
  } catch {
    _ => None
  }
}

///|
pub fn AdditionalLayerInfo::from_vector_mask(
  key : Bytes,
  mask : VectorMask,
) -> AdditionalLayerInfo {
  let w = @binary.Writer::new()
  w.write_u32_be(mask.version.reinterpret_as_uint())
  w.write_u32_be(mask.flags.reinterpret_as_uint())
  if mask.path_records.length() > 0 {
    w.write_bytes(mask.path_records)
  }
  { signature: b"\x38\x42\x49\x4D", key, data: w.to_bytes() }
}

///|
/// Metadata Setting (key 'shmd') - Array of metadata items.
pub(all) struct MetadataItem {
  signature : Bytes // '8BIM'
  key : Bytes // 4-byte key
  copy_on_sheet : Bool
  data : Bytes
} derive(Eq, Show)

///|
pub fn AdditionalLayerInfo::as_metadata_setting(
  self : AdditionalLayerInfo,
) -> Array[MetadataItem]? {
  if self.key != b"shmd" || self.data.length() < 4 {
    return None
  }
  let reader = @binary.Reader::new(self.data)
  try {
    let count = reader.read_u32_be().reinterpret_as_int()
    let items : Array[MetadataItem] = []
    for _i = 0; _i < count; _i = _i + 1 {
      let sig = reader.read_bytes(4)
      let key = reader.read_bytes(4)
      let copy_on_sheet = reader.read_u8() != b'\x00'
      reader.skip(3) // padding
      let length = reader.read_u32_be().reinterpret_as_int()
      let data = if length > 0 { reader.read_bytes(length) } else { b"" }
      items.push({ signature: sig, key, copy_on_sheet, data })
    }
    Some(items)
  } catch {
    _ => None
  }
}

///|
pub fn AdditionalLayerInfo::from_metadata_setting(
  items : Array[MetadataItem],
) -> AdditionalLayerInfo {
  let w = @binary.Writer::new()
  w.write_u32_be(items.length().reinterpret_as_uint())
  for i = 0; i < items.length(); i = i + 1 {
    let item = items[i]
    w.write_bytes(item.signature)
    w.write_bytes(item.key)
    w.write_u8(if item.copy_on_sheet { b'\x01' } else { b'\x00' })
    w.write_zeros(3) // padding
    w.write_u32_be(item.data.length().reinterpret_as_uint())
    if item.data.length() > 0 {
      w.write_bytes(item.data)
    }
  }
  { signature: b"\x38\x42\x49\x4D", key: b"shmd", data: w.to_bytes() }
}

///|
/// Text Engine Data (key 'Txt2') - raw bytes of text engine data.
pub fn AdditionalLayerInfo::as_text_engine_data(
  self : AdditionalLayerInfo,
) -> Bytes? {
  if self.key != b"Txt2" {
    return None
  }
  Some(self.data)
}

///|
pub fn AdditionalLayerInfo::from_text_engine_data(
  data : Bytes,
) -> AdditionalLayerInfo {
  { signature: b"\x38\x42\x49\x4D", key: b"Txt2", data }
}

///|
/// Placed Layer - obsolete (key 'plLd') - complex struct + Descriptor.
/// type(4) + version(4) + unique_id (Pascal string) + page_number(4)
/// + total_pages(4) + anti_alias(4) + layer_type(4)
/// + transform(8 doubles) + warp descriptor.
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
/// Annotations (key 'Anno') - major_version(2) + minor_version(2) + count(4) + records.
/// Complex structure - exposed as opaque with version info.
pub(all) struct AnnotationsData {
  major_version : Int
  minor_version : Int
  count : Int
  data : Bytes // Raw annotation records
} derive(Eq, Show)

///|
pub fn AdditionalLayerInfo::as_annotations(
  self : AdditionalLayerInfo,
) -> AnnotationsData? {
  if self.key != b"Anno" || self.data.length() < 8 {
    return None
  }
  let reader = @binary.Reader::new(self.data)
  try {
    let major_version = reader.read_u16_be().reinterpret_as_int()
    let minor_version = reader.read_u16_be().reinterpret_as_int()
    let count = reader.read_u32_be().reinterpret_as_int()
    let remaining = reader.remaining()
    let data = if remaining > 0 { reader.read_bytes(remaining) } else { b"" }
    Some({ major_version, minor_version, count, data })
  } catch {
    _ => None
  }
}

///|
pub fn AdditionalLayerInfo::from_annotations(
  info : AnnotationsData,
) -> AdditionalLayerInfo {
  let w = @binary.Writer::new()
  w.write_u16_be(info.major_version.reinterpret_as_uint())
  w.write_u16_be(info.minor_version.reinterpret_as_uint())
  w.write_u32_be(info.count.reinterpret_as_uint())
  if info.data.length() > 0 {
    w.write_bytes(info.data)
  }
  { signature: b"\x38\x42\x49\x4D", key: b"Anno", data: w.to_bytes() }
}

///|
/// Gradient Map (key 'grdm') - complex structure.
/// Exposed as version + raw data for round-trip.
pub(all) struct GradientMapData {
  version : Int
  data : Bytes // Raw gradient data after version
} derive(Eq, Show)

///|
pub fn AdditionalLayerInfo::as_gradient_map(
  self : AdditionalLayerInfo,
) -> GradientMapData? {
  if self.key != b"grdm" || self.data.length() < 2 {
    return None
  }
  let reader = @binary.Reader::new(self.data)
  try {
    let version = reader.read_u16_be().reinterpret_as_int()
    let remaining = reader.remaining()
    let data = if remaining > 0 { reader.read_bytes(remaining) } else { b"" }
    Some({ version, data })
  } catch {
    _ => None
  }
}

///|
pub fn AdditionalLayerInfo::from_gradient_map(
  info : GradientMapData,
) -> AdditionalLayerInfo {
  let w = @binary.Writer::new()
  w.write_u16_be(info.version.reinterpret_as_uint())
  if info.data.length() > 0 {
    w.write_bytes(info.data)
  }
  { signature: b"\x38\x42\x49\x4D", key: b"grdm", data: w.to_bytes() }
}
