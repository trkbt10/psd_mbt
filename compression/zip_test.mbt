///|
test "zlib compress/decompress round-trip" {
  let original = b"\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0A\x0B\x0C\x0D\x0E\x0F"
  let compressed = zlib_compress(original)
  // Zlib output should start with 0x78 (deflate method)
  inspect(compressed[0].to_int() == 0x78, content="true")
  let decompressed = zlib_decompress(compressed, original.length())
  inspect(decompressed == original, content="true")
}

///|
test "zlib compress/decompress larger data" {
  // 256 bytes of repeating pattern - should compress well
  let data = Bytes::makei(256, fn(i) { (i % 16).to_byte() })
  let compressed = zlib_compress(data)
  // Compressed should be smaller than original for repetitive data
  inspect(compressed.length() < data.length(), content="true")
  let decompressed = zlib_decompress(compressed, data.length())
  inspect(decompressed == data, content="true")
}

///|
test "zlib compress/decompress uniform data" {
  // All zeros - extremely compressible
  let data = Bytes::make(1024, b'\x00')
  let compressed = zlib_compress(data)
  inspect(compressed.length() < 32, content="true")
  let decompressed = zlib_decompress(compressed, data.length())
  inspect(decompressed == data, content="true")
}

///|
test "prediction filter 8-bit round-trip" {
  // 4x2 image, 8-bit depth, 1 byte per pixel
  // Row 0: 10, 20, 30, 40
  // Row 1: 50, 60, 70, 80
  let data = Bytes::from_array(
    [10, 20, 30, 40, 50, 60, 70, 80].map(fn(x) { x.to_byte() }),
  )
  let filtered = apply_prediction_filter(data, 4, 2, 8)
  // Row 0 filtered: 10, (20-10)=10, (30-20)=10, (40-30)=10
  // Row 1 filtered: 50, (60-50)=10, (70-60)=10, (80-70)=10
  inspect(filtered[0].to_int(), content="10")
  inspect(filtered[1].to_int(), content="10")
  inspect(filtered[4].to_int(), content="50")
  inspect(filtered[5].to_int(), content="10")
  let restored = remove_prediction_filter(filtered, 4, 2, 8)
  inspect(restored == data, content="true")
}

///|
test "prediction filter 8-bit wrapping" {
  // Test byte wrapping: 10 - 200 = -190, should wrap to 66 (& 0xFF)
  let data = Bytes::from_array([200, 10, 100, 50].map(fn(x) { x.to_byte() }))
  let filtered = apply_prediction_filter(data, 4, 1, 8)
  inspect(filtered[0].to_int(), content="200")
  // (10 - 200) & 0xFF = -190 & 0xFF = 66
  inspect(filtered[1].to_int(), content="66")
  let restored = remove_prediction_filter(filtered, 4, 1, 8)
  inspect(restored == data, content="true")
}

///|
test "prediction filter 16-bit round-trip" {
  // 2x2 image, 16-bit depth, 2 bytes per pixel (stride=2)
  // Pixel values as big-endian 16-bit: 0x0100, 0x0200, 0x0300, 0x0400
  let data = Bytes::from_array([
    b'\x01', b'\x00', b'\x02', b'\x00', b'\x03', b'\x00', b'\x04', b'\x00',
  ])
  let filtered = apply_prediction_filter(data, 2, 2, 16)
  // Row 0: first 2 bytes unchanged (0x01,0x00), then delta from 2 bytes prior
  // filtered[2] = (0x02 - 0x01) & 0xFF = 0x01
  // filtered[3] = (0x00 - 0x00) & 0xFF = 0x00
  inspect(filtered[0].to_int(), content="1")
  inspect(filtered[1].to_int(), content="0")
  inspect(filtered[2].to_int(), content="1")
  inspect(filtered[3].to_int(), content="0")
  let restored = remove_prediction_filter(filtered, 2, 2, 16)
  inspect(restored == data, content="true")
}

///|
test "ZIP no prediction compress/decompress round-trip for channel" {
  // Simulate a 4x4 8-bit channel
  let raw_data = Bytes::makei(16, fn(i) { (i * 17).to_byte() })
  // Compress with zlib
  let compressed = zlib_compress(raw_data)
  // Decompress
  let decompressed = zlib_decompress(compressed, 16)
  inspect(decompressed == raw_data, content="true")
}

///|
test "ZIP with prediction compress/decompress round-trip for channel" {
  // Simulate a 4x4 8-bit channel
  let raw_data = Bytes::makei(16, fn(i) { (i * 17).to_byte() })
  // Apply prediction filter first
  let filtered = apply_prediction_filter(raw_data, 4, 4, 8)
  // Compress
  let compressed = zlib_compress(filtered)
  // Decompress
  let decompressed = zlib_decompress(compressed, 16)
  // Remove prediction filter
  let restored = remove_prediction_filter(decompressed, 4, 4, 8)
  inspect(restored == raw_data, content="true")
}
