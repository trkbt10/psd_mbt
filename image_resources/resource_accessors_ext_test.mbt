///|
test "ResolutionInfo round-trip" {
  let info : ResolutionInfo = {
    h_res: 0x00480000, // 72 dpi in fixed 16.16
    h_res_unit: 1,
    width_unit: 1,
    v_res: 0x00480000,
    v_res_unit: 1,
    height_unit: 1,
  }
  let block = ImageResourceBlock::from_resolution_info(info)
  inspect(block.resource_id, content="1005")
  inspect(block.data.length(), content="16")
  match block.as_resolution_info() {
    Some(parsed) => {
      inspect(parsed.h_res, content="4718592")
      inspect(parsed.h_res_unit, content="1")
      inspect(parsed.width_unit, content="1")
      inspect(parsed.v_res, content="4718592")
      inspect(parsed.v_res_unit, content="1")
    }
    None => panic()
  }
}

///|
test "PrintFlags round-trip" {
  let flags : PrintFlags = {
    labels: true,
    crop_marks: false,
    color_bars: true,
    registration_marks: false,
    negative: false,
    flip: false,
    interpolate: true,
    caption: false,
    print_flags: false,
  }
  let block = ImageResourceBlock::from_print_flags(flags)
  inspect(block.resource_id, content="1011")
  match block.as_print_flags() {
    Some(parsed) => {
      inspect(parsed.labels, content="true")
      inspect(parsed.crop_marks, content="false")
      inspect(parsed.color_bars, content="true")
      inspect(parsed.interpolate, content="true")
    }
    None => panic()
  }
}

///|
test "PrintFlagsInfo round-trip" {
  let info : PrintFlagsInfo = {
    version: 1,
    center_crop: true,
    bleed_width: 0,
    bleed_scale: 1,
  }
  let block = ImageResourceBlock::from_print_flags_info(info)
  inspect(block.resource_id, content="10000")
  match block.as_print_flags_info() {
    Some(parsed) => {
      inspect(parsed.version, content="1")
      inspect(parsed.center_crop, content="true")
      inspect(parsed.bleed_width, content="0")
      inspect(parsed.bleed_scale, content="1")
    }
    None => panic()
  }
}

///|
test "AlphaChannelNames round-trip" {
  let names = ["Red", "Green", "Blue", "Alpha"]
  let block = ImageResourceBlock::from_alpha_channel_names(names)
  inspect(block.resource_id, content="1006")
  match block.as_alpha_channel_names() {
    Some(parsed) => {
      inspect(parsed.length(), content="4")
      inspect(parsed[0], content="Red")
      inspect(parsed[1], content="Green")
      inspect(parsed[2], content="Blue")
      inspect(parsed[3], content="Alpha")
    }
    None => panic()
  }
}

///|
test "Caption round-trip" {
  let block = ImageResourceBlock::from_caption("Hello World")
  inspect(block.resource_id, content="1008")
  inspect(block.as_caption(), content="Some(\"Hello World\")")
}

///|
test "BackgroundColor round-trip" {
  let bg : BackgroundColor = { color_space: 0, components: [65535, 0, 0, 0] }
  let block = ImageResourceBlock::from_background_color(bg)
  inspect(block.resource_id, content="1010")
  match block.as_background_color() {
    Some(parsed) => {
      inspect(parsed.color_space, content="0")
      inspect(parsed.components[0], content="65535")
      inspect(parsed.components[1], content="0")
    }
    None => panic()
  }
}

///|
test "CopyrightFlag round-trip" {
  let block = ImageResourceBlock::from_copyright_flag(true)
  inspect(block.resource_id, content="1034")
  inspect(block.as_copyright_flag(), content="Some(true)")
  let block2 = ImageResourceBlock::from_copyright_flag(false)
  inspect(block2.as_copyright_flag(), content="Some(false)")
}

///|
test "URL round-trip" {
  let block = ImageResourceBlock::from_url("https://example.com")
  inspect(block.resource_id, content="1035")
  let expected =
    #|Some("https://example.com")
  inspect(block.as_url(), content=expected)
}

///|
test "LayerStateInfo round-trip" {
  let block = ImageResourceBlock::from_layer_state_info(3)
  inspect(block.resource_id, content="1024")
  inspect(block.as_layer_state_info(), content="Some(3)")
}

///|
test "LayerGroupInfo round-trip" {
  let block = ImageResourceBlock::from_layer_group_info([0, 1, 2, 1])
  inspect(block.resource_id, content="1025")
  match block.as_layer_group_info() {
    Some(ids) => {
      inspect(ids.length(), content="4")
      inspect(ids[0], content="0")
      inspect(ids[2], content="2")
    }
    None => panic()
  }
}

///|
test "VersionInfo round-trip" {
  let info : VersionInfo = {
    version: 1,
    has_real_merged_data: true,
    writer_name: "Adobe Photoshop",
    reader_name: "Adobe Photoshop",
    file_version: 2,
  }
  let block = ImageResourceBlock::from_version_info(info)
  inspect(block.resource_id, content="1057")
  match block.as_version_info() {
    Some(parsed) => {
      inspect(parsed.version, content="1")
      inspect(parsed.has_real_merged_data, content="true")
      inspect(parsed.writer_name, content="Adobe Photoshop")
      inspect(parsed.reader_name, content="Adobe Photoshop")
      inspect(parsed.file_version, content="2")
    }
    None => panic()
  }
}

///|
test "PixelAspectRatio round-trip" {
  let info : PixelAspectRatio = { version: 1, aspect_ratio: 1.0 }
  let block = ImageResourceBlock::from_pixel_aspect_ratio(info)
  inspect(block.resource_id, content="1064")
  match block.as_pixel_aspect_ratio() {
    Some(parsed) => {
      inspect(parsed.version, content="1")
      inspect(parsed.aspect_ratio, content="1")
    }
    None => panic()
  }
}

///|
test "LayerSelectionIDs round-trip" {
  let block = ImageResourceBlock::from_layer_selection_ids([10, 20, 30])
  inspect(block.resource_id, content="1069")
  match block.as_layer_selection_ids() {
    Some(ids) => {
      inspect(ids.length(), content="3")
      inspect(ids[0], content="10")
      inspect(ids[2], content="30")
    }
    None => panic()
  }
}

///|
test "LayerGroupsEnabled round-trip" {
  let block = ImageResourceBlock::from_layer_groups_enabled([true, false, true])
  inspect(block.resource_id, content="1072")
  match block.as_layer_groups_enabled() {
    Some(flags) => {
      inspect(flags.length(), content="3")
      inspect(flags[0], content="true")
      inspect(flags[1], content="false")
    }
    None => panic()
  }
}

///|
test "URLList round-trip" {
  let e1 : URLListEntry = { long_val: 0, id: 1, url: "http://a.com" }
  let e2 : URLListEntry = { long_val: 0, id: 2, url: "http://b.com" }
  let entries = [e1, e2]
  let block = ImageResourceBlock::from_url_list(entries)
  inspect(block.resource_id, content="1054")
  match block.as_url_list() {
    Some(parsed) => {
      inspect(parsed.length(), content="2")
      inspect(parsed[0].id, content="1")
      inspect(parsed[0].url, content="http://a.com")
      inspect(parsed[1].id, content="2")
    }
    None => panic()
  }
}

///|
test "OriginID round-trip" {
  let block = ImageResourceBlock::from_origin_id(42)
  inspect(block.resource_id, content="1044")
  inspect(block.as_origin_id(), content="Some(42)")
}

///|
test "UnicodeAlphaNames round-trip" {
  let names = ["Alpha 1", "Mask"]
  let block = ImageResourceBlock::from_unicode_alpha_names(names)
  inspect(block.resource_id, content="1045")
  match block.as_unicode_alpha_names() {
    Some(parsed) => {
      inspect(parsed.length(), content="2")
      inspect(parsed[0], content="Alpha 1")
      inspect(parsed[1], content="Mask")
    }
    None => panic()
  }
}

///|
test "IndexedColorTableCount round-trip" {
  let block = ImageResourceBlock::from_indexed_color_table_count(256)
  inspect(block.resource_id, content="1046")
  inspect(block.as_indexed_color_table_count(), content="Some(256)")
}

///|
test "AlphaIdentifiers round-trip" {
  let ids = [100, 200, 300]
  let block = ImageResourceBlock::from_alpha_identifiers(ids)
  inspect(block.resource_id, content="1051")
  match block.as_alpha_identifiers() {
    Some(parsed) => {
      inspect(parsed.length(), content="3")
      inspect(parsed[0], content="100")
      inspect(parsed[1], content="200")
      inspect(parsed[2], content="300")
    }
    None => panic()
  }
}

///|
test "DocumentSpecificIDs round-trip" {
  let block = ImageResourceBlock::from_document_specific_ids(1000)
  inspect(block.resource_id, content="1081")
  inspect(block.as_document_specific_ids(), content="Some(1000)")
}

///|
test "DocumentIdsSeed round-trip" {
  let block = ImageResourceBlock::from_document_ids_seed(12345)
  inspect(block.resource_id, content="1043")
  inspect(block.as_document_ids_seed(), content="Some(12345)")
}

///|
test "AutoSaveFilePath round-trip" {
  let block = ImageResourceBlock::from_auto_save_file_path("/tmp/test.psd")
  inspect(block.resource_id, content="1086")
  inspect(block.as_auto_save_file_path(), content="Some(\"/tmp/test.psd\")")
}

///|
test "AutoSaveFormat round-trip" {
  let block = ImageResourceBlock::from_auto_save_format("Photoshop")
  inspect(block.resource_id, content="1087")
  inspect(block.as_auto_save_format(), content="Some(\"Photoshop\")")
}

///|
test "PrintScale round-trip" {
  let info : PrintScale = {
    style: 2,
    x_location: 1.0,
    y_location: 2.0,
    scale: 0.5,
  }
  let block = ImageResourceBlock::from_print_scale(info)
  inspect(block.resource_id, content="1089")
  match block.as_print_scale() {
    Some(parsed) => {
      inspect(parsed.style, content="2")
      inspect(parsed.scale, content="0.5")
    }
    None => panic()
  }
}

///|
test "ICCUntagged round-trip" {
  let block = ImageResourceBlock::from_icc_untagged(true)
  inspect(block.resource_id, content="1074")
  inspect(block.as_icc_untagged(), content="Some(true)")
  let block2 = ImageResourceBlock::from_icc_untagged(false)
  inspect(block2.as_icc_untagged(), content="Some(false)")
}
