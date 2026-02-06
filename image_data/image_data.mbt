///|
pub(all) struct ImageData {
  compression : @types.Compression
  data : Bytes
} derive(Eq, Show)

///|
/// Parse image data section.
/// channels, height, version are needed for RLE byte count reading.
pub fn ImageData::parse(
  reader : @binary.Reader,
  channels : Int,
  height : Int,
  version : @types.PsdVersion,
  depth : Int,
  width : Int,
) -> ImageData raise @types.PsdError {
  let comp_int = reader.read_u16_be().reinterpret_as_int()
  let compression = @types.Compression::from_int(comp_int)
  match compression {
    Raw => {
      let remaining = reader.remaining()
      let data = if remaining > 0 { reader.read_bytes(remaining) } else { b"" }
      { compression, data }
    }
    Rle => {
      let total_lines = channels * height
      // Read all byte counts first
      let byte_counts : Array[Int] = []
      for _i = 0; _i < total_lines; _i = _i + 1 {
        byte_counts.push(reader.read_rle_count(version))
      }
      // Read and decode each scanline
      let bytes_per_line = width * (depth / 8)
      let buf = @buffer.new(size_hint=total_lines * bytes_per_line)
      for line = 0; line < total_lines; line = line + 1 {
        let compressed = reader.read_bytes(byte_counts[line])
        let decoded = @compression.packbits_decode(compressed, bytes_per_line)
        buf.write_bytes(decoded)
      }
      { compression: Raw, data: buf.to_bytes() }
    }
    _ => {
      // ZIP not yet supported - store remaining as opaque
      let remaining = reader.remaining()
      let data = if remaining > 0 { reader.read_bytes(remaining) } else { b"" }
      { compression, data }
    }
  }
}

///|
/// Build image data section with the specified compression.
/// For RLE, channels/height/version/depth/width are needed.
pub fn ImageData::build(
  self : ImageData,
  writer : @binary.Writer,
  compression : @types.Compression,
  channels : Int,
  height : Int,
  version : @types.PsdVersion,
  depth : Int,
  width : Int,
) -> Unit {
  writer.write_u16_be(compression.to_int().reinterpret_as_uint())
  match compression {
    Raw => if self.data.length() > 0 { writer.write_bytes(self.data) }
    Rle => {
      let bytes_per_line = width * (depth / 8)
      let total_lines = channels * height
      // Encode each scanline
      let encoded_lines : Array[Bytes] = []
      for line = 0; line < total_lines; line = line + 1 {
        let offset = line * bytes_per_line
        let line_buf = @buffer.new(size_hint=bytes_per_line)
        for j = 0; j < bytes_per_line; j = j + 1 {
          line_buf.write_byte(self.data[offset + j])
        }
        encoded_lines.push(@compression.packbits_encode(line_buf.to_bytes()))
      }
      // Write byte counts
      for line = 0; line < total_lines; line = line + 1 {
        writer.write_rle_count(encoded_lines[line].length(), version)
      }
      // Write compressed data
      for line = 0; line < total_lines; line = line + 1 {
        writer.write_bytes(encoded_lines[line])
      }
    }
    _ =>
      // ZIP not yet supported - write opaque data
      if self.data.length() > 0 {
        writer.write_bytes(self.data)
      }
  }
}
