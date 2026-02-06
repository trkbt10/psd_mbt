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
