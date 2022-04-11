##[
    Module which contains types for all FXF elements,
    as well as procs to parse and write them from and to binary streams.
]##

import std/[streams]

import ./private/[grid_common, stream_helpers]
import ./common

export grid_common

const
    Version1* = uint32(1)

type
    InvalidVersionException* {.exportc: "rconv_fxf_$1".} = object of CatchableError
    ## Exception which is thrown when the loaded Version is not parsable/valid

    ChartFile* = ref object
        ## A single file containing all meta information and chart data
        ## with multiple difficulties
        `version`*: uint32
        ## A complete FXF-Chart file which contains multiple charts (Difficulties)
        `title`*: string
        ## Song title
        `artist`*: string
        ## Song's artist
        `audio`*: string
        ## Local path to audio file (relative to this files directory)
        `jacket`*: string
        ## Local path to jacket (relative to this files directory)
        `offset`*: int32
        ## Audio outset in ms
        `numBpm`*: uint32
        ## Number of bpm-change entries
        `bpmChange`*: seq[BpmChange]
        ## The changes of the BPM
        `charts`*: ChartCollection
        ## Chart collection which separates the difficulties

    ChartCollection* {.exportc: "rconv_fxf_$1".} = ref object
        ## Multiple charts keyed by their difficulties
        `bscPresent`*: uint8
        ## If the `basic` difficulty/chart is present
        `advPresent`*: uint8
        ## If the `advanced` difficulty/chart is present
        `extPresent`*: uint8
        ## If the `extreme` difficulty/chart is present
        `basic`*: Chart
        ## The chart for the `basic` difficulty
        `advanced`*: Chart
        ## The chart for the `advanced` difficulty
        `extreme`*: Chart
        ## The chart for the `extreme` difficulty

    Chart* {.exportc: "rconv_fxf_$1".} = ref object
        ## A single FXF chart which holds the note/hold information
        `rating`*: uint32
        ## The charts difficulty rating as numerical value
        `numTick`*: uint32
        ## Number of tick entries
        `ticks`*: seq[Tick]
        ## The ticks/notes of the chart

    BpmChange* {.exportc: "rconv_fxf_$1".} = ref object
        ## A change of BPM in the song/chart on a given time
        bpm*: float32
        ## The BPM it changes to
        time*: float32
        ## Timestamp in milliseconds when the bpm changes
        snapSize*: uint16
        ## optional. The snap-size in which this change occurs
        snapIndex*: uint16
        ## optional. The snap-index in which the change occurs

    Tick* {.exportc: "rconv_fxf_$1".} = ref object
        ## A tick referres to a time in the chart, where one or more
        ## actions need to be performed.
        `time`*: float32
        ## Timestamp in milliseconds when the button needs to be pressed
        `snapSize`*: uint16
        ## The snap-size in which this tick occurs
        `snapIndex`*: uint16
        ## The snap-index in which the tick occurs
        `numNotes`*: uint8
        ## Number of note entries
        `notes`*: seq[uint8]
        ## Sequence of notes to press at this time
        `numHolds`*: uint8
        ## Number of hold entries
        `holds`*: seq[Hold]
        ## Sequence of holds to start at this time

    Hold* {.exportc: "rconv_fxf_$1".} = ref object
        ## A hold is a regular note which needs to be held until a certain time.
        ## It starts on the `from` position together with an animation which
        ## starts on the `to` position.
        ## The hold resolves at the `releaseOn` property (chart time, not offset),
        ## and is indicated with an animation.
        `from`*: NoteRange
        ## Index the hold starts on (see notes in Tick interface)
        to*: NoteRange
        ## Index the hold ends on (see notes in Tick interface)
        releaseOn*: float32
        ## Timestamp in milliseconds when to release the note.
        ## There is no need to search for the hold end
        ## and animation duration can be calculated really easily

func newChartCollection*(basic: Chart = nil, advanced: Chart = nil, extreme: Chart = nil): ChartCollection {.cdecl, exportc: "rconv_fxf_$1", dynlib.} =
    result = ChartCollection()
    result.bscPresent = uint8(basic != nil)
    result.basic = basic
    result.advPresent = uint8(advanced != nil)
    result.advanced = advanced
    result.extPresent = uint8(extreme != nil)
    result.extreme = extreme

func newChartFile*(
    title: string = "",
    artist: string = "",
    audio: string = "",
    jacket: string = "",
    offset: int32 = 0,
    bpmChange: seq[BpmChange] = @[],
    charts = newChartCollection()
): ChartFile {.cdecl, exportc: "rconv_fxf_$1", dynlib.} =
    result = ChartFile()
    result.version = Version1
    result.title = title
    result.artist = artist
    result.audio = audio
    result.jacket = jacket
    result.offset = offset
    result.numBpm = uint32(bpmChange.len)
    result.bpmChange = bpmChange
    result.charts = charts

func newChart*(rating: uint32 = 1, ticks: seq[Tick] = @[]): Chart {.cdecl, exportc: "rconv_fxf_$1", dynlib.} =
    result = Chart()
    result.rating = rating
    result.numTick = uint32(ticks.len)
    result.ticks = ticks

func newBpmChange*(
    bpm: float32 = 0,
    time: float32 = 0,
    snapSize: uint16 = 0,
    snapIndex: uint16 = 0
): BpmChange {.cdecl, exportc: "rconv_fxf_$1", dynlib.} =
    result = BpmChange()
    result.bpm = bpm
    result.time = time
    result.snapSize = snapSize
    result.snapIndex = snapIndex

func newTick*(
    time: float32 = 0,
    snapSize: uint16 = 0,
    snapIndex: uint16 = 0,
    notes: seq[uint8] = @[],
    holds: seq[Hold] = @[]
): Tick {.cdecl, exportc: "rconv_fxf_$1", dynlib.} =
    result = Tick()
    result.time = time
    result.snapSize = snapSize
    result.snapIndex = snapIndex
    result.numNotes = uint8(notes.len)
    result.notes = notes
    result.numHolds = uint8(holds.len)
    result.holds = holds

func newHold*(`from`: NoteRange, to: NoteRange, releaseOn: float32 = 0): Hold {.cdecl, exportc: "rconv_fxf_$1", dynlib.} =
    result = Hold()
    result.`from` = `from`
    result.to = to
    result.releaseOn = releaseOn

func asFormattingParams*(chart: ChartFile): FormattingParameters {.cdecl, exportc: "rconv_fxf_$1", dynlib.} =
    ## Creates formatting-parameters from the provided chart-file

    result = newFormattingParameters(
        title = chart.title,
        artist = chart.artist,
        extension = $FileType.FXF,
    )

proc readFXFBpmChange(stream: Stream): BpmChange {.cdecl, exportc: "rconv_fxf_$1", dynlib.} =
    result.bpm = stream.readFloat32
    result.time = stream.readFloat32
    result.snapSize = stream.readUint16
    result.snapIndex = stream.readUint16

proc readFXFHold(stream: Stream): Hold {.cdecl, exportc: "rconv_fxf_$1", dynlib.} =
    result.`from` = stream.readUint8
    result.to = stream.readUint8
    result.releaseOn = stream.readFloat32

proc readFXFTick(stream: Stream): Tick {.cdecl, exportc: "rconv_fxf_$1", dynlib.} =
    result.time = stream.readFloat32
    result.snapSize = stream.readUint16
    result.snapIndex = stream.readUint16
    result.numNotes = stream.readUint8
    result.notes = @[]

    for i in 0..uint32(result.numNotes):
        result.notes.add stream.readUint8

    result.numHolds = stream.readUint8
    result.holds = @[]

    for i in 0..uint32(result.numHolds):
        result.holds.add stream.readFXFHold

proc readFXFChart(stream: Stream): Chart {.cdecl, exportc: "rconv_fxf_$1", dynlib.} =
    result.rating = stream.readUint32
    result.numTick = stream.readUint32
    result.ticks = @[]

    for i in 0..result.numTick:
        result.ticks.add stream.readFXFTick

proc readFXFChartCollection(stream: Stream): ChartCollection {.cdecl, exportc: "rconv_fxf_$1", dynlib.} =
    result.bscPresent = stream.readUint8
    result.advPresent = stream.readUint8
    result.extPresent = stream.readUint8

    if result.bscPresent != 0:
        result.basic = stream.readFXFChart
    if result.advPresent != 0:
        result.advanced = stream.readFXFChart
    if result.extPresent != 0:
        result.extreme = stream.readFXFChart

proc parseFXF*(stream: Stream, lenient: bool = false): ChartFile {.cdecl, exportc: "rconv_fxf_$1".} =
    ## Parse a FXF Chart File from the stream

    var version = stream.readUint32
    if Version1 != version:
        raise newException(InvalidVersionException, "The loaded version " & $version & " is not valid!")

    result.version = version
    result.title = stream.readUTF8Str
    result.artist = stream.readUTF8Str
    result.audio = stream.readUTF8Str
    result.jacket = stream.readUTF8Str
    result.offset = stream.readInt32
    result.numBpm = stream.readUint32
    result.bpmChange = @[]

    for i in 0..result.numBpm:
        result.bpmChange.add stream.readFXFBpmChange

    result.charts = stream.readFXFChartCollection

proc write(chart: Chart, stream: Stream): void {.cdecl, exportc: "rconv_fxf_writeChart", dynlib.} =
    stream.write(chart.rating)
    stream.write(uint32(chart.ticks.len))

    for tick in chart.ticks:
        stream.write(tick.time)
        stream.write(tick.snapSize)
        stream.write(tick.snapIndex)
        stream.write(uint8(tick.notes.len))

        for note in tick.notes:
            stream.write(note)

        stream.write(uint8(tick.holds.len))

        for hold in tick.holds:
            stream.write(uint8(hold.`from`))
            stream.write(uint8(hold.to))
            stream.write(hold.releaseOn)

proc write*(chart: ChartFile, stream: Stream): void {.cdecl, exportc: "rconv_fxf_$1", dynlib.} =
    stream.write(chart.version)
    stream.writeUTF8(chart.title, chart.artist, chart.audio, chart.jacket)
    stream.write(chart.offset)
    stream.write(uint32(chart.bpmChange.len))

    for bpmChange in chart.bpmChange:
        stream.write(bpmChange.bpm)
        stream.write(bpmChange.time)
        stream.write(bpmChange.snapSize)
        stream.write(bpmChange.snapIndex)

    stream.write(uint8(chart.charts.basic != nil))
    stream.write(uint8(chart.charts.advanced != nil))
    stream.write(uint8(chart.charts.extreme != nil))

    if chart.charts.basic != nil:
        chart.charts.basic.write(stream)
    if chart.charts.advanced != nil:
        chart.charts.advanced.write(stream)
    if chart.charts.extreme != nil:
        chart.charts.extreme.write(stream)
