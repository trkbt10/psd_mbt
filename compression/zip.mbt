///|
/// Compress data using zlib (RFC 1950).
/// Used for PSD compression type 2 (ZIP without prediction).
pub fn zlib_compress(data : Bytes) -> Bytes {
  let output = @io.Buffer::new()
  let writer = @zlib.Writer::new(output)
  let slice = @io.Slice::new(data.to_array())
  let _ = writer.write(slice)
  let _ = writer.close()
  output.to_bytes()
}

///|
/// Decompress zlib (RFC 1950) compressed data.
/// Used for PSD compression type 2 (ZIP without prediction).
pub fn zlib_decompress(
  data : Bytes,
  expected_length : Int,
) -> Bytes raise @types.PsdError {
  let input = @io.Buffer::new()
  let _ = input.write_bytes(data)
  let (reader, err) = @zlib.Reader::new(input)
  if err != None {
    raise @types.PsdError::UnexpectedEof
  }
  let output = @io.Buffer::new(size_hint=expected_length)
  let (_, err2) = @io.copy(output, reader)
  if err2 != None {
    raise @types.PsdError::UnexpectedEof
  }
  let _ = reader.close()
  output.to_bytes()
}

///|
/// Apply sub prediction filter to raw data before compression.
/// PSD ZIP with prediction uses a per-row delta encoding:
/// encoded[i] = (raw[i] - raw[i - stride]) & 0xFF for i >= stride
/// encoded[i] = raw[i] for i < stride
/// stride = bytes_per_sample (depth / 8)
pub fn apply_prediction_filter(
  data : Bytes,
  width : Int,
  height : Int,
  depth : Int,
) -> Bytes {
  let stride = depth / 8
  let bytes_per_row = width * stride
  let buf = @buffer.new(size_hint=data.length())
  for row = 0; row < height; row = row + 1 {
    let row_offset = row * bytes_per_row
    // First 'stride' bytes are unchanged
    for i = 0; i < stride; i = i + 1 {
      buf.write_byte(data[row_offset + i])
    }
    // Remaining bytes: delta from stride bytes prior
    for i = stride; i < bytes_per_row; i = i + 1 {
      let current = data[row_offset + i].to_int()
      let prev = data[row_offset + i - stride].to_int()
      buf.write_byte((current - prev).land(0xFF).to_byte())
    }
  }
  buf.to_bytes()
}

///|
/// Remove sub prediction filter after decompression.
/// Inverse of apply_prediction_filter.
pub fn remove_prediction_filter(
  data : Bytes,
  width : Int,
  height : Int,
  depth : Int,
) -> Bytes {
  let stride = depth / 8
  let bytes_per_row = width * stride
  let result : Array[Byte] = Array::make(data.length(), b'\x00')
  for row = 0; row < height; row = row + 1 {
    let row_offset = row * bytes_per_row
    // First 'stride' bytes are unchanged
    for i = 0; i < stride; i = i + 1 {
      result[row_offset + i] = data[row_offset + i]
    }
    // Remaining bytes: accumulate
    for i = stride; i < bytes_per_row; i = i + 1 {
      let delta = data[row_offset + i].to_int()
      let prev = result[row_offset + i - stride].to_int()
      result[row_offset + i] = (delta + prev).land(0xFF).to_byte()
    }
  }
  Bytes::from_array(result)
}
