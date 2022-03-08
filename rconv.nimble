# Package

version       = "0.1.0"
author        = "PreFiXAUT"
description   = "Rhythm Game file converter"
license       = "MIT"
srcDir        = "src"
binDir        = "bin"
skipDirs      = @[".github", ".vscode", "definitions"]
skipFiles     = @[".editorconfig"]
namedBin      = {"rconv/cli": "rconv"}.toTable
installExt    = @["nim"]

# Dependencies

requires "nim >= 1.6.0"

requires "argparse >= 2.0.1"
requires "glob >= 0.11.1"

# Tasks

task clib, "Compile the library to a native one (dll/so)":
    switch "outdir", "dist"
    switch "app", "lib"
    switch "usenimcache"
    setCommand "c", "src/rconv.nim"

task docs, "Build the documentation from source-code":
    switch "outdir", "docs"
    switch "project"
    switch "index", "on"
    switch "git.url", "https://github.com/prefixaut/rconv"
    switch "git.commit", "master"
    switch "git.devel", "master"
    setCommand "doc", "src/rconv.nim"
