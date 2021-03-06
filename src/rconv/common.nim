import std/[options, strformat, strutils]

import pkg/regex

type
    FileType* {.pure.} = enum
        ## File types which are supported
        Memo = "memo"
        Memo2 = "memo2"
        Malody = "malody"
        StepMania = "sm"
        StepMania5 = "sm5"
        KickItUp = "ksf"
        FXF = "fxf"

    ConvertOptions* = object
        ## Options for converting one chart-file to another type
        bundle*: bool
        ## All output files should instead be bundles (if the output type supports it).
        songFolders*: bool
        ## If it should create a folder for each song (artist & title).
        jsonPretty*: bool
        ## If the output-type is json based, if it should format it prettyly
        keep*: bool
        ## If it should keep the original meta-data when merging a file
        lenient*: bool
        ## If parsing of the files should be lenient/not strict - Ignores certain syntax errors
        merge*: bool
        ## If the output-type supports multiple charts to be in a single file,
        ## if it should merge existing and new charts together.
        output*: string
        ## The output directory where it should write the files to
        preserve*: bool
        ## If it should preserve any existing output-files.
        ## Doesn't save the convertion at all then.
        resources*: bool
        ## If it should copy over all referenced resources (audio, graphics, etc.)
        ## to the charts output folder.
        normalize*: bool
        ## If it should normalize the output-paths (folder/file).
        folderFormat*: string
        ## The format for chart/folders (if enabled).
        chartFormat*: string
        ## The format for the chart file.

    FormattingParameters* = object
        ## Parameters to format a folder or chart.
        title*: string
        artist*: string
        difficulty*: string
        level*: string
        mode*: string
        extension*: string

    ConvertResult* = object
        ## Result from converting a chart-file
        folderName*: string
        ## The folder-name in which the file has been put into.
        ## It's only the directory name.
        ## For a full-path, use `filePath` instead.
        filePath*: string
        ## Absolute file-path to the file.

    CombinedError* = object of CatchableError
        ## An error which combines/collects multiple error messages into one.
        errors*: seq[ref Exception]
        ## The combined/collected errors.

    ParseError* = object of CatchableError ## \
    ## Error which occurs when parsing of a file failed.

    ConvertException* = object of CatchableError ## \
    ## An error which occurs during conversion.
    ## More detailed information is from extending Exceptions.

    MissingTypeException* = object of ConvertException ## \
    ## Exception which occurs when no input type was provided and/or couldn't be determined automatically.

    InvalidTypeException* = object of ConvertException
        ## Exception which occurs when the converter does not have a convertion available
        ## for the input type.
        file*: string
        ## The file that was attempted to be converted.
        inputType*: FileType
        ## The fileType which has no available convertions.

    MissingConversionException* = object of ConvertException
        ## Exception which occurs when it's not possible to convert from the input type to the
        ## requested output type.
        file: string
        ## The file that was attempted to be converted.
        inputType*: FileType
        ## The fileType from where it attempted to convert from.
        outputType*: FileType
        ## The fileType to where it attmepted to convert to.

    PreserveFileException* = object of ConvertException ## \
        ## Exception which occurs when the options have `preserve` enabled,
        ## and the output-file already exists.

const
    OneMinute* = 60_000 ## \
    ## One minute in milliseconds. Used for various time convertions
    PlaceholderTitle* = "%title%" ## \
    ## Placeholder for the charts song-title
    PlaceholderArtist* = "%artist%" ## \
    ## Placeholder for the charts artist
    PlaceholderDifficulty* = "%difficulty%" ## \
    ## Placeholder for the charts difficulty
    PlaceholderLevel* = "%level%" ## \
    ## Placeholder for the charts difficulty-level
    PlaceholderMode* = "%mode%" ## \
    ## Placeholder for the chart mode
    DefaultFolderFormat* = fmt"{PlaceholderTitle} ({PlaceholderArtist})" ## \
    ## Default format for folders
    DefaultChartFormat* = fmt"{PlaceholderArtist} - {PlaceholderTitle}_{PlaceholderDifficulty}_{PlaceholderLevel}_{PlaceholderMode}" ## \
    ## Default format for charts which have a separate file per difficulty
    DefaultNonDifficultyChartFormat* = fmt"{PlaceholderArtist} - {PlaceholderTitle}" ## \
    ## Default format for charts which have all difficulties in one file
    FormatReplaceRegex = re"([[:punct:][:cntrl:]]+)" ## \
    ## Regex to replace multiple separators and other invalid entities with dashes
    FormatCleanupRegex = re"([[:space:]_]+)|([[:space:][:punct:]])+$|(\([[:space:]_\-\+]*\))|^([[:space:][:punct:]])+" ## \
    ## Regex to remove ending separators and empty brackets

func newConvertOptions*(
    bundle: bool = false,
    songFolders: bool = false,
    jsonPretty: bool = false,
    keep: bool = false,
    merge: bool = false,
    output: string = ".",
    preserve: bool = false,
    resources: bool = false,
    normalize: bool = false,
    folderFormat: string = DefaultFolderFormat,
    chartFormat: string = ""
): ConvertOptions =
    ## Function to create a new `ConvertOptions` instance.

    result = ConvertOptions(
        bundle: bundle,
        songFolders: songFolders,
        jsonPretty: jsonPretty,
        merge: merge,
        output: output,
        resources: resources,
        normalize: normalize,
        folderFormat: folderFormat,
        chartFormat: chartFormat,
    )

func newFormattingParameters*(
    title: string = "untitled",
    artist: string = "unknown",
    difficulty: string = "edit",
    level: string = "",
    mode: string = "",
    extension: string = "txt",
): FormattingParameters =
    ## Function to create a new `FormattingParameters` instance.

    result = FormattingParameters(
        title: title,
        artist: artist,
        difficulty: difficulty,
        level: level,
        mode: mode,
        extension: extension,
    )

proc formatFileName*(this: ConvertOptions, params: FormattingParameters): string =
    ## Formats the `ConvertOptions`' `chartFormat` by replacing the Placeholders
    ## with the provided formatting parameters.

    result = this.chartFormat
        .replace(PlaceholderTitle, params.title)
        .replace(PlaceholderArtist, params.artist)
        .replace(PlaceholderDifficulty, params.difficulty)
        .replace(PlaceholderLevel, params.level)
        .replace(PlaceholderMode, params.mode)
        .replace(FormatReplaceRegex, "-")
        .replace(FormatCleanupRegex, "")
    result &= "." & params.extension

    if this.normalize:
        result = normalize(result)

func formatFolderName*(this: ConvertOptions, params: FormattingParameters): string =
    ## Formats the `ConvertOptions`' `folderFormat` by replacing the Placeholders
    ## with the provided formatting parameters.

    result = this.folderFormat
        .replace(PlaceholderTitle, params.title)
        .replace(PlaceholderArtist, params.artist)

    if this.normalize:
        result = normalize(result)

func detectFileType*(file: string): Option[FileType] =
    ## Attmpts to detect the file-type of the provided file-path.

    result = none(FileType)
    let pos = file.rfind(".")

    if pos > -1:
        let ending = file.substr(pos + 1)
        case ending:
        of "memo":
            result = some(FileType.Memo)
        of "memo2", "txt":
            result = some(FileType.Memo2)
        of "mc":
            result = some(FileType.Malody)
        of "fxfc":
            result = some(FileType.FXF)
        of "sm":
            result = some(FileType.StepMania)
        of "ssc":
            result = some(FileType.StepMania5)
        of "ksf":
            result = some(FileType.KickItUp)

func getFileExtension*(fileType: FileType): string =
    ## Get's the file-extension for the provided file-type

    case fileType:
    of FileType.Memo:
        result = "memo"
    of FileType.Memo2:
        result = "memo2"
    of FileType.Malody:
        result = "mc"
    of FileType.FXF:
        result = "fxf"
    of FileType.StepMania:
        result = "sm"
    of FileType.StepMania5:
        result = "ssc"
    of FileType.KickItUp:
        result = "ksf"

func getDefaultChartFormat*(fileType: FileType): string =
    ## Gets the default chart-format for the provided file-type

    case fileType:
    of FileType.FXF, FileType.StepMania:
        return DefaultNonDifficultyChartFormat
    else:
        return DefaultChartFormat

func getDefaultOptions*(to: FileType): ConvertOptions =
    ## Creates file-type specific default-options.
    ##
    ## See also:
    ## * `getDefaultChartFormat,FileType`_

    let format = getDefaultChartFormat(to)
    result = newConvertOptions(chartFormat = format)
