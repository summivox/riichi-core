'use strict'
require! {
  '../pai': Pai
}

!function precond(kyoku)
  unless kyoku.phase == \postTsumo
    throw Error "wrong phase #{kyoku.phase} (should be 'postTsumo')"

# TODO: re-doc
#   player: `(currPlayer + 1)%4` -- implicit, may be omitted
#   <canonical>
#     ownPai: [2]Pai -- should satisfy the following:
#       both must exist in juntehai
#       ownPai.0.equivNumber < ownPai.1.equivNumber
#       `ownPai ++ kyoku.currPai` should form a shuntsu
#   <convenience constructor>
#     dir: Number
#       < 0 : e.g. 34m chi 5m
#       = 0 : e.g. 46m chi 5m
#       > 0 : e.g. 67m chi 5m
#     preferAkahai: Boolean
#       when you can use either akahai or normal 5 to chi:
#         true : use akahai
#         false: use normal 5
export function create(kyoku, {
  ownPai, dir, preferAkahai
})
  # CPKR boilerplate
  precond kyoku
  if kyoku.isClient and kyoku.me == kyoku.currPlayer
    throw Error "cannot declare in your own turn"

export class chi # {{{
  # client-declared
  # minimal:
  # full:
  #   ownPai: [2]Pai
  # private:
  #   fuuro

  (kyoku, {@player, @ownPai, dir, preferAkahai = true}) -> with kyoku
    @type = \chi
    @seq = ..seq
    if @player?
      assert.equal @player, (..currPlayer + 1)%4
    else
      @player = (..currPlayer + 1)%4
    if ..isClient
      assert.equal @player, ..me,
        "cannot construct for others on client instance"
    if !@ownPai?
      # infer `ownPai` from `dir`, `preferAkahai`, and player's juntehai
      assert.isNumber dir
      assert.isBoolean preferAkahai
      with ..currPai # sutehai
        n = ..equivNumber # number
        P = Pai[..S] # suite
      switch
      | dir <  0 => assert n not in [1 2] ; a = P[n - 2] ; b = P[n - 1]
      | dir == 0 => assert n not in [1 9] ; a = P[n - 1] ; b = P[n + 1]
      | dir >  0 => assert n not in [8 9] ; a = P[n + 1] ; b = P[n + 2]
      @ownPai = [a, b]
      with ..playerHidden[@player]
        assert (..countEquiv(a) and ..countEquiv(b)),
          "you must have [#a#b] in juntehai"
        # check whether we replace one of @ownPai with corresponding akahai
        if a.number == 5 then i = 0 ; p5 = a
        if b.number == 5 then i = 1 ; p5 = b
        if p5?
          p0 = p5.akahai
          p5n = ..count1(p5)
          p0n = ..count1(p0)
          # truth table: (has normal), (has akahai, prefer akahai) -> use akahai
          # |   | 00 | 01 | 11 | 10 |
          # | 0 | X  | X  | 1  | 1  |
          # | 1 | 0  | 0  | 1  | 0  |
          if p5n == 0 or (p0n > 0 and preferAkahai) then @ownPai[i] = p0
    @init kyoku

  init: (kyoku) -> with @kyoku = kyoku
    assert.equal @type, \chi
    assert.equal ..phase, \postDahai
    if @player?
      assert.equal @player, (..currPlayer + 1)%4
    else
      @player = (..currPlayer + 1)%4

    assert.lengthOf @ownPai, 2
    [a, b] = @ownPai
    c = ..currPai
    if a.N > b.N then [a, b] = @ownPai = [b, a]
    [p, q, r] = [a, b, c] .map (.equivPai) .sort Pai.compare
    assert (p.suite == q.suite == r.suite and p.succ == q and q.succ == r),
      "[#p#q#r] is not valid shuntsu"
      # NOTE: `equivPai` is shown (not original)

    # build fuuro object
    @fuuro = {
      type: \minjun
      anchor: p
      ownPai: @ownPai
      otherPai: c
      fromPlayer: ..currPlayer
      kakanPai: null
    }
    with ..playerHidden[@player] => if .. instanceof PlayerHidden
      assert (..count1(a) and ..count1(b)), "you must have [#a#b] in juntehai"

    return this

  apply: !-> with kyoku = @kyoku
    .._didNotHoujuu this
    ..playerHidden[@player].remove2 @ownPai.0, @ownPai.1
    ..playerPublic[@player]
      ..fuuro.push @fuuro
      ..menzen = false
    ..playerPublic[..currPlayer].lastSutehai.fuuroPlayer = @player

    ..currDecl.clear!
    ..currPlayer = @player
    ..phase = \postChiPon

  toPartials: -> for til 4 => @{type, seq, ownPai}

  toMinimal: -> @{type, seq, ownPai}
# }}}

