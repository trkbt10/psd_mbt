// Image Resources: Resolution Info
//
// PSD File Format Specification, "Image Resources" section.

///|
/// Resolution Info (ID 1005).
///
/// Spec: "0x03ED (Photoshop 2.5)"
///   "ResolutionInfo structure. See Appendix A in Photoshop API Guide.pdf."
///   | Length | Description                            |
///   |--------|----------------------------------------|
///   | 4      | Horizontal resolution (fixed-point 16.16) |
///   | 2      | HResUnit (1 = pixels/inch, 2 = pixels/cm) |
///   | 2      | WidthUnit (1=in, 2=cm, 3=pt, 4=picas, 5=columns) |
///   | 4      | Vertical resolution (fixed-point 16.16)   |
///   | 2      | VResUnit (1 = pixels/inch, 2 = pixels/cm) |
///   | 2      | HeightUnit (1=in, 2=cm, 3=pt, 4=picas, 5=columns) |
pub(all) struct ResolutionInfo {
  h_res : Int // Horizontal resolution fixed-point 16.16
  h_res_unit : Int // 1 = pixels/inch, 2 = pixels/cm
  width_unit : Int // 1 = inches, 2 = cm, 3 = points, 4 = picas, 5 = columns
  v_res : Int // Vertical resolution fixed-point 16.16
  v_res_unit : Int // 1 = pixels/inch, 2 = pixels/cm
  height_unit : Int // 1 = inches, 2 = cm, 3 = points, 4 = picas, 5 = columns
} derive(Eq, Show)

///|
pub fn ImageResourceBlock::as_resolution_info(
  self : ImageResourceBlock,
) -> ResolutionInfo? {
  if self.resource_id != 1005 || self.data.length() < 16 {
    return None
  }
  let reader = @binary.Reader::new(self.data)
  try {
    let h_res = reader.read_i32_be()
    let h_res_unit = reader.read_u16_be().reinterpret_as_int()
    let width_unit = reader.read_u16_be().reinterpret_as_int()
    let v_res = reader.read_i32_be()
    let v_res_unit = reader.read_u16_be().reinterpret_as_int()
    let height_unit = reader.read_u16_be().reinterpret_as_int()
    Some({ h_res, h_res_unit, width_unit, v_res, v_res_unit, height_unit })
  } catch {
    _ => None
  }
}

///|
pub fn ImageResourceBlock::from_resolution_info(
  info : ResolutionInfo,
) -> ImageResourceBlock {
  let w = @binary.Writer::new()
  w.write_i32_be(info.h_res)
  w.write_u16_be(info.h_res_unit.reinterpret_as_uint())
  w.write_u16_be(info.width_unit.reinterpret_as_uint())
  w.write_i32_be(info.v_res)
  w.write_u16_be(info.v_res_unit.reinterpret_as_uint())
  w.write_u16_be(info.height_unit.reinterpret_as_uint())
  { resource_id: 1005, name: "", data: w.to_bytes() }
}
