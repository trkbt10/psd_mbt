import { create } from "zustand";
import type { TreeSelection } from "../wasm/types";

interface UIState {
  selection: TreeSelection | null;
  expandedPaths: Set<string>;
  select: (sel: TreeSelection | null) => void;
  toggleExpand: (path: string) => void;
  expandAll: () => void;
  collapseAll: () => void;
  reset: () => void;
}

export const useUIStore = create<UIState>((set) => ({
  selection: null,
  expandedPaths: new Set(["header", "layers"]),

  select: (sel) => set({ selection: sel }),

  toggleExpand: (path) =>
    set((s) => {
      const next = new Set(s.expandedPaths);
      if (next.has(path)) next.delete(path);
      else next.add(path);
      return { expandedPaths: next };
    }),

  expandAll: () => set({ expandedPaths: new Set(["__all__"]) }),

  collapseAll: () => set({ expandedPaths: new Set() }),

  reset: () =>
    set({
      selection: null,
      expandedPaths: new Set(["header", "layers"]),
    }),
}));

export function isExpanded(
  expandedPaths: Set<string>,
  path: string,
): boolean {
  return expandedPaths.has("__all__") || expandedPaths.has(path);
}
