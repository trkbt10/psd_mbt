import type { PsdIR } from "./types";
import type { LayerPixelData } from "../webgl/types";

type PendingResolve = {
  resolve: (value: unknown) => void;
  reject: (reason: unknown) => void;
};

let worker: Worker | null = null;
let messageId = 0;
const pending = new Map<number, PendingResolve>();

function getWorker(): Worker {
  if (!worker) {
    worker = new Worker(new URL("./worker.ts", import.meta.url), {
      type: "module",
    });
    worker.onmessage = (e) => {
      const { id, type, payload } = e.data;
      if (type === "progress") {
        console.log(payload);
        return;
      }
      const p = pending.get(id);
      if (!p) return;
      pending.delete(id);
      if (type === "error") p.reject(new Error(payload));
      else p.resolve(payload);
    };
  }
  return worker;
}

export function parsePsd(
  file: File,
): Promise<{ ir: PsdIR; handle: number }> {
  return new Promise((resolve, reject) => {
    const id = ++messageId;
    pending.set(id, {
      resolve: resolve as (v: unknown) => void,
      reject,
    });
    file.arrayBuffer().then((buf) => {
      getWorker().postMessage(
        { id, type: "parse", payload: buf },
        { transfer: [buf] },
      );
    });
  });
}

export function rebuildPsd(handle: number): Promise<Uint8Array> {
  return new Promise((resolve, reject) => {
    const id = ++messageId;
    pending.set(id, {
      resolve: (buf) => resolve(new Uint8Array(buf as ArrayBuffer)),
      reject,
    });
    getWorker().postMessage({ id, type: "rebuild", payload: handle });
  });
}

export function getCompositeRgba(handle: number): Promise<Uint8Array> {
  return new Promise((resolve, reject) => {
    const id = ++messageId;
    pending.set(id, {
      resolve: (buf) => resolve(new Uint8Array(buf as ArrayBuffer)),
      reject,
    });
    getWorker().postMessage({ id, type: "get-composite-rgba", payload: handle });
  });
}

export function getLayerRgba(
  handle: number,
  layerIndex: number,
  bounds: { left: number; top: number; right: number; bottom: number },
): Promise<LayerPixelData> {
  return new Promise((resolve, reject) => {
    const w = bounds.right - bounds.left;
    const h = bounds.bottom - bounds.top;
    const id = ++messageId;
    pending.set(id, {
      resolve: (buf: unknown) => {
        const rgba = new Uint8Array(buf as ArrayBuffer);
        if (rgba.byteLength === 0 || w <= 0 || h <= 0) {
          resolve({ rgba: new Uint8Array(0), width: 0, height: 0, offsetX: 0, offsetY: 0 });
          return;
        }
        resolve({ rgba, width: w, height: h, offsetX: bounds.left, offsetY: bounds.top });
      },
      reject,
    });
    getWorker().postMessage({
      id,
      type: "get-layer-rgba",
      payload: { handle, layerIndex },
    });
  });
}
