///|
pub(all) struct ChannelImageData {
  compression : @types.Compression
  data : Bytes
} derive(Eq, Show)

///|
/// Parse channel image data. data_length includes the 2-byte compression field.
pub fn ChannelImageData::parse(
  reader : @binary.Reader,
  data_length : Int,
) -> ChannelImageData raise @types.PsdError {
  let comp_int = reader.read_u16_be().reinterpret_as_int()
  let compression = @types.Compression::from_int(comp_int)
  let pixel_bytes = data_length - 2
  let data = if pixel_bytes > 0 { reader.read_bytes(pixel_bytes) } else { b"" }
  { compression, data }
}

///|
pub fn ChannelImageData::build(
  self : ChannelImageData,
  writer : @binary.Writer,
) -> Unit {
  writer.write_u16_be(self.compression.to_int().reinterpret_as_uint())
  if self.data.length() > 0 {
    writer.write_bytes(self.data)
  }
}
