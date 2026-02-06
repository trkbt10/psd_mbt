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
