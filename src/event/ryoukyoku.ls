'use strict'

!function precond(kyoku)
  unless kyoku.phase in <[preTsumo postDahai]>
    throw Error "wrong phase #{kyoku.phase}"

export function create(kyoku, {reason, renchan})
  precond kyoku
  if kyoku.isClient
    throw Error "can only be created on server side"

  return ryoukyoku-server with {
    kyoku.seq, kyoku
    reason, renchan
  }

export function fromServer(kyoku, {
  type, seq
  reason, renchan
})
  precond kyoku
  unless kyoku.isClient
    throw Error "must be called on client side"
  unless type == \ryoukyoku
    throw Error "wrong type #type (should be 'ryoukyoku')"
  unless kyoku.seq == seq
    throw Error "seq mismatch: kyoku at #{kyoku.seq}, event at #seq"

  renchan = !!renchan

  return ryoukyoku-client with {
    kyoku.seq, kyoku
    reason, renchan
  }

ryoukyoku-server =
  toLog: -> {type: \ryoukyoku, @seq, @reason, @renchan}

  toClients: ->
    x = {type: \ryoukyoku, @seq, @reason, @renchan}
    [x x x x]

  apply: !->
    {seq, kyoku, reason, renchan} = @
    unless kyoku.seq == seq
      throw Error "seq mismatch: kyoku at #{kyoku.seq}, event at #seq"

    kyoku.result <<< {type: \ryoukyoku, reason, renchan}
    kyoku._end!

ryoukyoku-client =
  apply: ryoukyoku-server.apply
