import type { LayerTreeNode } from "../../wasm/types";
import { useUIStore, isExpanded } from "../../store/ui-store";
import { usePsdStore } from "../../store/psd-store";
import { TreeNode } from "./TreeNode";

interface LayersTreeProps {
  nodes: LayerTreeNode[];
  depth: number;
  pathPrefix: number[];
}

export function LayersTree({ nodes, depth, pathPrefix }: LayersTreeProps) {
  return (
    <>
      {nodes.map((node, i) => (
        <LayerNodeComponent
          key={i}
          node={node}
          depth={depth}
          path={[...pathPrefix, i]}
        />
      ))}
    </>
  );
}

function LayerNodeComponent({
  node,
  depth,
  path,
}: {
  node: LayerTreeNode;
  depth: number;
  path: number[];
}) {
  const { selection, expandedPaths, select, toggleExpand } = useUIStore();
  const { visibilityOverrides, toggleLayerVisibility, failedLayers, layersLoaded } = usePsdStore();
  const pathKey = `layer-${path.join(".")}`;

  const isNodeSelected =
    selection?.section === "layers" &&
    "path" in selection &&
    selection.path?.join(".") === path.join(".");

  if (node.type === "group") {
    const expanded = isExpanded(expandedPaths, pathKey);
    const effectiveVisible = visibilityOverrides.has(node.layerIndex)
      ? visibilityOverrides.get(node.layerIndex)!
      : node.visible;
    return (
      <TreeNode
        label={node.name}
        icon={<FolderIcon open={expanded} />}
        depth={depth}
        isExpanded={expanded}
        isSelected={isNodeSelected}
        isVisible={effectiveVisible}
        hasChildren={node.children.length > 0}
        badges={[
          ...(node.blendMode !== "passThrough"
            ? [{ text: node.blendMode }]
            : []),
          ...(node.opacity < 255
            ? [{ text: `${Math.round((node.opacity / 255) * 100)}%` }]
            : []),
          ...(layersLoaded && failedLayers.has(node.layerIndex)
            ? [{ text: "no pixels", variant: "warning" }]
            : []),
        ]}
        onSelect={() => {
          select({ section: "layers", path });
          toggleExpand(pathKey);
        }}
        onToggle={() => toggleExpand(pathKey)}
        onToggleVisibility={() => toggleLayerVisibility(node.layerIndex)}
      >
        <LayersTree nodes={node.children} depth={depth + 1} pathPrefix={path} />
      </TreeNode>
    );
  }

  if (node.type === "layer") {
    const effectiveVisible = visibilityOverrides.has(node.layerIndex)
      ? visibilityOverrides.get(node.layerIndex)!
      : node.visible;
    return (
      <TreeNode
        label={node.name}
        icon={<LayerIcon kind={node.layerKind} />}
        depth={depth}
        isSelected={isNodeSelected}
        isVisible={effectiveVisible}
        badges={[
          ...(node.blendMode !== "normal"
            ? [{ text: node.blendMode }]
            : []),
          ...(node.opacity < 255
            ? [{ text: `${Math.round((node.opacity / 255) * 100)}%` }]
            : []),
          ...(layersLoaded && failedLayers.has(node.layerIndex)
            ? [{ text: "no pixels", variant: "warning" }]
            : []),
        ]}
        onSelect={() => select({ section: "layers", path })}
        onToggleVisibility={() => toggleLayerVisibility(node.layerIndex)}
      />
    );
  }

  return null;
}

function FolderIcon({ open }: { open: boolean }) {
  return (
    <svg width="14" height="14" viewBox="0 0 14 14" fill="currentColor">
      {open ? (
        <path d="M1 3h4l1.5 1.5H13v8H1V3z" opacity="0.6" />
      ) : (
        <path d="M1 3h4l1.5 1.5H13v8H1V3z" opacity="0.4" />
      )}
    </svg>
  );
}

function LayerIcon({ kind }: { kind: string }) {
  const paths: Record<string, string> = {
    text: "M2 2h10v2H8v8H6V4H2V2z",
    shape: "M7 1l6 12H1L7 1z",
    adjustment: "M7 1a6 6 0 100 12 6 6 0 000-12zM7 3a4 4 0 010 8V3z",
    smartObject: "M3 1h8l2 2v8l-2 2H3l-2-2V3l2-2z",
    pixel: "M1 1h12v12H1V1z",
  };
  return (
    <svg width="14" height="14" viewBox="0 0 14 14" fill="currentColor" opacity="0.6">
      <path d={paths[kind] ?? paths.pixel} />
    </svg>
  );
}
