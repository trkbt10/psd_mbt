///|
pub(all) struct ChannelInfo {
  channel_id : Int
  data_length : Int
} derive(Eq, Show)

///|
pub(all) struct LayerRecord {
  rect : @types.Rect
  channels : Array[ChannelInfo]
  blend_mode : @types.BlendMode
  opacity : Int
  clipping : Int
  flags : Int
  mask_data : Bytes
  blending_ranges : Bytes
  name : String
  additional_info : Array[AdditionalLayerInfo]
} derive(Eq, Show)

///|
let blend_signature : Bytes = b"\x38\x42\x49\x4D"

///|
pub fn LayerRecord::parse(
  reader : @binary.Reader,
  version : @types.PsdVersion,
) -> LayerRecord raise @types.PsdError {
  // Rectangle
  let top = reader.read_i32_be()
  let left = reader.read_i32_be()
  let bottom = reader.read_i32_be()
  let right = reader.read_i32_be()
  let rect : @types.Rect = { top, left, bottom, right }
  // Channel count and info
  let channel_count = reader.read_u16_be().reinterpret_as_int()
  let channels : Array[ChannelInfo] = []
  for _i = 0; _i < channel_count; _i = _i + 1 {
    let channel_id = reader.read_i16_be()
    let data_length = reader.read_length(version)
    channels.push({ channel_id, data_length })
  }
  // Blend mode signature
  let sig = reader.read_bytes(4)
  if sig != blend_signature {
    raise @types.InvalidSignature(sig)
  }
  // Blend mode key
  let blend_key = reader.read_bytes(4)
  let blend_mode = @types.BlendMode::from_bytes(blend_key)
  // Opacity, clipping, flags, filler
  let opacity = reader.read_u8().to_int()
  let clipping = reader.read_u8().to_int()
  let flags = reader.read_u8().to_int()
  reader.skip(1) // filler
  // Extra data
  let extra_data_length = reader.read_u32_be().reinterpret_as_int()
  let extra_start = reader.position()
  // Layer Mask Data
  let mask_length = reader.read_u32_be().reinterpret_as_int()
  let mask_data = if mask_length > 0 {
    reader.read_bytes(mask_length)
  } else {
    b""
  }
  // Blending Ranges
  let ranges_length = reader.read_u32_be().reinterpret_as_int()
  let blending_ranges = if ranges_length > 0 {
    reader.read_bytes(ranges_length)
  } else {
    b""
  }
  // Layer Name (Pascal string, 4-byte boundary padding)
  let name = read_pascal_string_4byte(reader)
  // Additional Layer Information (remaining extra data)
  let consumed = reader.position() - extra_start
  let remaining = extra_data_length - consumed
  let additional_info = parse_additional_layer_infos(reader, remaining, version)
  {
    rect,
    channels,
    blend_mode,
    opacity,
    clipping,
    flags,
    mask_data,
    blending_ranges,
    name,
    additional_info,
  }
}

///|
pub fn LayerRecord::build(
  self : LayerRecord,
  writer : @binary.Writer,
  version : @types.PsdVersion,
) -> Unit {
  // Rectangle
  writer.write_i32_be(self.rect.top)
  writer.write_i32_be(self.rect.left)
  writer.write_i32_be(self.rect.bottom)
  writer.write_i32_be(self.rect.right)
  // Channel count + info
  writer.write_u16_be(self.channels.length().reinterpret_as_uint())
  for i = 0; i < self.channels.length(); i = i + 1 {
    writer.write_i16_be(self.channels[i].channel_id)
    writer.write_length(self.channels[i].data_length, version)
  }
  // Blend mode
  writer.write_bytes(blend_signature)
  writer.write_bytes(self.blend_mode.to_bytes())
  // Opacity, clipping, flags, filler
  writer.write_u8(self.opacity.to_byte())
  writer.write_u8(self.clipping.to_byte())
  writer.write_u8(self.flags.to_byte())
  writer.write_u8(b'\x00') // filler
  // Extra data length: need to calculate
  let extra_length = calc_extra_length(self, version)
  writer.write_u32_be(extra_length.reinterpret_as_uint())
  // Mask data
  writer.write_u32_be(self.mask_data.length().reinterpret_as_uint())
  if self.mask_data.length() > 0 {
    writer.write_bytes(self.mask_data)
  }
  // Blending ranges
  writer.write_u32_be(self.blending_ranges.length().reinterpret_as_uint())
  if self.blending_ranges.length() > 0 {
    writer.write_bytes(self.blending_ranges)
  }
  // Layer name
  write_pascal_string_4byte(writer, self.name)
  // Additional layer info
  build_additional_layer_infos(self.additional_info, writer, version)
}

///|
fn calc_extra_length(record : LayerRecord, version : @types.PsdVersion) -> Int {
  let mut len = 0
  // Mask data: 4 (length field) + data
  len += 4 + record.mask_data.length()
  // Blending ranges: 4 (length field) + data
  len += 4 + record.blending_ranges.length()
  // Layer name: Pascal string with 4-byte padding
  let name_len = record.name.length()
  let pascal_len = 1 + name_len // 1 byte length + string data
  let padded_len = (pascal_len + 3) / 4 * 4 // round up to 4-byte boundary
  len += padded_len
  // Additional layer info
  len += calc_ali_total_length(record.additional_info, version)
  len
}

///|
/// Read a Pascal string padded to 4-byte boundary.
fn read_pascal_string_4byte(
  reader : @binary.Reader,
) -> String raise @types.PsdError {
  let start = reader.position()
  let len = reader.read_u8().to_int()
  let str_bytes = if len > 0 { reader.read_bytes(len) } else { b"" }
  // Pad to 4-byte boundary: total consumed = 1 + len, pad to next multiple of 4
  let consumed = reader.position() - start
  let padded = (consumed + 3) / 4 * 4
  let pad = padded - consumed
  if pad > 0 {
    reader.skip(pad)
  }
  @binary.bytes_to_ascii(str_bytes)
}

///|
/// Write a Pascal string padded to 4-byte boundary.
fn write_pascal_string_4byte(writer : @binary.Writer, s : String) -> Unit {
  let len = s.length()
  writer.write_u8(len.to_byte())
  for i = 0; i < len; i = i + 1 {
    writer.write_u8(s[i].to_int().to_byte())
  }
  // Pad to 4-byte boundary
  let consumed = 1 + len
  let padded = (consumed + 3) / 4 * 4
  let pad = padded - consumed
  for _i = 0; _i < pad; _i = _i + 1 {
    writer.write_u8(b'\x00')
  }
}

///|
/// Channel ID -1 = transparency mask.
pub fn ChannelInfo::is_transparency(self : ChannelInfo) -> Bool {
  self.channel_id == -1
}

///|
/// Channel ID -2 = user supplied layer mask.
pub fn ChannelInfo::is_user_mask(self : ChannelInfo) -> Bool {
  self.channel_id == -2
}

///|
/// Channel ID -3 = real user supplied layer mask (when both vector and user mask present).
pub fn ChannelInfo::is_real_mask(self : ChannelInfo) -> Bool {
  self.channel_id == -3
}
