import { usePsdStore } from "../store/psd-store";
import { formatBytes } from "../utils/format";

export function Toolbar() {
  const fileName = usePsdStore((s) => s.fileName);
  const fileSize = usePsdStore((s) => s.fileSize);
  const ir = usePsdStore((s) => s.ir);
  const exportPsd = usePsdStore((s) => s.exportPsd);
  const clear = usePsdStore((s) => s.clear);

  return (
    <div className="toolbar">
      <div className="toolbar-left">
        <span className="toolbar-title">PSD Viewer</span>
        {fileName && (
          <>
            <span className="toolbar-separator" />
            <span className="toolbar-filename">{fileName}</span>
            <span className="toolbar-filesize">{formatBytes(fileSize)}</span>
          </>
        )}
      </div>
      <div className="toolbar-right">
        {ir && (
          <>
            <button className="toolbar-btn" onClick={exportPsd}>
              Export PSD
            </button>
            <button className="toolbar-btn toolbar-btn-secondary" onClick={clear}>
              Close
            </button>
          </>
        )}
      </div>
    </div>
  );
}
