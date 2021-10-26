import std/[json, jsonutils]
import ./memson

let fileContent = readFile("./resources/roll_the_dice_ext.memo")
writeFile("output.json", pretty(toJson(parseToMemson(fileContent)), 4))
