import std/[strformat, sugar, tables, unicode]
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

        # Hold Indicators
        Vertical    = "｜",
        Horizontal  = "―",
        Up          = "∧",
        Down        = "Ｖ",
        Left        = "＜"
        Right       = "＞",

        # Empty tokens
        EmptyTick   = "ー"
        EmptyNote   = "口"

    SectionPart = object
        timings: seq[Token]
        snaps: seq[Snap]
        notes: Table[NoteRange, Token]

const
    FillerNotes = { Token.Vertical, Token.Horizontal, Token.EmptyNote, Token.EmptyTick }
    HoldStart = { Token.Up, Token.Down, Token.Left, Token.Right }
    NotePosition = 0..15.NoteRange
    NonTokenChars = toRunes($(Whitespace + {'|'}))

proc parseMemoToMemson*(content: string): Memson =
    ## Parses the provided memo-data to a memson object (memo object representation).
    ## The content has to be a complete memo file to be parsed correctly.

    let reader = newLineReader(content)
    var sectionIndex: uint = 0
    var minBpm: float = -1
    var maxBpm: float = -1
    var bpm : float = -1
    var holds = initTable[NoteRange, seq[Note]]()
    var parts = newSeq[SectionPart]()
    var partIndex: uint8 = 0

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
                result.level = uint8(parseUInt(row.runeSubStr(6).strip))
                continue
            except ValueError:
                {.cast(noSideEffect).}:
                    raise newException(ParseError, fmt"Could not parse Level '{row}' on line {reader.line}!: " & getCurrentExceptionMsg())

        if row.toLower.startsWith("bpm"):
            try:
                bpm = parseFloat(row.runeSubStr(4).strip)
                minBpm = if (minBpm == -1): bpm else: min(bpm, minBpm)
                maxBpm = if (maxBpm == -1): bpm else: max(bpm, maxBpm)

                if (sectionIndex == 0):
                    result.bpm = bpm
                continue
            except ValueError:
                {.cast(noSideEffect).}:
                    raise newException(ParseError, fmt"Could not parse BPM '{row}' on line {reader.line}!: " & getCurrentExceptionMsg())

        try:
            let tmpIndex = parseUInt(row)
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

        parts.add parseSectionParts(partIndex, [row, reader.nextLine(), reader.nextLine(), reader.nextLine()])
        inc partIndex

    # Build the section from the sub-sections if any exist
    if parts.len > 0:
        result.sections.add parseSection(sectionIndex, partIndex, bpm, holds, parts)
        partIndex = 0
        inc sectionIndex

proc parseSection(index: uint, partIndex: uint8, bpm: float, holds: var Table[NoteRange, seq[Note]], parts: seq[SectionPart]): Section =
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
                result.timings.add tickToIndex(timing)
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

            let noteTiming = result.timings.find(tickToIndex(noteType))
            var hold = Note(kind: NoteType.Hold, time: uint8(offset + noteTiming), partIndex: uint8(partIndex / 4), animationStartIndex: uint8(noteIndex))
            result.notes[noteIndex] = hold

            # Create the seq if there's none set
            if not holds.contains(noteIndex):
                holds[noteIndex] = @[]
            holds[noteIndex].add hold

        for noteIndex in noteIndices:
            let noteType = singlePart.notes[noteIndex]
            let noteTiming = result.timings.find(tickToIndex(noteType))

            if holds.contains(noteIndex) and holds[noteIndex].len > 0:
                # Regular for loop makes the elements immutable, therefore
                # using this roundabout way with the index
                for hold in holds[noteIndex].mitems:
                    hold.releaseSection = uint8(index)
                    hold.releaseTime = uint8(offset + noteTiming)
                holds.del noteIndex
            else:
                result.notes[noteIndex] = Note(kind: NoteType.Note, time: uint8(offset + noteTiming), partIndex: uint8(partIndex / 4))

        # Increment the offset for the next sub-section
        inc offset, singlePart.timings.len
    
    # Sort the notes by the index
    result.notes.sort((a, b) => system.cmp(a[0], b[0]))

func parseSectionParts(index: uint8, rows: array[4, string]): SectionPart =
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
                raise newException(ParseError, fmt"Could not parse note-data from line: '{noteData.runeAt(noteIndex)}'!")

            result.notes[(rowIndex * 4) + noteIndex] = parsed
            inc noteIndex

        if line.runeLen > 4:
            try:
                let timingData = line.runeSubStr(4).strip(runes = NonTokenChars)
                for str in utf8(timingData):
                    var parsed = Token.EmptyTick

                    try:
                        parsed = parseEnum[Token]($str)
                    #except ValueError:
                    #    discard
                    except:
                        log fmt"Could not parse timing token from '{str}'!"
                        raise

                    result.timings.add parsed

                result.snaps.add Snap(len: uint8(timingData.runeLen), row: uint8(rowIndex), partIndex: index)
            except:
                {.cast(noSideEffect).}:
                    raise newException(ParseError, fmt"Could not parse timing-data from line: '{rows[rowIndex]}'! " & getCurrentExceptionMsg())
        inc rowIndex

func parseDifficulty(diff: string): Difficulty {.raises: [ParseError, ValueError] .} =
    try:
        return parseEnum[Difficulty](diff.toLower())
    except ValueError:
        raise newException(ParseError, fmt"Could not parse Difficulty '{diff}'!")

func holdOffset(token: Token): int =
    case token:
        of Token.Up:
            return -4
        of Token.Down:
            return 4
        of Token.Left:
            return -1            
        of Token.Right:
            return 1
        else:
            return 0

func tickToIndex(token: Token): int8 =
    case token:
        of Token.Pos1:
            return 1
        of Token.Pos2:
            return 2
        of Token.Pos3:
            return 3
        of Token.Pos4:
            return 4
        of Token.Pos5:
            return 5
        of Token.Pos6:
            return 6
        of Token.Pos7:
            return 7
        of Token.Pos8:
            return 8
        of Token.Pos9:
            return 9
        of Token.Pos10:
            return 10
        of Token.Pos11:
            return 11
        of Token.Pos12:
            return 12
        of Token.Pos13:
            return 13
        of Token.Pos14:
            return 14
        of Token.Pos15:
            return 15
        of Token.Pos16:
            return 16
        else:
            return -1
