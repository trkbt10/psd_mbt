///|
pub(all) struct ImageResources {
  blocks : Array[ImageResourceBlock]
} derive(Eq, Show)

///|
pub fn ImageResources::parse(
  reader : @binary.Reader,
) -> ImageResources raise @types.PsdError {
  let section_length = reader.read_u32_be().reinterpret_as_int()
  let blocks : Array[ImageResourceBlock] = []
  if section_length > 0 {
    let start_pos = reader.position()
    while reader.position() - start_pos < section_length {
      blocks.push(ImageResourceBlock::parse(reader))
    }
  }
  { blocks, }
}

///|
pub fn ImageResources::build(
  self : ImageResources,
  writer : @binary.Writer,
) -> Unit {
  if self.blocks.length() == 0 {
    writer.write_u32_be(0U)
    return
  }
  // Build blocks into a temp writer to get total length
  let temp = @binary.Writer::new()
  for i = 0; i < self.blocks.length(); i = i + 1 {
    self.blocks[i].build(temp)
  }
  let data = temp.to_bytes()
  writer.write_u32_be(data.length().reinterpret_as_uint())
  writer.write_bytes(data)
}
