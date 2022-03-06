import std/[unittest]

import rconv/step_mania

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
#BGCHANGES:;
#BGCHANGES2:;
#BGCHANGES3:;
#ANIMATIONS:;
#FGCHANGES:;
#KEYSOUNDS:;
#OFFSET:-0.246;
#STOPS:;
#BPMS:0.000=210.000
,5.000=230.000
,40.333=120.500
,90.000=90.750
;
#TIMESIGNATURES:;
#ATTACKS:;
#DELAYS:;
#TICKCOUNTS:;
#NOTES:;
#NOTES2:;
#COMBOS:;
#SPEEDS:;
#SCROLLS:;
#FAKES:;
#LABELS:;
"""

    test "parse":
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
