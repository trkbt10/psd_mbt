///|
test "ImageResources parse/build empty" {
  // section length = 0
  let data = b"\x00\x00\x00\x00"
  let reader = @binary.Reader::new(data)
  let res = ImageResources::parse(reader)
  inspect(res.blocks.length(), content="0")
  // Build and compare
  let writer = @binary.Writer::new()
  res.build(writer)
  inspect(writer.to_bytes() == data, content="true")
}

///|
test "ImageResourceBlock parse/build single block" {
  // '8BIM' + ID=1005 + empty name (2 bytes) + data_length=16 + 16 bytes ResolutionInfo
  let block_data = b"\x38\x42\x49\x4D\x03\xED\x00\x00\x00\x00\x00\x10\x00\x48\x00\x00\x00\x01\x00\x01\x00\x48\x00\x00\x00\x01\x00\x01"
  let reader = @binary.Reader::new(block_data)
  let block = ImageResourceBlock::parse(reader)
  inspect(block.resource_id, content="1005")
  inspect(block.name, content="")
  inspect(block.data.length(), content="16")
  // Build and compare
  let writer = @binary.Writer::new()
  block.build(writer)
  inspect(writer.to_bytes() == block_data, content="true")
}

///|
test "ImageResources parse/build with one block" {
  // section_length(4) + block (28 bytes)
  let data = b"\x00\x00\x00\x1C\x38\x42\x49\x4D\x03\xED\x00\x00\x00\x00\x00\x10\x00\x48\x00\x00\x00\x01\x00\x01\x00\x48\x00\x00\x00\x01\x00\x01"
  let reader = @binary.Reader::new(data)
  let res = ImageResources::parse(reader)
  inspect(res.blocks.length(), content="1")
  inspect(res.blocks[0].resource_id, content="1005")
  // Build and compare
  let writer = @binary.Writer::new()
  res.build(writer)
  inspect(writer.to_bytes() == data, content="true")
}

///|
test "ImageResourceBlock with name" {
  // Build a block with a non-empty name
  let block : ImageResourceBlock = {
    resource_id: 1005,
    name: "Test",
    data: b"\x00\x01\x02\x03",
  }
  let writer = @binary.Writer::new()
  block.build(writer)
  let built = writer.to_bytes()
  // Parse it back
  let reader = @binary.Reader::new(built)
  let parsed = ImageResourceBlock::parse(reader)
  inspect(parsed.resource_id, content="1005")
  inspect(parsed.name, content="Test")
  inspect(parsed.data.length(), content="4")
}

///|
test "ImageResourceBlock as_global_angle" {
  let block = ImageResourceBlock::from_global_angle(120)
  inspect(block.resource_id, content="1037")
  inspect(block.as_global_angle(), content="Some(120)")
  // Wrong resource_id should return None
  let other : ImageResourceBlock = {
    resource_id: 9999,
    name: "",
    data: b"\x00\x00\x00\x78",
  }
  inspect(other.as_global_angle(), content="None")
}

///|
test "ImageResourceBlock as_global_altitude" {
  let block = ImageResourceBlock::from_global_altitude(30)
  inspect(block.as_global_altitude(), content="Some(30)")
}

///|
test "ImageResourceBlock as_xmp round-trip" {
  let xmp_str = "<?xml version=\"1.0\"?>"
  let block = ImageResourceBlock::from_xmp(xmp_str)
  inspect(block.resource_id, content="1060")
  let expected =
    #|Some("<?xml version=\"1.0\"?>")
  inspect(block.as_xmp(), content=expected)
}

///|
test "ImageResourceBlock as_icc_profile" {
  let block : ImageResourceBlock = {
    resource_id: 1039,
    name: "",
    data: b"\x01\x02\x03",
  }
  match block.as_icc_profile() {
    Some(data) => inspect(data.length(), content="3")
    None => panic()
  }
}

///|
test "ImageResourceBlock as_transparency_index" {
  let block = ImageResourceBlock::from_transparency_index(42)
  inspect(block.as_transparency_index(), content="Some(42)")
}

///|
test "ImageResourceBlock thumbnail round-trip" {
  let thumb : ThumbnailResource = {
    format: 1,
    width: 100,
    height: 75,
    width_bytes: 300,
    total_size: 22500,
    compressed_size: 4,
    bits_per_pixel: 24,
    num_planes: 1,
    jfif_data: b"\xFF\xD8\xFF\xE0",
  }
  let block = ImageResourceBlock::from_thumbnail(thumb)
  inspect(block.resource_id, content="1036")
  match block.as_thumbnail() {
    Some(t) => {
      inspect(t.format, content="1")
      inspect(t.width, content="100")
      inspect(t.height, content="75")
      inspect(t.compressed_size, content="4")
      inspect(t.jfif_data.length(), content="4")
    }
    None => panic()
  }
}

///|
test "ImageResourceBlock grid_and_guides round-trip" {
  let gg : GridAndGuides = {
    version: 1,
    grid_horizontal: 576,
    grid_vertical: 576,
    guides: [{ position: 100, direction: 0 }, { position: 200, direction: 1 }],
  }
  let block = ImageResourceBlock::from_grid_and_guides(gg)
  inspect(block.resource_id, content="1032")
  match block.as_grid_and_guides() {
    Some(parsed) => {
      inspect(parsed.version, content="1")
      inspect(parsed.grid_horizontal, content="576")
      inspect(parsed.guides.length(), content="2")
      inspect(parsed.guides[0].position, content="100")
      inspect(parsed.guides[0].direction, content="0")
      inspect(parsed.guides[1].direction, content="1")
    }
    None => panic()
  }
}

///|
test "ImageResourceBlock odd data length padding" {
  // Block with odd-length data (3 bytes) should add padding byte
  let block : ImageResourceBlock = {
    resource_id: 1000,
    name: "",
    data: b"\x01\x02\x03",
  }
  let writer = @binary.Writer::new()
  block.build(writer)
  let built = writer.to_bytes()
  // Parse it back
  let reader = @binary.Reader::new(built)
  let parsed = ImageResourceBlock::parse(reader)
  inspect(parsed.resource_id, content="1000")
  inspect(parsed.data.length(), content="3")
  inspect(parsed.data == b"\x01\x02\x03", content="true")
  // Verify all bytes consumed (padding was properly skipped)
  inspect(reader.remaining(), content="0")
}
