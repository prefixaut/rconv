import std/[encodings, streams]

proc toString*(bytes: seq[byte]): string =
  result = newStringOfCap(len(bytes))
  for b in bytes:
    add(result, char(b))

proc readUTF8Str*(stream: Stream, terminator: uint8 = 0,
    includeTerm: bool = false, consumeTerm: bool = true): string =

    var buffer = newSeq[uint8]()
    while true:
        let c = stream.readUint8
        if c == terminator:
            if includeTerm:
                buffer.add(c)
            if not consumeTerm:
                stream.setPosition(stream.getPosition - 1)
            break
        buffer.add(c)
    
    result = convert(buffer.toString, "UTF-8")
