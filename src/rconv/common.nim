import std/[macros]

type
    ParseError* = object of CatchableError

const
    debug = true

macro log*(message: string): untyped =
    if debug:
        result = quote do:
            {.cast(noSideEffect).}:
                echo `message`
