///|
test "packbits: max literal run (128 bytes)" {
  // 128 unique bytes - forces a full literal run
  let data = Bytes::makei(128, fn(i) { i.to_byte() })
  let encoded = packbits_encode(data)
  // Control byte 127 (=128-1) + 128 literal bytes = 129 bytes
  inspect(encoded[0].to_int(), content="127")
  inspect(encoded.length(), content="129")
  let decoded = packbits_decode(encoded, 128)
  inspect(decoded == data, content="true")
}

///|
test "packbits: 129 unique bytes spans two literal runs" {
  let data = Bytes::makei(129, fn(i) { i.to_byte() })
  let encoded = packbits_encode(data)
  let decoded = packbits_decode(encoded, 129)
  inspect(decoded == data, content="true")
}

///|
test "packbits: max repeat run (128 identical bytes)" {
  let data = Bytes::make(128, b'\xAA')
  let encoded = packbits_encode(data)
  // Should encode as: control byte (257-128=129=0x81) + value byte = 2 bytes
  inspect(encoded.length(), content="2")
  inspect(encoded[0].to_int(), content="129")
  inspect(encoded[1], content="b'\\xAA'")
  let decoded = packbits_decode(encoded, 128)
  inspect(decoded == data, content="true")
}

///|
test "packbits: 256 identical bytes splits into two repeat runs" {
  let data = Bytes::make(256, b'\x55')
  let encoded = packbits_encode(data)
  // Two repeat runs of 128 each = 4 bytes
  inspect(encoded.length(), content="4")
  let decoded = packbits_decode(encoded, 256)
  inspect(decoded == data, content="true")
}

///|
test "packbits: alternating pattern AB AB AB" {
  // Non-compressible alternating pattern
  let data = Bytes::makei(20, fn(i) {
    if i % 2 == 0 {
      b'\xAA'
    } else {
      b'\xBB'
    }
  })
  let encoded = packbits_encode(data)
  let decoded = packbits_decode(encoded, 20)
  inspect(decoded == data, content="true")
}

///|
test "packbits: all 0xFF bytes" {
  let data = Bytes::make(10, b'\xFF')
  let encoded = packbits_encode(data)
  // Should be a single repeat run: control (257-10=247) + 0xFF = 2 bytes
  inspect(encoded.length(), content="2")
  let decoded = packbits_decode(encoded, 10)
  inspect(decoded == data, content="true")
}

///|
test "packbits: literal ending with run start" {
  // literal: AA BB CC, then run: DD DD DD DD
  let data = Bytes::from_array([
    b'\xAA', b'\xBB', b'\xCC', b'\xDD', b'\xDD', b'\xDD', b'\xDD',
  ])
  let encoded = packbits_encode(data)
  let decoded = packbits_decode(encoded, 7)
  inspect(decoded == data, content="true")
}

///|
test "packbits: two bytes" {
  let data = b"\xAA\xBB"
  let encoded = packbits_encode(data)
  let decoded = packbits_decode(encoded, 2)
  inspect(decoded == data, content="true")
}

///|
test "prediction filter: 1x1 image (single pixel)" {
  let data = b"\x42"
  let filtered = apply_prediction_filter(data, 1, 1, 8)
  // First pixel is unchanged
  inspect(filtered[0], content="b'\\x42'")
  let restored = remove_prediction_filter(filtered, 1, 1, 8)
  inspect(restored == data, content="true")
}

///|
test "prediction filter: 3x3 odd-width image" {
  let data = Bytes::makei(9, fn(i) { (i * 10 + 5).to_byte() })
  let filtered = apply_prediction_filter(data, 3, 3, 8)
  let restored = remove_prediction_filter(filtered, 3, 3, 8)
  inspect(restored == data, content="true")
}

///|
test "prediction filter: 32-bit depth" {
  // 2x1 image, 32-bit = 4 bytes per pixel, 8 bytes total
  let data = Bytes::from_array([
    b'\x00', b'\x01', b'\x02', b'\x03', b'\x10', b'\x11', b'\x12', b'\x13',
  ])
  let filtered = apply_prediction_filter(data, 2, 1, 32)
  // First 4 bytes unchanged, delta from 4 bytes prior
  inspect(filtered[0].to_int(), content="0")
  inspect(filtered[4].to_int(), content="16") // 0x10 - 0x00 = 16
  inspect(filtered[5].to_int(), content="16") // 0x11 - 0x01 = 16
  let restored = remove_prediction_filter(filtered, 2, 1, 32)
  inspect(restored == data, content="true")
}

///|
test "prediction filter: all zeros" {
  let data = Bytes::make(16, b'\x00')
  let filtered = apply_prediction_filter(data, 4, 4, 8)
  // All deltas should be 0
  for i = 0; i < 16; i = i + 1 {
    inspect(filtered[i].to_int(), content="0")
  }
  let restored = remove_prediction_filter(filtered, 4, 4, 8)
  inspect(restored == data, content="true")
}

///|
test "prediction filter: descending values with wrapping" {
  // 255, 200, 100, 0 -> deltas: 255, (200-255)&0xFF=201, (100-200)&0xFF=156, (0-100)&0xFF=156
  let data = Bytes::from_array([b'\xFF', b'\xC8', b'\x64', b'\x00'])
  let filtered = apply_prediction_filter(data, 4, 1, 8)
  inspect(filtered[0].to_int(), content="255") // first unchanged
  inspect(filtered[1].to_int(), content="201") // (200-255) & 0xFF
  inspect(filtered[2].to_int(), content="156") // (100-200) & 0xFF
  inspect(filtered[3].to_int(), content="156") // (0-100) & 0xFF
  let restored = remove_prediction_filter(filtered, 4, 1, 8)
  inspect(restored == data, content="true")
}

///|
test "ZIP prediction full pipeline 5x5 image" {
  // 5x5 8-bit channel - odd width
  let data = Bytes::makei(25, fn(i) { (i * 7 + 3).to_byte() })
  let filtered = apply_prediction_filter(data, 5, 5, 8)
  let compressed = zlib_compress(filtered)
  let decompressed = zlib_decompress(compressed, 25)
  let restored = remove_prediction_filter(decompressed, 5, 5, 8)
  inspect(restored == data, content="true")
}
