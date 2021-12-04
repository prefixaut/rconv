import std/[json, jsonutils, sets, tables]

import ./json as cj

import ../fxf as fxf
import ../malody as malody
import ../memson as memson

{.experimental: "codeReordering".}

proc jsonToHook*[T: malody.TimedElement](self: JsonNode): T =
    ## Hook to convert the provided JsonNode to the appropiate `TimeElement`.
    echo "json to hook"

    if self.kind != JsonNodeKind.JObject or not self.fields.hasKey "beat":
        discard

    echo self
    let beat = self.getBeatSafe()

    if self.hasField("bpm", JsonNodeKind.JFloat):
        result = malody.TimeSignature(beat = beat, bpm = self.getFloatSafe("bpm"))

    elif self.hasField("type", JsonNodeKind.JInt) and self.hasField("sound", JsonNodeKind.JString):
        result = malody.SoundCue(
            beat = beat,
            `type` = self.getIntSafe("type"),
            offset = self.getFloatSafe("offset"),
            vol: self.getFloatSafe("vol")
        )
    elif self.hasField("column", JsonNodeKind.JInt):
        if self.fields.hasKey("endbeat"):
            result = malody.ColumnHold(
                beat = beat,
                column = self.getIntSafe("column"),
                style = self.getIntSafe("style", -1),
                endbeat = self.getBeatSafe("endbeat"),
                hits = self.getIntSafe("hits", 1)
            )
        else:
            result = malody.ColumnNote(
                beat = beat,
                column = self.getIntSafe("column"),
                style = self.getIntSafe("style", -1)
            )
    elif self.hasField("x", JsonNodeKind.JInt):
        if self.hasField("w", JsonNodeKind.JInt):
            result = malody.SlideNote(
                beat = beat,
                w = self.getIntSafe("w"),
                `type` = self.getIntSafe(self, "type"),
                seg = if self.fields.hasKey("seg"): jsonTo(self.fields["seg"], seq[VerticalNote]) else: @[]
            )
        elif self.hasKey("type", JsonNodeKind.JInt):
            if self.fields.hasKey("endbeat"):
                result = malody.CatchHold(
                    beat = beat,
                    `type` = self.getIntSafe("type"),
                    endbeat = self.getBeatSafe("endbeat")
                )
            else:
                result = malody.CatchNote(
                    beat = beat,
                    `type` = self.getIntSafe("type")
                )
        else:
            result = malody.VerticalNote(
                beat = beat,
                x = self.getIntSafe("x")
            )
    elif self.hasField("index", JsonNodeKind.JInt):
        if self.fields.hasKey("endbeat"):
            result = malody.IndexHold(
                beat = beat,
                index = self.getIntSafe("index"),
                endbeat = self.getBeatSafe("endbeat"),
                endindex = self.getIntSafe("endindex")
            )
        else:
            result = malody.IndexNote(
                beat = beat,
                index = self.getIntSafe("index")
            )
    else:
        discard

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

proc toJsonHook*[T: Table[string, fxf.Chart]](this: T): JsonNode =
    ## Hook to convert the Table of Difficulty and Chart to a proper json-object.
    ## Regular table hooks convert it with additional artifacting and breaking structure.

    result = newJObject()
    for key, value in this.pairs:
        result[$key] = toJson(value)

proc toJsonHook*[T: fxf.Tick](this: T): JsonNode =
    ## Hook to convert a Tick into a json-object.
    ## Excludes empty/redundant elements in the result.

    result = newJObject()
    result["time"] = newJFloat(this.time)
    if this.snapSize > 0:
        result["snapSize"] = newJInt(this.snapSize)
        result["snapIndex"] = newJInt(this.snapIndex)
    if this.notes != nil and this.notes.len > 0:
        result["notes"] = toJson(this.notes)
    if this.holds != nil and this.holds.len > 0:
        result["holds"] = toJson(this.holds)
