import std/[strutils, unicode]

## A LineReader simply reads over the provided string and retutns
## stripped lines until all lines have been read.
##
type
    LineReader* = ref object of RootObj
        str: string
        len: int
        pos: int

const
    WhitespaceAndCR = Whitespace + {'\r'}
    NewLine = '\n'

func newLineReader*(str: string): LineReader =
    return LineReader(str: str, pos: 0)

method nextLine*(this: LineReader): string {.base, inline, raises: [ValueError] .} =
    ## Reads the next line without trailing whitespaces
    ## Skips empty lines all together
    var start = this.pos
    var lastCharPos = -1
    var finish = -1

    while this.pos < this.str.runeLen:
        let c = this.str[this.pos]
        let cLen = c.Rune.size

        if char(c) == NewLine:
            # Hasn't started yet
            if this.pos == start:
                this.pos += cLen
                start = this.pos
                continue
        
            # Mark the end
            if finish == -1:
                finish = lastCharPos
            
            this.pos += cLen
            continue

        # Skip whitespaces at the beginning and end of a line
        if WhitespaceAndCR.contains char(c):
            if this.pos == start:
                this.pos += cLen
                start = this.pos
            else:
                this.pos += cLen
            continue

        # String has already finished, and the pos has been moved in front
        # of the next character in the next (not empty) line.
        if finish != -1:
            break

        # Include this character to the regular output
        lastCharPos = this.pos
        this.pos += cLen

    # if it didn't "finish", due to reaching EOL
    result = if finish == -1 : this.str.substr(start, lastCharPos) else: this.str.substr(start, finish)

method isEOF*(this: LineReader): bool {.base, inline, raises: [] .} =
    ## Returns if the LineReader has reached the end and can't produce any more lines
    return this.pos >= this.str.runeLen

method reset*(this: LineReader): void {.base, inline, raises: [] .} =
    ## Resets the LineReader to the beginning
    this.pos = 0
