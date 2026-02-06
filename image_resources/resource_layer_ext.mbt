// Image Resources: Layer-related metadata resource accessors
//
// PSD File Format Specification, "Image Resources" section.

///|
/// Layer State Info (ID 1024).
///
/// Spec: "0x0400 (Photoshop 4.0)"
///   "Layer state information. 2 bytes containing the index of target layer
///    (0 = bottom layer)."
pub fn ImageResourceBlock::as_layer_state_info(
  self : ImageResourceBlock,
) -> Int? {
  if self.resource_id != 1024 || self.data.length() < 2 {
    return None
  }
  let reader = @binary.Reader::new(self.data)
  Some(reader.read_u16_be().reinterpret_as_int()) catch {
    _ => None
  }
}

///|
pub fn ImageResourceBlock::from_layer_state_info(
  target_layer : Int,
) -> ImageResourceBlock {
  let w = @binary.Writer::new()
  w.write_u16_be(target_layer.reinterpret_as_uint())
  { resource_id: 1024, name: "", data: w.to_bytes() }
}

///|
/// Layer Group Info (ID 1025).
///
/// Spec: "0x0401 (Photoshop 4.0)"
///   "Layer group information. 2 bytes per layer containing a group ID
///    for the dragging groups. Layers in a group have the same group ID."
pub fn ImageResourceBlock::as_layer_group_info(
  self : ImageResourceBlock,
) -> Array[Int]? {
  if self.resource_id != 1025 {
    return None
  }
  let reader = @binary.Reader::new(self.data)
  let ids : Array[Int] = []
  try {
    while reader.remaining() >= 2 {
      ids.push(reader.read_u16_be().reinterpret_as_int())
    }
  } catch {
    _ => ()
  }
  Some(ids)
}

///|
pub fn ImageResourceBlock::from_layer_group_info(
  ids : Array[Int],
) -> ImageResourceBlock {
  let w = @binary.Writer::new()
  for i = 0; i < ids.length(); i = i + 1 {
    w.write_u16_be(ids[i].reinterpret_as_uint())
  }
  { resource_id: 1025, name: "", data: w.to_bytes() }
}

///|
/// Layer Selection ID(s) (ID 1069).
///
/// Spec: "0x042D (Photoshop CS2)"
///   "Layer Selection ID(s). 2 byte count, following is repeated for
///    each count: 4 bytes of layer ID."
pub fn ImageResourceBlock::as_layer_selection_ids(
  self : ImageResourceBlock,
) -> Array[Int]? {
  if self.resource_id != 1069 || self.data.length() < 2 {
    return None
  }
  let reader = @binary.Reader::new(self.data)
  try {
    let count = reader.read_u16_be().reinterpret_as_int()
    let ids : Array[Int] = []
    for _i = 0; _i < count; _i = _i + 1 {
      ids.push(reader.read_u32_be().reinterpret_as_int())
    }
    Some(ids)
  } catch {
    _ => None
  }
}

///|
pub fn ImageResourceBlock::from_layer_selection_ids(
  ids : Array[Int],
) -> ImageResourceBlock {
  let w = @binary.Writer::new()
  w.write_u16_be(ids.length().reinterpret_as_uint())
  for i = 0; i < ids.length(); i = i + 1 {
    w.write_u32_be(ids[i].reinterpret_as_uint())
  }
  { resource_id: 1069, name: "", data: w.to_bytes() }
}

///|
/// Layer Group(s) Enabled ID (ID 1072).
///
/// Spec: "0x0430 (Photoshop CS2)"
///   "Layer Group(s) Enabled ID. 1 byte for each layer in the document,
///    repeated by length of the resource. NOTE: Layer groups have start
///    and end markers."
pub fn ImageResourceBlock::as_layer_groups_enabled(
  self : ImageResourceBlock,
) -> Array[Bool]? {
  if self.resource_id != 1072 {
    return None
  }
  let flags : Array[Bool] = []
  for i = 0; i < self.data.length(); i = i + 1 {
    flags.push(self.data[i] != b'\x00')
  }
  Some(flags)
}

///|
pub fn ImageResourceBlock::from_layer_groups_enabled(
  flags : Array[Bool],
) -> ImageResourceBlock {
  let buf = @buffer.new(size_hint=flags.length())
  for i = 0; i < flags.length(); i = i + 1 {
    buf.write_byte(if flags[i] { b'\x01' } else { b'\x00' })
  }
  { resource_id: 1072, name: "", data: buf.to_bytes() }
}
