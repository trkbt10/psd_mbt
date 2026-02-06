///|
pub(all) struct LayerInfo {
  layer_count : Int
  layers : Array[LayerRecord]
  channel_data : Array[Array[ChannelImageData]]
} derive(Eq, Show)

///|
pub fn LayerInfo::parse(
  reader : @binary.Reader,
  version : @types.PsdVersion,
) -> LayerInfo raise @types.PsdError {
  // Layer count (Int16, negative means alpha in merged result)
  let raw_count = reader.read_i16_be()
  let layer_count = raw_count
  let abs_count = if raw_count < 0 { -raw_count } else { raw_count }
  // Parse layer records
  let layers : Array[LayerRecord] = []
  for _i = 0; _i < abs_count; _i = _i + 1 {
    layers.push(LayerRecord::parse(reader, version))
  }
  // Parse channel image data (per layer, per channel)
  let channel_data : Array[Array[ChannelImageData]] = []
  for i = 0; i < abs_count; i = i + 1 {
    let layer_channels : Array[ChannelImageData] = []
    for j = 0; j < layers[i].channels.length(); j = j + 1 {
      let data_length = layers[i].channels[j].data_length
      layer_channels.push(ChannelImageData::parse(reader, data_length))
    }
    channel_data.push(layer_channels)
  }
  { layer_count, layers, channel_data }
}

///|
/// If layer_count is negative, the first alpha channel contains
/// the transparency data for the merged result.
pub fn LayerInfo::has_merged_transparency(self : LayerInfo) -> Bool {
  self.layer_count < 0
}

///|
/// Actual number of layers (absolute value of layer_count).
pub fn LayerInfo::actual_layer_count(self : LayerInfo) -> Int {
  if self.layer_count < 0 {
    -self.layer_count
  } else {
    self.layer_count
  }
}

///|
pub fn LayerInfo::build(
  self : LayerInfo,
  writer : @binary.Writer,
  version : @types.PsdVersion,
) -> Unit {
  // Layer count
  writer.write_i16_be(self.layer_count)
  // Layer records
  for i = 0; i < self.layers.length(); i = i + 1 {
    self.layers[i].build(writer, version)
  }
  // Channel image data
  for i = 0; i < self.channel_data.length(); i = i + 1 {
    for j = 0; j < self.channel_data[i].length(); j = j + 1 {
      self.channel_data[i][j].build(writer)
    }
  }
}
