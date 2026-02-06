///|
pub(all) suberror PsdError {
  UnexpectedEof
  InvalidSignature(Bytes)
  InvalidVersion(Int)
  InvalidColorMode(Int)
  InvalidCompression(Int)
}
