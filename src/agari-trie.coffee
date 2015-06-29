# agari-trie: pre-computed dictionary for decomposing
# the same suite, which is a key step in decomposition of agari/tenpai hands
#
# example:
#


# DFS to find all contiguous numeral mentsu configurations

# current decomposition:
#   shuntsu: array of smallest tile in each shuntsu (e.g. 345 => 3)
#   koutsu: array of tile triplet in each koutsu (e.g. 888 => 8)
shuntsu = []
koutsu = []

# currBin[i] = # of tiles with number (i+1)
currBin = (0 for i in [0...9])
flattenBin = (bin) -> bin.join('')

# bin -> soln
ret = {}
addRet = ->
  (ret[flattenBin currBin] ||= []).push [
    shuntsu.slice()
    koutsu.slice()
  ]

dfs = (i, j, nShuntsu, nKoutsu) ->
  # console.log "(#{i}, #{j}, #{nShuntsu}, #{nKoutsu}) #{flattenBin currBin}"
  if nShuntsu + nKoutsu >= 4 then return
  for k in [i..j]
    # try place shuntsu at k
    if currBin[k] <= 3 && currBin[k+1] <= 3 && currBin[k+2] <= 3
      shuntsu.push k
      currBin[k]++
      currBin[k+1]++
      currBin[k+2]++
      addRet()
      j2 = Math.min(Math.max(j, k+3), 9-1)
      dfs(k, j2, nShuntsu+1, nKoutsu)
      currBin[k+2]--
      currBin[k+1]--
      currBin[k]--
      shuntsu.pop()
    # try place koutsu at k
    if currBin[k] <= 1
      koutsu.push k
      currBin[k] += 3
      addRet()
      j2 = Math.min(Math.max(j, k+1), 9-1)
      dfs(k+1, j2, nShuntsu, nKoutsu+1)
      currBin[k] -= 3
      koutsu.pop()

dfs(0, 0, 0, 0)


# store all records into trie
# e.g. trie[1][2][2][1] => ret['122100000']
module.exports = trie = [0, 0, 0, 0, 0]
for bin, solns of ret
  p = trie
  for i in bin
    i = Number(i)
    if !i then break
    if !p[i] then p[i] = [0, 0, 0, 0, 0]
    p = p[i]
  p[0] = solns


# attempt to decompose several suupai of the same suite into mentsu
# no solution: null
# otherwise: array of possible decomposition, where:
#   each decomposition: [shuntsu, koutsu] (see `./agari-trie`)
decomposeMentsu = (numbers) ->
  # quick check: # of tiles
  if numbers.length % 3 != 0 then return null

  # bin[i] = # of (i-1) in numbers
  # bin[9] is guardian element (for easier trie traversal)
  bin = (0 for n in [0...10])
  bin[n]++ for n in numbers

  runs = []
  n = 1
  loop
    # skip 0
    while n <= 9 && bin[n] == 0
      n++
    # check if done
    if n > 9 then break
    # feed to trie
    p = trie
    n0 = n
    while n <= 9
      # no entry in trie => dead end => no solution
      p = p[bin[n]]
      if !p then return null
      if n > 9 || bin[n] == 0
        # found solution entry in trie
        # make copy and add offset
        pp = for [shuntsu, koutsu] in p
          shuntsu = shuntsu.slice()
          koutsu = koutsu.slice()
          for _, i in shuntsu
            shuntsu[i] += n0
          for _, i in koutsu
            koutsu[i] += n0
          [shuntsu, koutsu]
        runs.push pp
        break
      n++

  multiSoln = null
  for solns, n in runs
    if solns.length > 1
      multiSoln = solns.splice n

  soln #TODO: patch together the solutions
