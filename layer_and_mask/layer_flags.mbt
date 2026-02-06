///|
/// Check if transparency is protected for this layer.
pub fn LayerRecord::is_transparency_protected(self : LayerRecord) -> Bool {
  (self.flags & 0x01) != 0
}

///|
/// Check if this layer is visible.
pub fn LayerRecord::is_visible(self : LayerRecord) -> Bool {
  (self.flags & 0x02) != 0
}

///|
/// Check if the obsolete bit (bit 2) is set.
pub fn LayerRecord::is_obsolete(self : LayerRecord) -> Bool {
  (self.flags & 0x04) != 0
}

///|
/// Check if bit 4 of flags is 1 and bit 3 has useful info (PS5+).
pub fn LayerRecord::has_useful_info(self : LayerRecord) -> Bool {
  (self.flags & 0x08) != 0
}

///|
/// Check if pixel data is irrelevant to appearance (bit 4).
pub fn LayerRecord::is_pixel_irrelevant(self : LayerRecord) -> Bool {
  (self.flags & 0x10) != 0
}

///|
/// Parse mask_data field as typed LayerMaskData.
pub fn LayerRecord::as_mask_data(self : LayerRecord) -> LayerMaskData? {
  LayerMaskData::parse(self.mask_data)
}

///|
/// Parse blending_ranges field as typed LayerBlendingRanges.
pub fn LayerRecord::as_blending_ranges(
  self : LayerRecord,
) -> LayerBlendingRanges? {
  LayerBlendingRanges::parse(self.blending_ranges)
}
