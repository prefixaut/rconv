import std/[enumutils, json, jsonutils, sets, streams, tables]

import ./common
import ./private/json_helpers

type
    InvalidModeException* = object of CatchableError ## \
    ## Exception which is thrown when the chart's type can't be converted to the
    ## required output format

    Chart* = ref object
        ## A Malody chart-File object definition
        meta*: MetaData
        ## Meta data of the chart, such as version, creator and song data
        time*: seq[TimedElement]
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
        Unused_1 = 1
        ## Unused enum-property to prevent enum with holes
        Unused_2 = 2
        ## Unused enum-property to prevent enum with holes

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
        Unused_0 = 0
        Unused_1 = 1
        Unused_2 = 2
        Hold = 3

    SlideNoteType* {.pure.} = enum
        Unused_0 = 0
        Unused_1 = 1
        Unused_2 = 2
        Unused_3 = 3
        Hold = 4

    KeyColumnRange = range[0..9] ## \
    ## Range of available Columns
    IndexRange = range[0..15] ## \
    ## Range of available indices/note positions

    MetaData* = ref object
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

    SongData* = ref object
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

    ModeData* = ref object
        column*: int
        ## Used in Mode "Key" to determine how many keys/columns it's using
        bar_begin: int
        ## Used in Mode "Key" to determine when the bar should start to be displayed
        ## Usually it's the (index of the first note)-1 or 0
        speed: int
        ## The fall speed of the notes

    Beat* = array[3, int] ## \
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

    ElementType* {.pure.} = enum
        Plain
        ## A plain element - usually only used internally and shouldn't actually exist in any file
        TimeSignature
        ## Indicates a BPM change/Time Signature change
        SoundCue
        ## Defines a Sound/Song to be played
        IndexNote
        ## Note for the following Modes: Pad
        ColumnNote
        ## Note for following Modes: Key, Taiko, Ring
        CatchNote
        ## Note for the following Modes: Catch
        SlideNote
        ## Note for the following Modes: Slide

    HoldType* {.pure.} = enum
        None
        ## If it isn't a hold
        IndexHold
        ## Hold for the following Modes: Pad
        ColumnHold
        ## Hold for the following Modes: Key, Taiko, Ring
        CatchHold
        ## Hold for the following Modes: Catch

    TimedElement* = ref object of RootObj
        beat*: Beat
        ## The Beat on which this timed-element occurs
        case kind*: ElementType
            of TimeSignature:
                sigBpm*: float
                ## The new BPM it's changing to

            of SoundCue:
                cueType*: SoundCueType
                ## Type of Sound-Cue that should be played
                cueSound*: string
                ## (Relative) File-Path to the sound-file to play
                cueOffset*: float
                ## How much offset in ms it should wait before playing it
                cueVolume*: float
                ## How loud the sound should be played

            of IndexNote:
                index*: IndexRange
                ## Index of the Note (0-15) (When mode is "Pad")

            of ColumnNote:
                column*: KeyColumnRange
                ## The column in which this note is placed in
                colStyle*: int
                ## Taiko: Type of taiko-note

            of CatchNote:
                catchX*: int
                ## X-Position of the Note
                catchType*: CatchNoteType
                ## Optional type of the note

            of SlideNote:
                slideX*: int
                ## X-Position of the Note
                slideWidth*: int
                ## Width of the Note
                slideType*: SlideNoteType
                ## Optional type of the Note
                slideSegments*: seq[TimedElement]
                ## Additional positions of the long note/slides

            else:
                discard

        case hold*: HoldType
            of IndexHold:
                indexEndBeat*: Beat
                ## Beat when the hold is being released
                indexEnd*: IndexRange
                ## The index where the animation for the hold starts on

            of ColumnHold:
                colEndBeat*: Beat
                ## Beat when the hold is being released
                colHits*: int
                ## Taiko: Amount of hits the hold needs

            of CatchHold:
                catchEndBeat*: Beat
                ## Beat when the hold is being released
            else:
                discard
const
    EmptyBeat*: Beat = [-1, 0, 0]

func getPriority*(this: TimedElement): int =
    ## Internal helper function to get the priority of a `TimedElement`.
    ## Usually used for sorting.

    result = 1
    # Unknown types get a default score of 1

    if this.kind == ElementType.IndexNote or this.kind == ElementType.ColumnNote or this.kind == ElementType.CatchNote or this.kind == ElementType.SlideNote:
        # All Notes get a score of 2
        result = 2
    elif this.kind == ElementType.SoundCue:
        result = 3
    elif this.kind == ElementType.TimeSignature:
        result = 4

func getSoundCueType*(id: int): SoundCueType =
    result = SoundCueType.Effect

    case id:
    of 0:
        result = SoundCueType.Effect
    of 1:
        result = SoundCueType.Song
    of 2:
        result = SoundCueType.KeySound
    else:
        discard

func getSlideNoteType*(id: int): SlideNoteType =
    result = SlideNoteType.Hold

    case id:
    of 4:
        result = SlideNoteType.Hold
    else:
        discard

func getCatchNoteType*(id: int): CatchNoteType =
    result = CatchNoteType.Hold

    case id:
    of 3:
        result = CatchNoteType.Hold
    else:
        discard

func newSongData*(
    title: string = "",
    titleorg: string = "",
    artist: string = "",
    artistorg: string = "",
    id: int = 0
): SongData =
    new result
    result.title = title
    result.titleorg = titleorg
    result.artist = artist
    result.artistorg = artistorg
    result.id = id

func newModeData*(column: int = 0, bar_begin: int = 0, speed: int = 0): ModeData =
    new result
    result.column = column
    result.bar_begin = bar_begin
    result.speed = speed

func newMetaData*(
    `$ver`: int = 1,
    creator: string = "",
    background: string = "",
    version: string = "",
    preview: int = 0,
    id: uint = 0,
    mode: ChartMode = ChartMode.Key,
    time: int = 0,
    song: SongData = newSongData(),
    mode_ext: ModeData = newModeData()
): MetaData =
    new result
    result.`$ver` = `$ver`
    result.creator = creator
    result.background = background
    result.version = version
    result.preview = preview
    result.id = id
    result.mode = mode
    result.time = time
    result.song = song
    result.mode_ext = mode_ext

func newChart*(meta: MetaData = newMetaData(), time: seq[TimedElement] = @[], note: seq[TimedElement] = @[]): Chart =
    new result
    result.meta = meta
    result.time = time
    result.note = note

func newTimedElement*(beat: Beat = EmptyBeat): TimedElement =
    result = TimedElement(beat: beat, kind: ElementType.Plain, hold: HoldType.None)

func newTimeSignature*(beat: Beat = EmptyBeat, bpm: float = 0): TimedElement =
    result = TimedElement(beat: beat, kind: ElementType.TimeSignature, hold: HoldType.None)
    result.sigBpm = bpm

func newSoundCue*(
    beat: Beat = EmptyBeat,
    `type`: SoundCueType = SoundCueType.Effect,
    sound: string = "",
    offset: float = 0,
    volume: float = 0
): TimedElement =
    result = TimedElement(beat: beat, kind: ElementType.SoundCue, hold: HoldType.None)
    result.cueType = `type`
    result.cueSound = sound
    result.cueOffset = offset
    result.cueVolume = volume

proc newIndexNote*(beat: Beat = EmptyBeat, index: IndexRange = 0): TimedElement =
    result = TimedElement(beat: beat, kind: ElementType.IndexNote, hold: HoldType.None)
    result.index = index

func newColumnNote*(
    beat: Beat = EmptyBeat,
    column: KeyColumnRange = 0,
    style: int = 0
): TimedElement =
    result = TimedElement(beat: beat, kind: ElementType.ColumnNote, hold: HoldType.None)
    result.column = column
    result.colStyle = style

func newCatchNote*(
    beat: Beat = EmptyBeat,
    x: int = 0,
    `type`: CatchNoteType = CatchNoteType.Hold
): TimedElement =
    result = TimedElement(beat: beat, kind: ElementType.CatchNote, hold: HoldType.None)
    result.catchX = x
    result.catchType = `type`

func newSlideNote*(
    beat: Beat = EmptyBeat,
    x: int = 0,
    width: int = 0,
    `type`: SlideNoteType = SlideNoteType.Hold,
    segments: seq[TimedElement] = @[]
): TimedElement =
    result = TimedElement(beat: beat, kind: ElementType.SlideNote, hold: HoldType.None)
    result.slideX = x
    result.slideWidth = width
    result.slideType = `type`
    result.slideSegments = segments

func newIndexHold*(
    beat: Beat = EmptyBeat,
    index: IndexRange,
    endBeat: Beat = EmptyBeat,
    endIndex: IndexRange
): TimedElement =
    result = TimedElement(beat: beat, kind: ElementType.IndexNote, hold: IndexHold)
    result.index = index
    result.indexEndBeat = endBeat
    result.indexEnd = endIndex

func newColumnHold*(
    beat: Beat = EmptyBeat,
    column: KeyColumnRange = 0,
    style: int = 0,
    endBeat: Beat = EmptyBeat,
    hits: int = 1
): TimedElement =
    result = TimedElement(beat: beat, kind: ElementType.ColumnNote, hold: HoldType.ColumnHold)
    result.column = column
    result.colStyle = style
    result.colEndBeat = endBeat
    result.colHits = hits

func newCatchHold*(
    beat: Beat = EmptyBeat,
    x: int = 0,
    `type`: CatchNoteType = CatchNoteType.Hold,
    endBeat: Beat = EmptyBeat
): TimedElement =
    result = TimedElement(beat: beat, kind: ElementType.CatchNote, hold: HoldType.CatchHold)
    result.catchX = x
    result.catchType = `type`
    result.catchEndBeat = endBeat

func asFormattingParams*(chart: Chart): FormattingParameters =
    ## Creates formatting-parameters from the provided chart-file

    result = newFormattingParameters(
        title = chart.meta.song.title,
        artist = chart.meta.song.artist,
        difficulty = chart.meta.version,
        extension = FileType.Malody.getFileExtension,
    )

func getBeatSafe(self: JsonNode, field: string = "beat", default: malody.Beat = malody.EmptyBeat): malody.Beat =
    ## Internal helper function to safely get a beat from a JsonNode

    result = default
    if self.fields.hasKey(field):
        try:
            if self.fields[field].kind == JsonNodeKind.JArray:
                let arr = self.fields[field].elems
                for index in 0..2:
                    if arr.len >= index:
                        result[index] = arr[index].getInt
        except:
            discard

func toTimedElement*(self: JsonNode, lenient: bool = false): malody.TimedElement {.raises: [ParseError,ValueError].} =
    ## Hook to convert the provided JsonNode to the appropiate `TimeElement`.

    if self.kind != JsonNodeKind.JObject:
        if lenient:
            return malody.newTimedElement()
        raise newException(ParseError, "The kind of `JsonNode` must be `JObject`, but it's actual kind is `" & $self.kind & "`.")

    let beat = self.getBeatSafe()

    if self.hasField("bpm", JsonNodeKind.JFloat):
        result = malody.newTimeSignature(beat = beat, bpm = self.getFloatSafe("bpm"))

    elif self.hasField("type", JsonNodeKind.JInt) and self.hasField("sound", JsonNodeKind.JString):
        result = malody.newSoundCue(
            beat = beat,
            `type` = malody.getSoundCueType(self.getIntSafe("type")),
            offset = self.getFloatSafe("offset"),
            volume = self.getFloatSafe("vol")
        )
    elif self.hasField("index", JsonNodeKind.JInt):
        if self.fields.hasKey("endbeat"):
            result = malody.newIndexHold(
                beat = beat,
                index = self.getIntSafe("index"),
                endBeat = self.getBeatSafe("endbeat"),
                endIndex = self.getIntSafe("endindex")
            )
        else:
            result = malody.newIndexNote(
                beat = beat,
                index = self.getIntSafe("index")
            )
    elif self.hasField("column", JsonNodeKind.JInt):
        if self.fields.hasKey("endbeat"):
            result = malody.newColumnHold(
                beat = beat,
                column = self.getIntSafe("column"),
                style = self.getIntSafe("style", -1),
                endBeat = self.getBeatSafe("endbeat"),
                hits = self.getIntSafe("hits", 1)
            )
        else:
            result = malody.newColumnNote(
                beat = beat,
                column = self.getIntSafe("column"),
                style = self.getIntSafe("style", -1)
            )
    elif self.hasField("x", JsonNodeKind.JInt):
        if self.hasField("w", JsonNodeKind.JInt):
            var seg: seq[TimedElement] = @[]
            if self.fields.hasKey("seg"):
                seg.fromJson(self.fields["seg"], Joptions(allowMissingKeys: true, allowExtraKeys: true))

            result = malody.newSlideNote(
                beat = beat,
                x = self.getIntSafe("x"),
                width = self.getIntSafe("w"),
                `type` = getSlideNoteType(self.getIntSafe("type")),
                segments = seg
            )
        elif self.hasField("type", JsonNodeKind.JInt):
            if self.fields.hasKey("endbeat"):
                result = malody.newCatchHold(
                    beat = beat,
                    `type` = getCatchNoteType(self.getIntSafe("type")),
                    endBeat = self.getBeatSafe("endbeat")
                )
            else:
                result = malody.newCatchNote(
                    beat = beat,
                    `type` = getCatchNoteType(self.getIntSafe("type"))
                )
        else:
            result = malody.newTimedElement(beat = beat)
    else:
        result = malody.newTimedElement(beat = beat)

func toChart*(self: JsonNode, lenient: bool = false): malody.Chart {.raises:[ParseError,ValueError].} =
    ## Additional hook to make the hook for `TimedElement` work.

    if self.kind != JsonNodeKind.JObject:
        if lenient:
            return malody.newChart()
        raise newException(ParseError, "The kind of `JsonNode` must be `JObject`, but it's actual kind is `" & $self.kind & "`.")

    result = malody.newChart()

    if self.hasField("meta", JsonNodeKind.JObject):
        result.meta = self.fields["meta"].jsonTo(malody.MetaData, Joptions(allowMissingKeys: true, allowExtraKeys: true))

    if self.hasField("note", JsonNodeKind.JArray):
        for data in self.fields["note"].elems:
            let note = toTimedElement(data, lenient)
            result.note.add(note)

    if self.hasField("time", JsonNodeKind.JArray):
        for data in self.fields["time"].elems:
            let time = toTimedElement(data, lenient)
            result.time.add(time)

func toJsonHook*[T: malody.Chart](this: T): JsonNode =
    result = newJObject()
    result["meta"] = toJson(this.meta)
    result["time"] = newJArray()
    for time in this.time:
        result["time"].elems.add toJsonHook(time)

    result["note"] = newJArray()
    for note in this.note:
        result["note"].elems.add toJsonHook(note)

func toJsonHook*[T: malody.TimedElement](this: T): JsonNode =
    result = newJObject()
    result["beat"] = toJsonHook(this.beat)

    case this.kind:
    of malody.ElementType.TimeSignature:
        result["bpm"] = newJFloat(this.sigBpm)

    of malody.ElementType.SoundCue:
        result["type"] = newJInt(this.cueType.symbolRank)
        result["sound"] = newJString(this.cueSound)
        result["vol"] = newJFloat(this.cueVolume)

    of malody.ElementType.IndexNote:
        result["index"] = newJInt(this.index)
        if this.hold == malody.HoldType.IndexHold:
            result["endbeat"] = toJsonHook(this.indexEndBeat)
            result["endindex"] = newJInt(this.indexEnd)

    of malody.ElementType.ColumnNote:
        result["column"] = newJInt(this.column)
        result["style"] = newJInt(this.colStyle)
        if this.hold == malody.HoldType.ColumnHold:
            result["endbeat"] = toJsonHook(this.colEndBeat)
            result["hits"] = newJInt(this.colHits)

    of malody.ElementType.CatchNote:
        result["x"] = newJInt(this.catchX)
        result["type"] = newJInt(this.catchType.symbolRank)
        if this.hold == malody.HoldType.CatchHold:
            result["endbeat"] = toJsonHook(this.catchEndBeat)

    of malody.ElementType.SlideNote:
        result["x"] = newJInt(this.slideX)
        result["w"] = newJInt(this.slideWidth)
        result["type"] = newJInt(this.slideType.symbolRank)
        result["seg"] = newJArray()
        for e in this.slideSegments:
            result["seg"].elems.add toJsonHook(e)

    else:
        discard

func toJsonHook*[T: malody.Beat](this: T): JsonNode =
    result = newJArray()
    result.elems.add newJInt(this[0])
    result.elems.add newJInt(this[1])
    result.elems.add newJInt(this[2])

proc parseMalody*(data: string, lenient: bool = false): Chart =
    result = parseJson(data).toChart

proc parseMalody*(stream: Stream, lenient: bool = false): Chart =
    result = parseMalody(stream.readAll, lenient)

func write*(chart: Chart, pretty: bool = false): string =
    if pretty:
        result = toJsonHook(chart).pretty
    else:
        toUgly(result, toJson(chart))

proc write*(chart: Chart, stream: Stream, pretty: bool = false): void =
    stream.write(chart.write(pretty))
