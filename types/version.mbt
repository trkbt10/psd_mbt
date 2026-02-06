///|
pub(all) enum PsdVersion {
  Psd
  Psb
} derive(Eq, Show)

///|
pub fn PsdVersion::to_int(self : PsdVersion) -> Int {
  match self {
    Psd => 1
    Psb => 2
  }
}

///|
pub fn PsdVersion::from_int(value : Int) -> PsdVersion raise PsdError {
  match value {
    1 => Psd
    2 => Psb
    _ => raise InvalidVersion(value)
  }
}
