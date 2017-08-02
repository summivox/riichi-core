
/****************************************/
# ## Packed Single-suite Bin Representation
# A bin is an array of 9 ints from 0 to 4. This can be packed into a single
# 32-bit integer by simply writing it in octal (3 bit per element), i.e.
# (in verilog bit slice notation) `x[2:0] == bin[0]`, `x[5:3] == bin[1]`, etc.
#
# NOTE: packed representation is internal (implementation detail) and not
# exposed to public-facing API.

# ### Fast test if packed bin is valid
# `binValid(x)` => `true`/`false`
#
# `true` if all elements are from 0 to 4
#
# Key expression: `((a.&.3)+3).&.(a.&.4)`:
#
# - when `0 <= a <= 4`: equals `0`
# - when `5 <= a <= 7`: equals `1`
#
# This is trivially extended to act on all elements in packed bin.
const SEVEN = 8~777_777_777
const FOUR  = 8~444_444_444
const THREE = 8~333_333_333
export function binValid(x)
  not ( ((x.&.THREE)+(0.|.THREE)).&.x.&.FOUR )

# ### Extract one element from packed bin
# **Example**: `binGet(8~101000222, 6) == 8~1`
export function binGet(x, i)
  (x.>>.((i.|.0)+(i.<<.1))).&.8~7

# ### Add a pattern onto current bin at specified location
# **Example**: `binAdd(8~101000222, 8~111, 5) == 8~112100222`
export function binAdd(x, p, i)
  (x + (p.<<.((i.|.0)+(i.<<.1)))).|.0

# ### Converts bin to 0-padded string representation
# **Example**: `8~030000111` => `'030000111'`
export function binToString(x)
  s = Number x .toString 8
  return ('0' * (9 - s.length)) + s

# ### Packing and unpacking
# **Example**: `[1 1 1 0 0 0 0 3 0]` <=> `8~030000111`
#
# NOTE: input is not validated
export function binPack(bin)
  bin.reduceRight (a, b) -> (a.<<.3).|.b
export function binUnpack(x)
  for i til 9
    z = x.&.8~7
    x.>>.=3
    z


/****************************************/
# ## Pre-computed Tables for Accelerated Standard-form Decomposition
# Decomposition is a very frequent yet expensive operation. In order to save
# time, we exhaustively search for all decomposition solutions for all
# single-suite hands and store them in 2 hash tables: one for "complete" and
# the other for "waiting" (tenpai).

# ### "Complete" table
# `decomp1C[packedBin] = [{shuntsu, jantou, mentsu: [...]}, ...]`
#
# Given packed bin (single-suite), determine all distinct ways to decompose it
# into:
#
# - at most 4 complete mentsu (either shuntsu or koutsu)
# - at most 1 complete jantou
#
# Since shuntsu and mentsu both contain `3` pai, input must contain either:
#
# - `3n` pai: `n` complete mentsu and no jantou
# - `3n + 2` pai: `n` complete mentsu and exactly 1 complete jantou
#
# Each decomposition `{shuntsu, jantou, mentsu}`:
#
# - `shuntsu`: number of shuntsu in this decomposition (0 to 4)
# - `jantou`: position of jantou (0 to 8) or `null` if no jantou
# - `mentsu[i]`:
#   - shuntsu: position of (the smallest pai in) shuntsu (0 to 8)
#   - koutsu: position of (the 3 identical pai in) koutsu + 16 (16 to 24)
#
# The hash table contains only entries for bins that can be decomposed.
#
# **Example**:
#
# ```livescript
# decomp1C[8~000122100] `assert.deepEqual` [
#   * shuntsu: 2, jantou: null, mentsu: [2, 3]
# ]
# decomp1C[8~200003330] `assert.deepEqual` [
#   * shuntsu: 3, jantou: 8, mentsu: [1, 1, 1]
#   * shuntsu: 0, jantou: 8, mentsu: [17, 18, 19]
# ]
# ```
export const decomp1C = []
# Pre-computation algorithm: rather than enumerating all bins, we *generate*
# all valid decompositions by depth-first searching positions of components.
#
# In order to avoid duplicates, we search in the following order:
#
# 1. jantou (null, 0 to 8)
# 2. shuntsu (in non-decreasing position order)
# 3. koutsu (ditto)
!function makeDecomp1C
  jantou = null
  shuntsu = 0
  mentsu = [0 0 0 0]
  !function dfsShuntsu(n, iMin, binOld)
    for i from iMin til 7
      bin = binAdd(binOld, 8~111, i)
      if binValid bin
        shuntsu++
        mentsu[n] = i
        decomp1C.[][bin].push do
          {shuntsu, jantou, mentsu: mentsu.slice(0, n + 1)}
        if n < 3
          dfsShuntsu n + 1, i, bin # non-decreasing order
          dfsKoutsu  n + 1, 0, bin # proceed to koutsu
        shuntsu--
  !function dfsKoutsu(n, iMin, binOld)
    for i from iMin til 9
      bin = binAdd(binOld, 8~3, i)
      if binValid bin
        mentsu[n] = i.|.2~10000
        decomp1C.[][bin].push do
          {shuntsu, jantou, mentsu: mentsu.slice(0, n + 1)}
        if n < 3
          dfsKoutsu n + 1, i, bin
  # "no juntehai" is considered "complete" too
  decomp1C[0] = [{shuntsu: 0, jantou: null, mentsu: []}]
  # without jantou
  dfsShuntsu 0 0 0
  dfsKoutsu  0 0 0
  # with jantou
  for jantou til 9
    bin = 8~2.<<.((jantou.|.0)+(jantou.<<.1))
    decomp1C[bin] = [{shuntsu, jantou, mentsu: []}]
    dfsShuntsu 0 0 bin
    dfsKoutsu  0 0 bin

# ### "Waiting"/tenpai table
# `decomp1W[packedBin] = [{...}]`
#
# Given packed bin, determine all distinct ways to decompose it into:
#
# - an incomplete (1 pai missing) mentsu or jantou; one of:
#   - `'tanki'`: a single pai to become jantou (`8~1`)
#   - `'shanpon'`: a pair to become koutsu (`8~2`)
#   - `'kanchan'`: 2 spaced pai to become shuntsu (`8~101`)
#   - `'ryanmen'`, `'penchan'`: 2 adjacent pai to become shuntsu (`8~11`)
# - the rest can be completely decompsed (i.e. with `decomp1C` entry)
#
# while satisfying:
#
# - at most 4 mentsu (complete + incomplete)
# - at most 1 jantou (complete + incomplete)
#
# Each decomposition is an object:
#
# - `binC`: bin for the complete part of the decomposition
# - `cs`: a reference to `decomp1C[binC]`
# - `hasJantou`: whether the decomposition (complete + incomplete) has exactly
#   one jantou (true/false)
# - `allHasShuntsu`: whether all decompositions represented by this entry
#   contain one or more shuntsu
# - `tenpaiType`: type of the incomplete part; `'tanki'`, `'shanpon'`, etc.
#   (see above list)
# - `tenpaiN`: position of tenpai (missing pai)
# - `anchorN`: once the incomplete part is completed by adding the missing pai,
#   the position of this mentsu/jantou (see `decomp1C`)
#
# **Example**:
#
# ```livescript
# decomp1W[8~000001120] `assert.deepEqual` [
#   # ryanmen tenpai: two tenpai ways listed separately
#   * binC: 8~000000020, cs: decomp1C[8~000000020]
#     hasJantou: true, allHasShuntsu: true
#     tenpaiType: \ryanmen, tenpaiN: 1, anchorN: 1
#   * binC: 8~000000020, cs: decomp1C[8~000000020]
#     hasJantou: true, allHasShuntsu: true
#     tenpaiType: \ryanmen, tenpaiN: 4, anchorN: 2
#   # tanki tenpai
#   * binC: 8~000001110, cs: decomp1C[8~000001110]
#     hasJantou: true, allHasShuntsu: true
#     tenpaiType: \tanki, tenpaiN: 1, anchorN: 1
# ]
# # jun-chuuren tenpai form (see test data for `decompTenpai`)
# decomp1W[8~311111113].length `assert.equal` 15
# ```
export const decomp1W = []
# Pre-computation algorithm: try add an incomplete part on top of each bin in
# `decomp1C` table.
#
# NOTE: While I don't like the stateful-ness, I could not think of a "pure" way
# of handling `hasJantou` and `allHasShuntsu` as clean as status quo...
!function makeDecomp1W
  for binC, cs of decomp1C
    binC = Number binC
    hasJantou = cs.0.jantou?
    nMentsu = cs.0.mentsu.length
    allHasShuntsu = cs.every (.shuntsu > 0)
    if not hasJantou
      hasJantou = true # tanki serves as jantou
      for i from 0 to 8 => expand \tanki 8~1 0 0 i
      hasJantou = false # restore it
    if nMentsu < 4
      for i from 0 to 8 => expand \shanpon 8~2 0 0 i
      allHasShuntsu = true # kanchan/ryanmen/penchan serves as shuntsu
      for i from 0 to 6 => expand \kanchan 8~101 1 0 i
      expand \penchan 8~11 2 0 0
      for i from 1 to 6
        expand \ryanmen 8~11 -1 -1 i
        expand \ryanmen 8~11 2 0 i
      expand \penchan 8~11 -1 -1 7
      # no need to restore `allHasShuntsu` here
  !function expand(tenpaiType, pat, dTenpai, dAnchor, i)
    binW = binAdd(binC, pat, i)
    tenpaiN = i + dTenpai
    anchorN = i + dAnchor
    # Constraint: no blatant karaten (tenpai exhausted in juntehai)
    if binValid binW and binGet(binW, tenpaiN) < 4
      decomp1W.[][binW].push {
        binC, cs
        hasJantou, allHasShuntsu
        tenpaiType, tenpaiN, anchorN
      }

# ### Running Pre-computation
#
# It takes quite some time to build these tables (~150ms on my Surface Pro 4).
# While it seems attractive to compute once and simply load them, either
# through source code or (possibly compacted/compressed) file, they are not as
# fast as simply computing them, as the main time is spent on building the
# data structure of the tables while the computation "overhead" is minimal.
#
# Therefore, the tables are currently computed when this module is *first*
# `require`d. If asynchronous or delayed loading is desired, simply delay the
# `require` call.
now = require 'performance-now'
t0 = now!
makeDecomp1C!
t1 = now!
makeDecomp1W!
t2 = now!
# Time spent on computation is exported.
export STARTUP_TIME =
  c: t1 - t0
  w: t2 - t1
  cw: t2 - t0
