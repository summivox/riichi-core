'use strict'
require! {
  '../pai': Pai
  '../split-wall': splitWall

  '../player-state/public': PlayerPublic
  '../player-state/hidden': PlayerHidden
  '../player-state/hidden-mock': PlayerHiddenMock
}

!function precond(kyoku)
  unless kyoku.phase == \begin
    throw Error "wrong phase #{kyoku.phase} (should be 'begin')"
  unless kyoku.seq == 0
    throw Error "wrong seq #{kyoku.seq} (should be 0)"

export function create(kyoku, {wall})
  # game event boilerplate
  precond kyoku
  if kyoku.isClient
    throw Error "can only be created on server side"

  if wall?
    # validate provided wall
    wall = Pai.arrayN wall, 136
  else
    # default to randomly shuffled wall
    wall = Pai.shuffleAll kyoku.rulevar.dora.akahai

  wallParts = splitWall wall

  return deal-server with {
    seq: 0, kyoku
    wall
    wallParts
    initDoraHyouji: [wallParts.doraHyouji.0]
  }

export function fromServer(kyoku, {
  type, seq, forPlayer: me
  haipai, initDoraHyouji
})
  # game event boilerplate
  precond kyoku
  unless type == \deal
    throw Error "wrong type #type (should be 'deal')"
  unless kyoku.isClient
    throw Error "must be called on client side"
  unless kyoku.me == me
    throw Error "wrong player #me (should be #{kyoku.me})"

  return deal-client with {
    seq: 0, kyoku, forPlayer
    haipai: Pai.arrayN haipai, 13
    initDoraHyouji: Pai.arrayN initDoraHyouji, 1
  }

deal-server =
  toLog: -> {type: \deal, seq: 0, @wall}

  toClients: ->
    {chancha} = @kyoku
    for p til 4 => {
      type: \deal, seq: 0, forPlayer: p
      haipai: @wallParts.haipai[(4 - chancha + p)%4]
      @initDoraHyouji
    }

  apply: !->
    # game event boilerplate
    {kyoku, {haipai}:wallParts, initDoraHyouji} = @
    unless kyoku.seq == 0
      throw Error "wrong seq #{kyoku.seq} (should be 0)"

    kyoku.wallParts = wallParts
    kyoku.playerHidden = for p til 4
      new PlayerHidden haipai[(4 - kyoku.chancha + p)%4]
    kyoku.playerPublic = for p til 4
      new PlayerPublic (4 - kyoku.chancha + p)%4
    kyoku._addDoraHyouji initDoraHyouji
    kyoku.phase = \preTsumo

deal-client =
  apply: !->
    # game event boilerplate
    {kyoku, haipai, initDoraHyouji} = @
    unless kyoku.seq == 0
      throw Error "wrong seq #{kyoku.seq} (should be 0)"

    kyoku.wallParts =
      piipai: [], rinshan: [], doraHyouji: [], uraDoraHyouji: []
    kyoku.playerHidden = for p til 4
      if p == kyoku.me
      then new PlayerHidden @haipai
      else new PlayerHiddenMock
    kyoku.playerPublic = for p til 4
      new PlayerPublic (4 - kyoku.chancha + p)%4
    kyoku._addDoraHyouji initDoraHyouji
    kyoku.phase = \preTsumo
