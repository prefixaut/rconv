import std/[macros]

type
    ParseError* = object of CatchableError

    Difficulty* {.pure.} = enum
        Basic       = "basic",
        Advanced    = "advanced",
        Extreme     = "extreme"

const
    debug = true

macro log*(message: string): untyped =
    if debug:
        result = quote do:
            {.cast(noSideEffect).}:
                echo `message`
