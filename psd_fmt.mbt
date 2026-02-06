///|
pub struct PsdFile {
  header : @header.FileHeader
  color_mode_data : @color_mode_data.ColorModeData
  image_resources : @image_resources.ImageResources
  layer_and_mask_info : @layer_and_mask.LayerAndMaskInfo
  image_data : @image_data.ImageData
} derive(Eq, Show)

///|
pub fn PsdFile::parse(data : Bytes) -> PsdFile raise @types.PsdError {
  let reader = @binary.Reader::new(data)
  let header = @header.FileHeader::parse(reader)
  let color_mode_data = @color_mode_data.ColorModeData::parse(reader)
  let image_resources = @image_resources.ImageResources::parse(reader)
  let layer_and_mask_info = @layer_and_mask.LayerAndMaskInfo::parse(
    reader,
    header.version,
  )
  let image_data = @image_data.ImageData::parse(
    reader,
    header.channels,
    header.height,
    header.version,
    header.depth,
    header.width,
  )
  { header, color_mode_data, image_resources, layer_and_mask_info, image_data }
}

///|
pub fn PsdFile::build(self : PsdFile) -> Bytes {
  let writer = @binary.Writer::new()
  self.header.build(writer)
  self.color_mode_data.build(writer)
  self.image_resources.build(writer)
  self.layer_and_mask_info.build(writer, self.header.version)
  self.image_data.build(
    writer,
    self.image_data.compression,
    self.header.channels,
    self.header.height,
    self.header.version,
    self.header.depth,
    self.header.width,
  )
  writer.to_bytes()
}
