# rconv

rconv is a library and command-line program to convert between various rhythm game formats.

- [rconv](#rconv)
  - [Installation](#installation)
    - [Installation as CLI](#installation-as-cli)
    - [Installtion as Library](#installtion-as-library)
  - [Building](#building)
  - [Documentation](#documentation)
  - [Usage](#usage)
    - [Usage of CLI](#usage-of-cli)
    - [Usage of Library](#usage-of-library)
  - [Supported Formats](#supported-formats)
    - [Parsing](#parsing)
    - [Convertion](#convertion)
## Installation

### Installation as CLI

See the [releases](https://github.com/prefixaut/rconv/releases) for pre-build executables of your system.

If you want to build it yourself, see the [Building](#building) section for further information.

### Installtion as Library

Currently not available as nimble package just yet, as it's still in an unstable phase.

If you still want to use it as library, you can do so as a Git Submodule and import the [entry](./src/entry.nim)-file.

## Building

This project can be built with the regular [`nim` compiler](https://nim-lang.org/) ([Nim CLI Documentation](https://nim-lang.org/docs/nimc.html)).
Additionally, the following convenience tasks are defined in the [`config.nims`](config.nims) file:

* **cli**: Builds the project as a CLI application.
* **lib**: Builds the project as a regular library.
* **docs**: Builds the project's documentation.

These may then be executed like this:

```sh
$ nim --release cli
```

## Documentation

For full information of all functions, types, etc.,
please refer to the [documentation](https://prefixaut.github.io/rconv/theindex.html) from this repositiory.

## Usage

### Usage of CLI

The CLI is rather straight forward and may be used like this:

```sh
$ rconv [options] <--to=output-type> <input-files>
```

The CLI requires an output-type (`-t`/`--to`), and the file-paths to the charts you want to convert.

```
Usage:
   [options] [files ...]

Arguments:
  [files ...]      Input-Files to convert. At least one has to be specified

Options:
  -h, --help
  -b, --bundle               All output files should instead be bundles (if the output type supports it).
  -c, --color                Enable print messages to be in color.
  -C, --clean                If it should clean (delete all contents) of the output folder. Disabled if 'preserve' is enabled.
  -d, --delete-on-finish     Delete a processed file after handling it.
  -e, --delay-errors         Process files even if a previous file caused an error.
  -f, --song-folders         Enable that each song is getting placed into it's own sub-directory.
  -j, --json-pretty          Output JSON data prettily.
  -k, --keep                 If it should keep the original meta data when merging a file.
  -m, --merge                Merge all possible charts into existing files.
  -o, --output=OUTPUT        The output location for the files. If the directory doesn't exist, they will be created. (default: .)
  -p, --preserve             Preserve the original output file (don't override it) if it already exists.
  -P, --progress             Display the current progress.
  -q, --quiet                Skip all stdout/stderr messages.
  -r, --resources            Copy all neccessary resources (Sound-File, Jacket) to the output directory. Should only be used in comination with the "song-folders" option.
  -s, --stats                Show stats on the end of the operation.
  -t, --to=TO                The output type. Possible values: [fxf, malody, memo]
  -n, --normalize            Normalize the output-paths (folder/file).
  -V, --verbose              Print verbose messages on internal operations.
  -x, --folder-format=FOLDER_FORMAT
                             The format for song-folders. You may use the following placeholders: '%artist%', '%title%'. (default: %title% (%artist%))
  -z, --chart-format=CHART_FORMAT
                             The format for the output file-name. You may use the following placeholders: '%artist%', '%title%', '%difficulty%', and '%ext%'.Defaults to '%artist% - %title%.%ext%' on type 'fxf', otherwise to '%artist% - %title%_%difficulty%.%ext%'
```

Example:

```sh
rconv -C -j -f -t malody --out output/nested /somewhere/my-input/sample.memo
```

### Usage of Library

As library, you should only have to import the entry file and the file formtats you want to use.
Each file-format should be imported in an own namespace, as types might overlap (Multiple types called `Chart` for example).

Converting procs are found in the `rconv/mapper` (imported via `rconv`) and are named `to{OtherFormat}`, i.E. `toFXF` or `toMalody`.

```nim
import pkg/rconv
import pkg/rconv/fxf as fxf
import pkg/rconv/memo as memo

let rawMemo = readFile("/home/user/some-chart.memo")
let memoChart = memo.parseMemoToMemson(rawMemo)
let fxfChart = memoChart.toFXF
echo chart
```

## Supported Formats

### Parsing

* Memo
* Malody
* FXF

### Convertion

<table>
    <tr>
        <td>From / To</td>
        <td>Memo</td>
        <td>MemoV2</td>
        <td>Malody¹</td>
        <td>FXF</td>
        <td>StepMania</td>
        <td>osu!¹</td>
        <td>ITG</td>
    </tr>
    <tr>
        <td style="text-align: center;">Memo</td>
        <td style="text-align: center;">➖</td>
        <td style="text-align: center;">❌</td>
        <td style="text-align: center;">✔️</td>
        <td style="text-align: center;">✔️</td>
        <td style="text-align: center;">❌</td>
        <td style="text-align: center;">❌</td>
        <td style="text-align: center;">❌</td>
    </tr>
    <tr>
        <td style="text-align: center;">MemoV2</td>
        <td style="text-align: center;">❌</td>
        <td style="text-align: center;">➖</td>
        <td style="text-align: center;">❌</td>
        <td style="text-align: center;">❌</td>
        <td style="text-align: center;">❌</td>
        <td style="text-align: center;">❌</td>
        <td style="text-align: center;">❌</td>
    </tr>
    <tr>
        <td style="text-align: center;">Malody</td>
        <td style="text-align: center;">❌</td>
        <td style="text-align: center;">❌</td>
        <td style="text-align: center;">➖</td>
        <td style="text-align: center;">✔️</td>
        <td style="text-align: center;">❌</td>
        <td style="text-align: center;">❌</td>
        <td style="text-align: center;">❌</td>
    </tr>
    <tr>
        <td style="text-align: center;">FXF</td>
        <td style="text-align: center;">❌</td>
        <td style="text-align: center;">❌</td>
        <td style="text-align: center;">❌</td>
        <td style="text-align: center;">➖</td>
        <td style="text-align: center;">❌</td>
        <td style="text-align: center;">❌</td>
        <td style="text-align: center;">❌</td>
    </tr>
    <tr>
        <td style="text-align: center;">StepMania</td>
        <td style="text-align: center;">❌</td>
        <td style="text-align: center;">❌</td>
        <td style="text-align: center;">❌</td>
        <td style="text-align: center;">❌</td>
        <td style="text-align: center;">➖</td>
        <td style="text-align: center;">❌</td>
        <td style="text-align: center;">❌</td>
    </tr>
    <tr>
        <td style="text-align: center;">osu!</td>
        <td style="text-align: center;">❌</td>
        <td style="text-align: center;">❌</td>
        <td style="text-align: center;">❌</td>
        <td style="text-align: center;">❌</td>
        <td style="text-align: center;">❌</td>
        <td style="text-align: center;">➖</td>
        <td style="text-align: center;">❌</td>
    </tr>
    <tr>
        <td style="text-align: center;">ITG</td>
        <td style="text-align: center;">❌</td>
        <td style="text-align: center;">❌</td>
        <td style="text-align: center;">❌</td>
        <td style="text-align: center;">❌</td>
        <td style="text-align: center;">❌</td>
        <td style="text-align: center;">❌</td>
        <td style="text-align: center;">➖</td>
    </tr>
</table>

**¹** Formats which support multiple different game-types.
Convertion for these formats is only for the most relevant game-type (i.E. StepMania -> osu! = StepMania -> osu!mania)

