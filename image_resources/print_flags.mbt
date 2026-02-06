///|
/// PrintFlags (ID 1011) - 9 bytes of boolean flags.
pub(all) struct PrintFlags {
  labels : Bool
  crop_marks : Bool
  color_bars : Bool
  registration_marks : Bool
  negative : Bool
  flip : Bool
  interpolate : Bool
  caption : Bool
  print_flags : Bool
} derive(Eq, Show)

///|
/// Parse PrintFlags from an ImageResourceBlock (ID 1011).
pub fn ImageResourceBlock::as_print_flags(
  self : ImageResourceBlock,
) -> PrintFlags? {
  if self.resource_id != 1011 || self.data.length() < 9 {
    return None
  }
  Some({
    labels: self.data[0] != b'\x00',
    crop_marks: self.data[1] != b'\x00',
    color_bars: self.data[2] != b'\x00',
    registration_marks: self.data[3] != b'\x00',
    negative: self.data[4] != b'\x00',
    flip: self.data[5] != b'\x00',
    interpolate: self.data[6] != b'\x00',
    caption: self.data[7] != b'\x00',
    print_flags: self.data[8] != b'\x00',
  })
}

///|
/// Create a PrintFlags resource block.
pub fn ImageResourceBlock::from_print_flags(
  flags : PrintFlags,
) -> ImageResourceBlock {
  fn bool_byte(b : Bool) -> Byte {
    if b {
      b'\x01'
    } else {
      b'\x00'
    }
  }

  let data = Bytes::from_array([
    bool_byte(flags.labels),
    bool_byte(flags.crop_marks),
    bool_byte(flags.color_bars),
    bool_byte(flags.registration_marks),
    bool_byte(flags.negative),
    bool_byte(flags.flip),
    bool_byte(flags.interpolate),
    bool_byte(flags.caption),
    bool_byte(flags.print_flags),
  ])
  { resource_id: 1011, name: "", data }
}

///|
/// PrintFlagsInfo (ID 10000) - version(2) + centerCrop(1) + pad(1) + bleedWidth(4) + bleedScale(2)
pub(all) struct PrintFlagsInfo {
  version : Int
  center_crop : Bool
  bleed_width : Int
  bleed_scale : Int
} derive(Eq, Show)

///|
/// Parse PrintFlagsInfo from an ImageResourceBlock (ID 10000).
pub fn ImageResourceBlock::as_print_flags_info(
  self : ImageResourceBlock,
) -> PrintFlagsInfo? {
  if self.resource_id != 10000 || self.data.length() < 10 {
    return None
  }
  let reader = @binary.Reader::new(self.data)
  try {
    let version = reader.read_u16_be().reinterpret_as_int()
    let center_crop = reader.read_u8() != b'\x00'
    let _pad = reader.read_u8()
    let bleed_width = reader.read_u32_be().reinterpret_as_int()
    let bleed_scale = reader.read_u16_be().reinterpret_as_int()
    Some({ version, center_crop, bleed_width, bleed_scale })
  } catch {
    _ => None
  }
}

///|
/// Create a PrintFlagsInfo resource block.
pub fn ImageResourceBlock::from_print_flags_info(
  info : PrintFlagsInfo,
) -> ImageResourceBlock {
  let w = @binary.Writer::new()
  w.write_u16_be(info.version.reinterpret_as_uint())
  w.write_u8(if info.center_crop { b'\x01' } else { b'\x00' })
  w.write_u8(b'\x00') // padding
  w.write_u32_be(info.bleed_width.reinterpret_as_uint())
  w.write_u16_be(info.bleed_scale.reinterpret_as_uint())
  { resource_id: 10000, name: "", data: w.to_bytes() }
}
