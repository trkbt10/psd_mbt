///|
test "packbits_decode literal run" {
  // n=3: copy 4 bytes literally
  let encoded = b"\x03\xAA\xBB\xCC\xDD"
  let decoded = packbits_decode(encoded, 4)
  inspect(decoded.length(), content="4")
  inspect(decoded[0], content="b'\\xAA'")
  inspect(decoded[1], content="b'\\xBB'")
  inspect(decoded[2], content="b'\\xCC'")
  inspect(decoded[3], content="b'\\xDD'")
}

///|
test "packbits_decode repeat run" {
  // n=0xFD (-3): repeat next byte 4 times
  let encoded = b"\xFD\xEE"
  let decoded = packbits_decode(encoded, 4)
  inspect(decoded.length(), content="4")
  inspect(decoded[0], content="b'\\xEE'")
  inspect(decoded[3], content="b'\\xEE'")
}

///|
test "packbits_decode mixed" {
  // Literal 4 bytes + repeat 4 times
  let encoded = b"\x03\xAA\xBB\xCC\xDD\xFD\xEE"
  let decoded = packbits_decode(encoded, 8)
  inspect(decoded.length(), content="8")
  inspect(decoded[0], content="b'\\xAA'")
  inspect(decoded[3], content="b'\\xDD'")
  inspect(decoded[4], content="b'\\xEE'")
  inspect(decoded[7], content="b'\\xEE'")
}

///|
test "packbits_decode noop" {
  // 0x80 = 128 = noop, then literal 1 byte
  let encoded = b"\x80\x00\xAA"
  let decoded = packbits_decode(encoded, 1)
  inspect(decoded.length(), content="1")
  inspect(decoded[0], content="b'\\xAA'")
}

///|
test "packbits_decode empty" {
  let decoded = packbits_decode(b"", 0)
  inspect(decoded.length(), content="0")
}

///|
test "packbits_encode literal" {
  let data = b"\xAA\xBB\xCC\xDD"
  let encoded = packbits_encode(data)
  // Should produce: literal run of 4 bytes
  let decoded = packbits_decode(encoded, 4)
  inspect(decoded == data, content="true")
}

///|
test "packbits_encode repeat" {
  // 5 identical bytes
  let data = b"\xEE\xEE\xEE\xEE\xEE"
  let encoded = packbits_encode(data)
  // Should produce repeat run: 2 bytes
  inspect(encoded.length(), content="2")
  let decoded = packbits_decode(encoded, 5)
  inspect(decoded == data, content="true")
}

///|
test "packbits_encode mixed" {
  // 4 literal + 4 repeat
  let data = b"\xAA\xBB\xCC\xDD\xEE\xEE\xEE\xEE"
  let encoded = packbits_encode(data)
  let decoded = packbits_decode(encoded, 8)
  inspect(decoded == data, content="true")
}

///|
test "packbits round-trip single byte" {
  let data = b"\x42"
  let encoded = packbits_encode(data)
  let decoded = packbits_decode(encoded, 1)
  inspect(decoded == data, content="true")
}

///|
test "packbits round-trip zeros" {
  // 128 zero bytes - max repeat run
  let data = Bytes::makei(128, fn(_i) { b'\x00' })
  let encoded = packbits_encode(data)
  let decoded = packbits_decode(encoded, 128)
  inspect(decoded == data, content="true")
}
