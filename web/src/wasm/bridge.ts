import type { PsdIR } from "./types";

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
