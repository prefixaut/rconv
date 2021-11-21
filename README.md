# rconv

rconv is a library and command-line program to convert between various rhythm game formats.

Currently following formats are supported:
* Memo (Reading only)
* Malody (Reading only)
* FXF (Reading & Writing)

## Installation

Currently not available as nimble package just yet, as it's still in an unstable phase.

If you still want to use it as library, you can do so as a Git Submodule and import the [entry](./src/entry.nim)-file.

## Usage

### Library

As library, you should only have to import the entry file and the file formtats you want to use.
Each file-format should be imported in a own namespace, as types might overlap (Multiple types called `Chart` for example).

```nim
import pkg/rconv
import pkg/rconv/fxf as fxf

let chart: fxf.ChartFile = convert("/home/user/some-chart.memo", none(FileType), FileType.FXF, none(ConvertOptions))
echo chart
```

For full information of all functions, types, etc., please refer to the documentation.

### CLI

The CLI is rather straight forward and may be used like this:

```sh
rconv [options] <--to=output-type> <input-files>
```

The CLI requires an output-type (`-t`/`--to`), and the file-paths to the charts you want to convert.

For a full reference of all options, please call to the built in `-h`/`--help` option to display the help page.
