///|
pub struct Writer {
  buf : @buffer.Buffer
}

///|
pub fn Writer::new() -> Writer {
  { buf: @buffer.new() }
}

///|
pub fn Writer::write_u8(self : Writer, value : Byte) -> Unit {
  self.buf.write_byte(value)
}

///|
pub fn Writer::write_u16_be(self : Writer, value : UInt) -> Unit {
  self.buf.write_byte(((value >> 8) & 0xFFU).to_byte())
  self.buf.write_byte((value & 0xFFU).to_byte())
}

///|
pub fn Writer::write_i16_be(self : Writer, value : Int) -> Unit {
  self.write_u16_be(value.reinterpret_as_uint() & 0xFFFFU)
}

///|
pub fn Writer::write_u32_be(self : Writer, value : UInt) -> Unit {
  self.buf.write_byte(((value >> 24) & 0xFFU).to_byte())
  self.buf.write_byte(((value >> 16) & 0xFFU).to_byte())
  self.buf.write_byte(((value >> 8) & 0xFFU).to_byte())
  self.buf.write_byte((value & 0xFFU).to_byte())
}

///|
pub fn Writer::write_i32_be(self : Writer, value : Int) -> Unit {
  self.write_u32_be(value.reinterpret_as_uint())
}

///|
pub fn Writer::write_bytes(self : Writer, data : Bytes) -> Unit {
  self.buf.write_bytes(data)
}

///|
pub fn Writer::write_zeros(self : Writer, count : Int) -> Unit {
  for _i = 0; _i < count; _i = _i + 1 {
    self.buf.write_byte(b'\x00')
  }
}

///|
pub fn Writer::write_u64_be(self : Writer, value : UInt64) -> Unit {
  self.buf.write_byte(((value >> 56) & 0xFFUL).to_byte())
  self.buf.write_byte(((value >> 48) & 0xFFUL).to_byte())
  self.buf.write_byte(((value >> 40) & 0xFFUL).to_byte())
  self.buf.write_byte(((value >> 32) & 0xFFUL).to_byte())
  self.buf.write_byte(((value >> 24) & 0xFFUL).to_byte())
  self.buf.write_byte(((value >> 16) & 0xFFUL).to_byte())
  self.buf.write_byte(((value >> 8) & 0xFFUL).to_byte())
  self.buf.write_byte((value & 0xFFUL).to_byte())
}

///|
/// Write a version-dependent length field (UInt32 for PSD, UInt64 for PSB).
pub fn Writer::write_length(
  self : Writer,
  value : Int,
  version : @types.PsdVersion,
) -> Unit {
  match version {
    Psd => self.write_u32_be(value.reinterpret_as_uint())
    Psb => self.write_u64_be(value.to_uint64())
  }
}

///|
/// Write a version-dependent RLE byte count (UInt16 for PSD, UInt32 for PSB).
pub fn Writer::write_rle_count(
  self : Writer,
  value : Int,
  version : @types.PsdVersion,
) -> Unit {
  match version {
    Psd => self.write_u16_be(value.reinterpret_as_uint())
    Psb => self.write_u32_be(value.reinterpret_as_uint())
  }
}

///|
pub fn Writer::length(self : Writer) -> Int {
  self.buf.length()
}

///|
pub fn Writer::to_bytes(self : Writer) -> Bytes {
  self.buf.to_bytes()
}
