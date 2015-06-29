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
TSUUPAI_ALT = /([ESWNBGRPFCDHTZ])/
TSUUPAI_ALT_MAP = {
  E: 1, S: 2, W: 3, N: 4 # Fonpai {wind}
  B: 5, G: 6, R: 7 # Sangenpai {honor}
  P: 5, F: 6, C: 7
  D: 5, H: 6, T: 7
  Z: 7
}

module.exports = class Pai

  constructor: (paiStr) ->
    # works without new
    if this not instanceof Pai then return new Pai paiStr
    # check for null
    if !paiStr? then throw new Error 'riichi-core: Pai: ctor: null input'
    # check for cloning
    if paiStr instanceof Pai then paiStr = paiStr.toString()

    # canonicalize representation
    if match = paiStr.match SUUPAI
      # canonical suupai
      @paiStr = paiStr
    else if match = paiStr.match TSUUPAI
      # canonical tsuupai
      @paiStr = paiStr
    else if match = paiStr.match TSUUPAI_ALT
      # valid shorthand for tsuupai
      @paiStr = TSUUPAI_ALT_MAP[match[1]] + 'z'
    else throw new Error 'riichi-core: Pai: ctor: invalid shorthand: ' + paiStr

    # make immutable
    Object.freeze this

  toString: -> @paiStr
  isEqualTo: ({paiStr}) -> @paiStr == paiStr

  # extract parts of tile
  number: -> Number @paiStr[0]
  suite: -> @paiStr[1]

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
blacklist =
  toString: true
suites = ['m', 'p', 's', 'z']
for m in [0..3]
  for n in [0..9]
    paiStr = n + suites[m]
    try Pai paiStr catch _ then continue
    Pai[paiStr] = {}
for own paiStr, paiLit of Pai
  paiObj = Pai paiStr
  for k, v of paiObj
    if blacklist[k] then continue
    # convert predicate functions to values
    if v instanceof Function
      if v.length > 0 then continue
      v = paiObj[k]()
    # link pai literals
    if v instanceof Pai then v = Pai[v.toString()]
    paiLit[k] = v

# link alternative shorthands
for alt, n of TSUUPAI_ALT_MAP
  Pai[alt] = Pai[n + 'z']

# comparison functions for sorting
#   m < p < s < z
#   m, p, s : 1 < 2 < 3 < 4 < 0 < 5 < 6 < 7 < 8 < 9
Pai.compare = (a, b) ->
  if d = a.suite.charCodeAt(0) - b.suite.charCodeAt(0) then return d
  if d = a.equivNumber - b.equivNumber then return d
  if d = a.number - b.number then return d
  return 0
