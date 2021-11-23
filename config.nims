task cli, "Build the library's CLI for direct use":
    switch "out", "rconv"
    switch "outdir", "dist"
    switch "app", "console"
    switch "usenimcache"
    setCommand "c", "rconv/cli.nim"

task build, "Build the library":
    switch "outdir", "dist"
    switch "app", "lib"
    switch "usenimcache"
    setCommand "c", "rconv/library.nim"

task document, "Build the documentation":
    switch "outdir", "docs"
    switch "project"
    switch "index", "on"
    switch "git.url", "https://github.com/prefixaut/rconv"
    switch "git.commit", "master"
    switch "git.devel", "master"
    setCommand "doc", "rconv/library.nim"
