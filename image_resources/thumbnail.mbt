///|
pub(all) struct ThumbnailResource {
  format : Int
  width : Int
  height : Int
  width_bytes : Int
  total_size : Int
  compressed_size : Int
  bits_per_pixel : Int
  num_planes : Int
  jfif_data : Bytes
} derive(Eq, Show)

///|
/// Parse a thumbnail resource from an ImageResourceBlock (ID 1036).
pub fn ImageResourceBlock::as_thumbnail(
  self : ImageResourceBlock,
) -> ThumbnailResource? {
  if self.resource_id != 1036 || self.data.length() < 28 {
    return None
  }
  let reader = @binary.Reader::new(self.data)
  try {
    let format = reader.read_u32_be().reinterpret_as_int()
    let width = reader.read_u32_be().reinterpret_as_int()
    let height = reader.read_u32_be().reinterpret_as_int()
    let width_bytes = reader.read_u32_be().reinterpret_as_int()
    let total_size = reader.read_u32_be().reinterpret_as_int()
    let compressed_size = reader.read_u32_be().reinterpret_as_int()
    let bits_per_pixel = reader.read_u16_be().reinterpret_as_int()
    let num_planes = reader.read_u16_be().reinterpret_as_int()
    let jfif_data = if compressed_size > 0 {
      reader.read_bytes(compressed_size)
    } else {
      b""
    }
    Some({
      format,
      width,
      height,
      width_bytes,
      total_size,
      compressed_size,
      bits_per_pixel,
      jfif_data,
      num_planes,
    })
  } catch {
    _ => None
  }
}

///|
/// Format 1 = kJpegRGB (JFIF data).
pub fn ThumbnailResource::is_jpeg(self : ThumbnailResource) -> Bool {
  self.format == 1
}

///|
/// Format 0 = kRawRGB (raw RGB pixel data).
pub fn ThumbnailResource::is_raw_rgb(self : ThumbnailResource) -> Bool {
  self.format == 0
}

///|
/// Create a thumbnail resource block from a ThumbnailResource.
pub fn ImageResourceBlock::from_thumbnail(
  thumb : ThumbnailResource,
) -> ImageResourceBlock {
  let w = @binary.Writer::new()
  w.write_u32_be(thumb.format.reinterpret_as_uint())
  w.write_u32_be(thumb.width.reinterpret_as_uint())
  w.write_u32_be(thumb.height.reinterpret_as_uint())
  w.write_u32_be(thumb.width_bytes.reinterpret_as_uint())
  w.write_u32_be(thumb.total_size.reinterpret_as_uint())
  w.write_u32_be(thumb.compressed_size.reinterpret_as_uint())
  w.write_u16_be(thumb.bits_per_pixel.reinterpret_as_uint())
  w.write_u16_be(thumb.num_planes.reinterpret_as_uint())
  if thumb.jfif_data.length() > 0 {
    w.write_bytes(thumb.jfif_data)
  }
  { resource_id: 1036, name: "", data: w.to_bytes() }
}
