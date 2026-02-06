// Additional Layer Information: Adjustment Layer keys
//
// PSD File Format Specification, "Additional Layer Information" section.
// All adjustment layer keys share a common pattern: version(4) + Descriptor.
//
// Spec: "The following resources have a version number of 4 bytes
//   followed by a Descriptor (See See Descriptor structure)."
//
// Known adjustment layer keys:
//   | Key    | Name                    | Photoshop Version |
//   |--------|-------------------------|-------------------|
//   | 'SoCo' | Solid Color sheet       | Photoshop 6.0     |
//   | 'GdFl' | Gradient fill setting   | Photoshop 6.0     |
//   | 'PtFl' | Pattern fill setting    | Photoshop 6.0     |
//   | 'levl' | Levels                  | Photoshop CS      |
//   | 'curv' | Curves                  | Photoshop CS      |
//   | 'expA' | Exposure                | Photoshop CS2     |
//   | 'vibA' | Vibrance                | Photoshop CS3     |
//   | 'hue2' | Hue/Saturation (new)    | Photoshop CS      |
//   | 'blnc' | Color Balance           | Photoshop CS      |
//   | 'blwh' | Black and White         | Photoshop CS3     |
//   | 'phfl' | Photo Filter            | Photoshop CS      |
//   | 'mixr' | Channel Mixer           | Photoshop CS      |
//   | 'CgEd' | Content Generator Extra | Photoshop CC      |
//   | 'nvrt' | Invert                  | Photoshop CS      |
//   | 'post' | Posterize               | Photoshop CS      |
//   | 'thrs' | Threshold               | Photoshop CS      |
//   | 'selc' | Selective Color         | Photoshop CS      |
//   | 'brit' | Brightness/Contrast     | Photoshop CS3     |

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
///
/// Common pattern for all adjustment keys: version(4) + Descriptor.
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
