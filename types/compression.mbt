///|
pub(all) enum Compression {
  Raw
  Rle
  ZipNoPrediction
  ZipPrediction
} derive(Eq, Show)

///|
pub fn Compression::to_int(self : Compression) -> Int {
  match self {
    Raw => 0
    Rle => 1
    ZipNoPrediction => 2
    ZipPrediction => 3
  }
}

///|
pub fn Compression::from_int(value : Int) -> Compression raise PsdError {
  match value {
    0 => Raw
    1 => Rle
    2 => ZipNoPrediction
    3 => ZipPrediction
    _ => raise InvalidCompression(value)
  }
}
