import std/[enumutils, json, jsonutils, sets, tables]

import ./json_helpers

import ../malody as malody
import ../memson as memson

{.experimental: "codeReordering".}

func getBeatSafe(self: JsonNode, field: string = "beat", default: malody.Beat = malody.EmptyBeat): malody.Beat =
    ## Internal helper function to safely get a beat from a JsonNode

    result = default
    if self.fields.hasKey(field):
        try:
            if self.fields[field].kind == JsonNodeKind.JArray:
                let arr = self.fields[field].elems
                for index in 0..2:
                    if arr.len >= index:
                        result[index] = arr[index].getInt
        except:
            discard

proc toMalodyTimedElement*(self: JsonNode): malody.TimedElement =
    ## Hook to convert the provided JsonNode to the appropiate `TimeElement`.

    assert self.kind == JsonNodeKind.JObject:
        "The kind of `JsonNode` must be `JObject`, but it's actual kind is `" & $self.kind & "`."

    let beat = self.getBeatSafe()

    if self.hasField("bpm", JsonNodeKind.JFloat):
        result = malody.newTimeSignature(beat = beat, bpm = self.getFloatSafe("bpm"))

    elif self.hasField("type", JsonNodeKind.JInt) and self.hasField("sound", JsonNodeKind.JString):
        result = malody.newSoundCue(
            beat = beat,
            `type` = malody.getSoundCueType(self.getIntSafe("type")),
            offset = self.getFloatSafe("offset"),
            volume = self.getFloatSafe("vol")
        )
    elif self.hasField("index", JsonNodeKind.JInt):
        if self.fields.hasKey("endbeat"):
            result = malody.newIndexHold(
                beat = beat,
                index = self.getIntSafe("index"),
                endBeat = self.getBeatSafe("endbeat"),
                endIndex = self.getIntSafe("endindex")
            )
        else:
            result = malody.newIndexNote(
                beat = beat,
                index = self.getIntSafe("index")
            )
    elif self.hasField("column", JsonNodeKind.JInt):
        if self.fields.hasKey("endbeat"):
            result = malody.newColumnHold(
                beat = beat,
                column = self.getIntSafe("column"),
                style = self.getIntSafe("style", -1),
                endBeat = self.getBeatSafe("endbeat"),
                hits = self.getIntSafe("hits", 1)
            )
        else:
            result = malody.newColumnNote(
                beat = beat,
                column = self.getIntSafe("column"),
                style = self.getIntSafe("style", -1)
            )
    elif self.hasField("x", JsonNodeKind.JInt):
        if self.hasField("w", JsonNodeKind.JInt):
            var seg: seq[TimedElement] = @[]
            if self.fields.hasKey("seg"):
                seg.fromJson(self.fields["seg"], Joptions(allowMissingKeys: true, allowExtraKeys: true))

            result = malody.newSlideNote(
                beat = beat,
                x = self.getIntSafe("x"),
                width = self.getIntSafe("w"),
                `type` = getSlideNoteType(self.getIntSafe("type")),
                segments = seg
            )
        elif self.hasField("type", JsonNodeKind.JInt):
            if self.fields.hasKey("endbeat"):
                result = malody.newCatchHold(
                    beat = beat,
                    `type` = getCatchNoteType(self.getIntSafe("type")),
                    endBeat = self.getBeatSafe("endbeat")
                )
            else:
                result = malody.newCatchNote(
                    beat = beat,
                    `type` = getCatchNoteType(self.getIntSafe("type"))
                )
        else:
            result = malody.newTimedElement(beat = beat)
    else:
        result = malody.newTimedElement(beat = beat)

proc toMalodyChart*(self: JsonNode): malody.Chart {.raises:[ValueError].} =
    ## Additional hook to make the hook for `TimedElement` work.

    if self.kind != JsonNodeKind.JObject:
        raise newException(ValueError, "The kind of `JsonNode` must be `JObject`, but it's actual kind is `" & $self.kind & "`.")

    result = malody.newChart()

    if self.hasField("meta", JsonNodeKind.JObject):
        result.meta = self.fields["meta"].jsonTo(malody.MetaData, Joptions(allowMissingKeys: true, allowExtraKeys: true))

    if self.hasField("note", JsonNodeKind.JArray):
        for data in self.fields["note"].elems:
            let note = toMalodyTimedElement(data)
            result.note.add(note)

    if self.hasField("time", JsonNodeKind.JArray):
        for data in self.fields["time"].elems:
            let time = toMalodyTimedElement(data)
            result.time.add(time)

proc toJsonHook*[T: memson.BpmRange](this: T): JsonNode =
    result = newJNull()

    if this.min != this.max:
        result = newJObject()
        result["min"] = this.min
        result["max"] = this.max

proc toJsonHook*[T: OrderedTable[memson.NoteRange, memson.Note]](this: T): JsonNode =
    result = newJObject()
    for index, note in this.pairs:
        result[$index] = toJson(note)

proc toJsonHook*[T: memson.Note](this: T): JsonNode =
    result = newJObject()
    result["time"] = toJson(this.time)
    if this.kind == memson.NoteType.Hold:
        result["animationStartIndex"] = toJson(this.animationStartIndex)
        result["releaseTime"] = toJson(this.releaseTime)
        result["releaseSection"] = toJson(this.releaseSection)

proc toJsonHook*[T: malody.Chart](this: T): JsonNode =
    result = newJObject()
    result["meta"] = toJson(this.meta)
    result["time"] = newJArray()
    for time in this.time:
        result["time"].elems.add toJsonHook(time)
    
    result["note"] = newJArray()
    for note in this.note:
        result["note"].elems.add toJsonHook(note)

proc toJsonHook*[T: malody.TimedElement](this: T): JsonNode =
    result = newJObject()
    result["beat"] = toJsonHook(this.beat)

    case this.kind:
    of malody.ElementType.TimeSignature:
        result["bpm"] = newJFloat(this.sigBpm)

    of malody.ElementType.SoundCue:
        result["type"] = newJInt(this.cueType.symbolRank)
        result["sound"] = newJString(this.cueSound)
        result["vol"] = newJFloat(this.cueVolume)

    of malody.ElementType.IndexNote:
        result["index"] = newJInt(this.index)
        if this.hold == malody.HoldType.IndexHold:
            result["endbeat"] = toJsonHook(this.indexEndBeat)
            result["endindex"] = newJInt(this.indexEnd)

    of malody.ElementType.ColumnNote:
        result["column"] = newJInt(this.column)
        result["style"] = newJInt(this.colStyle)
        if this.hold == malody.HoldType.ColumnHold:
            result["endbeat"] = toJsonHook(this.colEndBeat)
            result["hits"] = newJInt(this.colHits)

    of malody.ElementType.CatchNote:
        result["x"] = newJInt(this.catchX)
        result["type"] = newJInt(this.catchType.symbolRank)
        if this.hold == malody.HoldType.CatchHold:
            result["endbeat"] = toJsonHook(this.catchEndBeat)

    of malody.ElementType.SlideNote:
        result["x"] = newJInt(this.slideX)
        result["w"] = newJInt(this.slideWidth)
        result["type"] = newJInt(this.slideType.symbolRank)
        result["seg"] = newJArray()
        for e in this.slideSegments:
            result["seg"].elems.add toJsonHook(e)

    else:
        discard

proc toJsonHook*[T: malody.Beat](this: T): JsonNode =
    result = newJArray()
    result.elems.add newJInt(this[0])
    result.elems.add newJInt(this[1])
    result.elems.add newJInt(this[2])
