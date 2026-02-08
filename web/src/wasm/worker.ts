import { initWasm, bytesToLatin1, latin1ToBytes, type PsdWasmExports } from "./loader";

interface WorkerMessage {
  id: number;
  type: "parse" | "rebuild" | "get-composite-rgba" | "get-layer-rgba";
  payload: ArrayBuffer | number | { handle: number; layerIndex: number };
}

interface ChannelMeta {
  id: number;
  compression: string;
  dataSize: number;
}

interface LayerChannelInfo {
  width: number;
  height: number;
  depth: number;
  version: "psd" | "psb";
  channels: ChannelMeta[];
}

/** Read data from the WASM cache in chunks, return as Uint8Array. */
function readCachedChunked(
  wasm: PsdWasmExports,
  totalSize: number,
): Uint8Array {
  const CHUNK = 65536; // 64KB per chunk
  const result = new Uint8Array(totalSize);
  for (let offset = 0; offset < totalSize; offset += CHUNK) {
    const chunkSize = Math.min(CHUNK, totalSize - offset);
    const latin1 = wasm.read_rgba_chunk(offset, chunkSize);
    for (let i = 0; i < latin1.length; i++) {
      result[offset + i] = latin1.charCodeAt(i);
    }
  }
  wasm.free_rgba_cache();
  return result;
}

/** Decompress zlib data using the browser's native DecompressionStream. */
async function zlibDecompress(data: Uint8Array): Promise<Uint8Array> {
  const ds = new DecompressionStream("deflate");
  const blob = new Blob([data as BlobPart]);
  const stream = blob.stream().pipeThrough(ds);
  return new Uint8Array(await new Response(stream).arrayBuffer());
}

/** PackBits (RLE) decoder. */
function packbitsDecode(data: Uint8Array, expectedLength: number): Uint8Array {
  const result = new Uint8Array(expectedLength);
  let srcIdx = 0;
  let dstIdx = 0;
  while (dstIdx < expectedLength && srcIdx < data.length) {
    let n = data[srcIdx++];
    if (n > 127) n = n - 256; // interpret as signed byte
    if (n >= 0) {
      // Copy next n+1 bytes literally
      const count = n + 1;
      for (let i = 0; i < count && dstIdx < expectedLength; i++) {
        result[dstIdx++] = data[srcIdx++];
      }
    } else if (n > -128) {
      // Repeat next byte (1-n) times
      const count = 1 - n;
      const val = data[srcIdx++];
      for (let i = 0; i < count && dstIdx < expectedLength; i++) {
        result[dstIdx++] = val;
      }
    }
    // n === -128: no-op
  }
  return result;
}

/** Decompress RLE channel data (byte_counts header + packed scanlines). */
function decompressRle(
  data: Uint8Array,
  width: number,
  height: number,
  depth: number,
  version: "psd" | "psb",
): Uint8Array {
  const bytesPerLine = Math.ceil((width * depth) / 8);
  const countSize = version === "psd" ? 2 : 4;
  let offset = 0;

  // Read byte counts for each scanline
  const byteCounts: number[] = [];
  for (let i = 0; i < height; i++) {
    if (countSize === 2) {
      byteCounts.push((data[offset] << 8) | data[offset + 1]);
      offset += 2;
    } else {
      byteCounts.push(
        ((data[offset] << 24) | (data[offset + 1] << 16) |
          (data[offset + 2] << 8) | data[offset + 3]) >>> 0,
      );
      offset += 4;
    }
  }

  const result = new Uint8Array(height * bytesPerLine);
  let dstOffset = 0;
  for (let line = 0; line < height; line++) {
    const lineData = data.subarray(offset, offset + byteCounts[line]);
    const decoded = packbitsDecode(lineData, bytesPerLine);
    result.set(decoded, dstOffset);
    offset += byteCounts[line];
    dstOffset += bytesPerLine;
  }
  return result;
}

/** Remove sub prediction filter (inverse delta encoding per row). */
function removePredictionFilter(
  data: Uint8Array,
  width: number,
  height: number,
  depth: number,
): Uint8Array {
  const stride = depth < 8 ? 1 : depth / 8;
  const bytesPerRow = Math.ceil((width * depth) / 8);
  const result = new Uint8Array(data.length);
  for (let row = 0; row < height; row++) {
    const off = row * bytesPerRow;
    // First 'stride' bytes unchanged
    for (let i = 0; i < stride; i++) {
      result[off + i] = data[off + i];
    }
    // Remaining: accumulate deltas
    for (let i = stride; i < bytesPerRow; i++) {
      result[off + i] = (data[off + i] + result[off + i - stride]) & 0xff;
    }
  }
  return result;
}

/** Read a sample from decompressed channel data, normalized to 0-255. */
function readSample(data: Uint8Array, offset: number, depth: number): number {
  switch (depth) {
    case 8:
      return data[offset];
    case 16:
      // Big-endian 16-bit → 8-bit: v/257 maps 0-65535 → 0-255
      return (((data[offset] << 8) | data[offset + 1]) / 257) | 0;
    case 32: {
      // Big-endian IEEE 754 float → 0-255
      const view = new DataView(data.buffer, data.byteOffset + offset, 4);
      const f = view.getFloat32(0, false);
      return Math.max(0, Math.min(255, Math.round(f * 255)));
    }
    default:
      return data[offset];
  }
}

/** Decompress a single channel using browser-native APIs. */
async function decompressChannel(
  wasm: PsdWasmExports,
  handle: number,
  layerIndex: number,
  chIndex: number,
  ch: ChannelMeta,
  info: LayerChannelInfo,
): Promise<Uint8Array> {
  // Get compressed data from WASM
  const size = wasm.prepare_layer_channel_data(handle, layerIndex, chIndex);
  if (size < 0) {
    throw new Error(wasm.get_last_error());
  }
  if (size === 0) {
    return new Uint8Array(0);
  }
  const compressed = readCachedChunked(wasm, size);

  // Decompress based on compression type
  switch (ch.compression) {
    case "raw":
      return compressed;
    case "rle":
      return decompressRle(
        compressed,
        info.width,
        info.height,
        info.depth,
        info.version,
      );
    case "zipNoPrediction":
      return zlibDecompress(compressed);
    case "zipPrediction": {
      const inflated = await zlibDecompress(compressed);
      return removePredictionFilter(
        inflated,
        info.width,
        info.height,
        info.depth,
      );
    }
    default:
      throw new Error(`Unknown compression: ${ch.compression}`);
  }
}

/** Build RGBA from decompressed channels using JS-native decompression. */
async function buildLayerRgbaJS(
  wasm: PsdWasmExports,
  handle: number,
  layerIndex: number,
): Promise<Uint8Array> {
  // Get channel metadata
  const infoJson = wasm.get_layer_channel_info(handle, layerIndex);
  if (!infoJson) {
    throw new Error(wasm.get_last_error());
  }
  const info: LayerChannelInfo = JSON.parse(infoJson);

  if (info.width <= 0 || info.height <= 0) {
    return new Uint8Array(0);
  }

  const pixelCount = info.width * info.height;
  const sampleBytes = info.depth < 8 ? 1 : info.depth / 8;
  const rgba = new Uint8Array(pixelCount * 4);

  let hasAlpha = false;
  for (const ch of info.channels) {
    if (ch.id === -1) hasAlpha = true;
  }

  // Decompress and assemble each channel
  for (let chIdx = 0; chIdx < info.channels.length; chIdx++) {
    const ch = info.channels[chIdx];

    // Map channel ID to RGBA offset
    let comp: number;
    if (ch.id === 0) comp = 0; // Red
    else if (ch.id === 1) comp = 1; // Green
    else if (ch.id === 2) comp = 2; // Blue
    else if (ch.id === -1) comp = 3; // Alpha
    else continue; // Skip user mask, etc.

    const chLabel = `layer[${layerIndex}] ch[${ch.id}] (${ch.compression}, ${ch.dataSize}B)`;
    let decompressed: Uint8Array;
    const t0 = performance.now();
    try {
      decompressed = await decompressChannel(
        wasm,
        handle,
        layerIndex,
        chIdx,
        ch,
        info,
      );
    } catch (err) {
      throw new Error(`${chLabel} decompression failed: ${err}`);
    }
    const elapsed = (performance.now() - t0).toFixed(0);

    const expectedSize = pixelCount * sampleBytes;
    if (decompressed.length !== expectedSize && decompressed.length > 0) {
      self.postMessage({
        id: 0,
        type: "progress",
        payload: `[worker] ${chLabel}: size mismatch ${decompressed.length} vs expected ${expectedSize}`,
      });
    }
    self.postMessage({
      id: 0,
      type: "progress",
      payload: `[worker] ${chLabel}: ${decompressed.length} bytes, ${elapsed}ms`,
    });

    // Fill RGBA component from decompressed channel data
    for (let pi = 0; pi < pixelCount; pi++) {
      rgba[pi * 4 + comp] = readSample(decompressed, pi * sampleBytes, info.depth);
    }
  }

  // Fill alpha to 255 if no alpha channel
  if (!hasAlpha) {
    for (let pi = 0; pi < pixelCount; pi++) {
      rgba[pi * 4 + 3] = 255;
    }
  }

  return rgba;
}

self.onmessage = async (e: MessageEvent<WorkerMessage>) => {
  const { type, payload, id } = e.data;

  try {
    const wasm = await initWasm();

    if (type === "parse") {
      const bytes = new Uint8Array(payload as ArrayBuffer);
      const latin1 = bytesToLatin1(bytes);
      const handle = wasm.parse_psd(latin1);
      if (handle < 0) {
        const error = wasm.get_last_error();
        self.postMessage({
          id,
          type: "error",
          payload: `Parse failed: ${error}`,
        });
        return;
      }
      const jsonStr = wasm.get_document_ir(handle);
      const ir = JSON.parse(jsonStr);
      self.postMessage({ id, type: "parse-result", payload: { ir, handle } });
    }

    if (type === "rebuild") {
      const handle = payload as number;
      const latin1 = wasm.rebuild_psd(handle);
      if (latin1.length === 0) {
        const error = wasm.get_last_error();
        self.postMessage({
          id,
          type: "error",
          payload: `Rebuild failed: ${error}`,
        });
        return;
      }
      const psdBytes = latin1ToBytes(latin1);
      self.postMessage(
        { id, type: "rebuild-result", payload: psdBytes.buffer },
        { transfer: [psdBytes.buffer] },
      );
    }
    if (type === "get-composite-rgba") {
      const handle = payload as number;
      self.postMessage({ id: 0, type: "progress", payload: `[worker] prepare_composite_rgba starting...` });
      const t0 = performance.now();
      const size = wasm.prepare_composite_rgba(handle);
      const elapsed1 = (performance.now() - t0).toFixed(0);
      self.postMessage({ id: 0, type: "progress", payload: `[worker] prepare_composite_rgba: ${size} bytes, ${elapsed1}ms` });
      if (size < 0) {
        const error = wasm.get_last_error();
        self.postMessage({
          id,
          type: "error",
          payload: `Get composite RGBA failed: ${error}`,
        });
        return;
      }
      const rgbaBytes = readCachedChunked(wasm, size);
      const elapsed2 = (performance.now() - t0).toFixed(0);

      // Check alpha channel: if all zeros, force to 255 (opaque).
      // Some PSD files store the composite with a non-alpha extra channel that's all zeros.
      let allAlphaZero = true;
      const step = Math.max(1, Math.floor(rgbaBytes.length / 4 / 100)); // sample 100 pixels
      for (let i = 0; i < rgbaBytes.length / 4 && allAlphaZero; i += step) {
        if (rgbaBytes[i * 4 + 3] !== 0) allAlphaZero = false;
      }
      if (allAlphaZero && rgbaBytes.length > 0) {
        self.postMessage({ id: 0, type: "progress", payload: `[worker] composite alpha all zero, forcing opaque` });
        for (let i = 3; i < rgbaBytes.length; i += 4) {
          rgbaBytes[i] = 255;
        }
      }

      self.postMessage({ id: 0, type: "progress", payload: `[worker] composite rgba total: ${elapsed2}ms` });
      self.postMessage(
        { id, type: "composite-rgba-result", payload: rgbaBytes.buffer },
        { transfer: [rgbaBytes.buffer] },
      );
    }

    if (type === "get-layer-rgba") {
      const { handle, layerIndex } = payload as { handle: number; layerIndex: number };
      self.postMessage({ id: 0, type: "progress", payload: `[worker] layer_rgba_js(${layerIndex}) starting...` });
      const t0 = performance.now();
      const rgbaBytes = await buildLayerRgbaJS(wasm, handle, layerIndex);
      const elapsed = (performance.now() - t0).toFixed(0);
      self.postMessage({ id: 0, type: "progress", payload: `[worker] layer_rgba_js(${layerIndex}): ${rgbaBytes.length} bytes, ${elapsed}ms` });

      self.postMessage(
        { id, type: "layer-rgba-result", payload: rgbaBytes.buffer },
        { transfer: [rgbaBytes.buffer] },
      );
    }
  } catch (err) {
    self.postMessage({ id, type: "error", payload: String(err) });
  }
};
