'use strict'
require! {
  '../pai': Pai
}

!function precond(kyoku)
  unless kyoku.phase == \postTsumo
    throw Error "wrong phase #{kyoku.phase} (should be 'postTsumo')"
  unless kyoku.nTsumoLeft > 0
    throw Error "cannot kan when no tsumo is left"

!function validate(kyoku, pai)
  riichi = kyoku.playerPublic[kyoku.currPlayer].riichi.accepted

  if riichi
    unless kyoku.rulevar.riichi.ankan
      throw Error "riichi ankan: not allowed by rule"

  PH = kyoku.playerHidden[kyoku.currPlayer]
  if PH.isMock then return

  unless PH.countEquiv(pai) == 4
    throw Error "need 4 [#pai] in juntehai"

  if riichi
    # riichi ankan rulevar:
    #   basic: all tenpai decomps must have `pai` as koutsu
    #   no okurikan: on top of "basic", can only use tsumohai for ankan
    #
    # TODO: some impls have a more relaxed "basic" rule:
    #   overall tenpai set must not change
    #
    # "okurikan" rule above might still apply even with relaxed "basic"
    koutsuInAllDecomps =
      PH.tenpaiDecomp.decomps.every -> it.mentsu.some ->
        it.type == \anko and it.anchor == pai
    unless koutsuInAllDecomps
      throw Error "riichi ankan: hand decomposition must not change"
    if not kyoku.rulevar.riichi.okurikan and PH.tsumohai.equivPai != pai
      throw Error "riichi ankan: okurikan not allowed by rule"

function createFuuro(kyoku, pai)
  if pai.isSuupai and pai.number == 5
    # include all akahai
    akahai = pai.akahai
    nAkahai = kyoku.rulevar.dora.akahai[pai.S]
    ownPai = for i til 4
      if i < nAkahai then akahai else pai
  else
    ownPai = [pai, pai, pai, pai]
  return {
    type: \ankan
    anchor: pai
    ownPai
    otherPai: null
    fromPlayer: null
    kakanPai: null
  }

export function create(kyoku, {pai})
  # action event boilerplate
  precond kyoku
  if kyoku.isClient and kyoku.currPlayer != kyoku.me
    throw Error "wrong player #{kyoku.currPlayer} (should be #{kyoku.me})"

  unless (pai = Pai[pai]?.equivPai)? => throw Error "invalid pai"
  validate kyoku, pai

  return {type: \ankan, kyoku.seq, pai}

export function fromClient(kyoku, {
  type, seq
  pai
})
  # action event boilerplate
  precond kyoku
  if kyoku.isClient
    throw Error "must be called on server side"
  unless type == \ankan
    throw Error "wrong type #type (should be 'ankan')"
  unless kyoku.seq == seq
    throw Error "seq mismatch: kyoku at #{kyoku.seq}, event at #seq"

  unless (pai = Pai[pai])? => throw Error "invalid pai"
  validate kyoku, pai

  return ankan-server with {
    kyoku.seq, kyoku
    pai
    newDoraHyouji: kyoku.getNewDoraHyouji \ankan
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
  unless type == \ankan
    throw Error "wrong type #type (should be 'ankan')"
  unless kyoku.seq == seq
    throw Error "seq mismatch: kyoku at #{kyoku.seq}, event at #seq"

  unless (pai = Pai[pai])? => throw Error "invalid pai"
  validate kyoku, pai

  newDoraHyouji = Pai.array newDoraHyouji

  return ankan-client with {
    kyoku.seq, kyoku
    pai
    newDoraHyouji
  }

ankan-server =
  toLog: -> {type: \ankan, @seq, @pai}

  toClients: ->
    x = {type: \ankan, @seq, @pai, @newDoraHyouji}
    [x, x, x, x]

  apply: !->
    # action event boilerplate
    {seq, kyoku, pai, newDoraHyouji} = @
    unless kyoku.seq == seq
      throw Error "seq mismatch: kyoku at #{kyoku.seq}, event at #seq"

    kyoku.playerHidden[kyoku.currPlayer].removeEquivN pai.equivPai, 4
    kyoku.playerPublic[kyoku.currPlayer].fuuro.push createFuuro kyoku, pai
    kyoku.nKan++

    kyoku._addDoraHyouji newDoraHyouji

    kyoku.rinshan = true
    kyoku.currPai = pai
    kyoku.phase = \postAnkan

ankan-client =
  apply: ankan-server.apply
