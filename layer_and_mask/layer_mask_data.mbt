///|
/// Layer Mask Data (20 or 36 bytes).
/// Describes the mask associated with a layer.
pub(all) struct LayerMaskData {
  rect : @types.Rect
  default_color : Int // 0 or 255
  flags : Int // bit flags
  // Optional extended fields (36-byte variant)
  real_flags : Int?
  real_background : Int?
  real_rect : @types.Rect?
} derive(Eq, Show)

///|
/// Parse LayerMaskData from raw bytes (opaque mask_data field).
pub fn LayerMaskData::parse(data : Bytes) -> LayerMaskData? {
  if data.length() == 0 {
    return None
  }
  if data.length() < 20 {
    return None
  }
  let reader = @binary.Reader::new(data)
  try {
    let top = reader.read_i32_be()
    let left = reader.read_i32_be()
    let bottom = reader.read_i32_be()
    let right = reader.read_i32_be()
    let rect : @types.Rect = { top, left, bottom, right }
    let default_color = reader.read_u8().to_int()
    let flags = reader.read_u8().to_int()
    // Check for extended 36-byte variant
    if data.length() >= 36 {
      let real_flags = reader.read_u8().to_int()
      let real_background = reader.read_u8().to_int()
      let rt = reader.read_i32_be()
      let rl = reader.read_i32_be()
      let rb = reader.read_i32_be()
      let rr = reader.read_i32_be()
      let real_rect : @types.Rect = { top: rt, left: rl, bottom: rb, right: rr }
      Some({
        rect,
        default_color,
        flags,
        real_flags: Some(real_flags),
        real_background: Some(real_background),
        real_rect: Some(real_rect),
      })
    } else {
      Some({
        rect,
        default_color,
        flags,
        real_flags: None,
        real_background: None,
        real_rect: None,
      })
    }
  } catch {
    _ => None
  }
}

///|
/// Build LayerMaskData back to raw bytes (20 or 36 bytes).
pub fn LayerMaskData::build(self : LayerMaskData) -> Bytes {
  let w = @binary.Writer::new()
  w.write_i32_be(self.rect.top)
  w.write_i32_be(self.rect.left)
  w.write_i32_be(self.rect.bottom)
  w.write_i32_be(self.rect.right)
  w.write_u8(self.default_color.to_byte())
  w.write_u8(self.flags.to_byte())
  match (self.real_flags, self.real_background, self.real_rect) {
    (Some(rf), Some(rb), Some(rr)) => {
      w.write_u8(rf.to_byte())
      w.write_u8(rb.to_byte())
      w.write_i32_be(rr.top)
      w.write_i32_be(rr.left)
      w.write_i32_be(rr.bottom)
      w.write_i32_be(rr.right)
    }
    _ => {
      // Pad to 20 bytes: 16 (rect) + 1 (default_color) + 1 (flags) + 2 (padding)
      w.write_u8(b'\x00')
      w.write_u8(b'\x00')
    }
  }
  w.to_bytes()
}

///|
/// Check if the mask position is relative to the layer.
pub fn LayerMaskData::is_position_relative(self : LayerMaskData) -> Bool {
  (self.flags & 0x01) != 0
}

///|
/// Check if the mask is disabled.
pub fn LayerMaskData::is_disabled(self : LayerMaskData) -> Bool {
  (self.flags & 0x02) != 0
}

///|
/// Check if the invert flag is set when blending (obsolete).
pub fn LayerMaskData::is_invert_on_blend(self : LayerMaskData) -> Bool {
  (self.flags & 0x04) != 0
}

///|
/// Check if the mask comes from rendering other data.
pub fn LayerMaskData::is_from_render(self : LayerMaskData) -> Bool {
  (self.flags & 0x08) != 0
}

///|
/// Check if the mask has parameters applied.
pub fn LayerMaskData::has_parameters(self : LayerMaskData) -> Bool {
  (self.flags & 0x10) != 0
}
