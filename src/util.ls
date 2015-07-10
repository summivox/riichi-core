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

# who would import lodash for this?
export function sum(arr)
  s = 0
  for x in arr => s += x
  s

# and what about this?
export function count(arr, f)
  s = 0
  for x in arr => if f x then s++
  s

# ... I give up, this one is too hard
require! 'lodash._baseclone': baseClone
export function clone(o)
  baseClone o, true, -> if it?.paiStr? then return it else return
