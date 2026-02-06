// Additional Layer Information: Descriptor-based and metadata keys
//
// PSD File Format Specification, "Additional Layer Information" section.
// These keys share a common pattern of version(4) + Descriptor.

///|
/// Compositor Used (key 'cinf').
///
/// Spec: "Key is 'cinf'. (Photoshop CC)"
///   | Length | Description      |
///   |--------|------------------|
///   | 4      | Version          |
///   | var    | Descriptor       |
pub fn AdditionalLayerInfo::as_compositor_used(
  self : AdditionalLayerInfo,
) -> (Int, @descriptor.Descriptor)? {
  if self.key != b"cinf" || self.data.length() < 4 {
    return None
  }
  let reader = @binary.Reader::new(self.data)
  try {
    let version = reader.read_u32_be().reinterpret_as_int()
    let desc = @descriptor.Descriptor::parse(reader)
    Some((version, desc))
  } catch {
    _ => None
  }
}

///|
pub fn AdditionalLayerInfo::from_compositor_used(
  version : Int,
  desc : @descriptor.Descriptor,
) -> AdditionalLayerInfo {
  let w = @binary.Writer::new()
  w.write_u32_be(version.reinterpret_as_uint())
  desc.build(w)
  { signature: b"\x38\x42\x49\x4D", key: b"cinf", data: w.to_bytes() }
}

///|
/// Vector Stroke Data (key 'vstk').
///
/// Spec: "Key is 'vstk'. (Photoshop CS6)"
///   | Length | Description      |
///   |--------|------------------|
///   | 4      | Version (= 16)   |
///   | var    | Descriptor       |
pub fn AdditionalLayerInfo::as_vector_stroke_data(
  self : AdditionalLayerInfo,
) -> (Int, @descriptor.Descriptor)? {
  if self.key != b"vstk" || self.data.length() < 4 {
    return None
  }
  let reader = @binary.Reader::new(self.data)
  try {
    let version = reader.read_u32_be().reinterpret_as_int()
    let desc = @descriptor.Descriptor::parse(reader)
    Some((version, desc))
  } catch {
    _ => None
  }
}

///|
pub fn AdditionalLayerInfo::from_vector_stroke_data(
  version : Int,
  desc : @descriptor.Descriptor,
) -> AdditionalLayerInfo {
  let w = @binary.Writer::new()
  w.write_u32_be(version.reinterpret_as_uint())
  desc.build(w)
  { signature: b"\x38\x42\x49\x4D", key: b"vstk", data: w.to_bytes() }
}

///|
/// Vector Stroke Content Data (key 'vscg').
///
/// Spec: "Key is 'vscg'. (Photoshop CS6)"
///   | Length | Description                                      |
///   |--------|--------------------------------------------------|
///   | 4      | Key for data ('SoCo', 'GdFl', or 'PtFl')        |
///   | 4      | Version (= 16)                                   |
///   | var    | Descriptor                                       |
pub fn AdditionalLayerInfo::as_vector_stroke_content(
  self : AdditionalLayerInfo,
) -> (Bytes, Int, @descriptor.Descriptor)? {
  if self.key != b"vscg" || self.data.length() < 8 {
    return None
  }
  let reader = @binary.Reader::new(self.data)
  try {
    let key = reader.read_bytes(4)
    let version = reader.read_u32_be().reinterpret_as_int()
    let desc = @descriptor.Descriptor::parse(reader)
    Some((key, version, desc))
  } catch {
    _ => None
  }
}

///|
pub fn AdditionalLayerInfo::from_vector_stroke_content(
  key : Bytes,
  version : Int,
  desc : @descriptor.Descriptor,
) -> AdditionalLayerInfo {
  let w = @binary.Writer::new()
  w.write_bytes(key)
  w.write_u32_be(version.reinterpret_as_uint())
  desc.build(w)
  { signature: b"\x38\x42\x49\x4D", key: b"vscg", data: w.to_bytes() }
}

///|
/// Metadata Setting (key 'shmd').
///
/// Spec: "Key is 'shmd'. (Photoshop 6.0)"
///   | Length | Description                              |
///   |--------|------------------------------------------|
///   | 4      | Count of metadata items                  |
///   | var    | For each item:                           |
///   |        |   4 bytes signature ('8BIM')             |
///   |        |   4 bytes key (e.g. 'mlst', 'cust')     |
///   |        |   1 byte copy on sheet duplication       |
///   |        |   3 bytes padding                        |
///   |        |   4 bytes data length                    |
///   |        |   var data                               |
pub(all) struct MetadataItem {
  signature : Bytes // '8BIM'
  key : Bytes // 4-byte key
  copy_on_sheet : Bool
  data : Bytes
} derive(Eq, Show)

///|
pub fn AdditionalLayerInfo::as_metadata_setting(
  self : AdditionalLayerInfo,
) -> Array[MetadataItem]? {
  if self.key != b"shmd" || self.data.length() < 4 {
    return None
  }
  let reader = @binary.Reader::new(self.data)
  try {
    let count = reader.read_u32_be().reinterpret_as_int()
    let items : Array[MetadataItem] = []
    for _i = 0; _i < count; _i = _i + 1 {
      let sig = reader.read_bytes(4)
      let key = reader.read_bytes(4)
      let copy_on_sheet = reader.read_u8() != b'\x00'
      reader.skip(3) // padding
      let length = reader.read_u32_be().reinterpret_as_int()
      let data = if length > 0 { reader.read_bytes(length) } else { b"" }
      items.push({ signature: sig, key, copy_on_sheet, data })
    }
    Some(items)
  } catch {
    _ => None
  }
}

///|
pub fn AdditionalLayerInfo::from_metadata_setting(
  items : Array[MetadataItem],
) -> AdditionalLayerInfo {
  let w = @binary.Writer::new()
  w.write_u32_be(items.length().reinterpret_as_uint())
  for i = 0; i < items.length(); i = i + 1 {
    let item = items[i]
    w.write_bytes(item.signature)
    w.write_bytes(item.key)
    w.write_u8(if item.copy_on_sheet { b'\x01' } else { b'\x00' })
    w.write_zeros(3) // padding
    w.write_u32_be(item.data.length().reinterpret_as_uint())
    if item.data.length() > 0 {
      w.write_bytes(item.data)
    }
  }
  { signature: b"\x38\x42\x49\x4D", key: b"shmd", data: w.to_bytes() }
}

///|
/// Text Engine Data (key 'Txt2').
///
/// Spec: "Key is 'Txt2'. (Photoshop CS3)"
///   Raw text engine data, stored as opaque bytes.
pub fn AdditionalLayerInfo::as_text_engine_data(
  self : AdditionalLayerInfo,
) -> Bytes? {
  if self.key != b"Txt2" {
    return None
  }
  Some(self.data)
}

///|
pub fn AdditionalLayerInfo::from_text_engine_data(
  data : Bytes,
) -> AdditionalLayerInfo {
  { signature: b"\x38\x42\x49\x4D", key: b"Txt2", data }
}

///|
/// Annotations (key 'Anno').
///
/// Spec: "Key is 'Anno'. (Photoshop 6.0)"
///   | Length | Description      |
///   |--------|------------------|
///   | 2      | Major version    |
///   | 2      | Minor version    |
///   | 4      | Count            |
///   | var    | Annotation data  |
pub(all) struct AnnotationsData {
  major_version : Int
  minor_version : Int
  count : Int
  data : Bytes // Raw annotation records
} derive(Eq, Show)

///|
pub fn AdditionalLayerInfo::as_annotations(
  self : AdditionalLayerInfo,
) -> AnnotationsData? {
  if self.key != b"Anno" || self.data.length() < 8 {
    return None
  }
  let reader = @binary.Reader::new(self.data)
  try {
    let major_version = reader.read_u16_be().reinterpret_as_int()
    let minor_version = reader.read_u16_be().reinterpret_as_int()
    let count = reader.read_u32_be().reinterpret_as_int()
    let remaining = reader.remaining()
    let data = if remaining > 0 { reader.read_bytes(remaining) } else { b"" }
    Some({ major_version, minor_version, count, data })
  } catch {
    _ => None
  }
}

///|
pub fn AdditionalLayerInfo::from_annotations(
  info : AnnotationsData,
) -> AdditionalLayerInfo {
  let w = @binary.Writer::new()
  w.write_u16_be(info.major_version.reinterpret_as_uint())
  w.write_u16_be(info.minor_version.reinterpret_as_uint())
  w.write_u32_be(info.count.reinterpret_as_uint())
  if info.data.length() > 0 {
    w.write_bytes(info.data)
  }
  { signature: b"\x38\x42\x49\x4D", key: b"Anno", data: w.to_bytes() }
}

///|
/// Gradient Map settings (key 'grdm').
///
/// Spec: "Key is 'grdm'. (Photoshop 6.0)"
///   | Length | Description                             |
///   |--------|--------------------------------------------------------------|
///   | 2      | Version (= 1)                           |
///   | var    | Gradient settings (reverse, dither, name, count, color stops, transparency stops) |
///
/// Stored as version + opaque data for round-trip fidelity.
pub(all) struct GradientMapData {
  version : Int
  data : Bytes // Raw gradient data after version
} derive(Eq, Show)

///|
pub fn AdditionalLayerInfo::as_gradient_map(
  self : AdditionalLayerInfo,
) -> GradientMapData? {
  if self.key != b"grdm" || self.data.length() < 2 {
    return None
  }
  let reader = @binary.Reader::new(self.data)
  try {
    let version = reader.read_u16_be().reinterpret_as_int()
    let remaining = reader.remaining()
    let data = if remaining > 0 { reader.read_bytes(remaining) } else { b"" }
    Some({ version, data })
  } catch {
    _ => None
  }
}

///|
pub fn AdditionalLayerInfo::from_gradient_map(
  info : GradientMapData,
) -> AdditionalLayerInfo {
  let w = @binary.Writer::new()
  w.write_u16_be(info.version.reinterpret_as_uint())
  if info.data.length() > 0 {
    w.write_bytes(info.data)
  }
  { signature: b"\x38\x42\x49\x4D", key: b"grdm", data: w.to_bytes() }
}
