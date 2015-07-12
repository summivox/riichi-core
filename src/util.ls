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

# simple functional (no need for lodash/prelude here)
export function sum(arr)
  s = 0
  for x in arr => s += x
  s
export function max(arr)
  m = -Infinity
  for x in arr => m >?= x
  m
export function min(arr)
  m = +Infinity
  for x in arr => m <?= x
  m
export function count(arr, f)
  s = 0
  for x in arr => if f x then s++
  s

# NOTE: in-place operation
export function randomShuffle(arr, rand = Math.random)
  l = arr.length
  for i from l - 1 til 0 by -1
    j = ~~(rand! * (i + 1))
    t = arr[j] ; arr[j] = arr[i] ; arr[i] = t
  arr

export function randomRange(lo, hi)
  Math.random!*(hi - lo) + lo

# ... I give up, this one is too hard
require! 'lodash._baseclone': baseClone
export function clone(o)
  baseClone o, true, -> if it?.paiStr? then return it else return
