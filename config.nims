task cli, "Build the CLI":
    switch "out", "rconv"
    switch "outdir", "dist"
    switch "app", "console"
    switch "usenimcache"
    setCommand "c", "src/rconv/cli.nim"

task lib, "Build the library":
    switch "outdir", "dist"
    switch "app", "lib"
    switch "usenimcache"
    setCommand "c", "src/rconv.nim"

task test, "Run the tests":
    # switch "usenimcache"
    setCommand "r", "tests/*.nim"

task docs, "Build the documentation":
    switch "outdir", "docs"
    switch "project"
    switch "index", "on"
    switch "git.url", "https://github.com/prefixaut/rconv"
    switch "git.commit", "master"
    switch "git.devel", "master"
    setCommand "doc", "src/rconv.nim"
