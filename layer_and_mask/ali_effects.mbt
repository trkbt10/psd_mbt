// Additional Layer Information: Effects Layer keys
//
// PSD File Format Specification, "Additional Layer Information" section.

///|
/// Legacy Effects Layer (key 'lrFX').
///
/// Spec: "Key is 'lrFX'. (Photoshop 5.0)"
///   "Effects Layer (Photoshop 5.0). Also see Object-based effects layer info."
///   | Length | Description               |
///   |--------|---------------------------|
///   | 2      | Version (= 0)             |
///   | 2      | Effects count             |
///   | var    | For each effect:          |
///   |        |   4 bytes signature ('8BIM') |
///   |        |   4 bytes type ('cmnS', 'dsdw', 'isdw', 'oglw', 'iglw', 'bevl', 'sofi') |
///   |        |   4 bytes data size       |
///   |        |   var data                |
pub(all) struct LegacyEffects {
  version : Int
  effects : Array[LegacyEffect]
} derive(Eq, Show)

///|
pub(all) struct LegacyEffect {
  signature : Bytes // '8BIM'
  effect_type : Bytes // 'cmnS', 'dsdw', 'isdw', 'oglw', 'iglw', 'bevl', 'sofi'
  data : Bytes
} derive(Eq, Show)

///|
pub fn AdditionalLayerInfo::as_legacy_effects(
  self : AdditionalLayerInfo,
) -> LegacyEffects? {
  if self.key != b"lrFX" || self.data.length() < 4 {
    return None
  }
  let reader = @binary.Reader::new(self.data)
  try {
    let version = reader.read_u16_be().reinterpret_as_int()
    let count = reader.read_u16_be().reinterpret_as_int()
    let effects : Array[LegacyEffect] = []
    for _i = 0; _i < count; _i = _i + 1 {
      let sig = reader.read_bytes(4)
      let etype = reader.read_bytes(4)
      let size = reader.read_u32_be().reinterpret_as_int()
      let data = if size > 0 { reader.read_bytes(size) } else { b"" }
      effects.push({ signature: sig, effect_type: etype, data })
    }
    Some({ version, effects })
  } catch {
    _ => None
  }
}

///|
pub fn AdditionalLayerInfo::from_legacy_effects(
  effects : LegacyEffects,
) -> AdditionalLayerInfo {
  let w = @binary.Writer::new()
  w.write_u16_be(effects.version.reinterpret_as_uint())
  w.write_u16_be(effects.effects.length().reinterpret_as_uint())
  for i = 0; i < effects.effects.length(); i = i + 1 {
    let e = effects.effects[i]
    w.write_bytes(e.signature)
    w.write_bytes(e.effect_type)
    w.write_u32_be(e.data.length().reinterpret_as_uint())
    if e.data.length() > 0 {
      w.write_bytes(e.data)
    }
  }
  { signature: b"\x38\x42\x49\x4D", key: b"lrFX", data: w.to_bytes() }
}

///|
/// Object-based Effects (key 'lfx2').
///
/// Spec: "Key is 'lfx2'. (Photoshop 6.0)"
///   "Object-based effects layer info. Also see Effects Layer."
///   | Length | Description         |
///   |--------|---------------------|
///   | 4      | Object effects version |
///   | 4      | Descriptor version  |
///   | var    | Descriptor          |
pub fn AdditionalLayerInfo::as_object_effects(
  self : AdditionalLayerInfo,
) -> (Int, @descriptor.Descriptor)? {
  if self.key != b"lfx2" || self.data.length() < 8 {
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
pub fn AdditionalLayerInfo::from_object_effects(
  version : Int,
  desc : @descriptor.Descriptor,
) -> AdditionalLayerInfo {
  let w = @binary.Writer::new()
  w.write_u32_be(version.reinterpret_as_uint())
  desc.build(w)
  { signature: b"\x38\x42\x49\x4D", key: b"lfx2", data: w.to_bytes() }
}
