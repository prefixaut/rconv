import std/[sequtils, streams, strformat, sugar, tables, unicode]
import std/strutils except split, strip

import ./private/line_reader
import ./common
import ./memson

{.experimental: "codeReordering".}

type
    Token {.pure.} = enum
        # Notes
        Pos1        = "①",
        Pos1_FW     = "１",
        Pos2        = "②",
        Pos2_FW     = "２",
        Pos3        = "③",
        Pos3_FW     = "３",
        Pos4        = "④",
        Pos4_FW     = "４",
        Pos5        = "⑤",
        Pos5_FW     = "５",
        Pos6        = "⑥",
        Pos6_FW     = "６",
        Pos7        = "⑦",
        Pos7_FW     = "７",
        Pos8        = "⑧",
        Pos8_FW     = "８",
        Pos9        = "⑨",
        Pos9_FW     = "９",
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

        # Extended positions which aren't standard and used infrequently
        Pos21       = "Ⓐ",
        Pos21_FW    = "Ａ",
        Pos22       = "Ⓑ",
        Pos22_FW    = "Ｂ",
        Pos23       = "Ⓒ",
        Pos23_FW    = "Ｃ",
        Pos24       = "Ⓓ",
        Pos24_FW    = "Ｄ",
        Pos25       = "Ⓔ",
        Pos25_FW    = "Ｅ",
        Pos26       = "Ⓕ",
        Pos26_FW    = "Ｆ",
        Pos27       = "Ⓖ",
        Pos27_FW    = "Ｇ",
        Pos28       = "Ⓗ",
        Pos28_FW    = "Ｈ",
        Pos29       = "Ⓘ",
        Pos29_FW    = "Ｉ",
        Pos30       = "Ⓙ",
        Pos30_FW    = "Ｊ",
        Pos31       = "Ⓚ",
        Pos31_FW    = "Ｋ",
        Pos32       = "Ⓛ",
        Pos32_FW    = "Ｌ",
        Pos33       = "Ⓜ",
        Pos33_FW    = "Ｍ",
        Pos34       = "Ⓝ",
        Pos34_FW    = "Ｎ",
        Pos35       = "Ⓞ",
        Pos35_FW    = "Ｏ",
        Pos36       = "Ⓟ",
        Pos36_FW    = "Ｐ",
        Pos37       = "Ⓠ",
        Pos37_FW     = "Ｑ",
        Pos38       = "Ⓡ",
        Pos38_FW    = "Ｒ",
        Pos39       = "Ⓢ",
        Pos39_FW    = "Ｓ",
        Pos40       = "Ⓣ",
        Pos40_FW    = "Ｔ",
        Pos41       = "Ⓤ",
        Pos41_FW    = "Ｕ",
        Pos42       = "Ⓥ",
        # Pos42_V     = "Ｖ", Is actually already used as "Down", cuz of course it is
        Pos43       = "Ⓦ",
        Pos43_FW    = "Ｗ",
        Pos44       = "Ⓧ",
        Pos44_FW    = "Ｘ",
        Pos45       = "Ⓨ",
        Pos45_FW    = "Ｙ",
        Pos46       = "Ⓩ",
        Pos46_FW    = "Ｚ",

        # Hold Indicators
        Vertical    = "｜",
        Horizontal  = "―",
        Up          = "∧",
        Down        = "Ｖ",
        Down2       = "∨",
        Left        = "＜"
        Right       = "＞",

        # Empty tokens
        Empty   = "-"

        # Other Tokens
        Separator   = "|"

    SectionPart = object
        timings: seq[Token]
        snaps: seq[Snap]
        notes: Table[NoteRange, Token]

    RowResult = object
        position: int
        tokens: seq[Token]

const
    AllTokens = Token.toSeq.map(t => $t)
    TokenMap: array[Token, int] = [
        1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,11,12,13,14,15,16,17,18,19,20,
        21,21,22,22,23,23,24,24,25,25,26,26,27,27,28,28,29,29,
        30,30,31,31,32,32,33,33,34,34,35,35,36,36,37,37,38,38,39,39,
        40,40,41,41,42,43,43,44,44,45,45,46,46,
        -1,-1,-1,42,-1,-1,-1,-1,-1
    ]
    InverseTokenMap: Table[int, Token] = [
        (21, Token.Pos21), (22, Token.Pos22), (23, Token.Pos23), (24, Token.Pos24), (25, Token.Pos25),
        (26, Token.Pos26), (27, Token.Pos27), (28, Token.Pos28), (29, Token.Pos29), (30, Token.Pos30),
        (31, Token.Pos31), (32, Token.Pos32), (33, Token.Pos33), (34, Token.Pos34), (35, Token.Pos35),
        (36, Token.Pos36), (37, Token.Pos37), (38, Token.Pos38), (39, Token.Pos39), (40, Token.Pos40),
        (41, Token.Pos41), (42, Token.Pos42), (43, Token.Pos43), (44, Token.Pos44), (45, Token.Pos45),
        (46, Token.Pos46)
    ].toTable
    FillerNotes = { Token.Vertical, Token.Horizontal, Token.Empty, Token.Empty}
    HoldStart = { Token.Up, Token.Down, Token.Down2, Token.Left, Token.Right }
    NotePosition = 0..15.NoteRange
    NonTokenChars = toRunes($(Whitespace + {'|'}))

proc parseMemo*(content: string): Memson =
    ## Parses the provided memo-data to a memson object (memo object representation).
    ## The content has to be a complete memo file to be parsed correctly.

    result = Memson()
    let reader = newLineReader(content)
    var sectionIndex: int = -1
    var minBpm: float = -1
    var maxBpm: float = -1
    var bpm : float = -1
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
            if parts.len > 0:
                result.sections.add parseSection(sectionIndex, partIndex, bpm, parts)
                parts = @[]
                partIndex = 0
            try:
                result.level = parseInt(row.runeSubStr(6).strip)
                continue
            except ValueError:
                {.cast(noSideEffect).}:
                    raise newException(ParseError, fmt"Could not parse Level '{row}' on line {reader.line}!: " & getCurrentExceptionMsg())

        if row.toLower.startsWith("bpm"):
            if parts.len > 0:
                result.sections.add parseSection(sectionIndex, partIndex, bpm, parts)
                parts = @[]
                partIndex = 0
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
                    result.sections.add parseSection(sectionIndex, partIndex, bpm, parts)

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
        result.sections.add parseSection(sectionIndex, partIndex, bpm, parts)
        partIndex = 0
        inc sectionIndex

    if minBpm != maxBpm:
        result.bpmRange = (min: minBpm, max: maxBpm)

proc write*(chart: Memson): string =
    # TODO: Implement
    result = ""

proc write*(chart: Memson, stream: Stream): void =
    stream.write(chart.write)

proc parseSection(index: int, partIndex: int, bpm: float, parts: seq[SectionPart]): Section =
    result = newSection(
        index = index,
        bpm = bpm,
        partCount = partIndex,
    )

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
        var holdIndices = newSeq[int]()

        # Iterate once over all elements to handle Holds directly,
        # and push regular notes into "noteIndices" for futher processing.
        for noteIndex in NotePosition:
            let noteType = if singlePart.notes.contains(noteIndex): singlePart.notes[noteIndex] else: Token.Empty

            # Skip empty/invalid notes
            if FillerNotes.contains(noteType):
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

            holdIndices.add holdEnd
            let noteTiming = result.timings.find(TokenMap[singlePart.notes[holdEnd]])
            if not result.notes.hasKey(holdEnd):
                result.notes[holdEnd] = @[]

            result.notes[holdEnd].add newHold(
                time = noteTiming,
                partIndex = partIndex,
                animationStartIndex = noteIndex,
                releaseTime = -1
            )
            inc result.noteCount

        # Remove all indices which are actually holds!
        # Otherwise we get double notes and holds don't end properly
        noteIndices.keepIf (idx) => not holdIndices.contains(idx)

        # Handle regular notes/hold endings
        for noteIndex in noteIndices:
            let noteType = singlePart.notes[noteIndex]
            let noteTiming = result.timings.find(TokenMap[noteType])

            if not result.notes.hasKey(noteIndex):
                result.notes[noteIndex] = @[]

            var releasedHold = false
            for tmp in result.notes[noteIndex].mitems:
                if tmp.kind == NoteType.Hold and tmp.releaseTime == -1:
                    tmp.releaseTime = noteTiming
                    tmp.releasePart = partIndex
                    tmp.releaseSection = index
                    releasedHold = true
                    break

            if not releasedHold:
                result.notes[noteIndex].add newNote(time = noteTiming, partIndex = partIndex)
                inc result.noteCount

    # Sort the notes by the index
    result.notes.sort((a, b) => system.cmp(a[0], b[0]))

proc parseSectionParts(index: int, lineIndex: int, rows: array[4, string]): SectionPart =
    result = SectionPart()
    result.snaps = @[]
    result.timings = @[]
    result.notes = initTable[NoteRange, Token]()

    var rowIndex = 0
    for line in rows:
        if line.isEmptyOrWhitespace():
            return

        let notes = parseTokens(line, lineIndex + rowIndex, 4)
        let ticks = parseTokens(line.runeSubStr(notes.position), lineIndex + rowIndex, -1, notes.position)

        for noteIndex, note in notes.tokens.pairs:
            result.notes[(rowIndex * 4) + noteIndex] = note

        if ticks.tokens.len > 0:
            for timing in ticks.tokens:
                result.timings.add timing
            result.snaps.add newSnap(length = ticks.tokens.len, row = rowIndex, partIndex = index)
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

proc parseTokens(row: string, rowNum: int, maxLen: int = -1, offset = 0): RowResult =
    result.tokens = @[]
    result.position = 0

    var size = 0
    var buffered = ""

    for note in utf8(row):
        inc result.position
        var parsed: Token = Token.Empty;

        if note.isEmptyOrWhitespace:
            if not buffered.isEmptyOrWhitespace:
                try:
                    let tmp = parseInt(buffered)
                    if InverseTokenMap.hasKey tmp:
                        parsed = InverseTokenMap[tmp]
                        buffered = ""
                    else:
                        continue
                except ValueError:
                    buffered = ""
                    continue
            continue

        try:
            if note[0].isDigit:
                buffered &= note
                continue
            parsed = parseEnum[Token](note)
            if TokenMap[parsed] == -1:
                if parsed == Token.Separator:
                    break

        #except ValueError:
        #    discard
        except:
            discard
            # raise newException(ParseError, fmt"Could not parse token '{note}' on pos {offset + result.position} from line {rowNum} '{row}'!")

        result.tokens.add parsed
        inc size
        if maxLen > -1 and size > maxLen:
            break
