import std/[strutils, unicode]

## A LineReader simply reads over the provided string and retutns
## stripped lines until all lines have been read.
##
type
    LineReader* = ref object of RootObj
        str: string
        len: int
        pos: int
        line: int

const
    WhitespaceAndCR = Whitespace + {'\r'}
    NewLine = '\n'

func newLineReader*(str: string): LineReader =
    return LineReader(str: str, pos: 0, line: 0)

method nextLine*(this: LineReader): string {.base, inline, noSideEffect, raises: [] .} =
    ## Reads the next line without trailing whitespaces
    ## Skips empty lines all together
    var start = this.pos
    var lastCharPos = -1
    var finish = -1

    while this.pos < this.str.runeLen:
        let c = this.str[this.pos]
        let cLen = c.Rune.size

        if char(c) == NewLine:
            inc this.line

            # Hasn't started yet
            if this.pos == start:
                inc this.pos, cLen
                start = this.pos
                continue
        
            # Mark the end
            if finish == -1:
                finish = lastCharPos
            
            inc this.pos, cLen
            continue

        # Skip whitespaces at the beginning and end of a line
        if WhitespaceAndCR.contains char(c):
            if this.pos == start:
                inc this.pos, cLen
                start = this.pos
            else:
                inc this.pos, cLen
            continue

        # String has already finished, and the pos has been moved in front
        # of the next character in the next (not empty) line.
        if finish != -1:
            break

        # Include this character to the regular output
        lastCharPos = this.pos
        inc this.pos, cLen

    # if it didn't "finish", due to reaching EOL
    result = if finish == -1 : this.str.substr(start, lastCharPos) else: this.str.substr(start, finish)

method line*(this: LineReader): int {.base, inline, noSideEffect, raises: [] .}  =
    return this.line

method isEOF*(this: LineReader): bool {.base, inline, noSideEffect, raises: [] .} =
    ## Returns if the LineReader has reached the end and can't produce any more lines
    return this.pos >= this.str.runeLen

method reset*(this: LineReader): void {.base, inline, noSideEffect, raises: [] .} =
    ## Resets the LineReader to the beginning
    this.pos = 0
    this.line = 0
