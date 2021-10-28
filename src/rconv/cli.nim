import std/[json, jsonutils]

import ./fxf
import ./memo
import ./memson
import ./converters/memson_to_fxf

let fileContent = readFile("./resources/roll_the_dice_ext.memo")
let parsed = parseMemoToMemson(fileContent)

writeFile("memson.json", pretty(toJson(parsed), 4))

let chart = convertMemsonToFXF(parsed)
writeFile("fxf.json", pretty(toJson(chart), 4))
