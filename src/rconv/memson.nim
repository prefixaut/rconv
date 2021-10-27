import std/[json, jsonutils, tables]

import ./common

type    
    NoteType* {.pure.} = enum
        Note        = "note"
        Hold        = "hold"

    NoteRange* = range[0..15]
    RowIndex* = range[0..3]

    Note* = object
        time*: uint8
        partIndex*: uint8
        case kind*: NoteType
        of Hold:
            animationStartIndex*: uint8
            releaseTime*: uint8
            releaseSection*: uint8
        else:
            discard

    Section* = object
        index*: uint
        bpm*: float
        partCount*: uint8
        timings*: seq[int8]
        snaps*: seq[Snap]
        notes*: OrderedTable[NoteRange, Note]

    Snap* = object
        len*: uint16
        partIndex*: uint16
        row*: RowIndex

    Memson* = object
        songTitle*: string
        artist*: string
        difficulty*: Difficulty
        level*: uint8
        bpm*: float
        bpmRange*: tuple[min: float, max: float]
        sections*: seq[Section]

proc toJsonHook*[T: Memson](this: T): JsonNode =
    result = newJObject()
    result["songTitle"] = toJson(this.songTitle)
    result["artist"] = toJson(this.artist)
    result["difficulty"] = toJson(this.difficulty)
    result["level"] = toJson(this.level)
    result["bpm"] = toJson(this.bpm)
    # Only needed if there's a range present
    if (this.bpmRange.min != this.bpmRange.max):
        result["bpmRange"] = newJObject()
        result["bpmRange"]["min"] = toJson(this.bpmRange.min)
        result["bpmRange"]["max"] = toJson(this.bpmRange.max)
    result["sections"] = newJArray()
    for sec in this.sections:
        add(result["sections"], toJson(sec))

proc toJsonHook*[T: Section](this: T): JsonNode =
    result = newJObject()
    result["index"] = toJson(this.index)
    result["bpm"] = toJson(this.bpm)
    result["partCount"] = toJson(this.partCount)
    result["snaps"] = toJson(this.snaps)
    result["notes"] = newJObject()

    for index, note in this.notes.pairs:
        result["notes"][$index] = toJson(note)

proc toJsonHook*[T: Note](this: T): JsonNode =
    result = newJObject()
    result["time"] = toJson(this.time)
    if this.kind == NoteType.Hold:
        result["animationStartIndex"] = toJson(this.animationStartIndex)
        result["releaseTime"] = toJson(this.releaseTime)
        result["releaseSection"] = toJson(this.releaseSection)
