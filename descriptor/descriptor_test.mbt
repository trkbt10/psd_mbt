///|
test "Descriptor empty round-trip" {
  let desc : Descriptor = { class_id_name: "", class_id: "null", items: [] }
  let data = desc.to_bytes()
  let parsed = Descriptor::from_bytes(data)
  inspect(parsed.class_id_name, content="")
  inspect(parsed.class_id, content="null")
  inspect(parsed.items.length(), content="0")
}

///|
test "Descriptor Boolean value" {
  let desc : Descriptor = {
    class_id_name: "",
    class_id: "null",
    items: [{ key: "enab", value: Boolean(true) }],
  }
  let data = desc.to_bytes()
  let parsed = Descriptor::from_bytes(data)
  inspect(parsed.items.length(), content="1")
  inspect(parsed.items[0].key, content="enab")
  match parsed.items[0].value {
    Boolean(v) => inspect(v, content="true")
    _ => panic()
  }
}

///|
test "Descriptor Integer value" {
  let desc : Descriptor = {
    class_id_name: "",
    class_id: "null",
    items: [{ key: "Scl ", value: Integer(100) }],
  }
  let data = desc.to_bytes()
  let parsed = Descriptor::from_bytes(data)
  match parsed.items[0].value {
    Integer(v) => inspect(v, content="100")
    _ => panic()
  }
}

///|
test "Descriptor Double value" {
  let desc : Descriptor = {
    class_id_name: "",
    class_id: "null",
    items: [{ key: "Scl ", value: Double(3.14) }],
  }
  let data = desc.to_bytes()
  let parsed = Descriptor::from_bytes(data)
  match parsed.items[0].value {
    Double(v) => inspect(v > 3.13 && v < 3.15, content="true")
    _ => panic()
  }
}

///|
test "Descriptor String value" {
  let desc : Descriptor = {
    class_id_name: "",
    class_id: "null",
    items: [{ key: "Nm  ", value: String("Hello") }],
  }
  let data = desc.to_bytes()
  let parsed = Descriptor::from_bytes(data)
  match parsed.items[0].value {
    String(s) => inspect(s, content="Hello")
    _ => panic()
  }
}

///|
test "Descriptor LargeInteger value" {
  let desc : Descriptor = {
    class_id_name: "",
    class_id: "null",
    items: [{ key: "Scl ", value: LargeInteger(1234567890123L) }],
  }
  let data = desc.to_bytes()
  let parsed = Descriptor::from_bytes(data)
  match parsed.items[0].value {
    LargeInteger(v) => inspect(v, content="1234567890123")
    _ => panic()
  }
}

///|
test "Descriptor Enumerated value" {
  let desc : Descriptor = {
    class_id_name: "",
    class_id: "null",
    items: [{ key: "Md  ", value: Enumerated("BlnM", "Nrml") }],
  }
  let data = desc.to_bytes()
  let parsed = Descriptor::from_bytes(data)
  match parsed.items[0].value {
    Enumerated(t, v) => {
      inspect(t, content="BlnM")
      inspect(v, content="Nrml")
    }
    _ => panic()
  }
}

///|
test "Descriptor UnitFloat value" {
  // Unit '#Pxl' = 0x2350786C
  let unit = 0x2350786C
  let desc : Descriptor = {
    class_id_name: "",
    class_id: "null",
    items: [{ key: "Sz  ", value: UnitFloat(unit, 72.0) }],
  }
  let data = desc.to_bytes()
  let parsed = Descriptor::from_bytes(data)
  match parsed.items[0].value {
    UnitFloat(u, v) => {
      inspect(u, content="592476268")
      inspect(v > 71.9 && v < 72.1, content="true")
    }
    _ => panic()
  }
}

///|
test "Descriptor nested Descriptor value" {
  let inner : Descriptor = {
    class_id_name: "",
    class_id: "RGBC",
    items: [
      { key: "Rd  ", value: Double(255.0) },
      { key: "Grn ", value: Double(128.0) },
      { key: "Bl  ", value: Double(0.0) },
    ],
  }
  let desc : Descriptor = {
    class_id_name: "",
    class_id: "null",
    items: [{ key: "Clr ", value: Descriptor(inner) }],
  }
  let data = desc.to_bytes()
  let parsed = Descriptor::from_bytes(data)
  match parsed.items[0].value {
    Descriptor(d) => {
      inspect(d.class_id, content="RGBC")
      inspect(d.items.length(), content="3")
      match d.items[0].value {
        Double(v) => inspect(v > 254.9 && v < 255.1, content="true")
        _ => panic()
      }
    }
    _ => panic()
  }
}

///|
test "Descriptor List value" {
  let desc : Descriptor = {
    class_id_name: "",
    class_id: "null",
    items: [{ key: "Pts ", value: List([Integer(1), Integer(2), Integer(3)]) }],
  }
  let data = desc.to_bytes()
  let parsed = Descriptor::from_bytes(data)
  match parsed.items[0].value {
    List(values) => {
      inspect(values.length(), content="3")
      match values[0] {
        Integer(v) => inspect(v, content="1")
        _ => panic()
      }
    }
    _ => panic()
  }
}

///|
test "Descriptor Alias value" {
  let alias_data = b"\x01\x02\x03\x04"
  let desc : Descriptor = {
    class_id_name: "",
    class_id: "null",
    items: [{ key: "alis", value: Alias(alias_data) }],
  }
  let data = desc.to_bytes()
  let parsed = Descriptor::from_bytes(data)
  match parsed.items[0].value {
    Alias(d) => inspect(d.length(), content="4")
    _ => panic()
  }
}

///|
test "Descriptor RawData value" {
  let raw = b"\xDE\xAD\xBE\xEF"
  let desc : Descriptor = {
    class_id_name: "",
    class_id: "null",
    items: [{ key: "Raw ", value: RawData(raw) }],
  }
  let data = desc.to_bytes()
  let parsed = Descriptor::from_bytes(data)
  match parsed.items[0].value {
    RawData(d) => inspect(d == raw, content="true")
    _ => panic()
  }
}

///|
test "Descriptor Class value" {
  let desc : Descriptor = {
    class_id_name: "",
    class_id: "null",
    items: [{ key: "Type", value: Class("Layer", "Lyr ") }],
  }
  let data = desc.to_bytes()
  let parsed = Descriptor::from_bytes(data)
  match parsed.items[0].value {
    Class(name, cid) => {
      inspect(name, content="Layer")
      inspect(cid, content="Lyr ")
    }
    _ => panic()
  }
}

///|
test "Descriptor Reference value" {
  let ref_item : ReferenceItem = Property("", "Lyr ", "Nm  ")
  let desc : Descriptor = {
    class_id_name: "",
    class_id: "null",
    items: [{ key: "null", value: Reference([ref_item]) }],
  }
  let data = desc.to_bytes()
  let parsed = Descriptor::from_bytes(data)
  match parsed.items[0].value {
    Reference(r) => {
      inspect(r.length(), content="1")
      match r[0] {
        Property(_, cid, kid) => {
          inspect(cid, content="Lyr ")
          inspect(kid, content="Nm  ")
        }
        _ => panic()
      }
    }
    _ => panic()
  }
}

///|
test "Descriptor GlobalObject value" {
  let inner : Descriptor = {
    class_id_name: "",
    class_id: "null",
    items: [{ key: "test", value: Boolean(false) }],
  }
  let desc : Descriptor = {
    class_id_name: "",
    class_id: "null",
    items: [{ key: "Glbl", value: GlobalObject(inner) }],
  }
  let data = desc.to_bytes()
  let parsed = Descriptor::from_bytes(data)
  match parsed.items[0].value {
    GlobalObject(d) => {
      inspect(d.items.length(), content="1")
      match d.items[0].value {
        Boolean(v) => inspect(v, content="false")
        _ => panic()
      }
    }
    _ => panic()
  }
}

///|
test "Descriptor multiple items round-trip" {
  let desc : Descriptor = {
    class_id_name: "MyClass",
    class_id: "MyCl",
    items: [
      { key: "enab", value: Boolean(true) },
      { key: "Scl ", value: Integer(42) },
      { key: "Nm  ", value: String("Test") },
      { key: "Opct", value: Double(0.75) },
    ],
  }
  let data = desc.to_bytes()
  let parsed = Descriptor::from_bytes(data)
  inspect(parsed.class_id_name, content="MyClass")
  inspect(parsed.class_id, content="MyCl")
  inspect(parsed.items.length(), content="4")
  match parsed.items[0].value {
    Boolean(v) => inspect(v, content="true")
    _ => panic()
  }
  match parsed.items[1].value {
    Integer(v) => inspect(v, content="42")
    _ => panic()
  }
  match parsed.items[2].value {
    String(s) => inspect(s, content="Test")
    _ => panic()
  }
  match parsed.items[3].value {
    Double(v) => inspect(v > 0.74 && v < 0.76, content="true")
    _ => panic()
  }
}
