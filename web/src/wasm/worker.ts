import { initWasm, bytesToLatin1, latin1ToBytes } from "./loader";

interface WorkerMessage {
  id: number;
  type: "parse" | "rebuild";
  payload: ArrayBuffer | number;
}

self.onmessage = async (e: MessageEvent<WorkerMessage>) => {
  const { type, payload, id } = e.data;

  try {
    const wasm = await initWasm();

    if (type === "parse") {
      const bytes = new Uint8Array(payload as ArrayBuffer);
      const latin1 = bytesToLatin1(bytes);

      // Diagnostic: check data integrity before parsing
      console.log("[wasm-worker] Input size:", bytes.length, "Latin1 length:", latin1.length);
      console.log("[wasm-worker] First 4 bytes:", bytes[0], bytes[1], bytes[2], bytes[3]);
      console.log("[wasm-worker] First 4 charCodes:", latin1.charCodeAt(0), latin1.charCodeAt(1), latin1.charCodeAt(2), latin1.charCodeAt(3));

      // Run diagnostics
      const dbg = wasm.debug_bytes(latin1, 8);
      console.log("[wasm-worker] debug_bytes(8):", dbg);
      console.log("[wasm-worker] test_bytes_len:", wasm.test_bytes_len(latin1));
      console.log("[wasm-worker] test_byte_at[0..3]:", wasm.test_byte_at(latin1, 0), wasm.test_byte_at(latin1, 1), wasm.test_byte_at(latin1, 2), wasm.test_byte_at(latin1, 3));
      console.log("[wasm-worker] test_sig_bytes:", "0x" + (wasm.test_sig_bytes(latin1) >>> 0).toString(16));
      console.log("[wasm-worker] test_sig_match:", wasm.test_sig_match(latin1));
      console.log("[wasm-worker] test_parse_header:", wasm.test_parse_header(latin1));
      console.log("[wasm-worker] test_parse_steps:", wasm.test_parse_steps(latin1));
      console.log("[wasm-worker] get_diag_pos:", wasm.get_diag_pos());
      console.log("[wasm-worker] test_layer_substeps:", wasm.test_layer_substeps(latin1));
      console.log("[wasm-worker] get_diag_pos (layer):", wasm.get_diag_pos());

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
  } catch (err) {
    self.postMessage({ id, type: "error", payload: String(err) });
  }
};
