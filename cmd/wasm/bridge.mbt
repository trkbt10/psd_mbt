///|
/// Global document store: maps handle IDs to parsed PsdFile instances.
let documents : Array[@psd_fmt.PsdFile?] = []

///|
/// Last error message for cross-boundary error reporting.
let last_error : Ref[String] = { val: "" }

///|
/// Parse a PSD file from a latin1-encoded string (each char = one byte).
/// Returns a non-negative handle on success, or -1 on error.
/// Call get_last_error() to retrieve the error message.
pub fn parse_psd(data_str : String) -> Int {
  last_error.val = ""
  try {
    let data = string_to_bytes(data_str)
    let psd = @psd_fmt.PsdFile::parse(data)
    let handle = documents.length()
    documents.push(Some(psd))
    handle
  } catch {
    e => {
      last_error.val = error_to_string(e)
      -1
    }
  }
}

///|
/// Get the document IR as a JSON string.
/// Returns empty string if the handle is invalid.
pub fn get_document_ir(handle : Int) -> String {
  last_error.val = ""
  if handle < 0 || handle >= documents.length() {
    last_error.val = "Invalid handle"
    return ""
  }
  match documents[handle] {
    Some(psd) => serialize_psd_to_json(psd)
    None => {
      last_error.val = "Document has been freed"
      ""
    }
  }
}

///|
/// Rebuild the PSD file from the stored document.
/// Returns a latin1-encoded string (each char = one byte), or empty string on error.
pub fn rebuild_psd(handle : Int) -> String {
  last_error.val = ""
  if handle < 0 || handle >= documents.length() {
    last_error.val = "Invalid handle"
    return ""
  }
  match documents[handle] {
    Some(psd) => bytes_to_latin1(psd.build())
    None => {
      last_error.val = "Document has been freed"
      ""
    }
  }
}

///|
/// Free a parsed document to release memory.
pub fn free_document(handle : Int) -> Unit {
  if handle >= 0 && handle < documents.length() {
    documents[handle] = None
  }
}

///|
/// Get the last error message. Returns empty string if no error.
pub fn get_last_error() -> String {
  last_error.val
}

///|
/// Convert a latin1-encoded String (each char 0-255) to Bytes.
fn string_to_bytes(s : String) -> Bytes {
  let buf = @buffer.new(size_hint=s.length())
  for ch in s {
    buf.write_byte(ch.to_int().to_byte())
  }
  buf.to_bytes()
}

///|
/// Convert Bytes to a latin1-encoded String (each byte becomes a char).
fn bytes_to_latin1(data : Bytes) -> String {
  let buf = @buffer.new(size_hint=data.length())
  for i = 0; i < data.length(); i = i + 1 {
    buf.write_char(data[i].to_int().unsafe_to_char())
  }
  buf.to_string()
}

///|
fn error_to_string(e : Error) -> String {
  match e {
    @types.UnexpectedEof => "Unexpected end of file"
    @types.InvalidSignature(_) => "Invalid PSD signature"
    @types.InvalidVersion(v) => "Invalid version: " + v.to_string()
    @types.InvalidColorMode(v) => "Invalid color mode: " + v.to_string()
    @types.InvalidCompression(v) => "Invalid compression: " + v.to_string()
    @types.InvalidReserved => "Invalid reserved bytes"
    @types.ChannelsOutOfRange(v) => "Channels out of range: " + v.to_string()
    @types.InvalidDepth(v) => "Invalid depth: " + v.to_string()
    @types.DimensionsOutOfRange(w, h) =>
      "Dimensions out of range: " + w.to_string() + "x" + h.to_string()
    @types.InvalidColorModeDataLength(expected, actual) =>
      "Invalid color mode data length: expected " +
      expected.to_string() +
      ", got " +
      actual.to_string()
    _ => "Unknown error"
  }
}

///|
fn main {
  ()
}
