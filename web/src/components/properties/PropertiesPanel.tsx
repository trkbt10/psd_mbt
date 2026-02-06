import type { PsdIR, TreeSelection, LayerTreeNode, LayerNode, GroupNode } from "../../wasm/types";
import { formatBytes } from "../../utils/format";
import { resourceTypeName } from "../../utils/resource-names";

interface Props {
  ir: PsdIR;
  selection: TreeSelection;
}

export function PropertiesPanel({ ir, selection }: Props) {
  return (
    <div className="properties-panel">
      {selection.section === "header" && <HeaderProperties ir={ir} />}
      {selection.section === "colorModeData" && (
        <PropertySection title="Color Mode Data">
          <PropertyRow label="Size" value={formatBytes(ir.colorModeData.size)} />
        </PropertySection>
      )}
      {selection.section === "imageResources" && (
        <ResourceProperties ir={ir} selection={selection} />
      )}
      {selection.section === "layers" && (
        <LayerProperties ir={ir} selection={selection} />
      )}
      {selection.section === "imageData" && (
        <PropertySection title="Image Data">
          <PropertyRow label="Compression" value={ir.imageData.compression} />
          <PropertyRow label="Data Size" value={formatBytes(ir.imageData.size)} />
        </PropertySection>
      )}
      {selection.section === "globalMask" && ir.globalMask && (
        <PropertySection title="Global Layer Mask">
          {ir.globalMask.overlayColorSpace !== undefined && (
            <PropertyRow label="Overlay Color Space" value={String(ir.globalMask.overlayColorSpace)} />
          )}
          {ir.globalMask.opacity !== undefined && (
            <PropertyRow label="Opacity" value={String(ir.globalMask.opacity)} />
          )}
          {ir.globalMask.kind !== undefined && (
            <PropertyRow label="Kind" value={String(ir.globalMask.kind)} />
          )}
        </PropertySection>
      )}
    </div>
  );
}

function HeaderProperties({ ir }: { ir: PsdIR }) {
  return (
    <PropertySection title="File Header">
      <PropertyRow label="Version" value={ir.header.version.toUpperCase()} />
      <PropertyRow label="Dimensions" value={`${ir.header.width} x ${ir.header.height}`} />
      <PropertyRow label="Channels" value={String(ir.header.channels)} />
      <PropertyRow label="Bit Depth" value={`${ir.header.depth}-bit`} />
      <PropertyRow label="Color Mode" value={ir.header.colorMode} />
    </PropertySection>
  );
}

function ResourceProperties({
  ir,
  selection,
}: {
  ir: PsdIR;
  selection: TreeSelection;
}) {
  if (
    selection.section !== "imageResources" ||
    !("resourceIndex" in selection) ||
    selection.resourceIndex === undefined
  ) {
    return (
      <PropertySection title="Image Resources">
        <PropertyRow label="Count" value={String(ir.imageResources.length)} />
        <PropertyRow
          label="Total Size"
          value={formatBytes(
            ir.imageResources.reduce((a, r) => a + r.size, 0),
          )}
        />
      </PropertySection>
    );
  }

  const res = ir.imageResources[selection.resourceIndex];
  if (!res) return null;

  return (
    <PropertySection title={resourceTypeName(res.id)}>
      <PropertyRow label="Resource ID" value={String(res.id)} />
      <PropertyRow label="Name" value={res.name || "(empty)"} />
      <PropertyRow label="Type" value={res.typeName} />
      <PropertyRow label="Data Size" value={formatBytes(res.size)} />
    </PropertySection>
  );
}

function LayerProperties({
  ir,
  selection,
}: {
  ir: PsdIR;
  selection: TreeSelection;
}) {
  if (
    selection.section !== "layers" ||
    !("path" in selection) ||
    !selection.path ||
    !ir.layerTree
  ) {
    return (
      <PropertySection title="Layers">
        <PropertyRow
          label="Total Layers"
          value={ir.layerTree && ir.layerTree.type === "root"
            ? String(countLayers(ir.layerTree.children))
            : "0"}
        />
      </PropertySection>
    );
  }

  const node = findNode(ir.layerTree, selection.path);
  if (!node) return null;

  if (node.type === "group") {
    return <GroupProperties node={node} />;
  }
  if (node.type === "layer") {
    return <LayerNodeProperties node={node} />;
  }
  return null;
}

function GroupProperties({ node }: { node: GroupNode }) {
  return (
    <PropertySection title={node.name}>
      <PropertyRow label="Type" value="Group" />
      <PropertyRow label="Blend Mode" value={node.blendMode} />
      <PropertyRow label="Opacity" value={`${Math.round((node.opacity / 255) * 100)}%`} />
      <PropertyRow label="Visible" value={node.visible ? "Yes" : "No"} />
      <PropertyRow label="State" value={node.groupState} />
      <PropertyRow label="Children" value={String(node.children.length)} />
      {node.properties.layerId !== undefined && (
        <PropertyRow label="Layer ID" value={String(node.properties.layerId)} />
      )}
      {node.properties.additionalInfo && node.properties.additionalInfo.length > 0 && (
        <AliList items={node.properties.additionalInfo} />
      )}
    </PropertySection>
  );
}

function LayerNodeProperties({ node }: { node: LayerNode }) {
  const w = node.rect.right - node.rect.left;
  const h = node.rect.bottom - node.rect.top;

  return (
    <PropertySection title={node.name}>
      <PropertyRow label="Type" value={node.layerKind} />
      <PropertyRow label="Dimensions" value={`${w} x ${h}`} />
      <PropertyRow label="Position" value={`(${node.rect.left}, ${node.rect.top})`} />
      <PropertyRow label="Blend Mode" value={node.blendMode} />
      <PropertyRow label="Opacity" value={`${Math.round((node.opacity / 255) * 100)}%`} />
      <PropertyRow label="Visible" value={node.visible ? "Yes" : "No"} />
      <PropertyRow label="Clipping" value={node.clipping ? "Yes" : "No"} />
      <PropertyRow label="Channels" value={String(node.channels.length)} />
      {node.properties.layerId !== undefined && (
        <PropertyRow label="Layer ID" value={String(node.properties.layerId)} />
      )}
      {node.properties.fillOpacity !== undefined && (
        <PropertyRow label="Fill Opacity" value={`${Math.round((node.properties.fillOpacity / 255) * 100)}%`} />
      )}
      {node.channels.map((ch, i) => (
        <PropertyRow
          key={i}
          label={`Channel ${ch.id}`}
          value={formatBytes(ch.dataLength)}
        />
      ))}
      {node.properties.additionalInfo && node.properties.additionalInfo.length > 0 && (
        <AliList items={node.properties.additionalInfo} />
      )}
    </PropertySection>
  );
}

function AliList({ items }: { items: { key: string; size: number; displayName?: string }[] }) {
  return (
    <div className="ali-list">
      <div className="property-row property-header">Additional Layer Info</div>
      {items.map((item, i) => (
        <PropertyRow
          key={i}
          label={item.displayName ?? item.key}
          value={`${item.key} (${formatBytes(item.size)})`}
        />
      ))}
    </div>
  );
}

function PropertySection({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <div className="property-section">
      <div className="property-section-title">{title}</div>
      {children}
    </div>
  );
}

function PropertyRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="property-row">
      <span className="property-label">{label}</span>
      <span className="property-value">{value}</span>
    </div>
  );
}

function findNode(
  tree: LayerTreeNode,
  path: number[],
): LayerTreeNode | null {
  let current: LayerTreeNode = tree;
  for (const idx of path) {
    const children =
      current.type === "root"
        ? current.children
        : current.type === "group"
          ? current.children
          : null;
    if (!children || idx >= children.length) return null;
    current = children[idx];
  }
  return current;
}

function countLayers(nodes: LayerTreeNode[]): number {
  let count = 0;
  for (const node of nodes) {
    count += 1;
    if (node.type === "group") {
      count += countLayers(node.children);
    }
  }
  return count;
}
