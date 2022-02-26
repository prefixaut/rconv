import std/[strutils, tables]

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

    NoteRange* = range[0..15] ## \
    ## All positions a note can be placed on.
    ## Posion description::
    ## 
    ##  0  1  2  3
    ##  4  5  6  7
    ##  8  9 10 11
    ##  12 13 14 15
    ## 

    RowIndex* = range[0..3] ## \
    ## Range of how many row-indices may exist (4).

    BpmRange* = tuple[min: float, max: float] ## \
        ## The range of BPM the file is in

    Note* = object
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
                releaseSection*: int
                ## In which section it has to look for the timing id.
            else:
                discard

    Section* = object
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
        notes*: OrderedTable[NoteRange, Note]
        ## Notes that need to be played.
        ## Keys are the positions, which start from top-left to bottom-right.
        ## _`NoteRange`

    Snap* = object
        ## Describes the amount of notes that can occur in a single beat.
        len*: int
        ## How many notes fit into a Snap.
        partIndex*: int
        ## In which part of the original section this snap is defined.
        row*: RowIndex
        ## The row in which this snap is defined.

    Memson* = object
        ## Memson is the in-memory data-structure for memo-files.
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
