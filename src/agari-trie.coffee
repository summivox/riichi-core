# tenpai/agari standard form decomposition (3n+1)
# conventions:
#   number range: [0, N)
#   max # of single pai: M
#   max # of all pai: K
# NOTE: several patterns can share one cap -- use array as "shared pointer"
N = 9
M = 4
K = 13
cap = {
  mentsu: [4]
  jantou: [1]
  machi : [1]
}

# NOTE: Machi for ryanmen is not defined as 2 choices are possible, which cannot
# be efficiently handled during searching. Solutions with "depleted" machi shall
# be filtered in an additional pass
patterns = [
  {name: 'shuntsu', kernel: [1, 1, 1], cnt: 3, rem: [cap.mentsu],            machi: null}
  {name: 'koutsu' , kernel: [3]      , cnt: 3, rem: [cap.mentsu],            machi: null}
  {name: 'jantou' , kernel: [2]      , cnt: 2, rem: [cap.jantou],            machi: null}
  {name: 'tanki'  , kernel: [1]      , cnt: 1, rem: [cap.jantou, cap.machi], machi: 0}
  {name: 'toitsu' , kernel: [2]      , cnt: 2, rem: [cap.machi] ,            machi: 0}
  {name: 'kanchan', kernel: [1, 0, 1], cnt: 2, rem: [cap.machi] ,            machi: 1}
  {name: 'ryanmen', kernel: [1, 1]   , cnt: 2, rem: [cap.machi] ,            machi: null}
]

# currBin[i] = # of pai i
# currCap[i] = max # of pai i (deducting machi)
currBin = (0 for i in [0...N])
currCap = (M for i in [0...N])
currCnt = 0
flattenBin = (bin) -> bin.join('')

# currAns: array of [patternId, offset]
currAns = []

# try place given pattern at offset
# return: if successfully placed
tryPlace = (patternId, offset) ->
  {name, kernel, cnt, rem, machi} = pattern = patterns[patternId]

  # check if out of boundary
  if offset + kernel.length > N then return false
  # check max # of pattern
  return false for r in rem when r[0] <= 0
  # check max # of all pai
  if currCnt + cnt > K then return false

  if machi? then machiAbs = offset + machi

  # check max # of single pai
  # NOTE: machi of current pattern is temporarily deducted
  canPlace = true
  if machi? then currCap[machiAbs]--
  for x, rel in kernel
    abs = offset + rel
    cap = currCap[abs]
    if currBin[abs] + x > currCap[abs]
      canPlace = false
      break
  if machi? then currCap[machiAbs]++
  if !canPlace then return false

  # place
  r[0]-- for r in rem
  currCnt += cnt
  for x, j in kernel
    currBin[offset+j] += x
  currAns.push "#{patternId}#{offset}"
  if machi? then currCap[offset + machi]--

  return true

# undo most recent placement
unPlace = (patternId, offset, n) ->
  if !n then return
  {name, kernel, cnt, rem, machi} = pattern = patterns[patternId]
  if machi? then machiAbs = offset + machi

  r[0] += n for r in rem
  currCnt -= cnt*n
  for x, j in kernel
    currBin[offset+j] -= x*n
  currAns.splice(-n, n)
  if machi? then currCap[machiAbs] += n
  return

# bin -> soln
bin2soln = {}
addSoln = ->
  (bin2soln[flattenBin currBin] ||= []).push(currAns.join(','))


# nested DFS: avoid searching the same configuration twice
# NOTE: "leading zeros" are suppressed by forcing 1st pattern to be placed at
# exactly offset 0

dfsOffset = (minOffset) ->
  # check if out of boundary
  if minOffset >= N then return
  # check max # of all pai
  if currCnt >= K then return
  # enumerate offset to place next pattern
  for offset in [minOffset...N] by 1
    dfsPattern(offset, 0)
    if minOffset == 0 then break
  return

dfsPattern = (offset, minPatternId) ->
  # enumerate patterns to place at this offset
  for patternId in [minPatternId...patterns.length] by 1
    n = 0 # count of total # of this pattern placed
    while tryPlace patternId, offset
      ++n
      addSoln()
      dfsPattern(offset, patternId+1)
      dfsOffset(offset+1)
    unPlace patternId, offset, n
  return

debugger
dfsOffset(0)
for bin, soln of bin2soln
  console.log "#{bin};#{soln.join(';')}"
return

# store all records into trie
# e.g. trie[0][1][2][2][1][0][0][0][0] => bin2soln['012210000']
emptyNode = -> (0 for _ in [0..M])
trie = emptyNode()
for bin, soln of bin2soln
  p = trie
  for x in bin
    q = p
    x = Number(x)
    if !q[x] then q[x] = emptyNode()
    p = q[x]
  q[x] = soln

json = JSON.stringify(trie)
console.log json.length
require('fs').writeFileSync('agari-trie.json', json, 'utf-8')
