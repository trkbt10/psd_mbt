import { create } from "zustand";
import type { PsdIR } from "../wasm/types";
import { parsePsd, rebuildPsd } from "../wasm/bridge";

interface PsdState {
  fileName: string | null;
  fileSize: number;
  ir: PsdIR | null;
  handle: number;
  loading: boolean;
  error: string | null;
  loadFile: (file: File) => Promise<void>;
  exportPsd: () => Promise<void>;
  clear: () => void;
}

export const usePsdStore = create<PsdState>((set, get) => ({
  fileName: null,
  fileSize: 0,
  ir: null,
  handle: -1,
  loading: false,
  error: null,

  loadFile: async (file) => {
    set({
      loading: true,
      error: null,
      fileName: file.name,
      fileSize: file.size,
    });
    try {
      const { ir, handle } = await parsePsd(file);
      set({ ir, handle, loading: false });
    } catch (err) {
      set({ error: String(err), loading: false });
    }
  },

  exportPsd: async () => {
    const { handle, fileName } = get();
    if (handle < 0) return;
    set({ loading: true });
    try {
      const bytes = await rebuildPsd(handle);
      const blob = new Blob([bytes as unknown as BlobPart], { type: "application/octet-stream" });
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = fileName ?? "output.psd";
      a.click();
      URL.revokeObjectURL(url);
      set({ loading: false });
    } catch (err) {
      set({ error: String(err), loading: false });
    }
  },

  clear: () =>
    set({
      fileName: null,
      fileSize: 0,
      ir: null,
      handle: -1,
      error: null,
    }),
}));
