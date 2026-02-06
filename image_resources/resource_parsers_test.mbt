///|
test "GridAndGuides round-trip with guides" {
  let gg : GridAndGuides = {
    version: 1,
    grid_horizontal: 576, // 18 * 32 = default grid
    grid_vertical: 576,
    guides: [
      { position: 100, direction: 0 }, // vertical
      { position: 200, direction: 1 }, // horizontal
      { position: 300, direction: 0 },
    ],
  }
  let block = ImageResourceBlock::from_grid_and_guides(gg)
  inspect(block.resource_id, content="1032")
  // 16 bytes header + 3 * 5 bytes guides = 31 bytes
  inspect(block.data.length(), content="31")
  match block.as_grid_and_guides() {
    Some(parsed) => {
      inspect(parsed.version, content="1")
      inspect(parsed.grid_horizontal, content="576")
      inspect(parsed.grid_vertical, content="576")
      inspect(parsed.guides.length(), content="3")
      inspect(parsed.guides[0].position, content="100")
      inspect(parsed.guides[0].direction, content="0")
      inspect(parsed.guides[1].position, content="200")
      inspect(parsed.guides[1].direction, content="1")
      inspect(parsed.guides[2].position, content="300")
      inspect(parsed.guides[2].direction, content="0")
    }
    None => panic()
  }
}

///|
test "GridAndGuides round-trip no guides" {
  let gg : GridAndGuides = {
    version: 1,
    grid_horizontal: 576,
    grid_vertical: 576,
    guides: [],
  }
  let block = ImageResourceBlock::from_grid_and_guides(gg)
  inspect(block.data.length(), content="16")
  match block.as_grid_and_guides() {
    Some(parsed) => inspect(parsed.guides.length(), content="0")
    None => panic()
  }
}

///|
test "GridAndGuides wrong ID returns None" {
  let block : ImageResourceBlock = {
    resource_id: 9999,
    name: "",
    data: b"\x00",
  }
  inspect(block.as_grid_and_guides(), content="None")
}

///|
test "Thumbnail JPEG round-trip" {
  let thumb : ThumbnailResource = {
    format: 1, // kJpegRGB
    width: 128,
    height: 96,
    width_bytes: 384, // (128 * 24 + 31) / 32 * 4
    total_size: 36864, // 384 * 96 * 1
    compressed_size: 5,
    bits_per_pixel: 24,
    num_planes: 1,
    jfif_data: b"\xFF\xD8\xFF\xE0\x00",
  }
  let block = ImageResourceBlock::from_thumbnail(thumb)
  inspect(block.resource_id, content="1036")
  // 28 bytes header + 5 bytes JFIF = 33
  inspect(block.data.length(), content="33")
  match block.as_thumbnail() {
    Some(parsed) => {
      inspect(parsed.format, content="1")
      inspect(parsed.width, content="128")
      inspect(parsed.height, content="96")
      inspect(parsed.width_bytes, content="384")
      inspect(parsed.compressed_size, content="5")
      inspect(parsed.bits_per_pixel, content="24")
      inspect(parsed.num_planes, content="1")
      inspect(parsed.jfif_data.length(), content="5")
      inspect(parsed.is_jpeg(), content="true")
      inspect(parsed.is_raw_rgb(), content="false")
    }
    None => panic()
  }
}

///|
test "Thumbnail raw RGB format" {
  let thumb : ThumbnailResource = {
    format: 0, // kRawRGB
    width: 2,
    height: 2,
    width_bytes: 8,
    total_size: 16,
    compressed_size: 0,
    bits_per_pixel: 24,
    num_planes: 1,
    jfif_data: b"",
  }
  let block = ImageResourceBlock::from_thumbnail(thumb)
  match block.as_thumbnail() {
    Some(parsed) => {
      inspect(parsed.is_jpeg(), content="false")
      inspect(parsed.is_raw_rgb(), content="true")
    }
    None => panic()
  }
}

///|
test "Thumbnail wrong ID returns None" {
  let block : ImageResourceBlock = {
    resource_id: 1005,
    name: "",
    data: b"\x00",
  }
  inspect(block.as_thumbnail(), content="None")
}

///|
test "GlobalAngle round-trip" {
  let block = ImageResourceBlock::from_global_angle(120)
  inspect(block.resource_id, content="1037")
  inspect(block.as_global_angle(), content="Some(120)")
}

///|
test "GlobalAngle default value 30" {
  let block = ImageResourceBlock::from_global_angle(30)
  inspect(block.as_global_angle(), content="Some(30)")
}

///|
test "GlobalAltitude round-trip" {
  let block = ImageResourceBlock::from_global_altitude(500)
  inspect(block.resource_id, content="1049")
  inspect(block.as_global_altitude(), content="Some(500)")
}

///|
test "TransparencyIndex round-trip" {
  let block = ImageResourceBlock::from_transparency_index(42)
  inspect(block.resource_id, content="1047")
  inspect(block.as_transparency_index(), content="Some(42)")
}

///|
test "XMP round-trip" {
  let xmp_str = "<x:xmpmeta>test</x:xmpmeta>"
  let block = ImageResourceBlock::from_xmp(xmp_str)
  inspect(block.resource_id, content="1060")
  let expected =
    #|Some("<x:xmpmeta>test</x:xmpmeta>")
  inspect(block.as_xmp(), content=expected)
}

///|
test "ICC Profile accessor" {
  let data = b"\x00\x01\x02\x03"
  let block : ImageResourceBlock = { resource_id: 1039, name: "", data }
  match block.as_icc_profile() {
    Some(profile) => inspect(profile.length(), content="4")
    None => panic()
  }
  // Wrong ID returns None
  let block2 : ImageResourceBlock = { resource_id: 1040, name: "", data }
  inspect(block2.as_icc_profile(), content="None")
}

///|
test "ResolutionInfo 300 dpi round-trip" {
  let info : ResolutionInfo = {
    h_res: 0x012C0000, // 300 dpi in 16.16 fixed point
    h_res_unit: 1,
    width_unit: 2, // cm
    v_res: 0x012C0000,
    v_res_unit: 1,
    height_unit: 2,
  }
  let block = ImageResourceBlock::from_resolution_info(info)
  match block.as_resolution_info() {
    Some(parsed) => {
      inspect(parsed.h_res, content="19660800")
      inspect(parsed.h_res_unit, content="1")
      inspect(parsed.width_unit, content="2")
      inspect(parsed.v_res, content="19660800")
      inspect(parsed.v_res_unit, content="1")
      inspect(parsed.height_unit, content="2")
    }
    None => panic()
  }
}
