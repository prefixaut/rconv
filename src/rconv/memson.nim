import std/[math, strutils, tables]

import ./common
import ./fxf as fxf

type
    Difficulty* {.pure.} = enum
        ## Difficulty for jubeat like games.
        ## Will be removed/replaced with a more generic solution soonish 
        Basic       = "basic",
        Advanced    = "advanced",
        Extreme     = "extreme"
        Edit        = "edit"

    NoteType* {.pure.} = enum
        ## The types of notes that exist (regular note, or a hold)
        Note        = "note"
        Hold        = "hold"

    NoteRange* = range[0..15] ## \
    ## All positions a note can be placed on.
    ## Posion description::
    ## 
    ##  0  1  2  3
    ##  4  5  6  7
    ##  8  9 10 11
    ##  12 13 14 15
    ## 

    RowIndex* = range[0..3] ## \
    ## Range of how many row-indices may exist (4).

    BpmRange* = tuple[min: float, max: float] ## \
        ## The range of BPM the file is in

    Note* = object
        ## A Note or Hold which has to be pressed.
        time*: int
        ## The timing id when this note has to be pressed.
        partIndex*: int
        ## In which part this note was originally defined.
        case kind*: NoteType
            ## Which kind this Note is (Note or Hold)
            of NoteType.Hold:
                animationStartIndex*: int
                ## On which position the animation for the hold starts on.
                releaseTime*: int
                ## The release timing id when the hold has to be released.
                releaseSection*: int
                ## In which section it has to look for the timing id.
            else:
                discard

    Section* = object
        ## Describes a complete section (with all parts).
        index*: int
        ## The index of this section.
        bpm*: float
        ## What BPM this section is using.
        partCount*: int
        ## How many parts this section originally consisted of.
        timings*: seq[int]
        ## Timing ids which defined when a note needs to be pressed.
        snaps*: seq[Snap]
        ## The snaps for the timing.
        notes*: OrderedTable[NoteRange, Note]
        ## Notes that need to be played.
        ## Keys are the positions, which start from top-left to bottom-right.
        ## _`NoteRange`

    Snap* = object
        ## Describes the amount of notes that can occur in a single beat.
        len*: int
        ## How many notes fit into a Snap.
        partIndex*: int
        ## In which part of the original section this snap is defined.
        row*: RowIndex
        ## The row in which this snap is defined.

    Memson* = object
        ## Memson is the in-memory data-structure for memo-files.
        songTitle*: string
        ## The title of the chart's song.
        artist*: string
        ## The artist of the chart's song.
        difficulty*: Difficulty
        ## The difficulty of the chart.
        level*: int
        ## The difficulty as level range (Usually 1-10) of the chart.
        bpm*: float
        ## The BPM of the chart. May not be accurate if the `bpmRange` is set.
        bpmRange*: BpmRange
        ## The BPM-Range of the chart.
        ## May only be set if BPM changes occur in the chart.
        sections*: seq[Section]
        ## The sections of the chart.

    FXFHoldRelease = tuple[fxf: fxf.Hold, memson: memson.Note] ## \
        ## Tuple to join a fxf and memson hold, to be able to set the
        ## `releaseOn` field of the fxf hold on time.

func parseDifficulty*(input: string): Difficulty =
    case input.toLower:
    of "basic":
        result = Difficulty.Basic
    of "adv", "advanced":
        result = Difficulty.Advanced
    of "ext", "extreme", "extra":
        result = Difficulty.Extreme
    else:
        result = Difficulty.Edit

func toFXF*(this: Memson): fxf.ChartFile =
    result = fxf.newChartFile(
        artist = this.artist,
        title = this.songTitle,
        jacket = "jacket.png",
        audio = "audio.mp3"
    )
    var chart: fxf.Chart = fxf.newChart(rating = uint32(this.level))

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

        let beat = OneMinute / bpm
        var indexOffset = 0

        for snap in section.snaps:
            let snapLength = beat / float(snap.len)

            for snapIndex in 0..<snap.len:
                let timing = indexOffset + snapIndex
                let noteTime = round((globalTime + (snapLength * float(snapIndex + 1))) * 10) / 10

                # Handle previously saved holds.
                # if a hold has to end now, then we give it the proper releaseTime
                # and remove it from the seq
                var newFXFHoldRelease = newSeq[FXFHoldRelease]()
                for r in holdRelease.mitems:
                    if r.memson.releaseSection == section.index and r.memson.releaseTime == timing:
                        r.fxf.releaseOn = noteTime
                    else:
                        newFXFHoldRelease.add r
                holdRelease = newFXFHoldRelease    

                var tick = fxf.newTick(
                    time = noteTime,
                    snapSize = uint16(snap.len),
                    snapIndex = uint16(snapIndex)
                )
                var hasData = false

                for noteIndex, note in section.notes.pairs:
                    if note.time != timing:
                        continue

                    hasData = true
                    if note.kind == NoteType.Hold:
                        var hold = fxf.newHold(`from` = note.animationStartIndex, to = noteIndex)
                        tick.holds.add hold
                        holdRelease.add (hold, note)
                    else:
                        tick.notes.add uint8(noteIndex)

                if hasData:
                    chart.ticks.add tick

            inc indexOffset, snap.len
            globalTime = globalTime + beat

    if this.difficulty == Difficulty.Basic:
        result.charts.basic = chart
    elif this.difficulty == Difficulty.Advanced:
        result.charts.advanced = chart
    else:
        result.charts.extreme = chart
