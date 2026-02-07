import { usePsdStore } from "./store/psd-store";
import { useUIStore } from "./store/ui-store";
import { DropZone } from "./components/DropZone";
import { Toolbar } from "./components/Toolbar";
import { TreeView } from "./components/tree/TreeView";
import { PropertiesPanel } from "./components/properties/PropertiesPanel";
import { PsdCanvas } from "./components/canvas/PsdCanvas";
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
      <div className={ir ? "main-layout main-layout--3col" : "main-layout"}>
        <div className="sidebar">
          {ir ? <TreeView ir={ir} /> : <DropZone />}
        </div>
        {ir ? (
          <>
            <div className="canvas-area">
              <PsdCanvas />
            </div>
            <div className="properties-area">
              {selection ? (
                <PropertiesPanel ir={ir} selection={selection} />
              ) : (
                <div className="empty-state">
                  Select an item in the tree to view details
                </div>
              )}
            </div>
          </>
        ) : (
          <div className="properties-area">
            <div className="empty-state">
              Drop a PSD file to get started
            </div>
          </div>
        )}
      </div>
      {loading && <Spinner />}
    </div>
  );
}
