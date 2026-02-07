import { useCanvasStore } from "../../store/canvas-store";
import { usePsdStore } from "../../store/psd-store";

export function CanvasControls() {
  const zoom = useCanvasStore((s) => s.zoom);
  const setZoom = useCanvasStore((s) => s.setZoom);
  const fitToView = useCanvasStore((s) => s.fitToView);
  const ir = usePsdStore((s) => s.ir);

  const handleFit = () => {
    if (!ir) return;
    const canvas = document.querySelector(".psd-canvas") as HTMLCanvasElement;
    if (!canvas) return;
    const rect = canvas.getBoundingClientRect();
    fitToView(ir.header.width, ir.header.height, rect.width, rect.height);
  };

  const zoomPercent = Math.round(zoom * 100);

  return (
    <div className="canvas-controls">
      <button
        className="canvas-ctrl-btn"
        onClick={() => setZoom(zoom / 1.2)}
        title="Zoom out"
      >
        -
      </button>
      <span className="canvas-ctrl-label">{zoomPercent}%</span>
      <button
        className="canvas-ctrl-btn"
        onClick={() => setZoom(zoom * 1.2)}
        title="Zoom in"
      >
        +
      </button>
      <button className="canvas-ctrl-btn" onClick={handleFit} title="Fit to view">
        Fit
      </button>
    </div>
  );
}
