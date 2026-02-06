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

///|
/// Decompress channel image data to raw pixels.
/// width/height define the channel dimensions, version determines RLE count size.
pub fn ChannelImageData::decompress(
  self : ChannelImageData,
  width : Int,
  height : Int,
  version : @types.PsdVersion,
  depth : Int,
) -> Bytes raise @types.PsdError {
  let bytes_per_line = width * (depth / 8)
  match self.compression {
    Raw => self.data
    Rle => {
      let reader = @binary.Reader::new(self.data)
      // Read byte counts for each scanline
      let byte_counts : Array[Int] = []
      for _i = 0; _i < height; _i = _i + 1 {
        byte_counts.push(reader.read_rle_count(version))
      }
      // Decode each scanline
      let buf = @buffer.new(size_hint=height * bytes_per_line)
      for line = 0; line < height; line = line + 1 {
        let compressed = reader.read_bytes(byte_counts[line])
        let decoded = @compression.packbits_decode(compressed, bytes_per_line)
        buf.write_bytes(decoded)
      }
      buf.to_bytes()
    }
    ZipNoPrediction => {
      let total_bytes = height * width * (depth / 8)
      @compression.zlib_decompress(self.data, total_bytes)
    }
    ZipPrediction => {
      let total_bytes = height * width * (depth / 8)
      let decompressed = @compression.zlib_decompress(self.data, total_bytes)
      @compression.remove_prediction_filter(decompressed, width, height, depth)
    }
  }
}

///|
/// Compress raw pixel data into channel image data with the specified compression.
pub fn ChannelImageData::compress(
  raw_data : Bytes,
  width : Int,
  height : Int,
  version : @types.PsdVersion,
  depth : Int,
  compression : @types.Compression,
) -> ChannelImageData {
  let bytes_per_line = width * (depth / 8)
  match compression {
    Raw => { compression, data: raw_data }
    Rle => {
      let w = @binary.Writer::new()
      // Encode each scanline
      let encoded_lines : Array[Bytes] = []
      for line = 0; line < height; line = line + 1 {
        let offset = line * bytes_per_line
        let line_buf = @buffer.new(size_hint=bytes_per_line)
        for j = 0; j < bytes_per_line; j = j + 1 {
          line_buf.write_byte(raw_data[offset + j])
        }
        encoded_lines.push(@compression.packbits_encode(line_buf.to_bytes()))
      }
      // Write byte counts
      for line = 0; line < height; line = line + 1 {
        w.write_rle_count(encoded_lines[line].length(), version)
      }
      // Write compressed data
      for line = 0; line < height; line = line + 1 {
        w.write_bytes(encoded_lines[line])
      }
      { compression, data: w.to_bytes() }
    }
    ZipNoPrediction => {
      let compressed = @compression.zlib_compress(raw_data)
      { compression, data: compressed }
    }
    ZipPrediction => {
      let filtered = @compression.apply_prediction_filter(
        raw_data, width, height, depth,
      )
      let compressed = @compression.zlib_compress(filtered)
      { compression, data: compressed }
    }
  }
}
