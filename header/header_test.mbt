///|
test "FileHeader parse/build round-trip" {
  // Minimal PSD header: 26 bytes
  // '8BPS' version=1 reserved=0 channels=3 height=1 width=1 depth=8 colormode=RGB(3)
  let header_bytes = b"\x38\x42\x50\x53\x00\x01\x00\x00\x00\x00\x00\x00\x00\x03\x00\x00\x00\x01\x00\x00\x00\x01\x00\x08\x00\x03"
  let reader = @binary.Reader::new(header_bytes)
  let header = FileHeader::parse(reader)
  inspect(header.version, content="Psd")
  inspect(header.channels, content="3")
  inspect(header.height, content="1")
  inspect(header.width, content="1")
  inspect(header.depth, content="8")
  inspect(header.color_mode, content="RGB")
  // Build and compare
  let writer = @binary.Writer::new()
  header.build(writer)
  let rebuilt = writer.to_bytes()
  inspect(rebuilt.length(), content="26")
  inspect(rebuilt == header_bytes, content="true")
}

///|
test "FileHeader invalid signature" {
  let bad_sig = b"\x00\x00\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00\x03\x00\x00\x00\x01\x00\x00\x00\x01\x00\x08\x00\x03"
  let reader = @binary.Reader::new(bad_sig)
  let result = try FileHeader::parse(reader) catch {
    _ => Err("error")
  } noraise {
    _ => Ok("ok")
  }
  inspect(result, content="Err(\"error\")")
}

///|
test "FileHeader invalid reserved bytes" {
  // Reserved byte at position 8 is non-zero
  let bad = b"\x38\x42\x50\x53\x00\x01\x00\x00\x00\x00\x00\x01\x00\x03\x00\x00\x00\x01\x00\x00\x00\x01\x00\x08\x00\x03"
  let reader = @binary.Reader::new(bad)
  let result : Result[String, String] = try {
    let _ = FileHeader::parse(reader)
    Ok("ok")
  } catch {
    @types.InvalidReserved => Err("InvalidReserved")
    _ => Err("other")
  }
  inspect(result, content="Err(\"InvalidReserved\")")
}

///|
test "FileHeader channels out of range" {
  // channels = 0 (too low)
  let bad = b"\x38\x42\x50\x53\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x00\x00\x00\x01\x00\x08\x00\x03"
  let reader = @binary.Reader::new(bad)
  let result : Result[String, String] = try {
    let _ = FileHeader::parse(reader)
    Ok("ok")
  } catch {
    @types.ChannelsOutOfRange(_) => Err("ChannelsOutOfRange")
    _ => Err("other")
  }
  inspect(result, content="Err(\"ChannelsOutOfRange\")")
}

///|
test "FileHeader invalid depth" {
  // depth = 4 (not in {1, 8, 16, 32})
  let bad = b"\x38\x42\x50\x53\x00\x01\x00\x00\x00\x00\x00\x00\x00\x03\x00\x00\x00\x01\x00\x00\x00\x01\x00\x04\x00\x03"
  let reader = @binary.Reader::new(bad)
  let result : Result[String, String] = try {
    let _ = FileHeader::parse(reader)
    Ok("ok")
  } catch {
    @types.InvalidDepth(_) => Err("InvalidDepth")
    _ => Err("other")
  }
  inspect(result, content="Err(\"InvalidDepth\")")
}

///|
test "FileHeader dimensions out of range" {
  // width = 0 (too low)
  let bad = b"\x38\x42\x50\x53\x00\x01\x00\x00\x00\x00\x00\x00\x00\x03\x00\x00\x00\x01\x00\x00\x00\x00\x00\x08\x00\x03"
  let reader = @binary.Reader::new(bad)
  let result : Result[String, String] = try {
    let _ = FileHeader::parse(reader)
    Ok("ok")
  } catch {
    @types.DimensionsOutOfRange(_, _) => Err("DimensionsOutOfRange")
    _ => Err("other")
  }
  inspect(result, content="Err(\"DimensionsOutOfRange\")")
}

///|
test "FileHeader PSB version" {
  // PSB header: version=2
  let psb_header = b"\x38\x42\x50\x53\x00\x02\x00\x00\x00\x00\x00\x00\x00\x03\x00\x00\x00\x01\x00\x00\x00\x01\x00\x08\x00\x03"
  let reader = @binary.Reader::new(psb_header)
  let header = FileHeader::parse(reader)
  inspect(header.version, content="Psb")
  // Round-trip
  let writer = @binary.Writer::new()
  header.build(writer)
  inspect(writer.to_bytes() == psb_header, content="true")
}
