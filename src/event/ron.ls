'use strict'
require! {
  '../pai': Pai
}

!function precond(kyoku)
  unless kyoku.phase in <[postDahai postAnkan postKakan]>
    throw Error "wrong phase #{kyoku.phase}
      \ (should be 'postDahai', 'postAnkan', or 'postKakan')"


########################################
# before resolution: 1 event for each player declaring ron

export function create(kyoku, {
  player
})
  precond kyoku
  if kyoku.isClient and kyoku.me != player
    throw Error "not your turn"
  if player == kyoku.currPlayer
    throw Error "cannot ron self"
  seq = kyoku.seq - kyoku.currDecl.count

  agari = Agari.create kyoku, player
  if !agari?
    throw Error "not agari"

  return {type: \ron, seq, player}

# NOTE: only called through `declare.fromClient`
export function fromClient(kyoku, {
  type, seq
  player, ownPai
})
  precond kyoku
  if kyoku.isClient
    throw Error "must be called on server side"
  unless type == \ron
    throw Error "wrong type #type (should be 'ron')"
  # seq already validated in `declare.fromClient`
  if player == kyoku.currPlayer
    throw Error "cannot ron self"

  agari = Agari.create kyoku, player
  if !agari?
    throw Error "not agari"

  return {type: \ron, player, toLog: -> @}


########################################
# after resolution: 1 event for all players declaring ron

export function create-multi(kyoku, players)
  precond kyoku
  if kyoku.isClient
    throw Error "must be called on server side"

  rons = for player in players
    if player == kyoku.currPlayer
      throw Error "cannot ron self"
    agari = Agari.create kyoku, player
    if !agari?
      throw Error "not agari"

    {player, agari, juntehai: kyoku.playerHidden[player].juntehai}

# NOTE: might be multi-ron when imported from server (resolved)
export function fromServer(kyoku, {
  type, seq
  rons # [] of {player, juntehai}
  uraDoraHyouji
})
  precond kyoku
  unless kyoku.isClient
    throw Error "must be called on client side"
  unless type == \ron
    throw Error "wrong type #type (should be 'ron')"
  unless kyoku.seq == seq
    throw Error "seq mismatch: kyoku at #{kyoku.seq}, event at #seq"

  rons .= map ->
    player: it.player
    juntehai: Pai.array it.juntehai .sort Pai.compare
    agari: Agari.create kyoku, it.player

  uraDoraHyouji = Pai.array uraDoraHyouji

  agari = Agari.create kyoku, kyoku.currPlayer

  return ron-client with {
    seq, kyoku
    rons
    uraDoraHyouji
    agari
  }

ron-server =
  toLog: -> {type: \ron, @seq, players: @rons.map (.player)}

ron-client =
  apply: !->
    {kyoku, seq, player} = @
    unless kyoku.seq == seq
      throw Error "seq mismatch: kyoku at #{kyoku.seq}, event at #seq"

    kyoku._didNotHoujuu \ron
    kyoku.playerHidden[player].remove2 a, b
    kyoku.playerPublic[player]
      ..fuuro.push fuuro
      ..menzen = false
    kyoku.playerPublic[kyoku.currPlayer].lastSutehai.fuuroPlayer = player

    kyoku.currDecl.clear!
    kyoku.currPlayer = player
    kyoku.phase = \postChiPon
