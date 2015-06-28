# Pai {tile}
#
# represents a tile with tenhou-compatible shorthand string
# instances are immutable

module.exports = class Pai

  @SUUPAI = SUUPAI = /([0-9])([mps])/
  @TSUUPAI = TSUUPAI = /([1-7])z/
  @TSUUPAI_ALT = TSUUPAI_ALT = /([ESWNBGRPFCDHTZ])/
  @TSUUPAI_ALT_MAP = TSUUPAI_ALT_MAP = {
    E: 1, S: 2, W: 3, N: 4 # Fonpai {wind}
    B: 5, G: 6, R: 7 # Sangenpai {honor}
    P: 5, F: 6, C: 7
    D: 5, H: 6, T: 7
                Z: 7
  }

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
  isEquivTo: (other) -> @equivPai().isEqual(other.equivPai())

  # handle indicator of dora
  succ: ->
    n = @equivNumber()
    if @isSuupai()
      n = (n-1)%9 + 1
    else
      if @isFonpai()
        n = (n-1)%4 + 1
      else
        n = (n-5)%3 + 5
    Pai(n + @suite())
  isSuccOf: (pred) -> @equivPai.isEqual pred.succ()
