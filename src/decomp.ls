# # Juntehai Decomposition
require! {
  './pai': Pai
}


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



/****************************************/
# ## Tenpai Decomposition of Full Juntehai
# `decompTenpai(bins)` =>
# ```
# {
#   decomps: [{mentsu: [...], jantou, k7, tenpaiType, tenpai, anchor}, ...]
#   tenpaiSet: [...]
# }
# ```
# NOTE: input is *unpacked* bins (4-array of 9-array of number from 0 to 4).
#
# Find all distinct decompositions of given full juntehai into:
#
# - at most 4 mentsu
# - exactly 1 jantou
#
# with exactly one of them incomplete (missing 1 pai) and the rest complete.
#
# **Example**: see test data (`/test/data/decomp/tenpai/*.json.ls`)

# ### Special Forms: Kokushi-musou and Chiitoitsu
#
# These are "non-standard" ways of tenpai/agari that applies only to juntehai
# as a whole.
#
# NOTE: shorthands:
#
# - kokushi-musou => kokushi/kokushi13 => `k`
# - chiitoitsu => chiitoi => `7`

# #### Kokushi-musou Tenpai
#
# juntehai must be either:
#
# - `'19m19p19s1234567z'` => 13-wait (on any yaochuupai)
# - replacing one yaochuupai with another in above => 1-wait (on the missing)
#
# Kokushi-musou is *exclusive*: a juntehai can either be decomposed
# into kokushi-musou or standard-form (4 mentsu + 1 jantou); never both.
function tenpaiK(bins)
  yaochuu = Pai.yaochuuFromBins bins
  c0 = c1 = c2 = 0
  i0 = -1
  for x, i in yaochuu => switch x
  | 0
    if ++c0 > 1 then return null
    i0 = i
  | 1 => ++c1
  | 2
    if ++c2 > 1 then return null
  | 3, 4 => return null
  if c1 == 13
    return 13
  if c0 == 1 and c1 == 11 and c2 == 1
    return i0
  return null

# #### Cached kokushi-musou tenpai results
DT_KOKUSHI = Pai.YAOCHUU.map (tenpai) -> [{
  mentsu: [], jantou: null, k7: \kokushi
  tenpaiType: \kokushi, tenpai, anchor: tenpai
}]
DT_KOKUSHI13 = Pai.YAOCHUU.map (tenpai) -> {
  mentsu: [], jantou: null, k7: \kokushi
  tenpaiType: \kokushi13, tenpai, anchor: tenpai
}

# #### Chiitoitsu Tenpai
#
# 6 toitsu + 1 tanki
#
# Contrary to kokushi-musou, there are juntehai that can be decomposed as both
# chiitoitsu and as standard-form. e.g. `'112233m44556p77z'` (ryanpeikou form).
function tenpai7(bins)
  c1 = c2 = 0
  p1 = null
  for s til 4 => for n til 9 => switch bins[s][n]
  | 0 => void
  | 1
    if ++c1 > 1 then return null
    p1 = Pai[s][n+1]
  | 2 => ++c2
  | _ => return null
  if c1 == 1 and c2 == 6 then return p1
  return null

# ### Misc Helpers

# #### Convert single-suite packed mentsu into all-suite mentsu
#
# - Packed mentsu: number; see `decomp1C`
# - All-suite mentsu: `{type, anchor}`
#   - `type`: `anko`/`shuntsu`
#   - `anchor`: Pai with smallest number
#
# **Example**:
#
# ```livescript
# mentsuWithSuite[1](4) `assert.deepEqual` {type: 'shuntsu', anchor: Pai\5s}
# mentsuWithSuite[2](17) `assert.deepEqual` {type: 'anko', anchor: Pai\2s}
# ```
#
# NOTE: `'anko'` is used instead of `'koutsu'` (see `decompAgari`)
mentsuWithSuite = Pai[0 1 2 3].map (P) -> (x) ->
  type: if x.&.2~10000 then \anko else \shuntsu
  anchor: P[(x.&.2~1111) + 1]

# ### Main Tenpai Decomposition Algorithm
export function decompTenpai(bins)
  # #### Kokushi
  # Since kokushi is exclusive, if juntehai matches then skip all rest.
  if (w = tenpaiK bins)?
    if w == 13
    then return {
      decomps: DT_KOKUSHI13
      tenpaiSet: Pai.YAOCHUU
    }
    else return {
      decomps: DT_KOKUSHI[w]
      tenpaiSet: [Pai.YAOCHUU[w]]
    }

  # #### Standard-form

  # result (shared with chiitoi)
  decomps = []
  tenpaiSet = []

  # pack input
  bitBins = bins.map binPack

  # complete decomp for each suite in input
  css =
    decomp1C[bitBins.0]
    decomp1C[bitBins.1]
    decomp1C[bitBins.2]
    # Constraint: 1-7z cannot form shuntsu
    decomp1C[bitBins.3]?.filter (.shuntsu == 0)

  # There is exactly 1 incomplete mentsu/jantou and it consists of pai from
  # only 1 suite. We might be able to infer which suite it is by looking at
  # number of suites without complete decomposition:
  #
  # - 0 => tenpai might come from any suite; we need to try each
  # - 1 => tenpai must come from this suite
  # - 2+ => no standard-form solution; try chiitoi instead
  jw = -1
  for j til 4
    if not css[j]?.length
      if jw == -1
      then jw = j
      else jw = -2; break
  switch jw
  | -1
    f 0 1 2 3
    f 1 0 2 3
    f 2 0 1 3
    f 3 0 1 2
  | 0 => f 0 1 2 3
  | 1 => f 1 0 2 3
  | 2 => f 2 0 1 3
  | 3 => f 3 0 1 2
  | _ => void

  # Enumerate standard-form decompositions with tenpai in suite `jw`
  !function f(jw, j0, j1, j2)
    ws = decomp1W[bitBins[jw]]
    return unless ws?
    cs0 = css[j0]
    cs1 = css[j1]
    cs2 = css[j2]

    # Constraint: exactly 1 jantou.
    # Complete suites may only contribute 0 or 1.
    cJantou0 = cs0.0.jantou
    cJantou1 = cs1.0.jantou
    cJantou2 = cs2.0.jantou
    cJantouN = cJantou0? + cJantou1? + cJantou2?
    return unless cJantouN <= 1
    # Cache the jantou (if any in complete suites)
    switch
    | cJantou0? => cJantou = Pai[j0][that + 1]
    | cJantou1? => cJantou = Pai[j1][that + 1]
    | cJantou2? => cJantou = Pai[j2][that + 1]
    | _ => cJantou = null

    # Tenpai set, represented as a bitmap.
    # e.g. jw == 0 then bit 2 set means `'3m'`in tenpai set
    bitmap = 0

    # Decomposition of full juntehai is basically filtered Cartesian product of
    # decompositions of all 4 suites. This is computed using nested for loops.
    # Despite the apparent deep nesting, the inner loop is not executed as many
    # times as it seems due to all the constraints on solution.

    # For each tenpai suite:
    for {cs: csw, tenpaiType, tenpaiN, anchorN}:w in ws
      # Constraint: 1-7z cannot form shuntsu.
      # NOTE: not redundant; this decides if tenpai is added to set
      continue if jw == 3 and w.allHasShuntsu
      # Constraint: exactly 1 jantou.
      # Jantou either comes from complete suites or tenpai suite
      continue unless cJantouN == 1 xor w.hasJantou

      # Add tenpai to set
      bitmap .|.= 1.<<.tenpaiN
      tenpai = Pai[jw][tenpaiN + 1]
      anchor = Pai[jw][anchorN + 1]
      # For each complete component of tenpai suite:
      for cw in csw
        # Constraint: 1-7z cannot form shuntsu
        continue if jw == 3 and cw.shuntsu > 0
        wJantou = if cw.jantou? then Pai[jw][that + 1] else null
        # For each complete decomposition (Cartesian product):
        for c0 in cs0 => for c1 in cs1 => for c2 in cs2
          # NOTE: shuntsu already filtered (see `css` above)
          decomps.push {
            mentsu: [].concat do
              cw.mentsu.map mentsuWithSuite[jw]
              c0.mentsu.map mentsuWithSuite[j0]
              c1.mentsu.map mentsuWithSuite[j1]
              c2.mentsu.map mentsuWithSuite[j2]
            jantou: cJantou ? wJantou
            k7: null
            tenpaiType, tenpai, anchor
          }
        /*end for c0, c1, c2*/
      /*end for cw*/
    /*end for w*/

    # Add tenpai from this suite to the overall tenpai set
    [].push.apply tenpaiSet, Pai.arrayFromBitmapSuite(bitmap, jw)
  /*end function f*/

  # #### Chiitoi
  #
  # NOTE:
  #
  # - Although chiitoi implies tanki-machi, it is not a part of the jantou in
  #   the 4 mentsu + 1 jantou standard-form. Therefore `tenpaiType` is set to
  #   `'chiitoi'` rather than `'tanki'`.
  # - Reason this is considered last: easier de-dupe in `tenpaiSet`
  if (w = tenpai7 bins)?
    decomps.push {
      mentsu: [], jantou: null, k7: \chiitoi
      tenpaiType: \chiitoi, tenpai: w, anchor: w
    }
    if w not in tenpaiSet then tenpaiSet.push w

  tenpaiSet.sort Pai.compare
  return {decomps, tenpaiSet}


# ## Agari Decomposition
# `decompAgari(tenpaiDecomp, agariPai, isRon)` =>
# `[{mentsu, jantou, k7, tenpaiType}, ...]`
#
# Agari is basically juntehai (in tenpai) + tenpai (the missing one). Although
# merely decomposing agari is a simpler problem than tenpai alone, since tenpai
# decomposition is *always* computed before agari anyway, we may as well build
# the agari decomposition on top of the tenpai decomposition. Since we already
# have `tenpaiType` information embedded in tenpai decomposition, this is a
# very straightforward transformation.

export function decompAgari({decomps}:tenpaiDecomp, agariPai, isRon)
  agariPai .= equivPai
  for {mentsu, jantou, k7, tenpaiType, tenpai, anchor} in decomps
    continue if agariPai != tenpai
    if !k7?
      switch tenpaiType
      # **tanki**: Add completed jantou
      | \tanki
        jantou = tenpai

      # **shanpon**: Append completed koutsu to (completed) mentsu array
      #
      # NOTE: the rule distinguishes between open (min) and closed (an) koutsu,
      # which in this case is determined by ron (min) or tsumo-agari (an).
      | \shanpon
        mentsu ++= {anchor, type: if isRon then \minko else \anko}

      # **kanchan/penchan/ryanmen**: Append completed shuntsu to (completed)
      # mentsu array
      | \kanchan, \penchan, \ryanmen
        mentsu ++= {anchor, type: \shuntsu}

      | _ => throw Error 'WTF'
    {mentsu, jantou, k7, tenpaiType}
