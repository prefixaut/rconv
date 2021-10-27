{.experimental: "codeReordering".}

type
    Chart* = object
        meta*: MetaData
        ## Meta data of the chart, such as version, creator and song data
        time*: seq[TimeSignature]
        ## Time signatures of the chart (BPM changes)
        note*: seq[TimedElement]
        ## Notes, Holds and other timed gameplay elements

    ChartType* {.pure.} = enum
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
        mode*: ChartType
        ## Mode of the Chart (For which game-mode this chart is available)
        time*: int
        ## Timestamp of when the chart was edited the last time
        song*: SongData
        ## Song meta-data

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
        id*: uint
        ## ID combination of the title & artist (only for ranked)

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
        ## 

    TimeSignature* = object of TimedElement
        bpm*: float

    SoundCue* = object of TimedElement
        `type`*: int
        sound*: string
        offset*: int
        vol*: float

    Note* = object of TimedElement
        index*: uint

    Hold* = object of Note
        endbeat*: Beat
        endindex*: int
