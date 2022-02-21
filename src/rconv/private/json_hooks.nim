import std/[json, jsonutils, sets, tables]

import ./json_helpers

import ../malody as malody
import ../memson as memson

{.experimental: "codeReordering".}

func getBeatSafe(self: JsonNode, field: string = "beat", default: malody.Beat = [-1, 0, 0]): malody.Beat =
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

    echo "BBBB"

    assert self.kind == JsonNodeKind.JObject:
        "The kind of `JsonNode` must be `JObject`, but it's actual kind is `" & $self.kind & "`."

    let beat = self.getBeatSafe()

    if self.hasField("bpm", JsonNodeKind.JFloat):
        result = malody.TimeSignature(beat: beat, bpm: self.getFloatSafe("bpm"))

    elif self.hasField("type", JsonNodeKind.JInt) and self.hasField("sound", JsonNodeKind.JString):
        echo "sound-cue"
        result = malody.SoundCue(
            beat: beat,
            `type`: malody.getSoundCueType(self.getIntSafe("type")),
            offset: self.getFloatSafe("offset"),
            vol: self.getFloatSafe("vol")
        )
    elif self.hasField("column", JsonNodeKind.JInt):
        echo "column-cue"
        if self.fields.hasKey("endbeat"):
            result = malody.ColumnHold(
                beat: beat,
                column: self.getIntSafe("column"),
                style: self.getIntSafe("style", -1),
                endbeat: self.getBeatSafe("endbeat"),
                hits: self.getIntSafe("hits", 1)
            )
        else:
            result = malody.ColumnNote(
                beat: beat,
                column: self.getIntSafe("column"),
                style: self.getIntSafe("style", -1)
            )
    elif self.hasField("x", JsonNodeKind.JInt):
        if self.hasField("w", JsonNodeKind.JInt):
            echo "vertical-note 1"
            var seg: seq[VerticalNote] = @[]
            if self.fields.hasKey("seg"):
                seg.fromJson(self.fields["seg"], Joptions(allowMissingKeys: true, allowExtraKeys: true))

            result = malody.SlideNote(
                beat: beat,
                w: self.getIntSafe("w"),
                `type`: getSlideNoteType(self.getIntSafe("type")),
                seg: seg
            )
        elif self.hasField("type", JsonNodeKind.JInt):
            echo "catch-note"
            if self.fields.hasKey("endbeat"):
                result = malody.CatchHold(
                    beat: beat,
                    `type`: getCatchNoteType(self.getIntSafe("type")),
                    endbeat: self.getBeatSafe("endbeat")
                )
            else:
                result = malody.CatchNote(
                    beat: beat,
                    `type`: getCatchNoteType(self.getIntSafe("type"))
                )
        else:
            echo "vertical-note 2"
            result = malody.VerticalNote(
                beat: beat,
                x: self.getIntSafe("x")
            )
    elif self.hasField("index", JsonNodeKind.JInt):
        echo "index-note"
        if self.fields.hasKey("endbeat"):
            result = malody.IndexHold(
                beat: beat,
                index: self.getIntSafe("index"),
                endbeat: self.getBeatSafe("endbeat"),
                endindex: self.getIntSafe("endindex")
            )
        else:
            result = malody.IndexNote(
                beat: beat,
                index: self.getIntSafe("index")
            )
    else:
        echo "timed-element"
        result = malody.TimedElement(beat: beat)

proc toMalodyChart*(self: JsonNode): malody.Chart =
    ## Additional hook to make the hook for `TimedElement` work.

    assert self.kind == JsonNodeKind.JObject,
        "The kind of `JsonNode` must be `JObject`, but it's actual kind is `" & $self.kind & "`."

    echo "aaaaaa"
    result.note = @[]
    result.time = @[]

    #if self.hasField("meta", JsonNodeKind.JObject):
    #    result.meta = self.fields["meta"].jsonTo(malody.MetaData, Joptions(allowMissingKeys: true, allowExtraKeys: true))

    if self.hasField("note", JsonNodeKind.JArray):
        for note in self.fields["note"].elems:
            result.note.add(toMalodyTimedElement(note))
    else:
        echo "no note"
    
    if self.hasField("time", JsonNodeKind.JArray):
        for time in self.fields["time"].elems:
            result.time.add time.jsonTo(malody.TimeSignature, Joptions(allowMissingKeys: true, allowExtraKeys: true))
    else:
        echo "no time"

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
