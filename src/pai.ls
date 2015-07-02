# Pai {tile}
# represents a tile with tenhou-compatible shorthand string
#
# NOTE:
# * Pai objects (e.g. `Pai('5m')`) provide definition of rules.
# * Pai literals (e.g. `Pai['5m']`) are generated from all distinct Pai objects
#   They are different from Pai objects in that all predicate functions are
#   converted to actual values.

SUUPAI = /([0-9])([mps])/
TSUUPAI = /([1-7])z/
TSUUPAI_ALT = /([ESWNBGRPFCZ])/
TSUUPAI_ALT_MAP =
  E: 1, S: 2, W: 3, N: 4 # Fonpai {wind}
  B: 5, G: 6, R: 7 # Sangenpai {honor}
  P: 5, F: 6, C: 7
  Z: 7
SUITES = <[m p s z]>
SUITE_NUMBER = m: 0, p: 1, s: 2, z: 3

module.exports = class Pai

  (paiStr) ->
    # works without new
    if this not instanceof Pai then return new Pai paiStr
    # check for null
    if !paiStr? then throw new Error 'riichi-core: Pai: ctor: null input'
    # check for cloning
    if paiStr instanceof Pai then paiStr = paiStr.toString()

    # canonicalize representation
    if m = paiStr.match SUUPAI
      # canonical suupai
      @paiStr = paiStr
    else if m = paiStr.match TSUUPAI
      # canonical tsuupai
      @paiStr = paiStr
    else if m = paiStr.match TSUUPAI_ALT
      # valid shorthand for tsuupai
      @paiStr = TSUUPAI_ALT_MAP[m[1]] + 'z'
    else throw new Error 'riichi-core: Pai: ctor: invalid shorthand: ' + paiStr

    # make immutable
    Object.freeze this

  toString: -> @paiStr
  isEqualTo: ({paiStr}) -> @paiStr == paiStr

  # extract parts of tile
  number: -> Number @paiStr[0]
  suite: -> @paiStr[1]
  suiteNumber: -> SUITE_NUMBER[@suite()]

  # test if tile belongs to a category
  isSuupai: -> @suite() != 'z'
  isManzu: -> @suite() == 'm'
  isPinzu: -> @suite() == 'p'
  isSouzu: -> @suite() == 's'
  isAkahai: -> @isSuupai() && @number() == 0
  isRaotoupai: -> @isSuupai() && (@number() == 1 || @number() == 9)
  isChunchanpai: -> @isSuupai() && @number() != 1 && @number() != 9
  isTsuupai: -> @suite() == 'z'
  isFonpai: -> @isTsuupai() && 1 <= @number() <= 4
  isSangenpai: -> @isTsuupai() && 5 <= @number() <= 7
  isYaochuupai: -> @isRaotoupai() || @isTsuupai()


  # hardcoded rules for dora

  # handle akahai {red tile} (denoted `/0[mps]/` but acts as red `/5[mps]/`)
  equivNumber: ->
    n = @number()
    if @isAkahai() then 5 else n
  equivPai: ->
    Pai(@equivNumber() + @suite())
  isEquivTo: (other) -> @equivPai().isEqualTo(other.equivPai())

  # handle indicator of dora
  succ: ->
    n = @equivNumber()
    if @isSuupai()
      if n == 9 then n = 1
      else ++n
    else
      if @isFonpai()
        if n == 4 then n = 1
        else ++n
      else
        if n == 7 then n = 5
        else ++n
    Pai(n + @suite())
  isSuccOf: (pred) -> @equivPai().isEqualTo(pred.succ())

# Build dictionary of pai literals
do ->
  blacklist =
    toString: true
  f = -> return @paiStr
  prototype = {toString: f, toJSON: f}
  for m from 0 to 3
    for n from 0 to 9
      paiStr = n + SUITES[m]
      try Pai paiStr catch e then continue
      Pai[paiStr] = Object.create(prototype)
  for own paiStr, paiLit of Pai
    paiObj = Pai paiStr
    for k, v of paiObj
      if blacklist[k] then continue
      # convert predicate functions to values
      if v instanceof Function
        if v.length > 0 then continue
        v = paiObj[k]()
      # link pai literals
      if v instanceof Pai then v = Pai[v.paiStr]
      paiLit[k] = v

# link alternative shorthands
do ->
  for alt, n of TSUUPAI_ALT_MAP
    Pai[alt] = Pai[n + 'z']
  for n from 0 to 9
    a = Pai[n] = new Array 4
    for m from 0 to 3
      a[m] = Pai[n + SUITES[m]]

# export constants
Pai.SUITES = SUITES
Pai.SUITE_NUMBER = SUITE_NUMBER


# comparison functions for sorting
#   m < p < s < z
#   m, p, s : 1 < 2 < 3 < 4 < 0 < 5 < 6 < 7 < 8 < 9
Pai.compare = (a, b) ->
  if d = a.suiteNumber - b.suiteNumber then return d
  if d = a.equivNumber - b.equivNumber then return d
  if d = a.number - b.number then return d
  return 0


# representations for a set of pai's:
#
# * contracted multi-pai string (tenhou-compatible)
#   e.g. 3347m40p11237s26z5m
#
# * sorted array of Pai literals
#
# * "bins" for simplified calculations
#   bins[0][i] => # of pai (i+1)-m  ;  0 <= i < 9
#   bins[1][i] => # of pai (i+1)-p  ;  0 <= i < 9
#   bins[2][i] => # of pai (i+1)-s  ;  0 <= i < 9
#   bins[3][i] => # of pai (i+1)-z  ;  0 <= i < 7
#
#   NOTE:
#   * bins format treats 0m/0p/0s as 5m/5p/5s
#   * for convenience, bins[3][7] = bins[3][8] = 0
#
# * bitmap, lsbit-first (for unique set of pai in single suite)
#   e.g. 0b000100100 => 36m/36p/...

Pai.arrayFromString = (s) ->
  ret = []
  for run in s.match /\d*\D/g
    l = run.length
    if l <= 2
      # not contracted
      ret.push Pai[run]
    else
      # contracted
      suite = run[l-1]
      for i til l-1
        number = run[i]
        ret.push Pai[number + suite]
  ret.sort Pai.compare
  ret

Pai.stringFromArray = (paiArray) ->
  if !paiArray? then throw Error 'riichi-core: tehai: stringify: null input'
  l = paiArray.length
  if l == 0 then return ''

  # make a sorted copy
  paiArray = paiArray.slice().sort Pai.compare
  ret = ''
  run = [paiArray[0].number]
  suite = paiArray[0].suite
  flush = -> ret += run.join('') + suite

  for i from 1 til l
    pai = paiArray[i]
    if pai.suite == suite
      run.push pai.number
    else
      flush()
      run = [pai.number]
      suite = pai.suite
  flush()
  return ret

Pai.binsFromString = (s) ->
  ret =
    [0 0 0 0 0 0 0 0 0]
    [0 0 0 0 0 0 0 0 0]
    [0 0 0 0 0 0 0 0 0]
    [0 0 0 0 0 0 0 0 0]
  for run in s.match /\d*\D/g
    l = run.length
    if l <= 2
      # not contracted
      pai = Pai[run]
      ret[pai.suiteNumber][pai.number-1]++
    else
      # contracted
      suiteNumber = SUITE_NUMBER[run[l-1]]
      for i til (l-1)
        number = Number run[i]
        if number == 0 then number = 5
        ret[suiteNumber][number-1]++
  ret

Pai.binsFromArray = (paiArray) ->
  ret =
    [0 0 0 0 0 0 0 0 0]
    [0 0 0 0 0 0 0 0 0]
    [0 0 0 0 0 0 0 0 0]
    [0 0 0 0 0 0 0 0 0]
  for pai in paiArray
    ret[pai.suiteNumber][pai.equivNumber-1]++
  ret

Pai.binFromBitmap = (bitmap) ->
  ret = [0 0 0 0 0 0 0 0 0]
  i = 0
  while bitmap
    ret[i++] = bitmap .&. 1
    bitmap .>>.= 1
  ret

Pai.arrayFromBitmapSuite = (bitmap, suite) ->
  # accept both 'm/p/s/z' and 0/1/2/3
  if suite.length then suite = SUITE_NUMBER[suite]
  n = 1
  ret = []
  while bitmap
    if bitmap .&. 1 then ret.push Pai[n][suite]
    n++
    bitmap .>>.= 1
  ret

# generate array of all 136 pai in uniform random order
# nAkapai: # of [0m, 0p, 0s] to replace corresponding [5m, 5p, 5s]
Pai.shuffleAll = (nAkapai = [1 1 1]) ->
  [m0, p0, s0] = nAkapai
  m5 = 4 - m0
  p5 = 4 - p0
  s5 = 4 - s0

  # meh.
  S = "1111222233334444#{'0'*m0}#{'5'*m5}6666777788889999m"+
      "1111222233334444#{'0'*p0}#{'5'*p5}6666777788889999p"+
      "1111222233334444#{'0'*s0}#{'5'*s5}6666777788889999s"+
      "1111222233334444555566667777z"
  a = Pai.arrayFromString S

  # shuffle
  for i from 136-1 til 0 by -1
    j = ~~(Math.random() * (i + 1))
    t = a[j] ; a[j] = a[i] ; a[i] = t
  a
