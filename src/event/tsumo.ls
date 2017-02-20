'use strict'
require! {
  '../pai': Pai
}

!function precond(kyoku)
  unless kyoku.phase == \preTsumo
    throw Error "wrong phase #{kyoku.phase} (should be 'preTsumo')"

export function create(kyoku)
  # game event boilerplate
  precond kyoku
  if kyoku.isClient
    throw Error "can only be created on server side"

  pai = if kyoku.rinshan
    then kyoku.wallParts.rinshan[*-1]
    else kyoku.wallParts.piipai[*-1]

  return tsumo-server with {
    kyoku.seq, kyoku
    pai
  }

export function fromServer(kyoku, {
  type, seq, forPlayer: me
  pai
})
  # game event boilerplate
  precond kyoku
  unless kyoku.isClient
    throw Error "must be called on client side"
  unless kyoku.me == me
    throw Error "wrong player #me (should be #{kyoku.me})"
  unless type == \tsumo
    throw Error "wrong type #type (should be 'tsumo')"
  unless kyoku.seq == seq
    throw Error "seq mismatch: kyoku at #{kyoku.seq}, event at #seq"

  if kyoku.currPlayer == me
    unless (pai = Pai[pai])? => throw Error "invalid pai"
    return tsumo-client with {
      kyoku.seq, kyoku,
      pai
    }
  else
    if pai? => throw Error "event should not have pai"
    return tsumo-client with {
      kyoku.seq, kyoku
      pai: null
    }

tsumo-server =
  toLog: -> {type: \tsumo, @seq, @pai}

  toClients: ->
    {currPlayer} = @kyoku
    for p til 4
      if p == currPlayer
        then {type: \tsumo, @seq, forPlayer: p, @pai}
        else {type: \tsumo, @seq, forPlayer: p}

  apply: !->
    # game event boilerplate
    {seq, kyoku, pai} = @
    unless kyoku.seq == seq
      throw Error "seq mismatch: kyoku at #{kyoku.seq}, event at #seq"

    if kyoku.rinshan
      kyoku.wallParts.rinshan.pop!
    else
      kyoku.wallParts.piipai.pop!

    kyoku.nTsumoLeft--
    kyoku.playerHidden[kyoku.currPlayer].tsumo pai
    kyoku.currPai = pai
    kyoku.phase = \postTsumo

tsumo-client =
  apply: !->
    # game event boilerplate
    {seq, kyoku, pai} = @
    unless kyoku.seq == seq
      throw Error "seq mismatch: kyoku at #{kyoku.seq}, event at #seq"

    kyoku.nTsumoLeft--
    kyoku.playerHidden[kyoku.currPlayer].tsumo pai
    kyoku.currPai = pai
    kyoku.phase = \postTsumo
