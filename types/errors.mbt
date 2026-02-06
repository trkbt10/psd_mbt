///|
pub(all) suberror PsdError {
  UnexpectedEof
  InvalidSignature(Bytes)
  InvalidVersion(Int)
  InvalidColorMode(Int)
  InvalidCompression(Int)
  InvalidReserved
  ChannelsOutOfRange(Int)
  InvalidDepth(Int)
  DimensionsOutOfRange(Int, Int)
  InvalidColorModeDataLength(Int, Int)
}
