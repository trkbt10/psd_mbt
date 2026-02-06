// Image Resources: Path Resources
//
// PSD File Format Specification, "Image Resources" section.
//
// Spec: "0x07D0-0x0BB6 (Photoshop 2.0)"
//   "Path Information (saved paths). See See Path resource format."
//   Resource IDs 2000-2997: Named paths (name is stored in resource name field).
//   Resource ID 2999: Name of clipping path.
//
// Path resource format:
//   Each path resource consists of a series of 26-byte path records.
//   | Length | Description            |
//   |--------|------------------------|
//   | 2      | Record type            |
//   | 24     | Record data            |
//
//   Record types:
//   | Type | Description                          |
//   |------|--------------------------------------|
//   | 0    | Closed subpath length record         |
//   | 1    | Closed subpath Bezier knot, linked    |
//   | 2    | Closed subpath Bezier knot, unlinked  |
//   | 3    | Open subpath length record            |
//   | 4    | Open subpath Bezier knot, linked      |
//   | 5    | Open subpath Bezier knot, unlinked    |
//   | 6    | Path fill rule record                |
//   | 7    | Clipboard record                     |
//   | 8    | Initial fill rule record              |

///|
pub(all) struct PathResource {
  records : Array[PathRecord]
} derive(Eq, Show)

///|
/// Each path record is 26 bytes: 2 bytes type + 24 bytes data.
///
/// Bezier knot records contain 3 control points (preceding, anchor, leaving),
/// each as a pair of fixed-point 8.24 values (vertical, horizontal).
pub(all) enum PathRecord {
  ClosedSubpathLength(Int) // type 0
  ClosedSubpathBezierKnotLinked(BezierKnot) // type 1
  ClosedSubpathBezierKnotUnlinked(BezierKnot) // type 2
  OpenSubpathLength(Int) // type 3
  OpenSubpathBezierKnotLinked(BezierKnot) // type 4
  OpenSubpathBezierKnotUnlinked(BezierKnot) // type 5
  PathFill(Int) // type 6
  Clipboard(ClipboardRecord) // type 7
  InitialFill(Int) // type 8
} derive(Eq, Show)

///|
/// Bezier knot: 3 points (control_preceding, anchor, control_leaving).
/// Each point is a pair of fixed-point 8.24 values (vertical, horizontal).
pub(all) struct BezierKnot {
  control_preceding : (Double, Double)
  anchor : (Double, Double)
  control_leaving : (Double, Double)
} derive(Eq, Show)

///|
/// Clipboard record: bounding box + resolution.
pub(all) struct ClipboardRecord {
  top : Double
  left : Double
  bottom : Double
  right : Double
  resolution : Double
} derive(Eq, Show)

///|
/// Convert fixed-point 8.24 Int32 to Double.
fn fixed_8_24_to_double(value : Int) -> Double {
  value.to_double() / 16777216.0 // 2^24
}

///|
/// Convert Double to fixed-point 8.24 Int32.
fn double_to_fixed_8_24(value : Double) -> Int {
  (value * 16777216.0).to_int()
}

///|
/// Read a BezierKnot from a reader (24 bytes: 6 fixed-point 8.24 values).
fn read_bezier_knot(
  reader : @binary.Reader,
) -> BezierKnot raise @types.PsdError {
  let cp_v = fixed_8_24_to_double(reader.read_i32_be())
  let cp_h = fixed_8_24_to_double(reader.read_i32_be())
  let a_v = fixed_8_24_to_double(reader.read_i32_be())
  let a_h = fixed_8_24_to_double(reader.read_i32_be())
  let cl_v = fixed_8_24_to_double(reader.read_i32_be())
  let cl_h = fixed_8_24_to_double(reader.read_i32_be())
  {
    control_preceding: (cp_v, cp_h),
    anchor: (a_v, a_h),
    control_leaving: (cl_v, cl_h),
  }
}

///|
/// Write a BezierKnot to a writer (24 bytes).
fn write_bezier_knot(writer : @binary.Writer, knot : BezierKnot) -> Unit {
  writer.write_i32_be(double_to_fixed_8_24(knot.control_preceding.0))
  writer.write_i32_be(double_to_fixed_8_24(knot.control_preceding.1))
  writer.write_i32_be(double_to_fixed_8_24(knot.anchor.0))
  writer.write_i32_be(double_to_fixed_8_24(knot.anchor.1))
  writer.write_i32_be(double_to_fixed_8_24(knot.control_leaving.0))
  writer.write_i32_be(double_to_fixed_8_24(knot.control_leaving.1))
}

///|
/// Check if a resource ID is a path resource (2000-2997 or 2999).
pub fn is_path_resource_id(id : Int) -> Bool {
  (id >= 2000 && id <= 2997) || id == 2999
}

///|
/// Parse a PathResource from an ImageResourceBlock.
pub fn ImageResourceBlock::as_path_resource(
  self : ImageResourceBlock,
) -> PathResource? {
  if not(is_path_resource_id(self.resource_id)) {
    return None
  }
  if self.data.length() < 26 {
    return None
  }
  let reader = @binary.Reader::new(self.data)
  let records : Array[PathRecord] = []
  try {
    while reader.remaining() >= 26 {
      let record_type = reader.read_u16_be().reinterpret_as_int()
      match record_type {
        0 => {
          let count = reader.read_u16_be().reinterpret_as_int()
          reader.skip(22) // padding
          records.push(ClosedSubpathLength(count))
        }
        1 => {
          let knot = read_bezier_knot(reader)
          records.push(ClosedSubpathBezierKnotLinked(knot))
        }
        2 => {
          let knot = read_bezier_knot(reader)
          records.push(ClosedSubpathBezierKnotUnlinked(knot))
        }
        3 => {
          let count = reader.read_u16_be().reinterpret_as_int()
          reader.skip(22) // padding
          records.push(OpenSubpathLength(count))
        }
        4 => {
          let knot = read_bezier_knot(reader)
          records.push(OpenSubpathBezierKnotLinked(knot))
        }
        5 => {
          let knot = read_bezier_knot(reader)
          records.push(OpenSubpathBezierKnotUnlinked(knot))
        }
        6 => {
          let fill_rule = reader.read_u16_be().reinterpret_as_int()
          reader.skip(22) // padding
          records.push(PathFill(fill_rule))
        }
        7 => {
          let top = fixed_8_24_to_double(reader.read_i32_be())
          let left = fixed_8_24_to_double(reader.read_i32_be())
          let bottom = fixed_8_24_to_double(reader.read_i32_be())
          let right = fixed_8_24_to_double(reader.read_i32_be())
          let resolution = fixed_8_24_to_double(reader.read_i32_be())
          reader.skip(4) // padding (24 - 20 = 4)
          records.push(Clipboard({ top, left, bottom, right, resolution }))
        }
        8 => {
          let fill = reader.read_u16_be().reinterpret_as_int()
          reader.skip(22) // padding
          records.push(InitialFill(fill))
        }
        _ =>
          // Unknown record type, skip remaining 24 bytes
          reader.skip(24)
      }
    }
  } catch {
    _ => ()
  }
  Some({ records, })
}

///|
/// Create a path resource block from a PathResource.
pub fn ImageResourceBlock::from_path_resource(
  resource_id : Int,
  path : PathResource,
) -> ImageResourceBlock {
  let w = @binary.Writer::new()
  for i = 0; i < path.records.length(); i = i + 1 {
    match path.records[i] {
      ClosedSubpathLength(count) => {
        w.write_u16_be(0U)
        w.write_u16_be(count.reinterpret_as_uint())
        w.write_zeros(22)
      }
      ClosedSubpathBezierKnotLinked(knot) => {
        w.write_u16_be(1U)
        write_bezier_knot(w, knot)
      }
      ClosedSubpathBezierKnotUnlinked(knot) => {
        w.write_u16_be(2U)
        write_bezier_knot(w, knot)
      }
      OpenSubpathLength(count) => {
        w.write_u16_be(3U)
        w.write_u16_be(count.reinterpret_as_uint())
        w.write_zeros(22)
      }
      OpenSubpathBezierKnotLinked(knot) => {
        w.write_u16_be(4U)
        write_bezier_knot(w, knot)
      }
      OpenSubpathBezierKnotUnlinked(knot) => {
        w.write_u16_be(5U)
        write_bezier_knot(w, knot)
      }
      PathFill(fill_rule) => {
        w.write_u16_be(6U)
        w.write_u16_be(fill_rule.reinterpret_as_uint())
        w.write_zeros(22)
      }
      Clipboard(clip) => {
        w.write_u16_be(7U)
        w.write_i32_be(double_to_fixed_8_24(clip.top))
        w.write_i32_be(double_to_fixed_8_24(clip.left))
        w.write_i32_be(double_to_fixed_8_24(clip.bottom))
        w.write_i32_be(double_to_fixed_8_24(clip.right))
        w.write_i32_be(double_to_fixed_8_24(clip.resolution))
        w.write_zeros(4)
      }
      InitialFill(fill) => {
        w.write_u16_be(8U)
        w.write_u16_be(fill.reinterpret_as_uint())
        w.write_zeros(22)
      }
    }
  }
  { resource_id, name: "", data: w.to_bytes() }
}
