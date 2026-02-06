///|
test "PathResource BezierKnot round-trip" {
  let knot : BezierKnot = {
    control_preceding: (0.5, 0.5),
    anchor: (0.25, 0.75),
    control_leaving: (0.0, 1.0),
  }
  let path : PathResource = {
    records: [ClosedSubpathLength(1), ClosedSubpathBezierKnotLinked(knot)],
  }
  let block = ImageResourceBlock::from_path_resource(2000, path)
  inspect(block.resource_id, content="2000")
  // Each record = 26 bytes, 2 records = 52 bytes
  inspect(block.data.length(), content="52")
  match block.as_path_resource() {
    Some(parsed) => {
      inspect(parsed.records.length(), content="2")
      match parsed.records[0] {
        ClosedSubpathLength(n) => inspect(n, content="1")
        _ => panic()
      }
      match parsed.records[1] {
        ClosedSubpathBezierKnotLinked(k) => {
          // Fixed-point precision: check approximate values
          inspect(k.anchor.0 > 0.24 && k.anchor.0 < 0.26, content="true")
          inspect(k.anchor.1 > 0.74 && k.anchor.1 < 0.76, content="true")
        }
        _ => panic()
      }
    }
    None => panic()
  }
}

///|
test "PathResource multiple record types" {
  let path : PathResource = {
    records: [
      PathFill(1),
      InitialFill(0),
      OpenSubpathLength(2),
      OpenSubpathBezierKnotLinked({
        control_preceding: (0.0, 0.0),
        anchor: (0.5, 0.0),
        control_leaving: (1.0, 0.0),
      }),
      OpenSubpathBezierKnotUnlinked({
        control_preceding: (0.0, 1.0),
        anchor: (0.5, 1.0),
        control_leaving: (1.0, 1.0),
      }),
    ],
  }
  let block = ImageResourceBlock::from_path_resource(2001, path)
  match block.as_path_resource() {
    Some(parsed) => {
      inspect(parsed.records.length(), content="5")
      match parsed.records[0] {
        PathFill(r) => inspect(r, content="1")
        _ => panic()
      }
      match parsed.records[1] {
        InitialFill(f) => inspect(f, content="0")
        _ => panic()
      }
      match parsed.records[2] {
        OpenSubpathLength(n) => inspect(n, content="2")
        _ => panic()
      }
    }
    None => panic()
  }
}

///|
test "PathResource ClipboardRecord round-trip" {
  let clip : ClipboardRecord = {
    top: 0.0,
    left: 0.0,
    bottom: 1.0,
    right: 1.0,
    resolution: 72.0,
  }
  let path : PathResource = {
    records: [Clipboard(clip), ClosedSubpathLength(0)],
  }
  let block = ImageResourceBlock::from_path_resource(2000, path)
  match block.as_path_resource() {
    Some(parsed) =>
      match parsed.records[0] {
        Clipboard(c) => {
          inspect(c.top > -0.01 && c.top < 0.01, content="true")
          inspect(c.bottom > 0.99 && c.bottom < 1.01, content="true")
          inspect(c.resolution > 71.9 && c.resolution < 72.1, content="true")
        }
        _ => panic()
      }
    None => panic()
  }
}

///|
test "PathResource is_path_resource_id" {
  inspect(is_path_resource_id(2000), content="true")
  inspect(is_path_resource_id(2500), content="true")
  inspect(is_path_resource_id(2997), content="true")
  inspect(is_path_resource_id(2998), content="false")
  inspect(is_path_resource_id(2999), content="true")
  inspect(is_path_resource_id(1999), content="false")
  inspect(is_path_resource_id(3000), content="false")
}

///|
test "PathResource clipping path name (ID 2999)" {
  let path : PathResource = { records: [PathFill(0)] }
  let block = ImageResourceBlock::from_path_resource(2999, path)
  inspect(block.resource_id, content="2999")
  match block.as_path_resource() {
    Some(parsed) => inspect(parsed.records.length(), content="1")
    None => panic()
  }
}

///|
test "PathResource non-path resource returns None" {
  let block : ImageResourceBlock = {
    resource_id: 1005,
    name: "",
    data: b"\x00\x01\x02\x03",
  }
  inspect(block.as_path_resource(), content="None")
}

///|
test "PathResource closed unlinked knot" {
  let knot : BezierKnot = {
    control_preceding: (0.1, 0.2),
    anchor: (0.3, 0.4),
    control_leaving: (0.5, 0.6),
  }
  let path : PathResource = {
    records: [ClosedSubpathLength(1), ClosedSubpathBezierKnotUnlinked(knot)],
  }
  let block = ImageResourceBlock::from_path_resource(2000, path)
  match block.as_path_resource() {
    Some(parsed) =>
      match parsed.records[1] {
        ClosedSubpathBezierKnotUnlinked(_) => inspect(true, content="true")
        _ => panic()
      }
    None => panic()
  }
}
