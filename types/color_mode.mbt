///|
pub(all) enum ColorMode {
  Bitmap
  Grayscale
  Indexed
  RGB
  CMYK
  Multichannel
  Duotone
  Lab
} derive(Eq, Show)

///|
pub fn ColorMode::to_int(self : ColorMode) -> Int {
  match self {
    Bitmap => 0
    Grayscale => 1
    Indexed => 2
    RGB => 3
    CMYK => 4
    Multichannel => 7
    Duotone => 8
    Lab => 9
  }
}

///|
pub fn ColorMode::from_int(value : Int) -> ColorMode raise PsdError {
  match value {
    0 => Bitmap
    1 => Grayscale
    2 => Indexed
    3 => RGB
    4 => CMYK
    7 => Multichannel
    8 => Duotone
    9 => Lab
    _ => raise InvalidColorMode(value)
  }
}
