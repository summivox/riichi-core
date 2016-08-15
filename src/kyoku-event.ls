# # Events
require! {
  'chai': {assert}

  './pai': Pai
  './decomp': {decompTenpai}
  './split-wall': splitWall
  './util': {OTHER_PLAYERS}

  './kyoku-player-public': PlayerPublic
  './kyoku-player-hidden': PlayerHidden
  './kyoku-player-hidden-mock': PlayerHiddenMock
}

# Global TODO
# - explain doraHyouji piggybacking
# - more watertight `init` checks
# - assertion messages even though source is pretty natural language
#   - separate "ctor" from "minimal"/"canonical"
#  - fix doc of all events

Event = exports

/*TODO
Type of the event; same as event class name (written in snakeCase)

This is useful for de-/serialization from/to JSON, as Class/prototype is not
preserved in JSON.

@member {string} Event#type
*/
/*TODO
Sequence number of the event (0-based).
(TBD: xref kyoku seq)

@member {number} Event#seq
*/
/*TODO
After {@link Event#init}, stores a reference to the kyoku upon which this event
is initialized.

@member {Kyoku} Event#kyoku
*/
/*TODO
Construct an event on a kyoku instance using minimal info. Some event types
allow alternative convenience constructor args (e.g. `chi`). The constructor
always tail calls {@link Event#init} to validate input.

@method Event#(constructor)
@param {Kyoku} kyoku
@param {?object} args - dictionary containing minimal information needed to
construct this type of event (see each event type).
*/

/*TODO
Validates this event against given kyoku instance and gather additional
information relevant to the event.

Note that this event might not have been constructed on this kyoku instance.
This is why a 2-step construction is necessary. (TBD: justify more)

@method Event#init
@param {Kyoku} kyoku
*/


# XXX
# Notice that constructor args is also a minimal set of parameters that
# sufficiently determines the event (at current kyoku state on master)
#
# Data fields for each event are described in the following manner:
# common:
#   "minimal": args used to construct
#   "private": cached values
# master-initiated:
#   "partial": sent to replicates (does NOT include "minimal")
# replicate-initiated:
#   "full": sent to replicates (includes "minimal")


/*TODO
utility function for reconstructing event object with correct class
from e.g. serialized event
@param {Event} e
*/
export function reconstruct({type}:e)
  ctor = Event[type]
  if !ctor? then throw Error "invalid event '#type'"
  ctor:: with e

# deal {{{
export class deal
  /*TODO
  __master-initiated__: {@link Kyoku#deal}

  Setup the wall and deal the initial hand to each player.
  (TBD: xref splitWall)

  @class
  @implements Event
  @constructor
  */
  (kyoku, {@wall}) -> with kyoku
    assert not ..isReplicate
    @type = \deal
    @seq = 0
    @wall ?= Pai.shuffleAll ..rulevar.dora.akahai
    @init kyoku

  #/*TODO
  #@static
  #@class Event/deal/ctor
  #@prop {?Pai[]} wall - defaults to randomly shuffled wall
  #*/
  #/*TODO
  #@static
  #@class Event/deal/full
  #@prop {Pai[]} wall
  #@prop {WallParts} wallParts - (TBD: xref splitWall)
  #@prop {Pai[]} initDoraHyouji - contains 1 pai: first dora-hyoujihai
  #*/
  #/*TODO
  #@static
  #@class Event/deal/minimal
  #@prop {Pai[]} wall
  #*/
  #/*TODO
  #@static
  #@class Event/deal/partial
  #@prop {Pai[]} haipai - initial hand for this player
  #@prop {Pai[]} initDoraHyouji - see `deal/full`
  #*/

  /*TODO
  @method
  @param {Kyoku} kyoku
  */
  init: (kyoku) -> with @kyoku = kyoku
    assert.equal @type, \deal
    assert.equal ..seq, 0
    assert.equal ..phase, \begin
    if not ..isReplicate
      assert.lengthOf @wall, 136
      @wallParts = splitWall @wall
      @initDoraHyouji = [@wallParts.doraHyouji.0]
    else
      assert.lengthOf @haipai, 13
      assert.lengthOf @initDoraHyouji, 1
    return this

  apply: !-> with kyoku = @kyoku
    if not ..isReplicate
      ..wallParts = {haipai} = @wallParts
      ..playerHidden = for p til 4
        new PlayerHidden haipai[(4 - ..chancha + p)%4]
    else
      ..wallParts = {piipai: [], rinshan: [], doraHyouji: [], uraDoraHyouji: []}
      ..playerHidden = for p til 4
        if p == ..me
        then new PlayerHidden @haipai
        else new PlayerHiddenMock
    ..playerPublic = for p til 4
      new PlayerPublic (4 - ..chancha + p)%4
    .._addDoraHyouji @initDoraHyouji

    ..phase = \preTsumo

  toPartials: ->
    assert not @kyoku.isReplicate
    chancha = @kyoku.chancha
    for p til 4
      @{type, seq, initDoraHyouji} <<<
        haipai: @wallParts.haipai[(4 - chancha + p)%4]

  toMinimal: -> @{type, seq, wall}
# }}}

# tsumo {{{
export class tsumo
  # master-initiated
  # minimal: (null)
  # partial:
  #	  pai: ?Pai -- for current player only

  (kyoku) -> with kyoku
    assert not ..isReplicate
    assert ..nTsumoLeft > 0
    @type = \tsumo
    @seq = ..seq
    if ..rinshan
      @pai = ..wallParts.rinshan[*-1]
    else
      @pai = ..wallParts.piipai[*-1]
    @init kyoku

  init: (kyoku) -> with @kyoku = kyoku
    assert.equal @type, \tsumo
    assert.equal ..phase, \preTsumo
    assert ..nTsumoLeft > 0
    if ..isReplicate and ..me != ..currPlayer
      @pai ?= null # NOTE: eliminates `void`
    else
      assert.isNotNull @pai
    return this

  apply: !-> with kyoku = @kyoku
    if not ..isReplicate
      if ..rinshan
        ..wallParts.rinshan.pop!
      else
        ..wallParts.piipai.pop!
    ..nTsumoLeft--
    ..playerHidden[..currPlayer].tsumo @pai
    # NOTE: above is correct -- rinshan tsumo also discards last piipai,
    # which is reflected in `nTsumoLeft`

    ..currPai = @pai # NOTE: null on replicate-others -- this is okay
    ..phase = \postTsumo

  toPartials: ->
    assert not @kyoku.isReplicate
    for p til 4
      if p == @kyoku.currPlayer then @{type, seq, pai} else @{type, seq}

  toMinimal: -> @{type, seq}
# }}}

export class dahai # {{{
  # replicate-initiated
  # minimal:
  #   pai: ?Pai
  #   tsumokiri: Boolean
  #   riichi: Boolean
  # full:
  #   newDoraHyouji: ?[]Pai
  #
  # NOTE: tsumokiri is implied by either:
  # - pai: null
  # - tsumokiri: true
  # consistency must be ensured (see `init`)

  (kyoku, {@pai = null, @tsumokiri = false, @riichi = false}) -> with kyoku
    @type = \dahai
    @seq = ..seq
    if ..isReplicate
      assert.equal ..currPlayer, ..me,
        "cannot construct for others on replicate instance"
    @init kyoku

  init: (kyoku) -> with @kyoku = kyoku
    assert.equal @type, \dahai
    assert ..phase in <[postTsumo postChiPon]>#
    PP = ..playerPublic[..currPlayer]
    PH = ..playerHidden[..currPlayer]

    # tsumokiri shorthand handling
    if not ..isReplicate or ..me == ..currPlayer
      # can actually fill in @pai
      tsumohai = PH.tsumohai
      if !@pai?
        assert.isNotFalse @tsumokiri
        assert.isNotNull tsumohai
        @tsumokiri = true
        @pai = tsumohai
      if @tsumokiri
        assert.equal @pai, tsumohai
    else
      # tsumohai unknown (PlayerHiddenMock); only check basic consistency
      if !@pai?
        assert.isNotFalse @tsumokiri
        @tsumokiri = true
    pai = @pai

    if PP.riichi.accepted
      assert.isTrue @tsumokiri, "can only tsumokiri after riichi"
      assert.isFalse @riichi, "can only riichi once"

    if ..phase == \postChiPon and ..rulevar.banKuikae?
      assert not ..isKuikae(PP.fuuro[*-1], pai), "kuikae banned by rule"

    # master: try reveal doraHyouji
    if not ..isReplicate
      if @newDoraHyouji?
        assert.deepEqual @newDoraHyouji, ..getNewDoraHyouji(this)
      else
        @newDoraHyouji = ..getNewDoraHyouji this

    if PH not instanceof PlayerHidden then return this
    with (if @tsumokiri then PH.canTsumokiri! else PH.canDahai pai)
      assert ..valid, ..reason
    if @riichi
      assert.isTrue PP.menzen, "can only riichi when menzen"
      n = ..nTsumoLeft
      m = ..rulevar.riichi.minTsumoLeft
      assert n >= m, "need at least #m piipai left (only #n now)"
      if @tsumokiri
        decomp = PH.tenpaiDecomp # maintained by PlayerHidden
      else
        decomp = PH.decompTenpaiWithout pai # calculated on demand
      assert decomp?.tenpaiSet?.length > 0, "not tenpai if dahai is [#pai]"

    return this

  apply: !-> with kyoku = @kyoku
    PP = ..playerPublic[..currPlayer]
    PH = ..playerHidden[..currPlayer]

    if @riichi
      PP.riichi.declared = true
      if ..virgin and ..rulevar.riichi.double then PP.riichi.double = true

    PP.dahai @ # {pai, tsumokiri, riichi}
    if @tsumokiri then PH.tsumokiri! else PH.dahai @pai

    .._addDoraHyouji @newDoraHyouji

    ..rinshan = false
    ..currPai = @pai
    ..phase = \postDahai

  toPartials: -> for til 4
    @{type, seq, pai, tsumokiri, riichi, newDoraHyouji}

  toMinimal: -> @{type, seq, pai, tsumokiri, riichi}
# }}}

export class ankan # {{{
  # replicate-initiated
  # minimal:
  #   pai: Pai
  # full:
  #   newDoraHyouji: ?[]Pai
  # private:
  #   fuuro

  (kyoku, {@pai}) -> with kyoku
    @type = \ankan
    @seq = ..seq
    if ..isReplicate
      assert.equal ..currPlayer, ..me,
        "cannot construct for others on replicate instance"
    @init kyoku

  init: (kyoku) -> with @kyoku = kyoku
    assert.equal @type, \ankan
    assert.equal ..phase, \postTsumo
    PP = ..playerPublic[..currPlayer]
    PH = ..playerHidden[..currPlayer]

    assert ..nTsumoLeft > 0, "cannot kan when no piipai left"
    assert.isNotNull @pai
    pai = @pai = @pai.equivPai

    # build fuuro object
    if pai.isSuupai and pai.number == 5
      # include all akahai
      akahai = pai.akahai
      nAkahai = ..rulevar.dora.akahai[pai.S]
      ownPai = [akahai]*nAkahai ++ [pai]*(4 - nAkahai)
    else
      ownPai = [pai]*4
    @fuuro = {
      type: \ankan
      anchor: pai
      ownPai
      otherPai: null
      fromPlayer: null
      kakanPai: null
    }

    # master: try reveal doraHyouji
    if not ..isReplicate
      if @newDoraHyouji?
        assert.deepEqual @newDoraHyouji, ..getNewDoraHyouji(this)
      else
        @newDoraHyouji = ..getNewDoraHyouji this

    if PH not instanceof PlayerHidden then return this
    assert.equal PH.countEquiv(pai), 4,
      "need 4 [#pai] in juntehai"
    if PP.riichi.accepted
      assert.isTrue ..rulevar.riichi.ankan, "riichi ankan: not allowed by rule"
      # riichi ankan condition (simplified)
      #   basic: all tenpai decomps must have `pai` as koutsu
      #   okurikan: can only use tsumohai for ankan
      #
      # TODO: some impls have a more relaxed "basic" rule:
      #   tenpai/wait set must not change
      # "okurikan" rule above might still apply even with relaxed "basic"
      allKoutsu = PH.tenpaiDecomp.decomps.every -> it.mentsu.some ->
        it.type == \anko and it.anchor == pai
      assert allKoutsu, "riichi ankan: hand decomposition must not change"
      if not ..rulevar.riichi.okurikan
        assert.equal PH.tsumohai.equivPai, pai,
          "riichi ankan: okurikan not allowed by rule"

    return this

  apply: !-> with kyoku = @kyoku
    ..playerHidden[..currPlayer].removeEquivN @pai.equivPai, 4
    ..playerPublic[..currPlayer].fuuro.push @fuuro
    ..nKan++

    .._addDoraHyouji @newDoraHyouji

    ..rinshan = true
    ..currPai = @pai
    ..phase = \postAnkan

  toPartials: -> for til 4 => @{type, seq, pai, newDoraHyouji}

  toMinimal: -> @{type, seq, pai}
# }}}

export class kakan # {{{
  # replicate-initiated
  # minimal:
  #   pai: Pai -- see `kakanPai` in fuuro/kakan
  # full:
  #   newDoraHyouji: ?[]Pai
  # private:
  #   fuuro

  (kyoku, {@pai}) -> with kyoku
    @type = \kakan
    @seq = ..seq
    if ..isReplicate
      assert.equal ..currPlayer, ..me,
        "cannot construct for others on replicate instance"
    @init kyoku

  init: (kyoku) -> with @kyoku = kyoku
    assert.equal @type, \kakan
    assert.equal ..phase, \postTsumo
    PP = ..playerPublic[..currPlayer]
    PH = ..playerHidden[..currPlayer]

    assert.isNotNull @pai
    {equivPai} = pai = @pai

    assert ..nTsumoLeft > 0, "cannot kan when no piipai left"

    # find fuuro/minko object to be modified
    fuuro = PP.fuuro.find -> it.type == \minko and it.anchor == equivPai
    assert.isNotNull fuuro, "need existing minko of [#equivPai]"
    @fuuro = fuuro

    # master: try reveal doraHyouji
    if not ..isReplicate
      if @newDoraHyouji?
        assert.deepEqual @newDoraHyouji, ..getNewDoraHyouji(this)
      else
        @newDoraHyouji = ..getNewDoraHyouji this

    if PH instanceof PlayerHidden
      assert.equal PH.count1(pai), 1, "need [#pai] in juntehai"

    return this

  apply: !-> with kyoku = @kyoku
    ..playerHidden[..currPlayer].removeEquivN @pai.equivPai, 1
    @fuuro
      ..type = \kakan
      ..kakanPai = @pai
    ..nKan++

    .._addDoraHyouji @newDoraHyouji

    ..rinshan = true
    ..currPai = @pai
    ..phase = \postKakan

  toPartials: -> for til 4 => @{type, seq, pai, newDoraHyouji}

  toMinimal: -> @{type, seq, pai}
# }}}

export class tsumoAgari # {{{
  # replicate-initiated:
  # minimal: null
  # full:
  #   juntehai: PlayerHidden::juntehai
  #   tsumohai: PlayerHidden::tsumohai
  #   uraDoraHyouji: ?[]Pai -- only revealed ones if riichi
  # private:
  #   agari: Agari

  (kyoku) -> with kyoku
    @type = \tsumoAgari
    @seq = ..seq
    if ..isReplicate
      assert.equal ..currPlayer, ..me,
        "cannot construct for others on replicate instance"
    @init kyoku

  init: (kyoku) -> with @kyoku = kyoku
    assert.equal @type, \tsumoAgari
    assert.equal ..phase, \postTsumo

    with ..playerHidden[..currPlayer]
      if .. instanceof PlayerHidden
        @{juntehai, tsumohai} = ..
        tenpaiDecomp = ..tenpaiDecomp

    if not ..isReplicate
      @uraDoraHyouji = ..getUraDoraHyouji ..currPlayer

    assert.isArray @juntehai
    tenpaiDecomp ?= decompTenpai Pai.binsFromArray @juntehai
    assert @tsumohai.equivPai in tenpaiDecomp.tenpaiSet


    @agari = ..agari this
    assert.isNotNull @agari

    return this

  apply: !-> with kyoku = @kyoku
    # TODO: for replicate, also reconstruct PlayerHidden (ron too)
    if @uraDoraHyouji?.length
      ..uraDoraHyouji = @uraDoraHyouji
      @agari = ..agari this # recalculate agari due to changed uraDoraHyouji
    ..result.type = \tsumoAgari
    for p til 4 => ..result.delta[p] += @agari.delta[p]
    ..result.takeKyoutaku ..currPlayer
    ..result.renchan = ..currPlayer == ..chancha
    ..result.agari = @agari
    .._end!

  toPartials: -> for til 4 => @{type, seq, juntehai, tsumohai, uraDoraHyouji}

  toMinimal: -> @{type, seq}
# }}}

export class kyuushuukyuuhai # {{{
  # replicate-initiated
  # minimal: null
  # full:
  #   juntehai: PlayerHidden::juntehai
  #   tsumohai: PlayerHidden::tsumohai
  #
  # NOTE: this is the only replicate-initiated ryoukyoku; completely
  # disjoint from `ryoukyoku` event which covers master-initiated ryoukyoku

  (kyoku) -> with kyoku
    @type = \kyuushuukyuuhai
    @seq = ..seq
    if ..isReplicate
      assert.equal ..currPlayer, ..me,
        "cannot construct for others on replicate instance"
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
      @player ?= new Event[@what](kyoku, @args) .player
    assert.isNull ..currDecl[@player],
      "a player can only declare once during one turn"
    return this

  apply: !-> with kyoku = @kyoku
    ..currDecl.add @{what, player, args} # NOTE: `args` can be null

  toPartials: ->
    for p til 4
      if p == @player
        @{type, seq, what, player, args}
      else
        @{type, seq, what, player}

  toMinimal: -> @{type, seq, what, args}
# }}}

export class chi # {{{
  # replicate-declared
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
    if ..isReplicate
      assert.equal @player, ..me,
        "cannot construct for others on replicate instance"
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
  # replicate-declared
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
    if ..isReplicate
      assert.equal @player, ..me,
        "cannot construct for others on replicate instance"
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
  # replicate-declared
  # minimal:
  #   player: 0/1/2/3 -- must not be `currPlayer`
  # full:
  #   newDoraHyouji: ?[]Pai
  # private:
  #   fuuro

  (kyoku, {@player}) -> with kyoku
    @type = \daiminkan
    @seq = ..seq
    if ..isReplicate
      assert.equal @player, ..me,
        "cannot construct for others on replicate instance"
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

    # master: try reveal doraHyouji
    if not ..isReplicate
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
  # replicate-initiated
  # minimal:
  #   player: 0/1/2/3 -- must not be `currPlayer`
  #   isFirst, isLast: ?Boolean -- added by master during resolve
  # full:
  #   juntehai: PlayerHidden::juntehai
  #   uraDoraHyouji: ?[]Pai -- only revealed ones if riichi
  # private:
  #   agari: Agari

  (kyoku, {@player, @isFirst = true, @isLast = true}) -> with kyoku
    @type = \ron
    @seq = ..seq
    if ..isReplicate
      assert.equal @player, ..me,
        "cannot construct for others on replicate instance"
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
    if not ..isReplicate
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
  # master-initiated
  # NOTE: no member

  (kyoku) -> with kyoku
    @type = \nextTurn
    @seq = ..seq
    assert not ..isReplicate
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
  # master-initiated
  # full:
  #   renchan: Boolean -- assigned to kyoku.result.renchan
  #   reason: String -- assigned to kyoku.result.reason
  #
  # NOTE: checks are all performed by master
  # see also `kyuushuukyuuhai`, `howanpai`

  (kyoku, {@renchan, @reason}) -> with kyoku
    @type = \ryoukyoku
    @seq = ..seq
    assert not ..isReplicate
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
  # master-initiated
  # full:
  #   renchan: Boolean
  #   delta: [4]Number
  #   juntehai: [4]?[]Pai -- reveals juntehai of only tenpai players

  (kyoku) -> with kyoku
    @type = \howanpai
    @seq = ..seq
    assert not ..isReplicate
    @init kyoku

  init: (kyoku) -> with @kyoku = kyoku
    assert.equal @type, \howanpai
    assert.equal ..phase, \preTsumo
    assert.equal ..nTsumoLeft, 0
    if not ..isReplicate
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
    else # replicate
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
