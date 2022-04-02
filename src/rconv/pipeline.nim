import std/[streams, strformat, options, os]

import ./common, mapper
import ./private/utils

# Import different game-modes into own scopes, as they often
# have colliding types
import ./fxf as fxf
import ./malody as malody
import ./memo as memo
import ./step_mania as sm

{.experimental: "codeReordering".}

proc convert*(file: string, fromType: Option[FileType], to: FileType, options: Option[ConvertOptions] = none[ConvertOptions]()): ConvertResult =
    ## Converts the provided file to the requested output-format (`to`).
    ## If the `fromType` is not provided, it'll attempt to detect it from the file via the _`detectFileType` func.
    ## If no `options` are provided, it'll get the default options for the output-type (`to`) via the `getDefaultOptions`_ func.
    ##
    ## Example:
    ## 
    ## ```nim
    ## import std/options
    ## import rconv
    ##
    ## let inputFile = "/example.fxf"
    ## let outDir = "./output"
    ##
    ## # This will use the default Convert-Options. See `getDefaultOptions`_
    ## try:
    ##     let result = convert(inputFile, some(FileType.FXF), FileType.Malody)
    ##     echo $result
    ## except MissingTypeException, MissingConversionException:
    ##     # Handle issues when the convertion from FXF to Malody doesn't exist
    ##     discard
    ## except ParseError:
    ##     # Handle issues when the file couldn't be parsed
    ##     discard
    ## except ConvertException:
    ##     # Handle issues from the convertion from FXF to Malody
    ##     discard
    ## ```

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
        let raw = readFile(file)
        let parsed = memo.parseMemo(raw)

        case to:
        of FileType.FXF:
            var chart = parsed.toFXF
            result = saveChart(chart, actualOptions, some($parsed.difficulty))

        of FileType.Malody:
            let chart = parsed.toMalody
            result = saveChart(chart, actualOptions)

        else:
            raise newException(MissingConversionException, fmt"Could not find a convertion from {fromType} to {to}!")

    of FileType.Malody:
        var raw = readFile(file)
        var parsed = malody.parseMalody(raw, actualOptions.lenient)

        case to:
        of FileType.FXF:
            var chart = parsed.toFXF
            result = saveChart(chart, actualOptions, none(string))

        of FileType.Malody:
            result = saveChart(parsed, actualOptions)

        of FileType.StepMania:
            let chart = parsed.toStepMania
            result = saveChart(chart, actualOptions)

        else:
            raise newException(MissingConversionException, fmt"Could not find a convertion from {fromType} to {to}!")

    of FileType.StepMania:
        let raw = readFile(file)
        let parsed = sm.parseStepMania(raw, actualOptions.lenient)

        case to:
        of FileType.Malody:
            let chart = parsed.toMalody
            result = saveChart(chart, actualOptions)

        of FileType.StepMania:
            result = saveChart(parsed, actualOptions)

        else:
            raise newException(MissingConversionException, fmt"Could not find a convertion from {fromType} to {to}!")

    of FileType.FXF:
        var stream = openFileStream(file)
        var parsed = fxf.parseFXF(stream)

        case to:
        of FileType.FXF:
            result = saveChart(parsed, actualOptions)

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
        outDir = joinPath(outDir, folderName)
    let filePath = joinPath(outDir, options.formatFileName(params))

    if fileExists(filePath) and options.preserve:
        raise newException(PreserveFileException, fmt"Output-File already exists: {filePath}")

    existsOrCreateDirRecursive(outDir)

    if fileExists(filePath) and options.merge:
        # TODO: Merge it the other way, to make the `chart` parameter not editable
        try:
            var readStrm = newFileStream(filePath, fmRead)
            var existing = fxf.parseFXF(readStrm)
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
    chart.write(writeStrm)
    writeStrm.flush
    writeStrm.close

    result = ConvertResult(
        folderName: folderName,
        filePath: filePath
    )

proc saveChart(chart: malody.Chart, options: ConvertOptions): ConvertResult =
    let params = malody.asFormattingParams(chart)

    var outDir = options.output
    if not isAbsolute(outDir):
        outDir = joinPath(getCurrentDir(), outDir)
    var folderName = ""
    if options.songFolders:
        folderName = options.formatFolderName(params)
        outDir = joinPath(outDir, folderName)
    let filePath = joinPath(outDir, options.formatFileName(params))

    if fileExists(filePath) and options.preserve:
        raise newException(PreserveFileException, fmt"Output-File already exists: {filePath}")

    existsOrCreateDirRecursive(outDir)

    var str = chart.write(options.jsonPretty)
    writeFile(filePath, str)

    result = ConvertResult(
        folderName: folderName,
        filePath: filePath
    )

proc saveChart(chart: sm.ChartFile, options: ConvertOptions): ConvertResult =
    let params = sm.asFormattingParams(chart)

    var outDir = options.output
    if not isAbsolute(outDir):
        outDir = joinPath(getCurrentDir(), outDir)
    var folderName = ""
    if options.songFolders:
        folderName = options.formatFolderName(params)
        outDir = joinPath(outDir, folderName)
    let filePath = joinPath(outDir, options.formatFileName(params))

    if fileExists(filePath) and options.preserve:
        raise newException(PreserveFileException, fmt"Output-File already exists: {filePath}")

    existsOrCreateDirRecursive(outDir)

    var str = chart.write()
    writeFile(filePath, str)

    result = ConvertResult(
        folderName: folderName,
        filePath: filePath
    )
