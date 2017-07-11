require! chalk
{stdout} = process

output = ->
  for r til 24
    for c til 80 => stdout.write it[r][c]
    stdout.write '\n'

canvas = for r til 24 => for c til 80 => chalk.bgBlue ' '

canvas[16][31] = chalk.bgRed.black '5'
canvas[16][32] = chalk.bgRed.black 'm'
canvas[16][34] = chalk.bgCyan.black '6'
canvas[16][35] = chalk.bgCyan.black 'p'
/*
canvas[16][37] = chalk.bgWhite.black '7'
canvas[16][38] = chalk.bgWhite.green 's'
canvas[16][40] = chalk.bgWhite.black '1'
canvas[16][41] = chalk.bgWhite.black 'z'
canvas[16][43] = chalk.bgWhite.black '2'
canvas[16][44] = chalk.bgWhite.black 'z'
canvas[16][46] = chalk.bold.bgWhite.red '7'
canvas[16][47] = chalk.bold.bgWhite.red 'z'
*/

canvas[17][31] = chalk.bgWhite.black '5'
canvas[17][32] = chalk.bgWhite.black 'z'
canvas[17][34] = chalk.bgGreen.black '6'
canvas[17][35] = chalk.bgGreen.black 'z'
canvas[17][37] = chalk.bgRed.black '7'
canvas[17][38] = chalk.bgRed.black 'z'

canvas[9][28] = chalk.bgWhite.black '5'
canvas[9][29] = chalk.bgWhite.red 'm'
canvas[10][28] = chalk.bgWhite.black '5'
canvas[10][29] = chalk.bgWhite.red 'm'
canvas[11][28] = chalk.bgWhite.black '5'
canvas[11][29] = chalk.bgWhite.red 'm'
canvas[12][28] = chalk.bgWhite.black '5'
canvas[12][29] = chalk.bgWhite.red 'm'
canvas[13][28] = chalk.bgWhite.black '5'
canvas[13][29] = chalk.bgWhite.red 'm'
canvas[14][28] = chalk.bgWhite.black '5'
canvas[14][29] = chalk.bgWhite.red 'm'


output canvas


void
