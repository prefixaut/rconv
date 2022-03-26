import std/[algorithm, math, sets, strutils, strformat, sugar, tables]

import ./common
import ./private/parser_helpers

import ./fxf as fxf
import ./malody as malody
import ./memson as memson
import ./step_mania as sm

type
    FXFHoldRelease = tuple[fxf: fxf.Hold, memson: memson.Note] ## \
    ## Tuple to join a fxf and memson hold, to be able to set the
    ## `releaseOn` field of the fxf hold on time.
    MalodyHoldRelease = tuple[memson: memson.Note, malody: malody.TimedElement] ## \
    ## Tuple to join a memson-hold and malody-hold, to be able to set the
    ## `endBeat` field on the malody hold on time.

proc getBeat(value: float): malody.Beat =
    ## Helper function to convert a fraction beat-index (1.5, 2.3, ...) to a
    ## indicative beat & snap position.
    ## Currently supports from 1 to 20th snaps
    let beat = int(value)
    let part = int(int((value - float(beat)) * 100_000) / 10)

    # Additional values are for rounding errors/IEEE float handling
    case part:
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
    MEMSON CONVERTS
------------------------------------------
]#

func toFXF*(this: memson.Memson): fxf.ChartFile =
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
                    if r.memson.releaseSection == section.index and r.memson.releaseTime == timing:
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
                        if note.kind == memson.NoteType.Hold:
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

    if this.difficulty == memson.Difficulty.Basic:
        result.charts.basic = chart
        result.charts.bscPresent = 1
    elif this.difficulty == memson.Difficulty.Advanced:
        result.charts.advanced = chart
        result.charts.advPresent = 1
    else:
        result.charts.extreme = chart
        result.charts.extPresent = 1

func toMalody*(this: memson.Memson): malody.Chart =
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
                if holdVal.memson.releaseSection == sectionIndex and holdVal.memson.releaseTime == timeIndex:
                    holdVal.malody.indexEndBeat = beat
                    releasesToDelete.add holdIndex
                    break
            for idx in releasesToDelete:
                holdRelease.del idx

            if time > -1:
                for secNotePos, secMultiNotes in section.notes:
                    for secNote in secMultiNotes:
                        if secNote.time == timeIndex:
                            if secNote.kind == memson.NoteType.Hold:
                                let hold = malody.newIndexHold(beat = beat, index = secNotePos, endIndex = secNote.animationStartIndex)
                                result.note.add hold
                                holdRelease.add (memson: secNote, malody: hold)
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

func toFXF*(this: malody.Chart): fxf.ChartFile =
    ## Function to map/convert `this` Chart to a FXF-ChartFile.
    ## The actual note-data will be present in the `fxf.ChartFile.charts`_ table.
    ## The difficulty is determined by the `memson.parseDifficulty`_ function.

    if (this.meta.mode != ChartMode.Pad):
        raise newException(InvalidModeException, fmt"The provided Malody-Chart is from the wrong Mode! Mode is {this.meta.mode}, where a {ChartMode.Pad} is required!")

    result = fxf.newChartFile(
        artist = this.meta.song.artist,
        title = this.meta.song.title,
        jacket = this.meta.background,
    )

    let diff = memson.parseDifficulty(this.meta.version)
    var chart: fxf.Chart = fxf.newChart(rating = 1)

    if diff == memson.Difficulty.Basic:
        result.charts.basic = chart
    elif diff == memson.Difficulty.Advanced:
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

func toStepMania*(chart: malody.Chart): sm.ChartFile =
    if chart.meta.mode != malody.ChartMode.Key:
        raise newException(InvalidModeException, fmt"The provided Malody-Chart is from the wrong Mode! Mode is {chart.meta.mode}, where a {ChartMode.Key} is required!")

    result = sm.newChartFile(
        credit = chart.meta.creator,
        sampleStart = chart.meta.preview / 1000,
        background = chart.meta.background
    )
    var output: sm.NoteData = nil
    var diff = sm.Difficulty.Edit

    for part in chart.meta.version.stripSplit(" "):
        try:
            diff = parseEnum[sm.Difficulty](part.toLower)
        except:
            discard

    case chart.meta.mode_ext.column:
        of 4:
            output = sm.newNoteData(sm.ChartType.DanceSingle, chart.meta.creator, diff)
        of 5:
            output = sm.newNoteData(sm.ChartType.PumpSingle, chart.meta.creator, diff)
        of 6:
            output = sm.newNoteData(sm.ChartType.DanceSolo, chart.meta.creator, diff)
        of 8:
            output = sm.newNoteData(sm.ChartType.DanceDouble, chart.meta.creator, diff)
        of 10:
            output = sm.newNoteData(sm.ChartType.PumpDouble, chart.meta.creator, diff)
        else:
            raise newException(ConvertException, fmt"The column-count {chart.meta.mode_ext.column} does not have a SM equivalent!")

    if not chart.meta.song.title.isEmptyOrWhitespace:
        if not chart.meta.song.titleorg.isEmptyOrWhitespace:
            result.title = chart.meta.song.titleorg
            result.titleTransliterated = chart.meta.song.title
        else:
            result.title = chart.meta.song.title

    if not chart.meta.song.artist.isEmptyOrWhitespace:
        if not chart.meta.song.artistorg.isEmptyOrWhitespace:
            result.artist = chart.meta.song.artistorg
            result.artistTransliterated = chart.meta.song.artist
        else:
            result.artist = chart.meta.song.artist

    for elem in chart.time:
        if elem.kind != malody.ElementType.TimeSignature:
            continue
        result.bpms.add sm.newBpmChange(float(elem.beat[0]) + ((1 / elem.beat[2]) * float(elem.beat[1])), elem.sigBpm)

    for elem in chart.note:
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

proc toMalody*(chart: sm.ChartFile, notes: NoteData): malody.Chart =
    result = malody.newChart()

    if not chart.artistTransliterated.isEmptyOrWhitespace:
        result.meta.song.artist = chart.artistTransliterated
        result.meta.song.artistorg = chart.artist
    else:
        result.meta.song.artist = chart.artist

    if not chart.titleTransliterated.isEmptyOrWhitespace:
        result.meta.song.title = chart.titleTransliterated
        result.meta.song.titleorg = chart.title
    else:
        result.meta.song.title = chart.title

    if not chart.music.isEmptyOrWhitespace:
        result.note.add malody.newSoundCue([0, 0, 1], malody.SoundCueType.Song, chart.music, chart.offset, 100.0)

    result.meta.mode = malody.ChartMode.Key
    result.meta.preview = int(chart.sampleStart * 1000)
    result.meta.background = chart.background
    if not chart.credit.isEmptyOrWhitespace:
        result.meta.creator = chart.credit
    elif notes != nil:
        result.meta.creator = notes.description

    for bpm in chart.bpms:
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

proc toMalody*(chart: sm.ChartFile, index: int = 0): malody.Chart =
    let notes = if chart.noteData.len > index: chart.noteData[index] else: nil
    result = toMalody(chart, notes)
