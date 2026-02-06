///|
test "ColorModeData parse/build empty" {
  // length=0
  let data = b"\x00\x00\x00\x00"
  let reader = @binary.Reader::new(data)
  let cmd = ColorModeData::parse(reader)
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
  let cmd = ColorModeData::parse(reader)
  inspect(cmd.data.length(), content="3")
  inspect(cmd.data[0], content="b'\\x01'")
  // Build and compare
  let writer = @binary.Writer::new()
  cmd.build(writer)
  inspect(writer.to_bytes() == data, content="true")
}
