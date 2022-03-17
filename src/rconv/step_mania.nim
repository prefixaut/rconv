import std/[enumutils, sequtils, strutils, options, sugar]

import ./common
import ./private/[parser_helpers, simfile_common, simfile_helper]

export simfile_common

{.experimental: "codeReordering".}

type
    InvalidNoteError* = object of ParseError
        ## Exception which is thrown when a Note is invalidly placed.
        beat*: int
        ## The beat where the note is placed in
        note*: Note
        ## The note that caused an error

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
        Keysound = "K"
        ## Special Keysound note ... ?
        Hidden = "H"
        ## A Ghost note

    Note* = ref object
        ## A single note to be played
        snap*: int
        ## On which snap this note is
        column*: int
        ## On which column the Note is placed on
        attack*: Attack
        ## The attack to apply when the note is played
        keysound*: int
        ## Keysound which has to be played when hit
        modifiers*: seq[Modifier]
        ## Modifiers to apply only for this note

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
        index*: int
        ## The index of the beat
        snapSize*: int
        ## The amount of snaps that exist in this beat
        notes*: seq[Note]
        ## All notes in this beat

    NoteData* = ref object
        ## A single chart (difficulty for a game-mode)
        chartType*: ChartType
        ## The game-mode of the chart
        description*: string
        ## The description of the chart
        difficulty*: Difficulty
        ## The difficulty of the chart
        difficultyLevel*: int
        ## The difficulty-level of the chart
        radarValues*: RadarValues
        ## The radar values of the chart
        beats*: seq[Beat]
        ## The individual beats of the chart

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
        noteData*: seq[NoteData]
        ## The noteData available for this song
        combos*: seq[ComboChange]
        ## Combo changes
        speeds*: seq[SpeedChange]
        ## Speed changes in the song
        scrolls*: seq[ScollSpeedChange]
        ## Scroll-Speed changes in the song
        fakes*: seq[FakeSection]
        ## Fake sections in the song
        labels*: seq[Label]
        ## Labels for the song

func newNoteError(msg: string, beat: int, note: Note): ref InvalidNoteError =
    result = newException(InvalidNoteError, msg)
    result.beat = beat
    result.note = note

func newTimedAttack*(time: float, length: float, mods: seq[Modifier] = @[]): TimedAttack =
    new result
    result.time = time
    result.length = length
    result.mods = mods

func newTimedAttack*(time: Option[float], length: Option[float], mods: seq[Modifier] = @[]): TimedAttack =
    result = newTimedAttack(time.get(0.0), length.get(0.0), mods)

func newNote*(kind: NoteType, snap: int, column: int, attack: Attack = nil, keysound: int = -1): Note =
    result = Note(kind: kind)
    result.snap = snap
    result.column = column
    result.attack = attack
    result.keysound = keysound

func newBeat*(index: int, snapSize: int = 0, notes: seq[Note] = @[]): Beat =
    new result
    result.index = index
    result.snapSize = snapSize
    result.notes = notes

func newNoteData*(
    chartType: ChartType,
    description: string = "",
    difficulty: Difficulty = Difficulty.Beginner,
    difficultyLevel: int = 1,
    beats: seq[Beat] = @[]
): NoteData =
    new result
    result.chartType = chartType
    result.description = description
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
    noteData: seq[NoteData] = @[],
    combos: seq[ComboChange] = @[],
    speeds: seq[SpeedChange] = @[],
    scrolls: seq[ScollSpeedChange] = @[],
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
    result.noteData = noteData
    result.combos = combos
    result.speeds = speeds
    result.scrolls = scrolls
    result.fakes = fakes
    result.labels = labels

proc parseTimedAttacks(data: string): seq[TimedAttack] =
    result = @[]
    let spl = data.split(":")
    let max = int(spl.len div 3) - 1

    for idx in 0..max:
        let offset = idx * 3
        let time = parseFloatSafe(spl[offset].split("=")[1])
        let lenOrEndSpl = spl[offset + 1].split("=")
        let lenOrEndVal = parseFloatSafe(lenOrEndSpl[1])
        let mods = spl[offset + 2].split("=")[1].splitByComma(true).mapIt(parseModifier(it))
        let length = if lenOrEndSpl[0].toLower.strip == "len":
            lenOrendVal
            # Annoying extra steps, to prevent rounding/fraction errors
            else: some(((lenOrEndVal.get() * 1000) - (time.get() * 1000)) / 1000)

        result.add newTimedAttack(time, length, mods)

func parseBeats(data: string, columns: int, lenient: bool): seq[Beat] =
    result = @[]

    var beatIndex = 0
    var snapIndex = 0
    var columnIndex = 0

    var beat = newBeat(0)
    var previousNote: Note = nil
    var longNotes = newSeq[Note](columns);

    var tmpData = ""
    # 0 = regular, 1 = attack-data, 2 = keysound-data, 3 = modifier-data
    var state = 0

    for str in data:
        if state == 1:
            if str == '}':
                state = 0
                previousNote.attack = parseAttack(tmpData)
                continue
            tmpData &= str
            continue
        elif str == '{':
            state = 1
            continue

        if state == 2:
            if str == ']':
                state = 0
                previousNote.keySound = parseInt(tmpData)
                continue
            tmpData &= str
            continue
        elif str == '[':
            state = 2
            continue

        if state == 3:
            if str == '>':
                state = 0
                previousNote.modifiers = tmpData.stripSplit("/").mapIt(parseModifier(it))
                continue
            tmpData &= str
            continue
        elif str == '<':
            state = 3
            continue

        if str == ',':
            beat.snapSize = snapIndex
            if beat.notes.len > 0:
                result.add beat

            inc beatIndex
            beat = newBeat(beatIndex)
            snapIndex = 0
            columnIndex = 0
            continue

        var kind = parseEnum[NoteType](($str).toUpper)
        var note = newNote(kind, snapIndex, columnIndex)

        if kind == NoteType.HoldEnd:
            var hold = longNotes[columnIndex]
            if hold != nil:
                if hold.kind == NoteType.Hold:
                    hold.holdEndBeat = beatIndex
                    hold.holdEndSnap = snapIndex
                    longNotes[columnIndex] = nil
                elif hold.kind == NoteType.Roll:
                    hold.rollEndBeat = beatIndex
                    hold.rollEndSnap = snapIndex
                    longNotes[columnIndex] = nil
                elif not lenient:
                    # This should never happen
                    raise newNoteError("Found invalid hold! Beat " & $beatIndex & ", Note: " & $hold[], beatIndex, hold)

            elif not lenient:
                raise newNoteError("Found hold-release where no hold was! Beat " & $beatIndex & ", Note: " & $note[], beatIndex, note)

        elif kind != NoteType.Empty:
            var doAdd = true

            if kind == NoteType.Hold or kind == NoteType.Roll:
                longNotes[columnIndex] = note
            elif longNotes[columnIndex] != nil:
                doAdd = false
                if not lenient:
                    raise newNoteError("Note is placed in a hold! Beat: " & $beatIndex & ", Note: " & $note[], beatIndex, note)

            if doAdd:
                previousNote = note
                beat.notes.add previousNote

        inc columnIndex
        if columnIndex >= columns:
            inc snapIndex
            columnIndex = 0

    beat.snapSize = snapIndex
    if beat.notes.len > 0:
        result.add beat

func parseDifficulty(data: string, description: string): Difficulty =
    # Fall back to edit difficulty
    result = Difficulty.Edit

    try:
        result = parseEnum[Difficulty](data)
    except ValueError:
        if data.endsWith(".edit"):
            result = Difficulty.Edit
        elif data == "smaniac":
            result = Difficulty.Challenge

    if result == Difficulty.Hard:
        if description.toLower == "smaniac" or description.toLower == "challenge":
            result = Difficulty.Challenge

func parseNoteData(data: string, lenient: bool): NoteData =
    let meta = data.split(":", 5)
    let mode = parseEnum[ChartType](meta[0].toLower)
    let columns = columnCount(mode)

    new result
    result.chartType = mode
    result.description = meta[1]
    result.difficulty = parseDifficulty(meta[2].toLower, result.description)
    result.difficultyLevel = parseInt(meta[3])
    result.radarValues = parseRadarValues(meta[4])
    result.beats = parseBeats(meta[5], columns, lenient)

func isYes(str: string): bool =
    return str.toLower in ["yes", "1", "es", "omes"]

proc putFileData(chart: var ChartFile, tag: string, data: string, lenient: bool): void =
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
        chart.bgChanges3 = parseBackgroundChanges(data)
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
        chart.noteData.add parseNoteData(data, lenient)
    of "notes2":
        # This one is quite uncommon and is normally the same content as the previous "notes" section,
        # but with note additions like inline keysounds, attacks and modifiers.
        # Since we support all the formats out of the box, we're usually only interested in the "notes2" section.
        # Therefore check if the note-data is already present and replace it.
        # Has its own section to not break compatibility with older parsers.

        var noteData = parseNoteData(data, lenient)
        let found = chart.noteData.find((existing: NoteData) => existing.chartType == noteData.chartType and existing.difficulty == noteData.difficulty and existing.difficultyLevel == noteData.difficultyLevel)

        if found > -1:
            chart.noteData[found] = noteData
        else:
            chart.noteData.add noteData

    of "combos":
        chart.combos = parseComboChanges(data)
    of "speeds":
        chart.speeds = parseSpeedChanges(data)
    of "scrolls":
        chart.scrolls = parseScollSpeedChanges(data)
    of "fakes":
        chart.fakes = parseFakeSections(data)
    of "labels":
        chart.labels = parseLabels(data)
    else:
        discard

proc parseStepMania*(data: string, lenient: bool = false): ChartFile =
    result = newChartFile()
    for tag, tagData in parseTags(data):
        result.putFileData(tag, tagData, lenient)
