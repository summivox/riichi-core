

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
      for i from 0 to 8 => expand 0 8~1   i # tanki
    if cs.0.mentsu.length < 4
      for i from 0 to 8 => expand 1 8~2   i # shanpon
      for i from 0 to 6 => expand 2 8~101 i # kanchan
      for i from 0 to 7 => expand 3 8~11  i # ryanmen/penchan
  function expand(p, pat, i)
    binW = (binC + (pat.<<.((i.|.0)+(i.<<.1)))).|.0
    if valid binW
      decomp1W.[][binW].push {
        binC, cs, pattern: p, offset: i
        #dShuntsu:~-> p >= 2
        #dJantou:~-> p == 0
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


########################################
# kokushi-musou and chiitoitsu
# shorthand: `k`, `7`, `k7`

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
    if ++c2 > 1 then return false
  | 3, 4 => return false
  return c1 == 12 and c2 == 1

# chiitoi tenpai: 6 toitsu + 1 tanki
function tenpai7(bins)
  c1 = c2 = 0
  p1 = -1
  for s til 4 => for n til 9 => switch bins[s][n]
  | 0 => void
  | 1 =>
    if ++c1 > 1 then return null
    p1 = Pai[s][n+1]
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


########################################
# tenpai

function decompTenpai(bins)
  # kokushi: exclusive
  if (w = tenpaiK bins) then return {
    decomps: [{
      mentsu: [], jantou: null, k7: \kokushi
      tenpaiType: if w.length == 1 then \kokushi else \kokushi13
      tenpaiSet: w
    }]
    tenpaiSet: w
  }

  decomps = []

  # complete decomp for each suite
  # 1-7z cannot form shuntsu
  css =
    decomp1C[bins.0]
    decomp1C[bins.1]
    decomp1C[bins.2]
    decomp1C[bins.3]?.filter (.shuntsu == 0)

  # number of suites without complete decomp:
  #   0 => all 4 suites may be waiting
  #   1 => only this suite can be waiting
  #   2+ => fail
  jw = -1
  for i til 4
    if not css[i]?.length
      if jw == -1 then jw = that
      else return ret
  switch jw
  | 0 => tenpaiSet = f 0 1 2 3
  | 1 => tenpaiSet = f 1 0 2 3
  | 2 => tenpaiSet = f 2 0 1 3
  | 3 => tenpaiSet = f 3 0 1 2
  | _ => tenpaiSet = [].concat do
    f 0 1 2 3
    f 1 0 2 3
    f 2 0 1 3
    f 3 0 1 2
  function f(jw, j0, j1, j2)
    ws = decomp1W[bins[jw]]
    cs0 = css[j0]
    cs1 = css[j1]
    cs2 = css[j2]

    # exactly 1 jantou from all sources
    cJantouN =
      (+cs0.0.jantou?) +
      (+cs1.0.jantou?) +
      (+cs2.0.jantou?)
    if cJantouN >= 2 then return []

    tenpaiBitmap1 = 0
    for w in ws # tenpai suite
      # 1-7z cannot form shuntsu
      if jw == 3 and w.pattern >= 2 then continue
      # exactly 1 jantou from all sources
      jantouN =
        cJantouN +
        (+(w.pattern == 0)) +
        (+w.cs.0.jantou?)
      if jantouN != 1 then continue
      # union into tenpai set
      {pattern, offset} = w
      switch pattern
      | 0, 1 # tanki and shanpon
        # remove "blatant" karaten
        if bins[jw][offset] == 4 then continue
        tenpaiBitmap1 .|.= 1.<<.offset
        tenpaiType = if pattern == 0 then \tanki else \shanpon
      | 2 # kanchan
        # remove "blatant" karaten
        if bins[jw][offset + 1] == 4 then continue
        tenpaiBitmap1 .|.= 1.<<.(offset + 1)
      | 3 # ryanmen/penchan
        # more complex now
        succ = false
        if offset - 1 >= 0 and bins[jw][offset - 1] != 4
          succ = true
          ...
        if offset + 2 >= 0 and bins[jw][offset + 2] != 4
          succ = true
          ...
        if succ
          ...
      | _ => throw Error 'WTF'

      for cw in w.cs # complete part of tenpai suite
        if jw == 3 and cw.shuntsu then continue
        for c0 in cs0 => for c1 in cs1 => for c2 in cs2 # complete suites
          ...
    ...

  # chiitoi: non-exclusive (might also be ryanpeikou)
  # NOTE: although chiitoi implies tanki, fu is not counted as such
  # (FIXME: dubious explanation)
  if (w = tenpai7 bins)
    ret.decomps.push {
      mentsu: [], jantou: null, k7: \chiitoi
      tenpaiType: \chiitoi
      tenpaiSet: w
    }
    if w.0 not in ret.tenpaiSet then ret.tenpaiSet.push w.0
  return ret
