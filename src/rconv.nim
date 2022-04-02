# The library entry file

##[
rconv is a universal library and CLI for parsing and converting rhythm game files.

The goal of this project is to have a reliable and consistent way to parse and convert
various formats.

Each format is placed into it's own module, so you need to import the formats you need.
If you need to import multiple format-modules, due to clashing naming of the types
(A Malody Chart is not the same as a StepMania Chart - go figure),
you may import them into their own namespace:

```nim
import rconv/fxf as fxf # Imported the fxf-format under fxf
import rconv/memo as memo # Imported the memo-format under memo

let fxfFile = "/example1.fxf"
let memoFile = "/example2.memo"

var fxfStream = openFileStream(fxfFile)
let fxfChart = fxf.parseFXF(fxfStream)
fxfStream.close()

let memoFile = memo.parseMemo(readFile(memoFile))
```

Convertion of files can be done in two ways:

- Manually by reading the file and converting the file via the mapping procs
- Use the convert proc which handles the convertion and file saving

Example of manual convertion:

```nim
import rconv
import rconv/malody as malody
import rconv/fxf as fxf

let fxfFile = "/example1.fxf"
let memoFile = "/example2.memo"

var fxfStream = openFileStream(fxfFile)
let fxfChart = fxf.parseFXF(fxfStream)
fxfStream.close()

let malodyChart = fxfChart.toMalody # The 'toMalody' proc is imported via 'rconv' ('rconv/mapper')
writeFile(memoFile, malodyChart.write())
```

Formats
-------

- `FXF <./rconv/fxf.html>`__
- `Malody <./rconv/malody.html>`__
- `Memo <./rconv/memo.html>`__
- `StepMania <./rconv/step_mania.html>`__

]##

import ./rconv/common
import ./rconv/mapper
import ./rconv/pipeline

export common
export mapper
export pipeline
