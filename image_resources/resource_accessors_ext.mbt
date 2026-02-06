///|
/// AlphaChannelNames (ID 1006) - sequence of Pascal strings.
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
        names.push(bytes_to_ascii(str_bytes))
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
/// Create AlphaChannelNames resource block.
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
/// Caption (ID 1008) - Pascal string.
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
/// Create a Caption resource block.
pub fn ImageResourceBlock::from_caption(caption : String) -> ImageResourceBlock {
  let w = @binary.Writer::new()
  w.write_u8(caption.length().to_byte())
  for i = 0; i < caption.length(); i = i + 1 {
    w.write_u8(caption[i].to_int().to_byte())
  }
  { resource_id: 1008, name: "", data: w.to_bytes() }
}

///|
/// BackgroundColor (ID 1010) - 10 bytes: color space (2) + 4 components (4x2).
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
/// CopyrightFlag (ID 1034) - 1 byte boolean.
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
/// URL (ID 1035) - raw string.
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
/// LayerStateInfo (ID 1024) - 2 bytes: target layer index.
pub fn ImageResourceBlock::as_layer_state_info(
  self : ImageResourceBlock,
) -> Int? {
  if self.resource_id != 1024 || self.data.length() < 2 {
    return None
  }
  let reader = @binary.Reader::new(self.data)
  Some(reader.read_u16_be().reinterpret_as_int()) catch {
    _ => None
  }
}

///|
pub fn ImageResourceBlock::from_layer_state_info(
  target_layer : Int,
) -> ImageResourceBlock {
  let w = @binary.Writer::new()
  w.write_u16_be(target_layer.reinterpret_as_uint())
  { resource_id: 1024, name: "", data: w.to_bytes() }
}

///|
/// LayerGroupInfo (ID 1025) - array of UInt16 group IDs.
pub fn ImageResourceBlock::as_layer_group_info(
  self : ImageResourceBlock,
) -> Array[Int]? {
  if self.resource_id != 1025 {
    return None
  }
  let reader = @binary.Reader::new(self.data)
  let ids : Array[Int] = []
  try {
    while reader.remaining() >= 2 {
      ids.push(reader.read_u16_be().reinterpret_as_int())
    }
  } catch {
    _ => ()
  }
  Some(ids)
}

///|
pub fn ImageResourceBlock::from_layer_group_info(
  ids : Array[Int],
) -> ImageResourceBlock {
  let w = @binary.Writer::new()
  for i = 0; i < ids.length(); i = i + 1 {
    w.write_u16_be(ids[i].reinterpret_as_uint())
  }
  { resource_id: 1025, name: "", data: w.to_bytes() }
}

///|
/// VersionInfo (ID 1057).
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
/// PixelAspectRatio (ID 1064) - version(4) + double(8).
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
/// LayerSelectionIDs (ID 1069) - count + array of layer IDs.
pub fn ImageResourceBlock::as_layer_selection_ids(
  self : ImageResourceBlock,
) -> Array[Int]? {
  if self.resource_id != 1069 || self.data.length() < 2 {
    return None
  }
  let reader = @binary.Reader::new(self.data)
  try {
    let count = reader.read_u16_be().reinterpret_as_int()
    let ids : Array[Int] = []
    for _i = 0; _i < count; _i = _i + 1 {
      ids.push(reader.read_u32_be().reinterpret_as_int())
    }
    Some(ids)
  } catch {
    _ => None
  }
}

///|
pub fn ImageResourceBlock::from_layer_selection_ids(
  ids : Array[Int],
) -> ImageResourceBlock {
  let w = @binary.Writer::new()
  w.write_u16_be(ids.length().reinterpret_as_uint())
  for i = 0; i < ids.length(); i = i + 1 {
    w.write_u32_be(ids[i].reinterpret_as_uint())
  }
  { resource_id: 1069, name: "", data: w.to_bytes() }
}

///|
/// LayerGroupsEnabledID (ID 1072) - array of bytes (enabled flags).
pub fn ImageResourceBlock::as_layer_groups_enabled(
  self : ImageResourceBlock,
) -> Array[Bool]? {
  if self.resource_id != 1072 {
    return None
  }
  let flags : Array[Bool] = []
  for i = 0; i < self.data.length(); i = i + 1 {
    flags.push(self.data[i] != b'\x00')
  }
  Some(flags)
}

///|
pub fn ImageResourceBlock::from_layer_groups_enabled(
  flags : Array[Bool],
) -> ImageResourceBlock {
  let buf = @buffer.new(size_hint=flags.length())
  for i = 0; i < flags.length(); i = i + 1 {
    buf.write_byte(if flags[i] { b'\x01' } else { b'\x00' })
  }
  { resource_id: 1072, name: "", data: buf.to_bytes() }
}

///|
/// URLList (ID 1054) - count + (long, ID, string) triples.
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
/// OriginID (ID 1044) - UInt32, base value for layer IDs.
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
/// UnicodeAlphaNames (ID 1045) - Array of Unicode strings.
/// Each string: 4-byte length + UTF-16BE characters.
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
/// IndexedColorTableCount (ID 1046) - UInt16.
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
/// AlphaIdentifiers (ID 1051) - Array of UInt32.
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

///|
/// DocumentSpecificIDs (ID 1081) - UInt32, base value for generating layer IDs.
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
/// Document-specific IDs seed (ID 1043) - UInt32.
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
/// AutoSaveFilePath (ID 1086) - Unicode string.
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
/// AutoSaveFormat (ID 1087) - Unicode string.
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

///|
/// PrintScale (ID 1089) - style(2) + x_location(float32) + y_location(float32) + scale(float32).
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
/// ICCUntaggedProfile (ID 1074) - 1 byte boolean.
/// Disables any assumed profile handling when opening.
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
