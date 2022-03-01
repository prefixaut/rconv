import std/[macros, sequtils, strformat, sugar, tables, unittest]

import rconv/memo
import rconv/memson

proc verifyNote(
    name: string,
    notes: OrderedTable[NoteRange, seq[Note]],
    index: NoteRange,
    pos: int = 0,
    time: int,
    part: int = 0
): void =
    let testName = fmt"{name} Note {index}[{pos}], time: {time}, part: {part}"
    test testName:
        # TODO: Find a way to connect this new test to the suite of where it's executed
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
    let testName = fmt"{name} Hold {index}[{pos}], time: {time}, part: {part}"
    test testName:
        # TODO: Find a way to connect this new test to the suite of where it's executed
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

macro noteBlock(name, body) =
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

        var nameArg = newNimNode(nnkExprEqExpr)
        nameArg.add ident("name")
        nameArg.add newStrLitNode(name.strVal)
        args.add nameArg

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

suite "memo":
    let parsed = parseMemoToMemson(testFile)

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
            parsed.sections[0].snaps.all (snap) => snap.len == 4
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
            parsed.sections[1].snaps.all (snap) => snap.len == 4

    noteBlock "Section 2":
        verifyNote(notes = parsed.sections[1].notes, index = 0, time = 4)
        verifyNote(notes = parsed.sections[1].notes, index = 2, time = 8)
        verifyNote(notes = parsed.sections[1].notes, index = 6, time = 2)
        verifyNote(notes = parsed.sections[1].notes, index = 9, time = 6)
        verifyNote(notes = parsed.sections[1].notes, index = 10, time = 14)
        verifyNote(notes = parsed.sections[1].notes, index = 12, time = 12)
        verifyNote(notes = parsed.sections[1].notes, index = 15, time = 0)

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
            parsed.sections[2].snaps.all (snap) => snap.len == 4


    noteBlock "Section 3":
        verifyNote(notes = parsed.sections[2].notes, index = 1, time = 8)
        verifyNote(notes = parsed.sections[2].notes, index = 2, time = 8)
        verifyNote(notes = parsed.sections[2].notes, index = 4, time = 2)
        verifyNote(notes = parsed.sections[2].notes, index = 5, time = 6)
        verifyNote(notes = parsed.sections[2].notes, index = 6, time = 6)
        verifyNote(notes = parsed.sections[2].notes, index = 7, time = 2)
        verifyNote(notes = parsed.sections[2].notes, index = 8, time = 10)
        verifyNote(notes = parsed.sections[2].notes, index = 9, time = 0)
        verifyNote(notes = parsed.sections[2].notes, index = 10, time = 0)
        verifyNote(notes = parsed.sections[2].notes, index = 11, time = 10)
        verifyNote(notes = parsed.sections[2].notes, index = 12, time = 4)
        verifyNote(notes = parsed.sections[2].notes, index = 13, time = 12)
        verifyNote(notes = parsed.sections[2].notes, index = 14, time = 12)
        verifyNote(notes = parsed.sections[2].notes, index = 15, time = 4)

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
            parsed.sections[3].snaps[0].len == 6
            parsed.sections[3].snaps[1].len == 4
            parsed.sections[3].snaps[2].len == 8
            parsed.sections[3].snaps[3].len == 4

    noteBlock "Section 4":
        verifyNote(notes = parsed.sections[3].notes, index = 0, time = 19, part = 1)
        verifyNote(notes = parsed.sections[3].notes, index = 1, time = 4)
        verifyNote(notes = parsed.sections[3].notes, index = 2, time = 16, part = 1)
        verifyNote(notes = parsed.sections[3].notes, index = 3, time = 7)
        verifyHold(
            notes = parsed.sections[3].notes,
            index = 4,
            pos = 0,
            start = 6,
            time = 0,
            release = 4,
            releaseSection = parsed.sections[3].index
        )
        verifyNote(notes = parsed.sections[3].notes, index = 5, time = 20, part = 2)
        verifyNote(notes = parsed.sections[3].notes, index = 6, time = 8, part = 2)
        verifyHold(
            notes = parsed.sections[3].notes,
            index = 7,
            pos = 0,
            start = 5,
            time = 10,
            release = 16,
            releaseSection = parsed.sections[3].index,
            part = 1
        )
        verifyNote(notes = parsed.sections[3].notes, index = 9, time = 9)
        verifyNote(notes = parsed.sections[3].notes, index = 10, time = 21, part = 1)
        verifyNote(notes = parsed.sections[3].notes, index = 13, time = 13, part = 1)
        verifyNote(notes = parsed.sections[3].notes, index = 14, time = 2)

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

    # 口口口口 |①－②－|
    # 口口口④ |③－④－|
    # 口②③①
    # ②口口②
    # 
    # ⑦⑦⑥⑦
    # ⑤口口口
    # ⑤口口⑧ |⑤－⑥－|
    # 口口⑤口 |⑦－⑧－|

    test "Section 5: Meta-Data":
        check:
            parsed.sections[4].index == 5
            parsed.sections[4].bpm == 160.0
            parsed.sections[4].partCount == 2
            parsed.sections[4].noteCount == 14
            parsed.sections[4].notes.len == 13
            parsed.sections[4].snaps.len == 4
            parsed.sections[4].snaps.all (snap) => snap.len == 4
    
    noteBlock "Section 5":

