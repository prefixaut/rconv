import std/[macros, sequtils, strformat, sugar, tables, unittest]

import rconv/private/test_utils

import rconv/[memo, mapper]
import rconv/fxf as fxf
import rconv/malody as malody

suite "memo":
    proc verifyNote(
        name: string,
        notes: OrderedTable[NoteRange, seq[Note]],
        index: NoteRange,
        pos: int = 0,
        time: int,
        part: int = 0
    ): void =
        let testName = fmt"{name}: Notes {index}[{pos}], time: {time}, part: {part}"
        test testName:
            check:
                notes.hasKey(index)
                notes[index].len > pos
                notes[index][pos].time == time
                notes[index][pos].kind == NoteType.Note
                notes[index][pos].partIndex == part

    proc verifyHold(
        name: string,
        notes: OrderedTable[NoteRange, seq[Note]],
        index: NoteRange,
        pos: int = 0,
        start: NoteRange,
        time: int,
        release: int,
        releaseSection: int,
        part: int = 0
    ): void =
        let testName = fmt"{name}: Holds {index}[{pos}], time: {time}, part: {part}"
        test testName:
            check:
                notes.hasKey(index)
                notes[index].len > pos
                notes[index][pos].time == time
                notes[index][pos].kind == NoteType.Hold
                notes[index][pos].partIndex == part

            if notes[index][pos].kind == NoteType.Hold:
                check:
                    notes[index][pos].animationStartIndex == start
                    notes[index][pos].releaseTime == release
                    notes[index][pos].releaseSection == releaseSection

    macro noteBlock(name, notes, body) =
        ## Helper macro to add the `name` parameter to the `verifyNote` and `verifyHold` procs

        result = newStmtList()
        let whiteList = @["verifyNote", "verifyHold"]

        for node in body.children:
            if node.kind != nnkCall:
                result.add node
                continue

            let procName = node[0].strVal

            if not whiteList.contains(procName):
                result.add node
                continue

            var args: seq[NimNode] = @[]
            var isFirst = true

            let nameArg = newNimNode(nnkExprEqExpr)
            nameArg.add ident("name")
            nameArg.add newStrLitNode(name.strVal)
            args.add nameArg

            let notesArg = newNimNode(nnkExprEqExpr)
            notesArg.add ident("notes")
            notesArg.add notes
            args.add notesArg

            for arg in node.children:
                if isFirst:
                    isFirst = false
                    continue
                args.add arg

            result.add newCall(node[0], args)

    let testFile = """
Song-Title-BlaFoo
Artist-Foobar

EXTREME

Level: 8
BPM: 160-195
Notes: 1337

BPM: 195
1
口口口口 |－－－－|
口口口口 |－－－－|
口口口口 |－－－－|
口口口口 |－－－－|
2
③口⑤口 |①－②－|
口口②口 |③－④－|
口④⑦口 |⑤－－－|
⑥口口① |⑥－⑦－|
BPM: 160
3
口⑤⑤口 |①－②－|
②④④② |③－④－|
⑥①①⑥ |⑤－⑥－|
③⑦⑦③ |⑦－－－|
4
口③口④ |①ー②ー③ー|
①口＜口 |ー④⑤⑥|
口⑥口口 |⑦ーー⑧ーー⑨ー|
口口②口 |ー⑩⑪⑫|

⑩口⑨口
口＞口⑦
口口⑫口
口⑧口口

口口口口
③⑪⑤⑨
口口口口
口口口口
5
口口口口 |①－②－|
口口口④ |③－④－|
口②③①
②口口②

⑦⑦⑥⑦
⑤口口口
⑤口口⑧ |⑤－⑥－|
口口⑤口 |⑦－⑧－|
    """

    let parsed = parseMemo(testFile)

    test "Chart: Meta-Data":
        check:
            parsed.songTitle == "Song-Title-BlaFoo"
            parsed.artist == "Artist-Foobar"
            parsed.difficulty == Difficulty.Extreme
            parsed.level == 8
            parsed.bpmRange.min == 160.0
            parsed.bpmRange.max == 195.0
            parsed.sections.len == 5

    test "Section 1: Meta-Data":
        check:
            parsed.sections[0].index == 1
            parsed.sections[0].bpm == 195.0
            parsed.sections[0].partCount == 1
            parsed.sections[0].noteCount == 0
            parsed.sections[0].notes.len == 0
            parsed.sections[0].snaps.len == 4
            parsed.sections[0].snaps.all (snap) => snap.length == 4
            parsed.sections[0].timings.len == 16
            parsed.sections[0].timings.all (timing) => timing == -1

    test "Section 2: Meta-Data":
        check:
            parsed.sections[1].index == 2
            parsed.sections[1].bpm == 195.0
            parsed.sections[1].partCount == 1
            parsed.sections[1].noteCount == 7
            parsed.sections[1].notes.len == 7
            parsed.sections[1].snaps.len == 4
            parsed.sections[1].snaps.all (snap) => snap.length == 4

    noteBlock "Section 2", parsed.sections[1].notes:
        verifyNote(index = 0, time = 4)
        verifyNote(index = 2, time = 8)
        verifyNote(index = 6, time = 2)
        verifyNote(index = 9, time = 6)
        verifyNote(index = 10, time = 14)
        verifyNote(index = 12, time = 12)
        verifyNote(index = 15, time = 0)

    test "Section 2: Timings":
        check:
            parsed.sections[1].timings[0] == 1
            parsed.sections[1].timings[1] == -1
            parsed.sections[1].timings[2] == 2
            parsed.sections[1].timings[3] == -1
            parsed.sections[1].timings[4] == 3
            parsed.sections[1].timings[5] == -1
            parsed.sections[1].timings[6] == 4
            parsed.sections[1].timings[7] == -1
            parsed.sections[1].timings[8] == 5
            parsed.sections[1].timings[9] == -1
            parsed.sections[1].timings[10] == -1
            parsed.sections[1].timings[11] == -1
            parsed.sections[1].timings[12] == 6
            parsed.sections[1].timings[13] == -1
            parsed.sections[1].timings[14] == 7
            parsed.sections[1].timings[15] == -1

    test "Section 3: Meta-Data":
        check:
            parsed.sections[2].index == 3
            parsed.sections[2].bpm == 160.0
            parsed.sections[2].partCount == 1
            parsed.sections[2].noteCount == 14
            parsed.sections[2].notes.len == 14
            parsed.sections[2].snaps.len == 4
            parsed.sections[2].snaps.all (snap) => snap.length == 4


    noteBlock "Section 3", parsed.sections[2].notes:
        verifyNote(index = 1, time = 8)
        verifyNote(index = 2, time = 8)
        verifyNote(index = 4, time = 2)
        verifyNote(index = 5, time = 6)
        verifyNote(index = 6, time = 6)
        verifyNote(index = 7, time = 2)
        verifyNote(index = 8, time = 10)
        verifyNote(index = 9, time = 0)
        verifyNote(index = 10, time = 0)
        verifyNote(index = 11, time = 10)
        verifyNote(index = 12, time = 4)
        verifyNote(index = 13, time = 12)
        verifyNote(index = 14, time = 12)
        verifyNote(index = 15, time = 4)

    test "Section 3: Timings":
        check:
            parsed.sections[2].timings[0] == 1
            parsed.sections[2].timings[1] == -1
            parsed.sections[2].timings[2] == 2
            parsed.sections[2].timings[3] == -1
            parsed.sections[2].timings[4] == 3
            parsed.sections[2].timings[5] == -1
            parsed.sections[2].timings[6] == 4
            parsed.sections[2].timings[7] == -1
            parsed.sections[2].timings[8] == 5
            parsed.sections[2].timings[9] == -1
            parsed.sections[2].timings[10] == 6
            parsed.sections[2].timings[11] == -1
            parsed.sections[2].timings[12] == 7
            parsed.sections[2].timings[13] == -1
            parsed.sections[2].timings[14] == -1
            parsed.sections[2].timings[15] == -1

    test "Section 4: Meta-Data":
        check:
            parsed.sections[3].index == 4
            parsed.sections[3].bpm == 160.0
            parsed.sections[3].partCount == 3
            parsed.sections[3].noteCount == 12
            parsed.sections[3].notes.len == 12
            parsed.sections[3].snaps.len == 4
            parsed.sections[3].snaps[0].length == 6
            parsed.sections[3].snaps[1].length == 4
            parsed.sections[3].snaps[2].length == 8
            parsed.sections[3].snaps[3].length == 4

    noteBlock "Section 4", notes = parsed.sections[3].notes:
        verifyNote(index = 0, time = 19, part = 1)
        verifyNote(index = 1, time = 4)
        verifyNote(index = 2, time = 16, part = 1)
        verifyNote(index = 3, time = 7)
        verifyHold(
            index = 4,
            start = 6,
            time = 0,
            release = 4,
            releaseSection = parsed.sections[3].index
        )
        verifyNote(index = 5, time = 20, part = 2)
        verifyNote(index = 6, time = 8, part = 2)
        verifyHold(
            index = 7,
            start = 5,
            time = 10,
            release = 16,
            releaseSection = parsed.sections[3].index,
            part = 1
        )
        verifyNote(index = 9, time = 9)
        verifyNote(index = 10, time = 21, part = 1)
        verifyNote(index = 13, time = 13, part = 1)
        verifyNote(index = 14, time = 2)

    test "Section 4: Timings":
        check:
            parsed.sections[3].timings[0] == 1
            parsed.sections[3].timings[1] == -1
            parsed.sections[3].timings[2] == 2
            parsed.sections[3].timings[3] == -1
            parsed.sections[3].timings[4] == 3
            parsed.sections[3].timings[5] == -1
            parsed.sections[3].timings[6] == -1
            parsed.sections[3].timings[7] == 4
            parsed.sections[3].timings[8] == 5
            parsed.sections[3].timings[9] == 6
            parsed.sections[3].timings[10] == 7
            parsed.sections[3].timings[11] == -1
            parsed.sections[3].timings[12] == -1
            parsed.sections[3].timings[13] == 8
            parsed.sections[3].timings[14] == -1
            parsed.sections[3].timings[15] == -1
            parsed.sections[3].timings[16] == 9
            parsed.sections[3].timings[17] == -1
            parsed.sections[3].timings[18] == -1
            parsed.sections[3].timings[19] == 10
            parsed.sections[3].timings[20] == 11
            parsed.sections[3].timings[21] == 12

    test "Section 5: Meta-Data":
        check:
            parsed.sections[4].index == 5
            parsed.sections[4].bpm == 160.0
            parsed.sections[4].partCount == 2
            parsed.sections[4].noteCount == 14
            parsed.sections[4].notes.len == 13
            parsed.sections[4].snaps.len == 4
            parsed.sections[4].snaps.all (snap) => snap.length == 4
            parsed.sections[4].snaps[0].partIndex == 0
            parsed.sections[4].snaps[1].partIndex == 0
            parsed.sections[4].snaps[2].partIndex == 1
            parsed.sections[4].snaps[3].partIndex == 1

    noteBlock "Section 5", parsed.sections[4].notes:
        verifyNote(index = 0, time = 12, part = 1)
        verifyNote(index = 1, time = 12, part = 1)
        verifyNote(index = 2, time = 10, part = 1)
        verifyNote(index = 3, time = 12, part = 1)
        verifyNote(index = 4, time = 8, part = 1)
        verifyNote(index = 7, time = 6)
        verifyNote(index = 8, time = 8, part = 1)
        verifyNote(index = 9, time = 2)
        verifyNote(index = 10, time = 4)
        verifyNote(index = 11, time = 0)
        verifyNote(index = 11, pos = 1, time = 14, part = 1)
        verifyNote(index = 12, time = 2)
        verifyNote(index = 14, time = 8, part = 1)
        verifyNote(index = 15, time = 2)

    test "Section 5: Timings":
        check:
            parsed.sections[4].timings[0] == 1
            parsed.sections[4].timings[1] == -1
            parsed.sections[4].timings[2] == 2
            parsed.sections[4].timings[3] == -1
            parsed.sections[4].timings[4] == 3
            parsed.sections[4].timings[5] == -1
            parsed.sections[4].timings[6] == 4
            parsed.sections[4].timings[7] == -1
            parsed.sections[4].timings[8] == 5
            parsed.sections[4].timings[9] == -1
            parsed.sections[4].timings[10] == 6
            parsed.sections[4].timings[11] == -1
            parsed.sections[4].timings[12] == 7
            parsed.sections[4].timings[13] == -1
            parsed.sections[4].timings[14] == 8
            parsed.sections[4].timings[15] == -1

suite "memo converter":
    let testFile = """
Song-Title-BlaFoo
Artist-Foobar

EXTREME

Level: 8
BPM: 160-195
Notes: 1337

BPM: 195
1
口口口口 |－－－－|
口口口口 |－－－－|
口口口口 |－－－－|
口口口口 |－－－－|
2
③口⑤口 |①－②－|
口口②口 |③－④－|
口④⑦口 |⑤－－－|
⑥口口① |⑥－⑦－|
BPM: 160
3
口③口④ |①ー②ー③ー|
①口＜口 |ー④⑤⑥|
口⑥口口 |⑦ーー⑧ーー⑨ー|
口口②口 |ー⑩⑪⑫|

⑩口⑨口
口＞口⑦
口口⑫口
口⑧口口

口口口口
③⑪⑤⑨
口口口口
口口⑪口
"""
    let parsed = parseMemo(testFile)

    test "to fxf":
        let chart = parsed.toFXF
        check:
            # File Meta-Data
            chart.version == fxf.Version1
            chart.title == "Song-Title-BlaFoo"
            chart.artist == "Artist-Foobar"
            chart.audio == "audio.mp3"
            chart.jacket == "jacket.png"
            chart.offset == 0
            chart.numBpm == 2

            # BPM Changes
            chart.bpmChange[0].time == 0
            chart.bpmChange[0].bpm == 195.0
            chart.bpmChange[0].snapIndex == 0
            chart.bpmChange[0].snapSize == 4
            # Times are rounded down to tens, as they are already milliseconds
            # and more precision isn't needed
            int(chart.bpmChange[1].time * 10) == int(2_461.5 * 10)
            chart.bpmChange[1].bpm == 160.0
            chart.bpmChange[1].snapIndex == 0
            chart.bpmChange[1].snapSize == 6

            # Difficulties/Charts
            chart.charts.bscPresent == 0
            chart.charts.basic == nil
            chart.charts.advPresent == 0
            chart.charts.advanced == nil
            chart.charts.extPresent == 1
            chart.charts.extreme != nil

        let diff = chart.charts.extreme
        check:
            # Rating must be multiplied * 10 in the file
            diff.rating == 80
            diff.numTick == 19

        check:
            diff.ticks[0].numNotes == 1
            diff.ticks[0].numHolds == 0
            int(diff.ticks[0].time * 10) == 12_308
            diff.ticks[0].snapSize == 4
            diff.ticks[0].snapIndex == 0
            diff.ticks[0].notes[0] == 15

        check:
            diff.ticks[1].numNotes == 1
            diff.ticks[1].numHolds == 0
            int(diff.ticks[1].time * 10) == 13_846
            diff.ticks[1].snapSize == 4
            diff.ticks[1].snapIndex == 2
            diff.ticks[1].notes[0] == 6

        check:
            diff.ticks[2].numNotes == 1
            diff.ticks[2].numHolds == 0
            int(diff.ticks[2].time * 10) == 15_385
            diff.ticks[2].snapSize == 4
            diff.ticks[2].snapIndex == 0
            diff.ticks[2].notes[0] == 0

        check:
            diff.ticks[3].numNotes == 1
            diff.ticks[3].numHolds == 0
            int(diff.ticks[3].time * 10) == 16_923
            diff.ticks[3].snapSize == 4
            diff.ticks[3].snapIndex == 2
            diff.ticks[3].notes[0] == 9

        check:
            diff.ticks[4].numNotes == 1
            diff.ticks[4].numHolds == 0
            int(diff.ticks[4].time * 10) == 18_462
            diff.ticks[4].snapSize == 4
            diff.ticks[4].snapIndex == 0
            diff.ticks[4].notes[0] == 2

        check:
            diff.ticks[5].numNotes == 1
            diff.ticks[5].numHolds == 0
            int(diff.ticks[5].time * 10) == 21_538
            diff.ticks[5].snapSize == 4
            diff.ticks[5].snapIndex == 0
            diff.ticks[5].notes[0] == 12

        check:
            diff.ticks[6].numNotes == 1
            diff.ticks[6].numHolds == 0
            int(diff.ticks[6].time * 10) == 23_077
            diff.ticks[6].snapSize == 4
            diff.ticks[6].snapIndex == 2
            diff.ticks[6].notes[0] == 10

        check:
            diff.ticks[7].numNotes == 0
            diff.ticks[7].numHolds == 1
            int(diff.ticks[7].time * 10) == 24_615
            diff.ticks[7].snapSize == 6
            diff.ticks[7].snapIndex == 0
            diff.ticks[7].holds[0].`from` == 6
            diff.ticks[7].holds[0].to == 4
            int(diff.ticks[7].holds[0].releaseOn * 10) == 27_115

        check:
            diff.ticks[8].numNotes == 1
            diff.ticks[8].numHolds == 0
            int(diff.ticks[8].time * 10) == 25_865
            diff.ticks[8].snapSize == 6
            diff.ticks[8].snapIndex == 2
            diff.ticks[8].notes[0] == 14

        check:
            diff.ticks[9].numNotes == 1
            diff.ticks[9].numHolds == 0
            int(diff.ticks[9].time * 10) == 27_115
            diff.ticks[9].snapSize == 6
            diff.ticks[9].snapIndex == 4
            diff.ticks[9].notes[0] == 1

        check:
            diff.ticks[10].numNotes == 1
            diff.ticks[10].numHolds == 0
            int(diff.ticks[10].time * 10) == 29_303
            diff.ticks[10].snapSize == 4
            diff.ticks[10].snapIndex == 1
            diff.ticks[10].notes[0] == 3

        check:
            diff.ticks[11].numNotes == 1
            diff.ticks[11].numHolds == 0
            int(diff.ticks[11].time * 10) == 30240
            diff.ticks[11].snapSize == 4
            diff.ticks[11].snapIndex == 2
            diff.ticks[11].notes[0] == 6

        check:
            diff.ticks[12].numNotes == 1
            diff.ticks[12].numHolds == 0
            int(diff.ticks[12].time * 10) == 31_178
            diff.ticks[12].snapSize == 4
            diff.ticks[12].snapIndex == 3
            diff.ticks[12].notes[0] == 9

        check:
            diff.ticks[13].numNotes == 0
            diff.ticks[13].numHolds == 1
            int(diff.ticks[13].time * 10) == 32_115
            diff.ticks[13].snapSize == 8
            diff.ticks[13].snapIndex == 0
            diff.ticks[13].holds[0].`from` == 5
            diff.ticks[13].holds[0].to == 7
            int(diff.ticks[13].holds[0].releaseOn * 10) == 34_928

        check:
            diff.ticks[14].numNotes == 1
            diff.ticks[14].numHolds == 0
            int(diff.ticks[14].time * 10) == 33_522
            diff.ticks[14].snapSize == 8
            diff.ticks[14].snapIndex == 3
            diff.ticks[14].notes[0] == 13

        check:
            diff.ticks[15].numNotes == 1
            diff.ticks[15].numHolds == 0
            int(diff.ticks[15].time * 10) == 34_928
            diff.ticks[15].snapSize == 8
            diff.ticks[15].snapIndex == 6
            diff.ticks[15].notes[0] == 2

        check:
            diff.ticks[16].numNotes == 1
            diff.ticks[16].numHolds == 0
            int(diff.ticks[16].time * 10) == 36_803
            diff.ticks[16].snapSize == 4
            diff.ticks[16].snapIndex == 1
            diff.ticks[16].notes[0] == 0

        check:
            diff.ticks[17].numNotes == 2
            diff.ticks[17].numHolds == 0
            int(diff.ticks[17].time * 10) == 37_740
            diff.ticks[17].snapSize == 4
            diff.ticks[17].snapIndex == 2
            diff.ticks[17].notes[0] == 5
            diff.ticks[17].notes[1] == 14

        check:
            diff.ticks[18].numNotes == 1
            diff.ticks[18].numHolds == 0
            int(diff.ticks[18].time * 10) == 38_678
            diff.ticks[18].snapSize == 4
            diff.ticks[18].snapIndex == 3
            diff.ticks[18].notes[0] == 10

    test "to malody":
        let chart = parsed.toMalody

        check:
            chart.meta.`$ver` == 1
            chart.meta.version == "Extreme"
            chart.meta.mode == malody.ChartMode.Pad
            chart.meta.song.title == "Song-Title-BlaFoo"
            chart.meta.song.artist == "Artist-Foobar"

        check:
            chart.time.len == 2
            chart.time.all(elem =>
                elem.kind == malody.ElementType.TimeSignature and elem.hold == malody.HoldType.None)

            chart.time[0].beat == [0, 0, 4]
            chart.time[0].sigBpm == 195.0

            chart.time[1].beat == [8, 0, 6]
            chart.time[1].sigBpm == 160.0

        check:
            chart.note.len == 20

        testMalodyIndexNote(chart.note[0], [4, 0, 4], 15)
        testMalodyIndexNote(chart.note[1], [4, 2, 4], 6)
        testMalodyIndexNote(chart.note[2], [5, 0, 4], 0)
        testMalodyIndexNote(chart.note[3], [5, 2, 4], 9)
        testMalodyIndexNote(chart.note[4], [6, 0, 4], 2)
        testMalodyIndexNote(chart.note[5], [7, 0, 4], 12)
        testMalodyIndexNote(chart.note[6], [7, 2, 4], 10)

        testMalodyIndexHold(chart.note[7], [8, 0, 6], 4, [8, 4, 6], 6)
        testMalodyIndexNote(chart.note[8], [8, 2, 6], 14)
        testMalodyIndexNote(chart.note[9], [8, 4, 6], 1)
        testMalodyIndexNote(chart.note[10], [9, 1, 4], 3)
        testMalodyIndexNote(chart.note[11], [9, 2, 4], 6)
        testMalodyIndexNote(chart.note[12], [9, 3, 4], 9)
        testMalodyIndexHold(chart.note[13], [10, 0, 8], 7, [10, 6, 8], 5)
        testMalodyIndexNote(chart.note[14], [10, 3, 8], 13)
        testMalodyIndexNote(chart.note[15], [10, 6, 8], 2)
        testMalodyIndexNote(chart.note[16], [11, 1, 4], 0)
        testMalodyIndexNote(chart.note[17], [11, 2, 4], 5)
        testMalodyIndexNote(chart.note[18], [11, 2, 4], 14)
        testMalodyIndexNote(chart.note[19], [11, 3, 4], 10)