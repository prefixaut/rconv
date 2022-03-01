import std/[macros, options, strformat, strutils]

type
    FileType* {.pure.} = enum
        ## File types which are supported
        Memo = "memo",
        Memo2 = "memo2",
        Malody = "malody",
        StepMania = "stepmania",
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
        ## An error which combines multiple error messages into one.
        errors*: seq[ref Exception]

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
    PlaceholderExtension* = "%ext%" ## \
    ## Placeholder for the file extension
    DefaultFolderFormat* = fmt"{PlaceholderTitle} ({PlaceholderArtist})" ## \
    ## Default format for folders
    DefaultChartFormat* = fmt"{PlaceholderArtist} - {PlaceholderTitle}_{PlaceholderDifficulty}.{PlaceholderExtension}" ## \
    ## Default format for charts which have a separate file per difficulty
    DefaultNonDifficultyChartFormat* = fmt"{PlaceholderArtist} - {PlaceholderTitle}.{PlaceholderExtension}" ## \
    ## Default format for charts which have all difficulties in one file
    debug = true

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
    extension: string = "txt",
): FormattingParameters =
    ## Function to create a new `FormattingParameters` instance.

    result = FormattingParameters(
        title: title,
        artist: artist,
        difficulty: difficulty,
        extension: extension,
    )

func formatFileName*(this: ConvertOptions, params: FormattingParameters): string =
    ## Formats the `ConvertOptions`' `chartFormat` by replacing the Placeholders
    ## with the provided formatting parameters.

    result = this.chartFormat
        .replaceWord(PlaceholderTitle, params.title)
        .replaceWord(PlaceholderArtist, params.artist)
        .replaceWord(PlaceholderDifficulty, params.difficulty)
        .replaceWord(PlaceholderExtension, params.extension)

    if this.normalize:
        result = normalize(result)

func formatFolderName*(this: ConvertOptions, params: FormattingParameters): string =
    ## Formats the `ConvertOptions`' `folderFormat` by replacing the Placeholders
    ## with the provided formatting parameters.

    result = this.folderFormat
        .replaceWord(PlaceholderTitle, params.title)
        .replaceWord(PlaceholderArtist, params.artist)

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
        result = "fxfc"
    of FileType.StepMania:
        result = "sm"

func getDefaultChartFormat*(fileType: FileType): string =
    ## Gets the default chart-format for the provided file-type

    case fileType:
    of FileType.FXF:
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

macro log*(message: string): untyped =
    ## Internal logging function which will be removed soon

    if debug:
        result = quote do:
            {.cast(noSideEffect).}:
                echo `message`
