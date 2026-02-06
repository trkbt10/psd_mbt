import type { ReactNode } from "react";

interface TreeNodeProps {
  label: string;
  icon?: ReactNode;
  depth: number;
  isExpanded?: boolean;
  isSelected?: boolean;
  hasChildren?: boolean;
  badges?: { text: string; variant?: string }[];
  onToggle?: () => void;
  onSelect?: () => void;
  children?: ReactNode;
}

export function TreeNode({
  label,
  icon,
  depth,
  isExpanded,
  isSelected,
  hasChildren,
  badges,
  onToggle,
  onSelect,
  children,
}: TreeNodeProps) {
  return (
    <div className="tree-node">
      <div
        className={`tree-node-row ${isSelected ? "selected" : ""}`}
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
