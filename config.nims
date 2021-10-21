task debug, "Run in debug mode":
  switch "d", "debug"
  switch "r"
  setCommand "c", "src/rconv/cli.nim"

task build, "Run in debug mode":
  switch "o", "dist/app.exe"
  setCommand "c", "src/rconv/cli.nim"