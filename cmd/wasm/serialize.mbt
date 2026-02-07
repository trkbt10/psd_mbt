///|
/// Serialize a PsdFile to JSON IR string.
fn serialize_psd_to_json(psd : @psd_fmt.PsdFile) -> String {
  let j = JsonBuf::new()
  j.object_start()
  // Header
  j.key("header")
  serialize_header(j, psd.header)
  // Color mode data
  j.comma()
  j.key("colorModeData")
  j.object_start()
  j.key("size")
  j.int(psd.color_mode_data.data.length())
  j.object_end()
  // Image resources
  j.comma()
  j.key("imageResources")
  serialize_image_resources(j, psd.image_resources)
  // Layer tree
  j.comma()
  j.key("layerTree")
  serialize_layer_tree(j, psd.layer_and_mask_info)
  // Global mask
  j.comma()
  j.key("globalMask")
  serialize_global_mask(j, psd.layer_and_mask_info.global_mask)
  // Global additional info
  j.comma()
  j.key("globalAdditionalInfo")
  serialize_ali_list(j, psd.layer_and_mask_info.additional_info)
  // Image data
  j.comma()
  j.key("imageData")
  j.object_start()
  j.key("compression")
  j.string(compression_name(psd.image_data.compression))
  j.comma()
  j.key("size")
  j.int(psd.image_data.data.length())
  j.object_end()
  j.object_end()
  j.to_string()
}

///|
fn serialize_header(j : JsonBuf, h : @header.FileHeader) -> Unit {
  j.object_start()
  j.key("version")
  j.string(version_name(h.version))
  j.comma()
  j.key("width")
  j.int(h.width)
  j.comma()
  j.key("height")
  j.int(h.height)
  j.comma()
  j.key("channels")
  j.int(h.channels)
  j.comma()
  j.key("depth")
  j.int(h.depth)
  j.comma()
  j.key("colorMode")
  j.string(color_mode_name(h.color_mode))
  j.object_end()
}

///|
fn serialize_image_resources(
  j : JsonBuf,
  res : @image_resources.ImageResources,
) -> Unit {
  j.array_start()
  for i = 0; i < res.blocks.length(); i = i + 1 {
    if i > 0 {
      j.comma()
    }
    let block = res.blocks[i]
    j.object_start()
    j.key("id")
    j.int(block.resource_id)
    j.comma()
    j.key("name")
    j.string(block.name)
    j.comma()
    j.key("size")
    j.int(block.data.length())
    j.comma()
    j.key("typeName")
    j.string(resource_type_name(block.resource_id))
    j.object_end()
  }
  j.array_end()
}

///|
fn serialize_layer_tree(
  j : JsonBuf,
  lm : @layer_and_mask.LayerAndMaskInfo,
) -> Unit {
  match lm.layer_info {
    Some(li) => {
      let tree = build_layer_tree(li.layers)
      serialize_tree_node(j, tree)
    }
    None => j.null()
  }
}

///|
fn serialize_tree_node(j : JsonBuf, node : LayerTreeNode) -> Unit {
  match node {
    Root(children) => {
      j.object_start()
      j.key("type")
      j.string("root")
      j.comma()
      j.key("children")
      j.array_start()
      for i = 0; i < children.length(); i = i + 1 {
        if i > 0 {
          j.comma()
        }
        serialize_tree_node(j, children[i])
      }
      j.array_end()
      j.object_end()
    }
    Layer(info) => {
      j.object_start()
      j.key("type")
      j.string("layer")
      j.comma()
      j.key("name")
      j.string(json_escape(info.name))
      j.comma()
      j.key("layerIndex")
      j.int(info.layer_index)
      j.comma()
      j.key("layerKind")
      j.string(info.layer_kind)
      j.comma()
      j.key("rect")
      serialize_rect(j, info.rect)
      j.comma()
      j.key("blendMode")
      j.string(blend_mode_name(info.blend_mode))
      j.comma()
      j.key("opacity")
      j.int(info.opacity)
      j.comma()
      j.key("visible")
      j.bool(info.visible)
      j.comma()
      j.key("clipping")
      j.bool(info.clipping)
      j.comma()
      j.key("channels")
      serialize_channel_list(j, info.channels)
      j.comma()
      j.key("properties")
      serialize_properties(j, info.properties)
      j.object_end()
    }
    Group(info) => {
      j.object_start()
      j.key("type")
      j.string("group")
      j.comma()
      j.key("name")
      j.string(json_escape(info.name))
      j.comma()
      j.key("layerIndex")
      j.int(info.layer_index)
      j.comma()
      j.key("blendMode")
      j.string(blend_mode_name(info.blend_mode))
      j.comma()
      j.key("opacity")
      j.int(info.opacity)
      j.comma()
      j.key("visible")
      j.bool(info.visible)
      j.comma()
      j.key("groupState")
      j.string(info.group_state)
      j.comma()
      j.key("properties")
      serialize_properties(j, info.properties)
      j.comma()
      j.key("children")
      j.array_start()
      for i = 0; i < info.children.length(); i = i + 1 {
        if i > 0 {
          j.comma()
        }
        serialize_tree_node(j, info.children[i])
      }
      j.array_end()
      j.object_end()
    }
  }
}

///|
fn serialize_rect(j : JsonBuf, r : @types.Rect) -> Unit {
  j.object_start()
  j.key("top")
  j.int(r.top)
  j.comma()
  j.key("left")
  j.int(r.left)
  j.comma()
  j.key("bottom")
  j.int(r.bottom)
  j.comma()
  j.key("right")
  j.int(r.right)
  j.object_end()
}

///|
fn serialize_channel_list(
  j : JsonBuf,
  channels : Array[@layer_and_mask.ChannelInfo],
) -> Unit {
  j.array_start()
  for i = 0; i < channels.length(); i = i + 1 {
    if i > 0 {
      j.comma()
    }
    j.object_start()
    j.key("id")
    j.int(channels[i].channel_id)
    j.comma()
    j.key("dataLength")
    j.int(channels[i].data_length)
    j.object_end()
  }
  j.array_end()
}

///|
fn serialize_properties(j : JsonBuf, props : LayerProperties) -> Unit {
  j.object_start()
  let mut first = true
  // Unicode name
  match props.unicode_name {
    Some(name) => {
      if not(first) {
        j.comma()
      }
      first = false
      j.key("unicodeName")
      j.string(json_escape(name))
    }
    None => ()
  }
  // Layer ID
  match props.layer_id {
    Some(id) => {
      if not(first) {
        j.comma()
      }
      first = false
      j.key("layerId")
      j.int(id)
    }
    None => ()
  }
  // Fill opacity
  match props.fill_opacity {
    Some(v) => {
      if not(first) {
        j.comma()
      }
      first = false
      j.key("fillOpacity")
      j.int(v)
    }
    None => ()
  }
  // Additional info summary
  if props.additional_info.length() > 0 {
    if not(first) {
      j.comma()
    }
    // first = false   (no further fields after this)
    j.key("additionalInfo")
    j.array_start()
    for i = 0; i < props.additional_info.length(); i = i + 1 {
      if i > 0 {
        j.comma()
      }
      let ali = props.additional_info[i]
      j.object_start()
      j.key("key")
      j.string(ali.key_str)
      j.comma()
      j.key("size")
      j.int(ali.size)
      j.comma()
      j.key("displayName")
      j.string(ali.display_name)
      j.object_end()
    }
    j.array_end()
  }
  j.object_end()
}

///|
fn serialize_global_mask(
  j : JsonBuf,
  gm : @layer_and_mask.GlobalLayerMaskInfo?,
) -> Unit {
  match gm {
    None => j.null()
    Some(g) =>
      match g.as_fields() {
        None => {
          j.object_start()
          j.key("size")
          j.int(g.data.length())
          j.object_end()
        }
        Some(f) => {
          j.object_start()
          j.key("overlayColorSpace")
          j.int(f.overlay_color_space)
          j.comma()
          j.key("opacity")
          j.int(f.opacity)
          j.comma()
          j.key("kind")
          j.int(f.kind)
          j.object_end()
        }
      }
  }
}

///|
fn serialize_ali_list(
  j : JsonBuf,
  infos : Array[@layer_and_mask.AdditionalLayerInfo],
) -> Unit {
  j.array_start()
  for i = 0; i < infos.length(); i = i + 1 {
    if i > 0 {
      j.comma()
    }
    j.object_start()
    j.key("key")
    j.string(bytes_to_ascii(infos[i].key))
    j.comma()
    j.key("size")
    j.int(infos[i].data.length())
    j.object_end()
  }
  j.array_end()
}

///|
fn version_name(v : @types.PsdVersion) -> String {
  match v {
    Psd => "psd"
    Psb => "psb"
  }
}

///|
fn color_mode_name(cm : @types.ColorMode) -> String {
  match cm {
    Bitmap => "bitmap"
    Grayscale => "grayscale"
    Indexed => "indexed"
    RGB => "rgb"
    CMYK => "cmyk"
    Multichannel => "multichannel"
    Duotone => "duotone"
    Lab => "lab"
  }
}

///|
fn compression_name(c : @types.Compression) -> String {
  match c {
    Raw => "raw"
    Rle => "rle"
    ZipNoPrediction => "zipNoPrediction"
    ZipPrediction => "zipPrediction"
  }
}

///|
fn blend_mode_name(bm : @types.BlendMode) -> String {
  match bm {
    PassThrough => "passThrough"
    Normal => "normal"
    Dissolve => "dissolve"
    Darken => "darken"
    Multiply => "multiply"
    ColorBurn => "colorBurn"
    LinearBurn => "linearBurn"
    DarkerColor => "darkerColor"
    Lighten => "lighten"
    Screen => "screen"
    ColorDodge => "colorDodge"
    LinearDodge => "linearDodge"
    LighterColor => "lighterColor"
    Overlay => "overlay"
    SoftLight => "softLight"
    HardLight => "hardLight"
    VividLight => "vividLight"
    LinearLight => "linearLight"
    PinLight => "pinLight"
    HardMix => "hardMix"
    Difference => "difference"
    Exclusion => "exclusion"
    Subtract => "subtract"
    Divide => "divide"
    Hue => "hue"
    Saturation => "saturation"
    Color => "color"
    Luminosity => "luminosity"
    Unknown(_) => "unknown"
  }
}

///|
fn resource_type_name(id : Int) -> String {
  if id >= 2000 && id <= 2997 {
    return "pathResource"
  }
  match id {
    1000 => "channelCount"
    1001 => "macPrintManagerInfo"
    1003 => "macPageFormatInfo"
    1005 => "resolutionInfo"
    1006 => "alphaChannelNames"
    1007 => "displayInfo"
    1008 => "caption"
    1009 => "borderInfo"
    1010 => "backgroundColor"
    1011 => "printFlags"
    1012 => "grayscaleHalftone"
    1013 => "colorHalftone"
    1014 => "duotoneHalftone"
    1015 => "grayscaleTransfer"
    1016 => "colorTransfer"
    1017 => "duotoneTransfer"
    1018 => "duotoneImageInfo"
    1019 => "effectiveBW"
    1024 => "layerStateInfo"
    1025 => "workingPath"
    1026 => "layerGroupInfo"
    1028 => "iptcNaa"
    1029 => "imageMode"
    1030 => "jpegQuality"
    1032 => "gridAndGuides"
    1033 => "thumbnailPs4"
    1034 => "copyrightFlag"
    1035 => "url"
    1036 => "thumbnail"
    1037 => "globalAngle"
    1038 => "colorSamplers"
    1039 => "iccProfile"
    1040 => "watermark"
    1041 => "iccUntaggedProfile"
    1042 => "effectsVisible"
    1043 => "documentIdsSeed"
    1044 => "unicodeAlphaNames"
    1045 => "indexedColorTableCount"
    1046 => "transparencyIndex"
    1047 => "transparencyIndex"
    1049 => "globalAltitude"
    1050 => "slices"
    1051 => "workflowUrl"
    1052 => "jumpToXpep"
    1053 => "alphaIdentifiers"
    1054 => "urlList"
    1057 => "versionInfo"
    1058 => "exifData1"
    1059 => "exifData3"
    1060 => "xmpMetadata"
    1061 => "captionDigest"
    1062 => "printScale"
    1064 => "pixelAspectRatio"
    1065 => "layerComps"
    1066 => "alternateDuotoneColors"
    1067 => "alternateSpotColors"
    1069 => "layerSelectionIds"
    1070 => "hdrToningInfo"
    1071 => "printInfo"
    1072 => "layerGroupsEnabled"
    1073 => "colorSamplers"
    1074 => "measurementScale"
    1075 => "timelineInfo"
    1076 => "sheetDisclosure"
    1077 => "displayInfoFP"
    1078 => "onionSkins"
    1080 => "countInfo"
    1081 => "printInfoCS5"
    1082 => "printStyle"
    1083 => "macNSPrintInfoPlist"
    1084 => "winsDEVMODE"
    1085 => "autoSaveFilePath"
    1086 => "autoSaveFormat"
    1087 => "pathSelectionState"
    1088 => "pathInfo"
    1089 => "originPathInfo"
    2999 => "clippingPathName"
    4000 => "pluginResource1"
    4001 => "pluginResource2"
    4002 => "pluginResource3"
    7000 => "imageSourcingLightroom"
    7001 => "imageSourcingCameraRaw"
    7002 => "imageSourcingCC"
    10000 => "printFlagsInfo"
    _ => "unknown"
  }
}

///|
fn bytes_to_ascii(data : Bytes) -> String {
  let buf = @buffer.new(size_hint=data.length())
  for i = 0; i < data.length(); i = i + 1 {
    let ch = data[i].to_int()
    if ch >= 32 && ch < 127 {
      buf.write_char(ch.unsafe_to_char())
    } else {
      buf.write_char('?')
    }
  }
  buf.to_string()
}

///|
fn json_escape(s : String) -> String {
  let buf = @buffer.new(size_hint=s.length())
  for ch in s {
    if ch == '"' {
      buf.write_string("\\\"")
    } else if ch == '\\' {
      buf.write_string("\\\\")
    } else if ch == '\n' {
      buf.write_string("\\n")
    } else if ch == '\r' {
      buf.write_string("\\r")
    } else if ch == '\t' {
      buf.write_string("\\t")
    } else {
      buf.write_char(ch)
    }
  }
  buf.to_string()
}
