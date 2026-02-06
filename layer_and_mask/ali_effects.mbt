///|
/// Legacy Effects Layer (key 'lrFX').
/// Contains version + count + effect records.
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
/// Parse legacy effects from ALI data (key 'lrFX').
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
/// Build legacy effects to ALI data.
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
/// Object Effects (key 'lfx2') - version(4) + Descriptor.
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

///|
/// Filter Mask (key 'FMsk') - color(10) + opacity(2).
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
