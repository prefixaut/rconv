import std/marshal
import ./memson

let fileContent = readFile("./resources/roll_the_dice_ext.memo")
writeFile("output.json", $$(parseToMemson(fileContent)))
