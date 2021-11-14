import std/[macros, options, strformat, strutils]

type
    Difficulty* {.pure.} = enum
        Basic       = "basic",
        Advanced    = "advanced",
        Extreme     = "extreme"

    FileType* {.pure.} = enum
        ## File types which are supported
        Memo = "memo",
        Memo2 = "memo2",
        Malody = "malody",
        StepMania = "stepmania",
        FXF = "fxf"

    ConvertOptions* = object
        ## Options for converting one chart-file to another type
        songFolders*: bool
        ## If it should create a folder for each song (artist & title).
        jsonPretty*: bool
        ## If the output-type is json based, if it should format it prettyly
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

    ParseError* = object of CatchableError
    ## Error which occurs when parsing of a file failed.

    ConvertException* = object of CatchableError
    ## An error which occurs during conversion.
    ## More detailed information is from extending Exceptions.

    MissingTypeException* = object of ConvertException
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

    PreserveFileException* = object of ConvertException
        ## Exception which occurs when the options have `preserve` enabled,
        ## and the output-file already exists.

const
    PlaceholderTitle* = "%title%"
    ## Placeholder for the charts song-title
    PlaceholderArtist* = "%artist%"
    ## Placeholder for the charts artist
    PlaceholderDifficulty* = "%difficulty%"
    ## Placeholder for the charts difficulty
    PlaceholderExtension* = "%ext%"
    ## Placeholder for the file extension
    debug = true

func parseDifficulty*(diff: string): Difficulty {.raises: [ParseError, ValueError] .} =
    try:
        return parseEnum[Difficulty](diff.toLower())
    except ValueError:
        raise newException(ParseError, fmt"Could not parse Difficulty '{diff}'!")

func formatFileName*(this: ConvertOptions, params: FormattingParameters): string =
    ## Formats the ConvertOptions' `chartFormat` by replacing the Placeholders
    ## with the provided formatting parameters.
    result = this.chartFormat
        .replaceWord(PlaceholderTitle, params.title)
        .replaceWord(PlaceholderArtist, params.artist)
        .replaceWord(PlaceholderDifficulty, params.difficulty)
        .replaceWord(PlaceholderExtension, params.extension)

func formatFolderName*(this: ConvertOptions, params: FormattingParameters): string =
    ## Formats the ConvertOptions' `folderFormat` by replacing the Placeholders
    ## with the provided formatting parameters.
    result = this.folderFormat
        .replaceWord(PlaceholderTitle, params.title)
        .replaceWord(PlaceholderArtist, params.artist)

func detectFileType*(file: string): Option[FileType] =
    ## Attmpts to detect the file-type of the provided file-path.
    result = none(FileType)

    let pos = file.rfind(".")
    if pos > -1:
        let ending = file.substr(pos)
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

macro log*(message: string): untyped =
    if debug:
        result = quote do:
            {.cast(noSideEffect).}:
                echo `message`
