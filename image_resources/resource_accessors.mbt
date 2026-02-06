// Image Resources: Core property accessors
//
// PSD File Format Specification, "Image Resources" section.

///|
/// ICC Profile (ID 1039).
///
/// Spec: "0x040F (Photoshop 4.0)"
///   "ICC Profile. The raw bytes of an ICC (International Color Consortium)
///    format profile. See ICC1v42_2006-05.pdf in the Documentation folder
///    and icProfileHeader.h in Sample Code\Common\Includes."
pub fn ImageResourceBlock::as_icc_profile(self : ImageResourceBlock) -> Bytes? {
  if self.resource_id == 1039 {
    Some(self.data)
  } else {
    None
  }
}

///|
/// XMP Metadata (ID 1060).
///
/// Spec: "0x0424 (Photoshop CS)"
///   "XMP metadata. File info. See documentation from Adobe XMP."
pub fn ImageResourceBlock::as_xmp(self : ImageResourceBlock) -> String? {
  if self.resource_id == 1060 {
    let buf = @buffer.new(size_hint=self.data.length())
    for i = 0; i < self.data.length(); i = i + 1 {
      buf.write_char(self.data[i].to_int().unsafe_to_char())
    }
    Some(buf.to_string())
  } else {
    None
  }
}

///|
pub fn ImageResourceBlock::from_xmp(xmp : String) -> ImageResourceBlock {
  let buf = @buffer.new(size_hint=xmp.length())
  for i = 0; i < xmp.length(); i = i + 1 {
    buf.write_byte(xmp[i].to_int().to_byte())
  }
  { resource_id: 1060, name: "", data: buf.to_bytes() }
}

///|
/// Global Angle (ID 1037).
///
/// Spec: "0x040D (Photoshop 4.0)"
///   "Global Angle. 4 bytes that contain an integer between 0 and 359,
///    which is the global lighting angle for effects layer. If not present,
///    assumed to be 30."
pub fn ImageResourceBlock::as_global_angle(self : ImageResourceBlock) -> Int? {
  if self.resource_id == 1037 && self.data.length() >= 4 {
    let reader = @binary.Reader::new(self.data)
    Some(reader.read_i32_be()) catch {
      _ => None
    }
  } else {
    None
  }
}

///|
pub fn ImageResourceBlock::from_global_angle(angle : Int) -> ImageResourceBlock {
  let w = @binary.Writer::new()
  w.write_i32_be(angle)
  { resource_id: 1037, name: "", data: w.to_bytes() }
}

///|
/// Global Altitude (ID 1049).
///
/// Spec: "0x0419 (Photoshop 6.0)"
///   "Global Altitude. 4 byte entry for altitude."
pub fn ImageResourceBlock::as_global_altitude(
  self : ImageResourceBlock,
) -> Int? {
  if self.resource_id == 1049 && self.data.length() >= 4 {
    let reader = @binary.Reader::new(self.data)
    Some(reader.read_i32_be()) catch {
      _ => None
    }
  } else {
    None
  }
}

///|
pub fn ImageResourceBlock::from_global_altitude(
  altitude : Int,
) -> ImageResourceBlock {
  let w = @binary.Writer::new()
  w.write_i32_be(altitude)
  { resource_id: 1049, name: "", data: w.to_bytes() }
}

///|
/// Transparency Index (ID 1047).
///
/// Spec: "0x0417 (Photoshop 6.0)"
///   "Transparency Index. 2 bytes for the index of transparent color,
///    if any."
pub fn ImageResourceBlock::as_transparency_index(
  self : ImageResourceBlock,
) -> Int? {
  if self.resource_id == 1047 && self.data.length() >= 2 {
    let reader = @binary.Reader::new(self.data)
    Some(reader.read_u16_be().reinterpret_as_int()) catch {
      _ => None
    }
  } else {
    None
  }
}

///|
pub fn ImageResourceBlock::from_transparency_index(
  index : Int,
) -> ImageResourceBlock {
  let w = @binary.Writer::new()
  w.write_u16_be(index.reinterpret_as_uint())
  { resource_id: 1047, name: "", data: w.to_bytes() }
}
