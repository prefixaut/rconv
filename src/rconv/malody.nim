{.experimental: "codeReordering".}

type
    Chart* = object
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
        `type`*: int
        ## Type of Sound-Cue that should be played
        sound*: string
        ## (Relative) File-Path to the sound-file to play
        offset*: int
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
