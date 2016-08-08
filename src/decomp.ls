require! {
  './pai': Pai
}

########################################
# packed bin
# 1 pos => 3 bits (octal)

const SEVEN = 8~777_777_777
const FOUR  = 8~444_444_444
const THREE = 8~333_333_333

function binValid(x)
  not ( ((x.&.THREE)+(0.|.THREE)).&.x.&.FOUR )
function binGet(x, i)
  (x.>>.((i.|.0)+(i.<<.1))).&.8~7
function binToString(key)
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
      if binValid bin
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
      if binValid bin
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
    bs = binToString bin
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
  # NOTE: I know that stateful-ness is bad, but I could not think of a "pure"
  # way of handling `hasJantou` and `existShuntsuLess` as clean...
  for binC, cs of decomp1C
    binC = Number binC
    hasJantou = cs.0.jantou?
    nMentsu = cs.0.mentsu.length
    existShuntsuLess = cs.some (.shuntsu == 0)
    if not hasJantou
      hasJantou = true # tanki serves as jantou
      for i from 0 to 8 => expand \tanki 8~1 0 i
      hasJantou = false # restore it
    if nMentsu < 4
      for i from 0 to 8 => expand \shanpon 8~2 0 i
      for i from 0 to 6 => expand \kanchan 8~101 1 i
      existShuntsuLess = false # ryanmen/penchan serves as shuntsu
      expand \penchan 8~11 2 0
      for i from 1 to 6
        expand \ryanmen 8~11 -1 i
        expand \ryanmen 8~11 2 i
      expand \penchan 8~11 -1 7
      # NOTE: no need to restore `existShuntsuLess`
  function expand(tenpaiType, pat, delta, pos)
    binW = (binC + (pat.<<.((pos.|.0)+(pos.<<.1)))).|.0
    tenpaiN = pos + delta
    if binValid binW and binGet(binW, tenpaiN) < 4
      decomp1W.[][binW].push {
        binC, cs, pos
        hasJantou, existShuntsuLess
        tenpaiType, tenpaiN
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

  return

  # dump C
  C = {[bin, cs] for bin, cs of decomp1C}
  Ck = [Number bin for bin, cs of decomp1C].sort!
  fs
    ..writeFileSync 'c-all.txt', printDecomp1C!
    ..writeFileSync 'c-keys.txt', Ck.join '\n'

  # dump W
  Wk = [binToString bin for bin, ws of decomp1W].sort!
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
  if c1 == 1 and c2 == 6 then return p1
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

mentsuWithSuite = Pai[0 1 2 3].map (P) -> (x) ->
  type: if x.&.2~10000 then \ankou else \shuntsu
  anchor: P[(x.&.2~1111) + 1]

function decompTenpai(bins)
  # kokushi: exclusive
  if (w = tenpaiK bins)
    tenpaiType = if w.length == 1 then \kokushi else \kokushi13
    # TODO: constant-ize
    return {
      decomps: w.map (tenpai) -> {
        mentsu: [], jantou: null, k7: \kokushi
        tenpaiType, tenpai
      }
      tenpaiSet: w
    }

  decomps = []
  tenpaiSet = []

  # complete decomp for each suite
  # 1-7z cannot form shuntsu
  css =
    decomp1C[bins.0]
    decomp1C[bins.1]
    decomp1C[bins.2]
    decomp1C[bins.3]?.filter (.shuntsu == 0)

  # number of suites without complete decomp:
  #   0 => tenpai might come from any suite (try each)
  #   1 => tenpai must come from this suite
  #   2+ => no solution; fail
  jw = -1
  for j til 4
    if not css[j]?.length
      if jw == -1 then jw = j
      else return {decomps, tenpaiSet}
  switch jw
  | 0 => f 0 1 2 3
  | 1 => f 1 0 2 3
  | 2 => f 2 0 1 3
  | 3 => f 3 0 1 2
  | _
    f 0 1 2 3
    f 1 0 2 3
    f 2 0 1 3
    f 3 0 1 2
  !function f(jw, j0, j1, j2)
    ws = decomp1W[bins[jw]]
    cs0 = css[j0]
    cs1 = css[j1]
    cs2 = css[j2]

    # filter: exactly 1 jantou from all sources
    # complete suites may only contribute 0 or 1
    cJantou0 = cs0.0.jantou
    cJantou1 = cs1.0.jantou
    cJantou2 = cs2.0.jantou
    cJantouN = cJantou0? + cJantou1? + cJantou2?
    if cJantouN >= 2 then return []
    # cache the jantou (if any)
    cJantou = cJantou0 ? cJantou1 ? cJantou2

    # tenpai set, represented as a bitmap
    # e.g. jw == 0 then bit 2 set means 3m in tenpai set
    bitmap = 0

    # each: tenpai suite
    for {cs: csw, tenpaiType, tenpaiN}:w in ws
      # filter: 1-7z cannot form shuntsu
      # NOTE: not redundant; this decides if tenpai is added to set
      continue if jw == 3 and not w.existShuntsuLess
      # filter: exactly 1 jantou from all sources
      # jantou either comes from complete suites or tenpai suite
      continue unless cJantouN == 1 xor w.hasJantou
      # add to tenpai set
      tenpai = mentsuWithSuite[jw](tenpaiN)
      bitmap .|.= 1.<<.tenpaiN
      # each: complete component of tenpai suite
      for cw in csw
        # filter: 1-7z cannot form shuntsu
        continue if jw == 3 and cw.shuntsu > 0
        # each: complete suites
        for c0 in cs0 => for c1 in cs1 => for c2 in cs2
          # NOTE: shuntsu already filtered (see `css` above)
          decomps.push {
            mentsu: [].concat do
              cw.mentsu.map mentsuWithSuite[jw]
              c0.mentsu.map mentsuWithSuite[j0]
              c1.mentsu.map mentsuWithSuite[j1]
              c2.mentsu.map mentsuWithSuite[j2]
            jantou: cJantou ? cw.jantou
            k7: null
            tenpaiType, tenpai
          }
        #end for c0, c1, c2
      #end for cw
    #end for w

    # add to overall tenpai set
    [].push.apply tenpaiSet, Pai.arrayFromBitmapSuite(bitmap, jw)
  #end function f

  # chiitoi: non-exclusive (might also be ryanpeikou)
  # NOTE: although chiitoi implies tanki, fu is not counted as such
  # (FIXME: explain this better)
  if (w = tenpai7 bins)?
    decomps.push {
      mentsu: [], jantou: null, k7: \chiitoi
      tenpaiType: \chiitoi, tenpai: w
    }
    if w not in tenpaiSet then tenpaiSet.push w

  tenpaiSet.sort Pai.compare
  return {decomps, tenpaiSet}
