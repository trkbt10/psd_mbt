///|
test "Writer::write_u8" {
  let w = Writer::new()
  w.write_u8(b'\x42')
  let bytes = w.to_bytes()
  inspect(bytes.length(), content="1")
  inspect(bytes[0], content="b'\\x42'")
}

///|
test "Writer::write_u16_be" {
  let w = Writer::new()
  w.write_u16_be(0x1234U)
  let bytes = w.to_bytes()
  inspect(bytes.length(), content="2")
  inspect(bytes[0], content="b'\\x12'")
  inspect(bytes[1], content="b'\\x34'")
}

///|
test "Writer::write_i16_be positive" {
  let w = Writer::new()
  w.write_i16_be(127)
  let bytes = w.to_bytes()
  inspect(bytes[0], content="b'\\x00'")
  inspect(bytes[1], content="b'\\x7F'")
}

///|
test "Writer::write_i16_be negative" {
  let w = Writer::new()
  w.write_i16_be(-2)
  let bytes = w.to_bytes()
  inspect(bytes[0], content="b'\\xFF'")
  inspect(bytes[1], content="b'\\xFE'")
}

///|
test "Writer::write_u32_be" {
  let w = Writer::new()
  w.write_u32_be(0x00010000U)
  let bytes = w.to_bytes()
  inspect(bytes.length(), content="4")
  inspect(bytes[0], content="b'\\x00'")
  inspect(bytes[1], content="b'\\x01'")
  inspect(bytes[2], content="b'\\x00'")
  inspect(bytes[3], content="b'\\x00'")
}

///|
test "Writer::write_i32_be negative" {
  let w = Writer::new()
  w.write_i32_be(-1)
  let bytes = w.to_bytes()
  inspect(bytes[0], content="b'\\xFF'")
  inspect(bytes[1], content="b'\\xFF'")
  inspect(bytes[2], content="b'\\xFF'")
  inspect(bytes[3], content="b'\\xFF'")
}

///|
test "Writer::write_bytes" {
  let w = Writer::new()
  w.write_bytes(b"\x41\x42\x43")
  let bytes = w.to_bytes()
  inspect(bytes.length(), content="3")
  inspect(bytes[0], content="b'\\x41'")
}

///|
test "Writer::write_zeros" {
  let w = Writer::new()
  w.write_zeros(4)
  let bytes = w.to_bytes()
  inspect(bytes.length(), content="4")
  inspect(bytes[0], content="b'\\x00'")
  inspect(bytes[3], content="b'\\x00'")
}

///|
test "Writer::length" {
  let w = Writer::new()
  inspect(w.length(), content="0")
  w.write_u32_be(0U)
  inspect(w.length(), content="4")
}

///|
test "Writer::write_u64_be" {
  let w = Writer::new()
  w.write_u64_be(0x0102030405060708UL)
  let bytes = w.to_bytes()
  inspect(bytes.length(), content="8")
  inspect(bytes[0], content="b'\\x01'")
  inspect(bytes[1], content="b'\\x02'")
  inspect(bytes[6], content="b'\\x07'")
  inspect(bytes[7], content="b'\\x08'")
}

///|
test "Writer::write_u64_be zero" {
  let w = Writer::new()
  w.write_u64_be(0UL)
  let bytes = w.to_bytes()
  inspect(bytes.length(), content="8")
  inspect(bytes[0], content="b'\\x00'")
  inspect(bytes[7], content="b'\\x00'")
}

///|
test "Writer::write_length PSD" {
  let w = Writer::new()
  w.write_length(16, @types.PsdVersion::Psd)
  let bytes = w.to_bytes()
  inspect(bytes.length(), content="4")
  inspect(bytes[3], content="b'\\x10'")
}

///|
test "Writer::write_length PSB" {
  let w = Writer::new()
  w.write_length(32, @types.PsdVersion::Psb)
  let bytes = w.to_bytes()
  inspect(bytes.length(), content="8")
  inspect(bytes[7], content="b'\\x20'")
}

///|
test "Writer::write_rle_count PSD" {
  let w = Writer::new()
  w.write_rle_count(10, @types.PsdVersion::Psd)
  inspect(w.to_bytes().length(), content="2")
}

///|
test "Writer::write_rle_count PSB" {
  let w = Writer::new()
  w.write_rle_count(10, @types.PsdVersion::Psb)
  inspect(w.to_bytes().length(), content="4")
}

///|
test "u64 round-trip" {
  let w = Writer::new()
  w.write_u64_be(0x0102030405060708UL)
  let r = Reader::new(w.to_bytes())
  inspect(r.read_u64_be(), content="72623859790382856")
}

///|
test "Writer/Reader round-trip" {
  let w = Writer::new()
  w.write_u8(b'\xFF')
  w.write_u16_be(0xABCDU)
  w.write_u32_be(0x12345678U)
  w.write_i32_be(-100)
  w.write_bytes(b"\x01\x02")
  let data = w.to_bytes()
  let r = Reader::new(data)
  inspect(r.read_u8(), content="b'\\xFF'")
  inspect(r.read_u16_be(), content="43981")
  inspect(r.read_u32_be(), content="305419896")
  inspect(r.read_i32_be(), content="-100")
  let tail = r.read_bytes(2)
  inspect(tail[0], content="b'\\x01'")
  inspect(tail[1], content="b'\\x02'")
  inspect(r.remaining(), content="0")
}
