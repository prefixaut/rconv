import std/[enumutils, strutils, options]

import ./private/[parser_helpers, imfile_helper]

type
    NoteType* {.pure.} = enum
        ## The type of notes that can be present in a SM file
        Empty = "0"
        ## No note
        Note = "1"
        ## Regular Note
        Hold = "4"
        ## Hold Note
        Mine = "M"
        ## A single Mine
        Lift = "L"
        ## Hold but with a timed release
        Fake = "F"
        ## Notes which can't be hit

    Difficulty* {.pure.} = enum
        Beginner = "beginner"
        Easy = "easy"
        Freestyle = "freestyle"
        Hard = "hard"
        Nightmare = "nightmare"
        Crazy = "crazy"
        CrazyPlus = "crazy+"
        Wild = "wild"
        Another = "another"

    ChartType* {.pure.} = enum
        HalfDouble = "halfdouble"
        Double = "double"
        Freestyle = "freestyle"
        NM = "nm"
        Single = "_1"
        Couple = "_2"

    Player* {.pure.} = enum
        Single = "single"
        Double = "double"

    ChartFile* = ref object =
        title*: string
        songName*: string
        artist*: string
        difficulty*: Difficulty
        tickCount*: int
        bpm*: float
        bpm2*: float
        bpm3*: float
        bunki*: int
        bunki2*: int
        difficultyLevel*: int
        startTime*: float
        startTime2*: float
        startTime3*: float
        player*: Player
        intro*: int
        titleFile*: string
        discFile*: string
        songFile*: string
