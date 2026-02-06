///|
test "ChannelImageData decompress Raw" {
  let raw_data = Bytes::makei(16, fn(i) { i.to_byte() })
  let cid : ChannelImageData = {
    compression: @types.Compression::Raw,
    data: raw_data,
  }
  let result = cid.decompress(4, 4, @types.PsdVersion::Psd, 8)
  inspect(result == raw_data, content="true")
}

///|
test "ChannelImageData compress/decompress RLE round-trip" {
  // 4x4 image, 8-bit depth, single channel
  let raw_data = Bytes::makei(16, fn(i) { (i * 17).to_byte() })
  let compressed = ChannelImageData::compress(
    raw_data,
    4,
    4,
    @types.PsdVersion::Psd,
    8,
    @types.Compression::Rle,
  )
  inspect(compressed.compression, content="Rle")
  let decompressed = compressed.decompress(4, 4, @types.PsdVersion::Psd, 8)
  inspect(decompressed == raw_data, content="true")
}

///|
test "ChannelImageData compress/decompress RLE repeated data" {
  // All same value - should compress well
  let raw_data = Bytes::makei(32, fn(_i) { b'\xAA' })
  let compressed = ChannelImageData::compress(
    raw_data,
    8,
    4,
    @types.PsdVersion::Psd,
    8,
    @types.Compression::Rle,
  )
  // Compressed should be smaller than raw
  // RLE data includes byte counts (4 * 2 = 8 bytes for PSD)
  let decompressed = compressed.decompress(8, 4, @types.PsdVersion::Psd, 8)
  inspect(decompressed == raw_data, content="true")
}

///|
test "ChannelImageData compress/decompress RLE PSB" {
  let raw_data = Bytes::makei(16, fn(i) { i.to_byte() })
  let compressed = ChannelImageData::compress(
    raw_data,
    4,
    4,
    @types.PsdVersion::Psb,
    8,
    @types.Compression::Rle,
  )
  let decompressed = compressed.decompress(4, 4, @types.PsdVersion::Psb, 8)
  inspect(decompressed == raw_data, content="true")
}

///|
test "ChannelImageData compress/decompress ZIP no prediction" {
  let raw_data = Bytes::makei(16, fn(i) { (i * 17).to_byte() })
  let compressed = ChannelImageData::compress(
    raw_data,
    4,
    4,
    @types.PsdVersion::Psd,
    8,
    @types.Compression::ZipNoPrediction,
  )
  inspect(compressed.compression, content="ZipNoPrediction")
  let decompressed = compressed.decompress(4, 4, @types.PsdVersion::Psd, 8)
  inspect(decompressed == raw_data, content="true")
}

///|
test "ChannelImageData compress/decompress ZIP with prediction" {
  let raw_data = Bytes::makei(16, fn(i) { (i * 17).to_byte() })
  let compressed = ChannelImageData::compress(
    raw_data,
    4,
    4,
    @types.PsdVersion::Psd,
    8,
    @types.Compression::ZipPrediction,
  )
  inspect(compressed.compression, content="ZipPrediction")
  let decompressed = compressed.decompress(4, 4, @types.PsdVersion::Psd, 8)
  inspect(decompressed == raw_data, content="true")
}

///|
test "ChannelImageData ZIP with prediction 16-bit" {
  // 2x2 image, 16-bit depth = 8 bytes
  let raw_data = Bytes::from_array([
    b'\x00', b'\x10', b'\x00', b'\x20', b'\x00', b'\x30', b'\x00', b'\x40',
  ])
  let compressed = ChannelImageData::compress(
    raw_data,
    2,
    2,
    @types.PsdVersion::Psd,
    16,
    @types.Compression::ZipPrediction,
  )
  let decompressed = compressed.decompress(2, 2, @types.PsdVersion::Psd, 16)
  inspect(decompressed == raw_data, content="true")
}

///|
test "ChannelImageData compress Raw" {
  let raw_data = Bytes::makei(8, fn(i) { i.to_byte() })
  let result = ChannelImageData::compress(
    raw_data,
    4,
    2,
    @types.PsdVersion::Psd,
    8,
    @types.Compression::Raw,
  )
  inspect(result.compression, content="Raw")
  inspect(result.data == raw_data, content="true")
}
