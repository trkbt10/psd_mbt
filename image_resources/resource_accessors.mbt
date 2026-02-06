///|
/// Return the data as an ICC color profile (raw bytes) if resource_id == 1039.
pub fn ImageResourceBlock::as_icc_profile(self : ImageResourceBlock) -> Bytes? {
  if self.resource_id == 1039 {
    Some(self.data)
  } else {
    None
  }
}

///|
/// Return the data as an XMP metadata string if resource_id == 1060.
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
/// Create an XMP metadata resource block.
pub fn ImageResourceBlock::from_xmp(xmp : String) -> ImageResourceBlock {
  let buf = @buffer.new(size_hint=xmp.length())
  for i = 0; i < xmp.length(); i = i + 1 {
    buf.write_byte(xmp[i].to_int().to_byte())
  }
  { resource_id: 1060, name: "", data: buf.to_bytes() }
}

///|
/// Return the global angle (Int32) if resource_id == 1037.
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
/// Create a Global Angle resource block.
pub fn ImageResourceBlock::from_global_angle(angle : Int) -> ImageResourceBlock {
  let w = @binary.Writer::new()
  w.write_i32_be(angle)
  { resource_id: 1037, name: "", data: w.to_bytes() }
}

///|
/// Return the global altitude (Int32) if resource_id == 1049.
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
/// Create a Global Altitude resource block.
pub fn ImageResourceBlock::from_global_altitude(
  altitude : Int,
) -> ImageResourceBlock {
  let w = @binary.Writer::new()
  w.write_i32_be(altitude)
  { resource_id: 1049, name: "", data: w.to_bytes() }
}

///|
/// Return the transparency index (UInt16) if resource_id == 1047.
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
/// Create a Transparency Index resource block.
pub fn ImageResourceBlock::from_transparency_index(
  index : Int,
) -> ImageResourceBlock {
  let w = @binary.Writer::new()
  w.write_u16_be(index.reinterpret_as_uint())
  { resource_id: 1047, name: "", data: w.to_bytes() }
}
