'use strict'

!function precond(kyoku)
  unless kyoku.phase in <[postTsumo postChiPon]>
    throw Error "wrong phase #{kyoku.phase} \
      (should be 'postTsumo' or 'postChiPon')"

!function validate(kyoku, pai, tsumokiri, riichi)
  PP = kyoku.playerPublic[kyoku.currPlayer]

  if PP.riichi.accepted
    unless tsumokiri
      throw Error "can only tsumokiri after riichi"
    if riichi
      throw Error "can only riichi once"

  if riichi and not PP.menzen
    throw Error "can only riichi when menzen"

  if kyoku.phase == \postChiPon and kyoku.isKuikae(PP.fuuro[*-1], pai)
    throw Error "cannot kuikae"

  PH = kyoku.playerHidden[kyoku.currPlayer]
  if PH.isMock then return

  if tsumokiri
    then PH.assertCanTsumokiri
    else PH.assertCanDahai pai

  if riichi
    n = kyoku.nTsumoLeft
    m = kyoku.rulevar.riichi.minTsumoLeft
    if n < m
      throw Error "need at least #m piipai left (only #n left now)"

    if tsumokiri
      decomp = PH.tenpaiDecomp # maintained by PlayerHidden
    else
      decomp = PH.decompTenpaiWithout pai # calculated on demand

    unless decomp?.tenpaiSet?.length > 0
      throw Error "not tenpai if dahai is [#pai]"

export function create(kyoku, {pai, tsumokiri, riichi})
  # action event boilerplate
  precond kyoku
  if kyoku.isClient and kyoku.currPlayer != kyoku.me
    throw Error "wrong player #{kyoku.currPlayer} (should be #{kyoku.me})"

  # tsumokiri shorthand and validation
  {tsumohai} = kyoku.playerHidden[kyoku.currPlayer]
  if !pai?
    if tsumokiri == false
      throw Error "invalid input: no pai and explicit no tsumokiri"
    tsumokiri = true
    if !tsumohai?
      throw Error "tsumokiri but no tsumohai"
    pai = tsumohai
  if tsumokiri and pai != tsumohai
    throw Error "tsumokiri: pai [#pai] is not tsumohai [#tsumohai]"

  unless (pai = Pai[pai])? => throw Error "invalid pai"
  tsumokiri = !!tsumokiri
  riichi = !!riichi
  validate kyoku, pai, tsumokiri, riichi

  return {type: \dahai, kyoku.seq, pai, tsumokiri, riichi}

export function fromClient(kyoku, {
  type, seq
  pai, tsumokiri, riichi
})
  # action event boilerplate
  precond kyoku
  if kyoku.isClient
    throw Error "must be called on server side"
  unless type == \dahai
    throw Error "wrong type #type (should be 'dahai')"
  unless kyoku.seq == seq
    throw Error "seq mismatch: kyoku at #{kyoku.seq}, event at #seq"

  unless (pai = Pai[pai])? => throw Error "invalid pai"
  tsumokiri = !!tsumokiri
  riichi = !!riichi
  validate kyoku, pai, tsumokiri, riichi

  return dahai-server with {
    kyoku.seq, kyoku
    pai, tsumokiri, riichi
    newDoraHyouji: kyoku.getNewDoraHyouji \dahai
  }

export function fromServer(kyoku, {
  type, seq
  pai, tsumokiri, riichi
  newDoraHyouji
})
  # action event boilerplate
  precond kyoku
  unless kyoku.isClient
    throw Error "must be called on client side"
  unless type == \dahai
    throw Error "wrong type #type (should be 'dahai')"
  unless kyoku.seq == seq
    throw Error "seq mismatch: kyoku at #{kyoku.seq}, event at #seq"

  unless (pai = Pai[pai])? => throw Error "invalid pai"
  tsumokiri = !!tsumokiri
  riichi = !!riichi
  validate kyoku, pai, tsumokiri, riichi

  newDoraHyouji = Pai.array newDoraHyouji

  return dahai-client with {
    kyoku.seq, kyoku
    pai, tsumokiri, riichi
    newDoraHyouji
  }

dahai-server =
  toLog: -> {type: \dahai, @seq, @pai, @tsumokiri, @riichi}

  toClients: ->
    x = {type: \dahai, @seq, @pai, @tsumokiri, @riichi, @newDoraHyouji}
    [x, x, x, x]

  apply: !->
    # action event boilerplate
    {seq, kyoku, pai, tsumokiri, riichi, newDoraHyouji} = @
    unless kyoku.seq == seq
      throw Error "seq mismatch: kyoku at #{kyoku.seq}, event at #seq"

    PP = kyoku.playerPublic[kyoku.currPlayer]
    PH = kyoku.playerHidden[kyoku.currPlayer]

    if riichi
      PP.riichi.declared = true
      if kyoku.virgin and kyoku.rulevar.riichi.double
        PP.riichi.double = true

    PP.dahai pai, tsumokiri, riichi
    if tsumokiri then PH.tsumokiri! else PH.dahai pai

    kyoku._addDoraHyouji newDoraHyouji

    kyoku.rinshan = false
    kyoku.currPai = pai
    kyoku.phase = \postDahai

dahai-client =
  apply: dahai-server.apply
