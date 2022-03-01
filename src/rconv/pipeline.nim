import std/[json, jsonutils, tables, streams, strformat, options, os]

import ./common, mapper

# Import different game-modes into own scopes, as they often
# have colliding types
import ./fxf as fxf
import ./malody as malody
import ./memo as memo
import ./memson as memson

include ./private/json_hooks

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
            var chart = parsed.toFXF
            result = saveChart(chart, actualOptions, some($parsed.difficulty))
        of FileType.Malody:
            let raw = readFile(file)
            let parsed = memo.parseMemoToMemson(raw)
            var chart = parsed.toMalody
            result = saveChart(chart, actualOptions)
        else:
            raise newException(MissingConversionException, fmt"Could not find a convertion from {fromType} to {to}!")

    of FileType.Malody:
        case to:
        of FileType.FXF:
            var raw = parseJson(readFile(file))
            var mc = raw.toMalodyChart()
            var chart: fxf.ChartFile = mc.toFXF()
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
            var readStrm = newFileStream(filePath, fmRead)
            var existing = readStrm.readFXFChartFile
            readStrm.close

            if options.keep:
                chart.title = existing.title
                chart.artist = existing.artist
                chart.audio = existing.audio
                chart.jacket = existing.jacket
                # TODO: Do offset and bpmChange as well?

            if existing.charts.basic != nil and chart.charts.basic == nil:
                chart.charts.basic = existing.charts.basic
            if existing.charts.advanced != nil and chart.charts.advanced == nil:
                chart.charts.advanced = existing.charts.advanced
            if existing.charts.extreme != nil and chart.charts.extreme == nil:
                chart.charts.extreme = existing.charts.extreme

        except:
            raise newException(ConvertException, fmt"Error while merging existing file {filePath}", getCurrentException())

    var writeStrm = newFileStream(filePath, fmWrite)
    chart.writeToStream(writeStrm)
    writeStrm.flush
    writeStrm.close

    result = ConvertResult(
        folderName: folderName,
        filePath: filePath
    )

proc saveChart(chart: var malody.Chart, options: ConvertOptions): ConvertResult =

    let params = malody.asFormattingParams(chart)

    var outDir = options.output
    if not isAbsolute(outDir):
        outDir = joinPath(getCurrentDir(), outDir)
    var folderName = ""
    if options.songFolders:
        folderName = options.formatFolderName(params)
        outDir &= DirSep & folderName
    let filePath = joinPath(outDir, options.formatFileName(params))

    if fileExists(filePath) and options.preserve:
        # TODO: Logging?
        raise newException(PreserveFileException, fmt"Output-File already exists: {filePath}")

    discard existsOrCreateDir(outDir)

    var str = ""
    if options.jsonPretty:
        str = toJsonHook(chart).pretty
    else:
        toUgly(str, toJson(chart))
    writeFile(filePath, str)

    result = ConvertResult(
        folderName: folderName,
        filePath: filePath
    )
