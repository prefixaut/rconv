import std/[tables, sequtils, strformat, sugar]

import pkg/balls

import rconv/memo
import rconv/memson

proc verifyNote(
    name: string,
    notes: OrderedTable[NoteRange, seq[Note]],
    index: NoteRange,
    pos: int = 0,
    time: int,
    part: int = 0
): void {.inline.} =
    let testName = fmt"#{name} Note #{index}[#{pos}], time: #{time}, part: #{part}"
    test testName:
        check notes.hasKey(index)
        check notes[index].len > pos
        check notes[index][pos].time == time
        check notes[index][pos].kind == NoteType.Note
        check notes[index][pos].partIndex == part

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
): void {.inline.} = 
    let testName = fmt"#{name} Hold #{index}[#{pos}], time: #{time}, part: #{part}"
    test testName:
        check notes.hasKey(index)
        check notes[index].len > pos
        check notes[index][pos].time == time
        check notes[index][pos].kind == NoteType.Hold
        check notes[index][pos].partIndex == part

        if notes[index][pos].kind == NoteType.Hold:
            check notes[index][pos].animationStartIndex == start
            check notes[index][pos].releaseTime == release
            check notes[index][pos].releaseSection == releaseSection

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

suite "memo":
    let parsed = parseMemoToMemson(testFile)

    block:
        ## Chart: Meta-Data
        check parsed.songTitle == "Song-Title-BlaFoo"
        check parsed.artist == "Artist-Foobar"
        check parsed.difficulty == Difficulty.Extreme
        check parsed.level == 8
        check parsed.bpmRange.min == 160.0
        check parsed.bpmRange.max == 195.0
        check parsed.sections.len == 5

    block:
        ## Section 1: Meta-Data
        check parsed.sections[0].index == 1
        check parsed.sections[0].bpm == 195.0
        check parsed.sections[0].partCount == 1
        check parsed.sections[0].noteCount == 0
        check parsed.sections[0].notes.len == 0
        check parsed.sections[0].snaps.len == 4
        check parsed.sections[0].snaps.all (snap) => snap.len == 4
        check parsed.sections[0].timings.len == 16
        check parsed.sections[0].timings.all (timing) => timing == -1

    block:
        ## Section 2: Meta-Data
        check parsed.sections[1].index == 2
        check parsed.sections[1].bpm == 195.0
        check parsed.sections[1].partCount == 1
        check parsed.sections[1].noteCount == 7
        check parsed.sections[1].notes.len == 7
        check parsed.sections[1].snaps.len == 4
        check parsed.sections[1].snaps.all (snap) => snap.len == 4

    block:
        ## Section 2: Notes
    verifyNote(name = "Section 2", notes = parsed.sections[1].notes, index = 0, time = 4)
    verifyNote(name = "Section 2", notes = parsed.sections[1].notes, index = 2, time = 8)
    verifyNote(name = "Section 2", notes = parsed.sections[1].notes, index = 6, time = 2)
    verifyNote(name = "Section 2", notes = parsed.sections[1].notes, index = 9, time = 6)
    verifyNote(name = "Section 2", notes = parsed.sections[1].notes, index = 10, time = 14)
    verifyNote(name = "Section 2", notes = parsed.sections[1].notes, index = 12, time = 12)
    verifyNote(name = "Section 2", notes = parsed.sections[1].notes, index = 15, time = 0)

    block:
        ## Section 2: Timings
        check parsed.sections[1].timings[0] == 1
        check parsed.sections[1].timings[1] == -1
        check parsed.sections[1].timings[2] == 2
        check parsed.sections[1].timings[3] == -1
        check parsed.sections[1].timings[4] == 3
        check parsed.sections[1].timings[5] == -1
        check parsed.sections[1].timings[6] == 4
        check parsed.sections[1].timings[7] == -1
        check parsed.sections[1].timings[8] == 5
        check parsed.sections[1].timings[9] == -1
        check parsed.sections[1].timings[10] == -1
        check parsed.sections[1].timings[11] == -1
        check parsed.sections[1].timings[12] == 6
        check parsed.sections[1].timings[13] == -1
        check parsed.sections[1].timings[14] == 7
        check parsed.sections[1].timings[15] == -1

    block:
        ## Section 3: Meta-Data
        check parsed.sections[2].index == 3
        check parsed.sections[2].bpm == 160.0
        check parsed.sections[2].partCount == 1
        check parsed.sections[2].noteCount == 14
        check parsed.sections[2].notes.len == 14
        check parsed.sections[2].snaps.len == 4
        check parsed.sections[2].snaps.all (snap) => snap.len == 4

    block:
        ## Section 3: Notes
    verifyNote(name = "Section 3", notes = parsed.sections[2].notes, index = 1, time = 8)
    verifyNote(name = "Section 3", notes = parsed.sections[2].notes, index = 2, time = 8)
    verifyNote(name = "Section 3", notes = parsed.sections[2].notes, index = 4, time = 2)
    verifyNote(name = "Section 3", notes = parsed.sections[2].notes, index = 5, time = 6)
    verifyNote(name = "Section 3", notes = parsed.sections[2].notes, index = 6, time = 6)
    verifyNote(name = "Section 3", notes = parsed.sections[2].notes, index = 7, time = 2)
    verifyNote(name = "Section 3", notes = parsed.sections[2].notes, index = 8, time = 10)
    verifyNote(name = "Section 3", notes = parsed.sections[2].notes, index = 9, time = 0)
    verifyNote(name = "Section 3", notes = parsed.sections[2].notes, index = 10, time = 0)
    verifyNote(name = "Section 3", notes = parsed.sections[2].notes, index = 11, time = 10)
    verifyNote(name = "Section 3", notes = parsed.sections[2].notes, index = 12, time = 4)
    verifyNote(name = "Section 3", notes = parsed.sections[2].notes, index = 13, time = 12)
    verifyNote(name = "Section 3", notes = parsed.sections[2].notes, index = 14, time = 12)
    verifyNote(name = "Section 3", notes = parsed.sections[2].notes, index = 15, time = 4)

    block:
        ## Section 3: Timings
        check parsed.sections[2].timings[0] == 1
        check parsed.sections[2].timings[1] == -1
        check parsed.sections[2].timings[2] == 2
        check parsed.sections[2].timings[3] == -1
        check parsed.sections[2].timings[4] == 3
        check parsed.sections[2].timings[5] == -1
        check parsed.sections[2].timings[6] == 4
        check parsed.sections[2].timings[7] == -1
        check parsed.sections[2].timings[8] == 5
        check parsed.sections[2].timings[9] == -1
        check parsed.sections[2].timings[10] == 6
        check parsed.sections[2].timings[11] == -1
        check parsed.sections[2].timings[12] == 7
        check parsed.sections[2].timings[13] == -1
        check parsed.sections[2].timings[14] == -1
        check parsed.sections[2].timings[15] == -1

    block:
        ## Section 4: Meta-Data
        check parsed.sections[3].index == 4
        check parsed.sections[3].bpm == 160.0
        check parsed.sections[3].partCount == 3
        check parsed.sections[3].noteCount == 12
        check parsed.sections[3].notes.len == 12
        check parsed.sections[3].snaps.len == 4
        check parsed.sections[3].snaps[0].len == 6
        check parsed.sections[3].snaps[1].len == 4
        check parsed.sections[3].snaps[2].len == 8
        check parsed.sections[3].snaps[3].len == 4

    block:
        ## Section 4: Notes
    verifyNote(name = "Section 4", notes = parsed.sections[3].notes, index = 0, time = 19, part = 1)
    verifyNote(name = "Section 4", notes = parsed.sections[3].notes, index = 1, time = 4)
    verifyNote(name = "Section 4", notes = parsed.sections[3].notes, index = 2, time = 16, part = 1)
    verifyNote(name = "Section 4", notes = parsed.sections[3].notes, index = 3, time = 7)
    verifyHold(
        name = "Section 4",
        notes = parsed.sections[3].notes,
        index = 4,
        pos = 0,
        start = 6,
        time = 0,
        release = 4,
        releaseSection = parsed.sections[3].index
    )
    verifyNote(name = "Section 4", notes = parsed.sections[3].notes, index = 5, time = 20, part = 2)
    verifyNote(name = "Section 4", notes = parsed.sections[3].notes, index = 6, time = 8, part = 2)
    verifyHold(
        name = "Section 4",
        notes = parsed.sections[3].notes,
        index = 7,
        pos = 0,
        start = 5,
        time = 10,
        release = 16,
        releaseSection = parsed.sections[3].index,
        part = 1
    )
    verifyNote(name = "Section 4", notes = parsed.sections[3].notes, index = 9, time = 9)
    verifyNote(name = "Section 4", notes = parsed.sections[3].notes, index = 10, time = 21, part = 1)
    verifyNote(name = "Section 4", notes = parsed.sections[3].notes, index = 13, time = 13, part = 1)
    verifyNote(name = "Section 4", notes = parsed.sections[3].notes, index = 14, time = 2)

    block:
        ## Section 4: Timings
        check parsed.sections[3].timings[0] == 1
        check parsed.sections[3].timings[1] == -1
        check parsed.sections[3].timings[2] == 2
        check parsed.sections[3].timings[3] == -1
        check parsed.sections[3].timings[4] == 3
        check parsed.sections[3].timings[5] == -1
        check parsed.sections[3].timings[6] == -1
        check parsed.sections[3].timings[7] == 4
        check parsed.sections[3].timings[8] == 5
        check parsed.sections[3].timings[9] == 6
        check parsed.sections[3].timings[10] == 7
        check parsed.sections[3].timings[11] == -1
        check parsed.sections[3].timings[12] == -1
        check parsed.sections[3].timings[13] == 8
        check parsed.sections[3].timings[14] == -1
        check parsed.sections[3].timings[15] == -1
        check parsed.sections[3].timings[16] == 9
        check parsed.sections[3].timings[17] == -1
        check parsed.sections[3].timings[18] == -1
        check parsed.sections[3].timings[19] == 10
        check parsed.sections[3].timings[20] == 11
        check parsed.sections[3].timings[21] == 12

    # 口口口口 |①－②－|
    # 口口口④ |③－④－|
    # 口②③①
    # ②口口②
    # 
    # ⑦⑦⑥⑦
    # ⑤口口口
    # ⑤口口⑧ |⑤－⑥－|
    # 口口⑤口 |⑦－⑧－|

    block:
        ## Section 5: Meta-Data
        check parsed.sections[4].index == 5
        check parsed.sections[4].bpm == 160.0
        check parsed.sections[4].partCount == 2
        check parsed.sections[4].noteCount == 14
        check parsed.sections[4].notes.len == 13
        check parsed.sections[4].snaps.len == 4
        check parsed.sections[4].snaps.all (snap) => snap.len == 4
