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
