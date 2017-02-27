'use strict'

!function precond(kyoku)
  unless kyoku.phase == \preTsumo
    throw Error "wrong phase #{kyoku.phase}"
  unless kyoku.nTsumoLeft == 0
    throw Error "still #{kyoku.nTsumoLeft} tsumo left"

export function create(kyoku)
  precond kyoku
  if kyoku.isClient
    throw Error "can only be created on server side"

  nTen = 0
  nNoTen = 0
  juntehai = [null null null null]
  for p til 4
    PH = kyoku.playerHidden[p]
    if PH.tenpaiDecomp.tenpaiSet.length > 0
      nTen++
      juntehai[p] = PH.juntehai.slice!
    else
      nNoTen++

  # TODO: nagashimangan

  delta = [0 0 0 0]
  if nTen > 0 and nNoTen > 0
    HOWANPAI_TOTAL = kyoku.rulevar.points.howanpai
    sTen = HOWANPAI_TOTAL / nTen
    sNoTen = HOWANPAI_TOTAL / nNoTen
    for p til 4
      delta[p] = if juntehai[p]? then +sTen else -sNoTen
  renchan = juntehai[kyoku.chancha]?

  return howanpai-server with {
    kyoku.seq, kyoku
    delta, renchan, juntehai
  }

export function fromServer(kyoku, {
  type, seq
  delta, juntehai, renchan
})
  precond kyoku
  unless kyoku.isClient
    throw Error "must be called on client side"
  unless type == \howanpai
    throw Error "wrong type #type (should be 'howanpai')"
  unless kyoku.seq == seq
    throw Error "seq mismatch: kyoku at #{kyoku.seq}, event at #seq"

  unless delta?.length == 4
    throw Error "invalid delta #delta"
  for p til 4
    unless Number.isInteger delta[p]
      throw Error "invalid delta #delta"
    if juntehai[p]?
      unless juntehai[p].length > 0
        throw Error "invalid juntehai[#p] #{juntehai[p]}"
  renchan = !!renchan

  return howanpai-client with {
    kyoku.seq, kyoku
    delta, juntehai, renchan
  }

howanpai-server =
  toLog: -> {type: \howanpai, @seq}

  toClients: ->
    x = {type: \howanpai, @seq, @delta, @juntehai, @renchan}
    [x x x x]

  apply: !->
    {seq, kyoku, delta, renchan} = @
    unless kyoku.seq == seq
      throw Error "seq mismatch: kyoku at #{kyoku.seq}, event at #seq"

    kyoku.result
      ..type = \howanpai
      ..renchan = renchan
      ..reason = \howanpai
      for p til 4
        ..delta[p] += delta[p]
    kyoku._end!

howanpai-client =
  apply: howanpai-server.apply
  # TODO: reveal juntehai
