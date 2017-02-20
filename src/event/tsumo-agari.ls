'use strict'

!function precond(kyoku)
  unless kyoku.phase == \postTsumo
    throw Error "wrong phase #{kyoku.phase} (should be 'postTsumo')"

export function create(kyoku)
  # action event boilerplate
  precond kyoku
  if kyoku.isClient and kyoku.currPlayer != kyoku.me
    throw Error "wrong player #{kyoku.currPlayer} (should be #{kyoku.me})"

  # TODO: check if is valid agari

  return {type: \tsumoAgari, kyoku.seq}

export function fromClient(kyoku, {
  type, seq
})
  # action event boilerplate
  precond kyoku
  if kyoku.isClient
    throw Error "must be called on server side"
  unless type == \kakan
    throw Error "wrong type #type (should be 'kakan')"
  unless kyoku.seq == seq
    throw Error "seq mismatch: kyoku at #{kyoku.seq}, event at #seq"

  # TODO: check agari

  return agari-server with {
    kyoku.seq, kyoku
    pai
    agari
    uraDoraHyouji: kyoku.getUraDoraHyouji kyoku.currPlayer
  }

export function fromServer(kyoku, {
  type, seq,
  juntehai, tsumohai
  uraDoraHyouji
})
  # action event boilerplate
  precond kyoku
  unless kyoku.isClient
    throw Error "must be called on client side"
  unless type == \kakan
    throw Error "wrong type #type (should be 'kakan')"
  unless kyoku.seq == seq
    throw Error "seq mismatch: kyoku at #{kyoku.seq}, event at #seq"

  juntehai = Pai.array juntehai
  unless (tsumohai = Pai[tsumohai])? => throw Error "invalid tsumohai"
  uraDoraHyouji = Pai.array uraDoraHyouji

  # TODO: check agari

  return agari-client with {
    kyoku.seq, kyoku
    juntehai, tsumohai
    uraDoraHyouji
  }


agari-server =
  toLog: -> {type: \tsumoAgari, @seq}

  toClients: ->
    x = {
      type: \tsumoAgari, @seq
      # TODO: juntehai, tsumohai
    }

export class tsumoAgari # {{{
  # client-initiated:
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
    if ..isClient
      assert.equal ..currPlayer, ..me,
        "cannot construct for others on client instance"
    @init kyoku

  init: (kyoku) -> with @kyoku = kyoku
    assert.equal @type, \tsumoAgari
    assert.equal ..phase, \postTsumo

    with ..playerHidden[..currPlayer]
      if .. instanceof PlayerHidden
        @{juntehai, tsumohai} = ..
        tenpaiDecomp = ..tenpaiDecomp

    if not ..isClient
      @uraDoraHyouji = ..getUraDoraHyouji ..currPlayer

    assert.isArray @juntehai
    tenpaiDecomp ?= decompTenpai Pai.binsFromArray @juntehai
    assert @tsumohai.equivPai in tenpaiDecomp.tenpaiSet

    @agari = ..agari this
    assert.isNotNull @agari

    return this

  apply: !-> with kyoku = @kyoku
    # TODO: for client, also reconstruct PlayerHidden (ron too)
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
