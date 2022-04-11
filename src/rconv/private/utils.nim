##[
    Module which contains general use utility procs.
]##

import std/[strutils, sequtils, options, os]

import pkg/bignum

func parseRat*(value: string): Rat =
    result = newRat(value)

func parseRatSafe*(value: string, default: Option[Rat] = none[Rat]()): Option[Rat] = 
    try:
        return some[Rat](parseRat(value))
    except:
        return default

func parseFloatSafe*(value: string, default: Option[float] = none[float]()): Option[float] =
    try:
        return some[float](parseFloat(value))
    except ValueError:
        return default

func parseIntSafe*(value: string, default: Option[int] = none[int]()): Option[int] =
    try:
        return some[int](parseInt(value))
    except ValueError:
        return default

func parseBoolSafe*(value: string, default: Option[bool] = none[bool]()): Option[bool] =
    try:
        return some[bool](parseBool(value))
    except ValueError:
        return default

func splitMin*(str: string, sep: string, minCount: int, default: string = ""): seq[string] =
    result = str.split(sep)
    let l = result.len
    for i in l..minCount:
        result.add default

func stripSplit*(str: string, sep: string, maxSplit: int = -1): seq[string] =
    result = str.split(sep, maxSplit).mapIt(it.strip)

func stripSplitMin*(str: string, sep: string, minCount: int, default: string = ""): seq[string] =
    result = str.splitMin(sep, minCount, default).mapIt(it.strip)

func last*[T](collection: seq[T]): T =
    result = collection[collection.len - 1]

func unshift*[T](collection: var seq[T]): T =
    result = collection[0]
    collection.delete(0)

func find*[T](collection: seq[T], fn: proc (element: T): bool, start: int = 0): int =
    result = -1
    for i in start..<collection.len:
        if fn(collection[i]):
            return i

proc existsOrCreateDirRecursive*(path: string): void =
    ## Custom _'existsOrCreateDir' proc, as the one from OS/STD doesn't do it recursively (for whatever reason)
    if dirExists(path):
        return
    createDir(path)
