import std/[json, jsonutils]
import ./memo
import ./memson

let fileContent = readFile("./resources/roll_the_dice_ext.memo")
writeFile("output.json", pretty(toJson(parseMemoToMemson(fileContent)), 4))
