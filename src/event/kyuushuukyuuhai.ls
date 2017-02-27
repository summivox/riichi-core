'use strict'

!function precond(kyoku)
  unless kyoku.phase == \postTsumo
    throw Error "wrong phase #{kyoku.phase} (should be 'postTsumo')"
  unless kyoku.virgin
    throw Error "can only kyuushuukyuuhai during first \
      uninterrupted tsumo round"

function validate(kyoku)
  PH = kyoku.playerHidden[kyoku.currPlayer]
  if PH.isMock then return PH

  {juntehai, tsumohai} = PH

  # NOTE: counting *unique* yaochuupai
  nYaochuu = 0
  bins = Pai.binsFromArray juntehai
  bins[tsumohai.S][tsumohai.N]++
  for x in Pai.yaochuuFromBins bins
    if x > 0 then nYaochuu++

  unless nYaochuu >= 9
    throw Error "need at least 9 distinct yaochuupai (you have #nYaochuu)"

  return PH

export function create(kyoku)
  # action event boilerplate
  precond kyoku
  if kyoku.isClient and kyoku.currPlayer != kyoku.me
    throw Error "wrong player #{kyoku.currPlayer} (should be #{kyoku.me})"

  validate kyoku

  return {type: \kyuushuukyuuhai, kyoku.seq}

export function fromClient(kyoku, {
  type, seq
})
  # action event boilerplate
  precond kyoku
  if kyoku.isClient
    throw Error "must be called on server side"
  unless type == \kyuushuukyuuhai
    throw Error "wrong type #type (should be 'kyuushuukyuuhai')"
  unless kyoku.seq == seq
    throw Error "seq mismatch: kyoku at #{kyoku.seq}, event at #seq"

  {juntehai, tsumohai} = validate kyoku

  return kyuushuukyuuhai-server with {
    kyoku.seq, kyoku
    juntehai, tsumohai
  }

export function fromServer(kyoku, {
  type, seq
  juntehai, tsumohai
})
  # action event boilerplate
  precond kyoku
  unless kyoku.isClient
    throw Error "must be called on client side"
  unless type == \kyuushuukyuuhai
    throw Error "wrong type #type (should be 'kyuushuukyuuhai')"
  unless kyoku.seq == seq
    throw Error "seq mismatch: kyoku at #{kyoku.seq}, event at #seq"

  validate kyoku
  juntehai = Pai.arrayN 13
  unless (tsumohai = Pai[tsumohai])? => throw Error "invalid tsumohai"

  return kyuushuukyuuhai-client with {
    kyoku.seq, kyoku
    juntehai, tsumohai
  }

kyuushuukyuuhai-server =
  toLog: -> {type: \kyuushuukyuuhai, @seq}

  toClients: ->
    x = {type: \kyuushuukyuuhai, @seq, @juntehai, @tsumohai}
    [x, x, x, x]

  apply: !->
    # action event boilerplate
    {seq, kyoku} = @
    unless kyoku.seq == seq
      throw Error "seq mismatch: kyoku at #{kyoku.seq}, event at #seq"

    kyoku.result <<< {
      type: \ryoukyoku
      reason: \kyuushuukyuuhai
      renchan: true
    }
    kyoku._end!

kyuushuukyuuhai-client =
  apply: kyuushuukyuuhai-server.apply
