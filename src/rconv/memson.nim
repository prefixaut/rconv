import std/[json, jsonutils, tables]

import ./common

type    
    NoteType* {.pure.} = enum
        Note        = "note"
        Hold        = "hold"

    NoteRange* = range[0..15]
    RowIndex* = range[0..3]

    BpmRange* = tuple[min: float, max: float]

    Note* = object
        time*: int
        partIndex*: int
        case kind*: NoteType
        of Hold:
            animationStartIndex*: int
            releaseTime*: int
            releaseSection*: int
        else:
            discard

    Section* = object
        index*: int
        bpm*: float
        partCount*: int
        timings*: seq[int]
        snaps*: seq[Snap]
        notes*: OrderedTable[NoteRange, Note]

    Snap* = object
        len*: int
        partIndex*: int
        row*: RowIndex

    Memson* = object
        songTitle*: string
        artist*: string
        difficulty*: Difficulty
        level*: int
        bpm*: float
        bpmRange*: BpmRange
        sections*: seq[Section]

proc toJsonHook*[T: BpmRange](this: T): JsonNode =
    result = newJNull()

    if this.min != this.max:
        result = newJObject()
        result["min"] = this.min
        result["max"] = this.max

proc toJsonHook*[T: OrderedTable[NoteRange, Note]](this: T): JsonNode =
    result = newJObject()
    for index, note in this.pairs:
        result[$index] = toJson(note)

proc toJsonHook*[T: Note](this: T): JsonNode =
    result = newJObject()
    result["time"] = toJson(this.time)
    if this.kind == NoteType.Hold:
        result["animationStartIndex"] = toJson(this.animationStartIndex)
        result["releaseTime"] = toJson(this.releaseTime)
        result["releaseSection"] = toJson(this.releaseSection)
