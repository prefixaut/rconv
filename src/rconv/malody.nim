import ./common

{.experimental: "codeReordering".}

const
    EmptyBeat*: Beat = [-1, 0, 0]

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

func newChart*(meta: MetaData = newMetaData(), time: seq[TimedElement] = @[], note: seq[TimedElement] = @[]): Chart =
    result = Chart()
    result.meta = meta
    result.time = time
    result.note = note

func newMetaData*(`$ver`: int = 1, creator: string = "", background: string = "", version: string = "", preview: int = 0, id: uint = 0,
    mode: ChartMode = ChartMode.Key, time: int = 0, song: SongData = newSongData(), mode_ext: ModeData = newModeData()): MetaData =

    result = MetaData()
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

func newSongData*(title: string = "", titleorg: string = "", artist: string = "", artistorg: string = "", id: int = 0): SongData =
    result = SongData()
    result.title = title
    result.titleorg = titleorg
    result.artist = artist
    result.artistorg = artistorg
    result.id = id

func newModeData*(column: int = 0, bar_begin: int = 0, speed: int = 0): ModeData =
    result = ModeData()
    result.column = column
    result.bar_begin = bar_begin
    result.speed = speed

func newTimedElement*(beat: Beat = EmptyBeat): TimedElement =
    result = TimedElement(kind: ElementType.Plain, hold: HoldType.None)
    result.beat = beat

func newTimeSignature*(beat: Beat = EmptyBeat, bpm: float = 0): TimedElement =
    result = TimedElement(kind: ElementType.TimeSignature, hold: HoldType.None)
    result.beat = beat
    result.sigBpm = bpm

func newSoundCue*(beat: Beat = EmptyBeat, `type`: SoundCueType = SoundCueType.Effect, sound: string = "", offset: float = 0, volume: float = 0): TimedElement =
    result = TimedElement(kind: ElementType.SoundCue, hold: HoldType.None)
    result.beat = beat
    result.cueType = `type`
    result.cueSound = sound
    result.cueOffset = offset
    result.cueVolume = volume

proc newIndexNote*(beat: Beat = EmptyBeat, index: IndexRange = 0): TimedElement =
    result = TimedElement(kind: ElementType.IndexNote, hold: HoldType.None)
    result.beat = beat
    result.index = index

func newColumnNote*(beat: Beat = EmptyBeat, column: KeyColumnRange = 0, style: int = 0): TimedElement =
    result = TimedElement(kind: ElementType.ColumnNote, hold: HoldType.None)
    result.beat = beat
    result.column = column
    result.colStyle = style

func newCatchNote*(beat: Beat = EmptyBeat, x: int = 0, `type`: CatchNoteType = CatchNoteType.Hold): TimedElement =
    result = TimedElement(kind: ElementType.CatchNote, hold: HoldType.None)
    result.beat = beat
    result.catchX = x
    result.catchType = `type`

func newSlideNote*(beat: Beat = EmptyBeat, x: int = 0, width: int = 0, `type`: SlideNoteType = SlideNoteType.Hold, segments: seq[TimedElement] = @[]): TimedElement =
    result = TimedElement(kind: ElementType.SlideNote, hold: HoldType.None)
    result.beat = beat
    result.slideX = x
    result.slideWidth = width
    result.slideType = `type`
    result.slideSegments = segments

func newIndexHold*(beat: Beat = EmptyBeat, index: IndexRange, endBeat: Beat = EmptyBeat, endIndex: IndexRange): TimedElement =
    result = TimedElement(kind: ElementType.IndexNote, hold: HoldType.IndexHold)
    result.beat = beat
    result.index = index
    result.indexEndBeat = endBeat
    result.indexEnd = endIndex

func newColumnHold*(beat: Beat = EmptyBeat, column: KeyColumnRange = 0, style: int = 0, endBeat: Beat = EmptyBeat, hits: int = 1): TimedElement =
    result = TimedElement(kind: ElementType.ColumnNote, hold: HoldType.ColumnHold)
    result.beat = beat
    result.column = column
    result.colStyle = style
    result.colEndBeat = endBeat
    result.colHits = hits

func newCatchHold*(beat: Beat = EmptyBeat, x: int = 0, `type`: CatchNoteType = CatchNoteType.Hold, endBeat: Beat = EmptyBeat): TimedElement =
    result = TimedElement(kind: ElementType.CatchNote, hold: HoldType.CatchHold)
    result.beat = beat
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
