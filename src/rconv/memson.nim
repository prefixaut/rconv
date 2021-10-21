import std/[sequtils, sugar, strformat, tables, unicode]
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
        Down        = "∨",
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

    NotePosition = range[0..15]

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
        timings: seq[uint8]
        snaps: seq[uint8]
        originalSnaps: seq[uint8]
        notes: Table[NotePosition, Note]

    Snap = object
        length: uint8
        row: uint8

    SubSection = object
        timings: seq[Token]
        snaps: seq[Snap]
        notes: Table[NotePosition, Token]

    Memson* = object
        songTitle: string
        artist: string
        difficulty: Difficulty
        level: uint8
        bpm: float
        bpmRange: tuple[min: float, max: float]
        sections: seq[Section]

const
    NonTokenChars = toRunes($(Whitespace + {'|'}))

func parseToMemson*(content: string): Memson {.raises: [ParseError, ValueError] .} =
    let reader = newLineReader(content)
    var sectionIndex: uint = 0
    var minBpm: float = -1
    var maxBpm: float = -1
    var bpm : float = -1
    var holds = initTable[NotePosition, Note]()
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
                # Clear the sub-sections
                subSections = newSeq[SubSection]()
            # Update the section to the next one
            sectionIndex = tmpIndex
            continue
        except:
            discard

        log "new subsection: " & $reader.line
        subSections.add parseSubSection([row, reader.nextLine(), reader.nextLine(), reader.nextLine()])

    # Build the section from the sub-sections if any exist
    if subSections.len > 0:
        result.sections.add parseSection(sectionIndex, bpm, holds, subSections)

proc parseSection(index: uint, bpm: float, holds: Table[NotePosition, Note], subSections: seq[SubSection]): Section =
    result.index = index
    result.bpm = bpm
    # TODO: Implementation

func parseSubSection(rows: array[4, string]): SubSection =
    result.snaps = newSeq[Snap]()
    result.timings = newSeq[Token]()
    result.notes = initTable[NotePosition, Token]()

    var rowIndex = 0
    for line in rows:
        log line
        let noteData = line.runeSubStr(0, 3).strip(runes = NonTokenChars)
        var noteIndex = 0
        for note in utf8(noteData):
            try:
                result.notes[(rowIndex * 4) + noteIndex] = parseEnum[Token](note)
                inc noteIndex
            except:
                raise newException(ParseError, fmt"Could not parse note-data from line: '{noteData.runeAt(noteIndex)}'!")

        if line.runeLen > 4:
            try:
                let timingData = line.runeSubStr(4).strip(runes = NonTokenChars)
                for str in utf8(timingData):
                    try:
                        result.timings.add parseEnum[Token]($str)
                    except:
                        log fmt"Could not parse timing token from '{str}'!"
                        raise

                result.snaps.add Snap(length: uint8(timingData.runeLen), row: uint8(rowIndex))
            except:
                {.cast(noSideEffect).}:
                    raise newException(ParseError, fmt"Could not parse timing-data from line: '{rows[rowIndex]}'! " & getCurrentExceptionMsg())

func parseDifficulty(diff: string): Difficulty {.raises: [ParseError, ValueError] .} =
    try:
        return parseEnum[Difficulty](diff.toLower())
    except ValueError:
        raise newException(ParseError, fmt"Could not parse Difficulty '{diff}'!")
