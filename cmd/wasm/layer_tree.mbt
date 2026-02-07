///|
/// Layer tree node types.
enum LayerTreeNode {
  Root(Array[LayerTreeNode])
  Layer(LayerNodeInfo)
  Group(GroupNodeInfo)
}

///|
struct LayerNodeInfo {
  name : String
  layer_index : Int
  layer_kind : String
  rect : @types.Rect
  blend_mode : @types.BlendMode
  opacity : Int
  visible : Bool
  clipping : Bool
  channels : Array[@layer_and_mask.ChannelInfo]
  properties : LayerProperties
}

///|
struct GroupNodeInfo {
  name : String
  layer_index : Int
  blend_mode : @types.BlendMode
  opacity : Int
  visible : Bool
  group_state : String
  children : Array[LayerTreeNode]
  properties : LayerProperties
}

///|
struct LayerProperties {
  unicode_name : String?
  layer_id : Int?
  fill_opacity : Int?
  additional_info : Array[AliSummary]
}

///|
struct AliSummary {
  key_str : String
  size : Int
  display_name : String
}

///|
/// Build a layer tree from flat PSD layer records.
/// PSD layers are stored bottom-to-top with section divider markers.
fn build_layer_tree(
  layers : Array[@layer_and_mask.LayerRecord],
) -> LayerTreeNode {
  let root : Array[LayerTreeNode] = []
  let stack : Array[Array[LayerTreeNode]] = [root]
  for i = 0; i < layers.length(); i = i + 1 {
    let layer = layers[i]
    let divider = find_section_divider(layer.additional_info)
    match divider {
      Some(sd) =>
        if sd.divider_type == 3 {
          // End marker: start a new group (children will follow)
          let children : Array[LayerTreeNode] = []
          stack.push(children)
        } else if sd.divider_type == 1 || sd.divider_type == 2 {
          // Open/closed folder marker: closes the current group
          let children = if stack.length() > 1 {
            let popped = stack.pop()
            match popped {
              Some(c) => c
              None => []
            }
          } else {
            []
          }
          // Reverse children since they were added bottom-to-top
          children.rev_in_place()
          let uname = find_unicode_name(layer.additional_info)
          let name = match uname {
            Some(n) => n
            None => layer.name
          }
          let bm = match sd.blend_mode {
            Some(m) => m
            None => layer.blend_mode
          }
          let group_state = if sd.divider_type == 1 { "open" } else { "closed" }
          let group = Group({
            name,
            layer_index: i,
            blend_mode: bm,
            opacity: layer.opacity,
            visible: (layer.flags & 2) == 0,
            group_state,
            children,
            properties: extract_properties(layer.additional_info),
          })
          let current = stack[stack.length() - 1]
          current.push(group)
        } else {
          // divider_type == 0: treat as regular layer
          add_layer_node(stack, layer, i)
        }
      None => add_layer_node(stack, layer, i)
    }
  }
  root.rev_in_place()
  Root(root)
}

///|
fn add_layer_node(
  stack : Array[Array[LayerTreeNode]],
  layer : @layer_and_mask.LayerRecord,
  index : Int,
) -> Unit {
  let uname = find_unicode_name(layer.additional_info)
  let name = match uname {
    Some(n) => n
    None => layer.name
  }
  let node = Layer({
    name,
    layer_index: index,
    layer_kind: classify_layer(layer.additional_info),
    rect: layer.rect,
    blend_mode: layer.blend_mode,
    opacity: layer.opacity,
    visible: (layer.flags & 2) == 0,
    clipping: layer.clipping != 0,
    channels: layer.channels,
    properties: extract_properties(layer.additional_info),
  })
  let current = stack[stack.length() - 1]
  current.push(node)
}

///|
fn find_section_divider(
  infos : Array[@layer_and_mask.AdditionalLayerInfo],
) -> @layer_and_mask.SectionDivider? {
  for i = 0; i < infos.length(); i = i + 1 {
    match infos[i].as_section_divider() {
      Some(sd) => return Some(sd)
      None => ()
    }
  }
  None
}

///|
fn find_unicode_name(
  infos : Array[@layer_and_mask.AdditionalLayerInfo],
) -> String? {
  for i = 0; i < infos.length(); i = i + 1 {
    match infos[i].as_unicode_name() {
      Some(n) => return Some(n)
      None => ()
    }
  }
  None
}

///|
fn classify_layer(infos : Array[@layer_and_mask.AdditionalLayerInfo]) -> String {
  let mut has_text = false
  let mut has_smart = false
  let mut has_vector_mask = false
  let mut has_adjustment = false
  for i = 0; i < infos.length(); i = i + 1 {
    let key = infos[i].key
    if key == b"TySh" {
      has_text = true
    }
    if key == b"SoLd" || key == b"SoLE" {
      has_smart = true
    }
    if key == b"vmsk" || key == b"vsms" {
      has_vector_mask = true
    }
    if is_adjustment_key(key) {
      has_adjustment = true
    }
  }
  if has_text {
    "text"
  } else if has_smart {
    "smartObject"
  } else if has_adjustment {
    "adjustment"
  } else if has_vector_mask {
    "shape"
  } else {
    "pixel"
  }
}

///|
fn is_adjustment_key(key : Bytes) -> Bool {
  key == b"SoCo" ||
  key == b"GdFl" ||
  key == b"PtFl" ||
  key == b"levl" ||
  key == b"curv" ||
  key == b"expA" ||
  key == b"vibA" ||
  key == b"hue2" ||
  key == b"blnc" ||
  key == b"blwh" ||
  key == b"phfl" ||
  key == b"mixr" ||
  key == b"CgEd" ||
  key == b"nvrt" ||
  key == b"post" ||
  key == b"thrs" ||
  key == b"selc" ||
  key == b"brit"
}

///|
fn extract_properties(
  infos : Array[@layer_and_mask.AdditionalLayerInfo],
) -> LayerProperties {
  let mut unicode_name : String? = None
  let mut layer_id : Int? = None
  let mut fill_opacity : Int? = None
  let ali_summaries : Array[AliSummary] = []
  for i = 0; i < infos.length(); i = i + 1 {
    let ali = infos[i]
    let key_str = bytes_to_ascii(ali.key)
    // Extract known properties
    match ali.as_unicode_name() {
      Some(n) => unicode_name = Some(n)
      None => ()
    }
    match ali.as_layer_id() {
      Some(id) => layer_id = Some(id)
      None => ()
    }
    match ali.as_fill_opacity() {
      Some(v) => fill_opacity = Some(v)
      None => ()
    }
    // Add to summary list
    ali_summaries.push({
      key_str,
      size: ali.data.length(),
      display_name: ali_display_name(key_str),
    })
  }
  { unicode_name, layer_id, fill_opacity, additional_info: ali_summaries }
}

///|
fn ali_display_name(key : String) -> String {
  match key {
    "luni" => "Unicode Name"
    "lyid" => "Layer ID"
    "lsct" => "Section Divider"
    "lsdk" => "Section Divider (Nested)"
    "clbl" => "Blend Clipping"
    "infx" => "Interior Blend"
    "knko" => "Knockout"
    "lspf" => "Protection Settings"
    "lclr" => "Sheet Color"
    "refp" => "Reference Point"
    "lnsr" => "Layer Name Source"
    "lyvr" => "Layer Version"
    "tsly" => "Transparency Shapes Layer"
    "iOpa" => "Fill Opacity"
    "TySh" => "Type Tool Info"
    "lrFX" => "Legacy Effects"
    "lfx2" => "Object Effects"
    "vmsk" => "Vector Mask"
    "vsms" => "Vector Mask (Stroke)"
    "SoLd" => "Smart Object (Placed Layer)"
    "SoLE" => "Smart Object (External)"
    "FMsk" => "Filter Mask"
    "shmd" => "Metadata Setting"
    "Txt2" => "Text Engine Data"
    "Anno" => "Annotations"
    "grdm" => "Gradient Map"
    "LMsk" => "User Mask"
    "brst" => "Blending Restrictions"
    "lmgm" => "Layer Mask as Global"
    "vmgm" => "Vector Mask as Global"
    "cinf" => "Compositor Used"
    "vstk" => "Vector Stroke Data"
    "vscg" => "Vector Stroke Content"
    "vogk" => "Vector Origination"
    "plLd" => "Placed Layer (Obsolete)"
    "SoCo" => "Solid Color Fill"
    "GdFl" => "Gradient Fill"
    "PtFl" => "Pattern Fill"
    "levl" => "Levels"
    "curv" => "Curves"
    "expA" => "Exposure"
    "vibA" => "Vibrance"
    "hue2" => "Hue/Saturation"
    "blnc" => "Color Balance"
    "blwh" => "Black & White"
    "phfl" => "Photo Filter"
    "mixr" => "Channel Mixer"
    "CgEd" => "Content Generator"
    "nvrt" => "Invert"
    "post" => "Posterize"
    "thrs" => "Threshold"
    "selc" => "Selective Color"
    "brit" => "Brightness/Contrast"
    _ => key
  }
}
