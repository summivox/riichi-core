'use strict'
require! {
  '../pai': Pai
}

!function precond(kyoku)
  unless kyoku.phase == \postDahai
    throw Error "wrong phase #{kyoku.phase} (should be 'postDahai')"

function validate(kyoku, player)
  pai = kyoku.currPai
  anchor = pai.equivPai

  PH = kyoku.playerHidden[player]
  unless PH.countEquiv(anchor) == 3
    throw Error "need 3 [#anchor] in juntehai"

function createFuuro(kyoku, player)
  pai = kyoku.currPai
  anchor = pai.equivPai

  PH = kyoku.playerHidden[player]
  unless PH.countEquiv(anchor) == 3
    throw Error "need 3 [#anchor] in juntehai"

  if anchor.isSuupai and anchor.number == 5
    akahai = anchor.akahai
    nOwnAkahai = kyoku.rulevar.dora.akahai[anchor.S] - (pai.number == 0)
    switch nOwnAkahai
    | 0 => ownPai = [anchor anchor anchor]
    | 1 => ownPai = [akahai anchor anchor]
    | 2 => ownPai = [akahai akahai anchor]
    | 3 => ownPai = [akahai akahai akahai]
    | 4 => ownPai = [akahai akahai akahai]
  else
    ownPai = [anchor anchor anchor]

  return {
    type: \daiminkan
    anchor
    ownPai
    otherPai: pai
    fromPlayer: kyoku.currPlayer
    kakanPai: null
  }

# ownPai: [2]Pai -- should satisfy the following:
#   both must exist in juntehai
#   `ownPai ++ kyoku.currPai` should form a koutsu (i.e. same `equivPai`)
export function create(kyoku, {
  player
})
  precond kyoku
  if kyoku.isClient and kyoku.me != player
    throw Error "not your turn"
  if player == kyoku.currPlayer
    throw Error "cannot daiminkan self"
  seq = kyoku.seq - kyoku.currDecl.count

  validate kyoku, player

  return {type: \daiminkan, seq, player}

# NOTE: only called through `declare.fromClient`
export function fromClient(kyoku, {
  type, seq
  player
})
  precond kyoku
  if kyoku.isClient
    throw Error "must be called on server side"
  unless type == \daiminkan
    throw Error "wrong type #type (should be 'daiminkan')"
  # seq already validated in `declare.fromClient`
  if player == kyoku.currPlayer
    throw Error "cannot daiminkan self"

  fuuro = createFuuro kyoku, player
  newDoraHyouji = kyoku.getNewDoraHyouji \daiminkan

  return daiminkan-server with
    {type: \daiminkan, kyoku, seq, player, fuuro, newDoraHyouji}

export function fromServer(kyoku, {
  type, seq
  player
  newDoraHyouji
})
  precond kyoku
  unless kyoku.isClient
    throw Error "must be called on client side"
  unless type == \daiminkan
    throw Error "wrong type #type (should be 'daiminkan')"
  unless kyoku.seq == seq
    throw Error "seq mismatch: kyoku at #{kyoku.seq}, event at #seq"
  if player == kyoku.currPlayer
    throw Error "cannot daiminkan self"

  fuuro = createFuuro kyoku, player, ownPai
  newDoraHyouji = Pai.array newDoraHyouji

  return daiminkan-client with {kyoku, seq, player, fuuro, newDoraHyouji}

daiminkan-server =
  toLog: -> {type: \daiminkan, @seq, @player}

  toClients: ->
    x = {type: \daiminkan, @seq, @player, @newDoraHyouji}
    [x, x, x, x]

  apply: !->
    {kyoku, seq, player, fuuro, newDoraHyouji} = @
    seqBeforeDecl = kyoku.seq - kyoku.currDecl.count
    unless seq == seqBeforeDecl
      throw Error "seq mismatch: kyoku at #seqBeforeDecl, event at #seq"
    @seq = kyoku.seq

    kyoku._didNotHoujuu \daiminkan
    kyoku.playerHidden[player].removeEquivN fuuro.anchor, 3
    kyoku.playerPublic[player]
      ..fuuro.push fuuro
      ..menzen = false
    kyoku.playerPublic[kyoku.currPlayer].lastSutehai.fuuroPlayer = player
    kyoku.nKan++

    kyoku._addDoraHyouji newDoraHyouji

    kyoku.rinshan = true
    kyoku.currDecl.clear!
    kyoku.currPlayer = player
    kyoku.phase = \preTsumo # NOTE: no need to ask for ron

daiminkan-client =
  apply: !->
    {kyoku, seq, player, fuuro, newDoraHyouji} = @
    unless kyoku.seq == seq
      throw Error "seq mismatch: kyoku at #{kyoku.seq}, event at #seq"

    kyoku._didNotHoujuu \daiminkan
    kyoku.playerHidden[player].removeEquivN fuuro.anchor, 3
    kyoku.playerPublic[player]
      ..fuuro.push fuuro
      ..menzen = false
    kyoku.playerPublic[kyoku.currPlayer].lastSutehai.fuuroPlayer = player
    kyoku.nKan++

    kyoku._addDoraHyouji newDoraHyouji

    kyoku.rinshan = true
    kyoku.currDecl.clear!
    kyoku.currPlayer = player
    kyoku.phase = \preTsumo # NOTE: no need to ask for ron
