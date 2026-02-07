///|
/// Convert planar channel data to interleaved RGBA uint8 bytes.
///
/// PSD stores image data in planar format: all pixels for channel 0,
/// then all pixels for channel 1, etc. This function converts to
/// interleaved RGBA suitable for WebGL texImage2D.
///
/// Handles RGB, Grayscale, CMYK, Indexed, Lab, Bitmap, Duotone, Multichannel
/// at 1, 8, 16, and 32-bit depths.
fn planar_to_rgba(
  data : Bytes,
  width : Int,
  height : Int,
  channels : Int,
  depth : Int,
  color_mode : @types.ColorMode,
  color_table : @color_mode_data.ColorModeData,
) -> Bytes {
  let pixel_count = width * height
  let buf = @buffer.new(size_hint=pixel_count * 4)
  match color_mode {
    RGB => planar_rgb_to_rgba(buf, data, pixel_count, channels, depth)
    Grayscale | Duotone =>
      planar_gray_to_rgba(buf, data, pixel_count, channels, depth)
    CMYK => planar_cmyk_to_rgba(buf, data, pixel_count, channels, depth)
    Indexed =>
      planar_indexed_to_rgba(buf, data, pixel_count, channels, color_table)
    Lab => planar_lab_to_rgba(buf, data, pixel_count, channels, depth)
    Bitmap => planar_bitmap_to_rgba(buf, data, width, height)
    Multichannel =>
      planar_multichannel_to_rgba(buf, data, pixel_count, channels, depth)
  }
  buf.to_bytes()
}

///|
/// Read a sample value from planar data, normalized to 0-255.
fn read_sample(data : Bytes, offset : Int, depth : Int) -> Int {
  match depth {
    8 => {
      if offset >= data.length() {
        return 0
      }
      data[offset].to_int()
    }
    16 => {
      if offset + 1 >= data.length() {
        return 0
      }
      let v = (data[offset].to_int() << 8) | data[offset + 1].to_int()
      v / 257
    }
    32 => {
      if offset + 3 >= data.length() {
        return 0
      }
      let bits = (data[offset].to_int() << 24) |
        (data[offset + 1].to_int() << 16) |
        (data[offset + 2].to_int() << 8) |
        data[offset + 3].to_int()
      let f = Float::reinterpret_from_uint(bits.reinterpret_as_uint())
      let fd = f.to_double()
      let clamped = if fd < 0.0 { 0.0 } else if fd > 1.0 { 1.0 } else { fd }
      (clamped * 255.0 + 0.5).to_int()
    }
    _ => 0
  }
}

///|
/// Bytes per sample at given depth.
fn sample_bytes(depth : Int) -> Int {
  if depth < 8 {
    1
  } else {
    depth / 8
  }
}

///|
fn planar_rgb_to_rgba(
  buf : @buffer.Buffer,
  data : Bytes,
  pixel_count : Int,
  channels : Int,
  depth : Int,
) -> Unit {
  let sb = sample_bytes(depth)
  let channel_size = pixel_count * sb
  let has_alpha = channels >= 4
  for i = 0; i < pixel_count; i = i + 1 {
    let off = i * sb
    let r = read_sample(data, off, depth)
    let g = read_sample(data, channel_size + off, depth)
    let b = read_sample(data, channel_size * 2 + off, depth)
    let a = if has_alpha {
      read_sample(data, channel_size * 3 + off, depth)
    } else {
      255
    }
    buf.write_byte(r.to_byte())
    buf.write_byte(g.to_byte())
    buf.write_byte(b.to_byte())
    buf.write_byte(a.to_byte())
  }
}

///|
fn planar_gray_to_rgba(
  buf : @buffer.Buffer,
  data : Bytes,
  pixel_count : Int,
  channels : Int,
  depth : Int,
) -> Unit {
  let sb = sample_bytes(depth)
  let channel_size = pixel_count * sb
  let has_alpha = channels >= 2
  for i = 0; i < pixel_count; i = i + 1 {
    let off = i * sb
    let v = read_sample(data, off, depth)
    let a = if has_alpha {
      read_sample(data, channel_size + off, depth)
    } else {
      255
    }
    buf.write_byte(v.to_byte())
    buf.write_byte(v.to_byte())
    buf.write_byte(v.to_byte())
    buf.write_byte(a.to_byte())
  }
}

///|
fn planar_cmyk_to_rgba(
  buf : @buffer.Buffer,
  data : Bytes,
  pixel_count : Int,
  channels : Int,
  depth : Int,
) -> Unit {
  let sb = sample_bytes(depth)
  let channel_size = pixel_count * sb
  let has_alpha = channels >= 5
  for i = 0; i < pixel_count; i = i + 1 {
    let off = i * sb
    let c = read_sample(data, off, depth)
    let m = read_sample(data, channel_size + off, depth)
    let y = read_sample(data, channel_size * 2 + off, depth)
    let k = read_sample(data, channel_size * 3 + off, depth)
    // PSD stores CMYK inverted: 0=full ink, 255=no ink
    // Convert: R = 255 - min(255, C*K/255)
    // Simpler: R = C*K/255 since values are already "amount of white"
    let r = c * k / 255
    let g = m * k / 255
    let b = y * k / 255
    let a = if has_alpha {
      read_sample(data, channel_size * 4 + off, depth)
    } else {
      255
    }
    buf.write_byte(r.to_byte())
    buf.write_byte(g.to_byte())
    buf.write_byte(b.to_byte())
    buf.write_byte(a.to_byte())
  }
}

///|
fn planar_indexed_to_rgba(
  buf : @buffer.Buffer,
  data : Bytes,
  pixel_count : Int,
  channels : Int,
  color_table : @color_mode_data.ColorModeData,
) -> Unit {
  let table = match color_table.as_indexed_table() {
    Some(t) => t
    None => {
      // Fallback: gray gradient
      let t : Array[(Int, Int, Int)] = []
      for i = 0; i < 256; i = i + 1 {
        t.push((i, i, i))
      }
      t
    }
  }
  let has_alpha = channels >= 2
  for i = 0; i < pixel_count; i = i + 1 {
    let idx = if i < data.length() { data[i].to_int() } else { 0 }
    let safe_idx = if idx >= 0 && idx < 256 { idx } else { 0 }
    let entry = table[safe_idx]
    let a = if has_alpha && pixel_count + i < data.length() {
      data[pixel_count + i].to_int()
    } else {
      255
    }
    buf.write_byte(entry.0.to_byte())
    buf.write_byte(entry.1.to_byte())
    buf.write_byte(entry.2.to_byte())
    buf.write_byte(a.to_byte())
  }
}

///|
fn planar_lab_to_rgba(
  buf : @buffer.Buffer,
  data : Bytes,
  pixel_count : Int,
  channels : Int,
  depth : Int,
) -> Unit {
  let sb = sample_bytes(depth)
  let channel_size = pixel_count * sb
  let has_alpha = channels >= 4
  for i = 0; i < pixel_count; i = i + 1 {
    let off = i * sb
    let l_raw = read_sample(data, off, depth)
    let a_raw = read_sample(data, channel_size + off, depth)
    let b_raw = read_sample(data, channel_size * 2 + off, depth)
    // PSD Lab: L = 0-255 maps to 0-100, a/b = 0-255 maps to -128..127
    let l = l_raw.to_double() * 100.0 / 255.0
    let a_val = a_raw.to_double() - 128.0
    let b_val = b_raw.to_double() - 128.0
    // Lab to XYZ (D65 illuminant)
    let fy = (l + 16.0) / 116.0
    let fx = a_val / 500.0 + fy
    let fz = fy - b_val / 200.0
    let x = lab_f_inv(fx) * 0.9505
    let y = lab_f_inv(fy)
    let z = lab_f_inv(fz) * 1.0890
    // XYZ to sRGB
    let rl = 3.2406 * x - 1.5372 * y - 0.4986 * z
    let gl = -0.9689 * x + 1.8758 * y + 0.0415 * z
    let bl = 0.0557 * x - 0.2040 * y + 1.0570 * z
    let r = srgb_gamma(rl)
    let g = srgb_gamma(gl)
    let b = srgb_gamma(bl)
    let alpha = if has_alpha {
      read_sample(data, channel_size * 3 + off, depth)
    } else {
      255
    }
    buf.write_byte(r.to_byte())
    buf.write_byte(g.to_byte())
    buf.write_byte(b.to_byte())
    buf.write_byte(alpha.to_byte())
  }
}

///|
fn lab_f_inv(t : Double) -> Double {
  let delta = 6.0 / 29.0
  if t > delta {
    t * t * t
  } else {
    3.0 * delta * delta * (t - 4.0 / 29.0)
  }
}

///|
fn srgb_gamma(linear : Double) -> Int {
  let v = if linear <= 0.0031308 {
    12.92 * linear
  } else {
    1.055 * pow(linear, 1.0 / 2.4) - 0.055
  }
  let clamped = if v < 0.0 { 0.0 } else if v > 1.0 { 1.0 } else { v }
  (clamped * 255.0 + 0.5).to_int()
}

///|
/// Simple pow approximation for sRGB gamma.
fn pow(base : Double, exp : Double) -> Double {
  // Use exp(exp * ln(base)) via Taylor series approximation
  if base <= 0.0 {
    return 0.0
  }
  let ln_base = ln_approx(base)
  exp_approx(exp * ln_base)
}

///|
/// Natural log approximation using the series ln(x) = 2 * sum(((x-1)/(x+1))^(2k+1) / (2k+1))
fn ln_approx(x : Double) -> Double {
  if x <= 0.0 {
    return -1000.0 // large negative
  }
  // Reduce: x = m * 2^e where 0.5 <= m < 1.0
  let mut val = x
  let mut e = 0
  while val >= 2.0 {
    val = val / 2.0
    e = e + 1
  }
  while val < 0.5 {
    val = val * 2.0
    e = e - 1
  }
  // ln(m * 2^e) = ln(m) + e * ln(2)
  let ln2 = 0.6931471805599453
  let t = (val - 1.0) / (val + 1.0)
  let t2 = t * t
  let mut sum = t
  let mut term = t
  for _i = 1; _i <= 12; _i = _i + 1 {
    term = term * t2
    let k = _i * 2 + 1
    sum = sum + term / k.to_double()
  }
  sum * 2.0 + e.to_double() * ln2
}

///|
/// Exponential approximation using Taylor series.
fn exp_approx(x : Double) -> Double {
  // Handle large values
  if x > 88.0 {
    return 1.0e38
  }
  if x < -88.0 {
    return 0.0
  }
  // Reduce: e^x = 2^(x/ln2) = 2^k * e^r where r is small
  let ln2 = 0.6931471805599453
  let k_f = x / ln2
  let k = if k_f >= 0.0 { (k_f + 0.5).to_int() } else { (k_f - 0.5).to_int() }
  let r = x - k.to_double() * ln2
  // e^r via Taylor series
  let mut sum = 1.0
  let mut term = 1.0
  for i = 1; i <= 16; i = i + 1 {
    term = term * r / i.to_double()
    sum = sum + term
  }
  // Multiply by 2^k
  let mut result = sum
  if k >= 0 {
    for _i = 0; _i < k; _i = _i + 1 {
      result = result * 2.0
    }
  } else {
    for _i = 0; _i < -k; _i = _i + 1 {
      result = result / 2.0
    }
  }
  result
}

///|
fn planar_bitmap_to_rgba(
  buf : @buffer.Buffer,
  data : Bytes,
  width : Int,
  height : Int,
) -> Unit {
  let bpl = (width + 7) / 8
  for row = 0; row < height; row = row + 1 {
    for col = 0; col < width; col = col + 1 {
      let byte_idx = row * bpl + col / 8
      let bit_idx = 7 - col % 8
      let bit = if byte_idx < data.length() {
        (data[byte_idx].to_int() >> bit_idx) & 1
      } else {
        0
      }
      // In PSD bitmap: 1=white, 0=black
      let v = if bit == 1 { 255 } else { 0 }
      buf.write_byte(v.to_byte())
      buf.write_byte(v.to_byte())
      buf.write_byte(v.to_byte())
      buf.write_byte(b'\xFF')
    }
  }
}

///|
fn planar_multichannel_to_rgba(
  buf : @buffer.Buffer,
  data : Bytes,
  pixel_count : Int,
  channels : Int,
  depth : Int,
) -> Unit {
  // Multichannel: treat first 3 channels as CMY (no K), convert to RGB
  let sb = sample_bytes(depth)
  let channel_size = pixel_count * sb
  for i = 0; i < pixel_count; i = i + 1 {
    let off = i * sb
    let c = if channels >= 1 { read_sample(data, off, depth) } else { 0 }
    let m = if channels >= 2 {
      read_sample(data, channel_size + off, depth)
    } else {
      0
    }
    let y = if channels >= 3 {
      read_sample(data, channel_size * 2 + off, depth)
    } else {
      0
    }
    // CMY to RGB (no K): R = 255 - C, G = 255 - M, B = 255 - Y
    buf.write_byte((255 - c).to_byte())
    buf.write_byte((255 - m).to_byte())
    buf.write_byte((255 - y).to_byte())
    buf.write_byte(b'\xFF')
  }
}
