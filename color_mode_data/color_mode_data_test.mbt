///|
test "ColorModeData parse/build empty" {
  // length=0
  let data = b"\x00\x00\x00\x00"
  let reader = @binary.Reader::new(data)
  let cmd = ColorModeData::parse(reader, @types.ColorMode::RGB)
  inspect(cmd.data.length(), content="0")
  // Build and compare
  let writer = @binary.Writer::new()
  cmd.build(writer)
  inspect(writer.to_bytes() == data, content="true")
}

///|
test "ColorModeData parse/build with data" {
  // length=3, data=[0x01, 0x02, 0x03]
  let data = b"\x00\x00\x00\x03\x01\x02\x03"
  let reader = @binary.Reader::new(data)
  let cmd = ColorModeData::parse(reader, @types.ColorMode::RGB)
  inspect(cmd.data.length(), content="3")
  inspect(cmd.data[0], content="b'\\x01'")
  // Build and compare
  let writer = @binary.Writer::new()
  cmd.build(writer)
  inspect(writer.to_bytes() == data, content="true")
}

///|
test "ColorModeData as_indexed_table round-trip" {
  let table : Array[(Int, Int, Int)] = []
  for i = 0; i < 256; i = i + 1 {
    table.push((i, 255 - i, i / 2))
  }
  let cmd = ColorModeData::from_indexed_table(table)
  inspect(cmd.data.length(), content="768")
  match cmd.as_indexed_table() {
    Some(t) => {
      inspect(t.length(), content="256")
      inspect(t[0], content="(0, 255, 0)")
      inspect(t[1], content="(1, 254, 0)")
      inspect(t[255], content="(255, 0, 127)")
    }
    None => panic()
  }
}

///|
test "ColorModeData as_indexed_table wrong size" {
  // Parse a ColorModeData with 3 bytes of data (not 768)
  let w = @binary.Writer::new()
  w.write_u32_be(3U)
  w.write_bytes(b"\x00\x01\x02")
  let reader = @binary.Reader::new(w.to_bytes())
  let cmd = ColorModeData::parse(reader, @types.ColorMode::RGB)
  inspect(cmd.as_indexed_table(), content="None")
}

///|
test "ColorModeData Indexed valid 768 bytes" {
  let buf = @buffer.new(size_hint=772)
  // Write length = 768
  buf.write_byte(b'\x00')
  buf.write_byte(b'\x00')
  buf.write_byte(b'\x03')
  buf.write_byte(b'\x00')
  // Write 768 bytes of data
  for _i = 0; _i < 768; _i = _i + 1 {
    buf.write_byte(b'\x00')
  }
  let reader = @binary.Reader::new(buf.to_bytes())
  let cmd = ColorModeData::parse(reader, @types.ColorMode::Indexed)
  inspect(cmd.data.length(), content="768")
}

///|
test "ColorModeData Indexed invalid length" {
  let w = @binary.Writer::new()
  w.write_u32_be(100U)
  for _i = 0; _i < 100; _i = _i + 1 {
    w.write_u8(b'\x00')
  }
  let reader = @binary.Reader::new(w.to_bytes())
  let result : Result[String, String] = try {
    let _ = ColorModeData::parse(reader, @types.ColorMode::Indexed)
    Ok("ok")
  } catch {
    @types.InvalidColorModeDataLength(_, _) => Err("InvalidColorModeDataLength")
    _ => Err("other")
  }
  inspect(result, content="Err(\"InvalidColorModeDataLength\")")
}

///|
test "ColorModeData RGB with zero length OK" {
  let data = b"\x00\x00\x00\x00"
  let reader = @binary.Reader::new(data)
  let cmd = ColorModeData::parse(reader, @types.ColorMode::RGB)
  inspect(cmd.data.length(), content="0")
}
