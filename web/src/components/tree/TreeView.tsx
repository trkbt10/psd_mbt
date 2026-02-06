import type { PsdIR } from "../../wasm/types";
import { useUIStore, isExpanded } from "../../store/ui-store";
import { TreeNode } from "./TreeNode";
import { LayersTree } from "./LayersTree";
import { formatBytes } from "../../utils/format";
import { resourceTypeName } from "../../utils/resource-names";

export function TreeView({ ir }: { ir: PsdIR }) {
  const { selection, expandedPaths, select, toggleExpand } = useUIStore();

  const isSelected = (section: string) =>
    selection?.section === section;

  return (
    <div className="tree-view">
      {/* Section 1: Header */}
      <TreeNode
        label="Header"
        icon={<SectionIcon />}
        depth={0}
        isSelected={isSelected("header")}
        isExpanded={isExpanded(expandedPaths, "header")}
        hasChildren
        badges={[
          { text: `${ir.header.width}x${ir.header.height}` },
          { text: ir.header.colorMode.toUpperCase(), variant: "accent" },
        ]}
        onSelect={() => select({ section: "header" })}
        onToggle={() => toggleExpand("header")}
      >
        <TreeNode
          label={`Version: ${ir.header.version.toUpperCase()}`}
          depth={1}
        />
        <TreeNode
          label={`Channels: ${ir.header.channels}`}
          depth={1}
        />
        <TreeNode
          label={`Depth: ${ir.header.depth}-bit`}
          depth={1}
        />
      </TreeNode>

      {/* Section 2: Color Mode Data */}
      <TreeNode
        label="Color Mode Data"
        icon={<SectionIcon />}
        depth={0}
        isSelected={isSelected("colorModeData")}
        badges={[{ text: formatBytes(ir.colorModeData.size) }]}
        onSelect={() => select({ section: "colorModeData" })}
      />

      {/* Section 3: Image Resources */}
      <TreeNode
        label="Image Resources"
        icon={<SectionIcon />}
        depth={0}
        isSelected={isSelected("imageResources") && !("resourceIndex" in (selection ?? {}))}
        isExpanded={isExpanded(expandedPaths, "resources")}
        hasChildren={ir.imageResources.length > 0}
        badges={[{ text: `${ir.imageResources.length} items` }]}
        onSelect={() => select({ section: "imageResources" })}
        onToggle={() => toggleExpand("resources")}
      >
        {ir.imageResources.map((res, i) => (
          <TreeNode
            key={i}
            label={resourceTypeName(res.id)}
            depth={1}
            isSelected={
              selection?.section === "imageResources" &&
              "resourceIndex" in selection &&
              selection.resourceIndex === i
            }
            badges={[
              { text: `#${res.id}`, variant: "muted" },
              { text: formatBytes(res.size) },
            ]}
            onSelect={() =>
              select({ section: "imageResources", resourceIndex: i })
            }
          />
        ))}
      </TreeNode>

      {/* Section 4: Layers */}
      <TreeNode
        label="Layers"
        icon={<SectionIcon />}
        depth={0}
        isSelected={isSelected("layers") && !("path" in (selection ?? {}))}
        isExpanded={isExpanded(expandedPaths, "layers")}
        hasChildren={ir.layerTree !== null}
        onSelect={() => select({ section: "layers" })}
        onToggle={() => toggleExpand("layers")}
      >
        {ir.layerTree && ir.layerTree.type === "root" && (
          <LayersTree nodes={ir.layerTree.children} depth={1} pathPrefix={[]} />
        )}
      </TreeNode>

      {/* Section 5: Image Data */}
      <TreeNode
        label="Image Data"
        icon={<SectionIcon />}
        depth={0}
        isSelected={isSelected("imageData")}
        badges={[
          { text: ir.imageData.compression },
          { text: formatBytes(ir.imageData.size) },
        ]}
        onSelect={() => select({ section: "imageData" })}
      />
    </div>
  );
}

function SectionIcon() {
  return (
    <svg width="14" height="14" viewBox="0 0 14 14" fill="currentColor">
      <rect x="1" y="1" width="12" height="12" rx="2" opacity="0.5" />
    </svg>
  );
}
