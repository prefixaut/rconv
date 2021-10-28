import std/[math, tables]

import ../common
from ../fxf import nil
from ../memson import nil

type
    HoldRelease = tuple[fxf: fxf.Hold, memson: memson.Note]

func convertMemsonToFXF*(input: memson.Memson): fxf.ChartFile =
    var chart: fxf.Chart = fxf.Chart(ticks: @[], rating: float(input.level))
    result.charts = initTable[common.Difficulty, fxf.Chart]()
    result.charts[input.difficulty] = chart

    result.bpmChanges = @[]
    result.version = 1

    # TODO: add this to memson
    result.offset = -1
    result.jacket = "jacket.png"
    result.audio = "audio.mp3"

    # Meta-Data
    result.artist = input.artist
    result.title = input.songTitle

    var bpm: float
    var globalTime: float = 0
    var holdRelease = newSeq[HoldRelease]()

    for section in input.sections:
        if (bpm != section.bpm):
            bpm = section.bpm
            result.bpmChanges.add fxf.BpmChange(bpm: bpm, time: round(globalTime * 10) / 10, snapSize: section.snaps[0].len, snapIndex: 0)

        let beat = 60_000 / bpm
        var indexOffset = 0

        for snap in section.snaps:
            let snapLength = beat / float(snap.len)

            for snapIndex in 0..<snap.len:
                let timing = indexOffset + snapIndex
                let noteTime = round((globalTime + (snapLength * float(snapIndex + 1))) * 10) / 10

                # Handle previously saved holds.
                # if a hold has to end now, then we give it the proper releaseTime
                # and remove it from the seq
                var newHoldRelease = newSeq[HoldRelease]()
                for r in holdRelease.mitems:
                    if r.memson.releaseSection == section.index and r.memson.releaseTime == timing:
                        r.fxf.releaseOn = noteTime
                    else:
                        newHoldRelease.add r
                holdRelease = newHoldRelease    

                var tick = fxf.Tick(time: noteTime, snapSize: snap.len, snapIndex: snapIndex)

                for noteIndex, note in section.notes.pairs:
                    if note.time != timing:
                        continue
                    if note.kind == memson.NoteType.Hold:
                        var hold = fxf.Hold(`from`: note.animationStartIndex, to: noteIndex)
                        tick.holds.add hold
                        holdRelease.add (hold, note)
                    else:
                        tick.notes.add noteIndex
                
                chart.ticks.add tick

            inc indexOffset, snap.len
            globalTime = globalTime + beat
    