task cli, "Build the library's CLI for direct use":
    switch "outdir", "dist"
    switch "app", "console"
    switch "usenimcache"
    setCommand "c", "src/rconv/cli.nim"

task build, "Build the library":
    switch "outdir", "dist"
    switch "app", "lib"
    switch "usenimcache"
    setCommand "c", "src/entry.nim"
