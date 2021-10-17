import ./memson

let fileContent = readFile("./roll_the_dice_ext.memo")
echo(parseToMemson(fileContent))
