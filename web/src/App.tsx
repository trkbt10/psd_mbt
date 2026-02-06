import { usePsdStore } from "./store/psd-store";
import { useUIStore } from "./store/ui-store";
import { DropZone } from "./components/DropZone";
import { Toolbar } from "./components/Toolbar";
import { TreeView } from "./components/tree/TreeView";
import { PropertiesPanel } from "./components/properties/PropertiesPanel";
import { Spinner } from "./components/common/Spinner";

export function App() {
  const ir = usePsdStore((s) => s.ir);
  const loading = usePsdStore((s) => s.loading);
  const error = usePsdStore((s) => s.error);
  const selection = useUIStore((s) => s.selection);

  return (
    <div className="app">
      <Toolbar />
      {error && <div className="error-banner">{error}</div>}
      <div className="main-layout">
        <div className="sidebar">
          {ir ? <TreeView ir={ir} /> : <DropZone />}
        </div>
        <div className="properties-area">
          {ir && selection ? (
            <PropertiesPanel ir={ir} selection={selection} />
          ) : (
            <div className="empty-state">
              {ir
                ? "Select an item in the tree to view details"
                : "Drop a PSD file to get started"}
            </div>
          )}
        </div>
      </div>
      {loading && <Spinner />}
    </div>
  );
}
