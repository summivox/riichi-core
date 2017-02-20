# # Events
'use strict'
require! {
  './pai': Pai
  './decomp': {decompTenpai}
  './split-wall': splitWall
  './util': {OTHER_PLAYERS}

  './kyoku-player-public': PlayerPublic
  './kyoku-player-hidden': PlayerHidden
  './kyoku-player-hidden-mock': PlayerHiddenMock
}

# ## Global TODO
#
# - explain `doraHyouji` piggybacking
# - more watertight `init` checks
# - assertion messages even though source is pretty natural language
#   - separate "ctor" from "minimal"/"canonical"
#  - fix doc of all events

# ## Overview (TL;DR)
#
# See architecture document for details on client/server and event-sourcing.
#
# ### Server Events
#
# List:
#
# - `deal`
# - `tsumo`
# - `ryoukyoku`
# - `howanpai`
#
# Procedure:
#
# 1.  Call `Kyoku#deal`/`Kyoku#go` on server, which constructs and executes the
#     event.
# 2.  Send partials to clients.
# 3.  Initialize and execute partial event on each client.
#
# ### Own-turn Events
#
# List:
#
# - `dahai`
# - `ankan`
# - `kakan`
# - `tsumoAgari`
# - `kyuushuuKyuuhai`
#
# Procedure:
#
# 1.  Construct event on client.
# 2.  Send type and ctor args to server.
# 3.  Construct event on server and execute.
# 4.  Send partials (full event) to clients.
# 5.  Initialize and execute event on each client.
#
# ### Declared Events
#
# List:
#
# - `chi`
# - `pon`
# - `daiminkan`
# - `ron`
#
# Procedure:
#
# 1.  Construct event on client.
# 2.  Send type and ctor args to server.
# 3.  Construct `declare` wrapper event on server and execute.
# 4.  Send partials (player, type) to clients.
# 5.  Initialize and execute `declare` on each client.
# 6.  After server collects all declarations, call `Kyoku#resolve` on server,
#     which executes the event that "wins".
# 7.  Send partials (full event) to clients.
# 8.  Initialize and execute event on each client.

function validatedPaiArray(a)
  b = a.map (Pai.)
  assert b.every (?)
  b
function validatedPaiArrayN(a, n)
  assert.lengthOf a, n
  validatedPaiArray(a)


export class kyuushuukyuuhai # {{{
  # client-initiated
  # minimal: null
  # full:: kyoku.getUraDoraHyouji kyoku.currPlayer
  #   juntehai: PlayerHidden::juntehai
  #   tsumohai: PlayerHidden::tsumohai
  #
  # NOTE: this is the only client-initiated ryoukyoku; completely
  # disjoint from `ryoukyoku` event which covers server-initiated ryoukyoku

  (kyoku) -> with kyoku
    @type = \kyuushuukyuuhai
    @seq = ..seq
    if ..isClient
      assert.equal ..currPlayer, ..me,
        "cannot construct for others on client instance"
    @init kyoku

  init: (kyoku) -> with @kyoku = kyoku
    assert.equal @type, \kyuushuukyuuhai
    assert.equal ..phase, \postTsumo

    assert ..virgin
    with ..playerHidden[..currPlayer]
      if .. instanceof PlayerHidden
        @{juntehai, tsumohai} = ..
    assert.lengthOf @juntehai, 13
    assert.isNotNull @tsumohai

    nYaochuu =
      Pai.yaochuuFromBins Pai.binsFromArray @juntehai ++ @tsumohai
      .filter (>0) .length
    assert nYaochuu >= 9

    return this

  apply: !-> with kyoku = @kyoku
    ..result
      ..type = \ryoukyoku
      ..reason = \kyuushuukyuuhai
      ..renchan = true
    .._end!

  toPartials: -> for til 4 => @{type, seq, juntehai, tsumohai}

  toMinimal: -> @{type, seq}
# }}}

export class declare # {{{
  # SPECIAL: EVENT WRAPPER
  # minimal:
  #   what: chi/pon/daiminkan/ron
  #   args: (constructor args for constructing corresponding event)
  #     player: 0/1/2/3
  # partial:
  #   player: 0/1/2/3 -- `args.player`
  #   what
  # full:
  #   player
  #   what
  #   args

  (kyoku, {@what, @args}) -> with kyoku
    @type = \declare
    @seq = ..seq
    @init kyoku

  init: (kyoku) -> with @kyoku = kyoku
    assert.equal @type, \declare
    assert @what in <[chi pon daiminkan ron]>#
    if @args?
      @player ?= new exports[@what](kyoku, @args) .player
    assert.isNull ..currDecl[@player],
      "a player can only declare once during one turn"
    return this

  apply: !-> with kyoku = @kyoku
    ..currDecl.add @{what, player, args} # NOTE: `args` can be null

  toPartials: ->
    for p til 4
      # FIXME: just make it uniform?
      if p == @player
        @{type, seq, what, player, args}
      else
        @{type, seq, what, player}

  toMinimal: -> @{type, seq, what, args}
# }}}

export class chi # {{{
  # client-declared
  # minimal:
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

export class pon # {{{
  # client-declared
  # minimal:
  #   player: 0/1/2/3 -- must not be `currPlayer`
  #   <canonical>
  #     ownPai: [2]Pai -- should satisfy the following:
  #       both must exist in juntehai
  #       `ownPai ++ kyoku.currPai` should form a koutsu (i.e. same `equivPai`)
  #   <convenience constructor>
  #     maxAkahai: Integer -- max number of akahai to use as ownPai
  # full:
  #   ownPai: [2]Pai
  # private:
  #   fuuro

  (kyoku, {@player, @ownPai, maxAkahai = 2}) -> with kyoku
    @type = \pon
    @seq = ..seq
    if ..isClient
      assert.equal @player, ..me,
        "cannot construct for others on client instance"
    if !@ownPai?
      # infer `ownPai` from `maxAkahai`
      assert.isNumber maxAkahai
      pai = ..currPai
      with ..playerHidden[@player]
        nAll = ..countEquiv(pai)
        assert nAll >= 2, "not enough [#pai] (you have #nAll, need 2)"
        if pai.number == 5
          akahai = Pai[pai.S][0]
          nAkahai = ..count1(akahai)
          nAkahai <?= maxAkahai <? 2
        else
          nAkahai = 0
      @ownPai = switch nAkahai
      | 0 => [pai, pai]
      | 1 => [akahai, pai]
      | 2 => [akahai, akahai]
    @init kyoku

  init: (kyoku) -> with @kyoku = kyoku
    assert.equal @type, \pon
    assert.notEqual @player, ..currPlayer
    assert.equal ..phase, \postDahai

    assert.lengthOf @ownPai, 2
    [a, b] = @ownPai
    c = ..currPai
    if a.N > b.N then [a, b] = @ownPai = [b, a]
    assert a.equivPai == b.equivPai == c.equivPai,
      "[#a#b#c] is not a valid koutsu"

    # build fuuro object
    @fuuro = {
      type: \minko
      anchor: c.equivPai
      ownPai: @ownPai
      otherPai: c
      fromPlayer: ..currPlayer
      kakanPai: null
    }

    with ..playerHidden[@player] => if .. instanceof PlayerHidden
      if a == b
        assert (..count1(a) >= 2), "you must have [#a#b] in juntehai"
      else
        assert (..count1(a) and ..count1(b)), "you must have [#a#b] in juntehai"

    return this

  apply: chi::apply # exactly the same code

  toPartials: -> for til 4 => @{type, seq, player, ownPai}
  # NOTE: can't reuse here: `player` is implicit in `chi` but not in `pon`

  toMinimal: -> @{type, seq, player, ownPai}
# }}}

export class daiminkan # {{{
  # client-declared
  # minimal:
  #   player: 0/1/2/3 -- must not be `currPlayer`
  # full:
  #   newDoraHyouji: ?[]Pai
  # private:
  #   fuuro

  (kyoku, {@player}) -> with kyoku
    @type = \daiminkan
    @seq = ..seq
    if ..isClient
      assert.equal @player, ..me,
        "cannot construct for others on client instance"
    @init kyoku

  init: (kyoku) -> with @kyoku = kyoku
    assert.equal @type, \daiminkan
    assert.notEqual @player, ..currPlayer
    assert.equal ..phase, \postDahai
    assert ..nTsumoLeft > 0, "cannot kan when no piipai left"
    pai = ..currPai
    anchor = pai.equivPai

    # build fuuro object
    # ownPai: list all 4 pai (e.g. 3 normal 1 aka) then exclude sutehai
    if anchor.isSuupai and anchor.number == 5
      # include all akahai
      akahai = anchor.akahai
      nAkahai = ..rulevar.dora.akahai[anchor.S]
      ownPai = [akahai]*nAkahai ++ [anchor]*(4 - nAkahai)
    else
      ownPai = [anchor]*4
    ownPai.splice(ownPai.indexOf(pai), 1) # NOTE: not `anchor`
    @fuuro = {
      type: \daiminkan
      anchor
      ownPai
      otherPai: pai
      fromPlayer: ..currPlayer
      kakanPai: null
    }

    # server: try reveal doraHyouji
    if not ..isClient
      if @newDoraHyouji?
        assert.deepEqual @newDoraHyouji, ..getNewDoraHyouji(this)
      else
        @newDoraHyouji = ..getNewDoraHyouji this

    with ..playerHidden[@player] => if .. instanceof PlayerHidden
      assert.equal ..countEquiv(anchor), 3,
        "need 3 [#anchor] in juntehai"

    return this

  apply: !-> with kyoku = @kyoku
    .._didNotHoujuu this
    ..playerHidden[@player].removeEquivN @fuuro.anchor, 3
    ..playerPublic[@player]
      ..fuuro.push @fuuro
      ..menzen = false
    ..playerPublic[..currPlayer].lastSutehai.fuuroPlayer = @player
    ..nKan++

    .._addDoraHyouji @newDoraHyouji

    ..rinshan = true
    ..currDecl.clear!
    ..currPlayer = @player
    ..phase = \preTsumo # NOTE: no need to ask for ron

  toPartials: -> for til 4 => @{type, seq, player, newDoraHyouji}

  toMinimal: -> @{type, seq, player}
# }}}

export class ron # {{{
  # client-initiated
  # minimal:
  #   player: 0/1/2/3 -- must not be `currPlayer`
  #   isFirst, isLast: ?Boolean -- added by server during resolve
  # full:
  #   juntehai: PlayerHidden::juntehai
  #   uraDoraHyouji: ?[]Pai -- only revealed ones if riichi
  # private:
  #   agari: Agari

  (kyoku, {@player, @isFirst = true, @isLast = true}) -> with kyoku
    @type = \ron
    @seq = ..seq
    if ..isClient
      assert.equal @player, ..me,
        "cannot construct for others on client instance"
    @init kyoku

  init: (kyoku) -> with @kyoku = kyoku
    assert.equal @type, \ron
    assert.notEqual @player, ..currPlayer
    assert ..phase in <[postDahai postAnkan postKakan]>#

    with ..playerHidden[@player]
      if .. instanceof PlayerHidden
        assert not ..furiten
        @{juntehai} = ..
        {tenpaiDecomp} = ..
    assert.isArray @juntehai
    tenpaiDecomp ?= decompTenpai Pai.binsFromArray @juntehai
    assert ..isKeiten tenpaiDecomp
    if not ..isClient
      @uraDoraHyouji = ..getUraDoraHyouji @player

    @agari = ..agari this
    assert.isNotNull @agari

    return this

  apply: !-> with kyoku = @kyoku
    ..currDecl.clear!
    if @uraDoraHyouji?.length
      ..uraDoraHyouji = @uraDoraHyouji
      @agari = ..agari this # recalculate agari due to changed uraDoraHyouji
    ..result.type = \ron
    for p til 4 => ..result.delta[p] += @agari.delta[p]
    ..result.takeKyoutaku @player
    ..result.renchan = ..result.renchan or @player == ..chancha
    ..result.[]agari.push @agari
    if @isLast then .._end!

  toPartials: -> for til 4
    @{type, seq, player, isFirst, isLast, juntehai, uraDoraHyouji}

  toMinimal: -> @{type, seq, player, isFirst, isLast}
# }}}

export class nextTurn # {{{
  # server-initiated
  # NOTE: no member

  (kyoku) -> with kyoku
    @type = \nextTurn
    @seq = ..seq
    assert not ..isClient
    @init kyoku

  init: (kyoku) -> with @kyoku = kyoku
    assert.equal @type, \nextTurn
    assert ..phase in <[postDahai postAnkan postKakan]>#
    return this

  apply: !-> with kyoku = @kyoku
    .._didNotHoujuu this
    if ..phase == \postDahai
      ..currPlayer = (..currPlayer + 1)%4
    ..currDecl.clear!
    ..phase = \preTsumo

  toPartials: -> for til 4 => @{type, seq}

  toMinimal: -> @{type, seq}
# }}}

export class ryoukyoku # {{{
  # server-initiated
  # full:
  #   renchan: Boolean -- assigned to kyoku.result.renchan
  #   reason: String -- assigned to kyoku.result.reason
  #
  # NOTE: checks are all performed by server
  # see also `kyuushuukyuuhai`, `howanpai`

  (kyoku, {@renchan, @reason}) -> with kyoku
    @type = \ryoukyoku
    @seq = ..seq
    assert not ..isClient
    @init kyoku

  init: (kyoku) -> with @kyoku = kyoku
    assert.equal @type, \ryoukyoku
    assert ..phase in <[preTsumo postDahai]>#
    return this

  apply: !-> with kyoku = @kyoku
    ..result{type, renchan, reason} = this
    .._end!

  toPartials: -> for til 4 => @{type, seq, renchan, reason}

  toMinimal: -> @{type, seq, renchan, reason}
# }}}

export class howanpai # {{{
  # server-initiated
  # full:
  #   renchan: Boolean
  #   delta: [4]Number
  #   juntehai: [4]?[]Pai -- reveals juntehai of only tenpai players

  (kyoku) -> with kyoku
    @type = \howanpai
    @seq = ..seq
    assert not ..isClient
    @init kyoku

  init: (kyoku) -> with @kyoku = kyoku
    assert.equal @type, \howanpai
    assert.equal ..phase, \preTsumo
    assert.equal ..nTsumoLeft, 0
    if not ..isClient
      ten = []
      noTen = []
      @juntehai = new Array 4
      for p til 4
        if ..playerHidden[p].tenpaiDecomp.tenpaiSet.length
          ten.push p
          @juntehai[p] = ..playerHidden[p].juntehai.slice!
        else
          noTen.push p
      # TODO: nagashimangan
      @delta = [0 0 0 0]
      if ten.length > 0 and noTen.length > 0
        HOWANPAI_TOTAL = ..rulevar.points.howanpai
        sTen = HOWANPAI_TOTAL / ten.length
        sNoTen = HOWANPAI_TOTAL / noTen.length
        for p in ten   => @delta[p] += sTen
        for p in noTen => @delta[p] -= sNoTen
      @renchan = ..chancha in ten
    else # client
      assert.lengthOf @delta, 4
      assert.lengthOf @juntehai, 4
    return this

  apply: !-> with kyoku = @kyoku
    ..result
      ..type = \ryoukyoku
      ..renchan = @renchan
      ..reason = \howanpai
    for p til 4 => ..result.delta[p] += @delta[p]
    # TODO: playerHidden (like agari)
    .._end!

  toPartials: -> for til 4 => @{type, seq, renchan, delta, juntehai}

  toMinimal: -> @{type, seq}
# }}}
