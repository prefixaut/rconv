import std/[strutils, tables]

import ./grid_common

export grid_common

type
    Difficulty* {.pure.} = enum
        ## Difficulty for jubeat like games.
        ## Will be removed/replaced with a more generic solution soonish 
        Basic       = "basic",
        Advanced    = "advanced",
        Extreme     = "extreme"
        Edit        = "edit"

    NoteType* {.pure.} = enum
        ## The types of notes that exist (regular note, or a hold)
        Note        = "note"
        Hold        = "hold"

    BpmRange* = tuple[min: float, max: float] ## \
    ## The range of BPM the file is in

    Note* = ref object
        ## A Note or Hold which has to be pressed.
        time*: int
        ## The timing id when this note has to be pressed.
        partIndex*: int
        ## In which part this note was originally defined.
        case kind*: NoteType
            ## Which kind this Note is (Note or Hold)
            of NoteType.Hold:
                animationStartIndex*: int
                ## On which position the animation for the hold starts on.
                releaseTime*: int
                ## The release timing id when the hold has to be released.
                releasePart*: int
                ## The part in which the the hold was released.
                releaseSection*: int
                ## In which section it has to look for the timing id.
            else:
                discard

    Section* = ref object
        ## Describes a complete section (with all parts).
        index*: int
        ## The index of this section.
        bpm*: float
        ## What BPM this section is using.
        partCount*: int
        ## How many parts this section originally consisted of.
        timings*: seq[int]
        ## Timing ids which defined when a note needs to be pressed.
        snaps*: seq[Snap]
        ## The snaps for the timing.
        noteCount*: uint
        ## How many notes in total are stored
        notes*: OrderedTable[NoteRange, seq[Note]]
        ## Notes that need to be played.
        ## Keys are the positions, which start from top-left to bottom-right.
        ## _`NoteRange`

    Snap* = ref object
        ## Describes the amount of notes that can occur in a single beat.
        length*: int
        ## How many notes fit into a Snap.
        partIndex*: int
        ## In which part of the original section this snap is defined.
        row*: RowIndex
        ## The row in which this snap is defined.

    Memo* = ref object
        ## memo is the in-memory data-structure for memo-files.
        songTitle*: string
        ## The title of the chart's song.
        artist*: string
        ## The artist of the chart's song.
        difficulty*: Difficulty
        ## The difficulty of the chart.
        level*: int
        ## The difficulty as level range (Usually 1-10) of the chart.
        bpm*: float
        ## The BPM of the chart. May not be accurate if the `bpmRange` is set.
        bpmRange*: BpmRange
        ## The BPM-Range of the chart.
        ## May only be set if BPM changes occur in the chart.
        sections*: seq[Section]
        ## The sections of the chart.

func `$`*(diff: Difficulty): string =
    case diff:
    of Basic:
        result = "Basic"
    of Advanced:
        result = "Advanced"
    of Extreme:
        result = "Extreme"
    of Edit:
        result = "Edit"

func newMemo*(
    songTitle: string = "",
    artist: string = "",
    difficulty: Difficulty = Difficulty.Basic,
    level: int = 1,
    bpm: float = 0.0,
    bpmRange: BpmRange,
    sections: seq[Section] = @[]
): Memo =
    new result
    result.songTitle = songTitle
    result.artist = artist
    result.difficulty = difficulty
    result.level = level
    result.bpm = bpm
    result.bpmRange = bpmRange
    result.sections = sections

func newSection*(
    index: int = 1,
    bpm: float = 0.0,
    partCount: int = 1,
    timings: seq[int] = @[],
    snaps: seq[Snap] = @[],
    noteCount: uint = 0, notes: OrderedTable[NoteRange, seq[Note]] = initOrderedTable[NoteRange, seq[Note]]()
): Section =
    new result
    result.index = index
    result.bpm = bpm
    result.partCount = partCount
    result.timings = timings
    result.snaps = snaps
    result.noteCount = noteCount
    result.notes = notes

func newSnap*(length: int = 1, partIndex: int = 0, row = 0): Snap =
    new result
    result.length = length
    result.partIndex = partIndex
    result.row = row

func newNote*(time: int = 0, partIndex: int = 0): Note =
    result = Note(kind: NoteType.Note)
    result.time = time
    result.partIndex = partIndex

func newHold*(
    time: int = 0,
    partIndex: int = 0,
    animationStartIndex: int = 0,
    releaseTime: int = 0,
    releasePart: int = 0,
    releaseSection: int = 1
): Note =
    result = Note(kind: NoteType.Hold)
    result.time = time
    result.partIndex = partIndex
    result.animationStartIndex = animationStartIndex
    result.releaseTime = releaseTime
    result.releasePart = releasePart
    result.releaseSection = releaseSection

func parseDifficulty*(input: string): Difficulty =
    case input.toLower:
    of "basic":
        result = Difficulty.Basic
    of "adv", "advanced":
        result = Difficulty.Advanced
    of "ext", "extreme", "extra":
        result = Difficulty.Extreme
    else:
        result = Difficulty.Edit
