// Additional Layer Information: Mask-related keys
//
// PSD File Format Specification, "Additional Layer Information" section:
//   "(**PSB**, the following keys have a length count of 8 bytes:
//    LMsk, Lr16, Lr32, Layr, Mt16, Mt32, Mtrn, Alph, FMsk, lnk2, FEid, FXid, PxSD."

///|
/// Vector Mask setting (keys 'vmsk', 'vsms').
///
/// Spec: "Key is 'vmsk' or 'vsms'. Data is as follows:"
///   | Length | Description                                                 |
///   |--------|-------------------------------------------------------------|
///   | 4      | Version (= 3 for Photoshop 6.0)                            |
///   | 4      | Flags. bit 1 = invert, bit 2 = not link, bit 3 = disable   |
///   | var    | Path records (see "Path resource format")                   |
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
/// User Mask (key 'LMsk').
///
/// Spec: "Key is 'LMsk'."
///   | Length | Description     |
///   |--------|-----------------|
///   | 10     | Color space     |
///   | 2      | Opacity         |
///   | 1      | Flag ( = 128 )  |
///
/// Note: PSB uses 8-byte length field for this key.
pub(all) struct UserMask {
  color_space : Int // 2 bytes color space ID
  color_components : Array[Int] // 4x UInt16
  opacity : Int // UInt16
  flag : Int // 1 byte (should be 128)
} derive(Eq, Show)

///|
pub fn AdditionalLayerInfo::as_user_mask(
  self : AdditionalLayerInfo,
) -> UserMask? {
  if self.key != b"LMsk" || self.data.length() < 13 {
    return None
  }
  let reader = @binary.Reader::new(self.data)
  try {
    let color_space = reader.read_u16_be().reinterpret_as_int()
    let c0 = reader.read_u16_be().reinterpret_as_int()
    let c1 = reader.read_u16_be().reinterpret_as_int()
    let c2 = reader.read_u16_be().reinterpret_as_int()
    let c3 = reader.read_u16_be().reinterpret_as_int()
    let opacity = reader.read_u16_be().reinterpret_as_int()
    let flag = reader.read_u8().to_int()
    Some({ color_space, color_components: [c0, c1, c2, c3], opacity, flag })
  } catch {
    _ => None
  }
}

///|
pub fn AdditionalLayerInfo::from_user_mask(
  mask : UserMask,
) -> AdditionalLayerInfo {
  let w = @binary.Writer::new()
  w.write_u16_be(mask.color_space.reinterpret_as_uint())
  for i = 0; i < 4; i = i + 1 {
    let v = if i < mask.color_components.length() {
      mask.color_components[i]
    } else {
      0
    }
    w.write_u16_be(v.reinterpret_as_uint())
  }
  w.write_u16_be(mask.opacity.reinterpret_as_uint())
  w.write_u8(mask.flag.to_byte())
  { signature: b"\x38\x42\x49\x4D", key: b"LMsk", data: w.to_bytes() }
}

///|
/// Filter Mask (key 'FMsk').
///
/// Spec: "Key is 'FMsk'. Data is as follows:"
///   | Length | Description      |
///   |--------|------------------|
///   | 2      | Color space      |
///   | 8      | Color components |
///   | 2      | Opacity          |
///
/// Note: PSB uses 8-byte length field for this key.
pub(all) struct FilterMask {
  color_space : Int
  color_components : Array[Int] // 4x UInt16
  opacity : Int
} derive(Eq, Show)

///|
pub fn AdditionalLayerInfo::as_filter_mask(
  self : AdditionalLayerInfo,
) -> FilterMask? {
  if self.key != b"FMsk" || self.data.length() < 12 {
    return None
  }
  let reader = @binary.Reader::new(self.data)
  try {
    let color_space = reader.read_u16_be().reinterpret_as_int()
    let c0 = reader.read_u16_be().reinterpret_as_int()
    let c1 = reader.read_u16_be().reinterpret_as_int()
    let c2 = reader.read_u16_be().reinterpret_as_int()
    let c3 = reader.read_u16_be().reinterpret_as_int()
    let opacity = reader.read_u16_be().reinterpret_as_int()
    Some({ color_space, color_components: [c0, c1, c2, c3], opacity })
  } catch {
    _ => None
  }
}

///|
pub fn AdditionalLayerInfo::from_filter_mask(
  mask : FilterMask,
) -> AdditionalLayerInfo {
  let w = @binary.Writer::new()
  w.write_u16_be(mask.color_space.reinterpret_as_uint())
  for i = 0; i < 4; i = i + 1 {
    let v = if i < mask.color_components.length() {
      mask.color_components[i]
    } else {
      0
    }
    w.write_u16_be(v.reinterpret_as_uint())
  }
  w.write_u16_be(mask.opacity.reinterpret_as_uint())
  { signature: b"\x38\x42\x49\x4D", key: b"FMsk", data: w.to_bytes() }
}
