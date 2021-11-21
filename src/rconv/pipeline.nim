import std/[json, jsonutils, tables, strformat, options, os]

import ./converters/[malody_to_fxf, memson_to_fxf]
import ./common

# Import different game-modes into own scopes, as they often
# have colliding types
from ./fxf import toJsonHook
import ./malody as malody
import ./memo as memo
import ./memson as memson

{.experimental: "codeReordering".}

proc convert*(file: string, fromType: Option[FileType], to: FileType, options: Option[ConvertOptions]): ConvertResult =
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
            let parsed = memo.parseMemoToMemson(readFile(file))
            var chart: fxf.ChartFile = convertMemsonToFXF(parsed)
            result = saveChart(chart, actualOptions, some(parsed.difficulty))
        else:
            raise newException(MissingConversionException, fmt"Could not find a convertion from {fromType} to {to}!")
    of FileType.Malody:
        case to:
        of FileType.FXF:
            let parsed = jsonTo(parseJson(readFile(file)), malody.Chart)
            var chart: fxf.ChartFile = convertMalodyToFXF(parsed)
            result = saveChart(chart, actualOptions, none(Difficulty))
        else:
            raise newException(MissingConversionException, fmt"Could not find a convertion from {fromType} to {to}!")
    else:
        raise newException(InvalidTypeException, fmt"Could not find a converter for input-type {fromType}")

proc saveChart(chart: var fxf.ChartFile, options: ConvertOptions, diff: Option[Difficulty] = none(Difficulty)): ConvertResult =
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
            let rawOriginal = readFile(filePath)
            var parsedOriginal = parseJson(rawOriginal).jsonTo(fxf.ChartFile)
            for d, c in parsedOriginal.charts.pairs:
                if not chart.charts.hasKey(d):
                    chart.charts[d] = c
        except:
            raise newException(ConvertException, fmt"Error while merging existing file {filePath}", getCurrentException())

    if options.jsonPretty:
        writeFile(filePath, pretty(toJson(chart), 4))
    else:
        writeFile(filePath, $toJson(chart))

    result = ConvertResult(
        folderName: folderName,
        filePath: filePath
    )
