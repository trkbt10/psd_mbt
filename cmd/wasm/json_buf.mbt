///|
/// Simple JSON string builder for serialization.
struct JsonBuf {
  buf : @buffer.Buffer
}

///|
fn JsonBuf::new() -> JsonBuf {
  { buf: @buffer.new(size_hint=4096) }
}

///|
fn JsonBuf::object_start(self : JsonBuf) -> Unit {
  self.buf.write_char('{')
}

///|
fn JsonBuf::object_end(self : JsonBuf) -> Unit {
  self.buf.write_char('}')
}

///|
fn JsonBuf::array_start(self : JsonBuf) -> Unit {
  self.buf.write_char('[')
}

///|
fn JsonBuf::array_end(self : JsonBuf) -> Unit {
  self.buf.write_char(']')
}

///|
fn JsonBuf::comma(self : JsonBuf) -> Unit {
  self.buf.write_char(',')
}

///|
fn JsonBuf::key(self : JsonBuf, k : String) -> Unit {
  self.buf.write_char('"')
  self.buf.write_string(k)
  self.buf.write_string("\":")
}

///|
fn JsonBuf::string(self : JsonBuf, s : String) -> Unit {
  self.buf.write_char('"')
  self.buf.write_string(s)
  self.buf.write_char('"')
}

///|
fn JsonBuf::int(self : JsonBuf, n : Int) -> Unit {
  self.buf.write_string(n.to_string())
}

///|
fn JsonBuf::bool(self : JsonBuf, b : Bool) -> Unit {
  self.buf.write_string(if b { "true" } else { "false" })
}

///|
fn JsonBuf::null(self : JsonBuf) -> Unit {
  self.buf.write_string("null")
}

///|
fn JsonBuf::to_string(self : JsonBuf) -> String {
  self.buf.to_string()
}
