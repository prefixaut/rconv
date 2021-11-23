import std/[json, jsonutils, tables]

import ./common

type
    ChartFile* = object
        ## A complete FXF-Chart file which contains multiple charts (Difficulties)
        version*: int
        ## Version of the format
        title*: string
        ## Song title
        artist*: string
        ## Song's artist
        audio*: string
        ## Local path to audio file (relative to this files directory)
        jacket*: string
        ## Local path to jacket (relative to this files directory)
        offset*: int
        ## Audio outset in ms
        bpmChanges*: seq[BpmChange]
        ## The changes of the BPM
        charts*: Table[Difficulty, Chart]
        ## Object of charts where key is difficulty name and value is the chart itself
        ## Usually a memo file contains only one chart
        ## but it makes sense to just store all charts in one file

    Chart* = object
        ## A single FXF chart which holds the note/hold information
        rating*: float
        ## The charts difficulty rating as numerical value
        ticks*: seq[Tick]
        ## The ticks/notes of the chart
    
    BpmChange* = object
        ## A change of BPM in the song/chart on a given time
        time*: float
        ## Timestamp in milliseconds when the bpm changes
        bpm*: float
        ## The BPM it changes to
        snapSize*: int
        ## optional. The snap-size in which this change occurs
        snapIndex*: int
        ## optional. The snap-index in which the change occurs

    NoteRange* = range[0..15] ## \
    ## Range of note indices which need to be pressed/held at some time.
    ## e.g. [3, 10] -> button 3 and 10 need to be pressed.
    ##
    ## This file format indexes buttons starting from 0 to 15::
    ## 
    ##  0  1  2  3
    ##  4  5  6  7
    ##  8  9  10 11
    ##  12 13 14 15
    ## 

    Tick* = object
        ## A tick referres to a time in the chart, where one or more
        ## actions need to be performed.
        time*: float
        ## Timestamp in milliseconds when the button needs to be pressed
        snapSize*: int
        ## optional. The snap-size in which this tick occurs
        snapIndex*: int
        ## optional. The snap-index in which the tick occurs
        notes*: seq[NoteRange]
        ## Sequence of notes to press at this time
        holds*: seq[Hold]
        ## Sequence of holds to start at this time
    
    Hold* = object
        ## A hold is a regular note which needs to be held until a certain time.
        ## It starts on the `from` position together with an animation which
        ## starts on the `to` position.
        ## The hold resolves at the `releaseOn` property (chart time, not offset),
        ## and is indicated with an animation.
        `from`*: NoteRange
        ## Index the hold starts on (see notes in Tick interface)
        to*: NoteRange
        ## Index the hold ends on (see notes in Tick interface)
        releaseOn*: float
        ## Timestamp in milliseconds when to release the note.
        ## There is no need to search for the hold end
        ## and animation duration can be calculated really easily

func asFormattingParams*(chart: ChartFile): FormattingParameters =
    ## Creates formatting-parameters from the provided chart-file

    result = newFormattingParameters(
        title = chart.title,
        artist = chart.artist,
        extension = $FileType.FXF,
    )

proc toJsonHook*[T: Table[Difficulty, Chart]](this: T): JsonNode =
    ## Hook to convert the Table of Difficulty and Chart to a proper json-object.
    ## Regular table hooks convert it with additional artifacting and breaking structure.

    result = newJObject()
    for key, value in this.pairs:
        result[$key] = toJson(value)

proc toJsonHook*[T: Tick](this: T): JsonNode =
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
