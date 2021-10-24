import std/[strformat, tables, unicode]
import std/strutils except split, strip

import ./utils/[lineReader]
import ./common

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

    Difficulty {.pure.} = enum
        Basic       = "basic",
        Advanced    = "advanced",
        Extreme     = "extreme"

    NoteType {.pure.} = enum
        Note,
        Hold

    NoteRange = range[0..15]
    RowIndex = range[0..3]

    Note = object
        time: uint8
        case noteType: NoteType
        of Hold:
            animationStartIndex: uint8
            releaseTime: uint8
            releaseSection: uint8
        else:
            discard

    Section = object
        index: uint
        bpm: float
        timings: seq[Token]
        snaps: array[RowIndex, uint8]
        originalSnaps: seq[uint8]
        notes: Table[NoteRange, Note]

    Snap = object
        len: uint8
        row: RowIndex

    SubSection = object
        timings: seq[Token]
        snaps: seq[Snap]
        notes: Table[NoteRange, Token]

    Memson* = object
        songTitle: string
        artist: string
        difficulty: Difficulty
        level: uint8
        bpm: float
        bpmRange: tuple[min: float, max: float]
        sections: seq[Section]

const
    FillerNotes = { Token.Vertical, Token.Horizontal, Token.EmptyNote }
    HoldStart = { Token.Up, Token.Down, Token.Left, Token.Right }
    NotePosition = 0..15.NoteRange
    NonTokenChars = toRunes($(Whitespace + {'|'}))

func parseToMemson*(content: string): Memson {.raises: [ParseError, ValueError] .} =
    let reader = newLineReader(content)
    var sectionIndex: uint = 0
    var minBpm: float = -1
    var maxBpm: float = -1
    var bpm : float = -1
    var holds = initTable[NoteRange, seq[Note]]()
    var subSections = newSeq[SubSection]()

    try:
        result.songTitle = reader.nextLine()
        result.artist = reader.nextLine()
        result.difficulty = parseDifficulty(reader.nextLine())
        result.sections = newSeq[Section]()
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
                    raise newException(ParseError, fmt"Could not parse BPM '{row}'!: " & getCurrentExceptionMsg())

        try:
            let tmpIndex = parseUInt(row.strip)
            if tmpIndex > 1:
                # Build the section from the sub-sections if any exist
                if subSections.len > 0:
                    result.sections.add parseSection(sectionIndex, bpm, holds, subSections)
                    inc sectionIndex

                # Clear the sub-sections
                subSections = newSeq[SubSection]()
            # Update the section to the next one
            sectionIndex = tmpIndex
            continue
        except:
            discard

        subSections.add parseSubSection([row, reader.nextLine(), reader.nextLine(), reader.nextLine()])

    # Build the section from the sub-sections if any exist
    if subSections.len > 0:
        result.sections.add parseSection(sectionIndex, bpm, holds, subSections)
        inc sectionIndex

proc parseSection(index: uint, bpm: float, holds: var Table[NoteRange, seq[Note]], subSections: seq[SubSection]): Section =
    result.index = index
    result.bpm = bpm
    result.notes = initTable[NoteRange, Note]()
    result.timings = newSeq[Token]()
    result.snaps = [uint8(0), uint8(0), uint8(0), uint8(0)]
    
    # TODO: Fix all of this, still a mess
    var offset = 0

    for sub in subSections:
        # Add the snaps
        for snap in sub.snaps:
            result.snaps[snap.row] += snap.len

        # Add the timings
        for timing in sub.timings:
            result.timings.add timing

        var noteIndices = newSeq[NoteRange]()

        for noteIndex in NotePosition:
            let noteType = if sub.notes.contains(noteIndex): sub.notes[noteIndex] else: Token.EmptyNote

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
                if FillerNotes.contains sub.notes[holdEnd]:
                    continue
                break

            var hold = Note(time: uint8(offset + result.timings.find(noteType)), noteType: NoteType.Hold, animationStartIndex: uint8(noteIndex))
            result.notes[noteIndex] = hold
            if not holds.contains(noteIndex):
                holds[noteIndex] = newSeq[Note]()
            holds[noteIndex].add hold

        for noteIndex in noteIndices:
            let noteTiming = result.timings.find(sub.notes[noteIndex])

            if holds.contains(noteIndex) and holds[noteIndex].len > 0:
                for hold in holds[noteIndex]:
                    discard
                    # TODO: Find out how to fix this
                    #when hold.noteType == NoteType.Hold:
                    #    hold.releaseSection = index
                    #    hold.releaseTime = offset + noteIndex
                holds.del noteIndex
            else:
                result.notes[noteIndex] = Note(noteType: NoteType.Note, time: uint8(offset + noteTiming))

        # Increment the offset for the next sub-section
        inc offset, sub.timings.len

func parseSubSection(rows: array[4, string]): SubSection =
    result.snaps = newSeq[Snap]()
    result.timings = newSeq[Token]()
    result.notes = initTable[NoteRange, Token]()

    var rowIndex = 0
    for line in rows:
        let noteData = line.runeSubStr(0, 3).strip(runes = NonTokenChars)
        var noteIndex = 0
        for note in utf8(noteData):
            var parsed: Token = EmptyNote;

            try:
                parsed = parseEnum[Token](note)
            except ValueError:
                discard
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
                    except ValueError:
                        discard
                    except:
                        log fmt"Could not parse timing token from '{str}'!"
                        raise

                    result.timings.add parsed

                result.snaps.add Snap(len: uint8(timingData.runeLen), row: uint8(rowIndex))
            except:
                {.cast(noSideEffect).}:
                    raise newException(ParseError, fmt"Could not parse timing-data from line: '{rows[rowIndex]}'! " & getCurrentExceptionMsg())

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
