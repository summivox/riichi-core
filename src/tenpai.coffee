# tenpai/agari standard form decomposition
# NOTE: bin(s) format is expected (see `./pai.coffee`)

_ = require 'lodash'


# -------------------------
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
# * waitBitmap[offset]: bitmap of `waitAbs[offset]`
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

# preprocessed wait fields
do ->
  wait2bitmap = (wait, offset) ->
    t = 0
    t |= 1<<m for m in wait
    t
  for pattern in patterns
    wait = pattern.wait
    if wait
      pattern.waitAbs = waitAbs = new Array N
      pattern.waitBitmap = waitBitmap = new Array N
      for offset in [0...N]
        a = (abs for rel in wait when 0 <= (abs = offset + rel) < N)
        waitAbs[offset] = a
        waitBitmap[offset] = wait2bitmap a
    else
      pattern.waitBitmap = (0 for i in [0...N])

# handling of pattern caps:
#   shuntsu + koutsu = mentsu <= 4
#   jantou <= 1
TARGET     = { shuntsu: 0, koutsu : 1, jantou : 2 }
TARGET_CAP = { shuntsu: 0, koutsu : 0, jantou : 1 }
CAP_TARGET = [[0, 1], [2]]
CAP = [4, 1]


# -------------------------
# generate all possible tenpai & agari configurations for single-suite juntehai

# binDecomp[compactBin bin]:
#   complete, waiting: array of decomp
# decomp:
#   [0] (nTarget): # of [shuntsu, koutsu, jantou], both complete and incomplete
#   [1] (placements): array of compacted placements `{patternId, offset}`
binDecomp = {}

# compact bins and placements into atoms (number/string)

compactBin = (bin) ->
  bin.join('') # keep leading zero for easy lookup
restoreBin = (bs) ->
  (Number x for x in bs)

compactPlacement = (patternId, offset) ->
  patternId*10 + offset
restorePlacement = (ps) ->
  {patternId: ps//10, offset: ps%10}

# creates and returns empty entry in binDecomp
ensureBinDecomp = (bin, key) ->
  (binDecomp[compactBin bin] ||= {})[key] ||= []

# exhaustive search
# NOTE: time-consuming process due to # of total conf's
makeBinDecomp = ->

  # state: current search node
  #   nPai = # of all pai (implicit in decomp object)
  state = {
    bin: (0 for i in [0...N])
    nPai: 0
    nTarget: [0, 0, 0]
    placements: []

    remaining: (pattern) ->
      c = TARGET_CAP[pattern.target]
      s = CAP[c]
      s -= @nTarget[t] for t in CAP_TARGET[c]
      s
    toDecomp: -> [
      @nTarget.slice()
      @placements.slice()
    ]
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
        decomp = state.toDecomp()
        if wait
          if !isKaraten(pattern, offset)
            ensureBinDecomp(state.bin, 'waiting').push(decomp)
            break # only 1 incomplete pattern can be placed in total
        else
          ensureBinDecomp(state.bin, 'complete').push(decomp)
          if remaining - n > 0
            dfsOffset(patternId, offset+1, remaining - n)
          dfsPattern(patternId+1)
      unPlace(pattern, offset, n)
    return

  dfsPattern(0)
  return binDecomp

# TODO: run in background
debugger
console.time 'makeBinDecomp'
makeBinDecomp()
console.timeEnd 'makeBinDecomp'

if 1
  console.time 'print'
  for bin, {complete, waiting} of binDecomp
    if complete?.length
      cs = ' C' + JSON.stringify complete
    else cs = ''
    if waiting?.length
      ws = ' W' + JSON.stringify waiting
    else ws = ''
    console.log "#{bin}:#{cs}#{ws}"
  console.timeEnd 'print'


# -------------------------
# decomposition of full juntehai in bins format

decompBinsTenpai = (bins) ->
  ns = (_.sum(bin) for bin in bins)
  n = _.sum(ns) #
  switch n%3
    when 1
      # check for tenpai
      return _decompBinsTenpai bins
    when 2
      # enumerate discard then check for tenpai
      ret = {
        tenpai: []
        decomps: []
      }
      for bin in bins
        for n, i in bin
          if n
            bin[i]--
            {tenpai, decomps} = _decompBinsTenpai(bins)
            ret.tenpai = _.union(ret.tenpai, tenpai)
            [].push.apply ret.decomps, decomps
            bin[i]++
      return ret
    else #0
      # cannot possibly be tenpai
      return {
        tenpai: []
        decomps: []
      }

OTHERS = [
  [1, 2, 3]
  [0, 2, 3]
  [0, 1, 3]
  [0, 1, 2]
]


# TODO

_getBinsDecomp = (bins) ->
  decompRaw = new Array 4
  for bin, i in bins
    b = binDecomp[compactBin bin]
    if i == 3
      # filter out any decomp with shuntsu
      # for decomp in b[0][1]
      null

    decompRaw[i] = b

_decompBinsTenpai = (bins) ->

  # general idea: 1 bin => tenpai, other bins => complete, nTargets add up
  for b0, i0 in bins
    # check if this bin can provide tenpai
    if !decompRaw[i0][1][0] then continue

    # load index of other bins
    [i1, i2, i3] = OTHERS[i0]
    [b1, b2, b3] = [bins[o1], bins[o2], bins[o3]]
    [d0, d1, d2, d3] = [
      decompRaw[d0][1]
      decompRaw[d1][0]
      decompRaw[d2][0]
      decompRaw[d3][0]
    ]
