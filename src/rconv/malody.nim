import std/[algorithm, math, sets, strformat, tables]

import ./common
import ./fxf as fxf
import ./memson as memson

{.experimental: "codeReordering".}

type
    Chart* = object
        ## A Malody chart-File object definition
        meta*: MetaData
        ## Meta data of the chart, such as version, creator and song data
        time*: seq[TimeSignature]
        ## Time signatures of the chart (BPM changes)

        #[
        effect*: seq[void]
        ## Effects of the chart
        ]#

        note*: seq[TimedElement]
        ## Notes, Holds and other timed gameplay elements

    ChartMode* {.pure.} = enum
        ## The mode for a malody chart.
        Key = 0
        ## "Mania" game mode (SM, PIU, ...) with varying amount of keys (4,5,6,7, ...)k
        
        # Type 1 and 2 seem to be deleted types for DDR pads and BMS/merged with "Key"

        Catch = 3
        ## osu!catch
        Pad = 4
        ## Jubeat
        Taiko = 5
        ## You should know taiko
        Ring = 6
        ## Reflect Beat
        Slide = 7
        ## Mania but for touchscreen

    CatchNoteType {.pure.} = enum
        Hold = 3

    SlideNoteType* {.pure.} = enum
        Hold = 4

    KeyColumnRange = range[1..10]
    ## Range of available Columns
    TabIndexRange = range[0..15]

    MetaData* = object
        `$ver`*: int
        ## Version of the chart-format
        creator*: string
        ## Creator of the chart
        background*: string
        ## Background image of the chart
        version*: string
        ## Chart version (only for ranked)
        preview*: int
        ## Offset in ms when the preview should start
        id*: uint
        ## ID of the chart (only for ranked)
        mode*: ChartMode
        ## Mode of the Chart (For which game-mode this chart is available)
        time*: int
        ## Timestamp of when the chart was edited the last time
        song*: SongData
        ## Song meta-data
        mode_ext*: ModeData
        ## Extra Data specifically for the Mode

    SongData* = object
        title*: string
        ## Title of the song.
        ## If the `titleorg` field exists, then this is should be the romanized/latin version
        titleorg*: string
        ## Title of the song in the original language
        artist*: string
        ## Artist of the song
        ## If the `artistorg` field exists, then this is should be the romanized/latin version
        artistorg*: string
        ## Arist of the song in the original language
        id*: int
        ## ID combination of the title & artist (only for ranked)

    ModeData* = object
        column*: int
        ## Used in Mode "Key" to determine how many keys/columns it's using
        bar_begin: int
        ## Used in Mode "Key" to determine when the bar should start to be displayed
        ## Usually it's the (index of the first note)-1 or 0
        speed: int
        ## The fall speed of the notes

    Beat* = array[3, int]
    ## A beat is the time when something happens
    ## Beat[0] is the section index
    ## Beat[1] is the snap index
    ## Beat[2] is the snap size

    SoundCueType* {.pure.} = enum
        Effect = 0
        ## A sound effect which is simply played over the song.
        Song = 1
        ## Sound/Actual song which is played for the entirety of the chart
        KeySound = 2
        ## Sound which is only played for a certain note.
        ## Usually ignored if the note hasn't been hit (see BMS)

    TimedElement* = object of RootObj
        beat*: Beat
        ## The Beat on which this timed-element occurs

    TimeSignature* = object of TimedElement
        bpm*: float
        ## The new BPM it's changing to

    SoundCue* = object of TimedElement
        `type`*: SoundCueType
        ## Type of Sound-Cue that should be played
        sound*: string
        ## (Relative) File-Path to the sound-file to play
        offset*: float
        ## How much offset in ms it should wait before playing it
        vol*: float
        ## How loud the sound should be played

    IndexNote* = object of TimedElement
        ## Note for the following Modes: Pad
        index*: TabIndexRange
        ## Index of the Note (0-15) (When mode is "Pad")

    ColumnNote* = object of TimedElement
        ## Note for following Modes: Key, Taiko, Ring
        column*: KeyColumnRange
        ## The column in which this note is placed in
        style*: int
        ## Taiko: Type of taiko-note

    VerticalNote* = object of TimedElement
        ## Note for the following Modes: Catch, Slide
        x*: int
        ## X-Position of the Note

    CatchNote* = object of VerticalNote
        ## Note for the following Modes: Catch
        `type`*: CatchNoteType
        ## Optional type of the note

    SlideNote* = object of VerticalNote
        ## Note for the following Modes: Slide
        w*: int
        ## Width of the Note
        `type`*: SlideNoteType
        ## Optional type of the Note
        seg*: seq[VerticalNote]
        ## Additional positions of the long note/slides

    IndexHold* = object of IndexNote
        ## Hold for the following Modes: Pad
        endbeat*: Beat
        ## Beat when the hold is being released
        endindex*: TabIndexRange
        ## The index where the Hold is being released on

    ColumnHold* = object of ColumnNote
        ## Note for the following Modes: Key, Taiko, Ring
        endbeat*: Beat
        ## Beat when the hold is being released
        hits: int
        ## Taiko: Amount of hits the hold needs

    CatchHold* = object of CatchNote
        endbeat*: Beat
        ## Beat when the hold is being released

func getPriority(this: malody.TimedElement): int =
    ## Internal helper function to get the priority of a `TimedElement`.
    ## Usually used for sorting.

    result = 1
    # Unknown types get a default score of 1

    if this of malody.IndexNote or this of malody.ColumnNote or this of malody.VerticalNote or this of malody.CatchNote:
        # All Notes get a score of 2
        result = 2
    elif this of malody.SoundCue:
        result = 3
    elif this of malody.TimeSignature:
        result = 4

proc toFXF*(this: Chart): fxf.ChartFile =
    ## Converts `this` Chart to a FXF-ChartFile.
    ## The actual note-data will be present in the `fxf.ChartFile.charts`_ table.
    ## The difficulty is determined by the `memson.parseDifficulty`_ function.

    if (this.meta.mode != ChartMode.Pad):
        raise newException(ValueError, fmt"The provided Malody-Chart is from the wrong Mode! Mode is {this.meta.mode}, where a {ChartMode.Pad} is required!")

    let diff = $memson.parseDifficulty(this.meta.version)
    var chart: fxf.Chart = fxf.Chart(ticks: @[], rating: 1)

    result.artist = this.meta.song.artist
    result.title = this.meta.song.title
    result.jacket = this.meta.background
    result.audio = ""
    result.bpmChanges = @[]
    result.charts = initTable[string, fxf.Chart]()
    result.charts[diff] = chart

    var beats = initHashSet[Beat]()
    var holdBeats = initHashSet[Beat]()
    var tmp: seq[TimedElement] = @[]

    for e in this.note:
        beats.incl e.beat
        echo e
        if e of IndexHold:
            holdBeats.incl IndexHold(e).endbeat
        tmp.add e

    for e in this.time:
        beats.incl e.beat
        tmp.add e

    # Temporary additional timed-element entry which will be added
    # when no other element is present on that beat.
    # Used to properly end hold notes.
    for b in difference(beats, holdBeats):
        tmp.add TimedElement(beat: b)

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
        let roundedTime = round(elementTime * 10) / 10

        if holdTable.hasKey element.beat:
            #for hold in holdTable[element.beat]:
            #    hold.releaseOn = roundedTime
            holdTable.del element.beat

        if element of TimeSignature:
            offset = elementTime
            bpm = TimeSignature(element).bpm
            lastBpmSection = element.beat[0]
            result.bpmChanges.add fxf.BpmChange(
                bpm: TimeSignature(element).bpm,
                time: roundedTime,
                snapIndex: element.beat[1],
                snapSize: element.beat[2]
            )
            continue

        if element of SoundCue:
            if SoundCue(element).`type` == SoundCueType.Song:
                result.audio = SoundCue(element).sound
                offset = (roundedTime + SoundCue(element).offset) * -1
            continue

        if not (element of IndexNote):
            # Skip all other unused elements
            continue

        var tick: fxf.Tick
        if not beatTable.hasKey element.beat:
            tick = fxf.Tick(
                time: roundedTime,
                snapIndex: element.beat[1],
                snapSize: element.beat[2],
                notes: @[],
                holds: @[]
            )
            beatTable[element.beat] = tick
        else:
            tick = beatTable[element.beat]
        
        if not (element of IndexHold):
            tick.notes.add IndexHold(element).index
            continue
        
        var hold = fxf.Hold(
            `from`: IndexHold(element).index,
            to: IndexHold(element).endindex,
            releaseOn: -1.0
        )

        if not holdTable.hasKey element.beat:
            holdTable[element.beat] = @[]
        holdTable[element.beat].add hold
        tick.holds.add hold
