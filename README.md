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
* **build**: Builds the project as a regular library.
* **document**: Builds the project's documentation.

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

For a full reference of all options, please call to the built in `-h`/`--help` option to display the help page.

### Usage of Library

As library, you should only have to import the entry file and the file formtats you want to use.
Each file-format should be imported in an own namespace, as types might overlap (Multiple types called `Chart` for example).

```nim
import pkg/rconv
import pkg/rconv/fxf as fxf

let chart: fxf.ChartFile = convert("/home/user/some-chart.memo", none(FileType), FileType.FXF, none(ConvertOptions))
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
        <td style="text-align: center;">❌</td>
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

