///|
/// All adjustment layer ALI keys share a common pattern:
/// version(4) + Descriptor.
/// This provides a generic accessor for any descriptor-based adjustment key.

///|
/// Known adjustment layer keys.
let adjustment_keys : Array[Bytes] = [
  b"SoCo", // Solid Color
   b"GdFl", // Gradient Fill
   b"PtFl", // Pattern Fill
   b"levl", // Levels
   b"curv", // Curves
   b"expA", // Exposure
   b"vibA", // Vibrance
   b"hue2", // Hue/Saturation
   b"blnc", // Color Balance
   b"blwh", // Black and White
   b"phfl", // Photo Filter
   b"mixr", // Channel Mixer
   b"CgEd", // Content Generator Extra
   b"nvrt", // Invert
   b"post", // Posterize
   b"thrs", // Threshold
   b"selc", // Selective Color
   b"brit", // Brightness/Contrast
]

///|
/// Check if a key is a known adjustment layer key.
pub fn is_adjustment_key(key : Bytes) -> Bool {
  for i = 0; i < adjustment_keys.length(); i = i + 1 {
    if adjustment_keys[i] == key {
      return true
    }
  }
  false
}

///|
/// Parse an adjustment layer descriptor.
/// Common pattern: version(4) + Descriptor.
pub fn AdditionalLayerInfo::as_adjustment_descriptor(
  self : AdditionalLayerInfo,
) -> (Int, @descriptor.Descriptor)? {
  if not(is_adjustment_key(self.key)) {
    return None
  }
  if self.data.length() < 4 {
    return None
  }
  let reader = @binary.Reader::new(self.data)
  try {
    let version = reader.read_u32_be().reinterpret_as_int()
    let desc = @descriptor.Descriptor::parse(reader)
    Some((version, desc))
  } catch {
    _ => None
  }
}

///|
/// Build an adjustment layer ALI block from a descriptor.
pub fn AdditionalLayerInfo::from_adjustment_descriptor(
  key : Bytes,
  version : Int,
  desc : @descriptor.Descriptor,
) -> AdditionalLayerInfo {
  let w = @binary.Writer::new()
  w.write_u32_be(version.reinterpret_as_uint())
  desc.build(w)
  { signature: b"\x38\x42\x49\x4D", key, data: w.to_bytes() }
}
