# enum: string wrapped in array as literals
# effortless `toString()` provided by array
export function Enum(names)
  o = {}
  for name in names => o[name] = [name]
  o

# player id lookup by natural turn after given player
# [next, oppo, prev]
export OTHER_PLAYERS = [[1 2 3] [2 3 0] [3 0 1] [0 1 2]]

# ceil positive number to nearest N
# e.g. ceilTo(1000, 100) => 1000, ceilTo(1001, 100) => 1100
export function ceilTo(x, N) => Math.ceil(x/N)*N
