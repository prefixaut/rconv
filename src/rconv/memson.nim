import std/[parseutils, sequtils, sugar, strformat, strutils, tables]
import std/nre except toSeq
import pkg/[unpack]

{.experimental: "codeReordering".}

type
    ParseError* = object of CatchableError

    TokenType {.pure.} = enum
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
        Right       = "＞"

    Difficulty {.pure.} = enum
        Basic       = "basic",
        Advanced    = "advanced",
        Extreme     = "extreme"
    
    NoteType {.pure.} = enum
        Note,
        Hold

    NotePosition = range[1..16]

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
        timings: seq[TokenType]
        snaps: seq[Snap]
        notes: Table[NotePosition, TokenType]

    Memson* = object
        songTitle: string
        artist: string
        difficulty: Difficulty
        level: uint8
        bpm: float
        bpmRange: tuple[min: float, max: float]
        sections: seq[Section]

proc parseToMemson*(content: string): Memson {.raises: [ParseError, ValueError] } =
    var data: seq[string]
    var sectionIndex: uint = 0
    var minBpm: float = -1
    var maxBpm: float = -1
    var bpm : float = -1
    var holds = initTable[NotePosition, Note]()
    var subSections = newSeq[SubSection]()

    try:
        let metaSplit = content.strip().split(re"(\r?\n){2}", 3)
        let songSplit = metaSplit[0].splitLines()
        echo(metaSplit)
        result.songTitle = songSplit[0]
        result.artist = songSplit[1].strip()
        result.difficulty = parseDifficulty(metaSplit[1].strip())
        result.sections = newSeq[Section]()
        data = metaSplit[2].splitLines()
    except:
        raise newException(ParseError, fmt"Could not parse memo header!: " & getCurrentExceptionMsg())

    var rowIndex = 0
    while rowIndex < data.len:
        var row = data[rowIndex].strip()
        rowIndex += 1

        if row.isEmptyOrWhitespace():
            continue

        if row.startsWith("level"):
            try:
                result.level = uint8(parseUInt(row.substr(6).strip()))
                continue
            except ValueError:
                raise newException(ParseError, fmt"Could not parse Level '{row}'!: " & getCurrentExceptionMsg())

        if row.startsWith("bpm"):
            try:
                bpm = parseFloat(row.substr(4).strip())
                minBpm = if (minBpm == -1): bpm else: min(bpm, minBpm)
                maxBpm = if (maxBpm == -1): bpm else: max(bpm, maxBpm)

                if (sectionIndex == 0):
                    result.bpm = bpm
                continue
            except ValueError:
                raise newException(ParseError, fmt"Could not parse BPM '{row}'!: " & getCurrentExceptionMsg())
        
        try:
            let tmpIndex = parseUInt(row.strip())
            if tmpIndex > 1:
                finishSection(sectionIndex, bpm, holds, result.sections, subSections)
                # Clear the sub-sections
                subSections = newSeq[SubSection]()
            # Update the section to the next one
            sectionIndex = tmpIndex
            continue
        except:
            discard

        subSections.add(parseSubSection(holds, [row, data[rowIndex + 1], data[rowIndex + 2], data[rowIndex + 3]]))
        rowIndex += 3
    
    finishSection(sectionIndex, bpm, holds, result.sections, subSections)

proc finishSection(index: uint, bpm: float, holds: Table[NotePosition, Note], sections: var seq[Section], subSections: seq[SubSection]): void =
    if subSections.len < 1:
        return

    sections.add parseSection(index, bpm, holds, sections, subSections)

func parseSection(index: uint, bpm: float, holds: Table[NotePosition, Note], sections: var seq[Section], subSections: seq[SubSection]): Section =
    result.index = index
    result.bpm = bpm
    # TODO: Implementation

func parseSubSection(holds: Table[NotePosition, Note], rows: array[4, string]): SubSection =
    result.snaps = newSeq[Snap]()
    result.timings = newSeq[TokenType]()
    result.notes = initTable[NotePosition, TokenType]()

    for rowIndex in 0..rows.len:
        let noteData = rows[rowIndex].substr(0, 4)
        for noteIndex in 0..noteData.len:
            try:
                result.notes[(rowIndex * 4) + noteIndex] = parseEnum[TokenType]($noteData[noteIndex])
            except:
                discard
        
        if noteData.len > 4:
            let timingData = rows[rowIndex].substr(4).strip(chars = Whitespace + {'|'})
            let timings = @timingData.map(str => parseEnum[TokenType]($str))
            result.timings &= timings
            result.snaps.add Snap(length: uint8(timings.len), row: uint8(rowIndex))

func parseDifficulty(diff: string): Difficulty {.raises: [ParseError, ValueError] } =
    try:
        return parseEnum[Difficulty](diff.toLowerAscii())
    except ValueError:
        raise newException(ParseError, fmt"Could not parse Difficulty '{diff}'!")
