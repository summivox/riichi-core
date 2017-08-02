# # Juntehai Decomposition
require! {
  './pai': Pai
  './decomp-lookup': {decomp1C, decomp1W}
}

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
