// Additional Layer Information: Simple property accessors
//
// PSD File Format Specification, "Additional Layer Information" section.
// These are simple fixed-size or boolean-typed keys.

///|
/// Layer ID (key 'lyid').
///
/// Spec: "Key is 'lyid'. (Photoshop 5.0)"
///   | Length | Description           |
///   |--------|-------------------------------|
///   | 4      | ID                            |
pub fn AdditionalLayerInfo::as_layer_id(self : AdditionalLayerInfo) -> Int? {
  if self.key != b"lyid" || self.data.length() < 4 {
    return None
  }
  let reader = @binary.Reader::new(self.data)
  Some(reader.read_u32_be().reinterpret_as_int()) catch {
    _ => None
  }
}

///|
pub fn AdditionalLayerInfo::from_layer_id(id : Int) -> AdditionalLayerInfo {
  let w = @binary.Writer::new()
  w.write_u32_be(id.reinterpret_as_uint())
  { signature: b"\x38\x42\x49\x4D", key: b"lyid", data: w.to_bytes() }
}

///|
/// Blend Clipping Elements (key 'clbl').
///
/// Spec: "Key is 'clbl'. (Photoshop 6.0)"
///   | Length | Description                                |
///   |--------|--------------------------------------------|
///   | 1      | Blend clipped elements (boolean)            |
///   | 3      | Padding                                    |
pub fn AdditionalLayerInfo::as_blend_clipping(
  self : AdditionalLayerInfo,
) -> Bool? {
  if self.key != b"clbl" || self.data.length() < 1 {
    return None
  }
  Some(self.data[0] != b'\x00')
}

///|
pub fn AdditionalLayerInfo::from_blend_clipping(
  value : Bool,
) -> AdditionalLayerInfo {
  let data = Bytes::from_array([
    if value {
      b'\x01'
    } else {
      b'\x00'
    },
    b'\x00',
    b'\x00',
    b'\x00',
  ])
  { signature: b"\x38\x42\x49\x4D", key: b"clbl", data }
}

///|
/// Blend Interior Elements (key 'infx').
///
/// Spec: "Key is 'infx'. (Photoshop 6.0)"
///   | Length | Description                                 |
///   |--------|---------------------------------------------|
///   | 1      | Blend interior elements (boolean)            |
///   | 3      | Padding                                     |
pub fn AdditionalLayerInfo::as_interior_blend(
  self : AdditionalLayerInfo,
) -> Bool? {
  if self.key != b"infx" || self.data.length() < 1 {
    return None
  }
  Some(self.data[0] != b'\x00')
}

///|
pub fn AdditionalLayerInfo::from_interior_blend(
  value : Bool,
) -> AdditionalLayerInfo {
  let data = Bytes::from_array([
    if value {
      b'\x01'
    } else {
      b'\x00'
    },
    b'\x00',
    b'\x00',
    b'\x00',
  ])
  { signature: b"\x38\x42\x49\x4D", key: b"infx", data }
}

///|
/// Knockout Setting (key 'knko').
///
/// Spec: "Key is 'knko'. (Photoshop 6.0)"
///   | Length | Description       |
///   |--------|-------------------|
///   | 1      | Knockout (boolean) |
///   | 3      | Padding           |
pub fn AdditionalLayerInfo::as_knockout(self : AdditionalLayerInfo) -> Bool? {
  if self.key != b"knko" || self.data.length() < 1 {
    return None
  }
  Some(self.data[0] != b'\x00')
}

///|
pub fn AdditionalLayerInfo::from_knockout(value : Bool) -> AdditionalLayerInfo {
  let data = Bytes::from_array([
    if value {
      b'\x01'
    } else {
      b'\x00'
    },
    b'\x00',
    b'\x00',
    b'\x00',
  ])
  { signature: b"\x38\x42\x49\x4D", key: b"knko", data }
}

///|
/// Protected Setting (key 'lspf').
///
/// Spec: "Key is 'lspf'. (Photoshop 6.0)"
///   | Length | Description                                                |
///   |--------|--------------------------------------------------------------|
///   | 4      | Protection flags (bit 0 = transparency, bit 1 = composite, bit 2 = position) |
pub fn AdditionalLayerInfo::as_protection_settings(
  self : AdditionalLayerInfo,
) -> Int? {
  if self.key != b"lspf" || self.data.length() < 4 {
    return None
  }
  let reader = @binary.Reader::new(self.data)
  Some(reader.read_u32_be().reinterpret_as_int()) catch {
    _ => None
  }
}

///|
pub fn AdditionalLayerInfo::from_protection_settings(
  flags : Int,
) -> AdditionalLayerInfo {
  let w = @binary.Writer::new()
  w.write_u32_be(flags.reinterpret_as_uint())
  { signature: b"\x38\x42\x49\x4D", key: b"lspf", data: w.to_bytes() }
}

///|
/// Sheet Color Setting (key 'lclr').
///
/// Spec: "Key is 'lclr'. (Photoshop 6.0)"
///   | Length | Description      |
///   |--------|------------------|
///   | 8      | Color (4 x 2 byte values) |
pub fn AdditionalLayerInfo::as_sheet_color(
  self : AdditionalLayerInfo,
) -> Array[Int]? {
  if self.key != b"lclr" || self.data.length() < 8 {
    return None
  }
  let reader = @binary.Reader::new(self.data)
  try {
    let c0 = reader.read_u16_be().reinterpret_as_int()
    let c1 = reader.read_u16_be().reinterpret_as_int()
    let c2 = reader.read_u16_be().reinterpret_as_int()
    let c3 = reader.read_u16_be().reinterpret_as_int()
    Some([c0, c1, c2, c3])
  } catch {
    _ => None
  }
}

///|
pub fn AdditionalLayerInfo::from_sheet_color(
  color : Array[Int],
) -> AdditionalLayerInfo {
  let w = @binary.Writer::new()
  for i = 0; i < 4; i = i + 1 {
    let v = if i < color.length() { color[i] } else { 0 }
    w.write_u16_be(v.reinterpret_as_uint())
  }
  { signature: b"\x38\x42\x49\x4D", key: b"lclr", data: w.to_bytes() }
}

///|
/// Reference Point (key 'fxrp').
///
/// Spec: "Key is 'fxrp'. (Photoshop 6.0)"
///   | Length | Description       |
///   |--------|-------------------|
///   | 16     | 2 double values for the reference point |
pub fn AdditionalLayerInfo::as_reference_point(
  self : AdditionalLayerInfo,
) -> (Double, Double)? {
  if self.key != b"fxrp" || self.data.length() < 16 {
    return None
  }
  let reader = @binary.Reader::new(self.data)
  try {
    let x_bits = reader.read_u64_be()
    let y_bits = reader.read_u64_be()
    Some((x_bits.reinterpret_as_double(), y_bits.reinterpret_as_double()))
  } catch {
    _ => None
  }
}

///|
pub fn AdditionalLayerInfo::from_reference_point(
  x : Double,
  y : Double,
) -> AdditionalLayerInfo {
  let w = @binary.Writer::new()
  w.write_u64_be(x.reinterpret_as_uint64())
  w.write_u64_be(y.reinterpret_as_uint64())
  { signature: b"\x38\x42\x49\x4D", key: b"fxrp", data: w.to_bytes() }
}

///|
/// Layer Name Source Setting (key 'lnsr').
///
/// Spec: "Key is 'lnsr'. (Photoshop 6.0)"
///   | Length | Description |
///   |--------|-------------|
///   | 4      | ID for the layer name source |
pub fn AdditionalLayerInfo::as_layer_name_source(
  self : AdditionalLayerInfo,
) -> Bytes? {
  if self.key != b"lnsr" || self.data.length() < 4 {
    return None
  }
  let reader = @binary.Reader::new(self.data)
  Some(reader.read_bytes(4)) catch {
    _ => None
  }
}

///|
pub fn AdditionalLayerInfo::from_layer_name_source(
  source_id : Bytes,
) -> AdditionalLayerInfo {
  { signature: b"\x38\x42\x49\x4D", key: b"lnsr", data: source_id }
}

///|
/// Layer Version (key 'lyvr').
///
/// Spec: "Key is 'lyvr'. (Photoshop 7.0)"
///   | Length | Description                   |
///   |--------|-------------------------------|
///   | 4      | Version (= 70 for Photoshop 7.0) |
pub fn AdditionalLayerInfo::as_layer_version(
  self : AdditionalLayerInfo,
) -> Int? {
  if self.key != b"lyvr" || self.data.length() < 4 {
    return None
  }
  let reader = @binary.Reader::new(self.data)
  Some(reader.read_u32_be().reinterpret_as_int()) catch {
    _ => None
  }
}

///|
pub fn AdditionalLayerInfo::from_layer_version(
  version : Int,
) -> AdditionalLayerInfo {
  let w = @binary.Writer::new()
  w.write_u32_be(version.reinterpret_as_uint())
  { signature: b"\x38\x42\x49\x4D", key: b"lyvr", data: w.to_bytes() }
}

///|
/// Transparency Shapes Layer (key 'tsly').
///
/// Spec: "Key is 'tsly'. (Photoshop 7.0)"
///   | Length | Description                           |
///   |--------|---------------------------------------|
///   | 1      | Transparency shapes layer (boolean)    |
///   | 3      | Padding                               |
pub fn AdditionalLayerInfo::as_transparency_shapes_layer(
  self : AdditionalLayerInfo,
) -> Bool? {
  if self.key != b"tsly" || self.data.length() < 1 {
    return None
  }
  Some(self.data[0] != b'\x00')
}

///|
pub fn AdditionalLayerInfo::from_transparency_shapes_layer(
  value : Bool,
) -> AdditionalLayerInfo {
  let data = Bytes::from_array([
    if value {
      b'\x01'
    } else {
      b'\x00'
    },
    b'\x00',
    b'\x00',
    b'\x00',
  ])
  { signature: b"\x38\x42\x49\x4D", key: b"tsly", data }
}

///|
/// Fill Opacity (key 'iOpa').
///
/// Spec: "Key is 'iOpa'. (Photoshop 7.0)"
///   | Length | Description                |
///   |--------|----------------------------|
///   | 1      | Fill Opacity (0..255)       |
pub fn AdditionalLayerInfo::as_fill_opacity(self : AdditionalLayerInfo) -> Int? {
  if self.key != b"iOpa" || self.data.length() < 1 {
    return None
  }
  Some(self.data[0].to_int())
}

///|
pub fn AdditionalLayerInfo::from_fill_opacity(
  opacity : Int,
) -> AdditionalLayerInfo {
  let data = Bytes::from_array([opacity.to_byte(), b'\x00', b'\x00', b'\x00'])
  { signature: b"\x38\x42\x49\x4D", key: b"iOpa", data }
}

///|
/// Channel Blending Restrictions Setting (key 'brst').
///
/// Spec: "Key is 'brst'. (Photoshop 6.0)"
///   | Length | Description                                    |
///   |--------|------------------------------------------------|
///   | var    | Following is repeated length / 4 times:        |
///   | 4      | Channel number that is restricted              |
pub fn AdditionalLayerInfo::as_blending_restrictions(
  self : AdditionalLayerInfo,
) -> Array[Int]? {
  if self.key != b"brst" {
    return None
  }
  let reader = @binary.Reader::new(self.data)
  let channels : Array[Int] = []
  try {
    while reader.remaining() >= 4 {
      channels.push(reader.read_u32_be().reinterpret_as_int())
    }
  } catch {
    _ => ()
  }
  Some(channels)
}

///|
pub fn AdditionalLayerInfo::from_blending_restrictions(
  channels : Array[Int],
) -> AdditionalLayerInfo {
  let w = @binary.Writer::new()
  for i = 0; i < channels.length(); i = i + 1 {
    w.write_u32_be(channels[i].reinterpret_as_uint())
  }
  { signature: b"\x38\x42\x49\x4D", key: b"brst", data: w.to_bytes() }
}

///|
/// Layer Mask as Global Mask (key 'lmgm') / Vector Mask as Global Mask (key 'vmgm').
///
/// Spec (lmgm): "Key is 'lmgm'. (Photoshop CS6)"
///   | Length | Description                                          |
///   |--------|------------------------------------------------------|
///   | 1      | 1: the layer mask is used in a final crossfade       |
///   |        | masking the layer and effects rather than being used  |
///   |        | to shape the layer and its effects.                   |
///
/// Spec (vmgm): "Key is 'vmgm'. Same as Layer mask as global mask,
///   but applying the vector mask."
pub fn AdditionalLayerInfo::as_mask_as_global(
  self : AdditionalLayerInfo,
) -> Bool? {
  if self.key != b"lmgm" && self.key != b"vmgm" {
    return None
  }
  if self.data.length() < 1 {
    return None
  }
  Some(self.data[0] != b'\x00')
}

///|
/// Create Layer Mask as Global Mask ALI block (key 'lmgm').
pub fn AdditionalLayerInfo::from_layer_mask_as_global(
  flag : Bool,
) -> AdditionalLayerInfo {
  let w = @binary.Writer::new()
  w.write_u8(if flag { b'\x01' } else { b'\x00' })
  w.write_zeros(3) // padding to 4 bytes
  { signature: b"\x38\x42\x49\x4D", key: b"lmgm", data: w.to_bytes() }
}

///|
/// Create Vector Mask as Global Mask ALI block (key 'vmgm').
pub fn AdditionalLayerInfo::from_vector_mask_as_global(
  flag : Bool,
) -> AdditionalLayerInfo {
  let w = @binary.Writer::new()
  w.write_u8(if flag { b'\x01' } else { b'\x00' })
  w.write_zeros(3) // padding to 4 bytes
  { signature: b"\x38\x42\x49\x4D", key: b"vmgm", data: w.to_bytes() }
}
