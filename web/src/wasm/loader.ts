export interface PsdWasmExports {
  parse_psd: (data: string) => number;
  get_document_ir: (handle: number) => string;
  rebuild_psd: (handle: number) => string;
  free_document: (handle: number) => void;
  get_last_error: () => string;
  get_composite_rgba: (handle: number) => string;
  get_layer_rgba: (handle: number, layerIndex: number) => string;
  get_layer_count: (handle: number) => number;
  prepare_layer_rgba: (handle: number, layerIndex: number) => number;
  prepare_composite_rgba: (handle: number) => number;
  read_rgba_chunk: (offset: number, size: number) => string;
  free_rgba_cache: () => void;
  get_layer_channel_info: (handle: number, layerIndex: number) => string;
  prepare_layer_channel_data: (handle: number, layerIndex: number, chIndex: number) => number;
}

let wasmExports: PsdWasmExports | null = null;
let initPromise: Promise<PsdWasmExports> | null = null;

export async function initWasm(): Promise<PsdWasmExports> {
  if (wasmExports) return wasmExports;
  if (!initPromise) {
    initPromise = (async () => {
      const result = await WebAssembly.instantiateStreaming(
        fetch(import.meta.env.BASE_URL + "wasm/psd_fmt.wasm"),
        {},
        // @ts-expect-error wasm-gc builtins not yet in TypeScript types
        { builtins: ["js-string"], importedStringConstants: "_" },
      );
      wasmExports = result.instance.exports as unknown as PsdWasmExports;
      return wasmExports;
    })();
  }
  return initPromise;
}

/** Convert Uint8Array to latin1 string (each byte -> char code 0-255). */
export function bytesToLatin1(bytes: Uint8Array): string {
  const chunks: string[] = [];
  const CHUNK = 8192;
  for (let i = 0; i < bytes.length; i += CHUNK) {
    chunks.push(
      String.fromCharCode.apply(null, Array.from(bytes.subarray(i, i + CHUNK))),
    );
  }
  return chunks.join("");
}

/** Convert latin1 string back to Uint8Array. */
export function latin1ToBytes(str: string): Uint8Array {
  const bytes = new Uint8Array(str.length);
  for (let i = 0; i < str.length; i++) {
    bytes[i] = str.charCodeAt(i);
  }
  return bytes;
}
