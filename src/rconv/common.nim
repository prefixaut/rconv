import std/[macros, strformat, strutils]

type
    ParseError* = object of CatchableError

    Difficulty* {.pure.} = enum
        Basic       = "basic",
        Advanced    = "advanced",
        Extreme     = "extreme"

const
    debug = true

func parseDifficulty*(diff: string): Difficulty {.raises: [ParseError, ValueError] .} =
    try:
        return parseEnum[Difficulty](diff.toLower())
    except ValueError:
        raise newException(ParseError, fmt"Could not parse Difficulty '{diff}'!")

macro log*(message: string): untyped =
    if debug:
        result = quote do:
            {.cast(noSideEffect).}:
                echo `message`
