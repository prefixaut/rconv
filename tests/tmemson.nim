import std/unittest

import rconv/[memo, mapper]
import rconv/fxf as fxf

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

suite "memson: convert":
    let parsed = parseMemoToMemson(testFile)

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
            chart.bpmChange[1].snapSize == 4

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
            diff.numTick == 34

        check:
            int(diff.ticks[0].time * 10) == int(1_230.7 * 10)
