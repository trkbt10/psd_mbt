///|
/// Calculate bytes per scanline for a given width and bit depth.
/// Handles 1-bit depth correctly: (width * depth + 7) / 8
/// For 8/16/32-bit: width * (depth / 8)
pub fn bytes_per_line(width : Int, depth : Int) -> Int {
  if depth < 8 {
    (width * depth + 7) / 8
  } else {
    width * (depth / 8)
  }
}
