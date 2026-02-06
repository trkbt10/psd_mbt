///|
/// PSD Descriptor: a key-value structure used extensively in modern PSD files.
pub(all) struct Descriptor {
  class_id_name : String // Unicode name
  class_id : String // classID (variable length key)
  items : Array[DescriptorItem]
} derive(Eq, Show)

///|
pub(all) struct DescriptorItem {
  key : String // key ID (variable length key)
  value : DescriptorValue
} derive(Eq, Show)

///|
/// ~16 OSType value variants found in PSD descriptors.
pub(all) enum DescriptorValue {
  // Core types
  Boolean(Bool) // 'bool'
  Integer(Int) // 'long'
  LargeInteger(Int64) // 'comp'
  Double(Double) // 'doub'
  String(String) // 'TEXT'
  Enumerated(String, String) // 'enum': typeID + value
  UnitFloat(Int, Double) // 'UntF': unit + value

  // Compound types
  Descriptor(Descriptor) // 'Objc'
  List(Array[DescriptorValue]) // 'VlLs'
  Reference(Array[ReferenceItem]) // 'obj '
  Class(String, String) // 'type'/'GlbC': name + classID
  Alias(Bytes) // 'alis'
  RawData(Bytes) // 'tdta'

  // PS6+ types
  ObjectArray(Descriptor) // 'ObAr'
  GlobalObject(Descriptor) // 'GlbO'
} derive(Eq, Show)

///|
pub(all) enum ReferenceItem {
  Property(String, String, String) // classID name, classID, keyID
  Class(String, String) // name, classID
  EnumeratedRef(String, String, String, String) // name, classID, typeID, value
  Offset(String, String, Int) // name, classID, offset
  Identifier(String, String, Int) // name, classID, identifier
  Index(String, String, Int) // name, classID, index
  Name(String, String, String) // classIdName, classID, name value
} derive(Eq, Show)

///|
/// Read a variable-length ID string.
/// If the length field is 0, read 4 bytes. Otherwise read length bytes.
fn read_id(reader : @binary.Reader) -> String raise @types.PsdError {
  let len = reader.read_u32_be().reinterpret_as_int()
  let actual_len = if len == 0 { 4 } else { len }
  let bytes = reader.read_bytes(actual_len)
  bytes_to_string(bytes)
}

///|
/// Write a variable-length ID string.
/// If the string is exactly 4 bytes, write length=0 then the 4 bytes.
/// Otherwise write the actual length.
fn write_id(writer : @binary.Writer, id : String) -> Unit {
  if id.length() == 4 {
    writer.write_u32_be(0U)
  } else {
    writer.write_u32_be(id.length().reinterpret_as_uint())
  }
  for i = 0; i < id.length(); i = i + 1 {
    writer.write_u8(id[i].to_int().to_byte())
  }
}

///|
/// Read a Unicode string (4-byte length + UTF-16BE chars).
fn read_unicode_string(reader : @binary.Reader) -> String raise @types.PsdError {
  let char_count = reader.read_u32_be().reinterpret_as_int()
  let buf = @buffer.new(size_hint=char_count)
  for _i = 0; _i < char_count; _i = _i + 1 {
    let code_unit = reader.read_u16_be().reinterpret_as_int()
    if code_unit != 0 {
      buf.write_char(code_unit.unsafe_to_char())
    }
  }
  buf.to_string()
}

///|
/// Write a Unicode string (4-byte length + UTF-16BE chars).
fn write_unicode_string(writer : @binary.Writer, s : String) -> Unit {
  writer.write_u32_be(s.length().reinterpret_as_uint())
  for i = 0; i < s.length(); i = i + 1 {
    writer.write_u16_be(s[i].to_int().reinterpret_as_uint())
  }
}

///|
fn bytes_to_string(data : Bytes) -> String {
  let buf = @buffer.new(size_hint=data.length())
  for i = 0; i < data.length(); i = i + 1 {
    buf.write_char(data[i].to_int().unsafe_to_char())
  }
  buf.to_string()
}

///|
fn string_to_bytes(s : String) -> Bytes {
  let buf = @buffer.new(size_hint=s.length())
  for i = 0; i < s.length(); i = i + 1 {
    buf.write_byte(s[i].to_int().to_byte())
  }
  buf.to_bytes()
}

///|
/// Parse a Descriptor from a binary reader.
pub fn Descriptor::parse(
  reader : @binary.Reader,
) -> Descriptor raise @types.PsdError {
  let class_id_name = read_unicode_string(reader)
  let class_id = read_id(reader)
  let item_count = reader.read_u32_be().reinterpret_as_int()
  let items : Array[DescriptorItem] = []
  for _i = 0; _i < item_count; _i = _i + 1 {
    let key = read_id(reader)
    let value = parse_value(reader)
    items.push({ key, value })
  }
  { class_id_name, class_id, items }
}

///|
/// Build a Descriptor to a binary writer.
pub fn Descriptor::build(self : Descriptor, writer : @binary.Writer) -> Unit {
  write_unicode_string(writer, self.class_id_name)
  write_id(writer, self.class_id)
  writer.write_u32_be(self.items.length().reinterpret_as_uint())
  for i = 0; i < self.items.length(); i = i + 1 {
    write_id(writer, self.items[i].key)
    build_value(self.items[i].value, writer)
  }
}

///|
/// Parse a descriptor value based on its OSType tag.
fn parse_value(
  reader : @binary.Reader,
) -> DescriptorValue raise @types.PsdError {
  let os_type = reader.read_bytes(4)
  let tag = bytes_to_string(os_type)
  match tag {
    "bool" => {
      let v = reader.read_u8()
      Boolean(v != b'\x00')
    }
    "long" => {
      let v = reader.read_i32_be()
      Integer(v)
    }
    "comp" => {
      let hi = reader.read_u32_be().reinterpret_as_int()
      let lo = reader.read_u32_be().reinterpret_as_int()
      let v = (hi.to_int64() << 32) | (lo.to_int64() & 0xFFFFFFFFL)
      LargeInteger(v)
    }
    "doub" => {
      let bits = reader.read_u64_be()
      let v = bits.reinterpret_as_double()
      Double(v)
    }
    "TEXT" => {
      let s = read_unicode_string(reader)
      String(s)
    }
    "enum" => {
      let type_id = read_id(reader)
      let enum_val = read_id(reader)
      Enumerated(type_id, enum_val)
    }
    "UntF" => {
      let unit_bytes = reader.read_bytes(4)
      let unit = bytes_to_string(unit_bytes)
      let unit_int = (unit[0].to_int() << 24) |
        (unit[1].to_int() << 16) |
        (unit[2].to_int() << 8) |
        unit[3].to_int()
      let bits = reader.read_u64_be()
      let value = bits.reinterpret_as_double()
      UnitFloat(unit_int, value)
    }
    "Objc" => {
      let desc = Descriptor::parse(reader)
      Descriptor(desc)
    }
    "GlbO" => {
      let desc = Descriptor::parse(reader)
      GlobalObject(desc)
    }
    "VlLs" => {
      let count = reader.read_u32_be().reinterpret_as_int()
      let values : Array[DescriptorValue] = []
      for _i = 0; _i < count; _i = _i + 1 {
        values.push(parse_value(reader))
      }
      List(values)
    }
    "obj " => {
      let count = reader.read_u32_be().reinterpret_as_int()
      let refs : Array[ReferenceItem] = []
      for _i = 0; _i < count; _i = _i + 1 {
        refs.push(parse_reference_item(reader))
      }
      Reference(refs)
    }
    "type" | "GlbC" => {
      let name = read_unicode_string(reader)
      let class_id = read_id(reader)
      Class(name, class_id)
    }
    "alis" => {
      let length = reader.read_u32_be().reinterpret_as_int()
      let data = reader.read_bytes(length)
      Alias(data)
    }
    "tdta" => {
      let length = reader.read_u32_be().reinterpret_as_int()
      let data = reader.read_bytes(length)
      RawData(data)
    }
    "ObAr" => {
      let desc = Descriptor::parse(reader)
      ObjectArray(desc)
    }
    // Unknown OSType: try to read it as raw data with a 4-byte length
    _ => {
      let length = reader.read_u32_be().reinterpret_as_int()
      let data = reader.read_bytes(length)
      RawData(data)
    }
  }
}

///|
/// Parse a reference item from a reader.
fn parse_reference_item(
  reader : @binary.Reader,
) -> ReferenceItem raise @types.PsdError {
  let os_type = reader.read_bytes(4)
  let tag = bytes_to_string(os_type)
  match tag {
    "prop" => {
      let name = read_unicode_string(reader)
      let class_id = read_id(reader)
      let key_id = read_id(reader)
      Property(name, class_id, key_id)
    }
    "Clss" => {
      let name = read_unicode_string(reader)
      let class_id = read_id(reader)
      Class(name, class_id)
    }
    "Enmr" => {
      let name = read_unicode_string(reader)
      let class_id = read_id(reader)
      let type_id = read_id(reader)
      let enum_val = read_id(reader)
      EnumeratedRef(name, class_id, type_id, enum_val)
    }
    "rele" => {
      let name = read_unicode_string(reader)
      let class_id = read_id(reader)
      let offset = reader.read_u32_be().reinterpret_as_int()
      Offset(name, class_id, offset)
    }
    "Idnt" => {
      let name = read_unicode_string(reader)
      let class_id = read_id(reader)
      let identifier = reader.read_u32_be().reinterpret_as_int()
      Identifier(name, class_id, identifier)
    }
    "indx" => {
      let name = read_unicode_string(reader)
      let class_id = read_id(reader)
      let index = reader.read_u32_be().reinterpret_as_int()
      Index(name, class_id, index)
    }
    "name" => {
      let name = read_unicode_string(reader)
      let class_id = read_id(reader)
      let name_value = read_unicode_string(reader)
      Name(name, class_id, name_value)
    }
    // Unknown reference type - try to skip it gracefully
    _ => {
      let name = read_unicode_string(reader)
      let class_id = read_id(reader)
      Class(name, class_id)
    }
  }
}

///|
/// Build a descriptor value to a binary writer.
fn build_value(value : DescriptorValue, writer : @binary.Writer) -> Unit {
  match value {
    Boolean(v) => {
      writer.write_bytes(string_to_bytes("bool"))
      writer.write_u8(if v { b'\x01' } else { b'\x00' })
    }
    Integer(v) => {
      writer.write_bytes(string_to_bytes("long"))
      writer.write_i32_be(v)
    }
    LargeInteger(v) => {
      writer.write_bytes(string_to_bytes("comp"))
      writer.write_i32_be((v.reinterpret_as_uint64() >> 32).to_int())
      writer.write_i32_be(v.to_int())
    }
    Double(v) => {
      writer.write_bytes(string_to_bytes("doub"))
      writer.write_u64_be(v.reinterpret_as_uint64())
    }
    String(s) => {
      writer.write_bytes(string_to_bytes("TEXT"))
      write_unicode_string(writer, s)
    }
    Enumerated(type_id, enum_val) => {
      writer.write_bytes(string_to_bytes("enum"))
      write_id(writer, type_id)
      write_id(writer, enum_val)
    }
    UnitFloat(unit, v) => {
      writer.write_bytes(string_to_bytes("UntF"))
      // Write unit as 4 bytes
      let u = unit.reinterpret_as_uint()
      writer.write_u8(((u >> 24) & 0xFFU).to_byte())
      writer.write_u8(((u >> 16) & 0xFFU).to_byte())
      writer.write_u8(((u >> 8) & 0xFFU).to_byte())
      writer.write_u8((u & 0xFFU).to_byte())
      writer.write_u64_be(v.reinterpret_as_uint64())
    }
    Descriptor(desc) => {
      writer.write_bytes(string_to_bytes("Objc"))
      desc.build(writer)
    }
    GlobalObject(desc) => {
      writer.write_bytes(string_to_bytes("GlbO"))
      desc.build(writer)
    }
    List(values) => {
      writer.write_bytes(string_to_bytes("VlLs"))
      writer.write_u32_be(values.length().reinterpret_as_uint())
      for i = 0; i < values.length(); i = i + 1 {
        build_value(values[i], writer)
      }
    }
    Reference(refs) => {
      writer.write_bytes(string_to_bytes("obj "))
      writer.write_u32_be(refs.length().reinterpret_as_uint())
      for i = 0; i < refs.length(); i = i + 1 {
        build_reference_item(refs[i], writer)
      }
    }
    Class(name, class_id) => {
      writer.write_bytes(string_to_bytes("type"))
      write_unicode_string(writer, name)
      write_id(writer, class_id)
    }
    Alias(data) => {
      writer.write_bytes(string_to_bytes("alis"))
      writer.write_u32_be(data.length().reinterpret_as_uint())
      writer.write_bytes(data)
    }
    RawData(data) => {
      writer.write_bytes(string_to_bytes("tdta"))
      writer.write_u32_be(data.length().reinterpret_as_uint())
      writer.write_bytes(data)
    }
    ObjectArray(desc) => {
      writer.write_bytes(string_to_bytes("ObAr"))
      desc.build(writer)
    }
  }
}

///|
/// Build a reference item to a binary writer.
fn build_reference_item(item : ReferenceItem, writer : @binary.Writer) -> Unit {
  match item {
    Property(name, class_id, key_id) => {
      writer.write_bytes(string_to_bytes("prop"))
      write_unicode_string(writer, name)
      write_id(writer, class_id)
      write_id(writer, key_id)
    }
    Class(name, class_id) => {
      writer.write_bytes(string_to_bytes("Clss"))
      write_unicode_string(writer, name)
      write_id(writer, class_id)
    }
    EnumeratedRef(name, class_id, type_id, enum_val) => {
      writer.write_bytes(string_to_bytes("Enmr"))
      write_unicode_string(writer, name)
      write_id(writer, class_id)
      write_id(writer, type_id)
      write_id(writer, enum_val)
    }
    Offset(name, class_id, offset) => {
      writer.write_bytes(string_to_bytes("rele"))
      write_unicode_string(writer, name)
      write_id(writer, class_id)
      writer.write_u32_be(offset.reinterpret_as_uint())
    }
    Identifier(name, class_id, identifier) => {
      writer.write_bytes(string_to_bytes("Idnt"))
      write_unicode_string(writer, name)
      write_id(writer, class_id)
      writer.write_u32_be(identifier.reinterpret_as_uint())
    }
    Index(name, class_id, index) => {
      writer.write_bytes(string_to_bytes("indx"))
      write_unicode_string(writer, name)
      write_id(writer, class_id)
      writer.write_u32_be(index.reinterpret_as_uint())
    }
    Name(name, class_id, name_value) => {
      writer.write_bytes(string_to_bytes("name"))
      write_unicode_string(writer, name)
      write_id(writer, class_id)
      write_unicode_string(writer, name_value)
    }
  }
}

///|
/// Parse a Descriptor from raw bytes.
pub fn Descriptor::from_bytes(data : Bytes) -> Descriptor raise @types.PsdError {
  let reader = @binary.Reader::new(data)
  Descriptor::parse(reader)
}

///|
/// Build a Descriptor to raw bytes.
pub fn Descriptor::to_bytes(self : Descriptor) -> Bytes {
  let writer = @binary.Writer::new()
  self.build(writer)
  writer.to_bytes()
}
