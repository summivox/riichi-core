# tenpai/agari standard form decomposition
# NOTE: bin(s) format is expected (see `./pai.coffee`)

_ = require 'lodash'

Pai = require './pai.js'


# magic numbers:
#   number range: [0, N)
#   max # of single pai in game: M
#   max # of pai in juntehai: K
N = 9
M = 4
K = 14



# -------------------------
# pattern:
# * kernel[i] placed at bin[offset+i], nPai = sum(kernel)
# * either:
#   * complete (wait == null, `target == name`)
#   * waits for valid pai `offset+wait[i]` to become `target`
# * waitAbs[offset]: precomputed array of all valid `offset+wait[i]`
patterns = [
  # complete mentsu/jantou : no wait
  { name: 'shuntsu', target: 'shuntsu', kernel: [1, 1, 1], wait: null }
  { name: 'koutsu' , target: 'koutsu' , kernel: [3]      , wait: null }
  { name: 'jantou' , target: 'jantou' , kernel: [2]      , wait: null }
  # incomplete mentsu/jantou : 1/2 wait(s)
  # NOTE: 'ryanmen' could actually become 'penchan' depending on position
  { name: 'tanki'  , target: 'jantou' , kernel: [1]      , wait: [0] }
  { name: 'toitsu' , target: 'koutsu' , kernel: [2]      , wait: [0] }
  { name: 'kanchan', target: 'shuntsu', kernel: [1, 0, 1], wait: [1] }
  { name: 'ryanmen', target: 'shuntsu', kernel: [1, 1]   , wait: [-1, 2] }
]
nPatterns = patterns.length

do ->
  for pattern, id in patterns
    pattern.id = id
    pattern.nPai = _.sum pattern.kernel
    if wait = pattern.wait
      pattern.waitAbs = waitAbs = new Array N
      for offset in [0...N]
        a = (abs for rel in wait when 0 <= (abs = offset + rel) < N)
        waitAbs[offset] = a
  return

# handling of pattern caps:
#   shuntsu + koutsu = mentsu <= 4
#   jantou <= 1
TARGET     = { shuntsu: 0, koutsu : 1, jantou : 2 } # id
CAP_MENTSU = 4
CAP_JANTOU = 1



# -------------------------
# precompute all complete/waiting single-suite juntehai configurations and all
# possible ways to decompose them into patterns
#
# decomp1Lookup[compactBin bin]:
#   complete, waiting: array of decomp1
# decomp1:
#   nTarget: # of [shuntsu, koutsu, jantou], both complete and incomplete
#   placements: array of compacted placements `{patternId, offset}`
#
# NOTE:
# * placements are sorted by patternId then offset (compacted: numerical order)
# * as a result, incomplete patterns (if any) must be at the end of `placements`
decomp1Lookup = {}


# compact bins and placements into atoms (number/string)

compactBin = (bin) ->
  bin.join('') # keep leading zero for easy lookup
restoreBin = (bs) ->
  (Number x for x in bs)

compactPlacement = (patternId, offset) ->
  patternId*10 + offset
restorePlacement = (ps) ->
  {patternId: ps//10, offset: ps%10}


# get entry / create empty entry in decomp1Lookup
# key: 'complete'/'waiting'
decomp1LookupEntry = (bin, key) ->
  decomp1Lookup[compactBin bin]?[key] ? [] # NOTE: significant whitespace
ensureDecomp1LookupEntry = (bin, key) ->
  (decomp1Lookup[compactBin bin] ||= {})[key] ||= []


# precompute decomp1Lookup
# NOTE: time-consuming process due to # of total conf's
makeDecomp1Lookup = ->

  # state: current search node
  #   nPai = # of all pai (implicit in decomp1 object)
  state = {
    bin: (0 for i in [0...N])
    nPai: 0
    nTarget: [0, 0, 0]
    placements: []

    remaining: (pattern) ->
      if pattern.target == 'jantou'
        CAP_JANTOU - @nTarget[2]
      else
        CAP_MENTSU - @nTarget[0] - @nTarget[1]
    toDecomp1: -> {
      nTarget: @nTarget.slice()
      placements: @placements.slice()
    }
  }

  # try place given pattern at offset
  # return: if successfully placed
  tryPlace = (pattern, offset) ->
    {id, target, kernel, nPai} = pattern

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
    state.nTarget[TARGET[target]]++
    for x, rel in kernel
      state.bin[offset + rel] += x
    state.placements.push(compactPlacement(id, offset))
    return true

  # undo most recent placement (repeated n times)
  unPlace = (pattern, offset, n) ->
    if !n then return
    {target, kernel, nPai} = pattern

    state.nPai -= nPai*n
    state.nTarget[TARGET[target]] -= n
    for x, rel in kernel
      state.bin[offset + rel] -= x*n
    state.placements.splice(-n, n)
    return

  # check for invalid case of pure void wait (juntehai karaten)
  isKaraten = (pattern, offset) ->
    {machiAbs} = pattern
    if !machiAbs? then return false
    return false for m in machiAbs[offset] when state.bin[m] < M
    return true

  # nested DFS: avoid searching the same configuration twice
  dfsPattern = (minPatternId) ->
    if state.nPai >= K then return
    for patternId in [minPatternId...nPatterns] by 1
      pattern = patterns[patternId]
      remaining = state.remaining(pattern)
      if remaining
        dfsOffset(patternId, 0, remaining)
    return
  dfsOffset = (patternId, minOffset, remaining) ->
    if minOffset >= N then return
    {wait} = pattern = patterns[patternId]
    for offset in [minOffset...N] by 1
      n = 0 # total # of patterns placed at this location
      while n < remaining && tryPlace(pattern, offset)
        n++
        decomp1 = state.toDecomp1()
        if wait
          if !isKaraten(pattern, offset)
            ensureDecomp1LookupEntry(state.bin, 'waiting').push(decomp1)
            break # only 1 incomplete pattern can be placed in total
        else
          ensureDecomp1LookupEntry(state.bin, 'complete').push(decomp1)
          if remaining - n > 0
            dfsOffset(patternId, offset+1, remaining - n)
          dfsPattern(patternId+1)
      unPlace(pattern, offset, n)
    return

  # "zero" decomposition
  ensureDecomp1LookupEntry(state.bin, 'complete').push(state.toDecomp1())
  # launch search
  dfsPattern(0)
  return makeDecomp1Lookup

# prints decomp1Lookup (compact)
# NOTE: very large output; try redirect stdout to file
printDecomp1Lookup = ->
  console.time 'print'
  for bin, {complete, waiting} of decomp1Lookup
    if complete?.length
      cs = ' C' + JSON.stringify complete
    else cs = ''
    if waiting?.length
      ws = ' W' + JSON.stringify waiting
    else ws = ''
    console.log "#{bin}:#{cs}#{ws}"
  console.timeEnd 'print'

console.time 'makeDecomp1Lookup'
do makeDecomp1Lookup # TODO: run in background
console.timeEnd 'makeDecomp1Lookup'



# -------------------------
# decompose complete juntehai (4 bins, all suites) for tenpai/agari
#
# decomp:
#   mentsu: array of:
#     type: (see pattern.name)
#     pai: Pai (pattern origin)
#   jantou: null or Pai
#   wait: null or array of Pai
#
# NOTE:
# * `decomp` refers to the whole hand
#   `decomp1` only refers to one suite
#
# * `mentsu.type` => `pattern.name` instead of `pattern.target` so that
#   incomplete patterns can be identified


# helper functions

# find wait in one particular decomp1 of a bin (bitmap format)
# NOTE: wait can only be at the end of placements, see above
waitBitmapFromDecomp1 = (bin, decomp1) ->
  ret = 0
  placements = decomp1.placements
  placement = placements[placements.length-1]
  {patternId, offset} = restorePlacement placement
  {waitAbs} = patterns[patternId]
  if waitAbs
    for w in waitAbs[offset]
      if bin[w] < M
        ret |= 1<<w
  ret

# plus/minus decomp1.nTarget from rem ([CAP_MENTSU, CAP_JANTOU])
# return false if cap goes negative
addRem = (rem, decomp1, sign) ->
  {nTarget, placements} = decomp1
  if !placements.length then return true
  rem[0] += sign * (nTarget[0] + nTarget[1])
  rem[1] += sign * nTarget[2]
  return rem[0] >= 0 && rem[1] >= 0

# decomp1 for each bin
decomp1sFromBins = (bins, key) ->
  [
    decomp1LookupEntry(bins[0], key)
    decomp1LookupEntry(bins[1], key)
    decomp1LookupEntry(bins[2], key)
    decomp1LookupEntry(bins[3], key)
      .filter (decomp1) -> decomp1.nTarget[TARGET['shuntsu']] == 0
  ]

# produce decomp from 4*decomp1 (which in turn come from each bin/suite)
# NOTE: need to provide corresponding suite numbers (see `decompTenpai`)
stitch = (decomp1s, suites) ->
  ret =
    mentsu: []
    jantou: null
    wait: null
  for placements, i in _.pluck decomp1s, 'placements'
    suite = suites[i]
    for placement in placements
      {patternId, offset} = restorePlacement placement
      {name, target} = patterns[patternId]
      switch target
        when 'shuntsu', 'koutsu'
          ret.mentsu.push {
            type: name # NOTE: see above
            pai: Pai[offset+1][suite]
          }
        when 'jantou'
          ret.jantou = Pai[offset+1][suite]
  ret


# tenpai/agari full hand decomposition
# NOTE: (3*n+1) and (3*n+2) tenpai calculations are relevent in different
# contexts and therefore have different semantics

# (3*n+2): tenpai after discard
# return: dict of: paiStr => (3*n+1) tenpai result after discarding paiStr
decompDiscardTenpai = (bins) ->
  ret = {}
  for bin, s in bins
    for n, i in bin
      if n
        bin[i]--
        {wait} = tenpai = decompTenpai(bins)
        if wait.length
          ret[i + Pai.SUITES[s]] = tenpai
        bin[i]++
  return ret

# (3*n+1): tenpai
# return:
#   decomps: array of decomp
#   wait: array of Pai (= union of decomps[i].wait)
decompTenpai = (bins) ->
  ret = {
    decomps: []
    wait: []
  }
  CC = decomp1sFromBins(bins, 'complete')
  WW = decomp1sFromBins(bins, 'waiting')

  # 1 suite waiting + 3 suites complete
  f = (iw, ic0, ic1, ic2) ->
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
      addRem(rem, d1W, -1)
      for d1C0 in d1sC0
        if addRem(rem, d1C0, -1)
          for d1C1 in d1sC1
            if addRem(rem, d1C1, -1)
              for d1C2 in d1sC2
                if addRem(rem, d1C2, -1)
                  decomp = stitch [d1W, d1C0, d1C1, d1C2], [iw, ic0, ic1, ic2]
                  decomp.wait = convert(waitOne, iw)
                  ret.decomps.push decomp
                  waitSuite |= waitOne
                  # NOTE: this cannot be moved to outer loop because we need
                  # to verify that this decomp is valid
                addRem(rem, d1C2, +1)
            addRem(rem, d1C1, +1)
        addRem(rem, d1C0, +1)
      addRem(rem, d1W, +1)
    [].push.apply ret.wait, convert(waitSuite, iw)
    return
  # enumerate which suite is waiting
  f(0, 1, 2, 3)
  f(1, 0, 2, 3)
  f(2, 0, 1, 3)
  f(3, 0, 1, 2)
  ret

# (3*n+2): agari
# return: array of decomp
# NOTE: mostly parallel code of `decompTenpai` (3*n+1) as we don't have to
# enumerate the waiting suite
decompAgari = (bins) ->
  ret = []
  CC = decomp1sFromBins(bins, 'complete')
  d1sC0 = CC[0] ; if !d1sC0.length then return ret
  d1sC1 = CC[1] ; if !d1sC1.length then return ret
  d1sC2 = CC[2] ; if !d1sC2.length then return ret
  d1sC3 = CC[3] ; if !d1sC3.length then return ret
  rem = [CAP_MENTSU, CAP_JANTOU]
  for d1C0 in d1sC0
    addRem(rem, d1C0, -1)
    for d1C1 in d1sC1
      if addRem(rem, d1C1, -1)
        for d1C2 in d1sC2
          if addRem(rem, d1C2, -1)
            for d1C3 in d1sC3
              if addRem(rem, d1C3, -1)
                decomp = stitch [d1C0, d1C1, d1C2, d1C3], [0, 1, 2, 3]
                ret.push decomp
              addRem(rem, d1C3, +1)
          addRem(rem, d1C2, +1)
      addRem(rem, d1C1, +1)
    addRem(rem, d1C0, +1)
  ret


# small tests
do ->
  # bins = Pai.binsFromString '5666777788m'
  # bins = Pai.binsFromString '3456789m1234p11s1s'

  console.time 'decompTenpai'

  bins = Pai.binsFromString '22234567p44s'
  tenpai = decompTenpai(bins)

  bins = Pai.binsFromString '123m067p2366778s6s'
  discardTenpai = decompDiscardTenpai(bins)

  bins = Pai.binsFromString '1112345678999p'
  tenpai9 = decompTenpai(bins)

  bins = Pai.binsFromString '11122345678999p'
  agari9 = decompAgari(bins)

  console.timeEnd 'decompTenpai'

  print = (x) -> console.log JSON.stringify(x, 0, 2)
  print tenpai
  print discardTenpai
  print tenpai9
  print agari9


# exposes

module.exports = {
  decomp1Lookup
  decompDiscardTenpai
  decompTenpai
  decompAgari
}
