task regular, "Run in regular mode":
  switch "o", "dist/app.exe"
  setCommand "c", "src/rconv/cli.nim"

task debug, "Run in debug mode":
  switch "d", "debug"
  switch "r"
  switch "o", "dist/app.exe"
  setCommand "c", "src/rconv/cli.nim"
