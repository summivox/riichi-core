'use strict'
require! {
  './agari': Agari
  '../player-state/hidden': PlayerHidden
}

!function precond(kyoku)
  unless kyoku.phase == \postTsumo
    throw Error "wrong phase #{kyoku.phase} (should be 'postTsumo')"

export function create(kyoku)
  # action event boilerplate
  precond kyoku
  if kyoku.isClient and kyoku.currPlayer != kyoku.me
    throw Error "wrong player #{kyoku.currPlayer} (should be #{kyoku.me})"

  agari = Agari.create kyoku, kyoku.currPlayer
  if !agari?
    throw Error "cannot tsumoAgari"

  return {type: \tsumoAgari, kyoku.seq}

export function fromClient(kyoku, {
  type, seq
})
  # action event boilerplate
  precond kyoku
  if kyoku.isClient
    throw Error "must be called on server side"
  unless type == \tsumoAgari
    throw Error "wrong type #type (should be 'tsumoAgari')"
  unless kyoku.seq == seq
    throw Error "seq mismatch: kyoku at #{kyoku.seq}, event at #seq"

  agari = Agari.create kyoku, kyoku.currPlayer
  if !agari?
    throw Error "not agari"

  return tsumo-agari-server with {
    seq, kyoku
    agari
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

  juntehai = Pai.array juntehai .sort Pai.compare
  unless (tsumohai = Pai[tsumohai])? => throw Error "invalid tsumohai"
  uraDoraHyouji = Pai.array uraDoraHyouji

  agari = Agari.create kyoku, kyoku.currPlayer

  return tsumo-agari-client with {
    seq, kyoku
    juntehai, tsumohai
    uraDoraHyouji
    agari
  }

tsumo-agari-server =
  toLog: -> {type: \tsumoAgari, @seq}

  toClients: ->
    player = @kyoku.currPlayer
    {juntehai, tsumohai} = @kyoku.playerHidden[player]
    x = {
      type: \tsumoAgari, @seq
      juntehai, tsumohai
      uraDoraHyouji: kyoku.getUraDoraHyouji player
    }
    [x, x, x, x]

  apply: !->
    Agari.score @kyoku, @agari, false
    player = @kyoku.currPlayer
    with @kyoku.result
      ..type = \tsumoAgari
      ..agari = @agari
      ..renchan = @kyoku.currPlayer == @kyoku.chancha
      for p til 4 => ..delta[p] += @agari.delta[p]
      ..takeKyoutaku player
    @kyoku._end!

tsumo-agari-client =
  apply: !->
    # backfill uraDoraHyouji
    if @uraDoraHyouji?.length
      @kyoku.uraDoraHyouji ?= @uraDoraHyouji

    # rebuild playerHidden
    player = @kyoku.currPlayer
    if @kyoku.playerHidden[player].isMock
      @kyoku.playerHidden[player] =
        with new PlayerHidden @juntehai => ..tsumo @tsumohai

    Agari.score @kyoku, @agari, false
    with @kyoku.result
      ..type = \tsumoAgari
      ..agari = @agari
      ..renchan = @kyoku.currPlayer == @kyoku.chancha
      for p til 4 => ..delta[p] += @agari.delta[p]
      ..takeKyoutaku player
    @kyoku._end!
