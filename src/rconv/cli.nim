import std/[options, strutils, strformat]

import pkg/[argparse]

import ./common, pipeline

let cli = newParser:
    help("Usage: rconv [options] <input-files...>")
    flag("-c", "--color", 
        help="Enable print messages to be in color.")
    flag("-d", "--delete-on-finish",
        help="Delete a processed file after handling it.")
    flag("-e", "--delay-errors",
        help="Process files even if a previous file caused an error.")
    flag("-f", "--song-folders",
        help="Enable that each song is getting placed into it's own sub-directory.")
    flag("-j", "--json-pretty",
        help="Output JSON data prettily.")
    flag("-m", "--merge",
        help="Merge all possible charts into existing files.")
    option("-o", "--output", default=some("."),
        help="The output location for the files. If the directory doesn't exist, they will be created. Defaults to current directoy (\".\").")
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
    option("-t", "--to", required=true, choices=(@["fxf", "malody", "memo", "memson"]),
        help="The output type. Must be one of the following: \"fxf\", \"malody\", \"memo\" and \"memson\".")
    flag("-n", "--normalize",
        help="Normalize the output-paths (folder/file).")
    flag("-V", "--verbose",
        help="Print verbose messages on internal operations.")
    option("-x", "--folder-format", default=some(DefaultFolderFormat),
        help="he format for song-folders. You may use the following placeholders: \"%artist%\", \"%title%\".")
    option("-z", "--chart-format",
        help="The format for the output file-name. You may use the following placeholders: \"%artist%\", \"%title%\", \"%difficulty%\", \"%ext%\". Defaults to \"%artist% - %title%.%ext%\" on type \"fxf\", otherwise to \"%artist% - %title%_%difficulty%.%ext%\"")
    arg("files", nargs=(-1),
        help="Input-Files to convert. At least one has to be specified")

try:
    var params = cli.parse(commandLineParams())
    if params.files.len == 0:
        raise newException(ValueError, "No input-files specified!")

    let to = parseEnum[FileType](params.to.toLower)
    if params.chart_format.isEmptyOrWhitespace:
        case to:
        of FileType.FXF:
            params.chart_format = DefaultNonDifficultyChartFormat
        else:
            params.chart_format = DefaultChartFormat

    let convOptions = ConvertOptions(
        songFolders: params.song_folders,
        jsonpretty: params.json_pretty,
        merge: params.merge,
        output: params.output,
        preserve: params.preserve,
        resources: params.resources,
        normalize: params.normalize,
        folderFormat: params.folder_format,
        chartFormat: params.chart_format,
    )

    for path in params.files:
        try:
            echo $convert(path, to, some(convOptions))
        except:
            raise newException(ConvertException, fmt"Failed to convert file {path}! Error: {getCurrentExceptionMsg()}", getCurrentException())
except ShortCircuit as e:
    if e.flag == "argparse_help":
        echo cli.help
        quit(1)
except:
    stderr.writeLine getCurrentExceptionMsg()
    quit(1)
