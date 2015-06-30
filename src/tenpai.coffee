# tenpai/agari standard form decomposition
# conventions:
#   number range: [0, N)
#   max # of single pai: M
#   max # of all pai: K
N = 9
M = 4
K = 14

# cap: maximum # of patterns:
#   shuntsu + koutsu = mentsu <= 4
#   jantou <= 1
#   machi <= 1
# shared cap implemented as 1-elem array
cap = {
  mentsu: [4]
  jantou: [1]
  machi : [1]
}

# pattern fields:
#   'as':
#     complete: same as 'name'
#     incomplete: 'name' of the pattern it eventually completes
#   'rem': pattern cap groups it belongs to
#   'kernel': layout of pai
#   'nPai': total # of pai (= sum of 'kernel')
#   'machi[offset]': array of machi pai candidates

# helper: pre-process machi from relative indices
prepMachi = (machi) ->
  ret = new Array N
  for offset in [0...N]
    ret[offset] = (abs for rel in machi when 0 <= (abs = offset + rel) < N)

patterns = [
  # complete mentsu/jantou : no machi
  { #0
    name: 'shuntsu', as: 'shuntsu', rem: [cap.mentsu]
    kernel: [1, 1, 1], nPai: 3, machi: null
  }
  { #1
    name: 'koutsu', as: 'koutsu', rem: [cap.mentsu]
    kernel: [3], nPai: 3, machi: null
  }
  { #2
    name: 'jantou', as: 'jantou', rem: [cap.jantou]
    kernel: [2], nPai: 2, machi: null
  }
  # incomplete mentsu/jantou : 1/2 machi
  { #3
    name: 'tanki', as: 'jantou', rem: [cap.jantou, cap.machi]
    kernel: [1], nPai: 1, machi: prepMachi [0]
  }
  { #4
    name: 'toitsu', as: 'koutsu', rem: [cap.mentsu, cap.machi]
    kernel: [2], nPai: 2, machi: prepMachi [0]
  }
  { #5
    name: 'kanchan', as: 'shuntsu', rem: [cap.mentsu, cap.machi]
    kernel: [1, 0, 1], nPai: 2, machi: prepMachi [1]
  }
  { #6 (NOTE: both ryanman & penchan)
    name: 'ryanmen', as: 'shuntsu', rem: [cap.mentsu, cap.machi]
    kernel: [1, 1], nPai: 2, machi: prepMachi [-1, 2]
  }
]

# exhaustively search for all valid partial/full junteihai configurations
# (represented as "bins" -- histogram of pai) that are either complete (3*n)
# or tenpai (3*n+1, 3*n+2)
getBinDecomp = ->

  # currBin[i] = # of pai i
  # currNPai = # of all pai
  # currNShuntsu = # of shuntsu (both complete and incomplete)
  # currMachi = array of absolute indices of machi options
  currBin = (0 for i in [0...N])
  currNPai = 0
  currNShuntsu = 0
  currMachi = null

  compactBin = (bin) ->
    bin.join('')
    # parseInt(bin.join(''))
    # parseInt(bin.join(''), M+1)

  # currDecomp: array of condensed {patternId, offset} (10*pid + offset)
  currDecomp = []

  appendPattern = (patternId, offset) ->
    currDecomp.push(patternId*10 + offset)

  # binDecomp[compactBin bin] gives decompositions for `bin`:
  #   [0]: complete / no-ten :
  #     [0]: 0 (empty tenpai set)
  #     [1]: array of decomp's
  #   [1]: incomplete / tenpai / machi / waiting :
  #     [0]: union of tenpai sets of all decomp's
  #     [1]: array of decomp's
  # decomp:
  #   [0]: tenpai set (as bitset, e.g. LSB = 1m, MSB = 9m)
  #   [1]: # of shuntsu placed
  #   [2]: (same as currDecomp)
  binDecomp = {}

  machi2bitmap = (machi) ->
    t = 0
    t |= 1<<m for m in machi
    t

  appendDecomp = ->
    decompSet = (binDecomp[compactBin currBin] ||= [[0, []], [0, []]])
    decomp = currDecomp.slice().sort()
    if currMachi?
      tenpai = machi2bitmap currMachi
      decompSet[1][0] |= tenpai
      decompSet[1][1].push [tenpai, currNShuntsu, decomp]
    else
      decompSet[0][1].push [0, currNShuntsu, decomp]

  # try place given pattern at offset
  # return: if successfully placed
  tryPlace = (patternId, offset) ->
    {name, as, kernel, nPai, rem, machi} = pattern = patterns[patternId]

    # check if out of boundary
    if offset + kernel.length > N then return false
    # check max # of pattern
    return false for r in rem when r[0] <= 0
    # check max # of all pai
    if currNPai + nPai > K then return false

    # check max # of single pai
    canPlace = true
    for x, rel in kernel
      abs = offset + rel
      if currBin[abs] + x > M
        canPlace = false
        break
    if !canPlace then return false

    # place
    r[0]-- for r in rem
    currNPai += nPai
    if as == 'shuntsu' then currNShuntsu++
    for x, j in kernel
      currBin[offset+j] += x

    appendPattern(patternId, offset)

    # set machi
    if machi? then currMachi = machi[offset]

    return true

  # undo most recent placement
  unPlace = (patternId, offset, n) ->
    if !n then return
    {name, as, kernel, nPai, rem, machi} = pattern = patterns[patternId]

    r[0] += n for r in rem
    currNPai -= nPai*n
    if as == 'shuntsu' then currNShuntsu -= n
    for x, j in kernel
      currBin[offset+j] -= x*n
    currDecomp.splice(-n, n)
    if machi? then currMachi = null
    return

  # check if machi is still available
  checkMachi = ->
    if !currMachi? then return true
    for m in currMachi
      if currBin[m] < M
        return true
    return false

  # nested DFS: avoid searching the same configuration twice

  dfsOffset = (minOffset) ->
    # check if out of boundary
    if minOffset >= N then return
    # check max # of all pai
    if currNPai >= K then return
    # enumerate offset to place next pattern
    for offset in [minOffset...N] by 1
      dfsPattern(offset, 0)
    return

  dfsPattern = (offset, minPatternId) ->
    # enumerate patterns to place at this offset
    for patternId in [minPatternId...patterns.length] by 1
      n = 0 # count of total # of this pattern placed
      while tryPlace patternId, offset
        ++n
        if !checkMachi() then break
        appendDecomp()
        dfsPattern(offset, patternId+1)
        dfsOffset(offset+1)
      unPlace patternId, offset, n
    return

  dfsOffset(0)
  return binDecomp

# TODO: memoize / run in background
console.time 'getBinDecomp'
binDecomp = getBinDecomp()
console.timeEnd 'getBinDecomp'

console.time 'print'
for bin, decomp of binDecomp
  console.log "#{bin}:#{JSON.stringify decomp}"
console.timeEnd 'print'
