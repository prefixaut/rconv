import std/[enumutils, strutils]

import ./private/line_reader

type
    NoteType* {.pure.} = enum
        ## The type of notes that can be present in a SM file
        Empty = "0"
        ## No note
        Note = "1"
        ## Regular Note
        Hold = "2"
        ## Hold start/head
        HoldEnd = "3"
        ## Hold/Roll end/tail
        Roll = "4"
        ## Roll start/head
        Mine = "M"
        ## A single Mine
        Lift = "L"
        ## Hold but with a timed release
        Fake = "F"
        ## Notes which can't be hit
        Attack = "A"
        ## ???
        Keysound = "K"
        ## ?????????
        Minefield = "N"
        ## More mines ???
        Hidden = "H"
        ## A Ghost note

    GameMode* {.pure.} = enum
        ## The type of the game-mode for which the chart is for
        DanceSingle = "dance-single"
        ## 4k
        DanceDouble = "dance-double"
        ## 8k
        DanceCouple = "dance-couple"
        ## 8k
        DanceRoutine = "dance-routine"
        ## 8k
        DanceSolo = "dance-solo"
        ## 6k
        PumpSingle = "pump-single"
        ## 5k
        PumpHalfdouble = "pump-halfdouble"
        ## 6k
        PumpDouble = "pump-double"
        ## 10k
        PumpCouple = "pump-couple"
        ## 10k

    Difficulty* {.pure.} = enum
        ## The difficulty of a chart.
        ## The same difficulty may only be defined once with the same game-mode, except for the Edit.
        ## Edit-Difficulties may be present unlimited amount of times.
        Beginner = "Beginner"
        Easy = "Easy"
        Medium = "Medium"
        Hard = "Hard"
        Challange = "Challange"
        Edit = "Edit"

    Color* = array[4, float] ## \
    ## A rgba color representation

    RadarValues* = array[5, float] ## \
    ## Radar values from SM 3.9 (Stream, Voltage, Air, Freeze & Chaos)

    BpmChange* = ref object
        ## A bpm-change in a song
        beat*: float32
        ## At which beat the change occurs
        bpm*: float32
        ## To what BPM it should change

    Stop* = ref object
        beat*: float32
        ## At which beat the stop occurs
        duration*: float32
        ## For how long the stop holds on

    Delay* = ref object
        beat*: float32
        ## At which beat the delay occurs
        duration*: float32
        ## For how long the delay holds on

    TimeSignature* = ref object
        ## A time-signature change (ie. 3/4 or 7/8)
        beat*: float32
        ## At which point the time-signature changes
        numerator*: int
        ## The numerator of the signature
        denominator*: int
        ## The deniminator of the signature

    InstrumentTrack* = ref object
        ## A special track for a single instrument
        instrument*: string
        ## The instrument name
        file*: string
        ## The file-path to the track/song

    TickCount* = ref object
        ## Specifies how many checkpoints a hold has in a beat.
        beat*: float32
        ## At which beat the tick-count changes
        count*: int
        ## How many ticks it should change to

    BackgroundChange* = ref object
        ## A background change which occurrs at a specified time
        beat*: float32
        ## The beat on which the change occurs
        path*: string
        ## The file path (or if it's a folder path, uses "default.lua") to the script file
        updateRate*: float32
        ## How often the change is updated
        crossFade*: bool
        ## If it should use the cross-fade effect (overruled by `effect`)
        stretchRewind*: bool
        ## If it should use the stretch-rewind effect (overruled by `effect`)
        stretchNoLoop*: bool
        ## If it should use the stretch-noloop effect (overruled by `effect`)
        effect*: string
        ## The background-effect to use
        file2*: string
        ## The second file to load/use
        transition*: string
        ## The the background transitions to this state
        color1*: Color
        ## First color passed to the script files
        color2*: Color
        ## Second color passed to the script files

    Attack* = ref object of RootObj
        ## The time when the attack occurs
        length*: float
        ## For how long the attack is active
        mods*: seq[string]
        ## The modifiers which will be applied

    TimedAttack* = ref object of Attack
        ## An attack is a modifier which occurs at a time for a certain time
        time*: float

    Note* = ref object
        ## A single note to be played
        attack*: Attack
        ## The attack to apply when the note is played
        keysound*: int
        ## Keysound which has to be played when hit
        case kind*: NoteType:
            ## The kind of the note
            of Hold:
                holdEndBeat*: int
                ## On which beat the hold has to end
                holdEndSnap*: int
                ## At which snap-index in the beat the hold has to end
            of Roll:
                rollEndBeat*: int
                ## On which beat the roll has to end
                rollEndSnap*: int
                ## At which snap-index in the beat the roll has to end
            else:
                discard

    Beat* = ref object
        ## A single beat which is divided into more snaps
        snapSize*: int
        ## The amount of snaps that exist in this beat
        notes*: seq[Note]
        ## All notes in this beat

    Chart* = ref object
        ## A single chart (difficulty for a game-mode)
        gameMode*: GameMode
        ## The game-mode of the chart
        chartArtist*: string
        ## The charter/chart-artist
        difficulty*: Difficulty
        ## The difficulty of the chart
        difficultyLevel*: int
        ## The difficulty-level of the chart
        radarValues*: RadarValues
        ## The radar values of the chart
        beats*: seq[Beat]

    ChartFile* = ref object
        ## A chart-file which represents a single song with multiple charts (difficulties/game-modes)
        title*: string
        ## The Song-Title
        subtitle*: string
        ## The Sub-Title of the Song (Usually extras like "xyz Remix" or memes)
        artist*: string
        ## Artist of the Song
        titleTransliterated*: string
        ## If the title is in a foreign language, then this one should be the translated one (to english usually)
        subtitleTransliterated*: string
        ## If the subtitle is in a foreign language, then this one should be the translated one (to english usually)
        artistTransliterated*: string
        ## If the arist is in a foreign language, then this one should be the translated one (to english usually)
        genre*: string
        ## Genre of the Song
        credit*: string
        ## Credits of the Song (Usually the charter)
        music*: string
        ## Path to the music file
        instrumentTracks: seq[InstrumentTrack]
        ## A special track for different Instruments
        keySounds*: seq[string]
        ## Keysound files to load
        banner*: string
        ## Path to the banner image
        background*: string
        ## Path to the background image
        lyricsPath*: string
        ## Path to the lyrics file
        cdTitle*: string
        ## Path to the cd-title image
        menuColor*: string
        ## The menu-color
        sampleStart*: float32
        ## Timestamp where the preview/sample starts from
        sampleLength*: float32
        ## How long the preview/sample should last
        selectable*: bool
        ## If this chart is selectable in the game
        offset*: float32
        ## Sound/Music offset in ms
        timeSignatures*: seq[TimeSignature]
        ## Changes of Time-Signatures
        bgChanges*: seq[BackgroundChange]
        ## Background-Changes for the background-layer 1
        bgChanges2*: seq[BackgroundChange]
        ## Background-Changes for the background-layer 2
        bgChanges3*: seq[BackgroundChange]
        ## Background-Changes for the background-layer 3
        animations*: seq[BackgroundChange]
        ## Animations to play during the song
        fgChanges*: seq[BackgroundChange]
        ## Background-Changes for the foreground-layer
        attacks*: seq[TimedAttack]
        ## Modifier changes in the song
        stops*: seq[Stop]
        ## Stops/breaks in the song
        delays*: seq[Delay]
        ## The delays of the song (?)
        bpms*: seq[BpmChange]
        ## BPM changes
        displayBpm*: string
        ## Custom string to properly display the BPM
        tickCounts*: seq[TickCount]
        ## The tick-counts for holds
        charts*: seq[Chart]
        ## The charts available for this song
        keySoundCharts*: seq[Chart]
        ## The charts for the keysounds

func newBpmChange*(beat: float32 = 0.0, bpm: float32 = 0.0): BpmChange =
    new result
    result.beat = beat
    result.bpm = bpm

func newStop*(beat: float32 = 0.0, duration: float32 = 0.0): Stop =
    new result
    result.beat = beat
    result.duration = duration

func newDelay*(beat: float32 = 0.0, duration: float32 = 0.0): Delay =
    new result
    result.beat = beat
    result.duration = duration

func newTimeSignature*(beat: float32 = 0.0, numerator: int = 4, denominator: int = 4): TimeSignature =
    new result
    result.beat = beat
    result.numerator = numerator
    result.denominator = denominator

func newInstrumentTrack*(instrument: string = "", file: string = ""): InstrumentTrack =
    new result
    result.instrument = instrument
    result.file = file

func newBackgroundChange*(
    beat: float32 = 0.0,
    path: string = "",
    updateRate: float32 = 0.0,
    crossFade: bool = false,
    stretchRewind: bool = false,
    stretchNoLoop: bool = false,
    effect: string = "",
    file2: string = "",
    transition: string = "",
    color1: Color = [0.0, 0.0, 0.0, 0.0],
    color2: Color = [0.0, 0.0, 0.0, 0.0]
): BackgroundChange =
    new result
    result.beat = beat
    result.path = path
    result.updateRate = updateRate
    result.crossFade = crossFade
    result.stretchRewind = stretchRewind
    result.stretchNoLoop = stretchNoLoop
    result.effect = effect
    result.file2 = file2
    result.transition = transition
    result.color1 = color1
    result.color2 = color2

func newAttack*(length: float32 = 0.0, mods: seq[string] = @[]): Attack =
    new result
    result.length = length
    result.mods = mods

func newTimedAttack*(time: float32 = 0.0, length: float32 = 0.0, mods: seq[string] = @[]): TimedAttack =
    new result
    result.time = time
    result.length = length
    result.mods = mods

func newTickCount*(beat: float32 = 0.0, count: int = 4): TickCount =
    new result
    result.beat = beat
    result.count = count

func newNote*(kind: NoteType = NoteType.Note, attack: Attack = nil, keysound: int = -1): Note =
    result = Note(kind: kind)
    result.attack = attack
    result.keysound = keysound

func newBeat*(snapSize: int = 0, notes: seq[Note] = @[]): Beat =
    new result
    result.snapSize = snapSize
    result.notes = notes

func newChart*(
    gameMode: GameMode,
    chartArtist: string = "",
    difficulty: Difficulty = Difficulty.Beginner,
    difficultyLevel: int = 1,
    beats: seq[Beat] = @[]
): Chart =
    new result
    result.gameMode = gameMode
    result.chartArtist = chartArtist
    result.difficulty = difficulty
    result.difficultyLevel = difficultyLevel
    result.beats = beats

func newChartFile*(
    title: string = "",
    subtitle: string = "",
    arist: string = "",
    titleTranslated: string = "",
    subtitleTranslated: string = "",
    aristTranslated: string = "",
    genre: string = "",
    credit: string = "",
    music: string = "",
    instrumentTracks: seq[InstrumentTrack] = @[],
    keySounds: seq[string] = @[],
    banner: string = "",
    background: string = "",
    lyricsPath: string = "",
    cdTitle: string = "",
    menuColor: string = "",
    sampleStart: float32 = 0.0,
    sampleLength: float32 = 0.0,
    selectable: bool = true,
    offset: float32 = 0.0,
    timeSignatures: seq[TimeSignature] = @[],
    bgChanges: seq[BackgroundChange] = @[],
    bgChanges2: seq[BackgroundChange] = @[],
    bgChanges3: seq[BackgroundChange] = @[],
    animations: seq[BackgroundChange] = @[],
    fgChanges: seq[BackgroundChange] = @[],
    attacks: seq[TimedAttack] = @[],
    stops: seq[Stop] = @[],
    delays: seq[Delay] = @[],
    bpms: seq[BpmChange] = @[],
    displayBpm: string = "",
    tickCounts: seq[TickCount] = @[],
    charts: seq[Chart] = @[],
    keySoundCharts: seq[Chart] = @[]
): ChartFile =
    new result
    result.title = title
    result.subtitle = subtitle
    result.artist = arist
    result.titleTransliterated = titleTranslated
    result.subtitleTransliterated = subtitleTranslated
    result.artistTransliterated = aristTranslated
    result.genre = genre
    result.credit = credit
    result.music = music
    result.instrumentTracks = instrumentTracks
    result.keySounds = keySounds
    result.banner = banner
    result.background = background
    result.lyricsPath = lyricsPath
    result.cdTitle = cdTitle
    result.menuColor = menuColor
    result.sampleStart = sampleStart
    result.sampleLength = sampleLength
    result.selectable = selectable
    result.offset = offset
    result.timeSignatures = timeSignatures
    result.bgChanges = bgChanges
    result.bgChanges2 = bgChanges2
    result.bgChanges3 = bgChanges3
    result.animations = animations
    result.fgChanges = fgChanges
    result.attacks = attacks
    result.stops = stops
    result.delays = delays
    result.bpms = bpms
    result.displayBpm = displayBpm
    result.tickCounts = tickCounts
    result.charts = charts
    result.keySoundCharts = keySoundCharts

func isYes(str: string): bool =
    return str.toLower in ["yes", "1", "es", "omes"]

func splitByComma(data: string): seq[string] =
    if data.contains(","):
        result = data.split(",")
    else:
        result = @[data]

func parseIntrumentTracks(data: string): seq[InstrumentTrack] =
    result = @[]
    for elem in data.splitByComma:
        let spl = elem.split("=")
        if spl.len >= 2:
            result.add(newInstrumentTrack(instrument = spl[0], file = spl[1]))

proc parseColor(data: string): Color =
    if data.strip.len == 0:
        return [0.0, 0.0, 0.0, 0.0]

    var spl = data.replace("^", ",").split(",")
    for i in spl.len..4:
        spl.add "0"
    result = [parseFloat(spl[0]), parseFloat(spl[1]), parseFloat(spl[2]), parseFloat(spl[3])]

proc parseBackgroundChanges(data: string): seq[BackgroundChange] =
    result = @[]
    for elem in data.splitByComma:
        var spl = elem.split("=")
        ## Fill up the seq to have 11 elements
        for i in spl.len..11:
            spl.add ""

        result.add newBackgroundChange(
            beat = parseFloat(spl[0]),
            path = spl[1],
            updateRate = parseFloat(spl[2]),
            crossFade = spl[3].toLower == "1",
            stretchRewind = spl[4].toLower == "1",
            stretchNoLoop = spl[5].toLower == "1",
            effect = spl[6],
            file2 = spl[7],
            transition = spl[8],
            color1 = parseColor(spl[9]),
            color2 = parseColor(spl[10])
        )

func parseStops(data: string): seq[Stop] =
    result = @[]
    for elem in data.splitByComma:
        let spl = elem.split("=")
        result.add newStop(beat = parseFloat(spl[0]), duration = parseFloat(spl[1]))

func parseBpms(data: string): seq[BpmChange] =
    result = @[]
    for elem in data.splitByComma:
        let spl = elem.split("=")
        result.add newBpmChange(beat = parseFloat(spl[0]), bpm = parseFloat(spl[1]))

func parseTimeSignatures(data: string): seq[TimeSignature] =
    result = @[]
    for elem in data.splitByComma:
        let spl = elem.split("=")
        result.add newTimeSignature(beat = parseFloat(spl[0]), numerator = parseInt(spl[1]), denominator = parseInt(spl[2]))

func parseAttack(data: string): Attack =
    let spl = data.split(":")
    result = newAttack(parseFloat(spl[1]), spl[0].splitByComma)

func parseTimedAttacks(data: string): seq[TimedAttack] =
    result = @[]
    for elem in data.splitByComma:
        var start = 0.0
        var len = 0.0
        var eend = 0.0
        var mods: seq[string] = @[]

        for part in elem.split(":"):
            let spl = part.split("=")

            case spl[0].toLower:
            of "time":
                start = parseFloat(spl[1])
            of "len":
                len = parseFloat(spl[1])
            of "end":
                eend = parseFloat(spl[1])
            of "mods":
                for tmp in spl[1].splitByComma:
                    mods.add tmp

            if eend > 0:
                len = eend - start
            
            result.add newTimedAttack(time = start, length = len, mods = mods)

func parseDelays(data: string): seq[Delay] =
    result = @[]
    for elem in data.splitByComma:
        let spl = elem.split("=")
        result.add newDelay(beat = parseFloat(spl[0]), duration = parseFloat(spl[1]))

func parseTickCounts(data: string): seq[TickCount] =
    result = @[]
    for elem in data.splitByComma:
        let spl = elem.split("=")
        result.add newTickCount(parseFloat(spl[0]), parseInt(spl[1]))

func parseRadarValues(data: string): RadarValues =
    let spl = data.splitByComma
    result = [parseFloat(spl[0]), parseFloat(spl[1]), parseFloat(spl[2]), parseFloat(spl[3]), parseFloat(spl[4])]

func columnCount(mode: GameMode): int =
    result = 4

    case mode:
    of GameMode.DanceSingle:
        result = 4
    of GameMode.PumpSingle:
        result = 5
    of GameMode.DanceSolo, GameMode.PumpHalfdouble:
        result = 6
    of GameMode.DanceCouple, GameMode.DanceDouble, GameMode.DanceRoutine:
        result = 8
    of GameMode.PumpCouple, GameMode.PumpDouble:
        result = 10
    else:
        discard

func parseBeats(data: string, columns: int): seq[Beat] =
    result = @[]

    var beat = newBeat()
    var lastNote: Note = nil
    var noteIndex = 0
    var inAttack = false
    var attackData = ""
    var inKeysound = false
    var keysoundData = ""

    for str in data:
        if inAttack:
            if str == '}':
                inAttack = false
                lastNote.attack = parseAttack(attackData)
                continue
            attackData &= str
            continue
        elif str == '{':
            inAttack = true
            continue

        if inKeysound:
            if str == ']':
                inKeysound = false
                lastNote.keySound = parseInt(keysoundData)
                continue
            keysoundData &= str
            continue
        elif str == '[':
            inKeysound = true
            continue

        if str == ',':
            result.add beat
            beat = newBeat()
            noteIndex = 0
            continue

        lastNote = newNote(parseEnum[NoteType]($str))
        beat.notes.add lastNote
        inc noteIndex

        if noteIndex >= columns:
            inc beat.snapSize
            noteIndex = 0

    inc beat.snapSize
    result.add beat

func parseChart(data: string): Chart =
    let meta = data.split(":", 5)
    let mode = parseEnum[GameMode](meta[0])
    let diff = parseEnum[Difficulty](meta[2])
    let columns = columnCount(mode)

    result = Chart()
    result.gameMode = mode
    result.chartArtist = meta[1]
    result.difficulty = diff
    result.difficultyLevel = parseInt(meta[3])
    result.radarValues = parseRadarValues(meta[4])
    result.beats = parseBeats(meta[5], columns)

func putFileData(chart: var ChartFile, tag: string, data: string): void =
    if data.strip.len == 0:
        return

    case tag.toLower:
    of "title":
        chart.title = data
    of "subtitle":
        chart.subtitle = data
    of "artist":
        chart.artist = data
    of "titletranslit":
        chart.titleTransliterated = data
    of "subtitletranslit":
        chart.subtitleTransliterated = data
    of "artisttranslit":
        chart.artistTransliterated = data
    of "genre":
        chart.genre = data
    of "credit":
        chart.credit = data
    of "music":
        chart.music = data
    of "instrumenttracks":
        chart.instrumentTracks = parseIntrumentTracks(data)
    of "banner":
        chart.banner = data
    of "background":
        chart.background = data
    of "lyricspath":
        chart.lyricsPath = data
    of "cdtitle":
        chart.cdTitle = data
    of "samplestart":
        chart.sampleStart = parseFloat(data)
    of "samplelength":
        chart.sampleLength = parseFloat(data)
    of "displaybpm":
        chart.displayBpm = data
    of "selectable":
        chart.selectable = data.isYes
    of "bgchanges":
        chart.bgChanges = parseBackgroundChanges(data)
    of "bgchanges2":
        chart.bgChanges2 = parseBackgroundChanges(data)
    of "bgchanges3":
        chart.bgChanges2 = parseBackgroundChanges(data)
    of "animations":
        chart.animations = parseBackgroundChanges(data)
    of "fgchanges":
        chart.fgChanges = parseBackgroundChanges(data)
    of "keysounds":
        chart.keySounds = data.split(",")
    of "offset":
        chart.offset = parseFloat(data)
    of "stops", "freezes":
        chart.stops = parseStops(data)
    of "bpms":
        chart.bpms = parseBpms(data)
    of "timesignatures":
        chart.timeSignatures = parseTimeSignatures(data)
    of "attacks":
        chart.attacks = parseTimedAttacks(data)
    of "delays":
        chart.delays = parseDelays(data)
    of "tickcounts":
        chart.tickCounts = parseTickCounts(data)
    of "notes":
        chart.charts.add parseChart(data)
    of "notes2":
        chart.keySoundCharts.add parseChart(data)

proc parseStepMania*(data: string): ChartFile =
    result = newChartFile()

    var reader = newLineReader(data)
    var inMeta = false
    var tag = ""
    var data = ""

    while not reader.isEOF():
        let line = reader.nextLine()

        if inMeta:
            let eend = line.find(";")
            if eend > -1:
                data &= line.substr(0, eend - 1)
                putFileData(result, tag, data)

                tag = ""
                data = ""
                inMeta = false
            else:
                data &= line
            continue

        if line.startsWith("#"):
            let sep = line.find(":")
            let eend = line.find(";")
            tag = line.substr(1, sep - 1).strip

            if eend > -1:
                putFileData(result, tag, line.substr(sep + 1, eend - 1))
                tag = ""
            else:
                data = line.substr(sep + 1)
                inMeta = true
            continue
