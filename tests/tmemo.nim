import std/[tables, sequtils, sugar, unittest]

import rconv/memo
import rconv/memson

proc verifyNote(notes: OrderedTable[NoteRange, Note], index: NoteRange, time: int, part: int = 0): void =
    check:
        notes.hasKey(index)
        notes[index].time == time
        notes[index].kind == NoteType.Note
        notes[index].partIndex == part

proc verifyHold(notes: OrderedTable[NoteRange, Note], index: NoteRange, start: NoteRange, time: int, release: int, releaseSection: int, part: int = 0): void =
    check:
        notes.hasKey(index)
        notes[index].time == time
        notes[index].kind == NoteType.Hold
        notes[index].partIndex == part
        notes[index].animationStartIndex == start
        notes[index].releaseTime == release
        notes[index].releaseSection == releaseSection

suite "memo":
    test "can parse v1 correctly":
        let fileData = """
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

        let parsed = parseMemoToMemson(fileData)
        check:
            parsed.songTitle == "Song-Title-BlaFoo"
            parsed.artist == "Artist-Foobar"
            parsed.difficulty == Difficulty.Extreme
            parsed.level == 8
            parsed.bpmRange.min == 160.0
            parsed.bpmRange.max == 195.0
            parsed.sections.len == 5

        check:
            parsed.sections[0].index == 1
            parsed.sections[0].bpm == 195.0
            parsed.sections[0].notes.len == 0
            parsed.sections[0].snaps.len == 4
            parsed.sections[0].snaps.all (snap) => snap.len == 4
            parsed.sections[0].timings.len == 16
            parsed.sections[0].timings.all (timing) => timing == -1
            parsed.sections[0].partCount == 1

        check:
            parsed.sections[1].index == 2
            parsed.sections[1].bpm == 195.0
            parsed.sections[1].partCount == 1
            parsed.sections[1].notes.len == 7
            parsed.sections[1].snaps.all (snap) => snap.len == 4

        verifyNote(parsed.sections[1].notes, 0, 4)
        verifyNote(parsed.sections[1].notes, 2, 8)
        verifyNote(parsed.sections[1].notes, 6, 2)
        verifyNote(parsed.sections[1].notes, 9, 6)
        verifyNote(parsed.sections[1].notes, 10, 14)
        verifyNote(parsed.sections[1].notes, 12, 12)
        verifyNote(parsed.sections[1].notes, 15, 0)

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

        check:
            parsed.sections[2].index == 3
            parsed.sections[2].bpm == 160.0
            parsed.sections[2].partCount == 1
            parsed.sections[2].notes.len == 14
            parsed.sections[2].snaps.all (snap) => snap.len == 4

        verifyNote(parsed.sections[2].notes, 1, 8)
        verifyNote(parsed.sections[2].notes, 2, 8)
        verifyNote(parsed.sections[2].notes, 4, 2)
        verifyNote(parsed.sections[2].notes, 5, 6)
        verifyNote(parsed.sections[2].notes, 6, 6)
        verifyNote(parsed.sections[2].notes, 7, 2)
        verifyNote(parsed.sections[2].notes, 8, 10)
        verifyNote(parsed.sections[2].notes, 9, 0)
        verifyNote(parsed.sections[2].notes, 10, 0)
        verifyNote(parsed.sections[2].notes, 11, 10)
        verifyNote(parsed.sections[2].notes, 12, 4)
        verifyNote(parsed.sections[2].notes, 13, 12)
        verifyNote(parsed.sections[2].notes, 14, 12)
        verifyNote(parsed.sections[2].notes, 15, 4)

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

        # 口③口④ |①ー②ー③ー| 6
        # ①口＜口 |ー④⑤⑥| 10
        # 口⑥口口 |⑦ーー⑧ーー⑨ー| 18
        # 口口②口 |ー⑩⑪⑫| 22

        # ⑩口⑨口
        # 口＞口⑦
        # 口口⑫口
        # 口⑧口口

        # 口口口口
        # ③⑪⑤⑨
        # 口口口口
        # 口口口口

        check:
            parsed.sections[3].index == 4
            parsed.sections[3].bpm == 160.0
            parsed.sections[3].partCount == 3
            parsed.sections[3].notes.len == 12
            parsed.sections[3].snaps[0].len == 6
            parsed.sections[3].snaps[1].len == 4
            parsed.sections[3].snaps[2].len == 8
            parsed.sections[3].snaps[3].len == 4

        verifyNote(parsed.sections[3].notes, 0, 19, 1)
        verifyNote(parsed.sections[3].notes, 1, 4)
        verifyNote(parsed.sections[3].notes, 2, 16, 1)
        verifyNote(parsed.sections[3].notes, 3, 7)
        verifyHold(parsed.sections[3].notes,
            index = 4,
            start = 6,
            time = 0,
            release = 4,
            releaseSection = parsed.sections[3].index
        )
        verifyNote(parsed.sections[3].notes, 5, 20, 2)
        verifyNote(parsed.sections[3].notes, 6, 8, 2)
        verifyHold(parsed.sections[3].notes,
            index = 7,
            start = 5,
            time = 10,
            release = 16,
            releaseSection = parsed.sections[3].index,
            part = 1
        )
        verifyNote(parsed.sections[3].notes, 9, 13)
        verifyNote(parsed.sections[3].notes, 10, 21, 1)
        verifyNote(parsed.sections[3].notes, 13, 13)
        verifyNote(parsed.sections[3].notes, 14, 2, 1)
