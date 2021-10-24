import std/[unicode]

type
    LineReader* = ref object of RootObj
        ## A LineReader simply reads over the provided string and retutns
        ## stripped lines until all lines have been read.
        # The string it's reading
        str: string
        # Total length of the string
        len: int
        # Byte offset where the reader left off
        cursor: int
        # Current line it's on
        line: int
        # Current column it's on
        col: int

# No using the strutil.Newlines, as it also contains the
# carrige-return (\r), which we simply ignore (screw CRLF)
const
    NewLine = '\n'

func newLineReader*(str: string): LineReader =
    ## Creates a new LineReader instance from the given string
    return LineReader(str: str, len: str.len, cursor: 0, line: 1, col: 1)

method nextLine*(this: LineReader): string {.base, noSideEffect, raises: [] .} =
    ## Reads the next line without trailing whitespaces
    ## Skips empty lines all together
    var start = this.cursor
    var lastCharcursor = -1
    var finish = -1

    while this.len > this.cursor:
        # Get the current character and it's byte length
        let c = this.str.runeAt(this.cursor)
        let cLen = c.size

        if cLen == 1 and char(c) == NewLine:
            # New line (with content) hasn't started yet.
            # Moving start along with the cursor until we find
            # the first character
            if this.cursor == start:
                inc this.cursor, cLen
                start = this.cursor
                inc this.line
                this.col = 1
                continue

            # Mark the end
            if finish == -1:
                finish = lastCharcursor

            # Increase the line, reset the column and move the cursor
            # to the next character
            inc this.line
            this.col = 1
            inc this.cursor, cLen
            continue

        # Skip whitespaces at the beginning and end of a line
        if isWhiteSpace(c) or (c.size == 1 and int(c).char == '\r'):
            if this.cursor == start:
                inc this.cursor, cLen
                inc this.col
                start = this.cursor
            else:
                inc this.cursor, cLen
                inc this.col
            continue

        # String has already finished, and the cursor has been moved in front
        # of the next character in the next (not empty) line.
        if finish != -1:
            break

        # Include this character to the regular output
        lastCharcursor = this.cursor
        inc this.cursor, cLen
        inc this.col

    # if it didn't "finish", due to reaching EOL, we need to use lastCharcursor instead of finish
    result = if finish == -1: this.str.substr(start, lastCharcursor) else: this.str.substr(start, finish)

method line*(this: LineReader): int {.base, inline, noSideEffect, raises: [] .}  =
    ## Returns the line number where the reader is currently on
    return this.line

method col*(this: LineReader): int {.base, inline, noSideEffect, raises: [] .} =
    ## Returns the column number where the reader is currently on
    return this.col

method isEOF*(this: LineReader): bool {.base, inline, noSideEffect, raises: [] .} =
    ## Returns if the LineReader has reached the end and can't produce any more lines
    return this.cursor >= this.len

method reset*(this: LineReader): void {.base, noSideEffect, raises: [] .} =
    ## Resets the LineReader to the beginning
    this.cursor = 0
    this.line = 1
    this.col = 1
