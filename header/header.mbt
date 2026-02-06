///|
pub struct FileHeader {
  version : @types.PsdVersion
  channels : Int
  height : Int
  width : Int
  depth : Int
  color_mode : @types.ColorMode
} derive(Eq, Show)

///|
let psd_signature : Bytes = b"\x38\x42\x50\x53"

///|
pub fn FileHeader::parse(
  reader : @binary.Reader,
) -> FileHeader raise @types.PsdError {
  let sig = reader.read_bytes(4)
  if sig != psd_signature {
    raise @types.InvalidSignature(sig)
  }
  let version_int = reader.read_u16_be().reinterpret_as_int()
  let version = @types.PsdVersion::from_int(version_int)
  // Reserved 6 bytes - must be zero
  let reserved = reader.read_bytes(6)
  for i = 0; i < 6; i = i + 1 {
    if reserved[i] != b'\x00' {
      raise @types.InvalidReserved
    }
  }
  let channels = reader.read_u16_be().reinterpret_as_int()
  if channels < 1 || channels > 56 {
    raise @types.ChannelsOutOfRange(channels)
  }
  let height = reader.read_u32_be().reinterpret_as_int()
  let width = reader.read_u32_be().reinterpret_as_int()
  let max_dim = match version {
    Psd => 30000
    Psb => 300000
  }
  if width < 1 || width > max_dim || height < 1 || height > max_dim {
    raise @types.DimensionsOutOfRange(width, height)
  }
  let depth = reader.read_u16_be().reinterpret_as_int()
  if depth != 1 && depth != 8 && depth != 16 && depth != 32 {
    raise @types.InvalidDepth(depth)
  }
  let color_mode_int = reader.read_u16_be().reinterpret_as_int()
  let color_mode = @types.ColorMode::from_int(color_mode_int)
  { version, channels, height, width, depth, color_mode }
}

///|
pub fn FileHeader::build(self : FileHeader, writer : @binary.Writer) -> Unit {
  // Signature '8BPS'
  writer.write_bytes(psd_signature)
  // Version
  writer.write_u16_be(self.version.to_int().reinterpret_as_uint())
  // Reserved 6 bytes
  writer.write_zeros(6)
  // Channels
  writer.write_u16_be(self.channels.reinterpret_as_uint())
  // Height
  writer.write_u32_be(self.height.reinterpret_as_uint())
  // Width
  writer.write_u32_be(self.width.reinterpret_as_uint())
  // Depth
  writer.write_u16_be(self.depth.reinterpret_as_uint())
  // Color Mode
  writer.write_u16_be(self.color_mode.to_int().reinterpret_as_uint())
}
