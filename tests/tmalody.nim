import std/[unittest]

import rconv/[mapper, malody]

suite "malody":

    test "parse":
        let testFile = """
{
    "meta": {
        "$ver": 0,
        "creator": "cool dude",
        "background": "bg.jpg",
        "version": "Hard lvl5",
        "preview": 6128,
        "id": 108082,
        "mode": 0,
        "time": 1648378649296,
        "song": {
            "title": "hello world",
            "artist": "foo bar",
            "invalid-key": 1234
        },
        "mode_ext": {
            "column": 4,
            "bar_begin": 3
        }
    },
    "time": [
        {
            "beat": [0, 0, 4],
            "bpm": 190.0
        },
        {
            "beat": [3, 3, 12],
            "bpm": 210.0
        }
    ],
    "note": [
        {
            "beat": [0, 0, 4],
            "column": 1
        },
        {
            "beat": [0, 0, 4],
            "column": 2
        },
        {
            "beat": [0, 1, 4],
            "column": 3
        },
        {
            "beat": [0, 2, 4],
            "column": 0
        },
        {
            "beat": [1, 3, 16],
            "column": 1
        },
        {
            "beat": [1, 5, 16],
            "column": 2
        },
        {
            "beat": [1, 12, 16],
            "column": 0
        },
        {
            "beat": [2, 1, 24],
            "column": 2
        },
        {
            "beat": [2, 1, 24],
            "column": 3
        },
        {
            "beat": [2, 9, 24],
            "column": 0
        },
        {
            "beat": [2, 9, 24],
            "column": 1
        },
        {
            "beat": [2, 14, 24],
            "column": 1
        },
        {
            "beat": [2, 19, 24],
            "column": 1
        },
        {
            "beat": [2, 23, 24],
            "column": 2
        },
        {
            "beat": [3, 4, 12],
            "column": 0
        },
        {
            "beat": [3, 7, 12],
            "column": 2
        },
        {
            "beat": [3, 7, 12],
            "column": 3
        },
        {
            "beat": [3, 9, 12],
            "column": 1
        },
        {
            "beat": [3, 10, 12],
            "column": 0
        }
    ],
    "extra": {
        "test": {
            "divide": 4,
            "speed": 100,
            "save": 0,
            "lock": 0,
            "edit_mode": 0
        }
    }
}
"""
        let chart = parseMalody(testFile)

        check:
            chart.meta.creator == "cool dude"
