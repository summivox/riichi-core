'use strict'
require! {
  '../pai': Pai
}

!function precond(kyoku)
  unless kyoku.phase == \postTsumo
    throw Error "wrong phase #{kyoku.phase} (should be 'postTsumo')"
  unless kyoku.nTsumoLeft > 0
    throw Error "cannot kan when no tsumo is left"

!function findFuuro(kyoku, pai)
  fuuro = kyoku.playerPublic[kyoku.currPlayer].fuuro.find ->
    it.type == \minko and it.anchor == equivPai
  if !fuuro? then throw Error "need existing minko of [#equivPai]"
  return fuuro

!function validate(kyoku, pai)
  findFuuro kyoku, pai

  PH = kyoku.playerHidden[kyoku.currPlayer]
  if PH.isMock then return

  unless PH.count1(pai) == 1
    throw Error "need [#pai] in juntehai"

export function create(kyoku, {pai})
  # action event boilerplate
  precond kyoku
  if kyoku.isClient and kyoku.currPlayer != kyoku.me
    throw Error "wrong player #{kyoku.currPlayer} (should be #{kyoku.me})"

  unless (pai = Pai[pai]?.equivPai)? => throw Error "invalid pai"
  validate kyoku, pai

  return {type: \kakan, kyoku.seq, pai}

export function fromClient(kyoku, {
  type, seq
  pai
})
  # action event boilerplate
  precond kyoku
  if kyoku.isClient
    throw Error "must be called on server side"
  unless type == \kakan
    throw Error "wrong type #type (should be 'kakan')"
  unless kyoku.seq == seq
    throw Error "seq mismatch: kyoku at #{kyoku.seq}, event at #seq"

  unless (pai = Pai[pai])? => throw Error "invalid pai"
  validate kyoku, pai

  return kakan-server with {
    kyoku.seq, kyoku
    pai
    newDoraHyouji: kyoku.getNewDoraHyouji \kakan
  }

export function fromServer(kyoku, {
  type, seq
  pai
  newDoraHyouji
})
  # action event boilerplate
  precond kyoku
  unless kyoku.isClient
    throw Error "must be called on client side"
  unless type == \kakan
    throw Error "wrong type #type (should be 'kakan')"
  unless kyoku.seq == seq
    throw Error "seq mismatch: kyoku at #{kyoku.seq}, event at #seq"

  unless (pai = Pai[pai])? => throw Error "invalid pai"
  validate kyoku, pai

  newDoraHyouji = Pai.array newDoraHyouji

  return kakan-client with {
    kyoku.seq, kyoku
    pai
    newDoraHyouji
  }

kakan-server =
  toLog: -> {type: \kakan, @seq, @pai}

  toClients: ->
    x = {type: \kakan, @seq, @pai, @newDoraHyouji}
    [x, x, x, x]

  apply: !->
    # action event boilerplate
    {seq, kyoku, pai, newDoraHyouji} = @
    unless kyoku.seq == seq
      throw Error "seq mismatch: kyoku at #{kyoku.seq}, event at #seq"

    kyoku.playerHidden[kyoku.currPlayer].removeEquivN pai.equivPai, 1
    findFuuro(kyoku, pai) <<<
      type: \kakan
      kakanPai: pai
    kyoku.nKan++

    kyoku._addDoraHyouji newDoraHyouji

    kyoku.rinshan = true
    kyoku.currPai = pai
    kyoku.phase = \postKakan

kakan-client =
  apply: kakan-server.apply
