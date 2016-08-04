

########################################
# bin ops

const FOUR  = 8~444_444_444
const THREE = 8~333_333_333
function valid(x)
  not ( ((x.&.THREE)+(0.|.THREE)).&.x.&.FOUR )
function binStr(key)
  s = Number key .toString 8
  return ('0' * (9 - s.length)) + s


########################################
# complete

# []{shuntsu: Number, jantou: Pai?, mentsu: []Number}
export decomp1C = []
export !function makeDecomp1C
  jantou = null
  shuntsu = 0
  mentsu = [0 0 0 0]
  !function dfsShuntsu(n, iMin, binOld)
    for i from iMin til 7
      bin = (binOld + (8~111.<<.((i.|.0)+(i.<<.1)))).|.0
      if valid bin
        shuntsu++
        mentsu[n] = i
        decomp1C.[][bin].push {shuntsu, jantou, mentsu: mentsu.slice(0, n + 1)}
        if n < 3
          dfsShuntsu n + 1, i, bin
          dfsKoutsu  n + 1, 0, bin
        shuntsu--
  !function dfsKoutsu(n, iMin, binOld)
    for i from iMin til 9
      bin = (binOld + (8~3.<<.((i.|.0)+(i.<<.1)))).|.0
      if valid bin
        mentsu[n] = i.|.2~10000
        decomp1C.[][bin].push do
          {shuntsu, jantou, mentsu: mentsu.slice(0, n + 1)}
        if n < 3
          dfsKoutsu n + 1, i, bin
  decomp1C[0] = [{shuntsu: 0, jantou: null, mentsu: []}]
  dfsShuntsu 0 0 0
  dfsKoutsu  0 0 0
  for jantou til 9
    bin = 8~2.<<.((jantou.|.0)+(jantou.<<.1))
    decomp1C[bin] = [{shuntsu, jantou, mentsu: []}]
    dfsShuntsu 0 0 bin
    dfsKoutsu  0 0 bin

export function printDecomp1C
  outs = []
  for bin, cs of decomp1C
    bs = binStr bin
    for {jantou, mentsu} in cs
      out = bs
      for x in mentsu
        out += if x.&.2~10000 then ',1' + (x.&.2~1111) else ',0' + x
      if jantou?
        out += ',2' + jantou
      outs.push out
  outs .sort! .join '\n'


########################################
# waiting

export decomp1W = []
export !function makeDecomp1W
  for binC, cs of decomp1C
    binC = Number binC
    if !cs.0.jantou?
      for i from 0 to 8 => expand 0 8~1   \tanki   i
    if cs.0.mentsu.length < 4
      for i from 0 to 8 => expand 1 8~2   \shanpon i
      for i from 0 to 6 => expand 2 8~101 \kanchan i
      do
                           expand 3 8~11  \penchan 0
                           expand 3 8~11  \penchan 7
      for i from 1 to 6 => expand 3 8~11  \ryanmen i
  function expand(p, pat, waitType, i)
    dShuntsu = if p >= 2 then 1 else 0
    dJantou = if p == 0 then true else false
    binW = (binC + (pat.<<.((i.|.0)+(i.<<.1)))).|.0
    if valid binW
      decomp1W.[][binW].push {
        binC, cs, dShuntsu, dJantou, waitType, p, i
      }


########################################
# test (TODO: move to actual test)

if module is require.main
  require! {assert, fs}

  console.time 'make total'
  console.time 'make C'
  makeDecomp1C!
  console.timeEnd 'make C'
  console.time 'make W'
  makeDecomp1W!
  console.timeEnd 'make W'
  console.timeEnd 'make total'

  # dump C
  C = {[bin, cs] for bin, cs of decomp1C}
  Ck = [Number bin for bin, cs of decomp1C].sort!
  fs
    ..writeFileSync 'c-all.txt', printDecomp1C!
    ..writeFileSync 'c-keys.txt', Ck.join '\n'

  # dump W
  Wk = [binStr bin for bin, ws of decomp1W].sort!
  fs
    ..writeFileSync 'w-keys-uniq.txt', Wk.join '\n'
