///|
pub struct ColorModeData {
  data : Bytes
} derive(Eq, Show)

///|
pub fn ColorModeData::parse(
  reader : @binary.Reader,
  color_mode : @types.ColorMode,
) -> ColorModeData raise @types.PsdError {
  let length = reader.read_u32_be().reinterpret_as_int()
  let data = if length > 0 { reader.read_bytes(length) } else { b"" }
  match color_mode {
    Indexed =>
      if length != 768 {
        raise @types.InvalidColorModeDataLength(768, length)
      }
    Duotone => if length == 0 { raise @types.InvalidColorModeDataLength(1, 0) }
    _ => ()
  }
  { data, }
}

///|
pub fn ColorModeData::build(
  self : ColorModeData,
  writer : @binary.Writer,
) -> Unit {
  writer.write_u32_be(self.data.length().reinterpret_as_uint())
  if self.data.length() > 0 {
    writer.write_bytes(self.data)
  }
}

///|
/// Interpret the color mode data as an indexed color table.
/// Returns array of (R, G, B) tuples for 256 colors, or None if data
/// is not exactly 768 bytes (256 * 3 channels, non-interleaved).
pub fn ColorModeData::as_indexed_table(
  self : ColorModeData,
) -> Array[(Int, Int, Int)]? {
  if self.data.length() != 768 {
    return None
  }
  let table : Array[(Int, Int, Int)] = []
  for i = 0; i < 256; i = i + 1 {
    let r = self.data[i].to_int()
    let g = self.data[256 + i].to_int()
    let b = self.data[512 + i].to_int()
    table.push((r, g, b))
  }
  Some(table)
}

///|
/// Create ColorModeData from an indexed color table of 256 (R, G, B) entries.
/// Colors are stored non-interleaved: all R values, then all G, then all B.
pub fn ColorModeData::from_indexed_table(
  table : Array[(Int, Int, Int)],
) -> ColorModeData {
  let buf = @buffer.new(size_hint=768)
  // Red channel
  for i = 0; i < 256; i = i + 1 {
    let entry = if i < table.length() { table[i] } else { (0, 0, 0) }
    buf.write_byte(entry.0.to_byte())
  }
  // Green channel
  for i = 0; i < 256; i = i + 1 {
    let entry = if i < table.length() { table[i] } else { (0, 0, 0) }
    buf.write_byte(entry.1.to_byte())
  }
  // Blue channel
  for i = 0; i < 256; i = i + 1 {
    let entry = if i < table.length() { table[i] } else { (0, 0, 0) }
    buf.write_byte(entry.2.to_byte())
  }
  { data: buf.to_bytes() }
}
