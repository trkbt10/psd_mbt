///|
pub(all) struct GlobalLayerMaskInfo {
  data : Bytes
} derive(Eq, Show)

///|
pub fn GlobalLayerMaskInfo::parse(
  reader : @binary.Reader,
) -> GlobalLayerMaskInfo raise @types.PsdError {
  let length = reader.read_u32_be().reinterpret_as_int()
  let data = if length > 0 { reader.read_bytes(length) } else { b"" }
  { data, }
}

///|
pub fn GlobalLayerMaskInfo::build(
  self : GlobalLayerMaskInfo,
  writer : @binary.Writer,
) -> Unit {
  writer.write_u32_be(self.data.length().reinterpret_as_uint())
  if self.data.length() > 0 {
    writer.write_bytes(self.data)
  }
}

///|
/// Typed interpretation of the global layer mask info data.
pub(all) struct GlobalMaskFields {
  overlay_color_space : Int
  color_components : Array[Int] // 4x UInt16
  opacity : Int // 0=transparent, 100=opaque
  kind : Int // 0=color selected, 1=color protected, 128=use value
} derive(Eq, Show)

///|
/// Parse the opaque data into typed fields.
pub fn GlobalLayerMaskInfo::as_fields(
  self : GlobalLayerMaskInfo,
) -> GlobalMaskFields? {
  // Need at least 13 bytes: 2 (color space) + 8 (4x UInt16) + 2 (opacity) + 1 (kind)
  if self.data.length() < 13 {
    return None
  }
  let reader = @binary.Reader::new(self.data)
  try {
    let overlay_color_space = reader.read_u16_be().reinterpret_as_int()
    let c0 = reader.read_u16_be().reinterpret_as_int()
    let c1 = reader.read_u16_be().reinterpret_as_int()
    let c2 = reader.read_u16_be().reinterpret_as_int()
    let c3 = reader.read_u16_be().reinterpret_as_int()
    let color_components = [c0, c1, c2, c3]
    let opacity = reader.read_u16_be().reinterpret_as_int()
    let kind = reader.read_u8().to_int()
    Some({ overlay_color_space, color_components, opacity, kind })
  } catch {
    _ => None
  }
}

///|
/// Create GlobalLayerMaskInfo from typed fields.
pub fn GlobalLayerMaskInfo::from_fields(
  fields : GlobalMaskFields,
) -> GlobalLayerMaskInfo {
  let w = @binary.Writer::new()
  w.write_u16_be(fields.overlay_color_space.reinterpret_as_uint())
  for i = 0; i < fields.color_components.length(); i = i + 1 {
    w.write_u16_be(fields.color_components[i].reinterpret_as_uint())
  }
  w.write_u16_be(fields.opacity.reinterpret_as_uint())
  w.write_u8(fields.kind.to_byte())
  { data: w.to_bytes() }
}
