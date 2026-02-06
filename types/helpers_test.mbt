///|
test "bytes_per_line depth=1" {
  // 8 pixels = 1 byte, 9 pixels = 2 bytes
  inspect(bytes_per_line(8, 1), content="1")
  inspect(bytes_per_line(9, 1), content="2")
  inspect(bytes_per_line(1, 1), content="1")
  inspect(bytes_per_line(16, 1), content="2")
  inspect(bytes_per_line(17, 1), content="3")
}

///|
test "bytes_per_line depth=8" {
  inspect(bytes_per_line(4, 8), content="4")
  inspect(bytes_per_line(1, 8), content="1")
  inspect(bytes_per_line(100, 8), content="100")
}

///|
test "bytes_per_line depth=16" {
  inspect(bytes_per_line(4, 16), content="8")
  inspect(bytes_per_line(1, 16), content="2")
}

///|
test "bytes_per_line depth=32" {
  inspect(bytes_per_line(4, 32), content="16")
  inspect(bytes_per_line(1, 32), content="4")
}
