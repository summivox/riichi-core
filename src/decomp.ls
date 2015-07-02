# tenpai/agari standard form decomposition
# NOTE: bin(s) format is expected (see `./pai.coffee`)

Pai = require './pai.js'

# because I don't want to require lodash
function sum arr
  s = 0
  for x in arr => s += x
  s


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
const N_MASK = ``(1<<N_LOG2) - 1``
const M_LOG2 = Math.ceil Math.log2 M
const M_MASK = ``(1<<M_LOG2) - 1``


# -------------------------
# pattern:
# * kernel[i] placed at bin[offset+i], nPai = sum(kernel)
# * either:
#   * complete (wait == null, `target == name`)
#   * waits for valid pai `offset+wait[i]` to become `target`
# * waitAbs[offset]: precomputed array of all valid `offset+wait[i]`
patterns =
  # complete mentsu/jantou : no wait
  * name: 'shuntsu' target: 'shuntsu' kernel: [1 1 1] wait: null
  * name: 'koutsu'  target: 'koutsu'  kernel: [3]     wait: null
  * name: 'jantou'  target: 'jantou'  kernel: [2]     wait: null
  # incomplete mentsu/jantou : 1/2 wait(s)
  # NOTE: 'ryanmen' could actually become 'penchan' depending on position
  * name: 'tanki'   target: 'jantou'  kernel: [1]     wait: [0]
  * name: 'toitsu'  target: 'koutsu'  kernel: [2]     wait: [0]
  * name: 'kanchan' target: 'shuntsu' kernel: [1 0 1] wait: [1]
  * name: 'ryanmen' target: 'shuntsu' kernel: [1 1]   wait: [-1 2]
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
# * `1` in `decomp1` stands for "1-suite"
# * placements are sorted by patternId then offset (compacted: numerical order)
# * as a result, incomplete patterns (if any) must be at the end of `placements`
decomp1Lookup = []


# compact bins and placements into integers (packed bitfields)

compactBin = ->
  s = 0
  for x til N
    s = (s .<<. M_LOG2) .|. it[x]
  s
# NOTE: the following can be used to produce a more human-readable key
# compactBin = -> Number it.join ''

compactPlacement = (patternId, offset) ->
  (patternId .<<. N_LOG2) + offset
restorePlacement = ->
  patternId: it .>>. N_LOG2
  offset:    it .&.  N_MASK


# get entry / create empty entry in decomp1Lookup
# key: 'complete'/'waiting'
#
# NOTE:
# * cannot be trivially written even in livescript
# * whitespaces are significant
decomp1LookupEntry = (bin, key) ->
  decomp1Lookup[compactBin bin]?[key] ? []
ensureDecomp1LookupEntry = (bin, key) ->
  (decomp1Lookup[compactBin bin] ||= {})[key] ||= []

# precompute the lookup table by searching
makeDecomp1Lookup = ->

  # state: current search node
  #   nPai = # of all pai (implicit in decomp1 object)
  state = {
    bin: [0] * N
    nPai: 0
    nTarget: [0] * TARGET_N
    placements: []

    remaining: (pattern) ->
      if pattern.target == 'jantou'
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
  tryPlace = (pattern, offset) ->
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
  unPlace = (pattern, offset, n) !->
    if !n then return
    {targetId, kernel, nPai} = pattern

    state.nPai -= nPai*n
    state.nTarget[targetId] -= n
    for x, rel in kernel
      state.bin[offset + rel] -= x*n
    state.placements.splice(-n, n) # equivalent to `.pop!` n times

  # check for invalid case of pure void wait (juntehai karaten)
  isKaraten = (pattern, offset) ->
    {machiAbs} = pattern
    if !machiAbs? then return false
    for m in machiAbs[offset]
      if state.bin[m] < M
        return false
    return true

  # nested DFS: avoid searching the same configuration twice
  dfsPattern = (minPatternId) !->
    if state.nPai >= K then return
    for patternId from minPatternId til nPatterns
      pattern = patterns[patternId]
      remaining = state.remaining(pattern)
      if remaining
        dfsOffset(patternId, 0, remaining)
  dfsOffset = (patternId, minOffset, remaining) !->
    if minOffset >= N then return
    {wait} = pattern = patterns[patternId]
    for offset from minOffset til N
      n = 0 # total # of patterns placed at this location
      while n < remaining && tryPlace(pattern, offset)
        n++
        decomp1 = state.toDecomp1!
        if wait
          if !isKaraten(pattern, offset)
            ensureDecomp1LookupEntry(state.bin, 'waiting').push(decomp1)
            break # only 1 waiting pattern can be placed in total
        else
          ensureDecomp1LookupEntry(state.bin, 'complete').push(decomp1)
          if remaining - n > 0
            dfsOffset(patternId, offset+1, remaining - n)
          dfsPattern(patternId+1)
      unPlace(pattern, offset, n)

  # "zero" decomposition
  ensureDecomp1LookupEntry(state.bin, 'complete').push(state.toDecomp1!)
  # launch search
  dfsPattern(0)
  return makeDecomp1Lookup

# prints decomp1Lookup
# NOTE: very large output; try redirect stdout to file
printDecomp1Lookup = !->
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
        ret .|.= 1 .<<. w
  ret

# subtract mentsu/jantou count of decomp1 from remaining
# return false if cap goes negative
subRem = (rem, decomp1) ->
  if !decomp1.placements.length then return true
  {nTarget: [shuntsu, koutsu, jantou]} = decomp1
  rem[0] -= shuntsu + koutsu
  rem[1] -= jantou
  return rem[0] >= 0 && rem[1] >= 0
# same as above, but add it back
addRem = (rem, decomp1) !->
  if !decomp1.placements.length then return true
  {nTarget: [shuntsu, koutsu, jantou]} = decomp1
  rem[0] += shuntsu + koutsu
  rem[1] += jantou

# decomp1 for each bin
decomp1sFromBins = (bins, key) -> [
  decomp1LookupEntry(bins[0], key)
  decomp1LookupEntry(bins[1], key)
  decomp1LookupEntry(bins[2], key)
  decomp1LookupEntry(bins[3], key).filter (.nTarget[TARGET_ID.shuntsu] == 0)
]

# produce decomp from 4*decomp1 (which in turn come from each bin/suite)
# NOTE: need to provide corresponding suite numbers (see `decompTenpai`)
stitch = (decomp1s, suites) ->
  ret =
    mentsu: []
    jantou: null
    wait: null
  for {placements}, i in decomp1s
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

  # check which bin/suite cannot be decomposed without discarding:
  # * 0: discard can come from any suite
  # * 1: discard can only come from this suite
  # * else: no solution
  CC = decomp1sFromBins(bins, 'complete')
  WW = decomp1sFromBins(bins, 'waiting')
  sDiscard = null
  for s til 4
    if !CC[s].length && !WW[s].length
      if sDiscard? then return ret
      sDiscard = s
  if sDiscard? then enumDiscardIn sDiscard
  else for s til 4 => enumDiscardIn s

  function enumDiscardIn s
    bin = bins[s]
    for i til N
      if bin[i]
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
    # ret.wait ++= convert(waitSuite, iw)
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
  ret


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
  ]>.map Pai.binsFromString
  discardTenpaiBins = <[
    123m067p2366778s6s
  ]>.map Pai.binsFromString
  agariBins = <[
    11122345678999p
  ]>.map Pai.binsFromString
  
  iters = 10
  clock = process?.hrtime!
  for i til iters
    tenpai = tenpaiBins.map decompTenpai
    discardTenpai = discardTenpaiBins.map decompDiscardTenpai
    agari = agariBins.map decompAgari
  clock = process?.hrtime clock

  len = tenpaiBins.length + discardTenpaiBins.length + agariBins.length
  clock = clock[1] / len / iters / 1e6 # in ms
  console.log clock

  print = (x) -> console.log JSON.stringify(x, 0, 2)
  print tenpai
  print discardTenpai
  print agari



export
  init: makeDecomp1Lookup
  # decomp1Lookup
  decompDiscardTenpai
  decompTenpai
  decompAgari
