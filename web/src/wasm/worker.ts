import { initWasm, bytesToLatin1, latin1ToBytes } from "./loader";

interface WorkerMessage {
  id: number;
  type: "parse" | "rebuild" | "get-composite-rgba" | "get-layer-rgba";
  payload: ArrayBuffer | number | { handle: number; layerIndex: number };
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
      const latin1 = wasm.get_composite_rgba(handle);
      if (latin1.length === 0) {
        const error = wasm.get_last_error();
        self.postMessage({
          id,
          type: "error",
          payload: `Get composite RGBA failed: ${error}`,
        });
        return;
      }
      const rgbaBytes = latin1ToBytes(latin1);
      self.postMessage(
        { id, type: "composite-rgba-result", payload: rgbaBytes.buffer },
        { transfer: [rgbaBytes.buffer] },
      );
    }

    if (type === "get-layer-rgba") {
      const { handle, layerIndex } = payload as { handle: number; layerIndex: number };
      const latin1 = wasm.get_layer_rgba(handle, layerIndex);
      if (latin1.length === 0) {
        // Empty layer or error - return empty buffer
        self.postMessage({ id, type: "layer-rgba-result", payload: new ArrayBuffer(0) });
        return;
      }
      const rgbaBytes = latin1ToBytes(latin1);
      self.postMessage(
        { id, type: "layer-rgba-result", payload: rgbaBytes.buffer },
        { transfer: [rgbaBytes.buffer] },
      );
    }
  } catch (err) {
    self.postMessage({ id, type: "error", payload: String(err) });
  }
};
