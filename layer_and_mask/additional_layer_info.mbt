///|
let ali_signature_8bim : Bytes = b"\x38\x42\x49\x4D"

///|
let ali_signature_8b64 : Bytes = b"\x38\x42\x36\x34"

///|
pub(all) struct AdditionalLayerInfo {
  signature : Bytes
  key : Bytes
  data : Bytes
} derive(Eq, Show)

///|
/// PSB extended-length keys: these keys use UInt64 length in PSB.
fn is_psb_extended_key(key : Bytes) -> Bool {
  key == b"LMsk" ||
  key == b"Lr16" ||
  key == b"Lr32" ||
  key == b"Layr" ||
  key == b"Mt16" ||
  key == b"Mt32" ||
  key == b"Mtrn" ||
  key == b"Alph" ||
  key == b"FMsk" ||
  key == b"lnk2" ||
  key == b"FEid" ||
  key == b"FXid" ||
  key == b"PxSD"
}

///|
pub fn AdditionalLayerInfo::parse(
  reader : @binary.Reader,
  version : @types.PsdVersion,
) -> AdditionalLayerInfo raise @types.PsdError {
  let signature = reader.read_bytes(4)
  if signature != ali_signature_8bim && signature != ali_signature_8b64 {
    raise @types.InvalidSignature(signature)
  }
  let key = reader.read_bytes(4)
  // Length: UInt64 for PSB extended keys, UInt32 otherwise
  let data_length = match version {
    Psb =>
      if is_psb_extended_key(key) {
        reader.read_u64_be().to_int()
      } else {
        reader.read_u32_be().reinterpret_as_int()
      }
    Psd => reader.read_u32_be().reinterpret_as_int()
  }
  let data = if data_length > 0 { reader.read_bytes(data_length) } else { b"" }
  // Skip padding if data length is odd (round to even)
  if data_length % 2 != 0 {
    reader.skip(1)
  }
  { signature, key, data }
}

///|
pub fn AdditionalLayerInfo::build(
  self : AdditionalLayerInfo,
  writer : @binary.Writer,
  version : @types.PsdVersion,
) -> Unit {
  writer.write_bytes(self.signature)
  writer.write_bytes(self.key)
  let data_length = self.data.length()
  // Length field: UInt64 for PSB extended keys, UInt32 otherwise
  match version {
    Psb =>
      if is_psb_extended_key(self.key) {
        writer.write_u64_be(data_length.to_uint64())
      } else {
        writer.write_u32_be(data_length.reinterpret_as_uint())
      }
    Psd => writer.write_u32_be(data_length.reinterpret_as_uint())
  }
  if data_length > 0 {
    writer.write_bytes(self.data)
  }
  // Padding if data length is odd
  if data_length % 2 != 0 {
    writer.write_u8(b'\x00')
  }
}

///|
/// Parse multiple AdditionalLayerInfo blocks from remaining bytes.
pub fn parse_additional_layer_infos(
  reader : @binary.Reader,
  byte_count : Int,
  version : @types.PsdVersion,
) -> Array[AdditionalLayerInfo] raise @types.PsdError {
  let result : Array[AdditionalLayerInfo] = []
  if byte_count <= 0 {
    return result
  }
  let start = reader.position()
  while reader.position() - start < byte_count {
    // Check if there are enough bytes for at least a signature (4 bytes)
    let remaining = byte_count - (reader.position() - start)
    if remaining < 12 {
      // Not enough for a valid ALI block, skip remaining
      if remaining > 0 {
        reader.skip(remaining)
      }
      break
    }
    result.push(AdditionalLayerInfo::parse(reader, version))
  }
  result
}

///|
/// Build multiple AdditionalLayerInfo blocks.
pub fn build_additional_layer_infos(
  infos : Array[AdditionalLayerInfo],
  writer : @binary.Writer,
  version : @types.PsdVersion,
) -> Unit {
  for i = 0; i < infos.length(); i = i + 1 {
    infos[i].build(writer, version)
  }
}

///|
/// Calculate the total byte length of multiple AdditionalLayerInfo blocks.
fn calc_ali_total_length(
  infos : Array[AdditionalLayerInfo],
  version : @types.PsdVersion,
) -> Int {
  let mut total = 0
  for i = 0; i < infos.length(); i = i + 1 {
    // signature (4) + key (4) + length field (4 or 8) + data + padding
    total += 4 + 4
    match version {
      Psb =>
        if is_psb_extended_key(infos[i].key) {
          total += 8
        } else {
          total += 4
        }
      Psd => total += 4
    }
    let data_len = infos[i].data.length()
    total += data_len
    if data_len % 2 != 0 {
      total += 1
    }
  }
  total
}

///|
pub(all) struct SectionDivider {
  divider_type : Int
  blend_mode : @types.BlendMode?
  sub_type : Int?
} derive(Eq, Show)

///|
/// Interpret as Unicode layer name if key is 'luni'.
pub fn AdditionalLayerInfo::as_unicode_name(
  self : AdditionalLayerInfo,
) -> String? {
  if self.key != b"luni" || self.data.length() < 4 {
    return None
  }
  let reader = @binary.Reader::new(self.data)
  try {
    let char_count = reader.read_u32_be().reinterpret_as_int()
    let buf = @buffer.new(size_hint=char_count)
    for _i = 0; _i < char_count; _i = _i + 1 {
      let code_unit = reader.read_u16_be().reinterpret_as_int()
      buf.write_char(code_unit.unsafe_to_char())
    }
    Some(buf.to_string())
  } catch {
    _ => None
  }
}

///|
/// Interpret as section divider if key is 'lsct' or 'lsdk'.
pub fn AdditionalLayerInfo::as_section_divider(
  self : AdditionalLayerInfo,
) -> SectionDivider? {
  if self.key != b"lsct" && self.key != b"lsdk" {
    return None
  }
  if self.data.length() < 4 {
    return None
  }
  let reader = @binary.Reader::new(self.data)
  try {
    let divider_type = reader.read_u32_be().reinterpret_as_int()
    let blend_mode : @types.BlendMode? = if self.data.length() >= 12 {
      let _sig = reader.read_bytes(4) // '8BIM'
      let bm_key = reader.read_bytes(4)
      Some(@types.BlendMode::from_bytes(bm_key))
    } else {
      None
    }
    let sub_type : Int? = if self.data.length() >= 16 {
      Some(reader.read_u32_be().reinterpret_as_int())
    } else {
      None
    }
    Some({ divider_type, blend_mode, sub_type })
  } catch {
    _ => None
  }
}
