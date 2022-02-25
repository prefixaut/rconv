import std/[json, jsonutils, sets, tables]

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
            vol = self.getFloatSafe("vol")
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
                w = self.getIntSafe("w"),
                `type` = getSlideNoteType(self.getIntSafe("type")),
                seg = seg
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
            result = malody.newVerticalNote(
                beat = beat,
                x = self.getIntSafe("x")
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
            let tmp = malody.newIndexNote(
                beat = beat,
                index = self.getIntSafe("index")
            )
            return tmp
    else:
        result = malody.newTimedElement(beat = beat)

proc toMalodyChart*(self: JsonNode): malody.Chart =
    ## Additional hook to make the hook for `TimedElement` work.

    assert self.kind == JsonNodeKind.JObject,
        "The kind of `JsonNode` must be `JObject`, but it's actual kind is `" & $self.kind & "`."

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
