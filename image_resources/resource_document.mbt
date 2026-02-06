// Image Resources: Document-level metadata, URLs, version, and print accessors
//
// PSD File Format Specification, "Image Resources" section.

///|
/// Caption (ID 1008).
///
/// Spec: "0x03F0 (Photoshop 2.0)"
///   "Caption. Pascal string."
pub fn ImageResourceBlock::as_caption(self : ImageResourceBlock) -> String? {
  if self.resource_id != 1008 || self.data.length() < 1 {
    return None
  }
  let len = self.data[0].to_int()
  if self.data.length() < 1 + len {
    return None
  }
  let buf = @buffer.new(size_hint=len)
  for i = 0; i < len; i = i + 1 {
    buf.write_char(self.data[1 + i].to_int().unsafe_to_char())
  }
  Some(buf.to_string())
}

///|
pub fn ImageResourceBlock::from_caption(caption : String) -> ImageResourceBlock {
  let w = @binary.Writer::new()
  w.write_u8(caption.length().to_byte())
  for i = 0; i < caption.length(); i = i + 1 {
    w.write_u8(caption[i].to_int().to_byte())
  }
  { resource_id: 1008, name: "", data: w.to_bytes() }
}

///|
/// Copyright Flag (ID 1034).
///
/// Spec: "0x040A (Photoshop 4.0)"
///   "Copyright flag. Boolean indicating whether image is copyrighted.
///    Can be set via Property suite or by user in File Info..."
pub fn ImageResourceBlock::as_copyright_flag(
  self : ImageResourceBlock,
) -> Bool? {
  if self.resource_id != 1034 || self.data.length() < 1 {
    return None
  }
  Some(self.data[0] != b'\x00')
}

///|
pub fn ImageResourceBlock::from_copyright_flag(
  flag : Bool,
) -> ImageResourceBlock {
  let data = Bytes::from_array([if flag { b'\x01' } else { b'\x00' }])
  { resource_id: 1034, name: "", data }
}

///|
/// URL (ID 1035).
///
/// Spec: "0x040B (Photoshop 4.0)"
///   "URL. Handle of a text string with uniform resource locator."
pub fn ImageResourceBlock::as_url(self : ImageResourceBlock) -> String? {
  if self.resource_id != 1035 {
    return None
  }
  let buf = @buffer.new(size_hint=self.data.length())
  for i = 0; i < self.data.length(); i = i + 1 {
    buf.write_char(self.data[i].to_int().unsafe_to_char())
  }
  Some(buf.to_string())
}

///|
pub fn ImageResourceBlock::from_url(url : String) -> ImageResourceBlock {
  let buf = @buffer.new(size_hint=url.length())
  for i = 0; i < url.length(); i = i + 1 {
    buf.write_byte(url[i].to_int().to_byte())
  }
  { resource_id: 1035, name: "", data: buf.to_bytes() }
}

///|
/// Document-Specific IDs Seed (ID 1043).
///
/// Spec: "0x0413 (Photoshop 5.0)"
///   "Document-Specific IDs seed number. 4 bytes: Base value, starting at
///    which layer IDs will be generated (or a greater value if existing IDs
///    already exceed it). Its purpose is to avoid the case where we add
///    layers, flatten, save, open, and then add more layers that end up with
///    the same IDs as the first set."
pub fn ImageResourceBlock::as_document_ids_seed(
  self : ImageResourceBlock,
) -> Int? {
  if self.resource_id != 1043 || self.data.length() < 4 {
    return None
  }
  let reader = @binary.Reader::new(self.data)
  Some(reader.read_u32_be().reinterpret_as_int()) catch {
    _ => None
  }
}

///|
pub fn ImageResourceBlock::from_document_ids_seed(
  seed : Int,
) -> ImageResourceBlock {
  let w = @binary.Writer::new()
  w.write_u32_be(seed.reinterpret_as_uint())
  { resource_id: 1043, name: "", data: w.to_bytes() }
}

///|
/// Origin Path Info (ID 1044).
///
/// Spec: "0x0414"
///   "Origin Path Info."
///   4 bytes: UInt32 base value for layer IDs.
pub fn ImageResourceBlock::as_origin_id(self : ImageResourceBlock) -> Int? {
  if self.resource_id != 1044 || self.data.length() < 4 {
    return None
  }
  let reader = @binary.Reader::new(self.data)
  Some(reader.read_u32_be().reinterpret_as_int()) catch {
    _ => None
  }
}

///|
pub fn ImageResourceBlock::from_origin_id(id : Int) -> ImageResourceBlock {
  let w = @binary.Writer::new()
  w.write_u32_be(id.reinterpret_as_uint())
  { resource_id: 1044, name: "", data: w.to_bytes() }
}

///|
/// URL List (ID 1054).
///
/// Spec: "0x041E (Photoshop 6.0)"
///   "URL List. 4 byte count of URLs, followed by 4 byte long,
///    4 byte ID, and Unicode string for each count."
pub(all) struct URLListEntry {
  long_val : Int
  id : Int
  url : String
} derive(Eq, Show)

///|
pub fn ImageResourceBlock::as_url_list(
  self : ImageResourceBlock,
) -> Array[URLListEntry]? {
  if self.resource_id != 1054 || self.data.length() < 4 {
    return None
  }
  let reader = @binary.Reader::new(self.data)
  try {
    let count = reader.read_u32_be().reinterpret_as_int()
    let entries : Array[URLListEntry] = []
    for _i = 0; _i < count; _i = _i + 1 {
      let long_val = reader.read_u32_be().reinterpret_as_int()
      let id = reader.read_u32_be().reinterpret_as_int()
      // Unicode string
      let str_len = reader.read_u32_be().reinterpret_as_int()
      let buf = @buffer.new(size_hint=str_len)
      for _j = 0; _j < str_len; _j = _j + 1 {
        let code = reader.read_u16_be().reinterpret_as_int()
        buf.write_char(code.unsafe_to_char())
      }
      entries.push({ long_val, id, url: buf.to_string() })
    }
    Some(entries)
  } catch {
    _ => None
  }
}

///|
pub fn ImageResourceBlock::from_url_list(
  entries : Array[URLListEntry],
) -> ImageResourceBlock {
  let w = @binary.Writer::new()
  w.write_u32_be(entries.length().reinterpret_as_uint())
  for i = 0; i < entries.length(); i = i + 1 {
    let e = entries[i]
    w.write_u32_be(e.long_val.reinterpret_as_uint())
    w.write_u32_be(e.id.reinterpret_as_uint())
    w.write_u32_be(e.url.length().reinterpret_as_uint())
    for j = 0; j < e.url.length(); j = j + 1 {
      w.write_u16_be(e.url[j].to_int().reinterpret_as_uint())
    }
  }
  { resource_id: 1054, name: "", data: w.to_bytes() }
}

///|
/// Version Info (ID 1057).
///
/// Spec: "0x0421 (Photoshop 6.0)"
///   "Version Info. 4 bytes version, 1 byte hasRealMergedData,
///    Unicode string: writer name, Unicode string: reader name,
///    4 bytes file version."
pub(all) struct VersionInfo {
  version : Int
  has_real_merged_data : Bool
  writer_name : String
  reader_name : String
  file_version : Int
} derive(Eq, Show)

///|
pub fn ImageResourceBlock::as_version_info(
  self : ImageResourceBlock,
) -> VersionInfo? {
  if self.resource_id != 1057 || self.data.length() < 13 {
    return None
  }
  let reader = @binary.Reader::new(self.data)
  try {
    let version = reader.read_u32_be().reinterpret_as_int()
    let has_real_merged_data = reader.read_u8() != b'\x00'
    // Unicode string: length (4 bytes) + UTF-16BE chars
    let writer_len = reader.read_u32_be().reinterpret_as_int()
    let writer_buf = @buffer.new(size_hint=writer_len)
    for _i = 0; _i < writer_len; _i = _i + 1 {
      let code = reader.read_u16_be().reinterpret_as_int()
      writer_buf.write_char(code.unsafe_to_char())
    }
    let writer_name = writer_buf.to_string()
    let reader_len = reader.read_u32_be().reinterpret_as_int()
    let reader_buf = @buffer.new(size_hint=reader_len)
    for _i = 0; _i < reader_len; _i = _i + 1 {
      let code = reader.read_u16_be().reinterpret_as_int()
      reader_buf.write_char(code.unsafe_to_char())
    }
    let reader_name = reader_buf.to_string()
    let file_version = reader.read_u32_be().reinterpret_as_int()
    Some({
      version,
      has_real_merged_data,
      writer_name,
      reader_name,
      file_version,
    })
  } catch {
    _ => None
  }
}

///|
pub fn ImageResourceBlock::from_version_info(
  info : VersionInfo,
) -> ImageResourceBlock {
  let w = @binary.Writer::new()
  w.write_u32_be(info.version.reinterpret_as_uint())
  w.write_u8(if info.has_real_merged_data { b'\x01' } else { b'\x00' })
  // Unicode string: length + UTF-16BE
  w.write_u32_be(info.writer_name.length().reinterpret_as_uint())
  for i = 0; i < info.writer_name.length(); i = i + 1 {
    w.write_u16_be(info.writer_name[i].to_int().reinterpret_as_uint())
  }
  w.write_u32_be(info.reader_name.length().reinterpret_as_uint())
  for i = 0; i < info.reader_name.length(); i = i + 1 {
    w.write_u16_be(info.reader_name[i].to_int().reinterpret_as_uint())
  }
  w.write_u32_be(info.file_version.reinterpret_as_uint())
  { resource_id: 1057, name: "", data: w.to_bytes() }
}

///|
/// Pixel Aspect Ratio (ID 1064).
///
/// Spec: "0x0428 (Photoshop CS)"
///   "Pixel Aspect Ratio. 4 bytes (version = 1 or 2),
///    8 bytes double, x / y of a pixel. Version 2, attempting
///    to correct values for NTSC and PAL, previously off by a factor of approx. 5%."
pub(all) struct PixelAspectRatio {
  version : Int
  aspect_ratio : Double
} derive(Eq, Show)

///|
pub fn ImageResourceBlock::as_pixel_aspect_ratio(
  self : ImageResourceBlock,
) -> PixelAspectRatio? {
  if self.resource_id != 1064 || self.data.length() < 12 {
    return None
  }
  let reader = @binary.Reader::new(self.data)
  try {
    let version = reader.read_u32_be().reinterpret_as_int()
    let bits = reader.read_u64_be()
    let aspect_ratio = bits.reinterpret_as_double()
    Some({ version, aspect_ratio })
  } catch {
    _ => None
  }
}

///|
pub fn ImageResourceBlock::from_pixel_aspect_ratio(
  info : PixelAspectRatio,
) -> ImageResourceBlock {
  let w = @binary.Writer::new()
  w.write_u32_be(info.version.reinterpret_as_uint())
  w.write_u64_be(info.aspect_ratio.reinterpret_as_uint64())
  { resource_id: 1064, name: "", data: w.to_bytes() }
}

///|
/// ICC Untagged Profile (ID 1074).
///
/// Spec: "0x0432 (Photoshop CS3)"
///   "ICC Untagged Profile. 1 byte that disables any assumed profile
///    handling when opening the file. 1 = intentionally untagged."
pub fn ImageResourceBlock::as_icc_untagged(self : ImageResourceBlock) -> Bool? {
  if self.resource_id != 1074 || self.data.length() < 1 {
    return None
  }
  Some(self.data[0] != b'\x00')
}

///|
pub fn ImageResourceBlock::from_icc_untagged(
  untagged : Bool,
) -> ImageResourceBlock {
  let data = Bytes::from_array([if untagged { b'\x01' } else { b'\x00' }])
  { resource_id: 1074, name: "", data }
}

///|
/// Document-Specific IDs (ID 1081).
///
/// Spec: "0x0439 (Photoshop CS3)"
///   "Document specific IDs. 4 bytes (nonce), base value for generating
///    unique layer IDs across the document."
pub fn ImageResourceBlock::as_document_specific_ids(
  self : ImageResourceBlock,
) -> Int? {
  if self.resource_id != 1081 || self.data.length() < 4 {
    return None
  }
  let reader = @binary.Reader::new(self.data)
  Some(reader.read_u32_be().reinterpret_as_int()) catch {
    _ => None
  }
}

///|
pub fn ImageResourceBlock::from_document_specific_ids(
  id : Int,
) -> ImageResourceBlock {
  let w = @binary.Writer::new()
  w.write_u32_be(id.reinterpret_as_uint())
  { resource_id: 1081, name: "", data: w.to_bytes() }
}

///|
/// Auto Save File Path (ID 1086).
///
/// Spec: "0x043E (Photoshop CC)"
///   "Auto Save File Path. Unicode string."
pub fn ImageResourceBlock::as_auto_save_file_path(
  self : ImageResourceBlock,
) -> String? {
  if self.resource_id != 1086 {
    return None
  }
  parse_unicode_resource_string(self.data)
}

///|
pub fn ImageResourceBlock::from_auto_save_file_path(
  path : String,
) -> ImageResourceBlock {
  { resource_id: 1086, name: "", data: build_unicode_resource_string(path) }
}

///|
/// Auto Save Format (ID 1087).
///
/// Spec: "0x043F (Photoshop CC)"
///   "Auto Save Format. Unicode string."
pub fn ImageResourceBlock::as_auto_save_format(
  self : ImageResourceBlock,
) -> String? {
  if self.resource_id != 1087 {
    return None
  }
  parse_unicode_resource_string(self.data)
}

///|
pub fn ImageResourceBlock::from_auto_save_format(
  format : String,
) -> ImageResourceBlock {
  { resource_id: 1087, name: "", data: build_unicode_resource_string(format) }
}

///|
/// Print Scale (ID 1089).
///
/// Spec: "0x0441"
///   "Print scale. 2 bytes style (0 = centered, 1 = size to fit,
///    2 = user defined). 4 bytes x location (floating point).
///    4 bytes y location (floating point). 4 bytes scale (floating point)."
pub(all) struct PrintScale {
  style : Int // 0=centered, 1=size to fit, 2=user defined
  x_location : Double
  y_location : Double
  scale : Double
} derive(Eq, Show)

///|
pub fn ImageResourceBlock::as_print_scale(
  self : ImageResourceBlock,
) -> PrintScale? {
  if self.resource_id != 1089 || self.data.length() < 14 {
    return None
  }
  let reader = @binary.Reader::new(self.data)
  try {
    let style = reader.read_u16_be().reinterpret_as_int()
    // Float32: read 4 bytes as UInt32, reinterpret as Float
    let x_bits = reader.read_u32_be()
    let y_bits = reader.read_u32_be()
    let s_bits = reader.read_u32_be()
    let x_location = Float::reinterpret_from_uint(x_bits).to_double()
    let y_location = Float::reinterpret_from_uint(y_bits).to_double()
    let scale = Float::reinterpret_from_uint(s_bits).to_double()
    Some({ style, x_location, y_location, scale })
  } catch {
    _ => None
  }
}

///|
pub fn ImageResourceBlock::from_print_scale(
  info : PrintScale,
) -> ImageResourceBlock {
  let w = @binary.Writer::new()
  w.write_u16_be(info.style.reinterpret_as_uint())
  w.write_u32_be(Float::from_double(info.x_location).reinterpret_as_uint())
  w.write_u32_be(Float::from_double(info.y_location).reinterpret_as_uint())
  w.write_u32_be(Float::from_double(info.scale).reinterpret_as_uint())
  { resource_id: 1089, name: "", data: w.to_bytes() }
}

///|
/// Parse a Unicode string resource: 4-byte length + UTF-16BE chars.
fn parse_unicode_resource_string(data : Bytes) -> String? {
  if data.length() < 4 {
    return None
  }
  let reader = @binary.Reader::new(data)
  try {
    let len = reader.read_u32_be().reinterpret_as_int()
    let buf = @buffer.new(size_hint=len)
    for _i = 0; _i < len; _i = _i + 1 {
      let code = reader.read_u16_be().reinterpret_as_int()
      buf.write_char(code.unsafe_to_char())
    }
    Some(buf.to_string())
  } catch {
    _ => None
  }
}

///|
/// Build a Unicode string resource: 4-byte length + UTF-16BE chars.
fn build_unicode_resource_string(s : String) -> Bytes {
  let w = @binary.Writer::new()
  w.write_u32_be(s.length().reinterpret_as_uint())
  for i = 0; i < s.length(); i = i + 1 {
    w.write_u16_be(s[i].to_int().reinterpret_as_uint())
  }
  w.to_bytes()
}
