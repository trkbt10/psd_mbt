///|
/// Layer ID (key 'lyid') - UInt32.
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
/// Blend Clipping (key 'clbl') - 1 byte bool.
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
/// Interior Blend (key 'infx') - 1 byte bool.
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
/// Knockout (key 'knko') - 1 byte bool.
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
/// Protection Settings (key 'lspf') - UInt32 bit flags.
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
/// Sheet Color (key 'lclr') - 8 bytes (4x UInt16 color).
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
/// Reference Point (key 'fxrp') - 2x Float64 (16 bytes).
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
/// Layer Name Source (key 'lnsr') - 4 bytes ID.
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
/// Layer Version (key 'lyvr') - UInt32 (typically = 70).
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
/// Transparency Shapes Layer (key 'tsly') - 1 byte.
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
/// Fill Opacity (key 'iOpa') - 1 byte (0-255).
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
