import std/[options, strutils, strformat, os]

import pkg/[argparse, glob]

import ./common, pipeline
import ./malody as malody

let cli = newParser:
    help("rconv v0.1.0")

    flag("-b", "--bundle",
        help="All output files should instead be bundles (if the output type supports it).")
    flag("-c", "--color",
        help="Enable print messages to be in color.")
    flag("-C", "--clean",
        help="If it should clean (delete all contents) of the output folder. Disabled if 'preserve' is enabled.")
    flag("-d", "--delete-on-finish",
        help="Delete a processed file after handling it.")
    flag("-e", "--delay-errors",
        help="Process files even if a previous file caused an error.")
    flag("-f", "--song-folders",
        help="Enable that each song is getting placed into it's own sub-directory.")
    flag("-j", "--json-pretty",
        help="Output JSON data prettily.")
    flag("-k", "--keep",
        help="If it should keep the original meta data when merging a file.")
    flag("-l", "--lenient",
        help="If parsing of the files should be lenient/not strict - Ignores certain syntax errors.")
    flag("-m", "--merge",
        help="Merge all possible charts into existing files.")
    option("-o", "--output", default=some("."),
        help="The output location for the files. If the directory doesn't exist, they will be created.")
    flag("-p", "--preserve",
        help="Preserve the original output file (don't override it) if it already exists.")
    flag("-P", "--progress",
        help="Display the current progress.")
    flag("-q", "--quiet",
        help="Skip all stdout/stderr messages.")
    flag("-r", "--resources",
        help="Copy all neccessary resources (Sound-File, Jacket) to the output directory. Should only be used in comination with the \"song-folders\" option.")
    flag("-s", "--stats",
        help="Show stats on the end of the operation.")
    option("-t", "--to", required=true, choices=(@["fxf", "malody", "memo", "sm"]),
        help="The output type.")
    flag("-n", "--normalize",
        help="Normalize the output-paths (folder/file).")
    flag("-V", "--verbose",
        help="Print verbose messages on internal operations.")
    option("-x", "--folder-format", default=some(DefaultFolderFormat),
        help=fmt"The format for song-folders. You may use the following placeholders: '{PlaceholderArtist}', and '{PlaceholderTitle}'.")
    option("-z", "--chart-format",
        help=fmt"The format for the output file-name. You may use the following placeholders: '{PlaceholderArtist}', '{PlaceholderTitle}', '{PlaceholderDifficulty}', '{PlaceholderLevel}', and '{PlaceholderMode}''." &
        fmt"Defaults to a reasonable Format depending on the output format.")
    arg("files", nargs=(-1),
        help="Input-Files to convert. At least one has to be specified")

try:
    var params = cli.parse(commandLineParams())
    if params == nil:
        raise newException(ValueError, "CLI is null!")

    if params.files.len == 0:
        raise newException(ValueError, "No input-files specified!")

    let to = try:
        parseEnum[FileType](params.to.toLower)
    except ValueError:
        raise newException(ValueError, fmt"Specified invalid output type '{params.to}'!")

    if params.chart_format.isEmptyOrWhitespace:
        params.chart_format = getDefaultChartFormat(to)
    if not isAbsolute(params.output):
        params.output = joinPath(getCurrentDir(), params.output)

    let convOptions = newConvertOptions(
        bundle = params.bundle,
        songFolders = params.song_folders,
        jsonPretty = params.json_pretty,
        keep = params.keep,
        merge = params.merge,
        output = params.output,
        preserve = params.preserve,
        resources = params.resources,
        normalize = params.normalize,
        folderFormat = params.folder_format,
        chartFormat = params.chart_format,
    )

    # Delete all entries of the output folder if requested
    if dirExists(params.output) and params.clean and not params.preserve:
        for entry in walkDir(params.output):
            if entry.kind == pcDir or entry.kind == pcLinkToDir:
                removeDir(entry.path)
            else:
                removeFile(entry.path)

    var errors = newSeq[ref Exception]()

    for path in params.files.mitems:
        # Fix windows paths, as glob doesn't work with these,
        # as it assumes the backslash is for escaping.
        when defined(windows):
            path = path.multiReplace(("\\", "/"))

        for filePath in walkGlob(path):
            try:
                discard convert(filePath, none(FileType), to, some(convOptions))
            except malody.InvalidModeException, InvalidTypeException, MissingTypeException, MissingConversionException:
                discard
            except:
                let e = newException(ConvertException, fmt"Failed to convert file '{filePath}'! Error: {getCurrentExceptionMsg()}", getCurrentException())
                if params.delay_errors:
                    errors.add e
                else:
                    raise e

    if errors.len > 0:
        var msg = "Multiple errors occured!"
        for e in errors:
            msg &= "\n" & e.msg
        var err = newException(CombinedError, msg)
        err.errors = errors
        raise err

except ShortCircuit, UsageError:
    echo cli.help
    quit(1)
except:
    echo repr(getCurrentException())
    stderr.writeLine getCurrentExceptionMsg()
    quit(1)
