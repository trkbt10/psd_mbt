import { useCallback, useState, useRef } from "react";
import { usePsdStore } from "../store/psd-store";
import { useUIStore } from "../store/ui-store";

export function DropZone() {
  const loadFile = usePsdStore((s) => s.loadFile);
  const reset = useUIStore((s) => s.reset);
  const [dragging, setDragging] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);

  const handleFile = useCallback(
    (file: File) => {
      if (
        file.name.endsWith(".psd") ||
        file.name.endsWith(".psb") ||
        file.type === "image/vnd.adobe.photoshop"
      ) {
        reset();
        loadFile(file);
      }
    },
    [loadFile, reset],
  );

  const onDrop = useCallback(
    (e: React.DragEvent) => {
      e.preventDefault();
      setDragging(false);
      const file = e.dataTransfer.files[0];
      if (file) handleFile(file);
    },
    [handleFile],
  );

  const onDragOver = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    setDragging(true);
  }, []);

  const onDragLeave = useCallback(() => {
    setDragging(false);
  }, []);

  const onClick = useCallback(() => {
    inputRef.current?.click();
  }, []);

  const onFileChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      const file = e.target.files?.[0];
      if (file) handleFile(file);
    },
    [handleFile],
  );

  return (
    <div
      className={`dropzone ${dragging ? "dropzone-active" : ""}`}
      onDrop={onDrop}
      onDragOver={onDragOver}
      onDragLeave={onDragLeave}
      onClick={onClick}
    >
      <div className="dropzone-content">
        <div className="dropzone-icon">
          <svg
            width="48"
            height="48"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="1.5"
          >
            <path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4" />
            <polyline points="17 8 12 3 7 8" />
            <line x1="12" y1="3" x2="12" y2="15" />
          </svg>
        </div>
        <p>Drop a PSD file here or click to browse</p>
        <span className="dropzone-hint">.psd, .psb</span>
      </div>
      <input
        ref={inputRef}
        type="file"
        accept=".psd,.psb"
        onChange={onFileChange}
        style={{ display: "none" }}
      />
    </div>
  );
}
