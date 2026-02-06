///|
pub struct Reader {
  data : Bytes
  mut offset : Int
}

///|
pub fn Reader::new(data : Bytes) -> Reader {
  { data, offset: 0 }
}

///|
pub fn Reader::remaining(self : Reader) -> Int {
  self.data.length() - self.offset
}

///|
pub fn Reader::position(self : Reader) -> Int {
  self.offset
}

///|
pub fn Reader::read_u8(self : Reader) -> Byte raise @types.PsdError {
  if self.offset >= self.data.length() {
    raise @types.UnexpectedEof
  }
  let value = self.data[self.offset]
  self.offset += 1
  value
}

///|
pub fn Reader::read_u16_be(self : Reader) -> UInt raise @types.PsdError {
  if self.offset + 2 > self.data.length() {
    raise @types.UnexpectedEof
  }
  let b0 = self.data[self.offset].to_uint()
  let b1 = self.data[self.offset + 1].to_uint()
  self.offset += 2
  (b0 << 8) | b1
}

///|
pub fn Reader::read_i16_be(self : Reader) -> Int raise @types.PsdError {
  let u = self.read_u16_be()
  if u >= 0x8000U {
    u.reinterpret_as_int() - 0x10000
  } else {
    u.reinterpret_as_int()
  }
}

///|
pub fn Reader::read_u32_be(self : Reader) -> UInt raise @types.PsdError {
  if self.offset + 4 > self.data.length() {
    raise @types.UnexpectedEof
  }
  let b0 = self.data[self.offset].to_uint()
  let b1 = self.data[self.offset + 1].to_uint()
  let b2 = self.data[self.offset + 2].to_uint()
  let b3 = self.data[self.offset + 3].to_uint()
  self.offset += 4
  (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
}

///|
pub fn Reader::read_i32_be(self : Reader) -> Int raise @types.PsdError {
  self.read_u32_be().reinterpret_as_int()
}

///|
pub fn Reader::read_bytes(
  self : Reader,
  n : Int,
) -> Bytes raise @types.PsdError {
  if self.offset + n > self.data.length() {
    raise @types.UnexpectedEof
  }
  let buf = @buffer.new()
  for i = 0; i < n; i = i + 1 {
    buf.write_byte(self.data[self.offset + i])
  }
  self.offset += n
  buf.to_bytes()
}

///|
pub fn Reader::read_u64_be(self : Reader) -> UInt64 raise @types.PsdError {
  if self.offset + 8 > self.data.length() {
    raise @types.UnexpectedEof
  }
  let b0 = self.data[self.offset].to_uint64()
  let b1 = self.data[self.offset + 1].to_uint64()
  let b2 = self.data[self.offset + 2].to_uint64()
  let b3 = self.data[self.offset + 3].to_uint64()
  let b4 = self.data[self.offset + 4].to_uint64()
  let b5 = self.data[self.offset + 5].to_uint64()
  let b6 = self.data[self.offset + 6].to_uint64()
  let b7 = self.data[self.offset + 7].to_uint64()
  self.offset += 8
  (b0 << 56) |
  (b1 << 48) |
  (b2 << 40) |
  (b3 << 32) |
  (b4 << 24) |
  (b5 << 16) |
  (b6 << 8) |
  b7
}

///|
/// Read a version-dependent length field (UInt32 for PSD, UInt64 for PSB).
/// Returns Int (practical range).
pub fn Reader::read_length(
  self : Reader,
  version : @types.PsdVersion,
) -> Int raise @types.PsdError {
  match version {
    Psd => self.read_u32_be().reinterpret_as_int()
    Psb => self.read_u64_be().to_int()
  }
}

///|
/// Read a version-dependent RLE byte count (UInt16 for PSD, UInt32 for PSB).
pub fn Reader::read_rle_count(
  self : Reader,
  version : @types.PsdVersion,
) -> Int raise @types.PsdError {
  match version {
    Psd => self.read_u16_be().reinterpret_as_int()
    Psb => self.read_u32_be().reinterpret_as_int()
  }
}

///|
pub fn Reader::skip(self : Reader, n : Int) -> Unit raise @types.PsdError {
  if self.offset + n > self.data.length() {
    raise @types.UnexpectedEof
  }
  self.offset += n
}
