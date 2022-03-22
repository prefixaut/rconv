import std/strutils

import ./line_reader

type
    Tag = tuple[name: string, data: string]

iterator parseTags*(data: string): Tag =
    var reader = newLineReader(data)
    var inMeta = false
    var tag = ""
    var data = ""

    while not reader.isEOF():
        var line = reader.nextLine()

        # Cut out comments
        let commentStart = line.find("//")
        if commentStart > -1:
            line = line.substr(commentStart + 2)

        # Skip now empty lines
        if line.isEmptyOrWhitespace:
            continue

        if inMeta:
            let eend = line.find(";")
            if eend > -1:
                data &= line.substr(0, eend - 1)
                yield (tag, data)

                tag = ""
                data = ""
                inMeta = false
            else:
                data &= line
            continue

        if line.startsWith("#"):
            let sep = line.find(":")
            let eend = line.find(";")
            tag = line.substr(1, sep - 1).strip

            if eend > -1:
                yield (tag, line.substr(sep + 1, eend - 1))
                tag = ""
            else:
                data = line.substr(sep + 1)
                inMeta = true
            continue

