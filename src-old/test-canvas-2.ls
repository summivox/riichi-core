require! chalk
{stdout} = process

output = ->
  for r til 24
    for c til 80 => stdout.write it[r][c]
    stdout.write '\n'

canvas = for r til 24 => for c til 80 => ' '

bitblt = (r1, r2, c1, c2, src) ->
  for r from r1 to r2
    for c from c1 to c2
      canvas[r][c] = src[r - r1][c - c1]

bitblt 8 15 31 48 """
  +----------------+
  | E1.0 $2k  [60] |
  | 1z 2z 3z ## ## |
  +----------------+
  |     45600N     |
  |E12300    34500W|
  |     S23400     |
  +----------------+
""".split \\n


canvas[16][31] = chalk.bold.red '5'
canvas[16][32] = chalk.bold.red 'm'
canvas[16][34] = chalk.bold.cyan '6'
canvas[16][35] = chalk.bold.cyan 'p'
canvas[16][37] = chalk.bold.green '7'
canvas[16][38] = chalk.bold.green 's'
/*
canvas[16][37] = chalk '7'
canvas[16][38] = chalk.green 's'
canvas[16][40] = chalk '1'
canvas[16][41] = chalk 'z'
canvas[16][43] = chalk '2'
canvas[16][44] = chalk 'z'
canvas[16][46] = chalk.red '7'
canvas[16][47] = chalk.red 'z'
*/

canvas[17][31] = chalk.bold.white '5'
canvas[17][32] = chalk.bold.white 'z'
canvas[17][34] = chalk.bold.white '6'
canvas[17][35] = chalk.bold.white 'z'
canvas[17][37] = chalk.bold.white '7'
canvas[17][38] = chalk.bold.white 'z'

canvas[9][28] = chalk.bold.red '5'
canvas[9][29] = chalk.bold.red 'm'
canvas[10][28] = chalk.bold.cyan '6'
canvas[10][29] = chalk.bold.cyan 'p'
canvas[11][28] = chalk.bold.green '7'
canvas[11][29] = chalk.bold.green 's'
canvas[12][28] = '5'
canvas[12][29] = chalk.red 'm'
canvas[13][28] = '5'
canvas[13][29] = chalk.red 'm'
canvas[14][28] = '5'
canvas[14][29] = chalk.red 'm'


output canvas


void
