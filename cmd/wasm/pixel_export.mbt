///|
/// Get the flattened composite image as RGBA pixels (latin1 string).
/// Returns width*height*4 bytes as a latin1 string, or empty string on error.
pub fn get_composite_rgba(handle : Int) -> String {
  last_error.val = ""
  if handle < 0 || handle >= documents.length() {
    last_error.val = "Invalid handle"
    return ""
  }
  match documents[handle] {
    Some(psd) => {
      let header = psd.header
      let w = header.width
      let h = header.height
      let data = psd.image_data.data
      if data.length() == 0 {
        last_error.val = "No image data"
        return ""
      }
      let rgba = planar_to_rgba(
        data,
        w,
        h,
        header.channels,
        header.depth,
        header.color_mode,
        psd.color_mode_data,
      )
      bytes_to_latin1(rgba)
    }
    None => {
      last_error.val = "Document has been freed"
      ""
    }
  }
}

///|
/// Get a single layer's RGBA pixel data.
/// Returns width*height*4 bytes as a latin1 string, or empty string on error/empty layer.
/// Caller should get bounds (x, y, w, h) from the IR layer tree.
pub fn get_layer_rgba(handle : Int, layer_index : Int) -> String {
  last_error.val = ""
  if handle < 0 || handle >= documents.length() {
    last_error.val = "Invalid handle"
    return ""
  }
  match documents[handle] {
    Some(psd) => {
      let layer_info = match psd.layer_and_mask_info.layer_info {
        Some(li) => li
        None => {
          last_error.val = "No layer info"
          return ""
        }
      }
      if layer_index < 0 || layer_index >= layer_info.layers.length() {
        last_error.val = "Layer index out of range"
        return ""
      }
      let layer = layer_info.layers[layer_index]
      let rect = layer.rect
      let lw = rect.right - rect.left
      let lh = rect.bottom - rect.top
      if lw <= 0 || lh <= 0 {
        return ""
      }
      let channel_data = layer_info.channel_data[layer_index]
      let depth = psd.header.depth
      let version = psd.header.version
      let pixel_count = lw * lh
      let sb = sample_bytes(depth)
      // Allocate RGBA buffer as mutable array (transparent black)
      let result = FixedArray::make(pixel_count * 4, b'\x00')
      // Process each channel
      for ch_idx = 0
          ch_idx < layer.channels.length() && ch_idx < channel_data.length()
          ch_idx = ch_idx + 1 {
        let ch_id = layer.channels[ch_idx].channel_id
        let rgba_offset : Int? = match ch_id {
          0 => Some(0) // Red
          1 => Some(1) // Green
          2 => Some(2) // Blue
          -1 => Some(3) // Transparency (alpha)
          _ => None // User mask, etc - skip
        }
        match rgba_offset {
          Some(comp) => {
            let decompressed = channel_data[ch_idx].decompress(
              lw, lh, version, depth,
            ) catch {
              _ => continue
            }
            for pi = 0; pi < pixel_count; pi = pi + 1 {
              let sample_val = read_sample(decompressed, pi * sb, depth)
              result[pi * 4 + comp] = sample_val.to_byte()
            }
          }
          None => continue
        }
      }
      // If no alpha channel was present, set all alpha to 255
      let has_alpha = layer.channels.iter().any(fn(ch) { ch.channel_id == -1 })
      if not(has_alpha) {
        for pi = 0; pi < pixel_count; pi = pi + 1 {
          result[pi * 4 + 3] = b'\xFF'
        }
      }
      // Convert to Bytes and use the same proven path as get_composite_rgba
      let rgba_bytes = Bytes::makei(result.length(), fn(i) { result[i] })
      bytes_to_latin1(rgba_bytes)
    }
    None => {
      last_error.val = "Document has been freed"
      ""
    }
  }
}

///|
/// Get the number of layers in the document.
/// Returns -1 on error.
pub fn get_layer_count(handle : Int) -> Int {
  if handle < 0 || handle >= documents.length() {
    return -1
  }
  match documents[handle] {
    Some(psd) =>
      match psd.layer_and_mask_info.layer_info {
        Some(li) => li.layers.length()
        None => 0
      }
    None => -1
  }
}
