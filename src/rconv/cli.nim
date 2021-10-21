import ./memson

let fileContent = readFile("./resources/roll_the_dice_ext.memo")
echo(parseToMemson(fileContent))
