'use strict'
require! {
  '../pai': Pai
}

!function precond(kyoku)
  unless kyoku.phase == \postDahai
    throw Error "wrong phase #{kyoku.phase} (should be 'postDahai')"

function infer(kyoku, player, maxAkahai)
  unless 0 <= maxAkahai <= 2
    throw Error "invalid maxAkahai #maxAkahai"

  pai = kyoku.currPai
  PH = kyoku.playerHidden[player]

  nAll = PH.countEquiv(pai)
  unless nAll >= 2
    throw Error "not enough [#pai] (you have #nAll, need 2)"

  if pai.number == 5
    akahai = pai.akahai
    nAkahai = PH.count1(akahai)
    nAkahai <?= maxAkahai <? 2
  else
    nAkahai = 0

  switch nAkahai
  | 0 => [pai, pai]
  | 1 => [akahai, pai]
  | 2 => [akahai, akahai]

function createFuuro(kyoku, player, ownPai)
  [a, b] = ownPai
  c = kyoku.currPai
  if a.number > b.number then [a, b] = ownPai = [b, a]
  unless a.equivPai == b.equivPai == c.equivPai
    throw Error "[#a#b#c] is not valid koutsu"

  # verify juntehai has ownPai
  PH = kyoku.playerHidden[player]
  if not PH.isMock
    if a == b
      unless PH.count1(a) >= 2
        throw Error "you must have [#a#b] in juntehai"
    else
      unless PH.count1(a) > 0 and PH.count1(b) > 0
        throw Error "you must have [#a#b] in juntehai"

  return {
    type: \minko
    anchor: c.equivPai
    ownPai
    otherPai: c
    fromPlayer: kyoku.currPlayer
    kakanPai: null
  }

# ownPai: [2]Pai -- should satisfy the following:
#   both must exist in juntehai
#   `ownPai ++ kyoku.currPai` should form a koutsu (i.e. same `equivPai`)
export function create(kyoku, {
  player, ownPai, maxAkahai
})
  precond kyoku
  if kyoku.isClient and kyoku.me != player
    throw Error "not your turn"
  if player == kyoku.currPlayer
    throw Error "cannot pon self"
  seq = kyoku.seq - kyoku.currDecl.count

  ownPai = Pai.arrayN(ownPai, 2)
  {ownPai} = createFuuro kyoku, player, ownPai

  return {type: \pon, seq, player, ownPai}

# NOTE: only called through `declare.fromClient`
export function fromClient(kyoku, {
  type, seq
  player, ownPai
})
  precond kyoku
  if kyoku.isClient
    throw Error "must be called on server side"
  unless type == \pon
    throw Error "wrong type #type (should be 'pon')"
  # seq already validated in `declare.fromClient`
  if player == kyoku.currPlayer
    throw Error "cannot pon self"

  ownPai = Pai.arrayN(ownPai, 2)
  fuuro = createFuuro kyoku, player, ownPai

  return pon-server with {kyoku, seq, player, fuuro}

export function fromServer(kyoku, {
  type, seq
  player, ownPai
})
  precond kyoku
  unless kyoku.isClient
    throw Error "must be called on client side"
  unless type == \pon
    throw Error "wrong type #type (should be 'pon')"
  unless kyoku.seq == seq
    throw Error "seq mismatch: kyoku at #{kyoku.seq}, event at #seq"
  if player == kyoku.currPlayer
    throw Error "cannot pon self"

  ownPai = Pai.arrayN(ownPai, 2)
  fuuro = createFuuro kyoku, player, ownPai

  return pon-client with {kyoku, seq, player, fuuro}

pon-server =
  toLog: -> {type: \pon, @seq, @player, @ownPai}

  toClients: ->
    x = {type: \pon, @seq, @player, @ownPai}
    [x, x, x, x]

  apply: !->
    {kyoku, seq, player, {ownPai: [a, b]}:fuuro} = @
    seqBeforeDecl = kyoku.seq - kyoku.currDecl.count
    unless seq == seqBeforeDecl
      throw Error "seq mismatch: kyoku at #seqBeforeDecl, event at #seq"
    @seq = kyoku.seq

    kyoku._didNotHoujuu \pon
    kyoku.playerHidden[player].remove2 a, b
    kyoku.playerPublic[player]
      ..fuuro.push fuuro
      ..menzen = false
    kyoku.playerPublic[kyoku.currPlayer].lastSutehai.fuuroPlayer = player

    kyoku.currDecl.clear!
    kyoku.currPlayer = player
    kyoku.phase = \postChiPon

pon-client =
  apply: !->
    {kyoku, seq, player, {ownPai: [a, b]}:fuuro} = @
    unless kyoku.seq == seq
      throw Error "seq mismatch: kyoku at #{kyoku.seq}, event at #seq"

    kyoku._didNotHoujuu \pon
    kyoku.playerHidden[player].remove2 a, b
    kyoku.playerPublic[player]
      ..fuuro.push fuuro
      ..menzen = false
    kyoku.playerPublic[kyoku.currPlayer].lastSutehai.fuuroPlayer = player

    kyoku.currDecl.clear!
    kyoku.currPlayer = player
    kyoku.phase = \postChiPon
