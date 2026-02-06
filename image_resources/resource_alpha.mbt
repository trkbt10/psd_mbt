// Image Resources: Alpha channel and color-related resource accessors
//
// PSD File Format Specification, "Image Resources" section.

///|
/// Alpha Channels Names (ID 1006).
///
/// Spec: "0x03F2 (Photoshop 2.0)"
///   "Alpha channels names. Series of Pascal strings."
pub fn ImageResourceBlock::as_alpha_channel_names(
  self : ImageResourceBlock,
) -> Array[String]? {
  if self.resource_id != 1006 {
    return None
  }
  let names : Array[String] = []
  let reader = @binary.Reader::new(self.data)
  try {
    while reader.remaining() > 0 {
      let len = reader.read_u8().to_int()
      if len > 0 {
        let str_bytes = reader.read_bytes(len)
        names.push(@binary.bytes_to_ascii(str_bytes))
      } else {
        names.push("")
      }
    }
  } catch {
    _ => ()
  }
  Some(names)
}

///|
pub fn ImageResourceBlock::from_alpha_channel_names(
  names : Array[String],
) -> ImageResourceBlock {
  let w = @binary.Writer::new()
  for i = 0; i < names.length(); i = i + 1 {
    let s = names[i]
    w.write_u8(s.length().to_byte())
    for j = 0; j < s.length(); j = j + 1 {
      w.write_u8(s[j].to_int().to_byte())
    }
  }
  { resource_id: 1006, name: "", data: w.to_bytes() }
}

///|
/// Background Color (ID 1010).
///
/// Spec: "0x03F2 (Photoshop 2.0)"
///   "Background color. See See Color structure."
///   | Length | Description                            |
///   |--------|----------------------------------------|
///   | 2      | Color space (0=RGB, 1=HSB, 2=CMYK...) |
///   | 8      | Color components (4 x UInt16)          |
pub(all) struct BackgroundColor {
  color_space : Int
  components : Array[Int] // 4x UInt16
} derive(Eq, Show)

///|
pub fn ImageResourceBlock::as_background_color(
  self : ImageResourceBlock,
) -> BackgroundColor? {
  if self.resource_id != 1010 || self.data.length() < 10 {
    return None
  }
  let reader = @binary.Reader::new(self.data)
  try {
    let color_space = reader.read_u16_be().reinterpret_as_int()
    let c0 = reader.read_u16_be().reinterpret_as_int()
    let c1 = reader.read_u16_be().reinterpret_as_int()
    let c2 = reader.read_u16_be().reinterpret_as_int()
    let c3 = reader.read_u16_be().reinterpret_as_int()
    Some({ color_space, components: [c0, c1, c2, c3] })
  } catch {
    _ => None
  }
}

///|
pub fn ImageResourceBlock::from_background_color(
  bg : BackgroundColor,
) -> ImageResourceBlock {
  let w = @binary.Writer::new()
  w.write_u16_be(bg.color_space.reinterpret_as_uint())
  for i = 0; i < bg.components.length(); i = i + 1 {
    w.write_u16_be(bg.components[i].reinterpret_as_uint())
  }
  { resource_id: 1010, name: "", data: w.to_bytes() }
}

///|
/// Unicode Alpha Names (ID 1045).
///
/// Spec: "0x0415 (Photoshop 6.0)"
///   "Unicode Alpha Names. Unicode string (4 bytes length followed by string)."
///   Sequence of: 4-byte length + UTF-16BE characters for each alpha channel.
pub fn ImageResourceBlock::as_unicode_alpha_names(
  self : ImageResourceBlock,
) -> Array[String]? {
  if self.resource_id != 1045 {
    return None
  }
  let reader = @binary.Reader::new(self.data)
  let names : Array[String] = []
  try {
    while reader.remaining() >= 4 {
      let len = reader.read_u32_be().reinterpret_as_int()
      let buf = @buffer.new(size_hint=len)
      for _j = 0; _j < len; _j = _j + 1 {
        let code = reader.read_u16_be().reinterpret_as_int()
        buf.write_char(code.unsafe_to_char())
      }
      names.push(buf.to_string())
    }
  } catch {
    _ => ()
  }
  Some(names)
}

///|
pub fn ImageResourceBlock::from_unicode_alpha_names(
  names : Array[String],
) -> ImageResourceBlock {
  let w = @binary.Writer::new()
  for i = 0; i < names.length(); i = i + 1 {
    let s = names[i]
    w.write_u32_be(s.length().reinterpret_as_uint())
    for j = 0; j < s.length(); j = j + 1 {
      w.write_u16_be(s[j].to_int().reinterpret_as_uint())
    }
  }
  { resource_id: 1045, name: "", data: w.to_bytes() }
}

///|
/// Indexed Color Table Count (ID 1046).
///
/// Spec: "0x0416 (Photoshop 6.0)"
///   "Indexed Color Table Count. 2 bytes for the number of colors in table
///    that are actually defined."
pub fn ImageResourceBlock::as_indexed_color_table_count(
  self : ImageResourceBlock,
) -> Int? {
  if self.resource_id != 1046 || self.data.length() < 2 {
    return None
  }
  let reader = @binary.Reader::new(self.data)
  Some(reader.read_u16_be().reinterpret_as_int()) catch {
    _ => None
  }
}

///|
pub fn ImageResourceBlock::from_indexed_color_table_count(
  count : Int,
) -> ImageResourceBlock {
  let w = @binary.Writer::new()
  w.write_u16_be(count.reinterpret_as_uint())
  { resource_id: 1046, name: "", data: w.to_bytes() }
}

///|
/// Alpha Identifiers (ID 1051).
///
/// Spec: "0x041B (Photoshop 6.0)"
///   "Alpha Identifiers. 4 bytes each, for Identifier."
///   Array of UInt32 identifiers, one per alpha channel.
pub fn ImageResourceBlock::as_alpha_identifiers(
  self : ImageResourceBlock,
) -> Array[Int]? {
  if self.resource_id != 1051 {
    return None
  }
  let reader = @binary.Reader::new(self.data)
  let ids : Array[Int] = []
  try {
    while reader.remaining() >= 4 {
      ids.push(reader.read_u32_be().reinterpret_as_int())
    }
  } catch {
    _ => ()
  }
  Some(ids)
}

///|
pub fn ImageResourceBlock::from_alpha_identifiers(
  ids : Array[Int],
) -> ImageResourceBlock {
  let w = @binary.Writer::new()
  for i = 0; i < ids.length(); i = i + 1 {
    w.write_u32_be(ids[i].reinterpret_as_uint())
  }
  { resource_id: 1051, name: "", data: w.to_bytes() }
}
