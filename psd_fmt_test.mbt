///|
test "PsdFile parse/build minimal 43-byte PSD round-trip" {
  // Minimal valid PSD: 1x1 RGB 8-bit, Raw compression, 3 bytes pixel data
  let minimal_psd = b"\x38\x42\x50\x53\x00\x01\x00\x00\x00\x00\x00\x00\x00\x03\x00\x00\x00\x01\x00\x00\x00\x01\x00\x08\x00\x03\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
  let psd = PsdFile::parse(minimal_psd)
  inspect(psd.header.version, content="Psd")
  inspect(psd.header.channels, content="3")
  inspect(psd.header.height, content="1")
  inspect(psd.header.width, content="1")
  inspect(psd.header.depth, content="8")
  inspect(psd.header.color_mode, content="RGB")
  inspect(psd.color_mode_data.data.length(), content="0")
  inspect(psd.image_resources.blocks.length(), content="0")
  inspect(psd.layer_and_mask_info.layer_info is None, content="true")
  inspect(psd.image_data.compression, content="Raw")
  inspect(psd.image_data.data.length(), content="3")
  // Round-trip
  let rebuilt = psd.build()
  inspect(rebuilt.length(), content="43")
  inspect(rebuilt == minimal_psd, content="true")
}

///|
test "PsdFile parse/build gap_ali_keys fixture round-trip" {
  // gap_ali_keys.psd: 4x4 RGB, 1 layer with LMsk, brst, lmgm, vmgm ALI keys + resources 1043/1069
  let fixture = b"\x38\x42\x50\x53\x00\x01\x00\x00\x00\x00\x00\x00\x00\x03\x00\x00\x00\x04\x00\x00\x00\x04\x00\x08\x00\x03\x00\x00\x00\x00\x00\x00\x00\x26\x38\x42\x49\x4d\x04\x13\x00\x00\x00\x00\x00\x04\x00\x00\x00\x2a\x38\x42\x49\x4d\x04\x2d\x00\x00\x00\x00\x00\x0a\x00\x02\x00\x00\x00\x01\x00\x00\x00\x02\x00\x00\x00\xd2\x00\x00\x00\xca\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x04\x00\x00\x00\x04\x00\x03\x00\x00\x00\x00\x00\x12\x00\x01\x00\x00\x00\x12\x00\x02\x00\x00\x00\x12\x38\x42\x49\x4d\x6e\x6f\x72\x6d\xff\x00\x02\x00\x00\x00\x00\x5e\x00\x00\x00\x00\x00\x00\x00\x00\x07\x4c\x61\x79\x65\x72\x20\x30\x38\x42\x49\x4d\x4c\x4d\x73\x6b\x00\x00\x00\x0d\x00\x00\xff\xff\x00\x00\x00\x00\x00\x00\x00\x64\x80\x00\x38\x42\x49\x4d\x62\x72\x73\x74\x00\x00\x00\x08\x00\x00\x00\x00\x00\x00\x00\x02\x38\x42\x49\x4d\x6c\x6d\x67\x6d\x00\x00\x00\x04\x01\x00\x00\x00\x38\x42\x49\x4d\x76\x6d\x67\x6d\x00\x00\x00\x04\x00\x00\x00\x00\x00\x00\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
  let psd = PsdFile::parse(fixture)
  // Verify header
  inspect(psd.header.width, content="4")
  inspect(psd.header.height, content="4")
  inspect(psd.header.channels, content="3")
  // Verify image resources
  inspect(psd.image_resources.blocks.length(), content="2")
  // Resource 1043: Document IDs Seed
  let seed = psd.image_resources.blocks[0].as_document_ids_seed()
  inspect(seed, content="Some(42)")
  // Resource 1069: Layer Selection IDs
  let sel_ids = psd.image_resources.blocks[1].as_layer_selection_ids()
  inspect(sel_ids, content="Some([1, 2])")
  // Verify layer
  let li = psd.layer_and_mask_info.layer_info.unwrap()
  inspect(li.actual_layer_count(), content="1")
  let layer = li.layers[0]
  inspect(layer.name, content="Layer 0")
  // Verify ALI keys: LMsk, brst, lmgm, vmgm
  inspect(layer.additional_info.length(), content="4")
  let lmsk = layer.additional_info[0].as_user_mask()
  inspect(lmsk is Some(_), content="true")
  let lmsk_v = lmsk.unwrap()
  inspect(lmsk_v.color_space, content="0")
  inspect(lmsk_v.color_components[0], content="65535")
  inspect(lmsk_v.opacity, content="100")
  inspect(lmsk_v.flag, content="128")
  let brst = layer.additional_info[1].as_blending_restrictions()
  inspect(brst, content="Some([0, 2])")
  let lmgm = layer.additional_info[2].as_mask_as_global()
  inspect(lmgm, content="Some(true)")
  let vmgm = layer.additional_info[3].as_mask_as_global()
  inspect(vmgm, content="Some(false)")
  // Round-trip: rebuild and compare byte-for-byte
  let rebuilt = psd.build()
  inspect(rebuilt.length(), content="336")
  inspect(rebuilt == fixture, content="true")
}

///|
test "PsdFile parse/build minimal PSB (47 bytes) round-trip" {
  // Minimal PSB: version=2, 1x1 RGB 8-bit, Raw compression
  // Same as PSD but version=2 and LayerAndMask section length is UInt64 (8 bytes instead of 4)
  let minimal_psb = b"\x38\x42\x50\x53\x00\x02\x00\x00\x00\x00\x00\x00\x00\x03\x00\x00\x00\x01\x00\x00\x00\x01\x00\x08\x00\x03\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
  let psb = PsdFile::parse(minimal_psb)
  inspect(psb.header.version, content="Psb")
  inspect(psb.header.channels, content="3")
  inspect(psb.header.height, content="1")
  inspect(psb.header.width, content="1")
  inspect(psb.header.depth, content="8")
  inspect(psb.header.color_mode, content="RGB")
  inspect(psb.layer_and_mask_info.layer_info is None, content="true")
  inspect(psb.image_data.compression, content="Raw")
  inspect(psb.image_data.data.length(), content="3")
  // Round-trip
  let rebuilt = psb.build()
  inspect(rebuilt.length(), content="47")
  inspect(rebuilt == minimal_psb, content="true")
}
