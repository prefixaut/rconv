import std/[strformat, unittest]

import rconv/step_mania
import rconv/private/test_utils

suite "step-mania":
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
#ATTACKS:TIME=1.618:END=3.166:MODS=*32 Invert, *32 No Flip
:TIME=2.004:END=3.166:MODS=*32 No Invert, *32 No Flip
:TIME=2.392:LEN=0.1:MODS=*64 30% Mini
:TIME=2.489:LEN=0.1:MODS=*64 60% Mini;
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
#NOTES2:;
#COMBOS:;
#SPEEDS:;
#SCROLLS:;
#FAKES:;
#LABELS:;
"""

    let testChange1 = newBackgroundChange(0.0, "something.jpg", 1.0, true, false, true, "bloom", "otherScript.lua", "CrossFade", [0.5, 0.2, 0.9, 1.0], [0.3, 0.2, 0.6, 0.8])
    let testChange2 = newBackgroundChange(420.0, "ayo.png", 2.0, false, true, true)
    let testChange3 = newBackgroundChange(69.333, "image.gif", 3.500, true, false, false, "invert", "label.png")

    test "parse":
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
                of NoteType.Keysound:
                    result = "KeyCound"
                of NoteType.Hidden:
                    result = "Hidden"
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
            if kind == NoteType.Hold:
                check:
                    note.holdEndBeat == expectedReleaseBeat
                    note.holdEndSnap == expectedReleaseSnap
            elif kind == NoteType.Roll:
                check:
                    note.rollEndBeat == expectedReleaseBeat
                    note.rollEndSnap == expectedReleaseSnap

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

            chart.attacks.len == 4

        check:
            int(chart.attacks[0].time * 1000) == int(1.618 * 1000)
            int(chart.attacks[0].length * 1000) == int(1.548 * 1000)
        check chart.attacks[0].mods == @["*32 Invert", "*32 No Flip"]
        check:
            int(chart.attacks[1].time * 1000) == int(2.004 * 1000)
            int(chart.attacks[1].length * 1000) == int(1.162 * 1000)
        check chart.attacks[1].mods == @["*32 No Invert", "*32 No Flip"]
        check:
            int(chart.attacks[2].time * 1000) == int(2.392 * 1000)
            int(chart.attacks[2].length * 1000) == int(0.1 * 1000)
        check chart.attacks[2].mods == @["*64 30% Mini"]
        check:
            int(chart.attacks[3].time * 1000) == int(2.489 * 1000)
            int(chart.attacks[3].length * 1000) == int(0.1 * 1000)
        check chart.attacks[3].mods == @["*64 60% Mini"]

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

            chart.charts.len == 1

        let diff = chart.charts[0]
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
