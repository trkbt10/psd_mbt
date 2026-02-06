///|
/// Decode PackBits compressed data.
/// PackBits is a simple RLE scheme from the Macintosh Toolbox.
/// Control byte n:
///   0..127  -> copy next (n+1) bytes literally
///   -1..-127 (129..255) -> repeat next byte (1-n) times
///   -128 (128) -> no-op
pub fn packbits_decode(
  data : Bytes,
  expected_length : Int,
) -> Bytes raise @types.PsdError {
  let buf = @buffer.new(size_hint=expected_length)
  let mut i = 0
  while i < data.length() && buf.length() < expected_length {
    let n = data[i].to_int()
    i += 1
    if n <= 127 {
      // Literal run: copy (n+1) bytes
      let count = n + 1
      for j = 0; j < count; j = j + 1 {
        if i >= data.length() {
          raise @types.UnexpectedEof
        }
        buf.write_byte(data[i])
        i += 1
      }
    } else if n == 128 {
      // No-op
      ()
    } else {
      // Repeat run: repeat next byte (257-n) times
      // n is unsigned 129..255, which means -127..-1 in signed
      // repeat count = 1 - (n as signed) = 1 - (n - 256) = 257 - n
      let count = 257 - n
      if i >= data.length() {
        raise @types.UnexpectedEof
      }
      let val = data[i]
      i += 1
      for _j = 0; _j < count; _j = _j + 1 {
        buf.write_byte(val)
      }
    }
  }
  buf.to_bytes()
}

///|
/// Encode data using PackBits compression.
/// Scans for runs of repeated bytes and literal sequences.
pub fn packbits_encode(data : Bytes) -> Bytes {
  let buf = @buffer.new(size_hint=data.length())
  let len = data.length()
  let mut i = 0
  while i < len {
    // Check for a run of repeated bytes
    let val = data[i]
    let mut run_len = 1
    while i + run_len < len && data[i + run_len] == val && run_len < 128 {
      run_len += 1
    }
    if run_len >= 3 {
      // Emit repeat run
      // Control byte = 257 - run_len (as unsigned byte)
      buf.write_byte((257 - run_len).to_byte())
      buf.write_byte(val)
      i += run_len
    } else {
      // Emit literal run: gather bytes until we hit a run of 3+ or reach 128
      let lit_start = i
      let mut lit_len = 0
      while i + lit_len < len && lit_len < 128 {
        // Check if there's a run of 3+ starting at current position
        if lit_len > 0 && i + lit_len + 2 < len {
          let c = data[i + lit_len]
          if data[i + lit_len + 1] == c && data[i + lit_len + 2] == c {
            break
          }
        }
        lit_len += 1
      }
      if lit_len == 0 {
        lit_len = 1
      }
      // Control byte = lit_len - 1
      buf.write_byte((lit_len - 1).to_byte())
      for j = 0; j < lit_len; j = j + 1 {
        buf.write_byte(data[lit_start + j])
      }
      i = lit_start + lit_len
    }
  }
  buf.to_bytes()
}
