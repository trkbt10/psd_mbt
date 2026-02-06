// Image Resources: Grid and Guides
//
// PSD File Format Specification, "Image Resources" section.

///|
/// Grid and Guides Information (ID 1032).
///
/// Spec: "0x0408 (Photoshop 4.0)"
///   "Grid and guides information. See See Grid and guides resource format."
///   | Length | Description                       |
///   |--------|-----------------------------------|
///   | 4      | Version (= 1)                    |
///   | 4      | Future: grid horizontal (32/inch) |
///   | 4      | Future: grid vertical (32/inch)   |
///   | 4      | Number of guide resource blocks   |
///   | var    | Guide records (5 bytes each)      |
///
///   Guide record:
///   | Length | Description                                   |
///   |--------|-----------------------------------------------|
///   | 4      | Location of guide in document coordinates     |
///   | 1      | Direction (0 = vertical, 1 = horizontal)      |
pub(all) struct GridAndGuides {
  version : Int
  grid_horizontal : Int
  grid_vertical : Int
  guides : Array[GuideRecord]
} derive(Eq, Show)

///|
pub(all) struct GuideRecord {
  position : Int
  direction : Int
} derive(Eq, Show)

///|
pub fn ImageResourceBlock::as_grid_and_guides(
  self : ImageResourceBlock,
) -> GridAndGuides? {
  if self.resource_id != 1032 || self.data.length() < 16 {
    return None
  }
  let reader = @binary.Reader::new(self.data)
  try {
    let version = reader.read_u32_be().reinterpret_as_int()
    let grid_horizontal = reader.read_u32_be().reinterpret_as_int()
    let grid_vertical = reader.read_u32_be().reinterpret_as_int()
    let guide_count = reader.read_u32_be().reinterpret_as_int()
    let guides : Array[GuideRecord] = []
    for _i = 0; _i < guide_count; _i = _i + 1 {
      let position = reader.read_i32_be()
      let direction = reader.read_u8().to_int()
      guides.push({ position, direction })
    }
    Some({ version, grid_horizontal, grid_vertical, guides })
  } catch {
    _ => None
  }
}

///|
pub fn ImageResourceBlock::from_grid_and_guides(
  gg : GridAndGuides,
) -> ImageResourceBlock {
  let w = @binary.Writer::new()
  w.write_u32_be(gg.version.reinterpret_as_uint())
  w.write_u32_be(gg.grid_horizontal.reinterpret_as_uint())
  w.write_u32_be(gg.grid_vertical.reinterpret_as_uint())
  w.write_u32_be(gg.guides.length().reinterpret_as_uint())
  for i = 0; i < gg.guides.length(); i = i + 1 {
    w.write_i32_be(gg.guides[i].position)
    w.write_u8(gg.guides[i].direction.to_byte())
  }
  { resource_id: 1032, name: "", data: w.to_bytes() }
}
