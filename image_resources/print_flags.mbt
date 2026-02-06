// Image Resources: Print Flags
//
// PSD File Format Specification, "Image Resources" section.

///|
/// Print Flags (ID 1011).
///
/// Spec: "0x03F3 (Photoshop 2.0)"
///   "Print flags. A series of one-byte boolean values (see Page Setup dialog):
///    labels, crop marks, color bars, registration marks, negative, flip,
///    interpolate, caption, print flags."
///   | Offset | Description          |
///   |--------|----------------------|
///   | 0      | Labels               |
///   | 1      | Crop marks           |
///   | 2      | Color bars           |
///   | 3      | Registration marks   |
///   | 4      | Negative             |
///   | 5      | Flip                 |
///   | 6      | Interpolate          |
///   | 7      | Caption              |
///   | 8      | Print flags          |
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
/// Print Flags Information (ID 10000).
///
/// Spec: "0x2710"
///   "Print flags information. 2 bytes version (= 1), 1 byte center crop marks,
///    1 byte (= 0), 4 bytes bleed width value, 2 bytes bleed width scale."
///   | Length | Description         |
///   |--------|---------------------|
///   | 2      | Version (= 1)      |
///   | 1      | Center crop marks   |
///   | 1      | Padding (= 0)      |
///   | 4      | Bleed width value   |
///   | 2      | Bleed width scale   |
pub(all) struct PrintFlagsInfo {
  version : Int
  center_crop : Bool
  bleed_width : Int
  bleed_scale : Int
} derive(Eq, Show)

///|
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
