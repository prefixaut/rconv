import std/[algorithm, math, sets, strutils, strformat, tables]

import pkg/[bignum, regex]

import ./common
import ./private/utils

import ./fxf as fxf
import ./malody as malody
import ./memo as memo
import ./step_mania as sm

type
    FXFHoldRelease = tuple[fxf: fxf.Hold, memo: memo.Note] ## \
    ## Tuple to join a fxf and memo hold, to be able to set the
    ## `releaseOn` field of the fxf hold on time.
    MalodyHoldRelease = tuple[memo: memo.Note, malody: malody.TimedElement] ## \
    ## Tuple to join a memo-hold and malody-hold, to be able to set the
    ## `endBeat` field on the malody hold on time.

const
    LevelRegex = re"(?:(?:[lL][vV])|(?:[lL][vV][lL])|(?:[lL][eE][vV][eE][lL]))?\s*\.*\s*([0-9]+[\.]?[0-9])"

proc getBeat(value: Rat): malody.Beat =
    ## Helper function to convert a fraction beat-index (1.5, 2.3, ...) to a
    ## indicative beat & snap position.
    ## Currently supports from 1 to 20th snaps
    let beat = value.num.toInt
    var beatDenom = value.denom.toInt
    while beatDenom > 10_000:
        beatDenom = int(beatDenom / 10_000)
    # TODO: Replace with a simple loop instead of this mess

    # Additional values are for rounding errors/IEEE float handling
    case beatDenom:
    of 9990, 9989:
        result = [beat, 3, 3]
    of 9500, 9499:
        result = [beat, 19, 20]
    of 9375:
        result = [beat, 15, 16]
    of 9166:
        result = [beat, 11, 12]
    of 9000:
        result = [beat, 18, 20]
    of 8750:
        result = [beat, 7, 8]
    of 8500:
        result = [beat, 17, 20]
    of 8333, 8332:
        result = [beat, 5, 6]
    of 8125:
        result = [beat, 13, 16]
    of 8000, 7999:
        result = [beat, 16, 20]
    of 7500, 7499:
        result = [beat, 3, 4]
    of 7000, 6999:
        result = [beat, 14, 20]
    of 6875:
        result = [beat, 11, 16]
    of 6666, 6659:
        result = [beat, 2, 3]
    of 6500:
        result = [beat, 13, 20]
    of 6250:
        result = [beat, 5, 8]
    of 6000:
        result = [beat, 12, 20]
    of 5833, 5832:
        result = [beat, 7, 12]
    of 5625:
        result = [beat, 9, 16]
    of 5500:
        result = [beat, 11, 20]
    of 5000:
        result = [beat, 1, 2]
    of 4500:
        result = [beat, 9, 20]
    of 4375:
        result = [beat, 7, 16]
    of 4166:
        result = [beat, 5, 12]
    of 4000:
        result = [beat, 8, 20]
    of 3750:
        result = [beat, 6, 16]
    of 3500:
        result = [beat, 7, 20]
    of 3333, 3329:
        result = [beat, 1, 3]
    of 3125:
        result = [beat, 5, 16]
    of 3000, 2999:
        result = [beat, 6, 20]
    of 2500:
        result = [beat, 1, 4]
    of 2000:
        result = [beat, 4, 20]
    of 1875:
        result = [beat, 3, 16]
    of 1666, 1659:
        result = [beat, 1, 6]
    of 1500:
        result = [beat, 3, 20]
    of 1250:
        result = [beat, 1, 8]
    of 1000:
        result = [beat, 2, 20]
    of 833, 832:
        result = [beat, 1, 12]
    of 625:
        result = [beat, 1, 16]
    of 500:
        result = [beat, 1, 20]
    of 0:
        result = [beat, 0, 2]
    else:
        result = [beat, 0, 1]
#[
------------------------------------------
    MEMO CONVERTS
------------------------------------------
]#

func toFXF*(this: memo.Memo): fxf.ChartFile {.cdecl, exportc: "rconv_memo_toFXF", dynlib.} =
    ## Function to map/convert `this` Chart to a FXF-ChartFile.

    result = fxf.newChartFile(
        artist = this.artist,
        title = this.songTitle,
        jacket = "jacket.png",
        audio = "audio.mp3"
    )
    var chart: fxf.Chart = fxf.newChart(rating = uint32(this.level) * 10)

    var bpm: float32
    var globalTime: float = 0
    var holdRelease = newSeq[FXFHoldRelease]()

    for section in this.sections:
        if (bpm != section.bpm):
            bpm = section.bpm
            var change = fxf.newBpmChange(
                bpm = bpm,
                time = float32(round(globalTime * 10) / 10),
                snapSize = uint16(section.snaps[0].length),
                snapIndex = uint16(0)
            )
            result.bpmChange.add change
            inc result.numBpm

        let beat = OneMinute / bpm
        var indexOffset = 0

        for snap in section.snaps:
            let snapTime = beat / float(snap.length)

            for snapIndex in 0..<snap.length:
                let timing = indexOffset + snapIndex
                let noteTime = round(globalTime * 10) / 10

                # Update the global-time after the current time has been loaded
                globalTime = globalTime + snapTime

                # Handle previously saved holds.
                # if a hold has to end now, then we give it the proper releaseTime
                # and remove it from the seq
                var tmpHoldRelease = newSeq[FXFHoldRelease]()
                for r in holdRelease.mitems:
                    if r.memo.releaseSection == section.index and r.memo.releaseTime == timing:
                        r.fxf.releaseOn = noteTime
                    else:
                        tmpHoldRelease.add r
                holdRelease = tmpHoldRelease

                var tick = fxf.newTick(
                    time = noteTime,
                    snapSize = uint16(snap.length),
                    snapIndex = uint16(snapIndex)
                )
                var hasData = false

                for noteIndex, multiNotes in section.notes.pairs:
                    for note in multiNotes:
                        if note.time != timing:
                            continue

                        hasData = true
                        if note.kind == memo.NoteType.Hold:
                            var hold = fxf.newHold(`from` = note.animationStartIndex, to = noteIndex)
                            tick.holds.add hold
                            holdRelease.add (hold, note)
                            inc tick.numHolds
                        else:
                            tick.notes.add uint8(noteIndex)
                            inc tick.numNotes

                if hasData:
                    chart.ticks.add tick
                    inc chart.numTick

            inc indexOffset, snap.length

    if this.difficulty == memo.Difficulty.Basic:
        result.charts.basic = chart
        result.charts.bscPresent = 1
    elif this.difficulty == memo.Difficulty.Advanced:
        result.charts.advanced = chart
        result.charts.advPresent = 1
    else:
        result.charts.extreme = chart
        result.charts.extPresent = 1

func toMalody*(this: memo.Memo): malody.Chart {.cdecl, exportc: "rconv_memo_toMalody", dynlib.} =
    ## Function to map/convert `this` Chart to a Malody Chart.

    result = malody.newChart(meta = malody.newMetaData(
        song = malody.newSongData(
            artist = this.artist,
            title = this.songTitle
        ),
        mode = malody.ChartMode.Pad,
        version = $this.difficulty
    ))

    var bpm: float32
    var sectionIndex = 1
    var beatIndex = 0
    var snapPos = 1
    var snapSize = 1
    var snapIndex = 0
    var holdRelease = newSeq[MalodyHoldRelease]()

    for section in this.sections:
        snapPos = 1
        snapIndex = 0

        if section.snaps.len > 0:
            snapSize = section.snaps[0].length
        else:
            snapSize = 0

        if section.bpm != bpm:
            bpm = section.bpm
            result.time.add malody.newTimeSignature(beat = [beatIndex, snapIndex, snapSize], bpm = bpm)

        var timeIndex = 0

        for time in section.timings:
            let beat = [beatIndex, snapIndex, snapSize]

            # Temporary seq, as we can't delete the holdIndex from the holdRelease
            # since we're already iterating over it
            var releasesToDelete = newSeq[int]()
            for holdIndex, holdVal in holdRelease.mpairs:
                if holdVal.memo.releaseSection == sectionIndex and holdVal.memo.releaseTime == timeIndex:
                    holdVal.malody.indexEndBeat = beat
                    releasesToDelete.add holdIndex
                    break
            for idx in releasesToDelete:
                holdRelease.del idx

            if time > -1:
                for secNotePos, secMultiNotes in section.notes:
                    for secNote in secMultiNotes:
                        if secNote.time == timeIndex:
                            if secNote.kind == memo.NoteType.Hold:
                                let hold = malody.newIndexHold(beat = beat, index = secNotePos, endIndex = secNote.animationStartIndex)
                                result.note.add hold
                                holdRelease.add (memo: secNote, malody: hold)
                            else:
                                result.note.add malody.newIndexNote(beat = beat, index = secNotePos)

            inc snapIndex
            if snapIndex >= snapSize:
                snapIndex = 0
                if section.snaps.len > snapPos:
                    snapSize = section.snaps[snapPos].length
                else:
                    snapSize = 0
                inc snapPos
                inc beatIndex
            inc timeIndex

        inc sectionIndex

#[
------------------------------------------
    MALODY CONVERTS
------------------------------------------
]#

proc toMemo*(this: malody.Chart): memo.Memo {.cdecl, exportc: "rconv_malody_toMemo", dynlib.} =
    if (this.meta.mode != ChartMode.Pad):
        raise newException(InvalidModeException, fmt"The provided Malody-Chart is from the wrong Mode! Mode is {this.meta.mode}, where a {ChartMode.Pad} is required!")

    result = memo.newMemo(
        songTitle = this.meta.song.title,
        artist = this.meta.song.artist,
    )
    var minBpm = 0.0
    var maxBpm = 0.0
    var bpmSet = false
    var currentBpm = 0.0
    var currentBeat = -1
    var currentSection = -1
    var timingOffset = 0
    var totalBeats = 0
    var sections = initTable[int, memo.Section]()
    var bpmChanges = initTable[int, float]()
    var notes = initTable[int, seq[malody.TimedElement]]()
    var noteTimings = initTable[int, int]()
    var holdTable = initTable[int, seq[tuple[malody: malody.TimedElement, memo: memo.Note]]]()

    for elem in this.note:
        if elem.kind != malody.ElementType.IndexNote:
            continue
        totalBeats = max(totalBeats, elem.beat[0])
        notes.mgetOrPut(elem.beat[0], @[]).add elem

    for elem in this.time:
        if elem.kind != malody.ElementType.TimeSignature:
            continue

        if minBpm == 0.0:
            minBpm = elem.sigBpm
        else:
            minBpm = min(minBpm, elem.sigBpm)

        if maxBpm == 0.0:
            maxBpm = elem.sigBpm
        else:
            maxBpm = max(maxBpm, elem.sigBpm)

        if not bpmSet or currentBpm != elem.sigBpm:
            currentBpm = elem.sigBpm
            bpmSet = true

        let sectionIdx = int(elem.beat[0] / 4)
        bpmChanges[sectionIdx] = elem.sigBpm       

    currentBpm = bpmChanges.getOrDefault(0, 0.0)

    for beatIdx in 0..totalBeats:
        let sectionIdx = int(beatIdx / 4) + 1
        var section: memo.Section

        if sections.hasKey sectionIdx:
            section = sections[sectionIdx]
        else:
            if bpmChanges.hasKey(sectionIdx) and bpmChanges[sectionIdx] != currentBpm:
                currentBpm = bpmChanges[sectionIdx]
            section = memo.newSection(index = sectionIdx, bpm = currentBpm)
            sections[sectionIdx] = section
            result.sections.add section

        if currentSection != sectionIdx:
            timingOffset = 0
        currentSection = sectionIdx

        if not notes.hasKey beatIdx:
            section.snaps.add memo.newSnap(4)
            for i in 0..4:
                section.timings.add -1
            inc timingOffset, 4

        for elem in notes.getOrDefault(beatIdx, @[]):
            if currentBeat != elem.beat[0]:
                for i in 0..elem.beat[2]:
                    section.timings.add -1
                section.snaps.add memo.newSnap(elem.beat[2])
                inc timingOffset, elem.beat[2]

            let elemTime = timingOffset - elem.beat[2] + elem.beat[1]
            currentBeat = elem.beat[0]
            if section.timings[elemTime] == -1:
                section.timings[elemTime] = noteTimings.mgetOrPut(sectionIdx, 1)
                noteTimings[sectionIdx] = noteTimings[sectionIdx] + 1

            if elem.hold == malody.HoldType.IndexHold:
                var tmp = memo.newHold(
                    time = elemTime,
                    animationStartIndex = elem.indexEnd,
                    releaseSection = int(elem.indexEndBeat[0] / 4) + 1
                )
                section.notes.mgetOrPut(elem.index, @[]).add tmp
                if elem.beat[0] == elem.indexEndBeat[0]:
                    tmp.releaseTime = timingOffset - elem.indexEndBeat[2] + elem.indexEndBeat[1]
                else:
                    holdTable.mgetOrPut(elem.indexEndBeat[0], @[]).add (elem, tmp)
            else:
                section.notes.mgetOrPut(elem.index, @[]).add memo.newNote(
                    time = elemTime,
                )

        for pair in holdTable.getOrDefault(beatIdx, @[]):
            let elem = pair.malody
            let note = pair.memo
            let elemTime = timingOffset - elem.indexEndBeat[2] + elem.indexEndBeat[1]
            note.releaseTime = elemTime
            if section.timings[elemTime] == -1:
                section.timings[elemTime] = noteTimings.mgetOrPut(sectionIdx, 1)
                noteTimings[sectionIdx] = noteTimings[sectionIdx] + 1
        holdTable.del beatIdx

    result.bpm = maxBpm
    result.bpmRange = (minBpm, maxBpm)

func toFXF*(this: malody.Chart): fxf.ChartFile {.cdecl, exportc: "rconv_malody_toFXF", dynlib.} =
    ## Function to map/convert `this` Chart to a FXF-ChartFile.
    ## The actual note-data will be present in the `fxf.ChartFile.charts`_ table.
    ## The difficulty is determined by the `memo.parseDifficulty`_ function.

    if (this.meta.mode != ChartMode.Pad):
        raise newException(InvalidModeException, fmt"The provided Malody-Chart is from the wrong Mode! Mode is {this.meta.mode}, where a {ChartMode.Pad} is required!")

    result = fxf.newChartFile(
        artist = this.meta.song.artist,
        title = this.meta.song.title,
        jacket = this.meta.background,
    )

    let diff = memo.parseDifficulty(this.meta.version)
    var chart: fxf.Chart = fxf.newChart(rating = 1)

    if diff == memo.Difficulty.Basic:
        result.charts.basic = chart
    elif diff == memo.Difficulty.Advanced:
        result.charts.advanced = chart
    else:
        result.charts.extreme = chart

    var beats = initHashSet[malody.Beat]()
    var holdBeats = initHashSet[malody.Beat]()
    var tmp: seq[TimedElement] = @[]

    for e in this.note:
        beats.incl e.beat
        if e.kind == ElementType.IndexNote and e.hold == HoldType.IndexHold:
            holdBeats.incl e.indexEndBeat
        tmp.add e

    for e in this.time:
        beats.incl e.beat
        tmp.add e

    # Temporary additional timed-element entry which will be added
    # when no other element is present on that beat.
    # Used to properly end hold notes.
    for b in difference(beats, holdBeats):
        tmp.add TimedElement(beat: b, kind: ElementType.Plain, hold: HoldType.None)

    let timedElements = sorted(tmp, proc (a: TimedElement, b: TimedElement): int =
        result = 0

        for i in 0..1:
            let diff = a.beat[i] - b.beat[i]
            if diff != 0:
                return diff

        result = b.getPriority - a.getPriority
    )

    var bpm: float = 1
    var offset: float = 0
    var lastBpmSection: int = 0
    var holdTable = initTable[malody.Beat, seq[fxf.Hold]]()
    var beatTable = initTable[malody.Beat, fxf.Tick]()

    for element in timedElements:
        let beatSize = OneMinute / bpm
        let snapLength = beatSize / float(element.beat[2])
        let elementTime = offset + (beatSize * float(element.beat[0] - lastBpmSection)) + (snapLength * float(element.beat[1]))
        let roundedTime: float32 = round(elementTime * 10) / 10

        if holdTable.hasKey element.beat:
            #for hold in holdTable[element.beat]:
            #    hold.releaseOn = roundedTime
            holdTable.del element.beat

        if element.kind == ElementType.TimeSignature:
            offset = elementTime
            bpm = element.sigBpm
            lastBpmSection = element.beat[0]
            result.bpmChange.add fxf.newBpmChange(
                bpm = float32(element.sigBpm),
                time = roundedTime,
                snapIndex = uint16(element.beat[1]),
                snapSize = uint16(element.beat[2])
            )
            continue

        if element.kind == ElementType.SoundCue:
            if element.cueType == SoundCueType.Song:
                result.audio = element.cueSound
                offset = (roundedTime + element.cueOffset) * -1
            continue

        if element.kind != ElementType.IndexNote:
            # Skip all other unused elements
            continue

        var tick: fxf.Tick

        if not beatTable.hasKey element.beat:
            tick = fxf.newTick(
                time = roundedTime,
                snapIndex = uint16(element.beat[1]),
                snapSize = uint16(element.beat[2])
            )
            beatTable[element.beat] = tick
            chart.ticks.add tick
        else:
            tick = beatTable[element.beat]

        if element.hold != HoldType.IndexHold:
            tick.notes.add uint8(element.index)
            continue

        var hold = fxf.newHold(
            `from` = element.index,
            to = element.indexEnd,
            releaseOn = -1.0
        )

        if not holdTable.hasKey element.beat:
            holdTable[element.beat] = @[]
        holdTable[element.beat].add hold
        tick.holds.add hold

func toStepMania*(this: malody.Chart): sm.ChartFile {.cdecl, exportc: "rconv_malody_toStepMania", dynlib.} =
    if this.meta.mode != malody.ChartMode.Key:
        raise newException(InvalidModeException, fmt"The provided Malody-Chart is from the wrong Mode! Mode is {this.meta.mode}, where a {ChartMode.Key} is required!")

    result = sm.newChartFile(
        credit = this.meta.creator,
        sampleStart = this.meta.preview / 1000,
        background = this.meta.background
    )
    var output: sm.NoteData = nil
    var diff = sm.Difficulty.Edit
    var level = 0

    for part in this.meta.version.stripSplit(" "):
        try:
            diff = parseEnum[sm.Difficulty](part.toLower)
        except:
            discard
        try:
            var match: RegexMatch
            if part.match(LevelRegex, match):
                level = int(parseFloat(match.groupFirstCapture(0, part)))
        except:
            discard

    case this.meta.mode_ext.column:
        of 4:
            output = sm.newNoteData(sm.ChartType.DanceSingle, this.meta.creator, diff, level)
        of 5:
            output = sm.newNoteData(sm.ChartType.PumpSingle, this.meta.creator, diff, level)
        of 6:
            output = sm.newNoteData(sm.ChartType.DanceSolo, this.meta.creator, diff, level)
        of 8:
            output = sm.newNoteData(sm.ChartType.DanceDouble, this.meta.creator, diff, level)
        of 10:
            output = sm.newNoteData(sm.ChartType.PumpDouble, this.meta.creator, diff, level)
        else:
            raise newException(ConvertException, fmt"The column-count {this.meta.mode_ext.column} does not have a SM equivalent!")

    result.noteData.add output

    if not this.meta.song.title.isEmptyOrWhitespace:
        if not this.meta.song.titleorg.isEmptyOrWhitespace:
            result.title = this.meta.song.titleorg
            result.titleTransliterated = this.meta.song.title
        else:
            result.title = this.meta.song.title

    if not this.meta.song.artist.isEmptyOrWhitespace:
        if not this.meta.song.artistorg.isEmptyOrWhitespace:
            result.artist = this.meta.song.artistorg
            result.artistTransliterated = this.meta.song.artist
        else:
            result.artist = this.meta.song.artist

    for elem in this.time:
        if elem.kind != malody.ElementType.TimeSignature:
            continue
        # Readable Version: elem.beat[0] + ((1 / elem.beat[2]) * elem.beat[1])
        result.bpms.add sm.newBpmChange(newRat(elem.beat[0]) + newRat().mul(newRat().divide(newRat(1), elem.beat[2]), newRat(elem.beat[1])), elem.sigBpm)

    for elem in this.note:
        if elem.kind == malody.ElementType.SoundCue:
            if elem.cueType == malody.SoundCueType.Song:
                result.music = elem.cueSound
                result.offset = elem.cueOffset
            continue

        if elem.kind != malody.ElementType.ColumnNote:
            continue

        # noteBeat is required to not violate nim's gc
        let noteBeat = elem.beat[0]
        var beatIndex = output.beats.find(proc (beat: sm.Beat): bool = beat.index == noteBeat)
        var beat: sm.Beat = nil

        if beatIndex == -1:
            beat = sm.newBeat(elem.beat[0], elem.beat[2])
            output.beats.add beat
        else:
            beat = output.beats[beatIndex]

        if elem.hold == malody.HoldType.ColumnHold:
            var hold = sm.newNote(sm.NoteType.Hold, elem.beat[1], elem.column)
            hold.releaseBeat = elem.colEndBeat[0]
            hold.releaseSnap = elem.colEndBeat[1]
            hold.releaseLift = false
            beat.notes.add hold
        else:
            beat.notes.add sm.newNote(sm.NoteType.Note, elem.beat[1], elem.column)

#[
------------------------------------------
    STEP-MANIA CONVERTS
------------------------------------------
]#

proc toMalody*(this: sm.ChartFile, notes: NoteData): malody.Chart {.cdecl, exportc: "rconv_sm_toMalody", dynlib.} =
    result = malody.newChart()

    if not this.artistTransliterated.isEmptyOrWhitespace:
        result.meta.song.artist = this.artistTransliterated
        result.meta.song.artistorg = this.artist
    else:
        result.meta.song.artist = this.artist

    if not this.titleTransliterated.isEmptyOrWhitespace:
        result.meta.song.title = this.titleTransliterated
        result.meta.song.titleorg = this.title
    else:
        result.meta.song.title = this.title

    if not this.music.isEmptyOrWhitespace:
        result.note.add malody.newSoundCue([0, 0, 1], malody.SoundCueType.Song, this.music, this.offset, 100.0)

    result.meta.mode = malody.ChartMode.Key
    result.meta.preview = int(this.sampleStart * 1000)
    result.meta.background = this.background
    if not this.credit.isEmptyOrWhitespace:
        result.meta.creator = this.credit
    elif notes != nil:
        result.meta.creator = notes.description

    for bpm in this.bpms:
        result.time.add malody.newTimeSignature(getBeat(bpm.beat), bpm.bpm)

    if notes != nil:
        result.meta.mode_ext.column = sm.columnCount(notes.chartType)
        result.meta.version = $notes.difficulty & " " & $notes.difficultyLevel
        for beat in notes.beats:
            for note in beat.notes:
                let noteBeat = [beat.index, note.snap, beat.snapSize]

                if note.kind == sm.NoteType.Hold or note.kind == sm.NoteType.Roll:
                    let releaseBeat = note.releaseBeat
                    let releaseIndex = notes.beats.find(proc (nb: sm.Beat): bool = nb.index == releaseBeat)
                    let releaseSnapSize = if releaseIndex > -1: notes.beats[releaseIndex].snapSize else: 4
                    result.note.add malody.newColumnHold(noteBeat, note.column, 0, [note.releaseBeat, note.releaseSnap, releaseSnapSize])

                elif note.kind == sm.NoteType.Note or note.kind == sm.NoteType.Lift:
                    result.note.add malody.newColumnNote(noteBeat, note.column)

proc toMalody*(this: sm.ChartFile, index: int = 0): malody.Chart {.cdecl, exportc: "rconv_sm_toMalodyByIndex", dynlib.} =
    let notes = if this.noteData.len > index: this.noteData[index] else: nil
    result = toMalody(this, notes)
