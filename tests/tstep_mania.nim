import std/[strformat, unittest, options, tables]

import rconv/step_mania

suite "step-mania":
    let regularNotes = {
        NoteType.Note: "1",
        NoteType.Mine: "M",
        NoteType.Lift: "L",
        NoteType.Fake: "F",
    }.toTable
    let holdNotes = {
        NoteType.Hold: "2",
        NoteType.Roll: "4",
    }.toTable

    proc checkBgChange(
        change: BackgroundChange,
        expected: BackgroundChange
    ): void =
        check:
            change.beat == expected.beat
            change.path == expected.path
            change.updateRate == expected.updateRate
            change.crossFade == expected.crossFade
            change.stretchRewind == expected.stretchRewind
            change.stretchNoLoop == expected.stretchNoLoop
            change.effect == expected.effect
            change.file2 == expected.file2
            change.transition == expected.transition
            change.color1 == expected.color1
            change.color2 == expected.color2

    proc testModifier(
        modifier: Modifier,
        expectedName: string,
        expectedApproachRate: int,
        expectedMagnitude: float = 100,
        expectedPercent: bool = true,
        expectedPlayer = ""
    ): void =

        check:
            modifier.name == expectedName
            modifier.approachRate == expectedApproachRate
            modifier.magnitude == expectedMagnitude
            modifier.isPercent == expectedPercent
            modifier.player == expectedPlayer

    template checkModifier(
        modifier: Modifier,
        expectedName: string,
        expectedApproachRate: int,
        expectedMagnitude: float = 100,
        expectedPercent: bool = true,
        expectedPlayer = ""
    ) =
        checkpoint("Modifier " & $modifier[] & " '" & expectedName & "': " & expectedPlayer & " *" & $expectedApproachRate & " " & $expectedMagnitude & (if expectedPercent: "%" else: ""))
        testModifier(modifier, expectedName, expectedApproachRate, expectedMagnitude, expectedPercent, expectedPlayer)

    func `$`(kind: NoteType): string =
        case kind:
            of NoteType.Note:
                result = "Note"
            of NoteType.Hold:
                result = "Hold"
            of NoteType.Roll:
                result = "Roll"
            of NoteType.Mine:
                result = "Mine"
            of NoteType.Lift:
                result = "Lift"
            of NoteType.Fake:
                result = "Fake"
            else:
                result = "---"

    proc testNote(
        note: Note,
        expectedSnap: int,
        expectedColumn: int,
        expectedKind: NoteType = NoteType.Note
    ): void =
        check:
            note.kind == expectedKind
            note.snap == expectedSnap
            note.column == expectedColumn

    template checkNote(
        note: Note,
        snap: int,
        column: int,
        kind: NoteType = NoteType.Note
    ) =
        checkpoint("Note (" & $kind & ") on Snap " & $snap & ", Column " & $column)
        testNote(note, snap, column, kind)

    proc testHold(
        note: Note,
        snap: int,
        column: int,
        expectedReleaseBeat: int,
        expectedReleaseSnap: int,
        kind: NoteType = NoteType.Hold
    ): void =
        testNote(note, snap, column, kind)
        if kind == NoteType.Hold or kind == NoteType.Roll:
            check:
                note.releaseBeat == expectedReleaseBeat
                note.releaseSnap == expectedReleaseSnap

    template checkHold(
        note: Note,
        snap: int,
        column: int,
        releaseBeat: int,
        releaseSnap: int,
        kind: NoteType = NoteType.Hold
    ) =
        checkpoint("Note (" & $kind & ") on Snap " & $snap & ", Column " & $column & ", Release on " & $releaseBeat & "-" & $releaseSnap)
        testHold(note, snap, column, releaseBeat, releaseSnap, kind)

    test "parse":

        let testFile = """
#TITLE:ゾンビー・サーカス;
#SUBTITLE:客招く誘蛾灯 テントに灯る;
#ARTIST:かめりあ;
#TITLETRANSLIT:No idea;
#SUBTITLETRANSLIT:Idk,I just copied it from Tr.20;
#ARTISTTRANSLIT:Camellia;
#GENRE:Deathmetal;
#CREDIT:PreFiXAUT;
#BANNER:bn-sample.png;
#BACKGROUND:bg-sample.jpg;
#LYRICSPATH:rainbow.lyc;
#CDTITLE:cdtitle-sample.png;
#MUSIC:audio-file.ogg;
#INSTRUMENTTRACKS:guitar=guitar.ogg,
drums=drumdum.mp3;
#SAMPLESTART:23.654;
#SAMPLELENGTH:62.195;
#DISPLAYBPM:120-666;
#SELECTABLE:YES;
#BGCHANGES:0.000=something.jpg=1.000=1=0=1=bloom=otherScript.lua=CrossFade=0.5^0.2^0.9^1.0=0.3^0.2^0.6^0.8
,420.000=ayo.png=2.000=0=1=1=====;
#BGCHANGES2:69.333=image.gif=3.500=1=0=0=invert=label.png;
#BGCHANGES3:420.000=ayo.png=2.000=0=1=1=====,
0.000=something.jpg=1.000=1=0=1=bloom=otherScript.lua=CrossFade=0.5^0.2^0.9^1.0=0.3^0.2^0.6^0.8
,69.333=image.gif=3.500=1=0=0=invert=label.png;
#ANIMATIONS:0.000=something.jpg=1.000=1=0=1=bloom=otherScript.lua=CrossFade=0.5^0.2^0.9^1.0=0.3^0.2^0.6^0.8;
#FGCHANGES:69.333=image.gif=3.500=1=0=0=invert=label.png,
0.000=something.jpg=1.000=1=0=1=bloom=otherScript.lua=CrossFade=0.5^0.2^0.9^1.0=0.3^0.2^0.6^0.8;
#KEYSOUNDS:pf_24_c#+.ogg,ba_op1.ogg,dr_hho.ogg,dr_rs.ogg,dr_bd8.ogg,dr_cs8.ogg,sq_a.ogg,pc_c.ogg,pf_op11.ogg;
#OFFSET:-0.246;
#STOPS:46.250000=0.030000,
46.500000=0.030000,
46.750000=0.030000;
#BPMS:0.000=210.000
,5.000=230.000
,40.333=120.500
,90.000=90.750
;
#TIMESIGNATURES:3.500=8=5,5.100=3=4,8.900=8=10;
#ATTACKS:
    TIME=26.879999:LEN=209715.000000:MODS=*4 500 bumpy,*8 -50 bumpyperiod:
    TIME=28.320000:LEN=5.000000:MODS=*8 no bumpy:
    TIME=0.000000:LEN=209715.000000:MODS=*-1 skew:
    TIME=0.000000:LEN=209715.000000:MODS=*-1 p2 10000 centered:
    TIME=0.000000:LEN=209715.000000:MODS=*-1 p1 no dark;
#DELAYS:65.134=4.262,84.001=43.232
,930.32=12.000;
#TICKCOUNTS:45.23=12,84.999=24;
#NOTES:
    dance-single:
    cool-dood:
    Challenge:
    20:
    0.2,0.3,0.5,0.7,0.9:
0000
0000
0000
0000
,
0000
0000
0000
0000
,
2011
0011
0400
0011
0010
0000
0011
0000
,
0000
3011
0011
M0FF
1011
0311
0000
1011
;
#COMBOS:33.333=3=100,
50.5=10=2,52=2=1;
#SPEEDS:12.000=10=20=1,76.666=7.5=12=0;
#SCROLLS:75.123=6.75;
#FAKES:44.542=61,89.028=13.999;
#LABELS:71.987=hello world
,91.565=goodbye;
"""

        let testChange1 = newBackgroundChange(0.0, "something.jpg", 1.0, true, false, true, "bloom", "otherScript.lua", "CrossFade", [0.5, 0.2, 0.9, 1.0], [0.3, 0.2, 0.6, 0.8])
        let testChange2 = newBackgroundChange(420.0, "ayo.png", 2.0, false, true, true)
        let testChange3 = newBackgroundChange(69.333, "image.gif", 3.500, true, false, false, "invert", "label.png")

        let chart = parseStepMania(testFile)

        check:
            chart.title == "ゾンビー・サーカス"
            chart.subtitle == "客招く誘蛾灯 テントに灯る"
            chart.artist == "かめりあ"
            chart.titleTransliterated == "No idea"
            chart.subtitleTransliterated == "Idk,I just copied it from Tr.20"
            chart.artistTransliterated == "Camellia"
            chart.genre == "Deathmetal"
            chart.credit == "PreFiXAUT"
            chart.banner == "bn-sample.png"
            chart.background == "bg-sample.jpg"
            chart.lyricsPath == "rainbow.lyc"
            chart.cdTitle == "cdtitle-sample.png"
            chart.music == "audio-file.ogg"
            chart.instrumentTracks.len == 2
            chart.instrumentTracks[0].instrument == "guitar"
            chart.instrumentTracks[0].file == "guitar.ogg"
            chart.instrumentTracks[1].instrument == "drums"
            chart.instrumentTracks[1].file == "drumdum.mp3"
            chart.sampleStart == 23.654
            chart.sampleLength == 62.195
            chart.displayBpm == "120-666"
            chart.selectable == true
            chart.bgChanges.len == 2

        checkBgChange(chart.bgChanges[0], testChange1)
        checkBgChange(chart.bgChanges[1], testChange2)
        check chart.bgChanges2.len == 1
        checkBgChange(chart.bgChanges2[0], testChange3)
        check chart.bgChanges3.len == 3
        checkBgChange(chart.bgChanges3[0], testChange2)
        checkBgChange(chart.bgChanges3[1], testChange1)
        checkBgChange(chart.bgChanges3[2], testChange3)
        check chart.animations.len == 1
        checkBgChange(chart.animations[0], testChange1)
        check chart.fgChanges.len == 2
        checkBgChange(chart.fgChanges[0], testChange3)
        checkBgChange(chart.fgChanges[1], testChange1)

        check:
            chart.keySounds == [
                "pf_24_c#+.ogg",
                "ba_op1.ogg",
                "dr_hho.ogg",
                "dr_rs.ogg",
                "dr_bd8.ogg",
                "dr_cs8.ogg",
                "sq_a.ogg",
                "pc_c.ogg",
                "pf_op11.ogg"
            ]
            chart.offset == -0.246
            chart.stops.len == 3
            chart.bpms.len == 4
            chart.bpms[0].beat == 0.0
            chart.bpms[0].bpm == 210.0
            chart.bpms[1].beat == 5.0
            chart.bpms[1].bpm == 230.0
            chart.bpms[2].beat == 40.333
            chart.bpms[2].bpm == 120.5
            chart.bpms[3].beat == 90.0
            chart.bpms[3].bpm == 90.75
            chart.timeSignatures.len == 3
            chart.timeSignatures[0].beat == 3.5
            chart.timeSignatures[0].numerator == 8
            chart.timeSignatures[0].denominator == 5
            chart.timeSignatures[1].beat == 5.1
            chart.timeSignatures[1].numerator == 3
            chart.timeSignatures[1].denominator == 4
            chart.timeSignatures[2].beat == 8.9
            chart.timeSignatures[2].numerator == 8
            chart.timeSignatures[2].denominator == 10

            chart.attacks.len == 5

        check:
            int(chart.attacks[0].time * 1000) == int(26.879 * 1000)
            int(chart.attacks[0].length * 1000) == int(209_715.000 * 1000)
            chart.attacks[0].mods.len == 2

        checkModifier(chart.attacks[0].mods[0], "bumpy", 4, 500.0, false)
        checkModifier(chart.attacks[0].mods[1], "bumpyperiod", 8, -50.0, false)

        check:
            int(chart.attacks[1].time * 1000) == int(28.320 * 1000)
            int(chart.attacks[1].length * 1000) == int(5.000 * 1000)
            chart.attacks[1].mods.len == 1

        checkModifier(chart.attacks[1].mods[0], "bumpy", 8, 0.0)

        check:
            int(chart.attacks[2].time * 1000) == int(0.000 * 1000)
            int(chart.attacks[2].length * 1000) == int(209_715.0000 * 1000)
            chart.attacks[2].mods.len == 1

        checkModifier(chart.attacks[2].mods[0], "skew", -1)

        check:
            int(chart.attacks[3].time * 1000) == int(0.000 * 1000)
            int(chart.attacks[3].length * 1000) == int(209_715.0000 * 1000)
            chart.attacks[3].mods.len == 1

        checkModifier(chart.attacks[3].mods[0], "centered", -1, 10_000.0, false, "p2")

        check:
            int(chart.attacks[4].time * 1000) == int(0.000 * 1000)
            int(chart.attacks[4].length * 1000) == int(209_715.0000 * 1000)
            chart.attacks[4].mods.len == 1

        checkModifier(chart.attacks[4].mods[0], "dark", -1, 0.0, true, "p1")

        check:
            chart.delays.len == 3
            int(chart.delays[0].beat * 1000) == int(65.134 * 1000)
            int(chart.delays[0].duration * 1000) == int(4.262 * 1000)
            int(chart.delays[1].beat * 1000) == int(84.001 * 1000)
            int(chart.delays[1].duration * 1000) == int(43.232 * 1000)
            int(chart.delays[2].beat * 1000) == int(930.32 * 1000)
            int(chart.delays[2].duration * 1000) == int(12.000 * 1000)

            chart.tickCounts.len == 2
            int(chart.tickCounts[0].beat * 1000) == int(45.23 * 1000)
            chart.tickCounts[0].count == 12
            int(chart.tickCounts[1].beat * 1000) == int(84.999 * 1000)
            chart.tickCounts[1].count == 24

            chart.noteData.len == 1

        let diff = chart.noteData[0]
        check:
            diff.chartType == ChartType.DanceSingle
            diff.description == "cool-dood"
            diff.difficulty == Difficulty.Challenge
            diff.difficultyLevel == 20
            diff.radarValues == [0.2, 0.3, 0.5, 0.7, 0.9]

            diff.beats.len == 2
            diff.beats[0].index == 2
            diff.beats[0].snapSize == 8
            diff.beats[0].notes.len == 11

        checkHold(diff.beats[0].notes[0], 0, 0, 3, 1)
        checkNote(diff.beats[0].notes[1], 0, 2)
        checkNote(diff.beats[0].notes[2], 0, 3)
        checkNote(diff.beats[0].notes[3], 1, 2)
        checkNote(diff.beats[0].notes[4], 1, 3)
        checkHold(diff.beats[0].notes[5], 2, 1, 3, 5, NoteType.Roll)
        checkNote(diff.beats[0].notes[6], 3, 2)
        checkNote(diff.beats[0].notes[7], 3, 3)
        checkNote(diff.beats[0].notes[8], 4, 2)
        checkNote(diff.beats[0].notes[9], 6, 2)
        checkNote(diff.beats[0].notes[10], 6, 3)

        check:
            diff.beats[1].index == 3
            diff.beats[1].snapSize == 8
            diff.beats[1].notes.len == 15

        checkNote(diff.beats[1].notes[0], 1, 2)
        checkNote(diff.beats[1].notes[1], 1, 3)
        checkNote(diff.beats[1].notes[2], 2, 2)
        checkNote(diff.beats[1].notes[3], 2, 3)
        checkNote(diff.beats[1].notes[4], 3, 0, NoteType.Mine)
        checkNote(diff.beats[1].notes[5], 3, 2, NoteType.Fake)
        checkNote(diff.beats[1].notes[6], 3, 3, NoteType.Fake)
        checkNote(diff.beats[1].notes[7], 4, 0)
        checkNote(diff.beats[1].notes[8], 4, 2)
        checkNote(diff.beats[1].notes[9], 4, 3)
        checkNote(diff.beats[1].notes[10], 5, 2)
        checkNote(diff.beats[1].notes[11], 5, 3)
        checkNote(diff.beats[1].notes[12], 7, 0)
        checkNote(diff.beats[1].notes[13], 7, 2)
        checkNote(diff.beats[1].notes[14], 7, 3)

        check:
            chart.combos.len == 3
            chart.combos[0].beat == 33.333
            chart.combos[0].hit == 3
            chart.combos[0].miss == 100
            chart.combos[1].beat == 50.5
            chart.combos[1].hit == 10
            chart.combos[1].miss == 2
            chart.combos[2].beat == 52.0
            chart.combos[2].hit == 2
            chart.combos[2].miss == 1

            chart.speeds.len == 2
            chart.speeds[0].beat == 12.000
            chart.speeds[0].ratio == 10.0
            chart.speeds[0].duration == 20.0
            chart.speeds[0].inSeconds == true
            chart.speeds[1].beat == 76.666
            chart.speeds[1].ratio == 7.5
            chart.speeds[1].duration == 12.0
            chart.speeds[1].inSeconds == false

            chart.scrolls.len == 1
            chart.scrolls[0].beat == 75.123
            chart.scrolls[0].factor == 6.75

            chart.fakes.len == 2
            chart.fakes[0].beat == 44.542
            chart.fakes[0].duration == 61.0
            chart.fakes[1].beat == 89.028
            chart.fakes[1].duration == 13.999

            chart.labels.len == 2
            chart.labels[0].beat == 71.987
            chart.labels[0].content == "hello world"
            chart.labels[1].beat == 91.565
            chart.labels[1].content == "goodbye"

    test "strict note in holds and rolls":
        for hKind, hStr in holdNotes.pairs:
            for kind, str in regularNotes.pairs:
                let testFile = fmt"""
#NOTES:
    dance-single:
    :
    Hard:
    10:
    0,0,0,0,0:
{hStr}000
0000
{str}000
0000
0000
0000
3000
0000
;
"""
                var didThrow = false
                try:
                    discard parseStepMania(testFile)
                except InvalidNoteError as e:
                    didThrow = true
                    check:
                        e.beat == 0
                        e.note.kind == kind
                        e.note.snap == 2
                        e.note.column == 0
                check didThrow == true

    test "lenient note in holds and rolls":
        for hKind, hStr in holdNotes.pairs:
            for kind, str in regularNotes.pairs:
                let testFile = fmt"""
#NOTES:
    dance-single:
    :
    Hard:
    10:
    0,0,0,0,0:
{hStr}000
0000
{str}000
0000
0000
0000
3000
0000
;
"""
                var didThrow = false
                try:
                    let chart = parseStepMania(testFile, true)
                    check:
                        chart.noteData[0].beats.len == 1
                        chart.noteData[0].beats[0].notes.len == 1
                    checkHold(chart.noteData[0].beats[0].notes[0], 0, 0, 0, 6, hKind)
                except InvalidNoteError:
                    didThrow = true
                check didThrow == false
