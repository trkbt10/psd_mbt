///|
/// Resolve LayerInfo from either the direct layer_info field or the Lr16/Lr32/Layr
/// global ALI blocks (used by 16/32-bit PSD files). Results are cached in lr16_cache.
fn resolve_layer_info(
  handle : Int,
  psd : @psd_fmt.PsdFile,
) -> @layer_and_mask.LayerInfo? {
  match psd.layer_and_mask_info.layer_info {
    Some(li) => Some(li)
    None =>
      match lr16_cache[handle] {
        Some(li) => Some(li)
        None =>
          match extract_layer_info_from_ali(
            psd.layer_and_mask_info.additional_info,
            psd.header.version,
          ) {
            Some(li) => {
              lr16_cache[handle] = Some(li)
              Some(li)
            }
            None => None
          }
      }
  }
}

///|
/// Cached RGBA result for chunked transfer.
/// Stored as FixedArray[Byte] to avoid Bytes<->String conversion overhead.
let rgba_cache_data : Ref[FixedArray[Byte]?] = { val: None }

///|
/// Prepare a layer's RGBA data for chunked reading.
/// Computes the RGBA pixels and caches them. Returns the byte count,
/// or -1 on error (call get_last_error() for details).
pub fn prepare_layer_rgba(handle : Int, layer_index : Int) -> Int {
  last_error.val = ""
  if handle < 0 || handle >= documents.length() {
    last_error.val = "Invalid handle"
    return -1
  }
  match documents[handle] {
    Some(psd) => {
      let layer_info = match resolve_layer_info(handle, psd) {
        Some(li) => li
        None => {
          last_error.val = "No layer info"
          return -1
        }
      }
      if layer_index < 0 || layer_index >= layer_info.layers.length() {
        last_error.val = "Layer index out of range"
        return -1
      }
      let layer = layer_info.layers[layer_index]
      let rect = layer.rect
      let lw = rect.right - rect.left
      let lh = rect.bottom - rect.top
      if lw <= 0 || lh <= 0 {
        rgba_cache_data.val = Some(FixedArray::make(0, b'\x00'))
        return 0
      }
      let channel_data = layer_info.channel_data[layer_index]
      let depth = psd.header.depth
      let version = psd.header.version
      let pixel_count = lw * lh
      let sb = sample_bytes(depth)
      let result = FixedArray::make(pixel_count * 4, b'\x00')
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
      let has_alpha = layer.channels.iter().any(fn(ch) { ch.channel_id == -1 })
      if not(has_alpha) {
        for pi = 0; pi < pixel_count; pi = pi + 1 {
          result[pi * 4 + 3] = b'\xFF'
        }
      }
      let size = result.length()
      rgba_cache_data.val = Some(result)
      size
    }
    None => {
      last_error.val = "Document has been freed"
      -1
    }
  }
}

///|
/// Prepare the flattened composite RGBA data for chunked reading.
/// Returns the byte count, or -1 on error.
pub fn prepare_composite_rgba(handle : Int) -> Int {
  last_error.val = ""
  if handle < 0 || handle >= documents.length() {
    last_error.val = "Invalid handle"
    return -1
  }
  match documents[handle] {
    Some(psd) => {
      let header = psd.header
      let w = header.width
      let h = header.height
      let data = psd.image_data.data
      if data.length() == 0 {
        last_error.val = "No image data"
        return -1
      }
      // For the composite (Section 5), limit channels to the color mode's
      // native count. Extra channels in the composite are often spot colors
      // or empty transparency masks (all zeros), not true alpha.
      let color_channels : Int = match header.color_mode {
        RGB | Lab => 3
        CMYK => 4
        Grayscale | Duotone => 1
        Indexed | Bitmap => 1
        Multichannel => header.channels
      }
      let rgba = planar_to_rgba(
        data,
        w,
        h,
        color_channels,
        header.depth,
        header.color_mode,
        psd.color_mode_data,
      )
      // Convert Bytes to FixedArray[Byte] for uniform cache access
      let arr = FixedArray::makei(rgba.length(), fn(i) { rgba[i] })
      let size = arr.length()
      rgba_cache_data.val = Some(arr)
      size
    }
    None => {
      last_error.val = "Document has been freed"
      -1
    }
  }
}

///|
/// Read a chunk of RGBA data from the cache as a latin1 string.
/// Call prepare_layer_rgba or prepare_composite_rgba first.
pub fn read_rgba_chunk(offset : Int, size : Int) -> String {
  match rgba_cache_data.val {
    None => ""
    Some(data) => {
      let data_len = data.length()
      if offset >= data_len {
        return ""
      }
      let end = if offset + size > data_len { data_len } else { offset + size }
      let len = end - offset
      let buf = @buffer.new(size_hint=len)
      for i = 0; i < len; i = i + 1 {
        buf.write_char(data[offset + i].to_int().unsafe_to_char())
      }
      buf.to_string()
    }
  }
}

///|
/// Free the cached RGBA data to release memory.
pub fn free_rgba_cache() -> Unit {
  rgba_cache_data.val = None
}

///|
/// Get metadata about a layer's channels as JSON.
/// Returns: {"width":W,"height":H,"depth":D,"version":"psd"|"psb",
///   "channels":[{"id":N,"compression":"raw"|"rle"|...,"dataSize":N},...]}
/// Returns empty string on error (call get_last_error()).
pub fn get_layer_channel_info(handle : Int, layer_index : Int) -> String {
  last_error.val = ""
  if handle < 0 || handle >= documents.length() {
    last_error.val = "Invalid handle"
    return ""
  }
  match documents[handle] {
    Some(psd) => {
      let layer_info = match resolve_layer_info(handle, psd) {
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
      let w = rect.right - rect.left
      let h = rect.bottom - rect.top
      let depth = psd.header.depth
      let version = psd.header.version
      let channel_data = layer_info.channel_data[layer_index]
      let j = JsonBuf::new()
      j.object_start()
      j.key("width")
      j.int(w)
      j.comma()
      j.key("height")
      j.int(h)
      j.comma()
      j.key("depth")
      j.int(depth)
      j.comma()
      j.key("version")
      j.string(
        match version {
          Psd => "psd"
          Psb => "psb"
        },
      )
      j.comma()
      j.key("channels")
      j.array_start()
      let ch_count = if layer.channels.length() < channel_data.length() {
        layer.channels.length()
      } else {
        channel_data.length()
      }
      for i = 0; i < ch_count; i = i + 1 {
        if i > 0 {
          j.comma()
        }
        j.object_start()
        j.key("id")
        j.int(layer.channels[i].channel_id)
        j.comma()
        j.key("compression")
        j.string(compression_name(channel_data[i].compression))
        j.comma()
        j.key("dataSize")
        j.int(channel_data[i].data.length())
        j.object_end()
      }
      j.array_end()
      j.object_end()
      j.to_string()
    }
    None => {
      last_error.val = "Document has been freed"
      ""
    }
  }
}

///|
/// Cache a single channel's compressed data for chunked reading.
/// Returns byte count, or -1 on error.
/// Use read_rgba_chunk / free_rgba_cache to read the data.
pub fn prepare_layer_channel_data(
  handle : Int,
  layer_index : Int,
  ch_index : Int,
) -> Int {
  last_error.val = ""
  if handle < 0 || handle >= documents.length() {
    last_error.val = "Invalid handle"
    return -1
  }
  match documents[handle] {
    Some(psd) => {
      let layer_info = match resolve_layer_info(handle, psd) {
        Some(li) => li
        None => {
          last_error.val = "No layer info"
          return -1
        }
      }
      if layer_index < 0 || layer_index >= layer_info.layers.length() {
        last_error.val = "Layer index out of range"
        return -1
      }
      let channel_data = layer_info.channel_data[layer_index]
      if ch_index < 0 || ch_index >= channel_data.length() {
        last_error.val = "Channel index out of range"
        return -1
      }
      let data = channel_data[ch_index].data
      let arr = FixedArray::makei(data.length(), fn(i) { data[i] })
      let size = arr.length()
      rgba_cache_data.val = Some(arr)
      size
    }
    None => {
      last_error.val = "Document has been freed"
      -1
    }
  }
}

///|
/// Get the flattened composite image as RGBA pixels (latin1 string).
/// Returns width*height*4 bytes as a latin1 string, or empty string on error.
/// NOTE: For large images, prefer prepare_composite_rgba + read_rgba_chunk.
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
      let color_channels : Int = match header.color_mode {
        RGB | Lab => 3
        CMYK => 4
        Grayscale | Duotone => 1
        Indexed | Bitmap => 1
        Multichannel => header.channels
      }
      let rgba = planar_to_rgba(
        data,
        w,
        h,
        color_channels,
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
/// Get a single layer's RGBA pixel data (latin1 string).
/// NOTE: For large layers, prefer prepare_layer_rgba + read_rgba_chunk.
pub fn get_layer_rgba(handle : Int, layer_index : Int) -> String {
  last_error.val = ""
  if handle < 0 || handle >= documents.length() {
    last_error.val = "Invalid handle"
    return ""
  }
  match documents[handle] {
    Some(psd) => {
      let layer_info = match resolve_layer_info(handle, psd) {
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
      let result = FixedArray::make(pixel_count * 4, b'\x00')
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
      let has_alpha = layer.channels.iter().any(fn(ch) { ch.channel_id == -1 })
      if not(has_alpha) {
        for pi = 0; pi < pixel_count; pi = pi + 1 {
          result[pi * 4 + 3] = b'\xFF'
        }
      }
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
      match resolve_layer_info(handle, psd) {
        Some(li) => li.layers.length()
        None => 0
      }
    None => -1
  }
}
