import std/unittest

import ../malody as malody

template testMalodyIndexNote*(note: malody.TimedElement, beatToTest: malody.Beat, indexToTest: int): untyped =
    check:
        note.kind == malody.ElementType.IndexNote
        note.hold == malody.HoldType.None
        note.beat == beatToTest
        note.index == indexToTest

template testMalodyIndexHold*(note: malody.TimedElement, beatToTest: malody.Beat, indexToTest: int, endBeatToTest: malody.Beat, endIndexToTest: int): untyped =
    check:
        note.kind == malody.ElementType.IndexNote
        note.hold == malody.HoldType.IndexHold
        note.beat == beatToTest
        note.index == indexToTest
        note.indexEnd == endIndexToTest
        note.indexEndBeat == endBeatToTest

template checkFloats*(val1: float, val2: float, ratio: float): bool =
    check:
        int(val1 * ratio) == int(val2 * ratio)

template checkFloats*(val1: float, val2: float, ratio: int): bool =
    checkFloats(val1, val2, float(ratio))
