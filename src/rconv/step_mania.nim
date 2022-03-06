import std/[enumutils, strutils, sequtils, sugar, options]

import ./private/[line_reader, parser_helpers]

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
        beat*: float
        ## At which beat the change occurs
        bpm*: float
        ## To what BPM it should change

    Stop* = ref object
        beat*: float
        ## At which beat the stop occurs
        duration*: float
        ## For how long the stop holds on

    Delay* = ref object
        beat*: float
        ## At which beat the delay occurs
        duration*: float
        ## For how long the delay holds on

    TimeSignature* = ref object
        ## A time-signature change (ie. 3/4 or 7/8)
        beat*: float
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
        beat*: float
        ## At which beat the tick-count changes
        count*: int
        ## How many ticks it should change to

    BackgroundChange* = ref object
        ## A background change which occurrs at a specified time
        beat*: float
        ## The beat on which the change occurs
        path*: string
        ## The file path (or if it's a folder path, uses "default.lua") to the script file
        updateRate*: float
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
        ## An attack is a modifier which occurs at a time/note for a certain time
        length*: float
        ## For how long the attack is active
        mods*: seq[string]
        ## The modifiers which will be applied

    TimedAttack* = ref object of Attack
        ## An attack which happens at the specified time
        time*: float
        ## The time when the attack occurs

    Combo* = ref object
        ## Changes the combo count for hits/misses
        beat*: float
        ## When the combo-change should occur
        hit*: int
        ## How much a single hit should count to the combo
        miss*: int
        ## How many misses a single miss should count

    Speed* = ref object
        ## Modifies the speed of the chart by ratio
        beat*: float
        ## The beat where the speed-change occurs on
        ratio*: float
        ## The ratio that will be applied
        duration*: float
        ## How long it should take for the ratio to be applied (will be applied gradually)
        inSeconds*: bool
        ## If the duration is specified in seconds or in beats

    Scroll* = ref object
        ## Modifies the scroll speed bt a factor
        beat*: float
        ## The beat where the scroll-speed occurs on
        factor*: float
        ## The factor of how much the scoll changes compared to the regular speed

    FakeSection* = ref object
        ## Marker for a section to make all notes fakes
        beat*: float
        ## The beat from when the fake-section should begin from
        duration*: float
        ## How long the fake-section should last (in beats)

    Label* = ref object
        ## Label for a certain beat
        beat*: float
        ## The beat on which the label is placed on
        content*: string
        ## The text/content of the label

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
        banner*: string
        ## Path to the banner image
        background*: string
        ## Path to the background image
        lyricsPath*: string
        ## Path to the lyrics file
        cdTitle*: string
        ## Path to the cd-title image
        music*: string
        ## Path to the music file
        instrumentTracks*: seq[InstrumentTrack]
        ## A special track for different Instruments
        sampleStart*: float
        ## Timestamp where the preview/sample starts from
        sampleLength*: float
        ## How long the preview/sample should last
        displayBpm*: string
        ## Custom string to properly display the BPM
        selectable*: bool
        ## If this chart is selectable in the game
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
        keySounds*: seq[string]
        ## Keysound files to load
        offset*: float
        ## Sound/Music offset in ms
        stops*: seq[Stop]
        ## Stops/breaks in the song
        bpms*: seq[BpmChange]
        ## BPM changes
        timeSignatures*: seq[TimeSignature]
        ## Changes of Time-Signatures
        attacks*: seq[TimedAttack]
        ## Modifier changes in the song
        delays*: seq[Delay]
        ## The delays of the song (?)
        tickCounts*: seq[TickCount]
        ## The tick-counts for holds
        charts*: seq[Chart]
        ## The charts available for this song
        keySoundCharts*: seq[Chart]
        ## The charts for the keysounds
        combos*: seq[Combo]
        ## Combo changes
        speeds*: seq[Speed]
        ## Speed changes in the song
        scrolls*: seq[Scroll]
        ## Scroll-Speed changes in the song
        fakes*: seq[FakeSection]
        ## Fake sections in the song
        labels*: seq[Label]
        ## Labels for the song

func newBpmChange*(beat: float, bpm: float): BpmChange =
    new result
    result.beat = beat
    result.bpm = bpm

func newBpmChange*(beat: Option[float], bpm: Option[float]): BpmChange =
    result = newBpmChange(beat.get(0.0), bpm.get(0.0))

func newStop*(beat: float, duration: float): Stop =
    new result
    result.beat = beat
    result.duration = duration

func newStop*(beat: Option[float], duration: Option[float]): Stop =
    result = newStop(beat.get(0.0), duration.get(0.0))

func newDelay*(beat: float, duration: float): Delay =
    new result
    result.beat = beat
    result.duration = duration

func newDelay*(beat: Option[float], duration: Option[float]): Delay =
    result = newDelay(beat.get(0.0), duration.get(0.0))

func newTimeSignature*(beat: float, numerator: int, denominator: int): TimeSignature =
    new result
    result.beat = beat
    result.numerator = numerator
    result.denominator = denominator

func newTimeSignature*(beat: Option[float], numerator: Option[int], denominator: Option[int]): TimeSignature =
    result = newTimeSignature(beat.get(0.0), numerator.get(4), denominator.get(4))

func newInstrumentTrack*(instrument: string = "", file: string = ""): InstrumentTrack =
    new result
    result.instrument = instrument
    result.file = file

func newCombo*(beat: float, hit: int, miss: int): Combo =
    new result
    result.beat = beat
    result.hit = hit
    result.miss = miss

func newCombo*(beat: Option[float], hit: Option[int], miss: Option[int]): Combo =
    result = newCombo(beat.get(0.0), hit.get(1), miss.get(1))

func newSpeed*(beat: float, ratio: float, duration: float, inSeconds: bool): Speed =
    new result
    result.beat = beat
    result.ratio = ratio
    result.duration = duration
    result.inSeconds = inSeconds

func newSpeed*(beat: Option[float], ration: Option[float], duration: Option[float], inSeconds: Option[bool]): Speed =
    result = newSpeed(beat.get(0.0), ration.get(1.0), duration.get(0.0), inSeconds.get(false))

func newScroll*(beat: float, factor: float): Scroll =
    new result
    result.beat = beat
    result.factor = factor

func newScroll*(beat: Option[float], factor: Option[float]): Scroll =
    result = newScroll(beat.get(0.0), factor.get(1.0))

func newFakeSection*(beat: float, duration: float): FakeSection =
    new result
    result.beat = beat
    result.duration = duration

func newFakeSection*(beat: Option[float], duration: Option[float]): FakeSection =
    result = newFakeSection(beat.get(0.0), duration.get(0.0))

func newLabel*(beat: float = 0.0, content: string = ""): Label =
    new result
    result.beat = beat
    result.content = content

func newBackgroundChange*(
    beat: float = 0.0,
    path: string = "",
    updateRate: float = 0.0,
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

func newAttack*(length: float = 0.0, mods: seq[string] = @[]): Attack =
    new result
    result.length = length
    result.mods = mods

func newTimedAttack*(time: float, length: float, mods: seq[string] = @[]): TimedAttack =
    new result
    result.time = time
    result.length = length
    result.mods = mods

func newTimedAttack*(time: Option[float], length: Option[float], mods: seq[string] = @[]): TimedAttack =
    result = newTimedAttack(time.get(0.0), length.get(0.0), mods)

func newTickCount*(beat: float, count: int): TickCount =
    new result
    result.beat = beat
    result.count = count

func newTickCount*(beat: Option[float], count: Option[int]): TickCount =
    result = newTickCount(beat.get(0.0), count.get(4))

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
    titleTransliterated: string = "",
    subtitleTransliterated: string = "",
    artistTransliterated: string = "",
    genre: string = "",
    credit: string = "",
    banner: string = "",
    background: string = "",
    lyricsPath: string = "",
    cdTitle: string = "",
    music: string = "",
    instrumentTracks: seq[InstrumentTrack] = @[],
    sampleStart: float = 0.0,
    sampleLength: float = 0.0,
    displayBpm: string = "",
    selectable: bool = true,
    bgChanges: seq[BackgroundChange] = @[],
    bgChanges2: seq[BackgroundChange] = @[],
    bgChanges3: seq[BackgroundChange] = @[],
    animations: seq[BackgroundChange] = @[],
    fgChanges: seq[BackgroundChange] = @[],
    keySounds: seq[string] = @[],
    offset: float = 0.0,
    stops: seq[Stop] = @[],
    bpms: seq[BpmChange] = @[],
    timeSignatures: seq[TimeSignature] = @[],
    attacks: seq[TimedAttack] = @[],
    delays: seq[Delay] = @[],
    tickCounts: seq[TickCount] = @[],
    charts: seq[Chart] = @[],
    keySoundCharts: seq[Chart] = @[],
    combos: seq[Combo] = @[],
    speeds: seq[Speed] = @[],
    scrolls: seq[Scroll] = @[],
    fakes: seq[FakeSection] = @[],
    labels: seq[Label] = @[],
): ChartFile =
    new result
    result.title = title
    result.subtitle = subtitle
    result.artist = arist
    result.titleTransliterated = titleTransliterated
    result.subtitleTransliterated = subtitleTransliterated
    result.artistTransliterated = artistTransliterated
    result.genre = genre
    result.credit = credit
    result.music = music
    result.instrumentTracks = instrumentTracks
    result.keySounds = keySounds
    result.banner = banner
    result.background = background
    result.lyricsPath = lyricsPath
    result.cdTitle = cdTitle
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
    result.combos = combos
    result.speeds = speeds
    result.scrolls = scrolls
    result.fakes = fakes
    result.labels = labels

func isYes(str: string): bool =
    return str.toLower in ["yes", "1", "es", "omes"]

func splitByComma(data: string): seq[string] =
    result = @[]
    if data.contains(","):
        result = data.split(",").filter(s => s.strip.len > 0)
    elif not data.isEmptyOrWhitespace:
        result = @[data]

func parseIntrumentTracks(data: string): seq[InstrumentTrack] =
    result = @[]
    for elem in data.splitByComma:
        let spl = elem.split("=")
        if spl.len >= 2:
            result.add(newInstrumentTrack(spl[0], spl[1]))

proc parseColor(data: string): Color =
    if data.strip.len == 0:
        return [0.0, 0.0, 0.0, 0.0]

    var spl = data.replace("^", ",").split(",")
    for i in spl.len..4:
        spl.add "0"
    result = [
        parseFloatSafe(spl[0]).get(0.0),
        parseFloatSafe(spl[1]).get(0.0),
        parseFloatSafe(spl[2]).get(0.0),
        parseFloatSafe(spl[3]).get(0.0)
    ]

proc parseBackgroundChanges(data: string): seq[BackgroundChange] =
    result = @[]
    for elem in data.splitByComma:
        var spl = elem.splitMin("=", 11)

        result.add newBackgroundChange(
            beat = parseFloatSafe(spl[0]).get(0.0),
            path = spl[1],
            updateRate = parseFloatSafe(spl[2]).get(0.0),
            crossFade = parseBoolSafe(spl[3]).get(false),
            stretchRewind = parseBoolSafe(spl[4]).get(false),
            stretchNoLoop = parseBoolSafe(spl[5]).get(false),
            effect = spl[6],
            file2 = spl[7],
            transition = spl[8],
            color1 = parseColor(spl[9]),
            color2 = parseColor(spl[10])
        )

func parseStops(data: string): seq[Stop] =
    result = @[]
    for elem in data.splitByComma:
        let spl = elem.splitMin("=", 2)
        result.add newStop(parseFloatSafe(spl[0]), parseFloatSafe(spl[1]))

func parseBpms(data: string): seq[BpmChange] =
    result = @[]
    for elem in data.splitByComma:
        let spl = elem.splitMin("=", 2)
        result.add newBpmChange(parseFloatSafe(spl[0]), parseFloatSafe(spl[1]))

func parseTimeSignatures(data: string): seq[TimeSignature] =
    result = @[]
    for elem in data.splitByComma:
        let spl = elem.split("=", 3)
        result.add newTimeSignature(parseFloatSafe(spl[0]), parseIntSafe(spl[1]), parseIntSafe(spl[2]))

func parseAttack(data: string): Attack =
    let spl = data.splitMin(":", 2)
    result = newAttack(parseFloatSafe(spl[1]).get(0.0), spl[0].splitByComma)

func parseTimedAttacks(data: string): seq[TimedAttack] =
    result = @[]
    for elem in data.splitByComma:
        var time = none[float]()
        var length = none[float]()
        var eend = none[float]()
        var mods: seq[string] = @[]

        for part in elem.split(":"):
            let spl = part.split("=")

            case spl[0].toLower:
            of "time":
                time = parseFloatSafe(spl[1])
            of "len":
                length = parseFloatSafe(spl[1])
            of "end":
                eend = parseFloatSafe(spl[1])
            of "mods":
                for tmp in spl[1].splitByComma:
                    mods.add tmp

            if eend.isSome and time.isSome:
                length = some(eend.get - time.get)

            result.add newTimedAttack(time, length, mods)

func parseDelays(data: string): seq[Delay] =
    result = @[]
    for elem in data.splitByComma:
        let spl = elem.splitMin("=", 2)
        result.add newDelay(parseFloatSafe(spl[0]), parseFloatSafe(spl[1]))

func parseTickCounts(data: string): seq[TickCount] =
    result = @[]
    for elem in data.splitByComma:
        let spl = elem.splitMin("=", 2)
        result.add newTickCount(parseFloatSafe(spl[0]), parseIntSafe(spl[1]))

func parseCombos(data: string): seq[Combo] =
    result = @[]
    for elem in data.splitByComma:
        let spl = elem.splitMin("=", 3)
        result.add newCombo(parseFloatSafe(spl[0]), parseIntSafe(spl[1]), parseIntSafe(spl[2]))

func parseSpeeds(data: string): seq[Speed] =
    result = @[]
    for elem in data.splitByComma:
        let spl = elem.splitMin("=", 4)
        result.add newSpeed(parseFloatSafe(spl[0]), parseFloatSafe(spl[1]), parseFloatSafe(spl[2]), parseBoolSafe(spl[3]))

func parseScrolls(data: string): seq[Scroll] =
    result = @[]
    for elem in data.splitByComma:
        let spl = elem.splitMin("=", 2)
        result.add newScroll(parseFloatSafe(spl[0]), parseFloatSafe(spl[1]))

func parseFakeSections(data: string): seq[FakeSection] =
    result = @[]
    for elem in data.splitByComma:
        let spl = elem.splitMin("=", 2)
        result.add newFakeSection(parseFloatSafe(spl[0]), parseFloatSafe(spl[1]))

func parseLabels(data: string): seq[Label] =
    result = @[]
    for elem in data.splitByComma:
        let spl = elem.splitMin("=", 2)
        if spl.len > 1:
            result.add newLabel(parseFloat(spl[0]), spl[1])

func parseRadarValues(data: string): RadarValues =
    var spl = data.splitMin(",", 5, "0")

    result = [
        parseFloatSafe(spl[0]).get(0.0),
        parseFloatSafe(spl[1]).get(0.0),
        parseFloatSafe(spl[2]).get(0.0),
        parseFloatSafe(spl[3]).get(0.0),
        parseFloatSafe(spl[4]).get(0.0)
    ]

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
    of "banner":
        chart.banner = data
    of "background":
        chart.background = data
    of "lyricspath":
        chart.lyricsPath = data
    of "cdtitle":
        chart.cdTitle = data
    of "music":
        chart.music = data
    of "instrumenttracks":
        chart.instrumentTracks = parseIntrumentTracks(data)
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
    of "delays", "warps":
        chart.delays = parseDelays(data)
    of "tickcounts":
        chart.tickCounts = parseTickCounts(data)
    of "notes":
        chart.charts.add parseChart(data)
    of "notes2":
        chart.keySoundCharts.add parseChart(data)
    of "combos":
        chart.combos = parseCombos(data)
    of "speeds":
        chart.speeds = parseSpeeds(data)
    of "scrolls":
        chart.scrolls = parseScrolls(data)
    of "fakes":
        chart.fakes = parseFakeSections(data)
    of "labels":
        chart.labels = parseLabels(data)
    else:
        discard

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
