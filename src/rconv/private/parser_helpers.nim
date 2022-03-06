import std/[strutils, options]

func parseFloatSafe*(value: string, default: Option[float] = none[float]()): Option[float] =
    try:
        return some[float](parseFloat(value))
    except ValueError:
        if default.isSome:
            return default
        return none[float]()

func parseIntSafe*(value: string, default: Option[int] = none[int]()): Option[int] =
    try:
        return some[int](parseInt(value))
    except ValueError:
        if default.isSome:
            return default
        return none[int]()

func parseBoolSafe*(value: string, default: Option[bool] = none[bool]()): Option[bool] =
    try:
        return some[bool](parseBool(value))
    except ValueError:
        if default.isSome:
            return default
        return none[bool]()

func splitMin*(str: string, sep: string, minCount: int, default: string = ""): seq[string] =
    result = str.split(sep)
    let l = result.len
    for i in l..minCount:
        result.add default
