##[
    Module which contains helper-procs for easier stream interactions.
]##

import std/[encodings, streams]

const
    Terminator = '\0'

func toString*(bytes: seq[byte]): string =
  result = newStringOfCap(len(bytes))
  for b in bytes:
    add(result, char(b))

proc readUTF8Str*(stream: Stream): string =
    var buffer = newSeq[uint8]()

    while not stream.atEnd:
        let c = stream.readUint8
        if char(c) == Terminator:
            buffer.add(c)
            break
        buffer.add(c)

    result = convert(buffer.toString, "UTF-8")

proc writeUTF8*(stream: Stream, strings: varargs[string]): void =
    for str in strings:
        stream.write(str, Terminator)
