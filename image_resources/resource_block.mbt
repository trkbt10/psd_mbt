///|
let resource_signature : Bytes = b"\x38\x42\x49\x4D"

///|
pub(all) struct ImageResourceBlock {
  resource_id : Int
  name : String
  data : Bytes
} derive(Eq, Show)

///|
pub fn ImageResourceBlock::parse(
  reader : @binary.Reader,
) -> ImageResourceBlock raise @types.PsdError {
  // Signature '8BIM'
  let sig = reader.read_bytes(4)
  if sig != resource_signature {
    raise @types.InvalidSignature(sig)
  }
  // Resource ID
  let resource_id = reader.read_u16_be().reinterpret_as_int()
  // Pascal string name (padded to even boundary)
  let name = read_pascal_string_even(reader)
  // Data length + data (padded to even boundary)
  let data_length = reader.read_u32_be().reinterpret_as_int()
  let data = if data_length > 0 { reader.read_bytes(data_length) } else { b"" }
  // Skip padding if data length is odd
  if data_length % 2 != 0 {
    reader.skip(1)
  }
  { resource_id, name, data }
}

///|
pub fn ImageResourceBlock::build(
  self : ImageResourceBlock,
  writer : @binary.Writer,
) -> Unit {
  // Signature
  writer.write_bytes(resource_signature)
  // Resource ID
  writer.write_u16_be(self.resource_id.reinterpret_as_uint())
  // Pascal string name (padded to even boundary)
  write_pascal_string_even(writer, self.name)
  // Data length
  writer.write_u32_be(self.data.length().reinterpret_as_uint())
  // Data
  if self.data.length() > 0 {
    writer.write_bytes(self.data)
  }
  // Padding if data length is odd
  if self.data.length() % 2 != 0 {
    writer.write_u8(b'\x00')
  }
}

///|
/// Read a Pascal string padded to even boundary.
/// Format: 1 byte length + N bytes string data + padding to make total even.
fn read_pascal_string_even(
  reader : @binary.Reader,
) -> String raise @types.PsdError {
  let len = reader.read_u8().to_int()
  let str_bytes = if len > 0 { reader.read_bytes(len) } else { b"" }
  // Total bytes read so far: 1 (length) + len (data)
  // Pad to even: if (1 + len) is odd, skip 1 byte
  if (1 + len) % 2 != 0 {
    reader.skip(1)
  }
  @binary.bytes_to_ascii(str_bytes)
}

///|
/// Write a Pascal string padded to even boundary.
fn write_pascal_string_even(writer : @binary.Writer, s : String) -> Unit {
  let len = s.length()
  writer.write_u8(len.to_byte())
  for i = 0; i < len; i = i + 1 {
    writer.write_u8(s[i].to_int().to_byte())
  }
  // Pad to even: if (1 + len) is odd, write padding byte
  if (1 + len) % 2 != 0 {
    writer.write_u8(b'\x00')
  }
}
