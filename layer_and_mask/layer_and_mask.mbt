///|
pub(all) struct LayerAndMaskInfo {
  layer_info : LayerInfo?
  global_mask : GlobalLayerMaskInfo?
  additional_info : Array[AdditionalLayerInfo]
} derive(Eq, Show)

///|
pub fn LayerAndMaskInfo::parse(
  reader : @binary.Reader,
  version : @types.PsdVersion,
) -> LayerAndMaskInfo raise @types.PsdError {
  // Section length
  let section_length = reader.read_length(version)
  if section_length == 0 {
    return { layer_info: None, global_mask: None, additional_info: [] }
  }
  let section_start = reader.position()
  // Layer Info length
  let li_len_field_size = match version {
    Psd => 4
    Psb => 8
  }
  let layer_info_length = reader.read_length(version)
  let layer_info : LayerInfo? = if layer_info_length > 0 {
    let li = LayerInfo::parse(reader, version)
    // Skip any unread bytes within layer info section
    let consumed_in_li = reader.position() - section_start - li_len_field_size
    if consumed_in_li < layer_info_length {
      reader.skip(layer_info_length - consumed_in_li)
    }
    // Skip padding byte if layer info length is odd (round to even)
    if layer_info_length % 2 != 0 {
      reader.skip(1)
    }
    Some(li)
  } else {
    None
  }
  // Global Layer Mask Info
  let remaining1 = section_length - (reader.position() - section_start)
  let global_mask : GlobalLayerMaskInfo? = if remaining1 >= 4 {
    Some(GlobalLayerMaskInfo::parse(reader))
  } else {
    None
  }
  // Additional Layer Information (remaining bytes)
  let remaining2 = section_length - (reader.position() - section_start)
  let additional_info = parse_additional_layer_infos(
    reader, remaining2, version,
  )
  { layer_info, global_mask, additional_info }
}

///|
pub fn LayerAndMaskInfo::build(
  self : LayerAndMaskInfo,
  writer : @binary.Writer,
  version : @types.PsdVersion,
) -> Unit {
  if self.layer_info is None &&
    self.global_mask is None &&
    self.additional_info.length() == 0 {
    // Empty section
    writer.write_length(0, version)
    return
  }
  // Build section content to temp writer
  let temp = @binary.Writer::new()
  // Layer Info
  match self.layer_info {
    Some(li) => {
      let li_temp = @binary.Writer::new()
      li.build(li_temp, version)
      let li_data = li_temp.to_bytes()
      let li_length = li_data.length()
      temp.write_length(li_length, version)
      temp.write_bytes(li_data)
      if li_length % 2 != 0 {
        temp.write_u8(b'\x00')
      }
    }
    None => temp.write_length(0, version)
  }
  // Global Layer Mask Info
  match self.global_mask {
    Some(gm) => gm.build(temp)
    None => temp.write_u32_be(0U)
  }
  // Additional layer info
  build_additional_layer_infos(self.additional_info, temp, version)
  // Write section length + content
  let section_data = temp.to_bytes()
  writer.write_length(section_data.length(), version)
  writer.write_bytes(section_data)
}
