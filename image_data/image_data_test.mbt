///|
test "ImageData parse/build raw" {
  // compression=0 (Raw), 3 bytes pixel data (1x1 RGB 8-bit)
  let data = b"\x00\x00\x01\x02\x03"
  let reader = @binary.Reader::new(data)
  let img = ImageData::parse(reader, 3, 1, @types.PsdVersion::Psd, 8, 1)
  inspect(img.compression, content="Raw")
  inspect(img.data.length(), content="3")
  inspect(img.data[0], content="b'\\x01'")
  // Build and compare
  let writer = @binary.Writer::new()
  img.build(writer, @types.Compression::Raw, 3, 1, @types.PsdVersion::Psd, 8, 1)
  inspect(writer.to_bytes() == data, content="true")
}

///|
test "ImageData parse/build empty raw" {
  // compression=0 (Raw), no pixel data
  let data = b"\x00\x00"
  let reader = @binary.Reader::new(data)
  let img = ImageData::parse(reader, 0, 0, @types.PsdVersion::Psd, 8, 0)
  inspect(img.compression, content="Raw")
  inspect(img.data.length(), content="0")
  // Build and compare
  let writer = @binary.Writer::new()
  img.build(writer, @types.Compression::Raw, 0, 0, @types.PsdVersion::Psd, 8, 0)
  inspect(writer.to_bytes() == data, content="true")
}

///|
test "ImageData parse RLE 1x1" {
  // 1x1 RGB 8-bit, RLE compression
  // byte counts: 3 entries (3 channels × 1 row), each = 2 (PSD UInt16)
  // compressed data: each line = [0x00, 0x00] (literal 1 byte = 0x00)
  let data = b"\x00\x01\x00\x02\x00\x02\x00\x02\x00\x00\x00\x00\x00\x00"
  let reader = @binary.Reader::new(data)
  let img = ImageData::parse(reader, 3, 1, @types.PsdVersion::Psd, 8, 1)
  // RLE is decoded to Raw
  inspect(img.compression, content="Raw")
  inspect(img.data.length(), content="3")
}

///|
test "ImageData ZIP no prediction round-trip" {
  // 2x2 RGB 8-bit, 12 bytes raw
  let raw_data = b"\xFF\xFF\xFF\xFF\x00\x00\x00\x00\x80\x80\x80\x80"
  let img : ImageData = { compression: @types.Compression::Raw, data: raw_data }
  let writer = @binary.Writer::new()
  img.build(
    writer,
    @types.Compression::ZipNoPrediction,
    3,
    2,
    @types.PsdVersion::Psd,
    8,
    2,
  )
  let zip_bytes = writer.to_bytes()
  // Parse back
  let reader = @binary.Reader::new(zip_bytes)
  let parsed = ImageData::parse(reader, 3, 2, @types.PsdVersion::Psd, 8, 2)
  inspect(parsed.compression, content="Raw")
  inspect(parsed.data == raw_data, content="true")
}

///|
test "ImageData ZIP with prediction round-trip" {
  // 2x2 RGB 8-bit, 12 bytes raw
  let raw_data = b"\xFF\xFF\xFF\xFF\x00\x00\x00\x00\x80\x80\x80\x80"
  let img : ImageData = { compression: @types.Compression::Raw, data: raw_data }
  let writer = @binary.Writer::new()
  img.build(
    writer,
    @types.Compression::ZipPrediction,
    3,
    2,
    @types.PsdVersion::Psd,
    8,
    2,
  )
  let zip_bytes = writer.to_bytes()
  // Parse back
  let reader = @binary.Reader::new(zip_bytes)
  let parsed = ImageData::parse(reader, 3, 2, @types.PsdVersion::Psd, 8, 2)
  inspect(parsed.compression, content="Raw")
  inspect(parsed.data == raw_data, content="true")
}

///|
test "ImageData RLE round-trip" {
  // Create raw pixel data for 2x2 RGB 8-bit
  // R channel: FF FF FF FF, G channel: 00 00 00 00, B channel: 80 80 80 80
  let raw_data = b"\xFF\xFF\xFF\xFF\x00\x00\x00\x00\x80\x80\x80\x80"
  let img : ImageData = { compression: @types.Compression::Raw, data: raw_data }
  // Build as RLE
  let writer = @binary.Writer::new()
  img.build(writer, @types.Compression::Rle, 3, 2, @types.PsdVersion::Psd, 8, 2)
  let rle_bytes = writer.to_bytes()
  // Parse back
  let reader = @binary.Reader::new(rle_bytes)
  let parsed = ImageData::parse(reader, 3, 2, @types.PsdVersion::Psd, 8, 2)
  inspect(parsed.data == raw_data, content="true")
}
