import type { ReactNode } from "react";

interface TreeNodeProps {
  label: string;
  icon?: ReactNode;
  depth: number;
  isExpanded?: boolean;
  isSelected?: boolean;
  isVisible?: boolean;
  hasChildren?: boolean;
  badges?: { text: string; variant?: string }[];
  onToggle?: () => void;
  onSelect?: () => void;
  onToggleVisibility?: () => void;
  children?: ReactNode;
}

export function TreeNode({
  label,
  icon,
  depth,
  isExpanded,
  isSelected,
  isVisible,
  hasChildren,
  badges,
  onToggle,
  onSelect,
  onToggleVisibility,
  children,
}: TreeNodeProps) {
  return (
    <div className="tree-node">
      <div
        className={`tree-node-row ${isSelected ? "selected" : ""} ${isVisible === false ? "tree-node-hidden" : ""}`}
        style={{ paddingLeft: `${depth * 16 + 8}px` }}
        onClick={onSelect}
      >
        {hasChildren ? (
          <button
            className="tree-chevron"
            onClick={(e) => {
              e.stopPropagation();
              onToggle?.();
            }}
          >
            {isExpanded ? "\u25BE" : "\u25B8"}
          </button>
        ) : (
          <span className="tree-spacer" />
        )}
        {icon && <span className="tree-icon">{icon}</span>}
        <span className="tree-label">{label}</span>
        {onToggleVisibility !== undefined && (
          <button
            className="tree-visibility-btn"
            onClick={(e) => {
              e.stopPropagation();
              onToggleVisibility();
            }}
            title={isVisible === false ? "Show layer" : "Hide layer"}
          >
            {isVisible === false ? <EyeClosedIcon /> : <EyeOpenIcon />}
          </button>
        )}
        {badges?.map((b, i) => (
          <span key={i} className={`badge ${b.variant ? `badge-${b.variant}` : ""}`}>
            {b.text}
          </span>
        ))}
      </div>
      {isExpanded && children}
    </div>
  );
}

function EyeOpenIcon() {
  return (
    <svg width="14" height="14" viewBox="0 0 14 14" fill="currentColor" opacity="0.6">
      <path d="M7 3C4 3 1.5 7 1.5 7s2.5 4 5.5 4 5.5-4 5.5-4S10 3 7 3zm0 6.5A2.5 2.5 0 117 4.5a2.5 2.5 0 010 5z" />
      <circle cx="7" cy="7" r="1.2" />
    </svg>
  );
}

function EyeClosedIcon() {
  return (
    <svg width="14" height="14" viewBox="0 0 14 14" fill="currentColor" opacity="0.4">
      <path d="M7 3C4 3 1.5 7 1.5 7s2.5 4 5.5 4 5.5-4 5.5-4S10 3 7 3zm0 6.5A2.5 2.5 0 117 4.5a2.5 2.5 0 010 5z" />
      <line x1="2" y1="2" x2="12" y2="12" stroke="currentColor" strokeWidth="1.5" />
    </svg>
  );
}
