# player id lookup by natural turn after given player
# [next, oppo, prev]
export OTHER_PLAYERS = [[1 2 3] [2 3 0] [3 0 1] [0 1 2]]

# floor/ceil positive number to multiple of N
# examples:
#             (999, 100)    (1000, 100)   (1001, 100)
#   floorTo   900           1000          1000
#    ceilTo   1000          1000          1100
export function floorTo(x, N) => Math.floor(x/N)*N
export function  ceilTo(x, N) =>  Math.ceil(x/N)*N

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
