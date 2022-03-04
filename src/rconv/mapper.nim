import std/[algorithm, math, sets, strformat, tables]

import ./common

import ./fxf as fxf
import ./malody as malody
import ./memson as memson

type
    FXFHoldRelease = tuple[fxf: fxf.Hold, memson: memson.Note] ## \
    ## Tuple to join a fxf and memson hold, to be able to set the
    ## `releaseOn` field of the fxf hold on time.
    MalodyHoldRelease = tuple[memson: memson.Note, malody: malody.TimedElement] ## \
    ## Tuple to join a memson-hold and malody-hold, to be able to set the
    ## `endBeat` field on the malody hold on time.

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
                snapSize = uint16(section.snaps[0].len),
                snapIndex = uint16(0)
            )
            result.bpmChange.add change
            inc result.numBpm

        let beat = OneMinute / bpm
        var indexOffset = 0

        for snap in section.snaps:
            let snapTime = beat / float(snap.len)

            for snapIndex in 0..<snap.len:
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
                    snapSize = uint16(snap.len),
                    snapIndex = uint16(snapIndex)
                )
                var hasData = false

                for noteIndex, multiNotes in section.notes.pairs:
                    for note in multiNotes:
                        if note.time != timing:
                            continue

                        hasData = true
                        if note.kind == NoteType.Hold:
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

            inc indexOffset, snap.len

    if this.difficulty == Difficulty.Basic:
        result.charts.basic = chart
        result.charts.bscPresent = 1
    elif this.difficulty == Difficulty.Advanced:
        result.charts.advanced = chart
        result.charts.advPresent = 1
    else:
        result.charts.extreme = chart
        result.charts.extPresent = 1

proc toMalody*(this: memson.Memson): malody.Chart =
    ## Function to map/convert `this` Chart to a Malody Chart.

    result = malody.newChart(meta = malody.newMetaData(
        song = malody.newSongData(
            artist = this.artist,
            title = this.songTitle
        ),
        mode = malody.ChartMode.Pad,
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
        snapIndex = 1
        # echo "section " & $sectionIndex & ": " & $section

        if section.snaps.len > 0:
            snapSize = section.snaps[0].len
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
                    releasesToDelete.add(holdIndex)
            for idx in releasesToDelete:
                holdRelease.del(idx)

            if time > -1:
                var note: memson.Note
                var index: int

                for secNotePos, secMultiNotes in section.notes:
                    for secNote in secMultiNotes:
                        if secNote.time == timeIndex:
                            note = secNote
                            index = secNotePos
                            break

                if note != nil:
                    if note.kind == memson.NoteType.Hold:
                        let hold = malody.newIndexHold(beat = beat, index = index, endIndex = index)
                        result.note.add hold
                        holdRelease.add (memson: note, malody: hold)
                    else:
                        result.note.add malody.newIndexNote(beat = beat, index = index)

            inc snapIndex
            if snapIndex > snapSize:
                snapIndex = 1
                if section.snaps.len > snapPos:
                    snapSize = section.snaps[snapPos].len
                else:
                    snapSize = 0
                inc snapPos
                inc beatIndex
            inc timeIndex

        inc sectionIndex

proc toFXF*(this: malody.Chart): fxf.ChartFile =
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

    var beats = initHashSet[Beat]()
    var holdBeats = initHashSet[Beat]()
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
    var holdTable = initTable[Beat, seq[fxf.Hold]]()
    var beatTable = initTable[Beat, fxf.Tick]()

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
