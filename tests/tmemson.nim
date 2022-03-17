import std/[sequtils, sugar, unittest]

import rconv/[memo, mapper]
import rconv/fxf as fxf
import rconv/malody as malody
import rconv/private/test_utils

suite "memson: convert":
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
            chart.meta.version == "extreme"
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

