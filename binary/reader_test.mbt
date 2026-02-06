///|
test "Reader::read_u8" {
  let reader = Reader::new(b"\x42")
  let v = reader.read_u8()
  inspect(v, content="b'\\x42'")
  inspect(reader.remaining(), content="0")
}

///|
test "Reader::read_u8 eof" {
  let reader = Reader::new(b"")
  let result = try reader.read_u8() catch {
    e => Err(e)
  } noraise {
    v => Ok(v)
  }
  inspect(result is Err(_), content="true")
}

///|
test "Reader::read_u16_be" {
  let reader = Reader::new(b"\x12\x34")
  let v = reader.read_u16_be()
  inspect(v, content="4660")
  inspect(reader.position(), content="2")
}

///|
test "Reader::read_i16_be positive" {
  let reader = Reader::new(b"\x00\x7F")
  let v = reader.read_i16_be()
  inspect(v, content="127")
}

///|
test "Reader::read_i16_be negative" {
  let reader = Reader::new(b"\xFF\xFE")
  let v = reader.read_i16_be()
  inspect(v, content="-2")
}

///|
test "Reader::read_u32_be" {
  let reader = Reader::new(b"\x00\x01\x00\x00")
  let v = reader.read_u32_be()
  inspect(v, content="65536")
}

///|
test "Reader::read_i32_be positive" {
  let reader = Reader::new(b"\x00\x00\x00\x01")
  let v = reader.read_i32_be()
  inspect(v, content="1")
}

///|
test "Reader::read_i32_be negative" {
  let reader = Reader::new(b"\xFF\xFF\xFF\xFF")
  let v = reader.read_i32_be()
  inspect(v, content="-1")
}

///|
test "Reader::read_bytes" {
  let reader = Reader::new(b"\x41\x42\x43\x44")
  let bytes = reader.read_bytes(3)
  inspect(bytes.length(), content="3")
  inspect(bytes[0], content="b'\\x41'")
  inspect(bytes[1], content="b'\\x42'")
  inspect(bytes[2], content="b'\\x43'")
  inspect(reader.remaining(), content="1")
}

///|
test "Reader::skip" {
  let reader = Reader::new(b"\x01\x02\x03\x04")
  reader.skip(2)
  let v = reader.read_u8()
  inspect(v, content="b'\\x03'")
}

///|
test "Reader::read_u64_be" {
  let reader = Reader::new(b"\x00\x00\x00\x01\x00\x00\x00\x00")
  let v = reader.read_u64_be()
  inspect(v, content="4294967296")
  inspect(reader.remaining(), content="0")
}

///|
test "Reader::read_u64_be zero" {
  let reader = Reader::new(b"\x00\x00\x00\x00\x00\x00\x00\x00")
  let v = reader.read_u64_be()
  inspect(v, content="0")
}

///|
test "Reader::read_length PSD" {
  let reader = Reader::new(b"\x00\x00\x00\x10")
  let v = reader.read_length(@types.PsdVersion::Psd)
  inspect(v, content="16")
}

///|
test "Reader::read_length PSB" {
  let reader = Reader::new(b"\x00\x00\x00\x00\x00\x00\x00\x20")
  let v = reader.read_length(@types.PsdVersion::Psb)
  inspect(v, content="32")
}

///|
test "Reader::read_rle_count PSD" {
  let reader = Reader::new(b"\x00\x0A")
  let v = reader.read_rle_count(@types.PsdVersion::Psd)
  inspect(v, content="10")
}

///|
test "Reader::read_rle_count PSB" {
  let reader = Reader::new(b"\x00\x00\x00\x0A")
  let v = reader.read_rle_count(@types.PsdVersion::Psb)
  inspect(v, content="10")
}

///|
test "Reader sequential reads" {
  // '8BPS' + version 1
  let reader = Reader::new(b"\x38\x42\x50\x53\x00\x01")
  let sig = reader.read_bytes(4)
  inspect(sig[0], content="b'\\x38'")
  let ver = reader.read_u16_be()
  inspect(ver, content="1")
  inspect(reader.remaining(), content="0")
}
