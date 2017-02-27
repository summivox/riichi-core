'use strict'

!function precond(kyoku)
  unless kyoku.phase in <[postDahai postAnkan postKakan]>
    throw Error "wrong phase #{kyoku.phase}"

export function create(kyoku)
  precond kyoku
  if kyoku.isClient
    throw Error "can only be created on server side"

  return next-turn-server with {
    kyoku.seq, kyoku
  }

export function fromServer(kyoku, {
  type, seq
})
  precond kyoku
  unless kyoku.isClient
    throw Error "must be called on client side"
  unless type == \nextTurn
    throw Error "wrong type #type (should be 'nextTurn')"
  unless kyoku.seq == seq
    throw Error "seq mismatch: kyoku at #{kyoku.seq}, event at #seq"

  return next-turn-client with {
    kyoku.seq, kyoku
  }

next-turn-server =
  toLog: -> {type: \nextTurn, @seq}

  toClients: ->
    x = {type: \nextTurn, @seq}
    [x x x x]

  apply: !->
    {seq, kyoku} = @
    unless kyoku.seq == seq
      throw Error "seq mismatch: kyoku at #{kyoku.seq}, event at #seq"

    kyoku._didNotHoujuu \nextTurn
    if kyoku.phase == \postDahai
      kyoku.currPlayer = (kyoku.currPlayer + 1)%4
    kyoku.currDecl.clear!
    kyoku.phase = \preTsumo

next-turn-client =
  apply: next-turn-server.apply
