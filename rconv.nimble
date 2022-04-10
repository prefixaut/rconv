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

# Required nim environment

requires "nim >= 1.6.0"

# Dependencies

requires "argparse >= 2.0.1"
requires "glob >= 0.11.1"
requires "regex >= 0.19.0"
requires "bignum >= 1.0.0"

# Test/Develop Dependencies

requires "coco >= 0.0.3"

# Tasks

task build, "Compile to a CLI app":
    switch "out", "bin/rconv"
    switch "app", "console"
    switch "usenimcache"
    setCommand "c", "src/rconv/cli.nim"

task staticlib, "Compile to a static library":
    switch "outdir", "dist"
    switch "app", "staticlib"
    switch "usenimcache"
    switch "noMain"
    switch "noLinking"
    #switch "passL", "-Llibs/gmp -llibgmp.dll"
    setCommand "c", "src/rconv.nim"

task dynlib, "Compile to a dynamic library":
    switch "outdir", "dist"
    switch "app", "lib"
    switch "usenimcache"
    switch "noMain"
    #switch "passL", "-Llibs/gmp -llibgmp.dll"
    setCommand "c", "src/rconv.nim"

task docs, "Build the documentation from source-code":
    switch "outdir", "docs"
    switch "project"
    switch "index", "on"
    switch "git.url", "https://github.com/prefixaut/rconv"
    switch "git.commit", "master"
    switch "git.devel", "master"
    setCommand "doc", "src/rconv.nim"
