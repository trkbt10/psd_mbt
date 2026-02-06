///|
pub(all) enum BlendMode {
  PassThrough
  Normal
  Dissolve
  Darken
  Multiply
  ColorBurn
  LinearBurn
  DarkerColor
  Lighten
  Screen
  ColorDodge
  LinearDodge
  LighterColor
  Overlay
  SoftLight
  HardLight
  VividLight
  LinearLight
  PinLight
  HardMix
  Difference
  Exclusion
  Subtract
  Divide
  Hue
  Saturation
  Color
  Luminosity
  Unknown(Bytes)
} derive(Eq, Show)

///|
pub fn BlendMode::from_bytes(data : Bytes) -> BlendMode {
  if data.length() != 4 {
    return Unknown(data)
  }
  // Compare as 4-byte ASCII key
  if data == b"pass" {
    PassThrough
  } else if data == b"norm" {
    Normal
  } else if data == b"diss" {
    Dissolve
  } else if data == b"dark" {
    Darken
  } else if data == b"mul " {
    Multiply
  } else if data == b"idiv" {
    ColorBurn
  } else if data == b"lbrn" {
    LinearBurn
  } else if data == b"dkCl" {
    DarkerColor
  } else if data == b"lite" {
    Lighten
  } else if data == b"scrn" {
    Screen
  } else if data == b"div " {
    ColorDodge
  } else if data == b"lddg" {
    LinearDodge
  } else if data == b"lgCl" {
    LighterColor
  } else if data == b"over" {
    Overlay
  } else if data == b"sLit" {
    SoftLight
  } else if data == b"hLit" {
    HardLight
  } else if data == b"vLit" {
    VividLight
  } else if data == b"lLit" {
    LinearLight
  } else if data == b"pLit" {
    PinLight
  } else if data == b"hMix" {
    HardMix
  } else if data == b"diff" {
    Difference
  } else if data == b"smud" {
    Exclusion
  } else if data == b"fsub" {
    Subtract
  } else if data == b"fdiv" {
    Divide
  } else if data == b"hue " {
    Hue
  } else if data == b"sat " {
    Saturation
  } else if data == b"colr" {
    Color
  } else if data == b"lum " {
    Luminosity
  } else {
    Unknown(data)
  }
}

///|
pub fn BlendMode::to_bytes(self : BlendMode) -> Bytes {
  match self {
    PassThrough => b"pass"
    Normal => b"norm"
    Dissolve => b"diss"
    Darken => b"dark"
    Multiply => b"mul "
    ColorBurn => b"idiv"
    LinearBurn => b"lbrn"
    DarkerColor => b"dkCl"
    Lighten => b"lite"
    Screen => b"scrn"
    ColorDodge => b"div "
    LinearDodge => b"lddg"
    LighterColor => b"lgCl"
    Overlay => b"over"
    SoftLight => b"sLit"
    HardLight => b"hLit"
    VividLight => b"vLit"
    LinearLight => b"lLit"
    PinLight => b"pLit"
    HardMix => b"hMix"
    Difference => b"diff"
    Exclusion => b"smud"
    Subtract => b"fsub"
    Divide => b"fdiv"
    Hue => b"hue "
    Saturation => b"sat "
    Color => b"colr"
    Luminosity => b"lum "
    Unknown(data) => data
  }
}
