///|
/// Type Tool (key 'TySh', PS6+) - transform matrix + Descriptor.
pub(all) struct TypeToolInfo {
  version : Int
  transform : Array[Double] // 6 doubles: xx, xy, yx, yy, tx, ty
  text_version : Int
  descriptor_version : Int
  text_data : @descriptor.Descriptor
} derive(Eq, Show)

///|
pub fn AdditionalLayerInfo::as_type_tool(
  self : AdditionalLayerInfo,
) -> TypeToolInfo? {
  if self.key != b"TySh" || self.data.length() < 60 {
    return None
  }
  let reader = @binary.Reader::new(self.data)
  try {
    let version = reader.read_u16_be().reinterpret_as_int()
    // Transform: 6 doubles (48 bytes)
    let transform : Array[Double] = []
    for _i = 0; _i < 6; _i = _i + 1 {
      let bits = reader.read_u64_be()
      transform.push(bits.reinterpret_as_double())
    }
    let text_version = reader.read_u16_be().reinterpret_as_int()
    let descriptor_version = reader.read_u32_be().reinterpret_as_int()
    let text_data = @descriptor.Descriptor::parse(reader)
    Some({ version, transform, text_version, descriptor_version, text_data })
  } catch {
    _ => None
  }
}

///|
pub fn AdditionalLayerInfo::from_type_tool(
  info : TypeToolInfo,
) -> AdditionalLayerInfo {
  let w = @binary.Writer::new()
  w.write_u16_be(info.version.reinterpret_as_uint())
  for i = 0; i < 6; i = i + 1 {
    let v = if i < info.transform.length() { info.transform[i] } else { 0.0 }
    w.write_u64_be(v.reinterpret_as_uint64())
  }
  w.write_u16_be(info.text_version.reinterpret_as_uint())
  w.write_u32_be(info.descriptor_version.reinterpret_as_uint())
  info.text_data.build(w)
  { signature: b"\x38\x42\x49\x4D", key: b"TySh", data: w.to_bytes() }
}
