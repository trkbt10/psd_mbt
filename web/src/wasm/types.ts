export interface PsdIR {
  header: HeaderIR;
  colorModeData: ColorModeDataIR;
  imageResources: ImageResourceIR[];
  layerTree: LayerTreeNode | null;
  globalMask: GlobalMaskIR | null;
  globalAdditionalInfo: AliSummaryIR[];
  imageData: ImageDataIR;
}

export interface HeaderIR {
  version: "psd" | "psb";
  width: number;
  height: number;
  channels: number;
  depth: number;
  colorMode: string;
}

export interface ColorModeDataIR {
  size: number;
}

export interface ImageResourceIR {
  id: number;
  name: string;
  size: number;
  typeName: string;
}

export type LayerTreeNode = RootNode | LayerNode | GroupNode;

export interface RootNode {
  type: "root";
  children: LayerTreeNode[];
}

export interface LayerNode {
  type: "layer";
  name: string;
  layerIndex: number;
  layerKind: string;
  rect: RectIR;
  blendMode: string;
  opacity: number;
  visible: boolean;
  clipping: boolean;
  channels: ChannelIR[];
  properties: LayerPropertiesIR;
}

export interface GroupNode {
  type: "group";
  name: string;
  layerIndex: number;
  blendMode: string;
  opacity: number;
  visible: boolean;
  groupState: "open" | "closed";
  properties: LayerPropertiesIR;
  children: LayerTreeNode[];
}

export interface RectIR {
  top: number;
  left: number;
  bottom: number;
  right: number;
}

export interface ChannelIR {
  id: number;
  dataLength: number;
}

export interface LayerPropertiesIR {
  unicodeName?: string;
  layerId?: number;
  fillOpacity?: number;
  additionalInfo?: AliSummaryIR[];
}

export interface AliSummaryIR {
  key: string;
  size: number;
  displayName?: string;
}

export interface GlobalMaskIR {
  overlayColorSpace?: number;
  opacity?: number;
  kind?: number;
  size?: number;
}

export interface ImageDataIR {
  compression: string;
  size: number;
}

export type TreeSelection =
  | { section: "header" }
  | { section: "colorModeData" }
  | { section: "imageResources"; resourceIndex?: number }
  | { section: "layers"; path?: number[] }
  | { section: "imageData" }
  | { section: "globalMask" }
  | { section: "globalAdditionalInfo" };
