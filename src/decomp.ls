# tenpai/agari decomposition
# NOTE: bin(s) format is expected (see `./pai`)

require! {
  './pai': Pai
  './util': {sum, clone}
}


# magic numbers:
#   number range: [0, N)
#   max # of single pai in game: M
#   max # of pai in juntehai: K
#   max # of jantou: CAP_JANTOU = 1
#   max # of mentsu (= shuntsu + koutsu): CAP_MENTSU
const N = 9, M = 4, K = 14
const CAP_JANTOU = 1
const CAP_MENTSU = calcCapMentsu K
function calcCapMentsu => Math.floor((it - 2)/3)

# derived
const N_LOG2 = Math.ceil Math.log2 N
const N_MASK = (1 .<<. N_LOG2) - 1
const MP_LOG2 = Math.ceil Math.log2 (M + 1)
const MP_MASK = (1 .<<. MP_LOG2) - 1


# -------------------------
# pattern:
# - kernel[i] placed at bin[offset+i], nPai = sum(kernel)
# - either:
#   - complete (wait == null, `target == name`)
#   - waits for valid pai `offset+wait[i]` to become `target`
# - waitAbs[offset]: precomputed array of all valid `offset+wait[i]`
#
# NOTE:
# - \toitsu + \jantou => shanpon
# - \ryanmen includes both ryanmen and penchan
# see also `decompAgariFromTenpai`
patterns =
  # complete mentsu/jantou : no wait
  * name: \shuntsu target: \shuntsu kernel: [1 1 1] wait: null
  * name: \koutsu  target: \koutsu  kernel: [3]     wait: null
  * name: \jantou  target: \jantou  kernel: [2]     wait: null
  # incomplete mentsu/jantou : 1/2 wait(s)
  # NOTE: \ryanmen could actually become \penchan depending on position
  * name: \tanki   target: \jantou  kernel: [1]     wait: [0]
  * name: \toitsu  target: \koutsu  kernel: [2]     wait: [0]
  * name: \kanchan target: \shuntsu kernel: [1 0 1] wait: [1]
  * name: \ryanmen target: \shuntsu kernel: [1 1]   wait: [-1 2]
const nPatterns = patterns.length

# index for `pattern.target` & `decomp1.nTarget`
const TARGET_ID = shuntsu: 0, koutsu: 1, jantou: 2
const TARGET_N = 3

# completes infered properties for patterns
for pattern, id in patterns
  pattern.id = id
  pattern.targetId = TARGET_ID[pattern.target]
  pattern.nPai = sum pattern.kernel
  if wait = pattern.wait
    pattern.waitAbs = waitAbs = new Array N
    for offset from 0 til N
      a = [abs for rel in wait when 0 <= (abs = offset + rel) < N]
      waitAbs[offset] = a



# -------------------------
# precomputed lookup table that maps complete/tenpai 1-suite juntehai (in bin
# format) to all valid pattern decompositions of it
#
# decomp1Lookup[compactBin bin]:
#   complete, waiting: array of decomp1
# decomp1: one decomposition of bin
#   nTarget: # of [shuntsu, koutsu, jantou], both complete and incomplete
#   placements: array of compacted placements `{patternId, offset}`
#
# NOTE:
# - `1` in `decomp1` stands for "1-suite"
# - placements are sorted by patternId then offset (compacted: numerical order)
# - as a result, incomplete patterns (if any) must be at the end of `placements`
decomp1Lookup = []


# compact bins and placements into integers (packed bitfields)

function compactBin
  s = 0
  for x til N
    s = (s .<<. MP_LOG2) .|. it[x]
  s
# NOTE: the following can be used to produce a more human-readable key
# compactBin = -> Number it.join ''

function compactPlacement(patternId, offset)
  (patternId .<<. N_LOG2) + offset
function restorePlacement
  patternId: it .>>. N_LOG2
  offset:    it .&.  N_MASK


# get entry / create empty entry in decomp1Lookup
# key: \complete/\waiting
#
# NOTE:
# - cannot be trivially written even in livescript
# - whitespaces are significant
function decomp1LookupEntry(bin, key)
  decomp1Lookup[compactBin bin]?[key] ? []
function ensureDecomp1LookupEntry(bin, key)
  (decomp1Lookup[compactBin bin] ||= {})[key] ||= []

# precompute the lookup table by searching
export init = function makeDecomp1Lookup
  if decomp1Lookup.length then return decomp1Lookup

  # state: current search node
  #   nPai = # of all pai (implicit in decomp1 object)
  state = {
    bin: [0] * N
    nPai: 0
    nTarget: [0] * TARGET_N
    placements: []

    remaining: (pattern) ->
      if pattern.target == \jantou
        CAP_JANTOU - @nTarget[2]
      else
        CAP_MENTSU - @nTarget[0] - @nTarget[1]
    toDecomp1: -> {
      nTarget: @nTarget.slice!
      placements: @placements.slice!
    }
  }

  # try place given pattern at offset
  # return: if successfully placed
  function tryPlace(pattern, offset)
    {id, targetId, kernel, nPai} = pattern

    # check if out of boundary
    if offset + kernel.length > N then return false

    # check if enough room to place
    canPlace = true
    for x, rel in kernel
      if state.bin[offset + rel] + x > M
        canPlace = false
        break
    if !canPlace then return false

    state.nPai += nPai
    state.nTarget[targetId]++
    for x, rel in kernel
      state.bin[offset + rel] += x
    state.placements.push(compactPlacement(id, offset))
    return true

  # undo most recent placement (repeated n times)
  !function unPlace(pattern, offset, n)
    if !n then return
    {targetId, kernel, nPai} = pattern

    state.nPai -= nPai*n
    state.nTarget[targetId] -= n
    for x, rel in kernel
      state.bin[offset + rel] -= x*n
    state.placements.splice(-n) # equivalent to `.pop!` n times

  # check for invalid case of pure void wait (juntehai karaten)
  function isKaraten(pattern, offset)
    {machiAbs} = pattern
    if !machiAbs? then return false
    for m in machiAbs[offset]
      if state.bin[m] < M
        return false
    return true

  # nested DFS: avoid searching the same configuration twice
  !function dfsPattern(minPatternId)
    if state.nPai >= K then return
    for patternId from minPatternId til nPatterns
      pattern = patterns[patternId]
      remaining = state.remaining(pattern)
      if remaining
        dfsOffset(patternId, 0, remaining)
  !function dfsOffset(patternId, minOffset, remaining)
    if minOffset >= N then return
    {wait} = pattern = patterns[patternId]
    for offset from minOffset til N
      n = 0 # total # of patterns placed at this location
      while n < remaining && tryPlace(pattern, offset)
        n++
        decomp1 = state.toDecomp1!
        if wait
          if !isKaraten(pattern, offset)
            ensureDecomp1LookupEntry(state.bin, \waiting).push(decomp1)
            break # only 1 waiting pattern can be placed in total
        else
          ensureDecomp1LookupEntry(state.bin, \complete).push(decomp1)
          if remaining - n > 0
            dfsOffset(patternId, offset+1, remaining - n)
          dfsPattern(patternId+1)
      unPlace(pattern, offset, n)

  # "zero" decomposition
  ensureDecomp1LookupEntry(state.bin, \complete).push(state.toDecomp1!)
  # launch search
  dfsPattern(0)
  return decomp1Lookup

# prints decomp1Lookup
# NOTE: very large output; try redirect stdout to file
export !function printDecomp1Lookup
  for bin, {complete, waiting} of decomp1Lookup
    if complete?.length
      cs = ' C' + JSON.stringify complete
    else cs = ''
    if waiting?.length
      ws = ' W' + JSON.stringify waiting
    else ws = ''
    console.log "#bin:#cs#ws"



# -------------------------
# decompose complete juntehai (4 bins, all suites) for tenpai/agari
#
# decomp:
#   standard form:
#     mentsu: array of:
#       type: (see pattern.name)
#       pai: Pai (pattern origin)
#     jantou: null or Pai
#     k7: null
#   kokushi/chiitoi form:
#     mentsu: []
#     jantou: null
#     k7: \kokushi or \chiitoi
#   wait: null or array of Pai
#
# NOTE:
# - `decomp` refers to the whole hand while `decomp1` only refers to one suite
#
# - `mentsu.type` taken from `pattern.name` instead of `pattern.target` so that
#   incomplete patterns can be identified


# helper functions

# find wait in one particular decomp1 of a bin (bitmap format)
# NOTE: wait can only be at the end of placements, see above
function waitBitmapFromDecomp1(bin, decomp1)
  ret = 0
  placements = decomp1.placements
  placement = placements[placements.length-1]
  {patternId, offset} = restorePlacement placement
  {waitAbs} = patterns[patternId]
  if waitAbs
    for w in waitAbs[offset]
      if bin[w] < M
        ret .|.= 1 .<<. w
  ret

# subtract mentsu/jantou count of decomp1 from remaining
# return false if cap goes negative
function subRem(rem, decomp1)
  if !decomp1.placements.length then return true
  {nTarget: [shuntsu, koutsu, jantou]} = decomp1
  rem[0] -= shuntsu + koutsu
  rem[1] -= jantou
  return rem[0] >= 0 && rem[1] >= 0
# same as above, but add it back
!function addRem(rem, decomp1)
  if !decomp1.placements.length then return true
  {nTarget: [shuntsu, koutsu, jantou]} = decomp1
  rem[0] += shuntsu + koutsu
  rem[1] += jantou

# decomp1 for each bin
function decomp1sFromBins(bins, key) => [
  decomp1LookupEntry(bins[0], key)
  decomp1LookupEntry(bins[1], key)
  decomp1LookupEntry(bins[2], key)
  decomp1LookupEntry(bins[3], key).filter (.nTarget[TARGET_ID.shuntsu] == 0)
]

# produce decomp from 4*decomp1 (which in turn come from each bin/suite)
# NOTE: need to provide corresponding suite numbers (see `decompTenpai`)
function stitch(decomp1s, suites)
  ret =
    mentsu: []
    jantou: null
    wait: null
    k7: null
  for {placements}, i in decomp1s
    suite = suites[i]
    for placement in placements
      {patternId, offset} = restorePlacement placement
      {name, target} = patterns[patternId]
      switch target
        when \shuntsu, \koutsu
          ret.mentsu.push {
            type: name # NOTE: see above
            pai: Pai[offset+1][suite]
          }
        when \jantou
          ret.jantou = Pai[offset+1][suite]
  ret


# tenpai/agari full hand decomposition
# NOTE: (3*n+1) and (3*n+2) tenpai calculations are relevent in different
# contexts and therefore have different semantics

# (3*n+2): tenpai after dahai {discard}
# return: dict of: discarded pai => (3*n+1) tenpai result
export function decompDahaiTenpai(bins)
  ret = {}

  # check which bin/suite cannot be decomposed without dahai:
  # - 0: dahai can come from any suite
  # - 1: dahai can only come from this suite
  # - else: no solution
  CC = decomp1sFromBins(bins, \complete)
  WW = decomp1sFromBins(bins, \waiting)
  sDahai = null
  for s til 4
    if !CC[s].length && !WW[s].length
      if sDahai? then return ret
      sDahai = s
  if sDahai? then enumDahaiIn sDahai
  else for s til 4 => enumDahaiIn s

  function enumDahaiIn s
    bin = bins[s]
    for i til N
      if bin[i]
        bin[i]--
        dt = decompTenpai(bins)
        if dt.wait.length
          ret[(i+1) + Pai.SUITES[s]] = dt
        bin[i]++
  return ret

# (3*n+1): tenpai
#   decomps: array of decomp
#   wait: array of Pai (= union of decomps[i].wait)
export function decompTenpai(bins)
  # kokushi: exclusive
  if (w = tenpaiK bins)
    return {
      decomps: [{mentsu: [], jantou: null, k7: \kokushi, wait: w}]
      wait: w
    }

  # standard form
  ret = {
    decomps: []
    wait: []
  }
  CC = decomp1sFromBins(bins, \complete)
  WW = decomp1sFromBins(bins, \waiting)

  # 1 suite waiting + 3 suites complete: enumerate which suite is waiting
  f(0, 1, 2, 3)
  f(1, 0, 2, 3)
  f(2, 0, 1, 3)
  f(3, 0, 1, 2)
  !function f(iw, ic0, ic1, ic2)
    d1sW  = WW[iw]  ; if !d1sW.length  then return
    d1sC0 = CC[ic0] ; if !d1sC0.length then return
    d1sC1 = CC[ic1] ; if !d1sC1.length then return
    d1sC2 = CC[ic2] ; if !d1sC2.length then return
    rem = [CAP_MENTSU, CAP_JANTOU]

    convert = Pai.arrayFromBitmapSuite # shorthand
    waitSuite = 0

    # cartesian product of decompositions from each bin
    for d1W in d1sW
      waitOne = waitBitmapFromDecomp1(bins[iw], d1W)
      subRem(rem, d1W)
      for d1C0 in d1sC0
        if subRem(rem, d1C0)
          for d1C1 in d1sC1
            if subRem(rem, d1C1)
              for d1C2 in d1sC2
                if subRem(rem, d1C2)
                  decomp = stitch [d1W, d1C0, d1C1, d1C2], [iw, ic0, ic1, ic2]
                  decomp.wait = convert(waitOne, iw)
                  ret.decomps.push decomp
                  waitSuite .|.= waitOne
                  # NOTE: this cannot be moved to outer loop because we need
                  # to verify that this decomp is valid
                addRem(rem, d1C2)
            addRem(rem, d1C1)
        addRem(rem, d1C0)
      addRem(rem, d1W)
    [].push.apply ret.wait, convert(waitSuite, iw)

  # chiitoi: might also be ryanpeikou
  # NOTE: 1 wait (tanki) by definition (see `tenpai7`)
  if (w = tenpai7 bins)
    ret.decomps.push {mentsu: [], jantou: null, k7: \chiitoi, wait: w}
    if -1 == ret.wait.indexOf w.0 then ret.wait.push w.0

  ret

# (3*n+2): agari
# array of decomp
# NOTE: mostly parallel code of `decompTenpai` (3*n+1) but even simpler as we
# don't have to enumerate the waiting suite
export function decompAgari(bins)
  # kokushi: exclusive
  if agariK bins
    return [{mentsu: [], jantou: null, k7: \kokushi, wait: null}]

  ret = []
  CC = decomp1sFromBins(bins, \complete)
  d1sC0 = CC[0] ; if !d1sC0.length then return ret
  d1sC1 = CC[1] ; if !d1sC1.length then return ret
  d1sC2 = CC[2] ; if !d1sC2.length then return ret
  d1sC3 = CC[3] ; if !d1sC3.length then return ret
  rem = [CAP_MENTSU, CAP_JANTOU]
  for d1C0 in d1sC0
    subRem(rem, d1C0)
    for d1C1 in d1sC1
      if subRem(rem, d1C1)
        for d1C2 in d1sC2
          if subRem(rem, d1C2)
            for d1C3 in d1sC3
              if subRem(rem, d1C3)
                decomp = stitch [d1C0, d1C1, d1C2, d1C3], [0, 1, 2, 3]
                ret.push decomp
              addRem(rem, d1C3)
          addRem(rem, d1C2)
      addRem(rem, d1C1)
    addRem(rem, d1C0)

  # chiitoi
  if agari7 bins
    ret.push {mentsu: [], jantou: null, k7: \chiitoi, wait: null}

  ret

# decompTenpai + agariPai + isRon => both tenpai and agari info
# each `decomp` has its `.wait` field changed to "type of wait":
#   \kokushi  => \kokushi or \kokushi13
#   \chiitoi
#   \tanki
#   \toitsu   => \shanpon (only 1 of the pair of decomps will remain)
#   \kanchan
#   \ryanmen  => \ryanmen or \penchan (e.g. 12/89 => penchan)
# each `decomp.mentsu` has its `.name` changed to "final form":
#   \shuntsu            => \shuntsu
#   \koutsu             => \anko
#   \toitsu             => \minko (ron) or \anko (tsumo)
#   \kanchan, \ryanmen  => \shuntsu
#
# NOTE: after \ryanmen is changed to \shuntsu, its `.pai` might need fixing
# (e.g. 34m ryanmen => pai = 3m ; +2m => 234m shuntsu => pai = 2m)
export function decompAgariFromTenpai({decomps}, agariPai, isRon)
  ret = []
  for decomp in clone decomps
    if agariPai not in decomp.wait then continue
    ret.push decomp
    switch decomp.k7
    | \kokushi =>
      if decomp.wait.length == 1
        wait = \kokushi
      else
        wait = \kokushi13
    | \chiitoi => wait = \chiitoi
    | _ => # standard form

      wait = \tanki # default when all 4 mentsu are complete
      for m in decomp.mentsu => switch m.type
      | \shuntsu => void
      | \koutsu  => m.type = \anko
      | \toitsu  =>
        wait = \shanpon
        if m.pai == agariPai and isRon
          m.type = \minko
        else
          m.type = \anko
      | \kanchan =>
        wait = \kanchan
        m.type = \shuntsu
      | \ryanmen =>
        if m.pai.number in [1 8]
          wait = \penchan
        else
          wait = \ryanmen
          if agariPai.succ == m.pai then m.pai = agariPai
        m.type = \shuntsu
      | _ => throw Error "unknown type"
    decomp.wait = wait
  ret


# kokushi-musou {13 orphans} and chiitoitsu {7 pairs} details
# shorthand: `k`, `7`, `k7` (in contrast with `std` for standard form)

# kokushi tenpai: either
# - [19m19p19s1234567z] => 13-wait
# - replacing one from above with another => 1-wait (the replaced)
function tenpaiK(bins)
  yaochuu = Pai.yaochuuFromBins bins
  c0 = c1 = c2 = 0
  i0 = -1
  for x, i in yaochuu => switch x
  | 0 =>
    if ++c0 > 1 then return null
    i0 = i
  | 1 => ++c1
  | 2 =>
    if ++c2 > 1 then return null
  | 3, 4 => return null
  if c1 == 13
    return Pai.YAOCHUU
  if c0 == 1 and c1 == 11 and c2 == 1
    return [Pai.YAOCHUU[i0]]
  return null

# kokushi agari: [19m19p19s1234567z] + one more
function agariK(bins)
  yaochuu = Pai.yaochuuFromBins bins
  c1 = c2 = 0
  for x, i in yaochuu => switch x
  | 1 => ++c1
  | 2 =>
    if ++c2 > 1 then return null
  | 3, 4 => return null
  return c1 == 12 and c2 == 1

# chiitoi tenpai: 6 toitsu + 1 tanki
function tenpai7(bins)
  c1 = c2 = 0
  p1 = -1
  for s til 4 => for n til 9 => switch bins[s][n]
  | 0 => void
  | 1 =>
    if ++c1 > 1 then return null
    p1 = Pai[n+1][s]
  | 2 => ++c2
  | _ => return null
  if c1 == 1 and c2 == 6 then return [p1]
  return null

# chiitoi agari: 7 toitsu (duh)
function agari7(bins)
  c2 = 0
  for s til 4 => for n til 9 => switch bins[s][n]
  | 0 => void
  | 2 => ++c2
  | _ => return false
  return c2 == 7


# small tests
if require.main == module
  # bins = Pai.binsFromString '5666777788m'
  # bins = Pai.binsFromString '3456789m1234p11s1s'

  debugger
  console.time 'precompute'
  makeDecomp1Lookup!
  console.timeEnd 'precompute'

  tenpaiBins = <[
    22234567p44s
    1112345678999p
    1122334455667s
    113355m224466p1z
    19m19p19s1234567z
    19m19p19s1234457z
    19m19p19s1234466z
  ]>.map Pai.binsFromString
  dahaiTenpaiBins = <[
    123m067p2366778s6s
  ]>.map Pai.binsFromString
  agariBins = <[
    11122345678999p
  ]>.map Pai.binsFromString

  iters = 10
  #iters = 1
  clock = process?.hrtime!
  for i til iters
    tenpai = tenpaiBins.map decompTenpai
    dahaiTenpai = dahaiTenpaiBins.map decompDahaiTenpai
    agari = agariBins.map decompAgari
  clock = process?.hrtime clock

  len = tenpaiBins.length + dahaiTenpaiBins.length + agariBins.length
  clock = clock[1] / len / iters / 1e6 # in ms
  console.log clock

  print = -> console.log JSON.stringify(it, 0, 2)
  #print = -> console.log JSON.stringify it
  print tenpai
  print dahaiTenpai
  print agari

