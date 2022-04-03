import std/[algorithm, sequtils, streams, strformat, sugar, tables, unicode]
import std/strutils except split, strip

import ./private/[line_reader, memo_common]
import ./common

export memo_common

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
    EmptyNote = "口"
    ReplaceableNotes = @[EmptyNote, $Token.Vertical, $Token.Horizontal]
    ReplaceableVertical = @[EmptyNote, $Token.Horizontal]
    ReplaceableHorizontal = @[EmptyNote, $Token.Vertical]
    HoldStarts = @[$Token.Up, $Token.Down, $Token.Left, $Token.Right]
    TokenMap: array[Token, int] = [
        1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,11,12,13,14,15,16,17,18,19,20,
        21,21,22,22,23,23,24,24,25,25,26,26,27,27,28,28,29,29,
        30,30,31,31,32,32,33,33,34,34,35,35,36,36,37,37,38,38,39,39,
        40,40,41,41,42,43,43,44,44,45,45,46,46,
        -1,-1,-1,42,-1,-1,-1,-1,-1
    ]
    InverseTokenMap: Table[int, Token] = [
        (-1, Token.Empty), (0, Token.Empty),
        (1, Token.Pos1), (2, Token.Pos2), (3, Token.Pos3), (4, Token.Pos4), (5, Token.Pos5),
        (6, Token.Pos6), (7, Token.Pos7), (8, Token.Pos8), (9, Token.Pos9), (10, Token.Pos10),
        (11, Token.Pos11), (12, Token.Pos12), (13, Token.Pos13), (14, Token.Pos14), (15, Token.Pos15),
        (16, Token.Pos16), (17, Token.Pos17), (18, Token.Pos18), (19, Token.Pos19), (20, Token.Pos20),
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

func parseTokens(row: string, rowNum: int, maxLen: int = -1, offset = 0): RowResult =
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

func parseSectionParts(index: int, lineIndex: int, rows: array[4, string]): SectionPart =
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

func parseSection(index: int, partIndex: int, bpm: float, parts: seq[SectionPart]): Section =
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

func parseMemo*(content: string): Memo =
    ## Parses the provided memo-data to a memo object (memo object representation).
    ## The content has to be a complete memo file to be parsed correctly.

    result = Memo() # newMemo doesn't work here because ... ?
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
            raise newException(ParseError, "Could not parse memo header!: " & getCurrentExceptionMsg())

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

proc writePart(printTable: Table[NoteRange, string], timingOffset: var int, section: Section, partIndex: int): string =
    result = ""
    var rowIndex = 0

    for noteIndex in 0..15:
        result &= printTable.getOrDefault(noteIndex, EmptyNote)

        if (noteIndex + 1) mod 4 == 0:
            for snapIndex, snap in section.snaps.pairs:
                if snapIndex == rowIndex and snap.partIndex == partIndex:
                    result &= " " & $Token.Separator
                    for time in timingOffset..<(timingOffset + snap.length):
                        let key = section.timings[time]
                        if InverseTokenMap.hasKey key:
                            result &= $InverseTokenMap[key]
                        else:
                            result &= $Token.Empty
                    result &= $Token.Separator
                    inc timingOffset, snap.length
                    break
            result &= "\n"
            inc rowIndex

proc write*(chart: Memo): string =
    var parts = @[
        @[chart.songTitle, chart.artist].join("\n"),
        $($chart.difficulty).toUpper
    ]
    var meta: seq[string] = @[]
    var noteCount = 0
    var holdTable = initTable[int, seq[tuple[pos: int, note: Note]]]()
    var currentBpm = 0.0

    if chart.level >= 0:
        meta.add "Level: " & $chart.level
    if chart.bpmRange.min != chart.bpmRange.max:
        meta.add "BPM: " & $chart.bpmRange.min & "-" & $chart.bpmRange.max
    elif chart.bpm > 0:
        meta.add "BPM: " & $chart.bpm
        currentBpm = chart.bpm

    parts.add meta.join("\n")

    for section in chart.sections:
        var sectionParts: seq[string] = @[]
        var notes = newSeq[tuple[pos: int, note: Note]]()
        var notesFeedback = newSeq[tuple[pos: int, note: Note]]()
        var printTable = initTable[NoteRange, string]()

        var timingOffset = 0
        var partIndex = 0

        for noteIndex in 0..15:
            for note in section.notes.getOrDefault(noteIndex, @[]):
                notes.add (noteIndex, note)
                if note.kind == NoteType.Hold:
                    let tmp = newNote(note.releaseTime, note.releasePart)
                    if note.releaseSection == section.index:
                        notes.add (noteIndex, tmp)
                    else:
                        holdTable.mgetOrPut(note.releaseSection, @[]).add (noteIndex, tmp)

        if holdTable.hasKey section.index:
            for note in holdTable[section.index]:
                notes.add note

        notes.sort ((a: tuple[pos: int, note: Note], b: tuple[pos: int, note: Note]) => a.note.time - b.note.time)

        while notes.len > 0:
            for elem in notes:
                let noteIndex = elem.pos
                let note = elem.note
                var uncommited = newSeq[tuple[pos: int, data: string]]()
                var isObstructed = printTable.hasKey noteIndex

                if note.kind == NoteType.Hold:
                    uncommited.add (noteIndex, $InverseTokenMap[section.timings[note.time]])
                    isObstructed = isObstructed or printTable.hasKey noteIndex
                    let diff = note.animationStartIndex - noteIndex
                    var fillerPositions = newSeq[int]()
                    var fillerReplace = ReplaceableHorizontal
                    var fillerNote = $Token.Horizontal

                    if diff >= -3 and diff <= -1:
                        uncommited.add (note.animationStartIndex, $Token.Right)
                        if printTable.hasKey note.animationStartIndex:
                            isObstructed = isObstructed or not ReplaceableNotes.contains printTable[note.animationStartIndex]

                        for filler in (diff + 1)..<0:
                            fillerPositions.add noteIndex + filler

                    elif diff == -4 or diff == -8 or diff == -12:
                        uncommited.add (note.animationStartIndex, $Token.Down)
                        if printTable.hasKey note.animationStartIndex:
                            isObstructed = isObstructed or not ReplaceableNotes.contains printTable[note.animationStartIndex]

                        fillerReplace = ReplaceableVertical
                        fillerNote = $Token.Vertical
                        for filler in 1..<((diff * -1) div 4):
                            fillerPositions.add noteIndex + (filler * -4)

                    elif diff >= 1 and diff <= 3:
                        uncommited.add (note.animationStartIndex, $Token.Left)
                        if printTable.hasKey note.animationStartIndex:
                            isObstructed = isObstructed or not ReplaceableNotes.contains printTable[note.animationStartIndex]

                        for filler in 1..<diff:
                            fillerPositions.add noteIndex + filler

                    elif diff == 4 or diff == 8 or diff == 12:
                        uncommited.add (note.animationStartIndex, $Token.Up)
                        if printTable.hasKey note.animationStartIndex:
                            isObstructed = isObstructed or not ReplaceableNotes.contains printTable[note.animationStartIndex]

                        fillerReplace = ReplaceableVertical
                        fillerNote = $Token.Vertical
                        for filler in 0..(diff div 4):
                            fillerPositions.add noteIndex + ((filler + 1) * 4)

                    for fillerIdx in fillerPositions:
                        let blocked = printTable.hasKey(fillerIdx)
                        if blocked and fillerReplace.contains printTable[fillerIdx]:
                            uncommited.add (fillerIdx, EmptyNote)
                        elif not blocked or not HoldStarts.contains printTable[fillerIdx]:
                            isObstructed = isObstructed or blocked
                            uncommited.add (fillerIdx, fillerNote)
                else:
                    uncommited.add (noteIndex, $InverseTokenMap[section.timings[note.time]])

                # If the content is blocked, add it to the feedback list, so it can be applied in the next part
                if isObstructed:
                    notesFeedback.add elem
                    continue

                inc noteCount
                for val in uncommited:
                    printTable[val.pos] = val.data 
            #/notes

            if partIndex == 0 or printTable.len > 0:
                sectionParts.add writePart(printTable, timingOffset, section, partIndex).strip
            inc partIndex
            printTable.clear

            notes = notesFeedback
            notesFeedback = @[]
        #/while

        if partIndex == 0 or printTable.len > 0:
            sectionParts.add writePart(printTable, timingOffset, section, partIndex).strip
        var sectionData = ""
        if section.bpm != currentBpm:
            sectionData = "BPM: " & $section.bpm & "\n"
            currentBpm = section.bpm
        sectionData &= $section.index & "\n"
        parts.add sectionData & sectionParts.join("\n\n")
    #/section

    result = parts.join("\n\n")

proc write*(chart: Memo, stream: Stream): void =
    stream.write(chart.write)
