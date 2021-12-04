import std/[json, jsonutils, tables, strformat, options, os]

import ./common

# Import different game-modes into own scopes, as they often
# have colliding types
import ./fxf as fxf
import ./malody as malody
import ./memo as memo
import ./memson as memson
import ./private/json_hooks

{.experimental: "codeReordering".}

proc convert*(file: string, fromType: Option[FileType], to: FileType, options: Option[ConvertOptions]): ConvertResult =
    ## Converts the provided file to the requested output-format (`to`).
    ## If the `fromType` is not provided, it'll attempt to detect it from the file via the _`detectFileType` func.
    ## If no `options` are provided, it'll get the default options for the output-type (`to`) via the _`getDefaultOptions` func.

    var actualFrom: FileType
    var actualOptions: ConvertOptions

    if fromType.isSome:
        actualFrom = fromType.get
    else:
        let tmp = detectFileType(file)
        if tmp.isSome:
            actualFrom = tmp.get
        else:
            raise newException(MissingTypeException, fmt"Could not detect file-file from file {file}!")
    
    if options.isSome:
        actualOptions = options.get
    else:
        actualOptions = getDefaultOptions(to)

    case actualFrom:
    of FileType.Memo:
        case to:
        of FileType.FXF:
            let raw = readFile(file)
            let parsed = memo.parseMemoToMemson(raw)
            var chart: fxf.ChartFile = parsed.toFXF
            result = saveChart(chart, actualOptions, some($parsed.difficulty))
        else:
            raise newException(MissingConversionException, fmt"Could not find a convertion from {fromType} to {to}!")

    of FileType.Malody:
        case to:
        of FileType.FXF:
            let raw = parseJson(readFile(file))
            var mc = malody.Chart()
            mc.fromJson(raw, Joptions(allowMissingKeys: true, allowExtraKeys: true))
            var chart: fxf.ChartFile = mc.toFXF
            result = saveChart(chart, actualOptions, none(string))
        else:
            raise newException(MissingConversionException, fmt"Could not find a convertion from {fromType} to {to}!")

    else:
        raise newException(InvalidTypeException, fmt"Could not find a converter for input-type {fromType}")

proc saveChart(chart: var fxf.ChartFile, options: ConvertOptions, diff: Option[string] = none(string)): ConvertResult =
    ## Saves the FXF-Chart to a file.
    ## The file-name and output directory are determined via the provided `options`.

    var params = fxf.asFormattingParams(chart)

    if diff.isSome:
        params.difficulty = $diff.get
    else:
        params.difficulty = ""

    var outDir = options.output
    if not isAbsolute(outDir):
        outDir = joinPath(getCurrentDir(), outDir)
    var folderName = ""
    if options.songFolders:
        folderName = options.formatFolderName(params)
        outDir &= folderName
    let filePath = joinPath(outDir, options.formatFileName(params))

    if fileExists(filePath) and options.preserve:
        # TODO: Logging?
        raise newException(PreserveFileException, fmt"Output-File already exists: {filePath}")

    discard existsOrCreateDir(outDir)

    if fileExists(filePath) and options.merge:
        try:
            var raw = parseJson(readFile(filePath))
            var existing = fxf.ChartFile()
            existing.fromJson(raw)

            for d, c in existing.charts.pairs:
                if not chart.charts.hasKey(d):
                    chart.charts[d] = c
        except:
            raise newException(ConvertException, fmt"Error while merging existing file {filePath}", getCurrentException())

    if options.jsonPretty:
        # TODO: Find solution, or this: https://github.com/treeform/jsony/issues/3
        writeFile(filePath, pretty(toJson(chart), 4))
    else:
        writeFile(filePath, $toJson(chart))

    result = ConvertResult(
        folderName: folderName,
        filePath: filePath
    )
