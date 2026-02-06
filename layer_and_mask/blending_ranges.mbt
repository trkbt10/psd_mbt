///|
/// Layer Blending Ranges.
/// Describes source and destination ranges for blending.
pub(all) struct LayerBlendingRanges {
  composite_gray : Bytes // 4 bytes: src low/high, dst low/high
  channels : Array[Bytes] // each 4 bytes per channel
} derive(Eq, Show)

///|
/// Parse LayerBlendingRanges from raw bytes (opaque blending_ranges field).
pub fn LayerBlendingRanges::parse(data : Bytes) -> LayerBlendingRanges? {
  if data.length() == 0 {
    return None
  }
  // Need at least 4 bytes for composite gray
  if data.length() < 4 {
    return None
  }
  let reader = @binary.Reader::new(data)
  try {
    let composite_gray = reader.read_bytes(4)
    let channels : Array[Bytes] = []
    // Remaining bytes should be in multiples of 4
    while reader.remaining() >= 4 {
      channels.push(reader.read_bytes(4))
    }
    Some({ composite_gray, channels })
  } catch {
    _ => None
  }
}

///|
/// Build LayerBlendingRanges back to raw bytes.
pub fn LayerBlendingRanges::build(self : LayerBlendingRanges) -> Bytes {
  let w = @binary.Writer::new()
  w.write_bytes(self.composite_gray)
  for i = 0; i < self.channels.length(); i = i + 1 {
    w.write_bytes(self.channels[i])
  }
  w.to_bytes()
}
