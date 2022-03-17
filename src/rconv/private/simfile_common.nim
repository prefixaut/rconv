import std/[options, strutils, sequtils, sugar]

import ./parser_helpers

type
    ChartType* {.pure.} = enum
        ## The type of the game-mode for which the chart is for

        DanceSingle = "dance-single"
        ## 4k - 4k in single-player
        DanceDouble = "dance-double"
        ## 8k - 4k with 2 pads in single-player
        DanceCouple = "dance-couple"
        ## 8k - 4k with 2 pads for 2 people
        DanceRoutine = "dance-routine"
        ## 8k - 4k with 2 pads where players rotate
        DanceSolo = "dance-solo"
        ## 6k - 6k in single-player
        PumpSingle = "pump-single"
        ## 5k - 5k in single-player
        PumpHalfdouble = "pump-halfdouble"
        ## 6k - 5k with 2 pads in single-player, but only inner arrows
        PumpDouble = "pump-double"
        ## 10k - 5k with 2 pads in single-player
        PumpCouple = "pump-couple"
        ## 10k - 5k with 2 pads for 2 people

    Difficulty* {.pure.} = enum
        ## The difficulty of a chart.
        ## The same difficulty may only be defined once with the same game-mode, except for the Edit.
        ## Edit-Difficulties may be present unlimited amount of times.
        Beginner = "beginner"
        Easy = "easy"
        Medium = "medium"
        Hard = "hard"
        Challenge = "challenge"
        Edit = "edit"

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
        ## Stops/Freezes which happen in a song
        beat*: float
        ## At which beat the stop occurs
        duration*: float
        ## For how long the stop holds on

    Delay* = ref object
        ## A delay segment in a song
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

    Modifier* = ref object
        ## Modifiers which may be applied to the song or on an individual note
        name*: string
        ## The name of the modifier
        player*: string
        ## The player for which the modifier is meant for
        approachRate*: int
        ## The approach-rate
        magnitude*: float
        ## The magnitude of the modifier
        isPercent*: bool
        ## If the '_magnitude is percent based

    Attack* = ref object of RootObj
        ## An attack is a modifier which occurs at a time/note for a certain time
        length*: float
        ## For how long the attack is active
        mods*: seq[Modifier]
        ## The modifiers which will be applied

    TimedAttack* = ref object of Attack
        ## An attack which happens at the specified time
        time*: float
        ## The time when the attack occurs

    ComboChange* = ref object
        ## Changes the combo count for hits/misses
        beat*: float
        ## When the combo-change should occur
        hit*: int
        ## How much a single hit should count to the combo
        miss*: int
        ## How many misses a single miss should count

    SpeedChange* = ref object
        ## Modifies the speed of the chart by ratio
        beat*: float
        ## The beat where the speed-change occurs on
        ratio*: float
        ## The ratio that will be applied
        duration*: float
        ## How long it should take for the ratio to be applied (will be applied gradually)
        inSeconds*: bool
        ## If the duration is specified in seconds or in beats

    ScollSpeedChange* = ref object
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

func columnCount*(mode: ChartType): int =
    ## Gets the column count for a ChartType

    result = 4

    case mode:
    of ChartType.DanceSingle:
        result = 4
    of ChartType.PumpSingle:
        result = 5
    of ChartType.DanceSolo, ChartType.PumpHalfdouble:
        result = 6
    of ChartType.DanceCouple, ChartType.DanceDouble, ChartType.DanceRoutine:
        result = 8
    of ChartType.PumpCouple, ChartType.PumpDouble:
        result = 10
    else:
        discard

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

func newComboChange*(beat: float, hit: int, miss: int): ComboChange =
    new result
    result.beat = beat
    result.hit = hit
    result.miss = miss

func newComboChange*(beat: Option[float], hit: Option[int], miss: Option[int]): ComboChange =
    result = newComboChange(beat.get(0.0), hit.get(1), miss.get(1))

func newSpeedChange*(beat: float, ratio: float, duration: float, inSeconds: bool): SpeedChange =
    new result
    result.beat = beat
    result.ratio = ratio
    result.duration = duration
    result.inSeconds = inSeconds

func newSpeedChange*(beat: Option[float], ratio: Option[float], duration: Option[float], inSeconds: Option[bool]): SpeedChange =
    result = newSpeedChange(beat.get(0.0), ratio.get(1.0), duration.get(0.0), inSeconds.get(false))

func newScollSpeedChange*(beat: float, factor: float): ScollSpeedChange =
    new result
    result.beat = beat
    result.factor = factor

func newScollSpeedChange*(beat: Option[float], factor: Option[float]): ScollSpeedChange =
    result = newScollSpeedChange(beat.get(0.0), factor.get(1.0))

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

func newModifier*(
    name: string,
    player: string = "",
    approachRate: int = 1,
    magnitude: float = 100,
    isPercent: bool = true
): Modifier =
    new result
    result.name = name
    result.approachRate = approachRate
    result.magnitude = magnitude
    result.isPercent = isPercent
    result.player = player

func newAttack*(length: float = 0.0, mods: seq[Modifier] = @[]): Attack =
    new result
    result.length = length
    result.mods = mods

func newTickCount*(beat: float, count: int): TickCount =
    new result
    result.beat = beat
    result.count = count

func newTickCount*(beat: Option[float], count: Option[int]): TickCount =
    result = newTickCount(beat.get(0.0), count.get(4))

func splitByComma*(data: string, doStrip: bool = false): seq[string] =
    result = @[]
    if data.contains(","):
        result = data.split(",").filter(s => s.strip.len > 0)
    elif not data.isEmptyOrWhitespace:
        result = @[data]

    if doStrip:
        result = result.map(s => s.strip)

func parseIntrumentTracks*(data: string): seq[InstrumentTrack] =
    result = @[]
    for elem in data.splitByComma:
        let spl = elem.split("=")
        if spl.len >= 2:
            result.add(newInstrumentTrack(spl[0], spl[1]))

proc parseColor*(data: string): Color =
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

proc parseBackgroundChanges*(data: string): seq[BackgroundChange] =
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

func parseStops*(data: string): seq[Stop] =
    result = @[]
    for elem in data.splitByComma:
        let spl = elem.splitMin("=", 2)
        result.add newStop(parseFloatSafe(spl[0]), parseFloatSafe(spl[1]))

func parseBpms*(data: string): seq[BpmChange] =
    result = @[]
    for elem in data.splitByComma:
        let spl = elem.splitMin("=", 2)
        result.add newBpmChange(parseFloatSafe(spl[0]), parseFloatSafe(spl[1]))

func parseTimeSignatures*(data: string): seq[TimeSignature] =
    result = @[]
    for elem in data.splitByComma:
        let spl = elem.split("=", 3)
        result.add newTimeSignature(parseFloatSafe(spl[0]), parseIntSafe(spl[1]), parseIntSafe(spl[2]))

func parseModifier*(data: string): Modifier =
    var spl = data.stripSplit(" ")
    let name = spl.pop()

    var approachRate = 1
    var magnitude = 100.0
    var isPercent = true

    var player = ""

    if spl.len > 0 and spl[0].startsWith("*"):
        let approachStr = spl.unshift()

        try:
            approachRate = parseInt(approachStr.substr(1))
        except:
            discard

    if spl.len > 0 and spl[0].toLower.startsWith("p"):
        player = spl.unshift()

    if spl.len > 0 and not spl[0].isEmptyOrWhitespace:
        isPercent = spl[0].endsWith("%")
        try:
            if isPercent:
                magnitude = parseFloat(spl[0].substr(-1))
            else:
                magnitude = parseFloat(spl[0])
        except ValueError:
            isPercent = true
            if spl[0].toLower == "no":
                magnitude = 0

    result = newModifier(name, player, approachRate, magnitude, isPercent)

func parseAttack*(data: string): Attack =
    let spl = data.splitMin(":", 2)
    result = newAttack(parseFloatSafe(spl[1]).get(0.0), spl[0].splitByComma.mapIt(parseModifier(it)))

func parseDelays*(data: string): seq[Delay] =
    result = @[]
    for elem in data.splitByComma:
        let spl = elem.splitMin("=", 2)
        result.add newDelay(parseFloatSafe(spl[0]), parseFloatSafe(spl[1]))

func parseTickCounts*(data: string): seq[TickCount] =
    result = @[]
    for elem in data.splitByComma:
        let spl = elem.splitMin("=", 2)
        result.add newTickCount(parseFloatSafe(spl[0]), parseIntSafe(spl[1]))

func parseComboChanges*(data: string): seq[ComboChange] =
    result = @[]
    for elem in data.splitByComma:
        let spl = elem.splitMin("=", 3)
        result.add newComboChange(parseFloatSafe(spl[0]), parseIntSafe(spl[1]), parseIntSafe(spl[2]))

func parseSpeedChanges*(data: string): seq[SpeedChange] =
    result = @[]
    for elem in data.splitByComma:
        let spl = elem.splitMin("=", 4)
        result.add newSpeedChange(parseFloatSafe(spl[0]), parseFloatSafe(spl[1]), parseFloatSafe(spl[2]), parseBoolSafe(spl[3]))

func parseScollSpeedChanges*(data: string): seq[ScollSpeedChange] =
    result = @[]
    for elem in data.splitByComma:
        let spl = elem.splitMin("=", 2)
        result.add newScollSpeedChange(parseFloatSafe(spl[0]), parseFloatSafe(spl[1]))

func parseFakeSections*(data: string): seq[FakeSection] =
    result = @[]
    for elem in data.splitByComma:
        let spl = elem.splitMin("=", 2)
        result.add newFakeSection(parseFloatSafe(spl[0]), parseFloatSafe(spl[1]))

func parseLabels*(data: string): seq[Label] =
    result = @[]
    for elem in data.splitByComma:
        let spl = elem.splitMin("=", 2)
        if spl.len > 1:
            result.add newLabel(parseFloat(spl[0]), spl[1])

func parseRadarValues*(data: string): RadarValues =
    var spl = data.splitMin(",", 5, "0")

    result = [
        parseFloatSafe(spl[0]).get(0.0),
        parseFloatSafe(spl[1]).get(0.0),
        parseFloatSafe(spl[2]).get(0.0),
        parseFloatSafe(spl[3]).get(0.0),
        parseFloatSafe(spl[4]).get(0.0)
    ]
