import std/[sequtils, strformat, sugar, tables, unicode]
import std/strutils except split, strip

import ./utils/line_reader
import ./common
import ./memson

{.experimental: "codeReordering".}

type
    Token {.pure.} = enum
        # Notes
        Pos1        = "①",
        Pos2        = "②",
        Pos3        = "③",
        Pos4        = "④",
        Pos5        = "⑤",
        Pos6        = "⑥",
        Pos7        = "⑦",
        Pos8        = "⑧",
        Pos9        = "⑨",
        Pos10       = "⑩",
        Pos11       = "⑪",
        Pos12       = "⑫",
        Pos13       = "⑬",
        Pos14       = "⑭",
        Pos15       = "⑮",
        Pos16       = "⑯",
        Pos17       = "⑰",
        Pos18       = "⑱",
        Pos19       = "⑲",
        Pos20       = "⑳",

        # Hold Indicators
        Vertical    = "｜",
        Horizontal  = "―",
        Up          = "∧",
        Down        = "Ｖ",
        Down2       = "∨",
        Left        = "＜"
        Right       = "＞",

        # Empty tokens
        EmptyTick   = "ー"
        EmptyTick2  = "－"
        EmptyTick3  = "-"
        EmptyTick4  = "〇" # WTF EVEN?!?!
        EmptyNote   = "口"

    SectionPart = object
        timings: seq[Token]
        snaps: seq[Snap]
        notes: Table[NoteRange, Token]

const
    AllTokens = Token.toSeq.map(t => $t)
    TokenMap: array[Token, int] = [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1]
    FillerNotes = { Token.Vertical, Token.Horizontal, Token.EmptyNote, Token.EmptyTick, Token.EmptyTick2, Token.EmptyTick3, Token.EmptyTick4 }
    HoldStart = { Token.Up, Token.Down, Token.Down2, Token.Left, Token.Right }
    NotePosition = 0..15.NoteRange
    NonTokenChars = toRunes($(Whitespace + {'|'}))

proc parseMemoToMemson*(content: string): Memson =
    ## Parses the provided memo-data to a memson object (memo object representation).
    ## The content has to be a complete memo file to be parsed correctly.

    let reader = newLineReader(content)
    var sectionIndex: int = -1
    var minBpm: float = -1
    var maxBpm: float = -1
    var bpm : float = -1
    var holds = initTable[NoteRange, seq[Note]]()
    var parts = newSeq[SectionPart]()
    var partIndex: int = 0

    try:
        result.songTitle = reader.nextLine()
        result.artist = reader.nextLine()
        result.difficulty = parseDifficulty(reader.nextLine())
        result.sections = @[]
    except:
        {.cast(noSideEffect).}:
            raise newException(ParseError, fmt"Could not parse memo header!: " & getCurrentExceptionMsg())

    while not reader.isEOF():
        var row = reader.nextLine()

        if row.isEmptyOrWhitespace():
            continue

        if row.toLower.startsWith("level"):
            try:
                result.level = parseInt(row.runeSubStr(6).strip)
                continue
            except ValueError:
                {.cast(noSideEffect).}:
                    raise newException(ParseError, fmt"Could not parse Level '{row}' on line {reader.line}!: " & getCurrentExceptionMsg())

        if row.toLower.startsWith("bpm"):
            try:
                var tmp = row.runeSubStr(4).strip
                let dashIdx = tmp.find("-")
                if dashIdx > -1:
                    let tmpMin = parseFloat(tmp.runeSubStr(0, dashIdx))
                    let tmpMax = parseFloat(tmp.runeSubStr(dashIdx + 1))
                    minBpm = if minBpm == -1: tmpMin else: min(minBpm, tmpMin)
                    maxBpm = if maxBpm == -1: tmpMax else: max(maxBpm, tmpMax)
                else:
                    bpm = parseFloat(tmp)
                    minBpm = if minBpm == -1: bpm else: min(bpm, minBpm)
                    maxBpm = if maxBpm == -1: bpm else: max(bpm, maxBpm)

                if (sectionIndex == 0):
                    result.bpm = bpm
                continue
            except ValueError:
                {.cast(noSideEffect).}:
                    raise newException(ParseError, fmt"Could not parse BPM '{row}' on line {reader.line}!: " & getCurrentExceptionMsg())

        try:
            let tmpIndex = parseInt(row)
            if tmpIndex > 1:
                # Build the section from the sub-sections if any exist
                if parts.len > 0:
                    result.sections.add parseSection(sectionIndex, partIndex, bpm, holds, parts)

                # Clear the sub-sections
                parts = @[]
                partIndex = 0

            # Update the section to the next one
            sectionIndex = tmpIndex
            continue
        except:
            # if it's not a index which could be parsed, then it's a regular section line
            discard

        let firstChar = row.strip.runeAt(0)
        if firstChar.isAlpha and not AllTokens.contains($firstChar):
            # Ignore other parameters
            continue

        parts.add parseSectionParts(partIndex, reader.line, [row, reader.nextLine(), reader.nextLine(), reader.nextLine()])
        inc partIndex

    # Build the section from the sub-sections if any exist
    if parts.len > 0:
        result.sections.add parseSection(sectionIndex, partIndex, bpm, holds, parts)
        partIndex = 0
        inc sectionIndex

proc parseSection(index: int, partIndex: int, bpm: float, holds: var Table[NoteRange, seq[Note]], parts: seq[SectionPart]): Section =
    result.index = index
    result.bpm = bpm
    result.partCount = partIndex
    result.notes = initOrderedTable[NoteRange, Note]()
    result.timings = @[]
    result.snaps = @[]

    var offset = 0

    for partIndex, singlePart in parts.pairs:
        # Add the snaps
        for snap in singlePart.snaps:
            result.snaps.add snap

        # Add the timings
        for timingIndex, timing in singlePart.timings.pairs:
            if not FillerNotes.contains timing:
                result.timings.add TokenMap[timing]
            else:
                result.timings.add -1

        var noteIndices = newSeq[int]()

        for noteIndex in NotePosition:
            let noteType = if singlePart.notes.contains(noteIndex): singlePart.notes[noteIndex] else: Token.EmptyNote

            # Skip empty/invalid notes
            if FillerNotes.contains(noteType) or HoldStart.contains(noteType):
                continue

            var holdOffset = holdOffset(noteType)

            # If it is a regular note, save it to the note-indices for later processing
            if holdOffset == 0:
                noteIndices.add noteIndex
                continue

            var holdEnd = noteIndex
            while NotePosition.contains holdEnd:
                inc holdEnd, holdOffset
                # Skip filler notes
                if FillerNotes.contains singlePart.notes[holdEnd]:
                    continue
                break

            let noteTiming = result.timings.find(TokenMap[noteType])
            var hold = Note(kind: NoteType.Hold, time: offset + noteTiming, partIndex: partIndex div 4, animationStartIndex: noteIndex)
            result.notes[noteIndex] = hold

            # Create the seq if there's none set
            if not holds.contains(noteIndex):
                holds[noteIndex] = @[]
            holds[noteIndex].add hold

        for noteIndex in noteIndices:
            let noteType = singlePart.notes[noteIndex]
            let noteTiming = result.timings.find(TokenMap[noteType])

            if holds.contains(noteIndex) and holds[noteIndex].len > 0:
                # Regular for loop makes the elements immutable, therefore
                # using this roundabout way with the index
                for hold in holds[noteIndex].mitems:
                    hold.releaseSection = index
                    hold.releaseTime = offset + noteTiming
                holds.del noteIndex
            else:
                result.notes[noteIndex] = Note(kind: NoteType.Note, time: offset + noteTiming, partIndex: partIndex div 4)

        # Increment the offset for the next sub-section
        inc offset, singlePart.timings.len
    
    # Sort the notes by the index
    result.notes.sort((a, b) => system.cmp(a[0], b[0]))

proc parseSectionParts(index: int, lineIndex: int, rows: array[4, string]): SectionPart =
    result.snaps = @[]
    result.timings = @[]
    result.notes = initTable[NoteRange, Token]()

    var rowIndex = 0
    for line in rows:
        if line.isEmptyOrWhitespace():
            return

        let noteData = line.runeSubStr(0, 4).strip(runes = NonTokenChars)
        var noteIndex = 0

        for note in utf8(noteData):
            var parsed: Token = Token.EmptyNote;

            try:
                parsed = parseEnum[Token](note)
            #except ValueError:
            #    discard
            except:
                raise newException(ParseError, fmt"Could not parse note-data '{note}' on pos {noteIndex} from line {lineIndex + rowIndex} '{line}'!")

            result.notes[(rowIndex * 4) + noteIndex] = parsed
            inc noteIndex

        if line.runeLen > 4:
            try:
                let timingData = line.runeSubStr(4).strip(runes = NonTokenChars)
                for str in utf8(timingData):
                    if str.isEmptyOrWhitespace:
                        continue
                    var parsed = Token.EmptyTick

                    try:
                        parsed = parseEnum[Token]($str)
                    #except ValueError:
                    #    discard
                    except:
                        log fmt"Could not parse timing token from '{str}'!"
                        raise

                    result.timings.add parsed

                result.snaps.add Snap(len: timingData.runeLen, row: rowIndex, partIndex: index)
            except:
                {.cast(noSideEffect).}:
                    raise newException(ParseError, fmt"Could not parse timing-data from line: '{rows[rowIndex]}'! " & getCurrentExceptionMsg())
        inc rowIndex

func holdOffset(token: Token): int =
    case token:
        of Token.Up:
            return -4
        of Token.Down, Token.Down2:
            return 4
        of Token.Left:
            return -1            
        of Token.Right:
            return 1
        else:
            return 0
