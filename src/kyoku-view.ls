# KyokuView
#
# A KyokuView instance is derived from a full Kyoku instance but contains only
# information visible from a particular player's perspective ("me"). It is
# intended to be kept in sync with the Kyoku instance by applying events
# emitted from it (over a communication channel and/or thru serialization)
#
# It provides:
# - Invariants:
#   - `init`
#   - `rulevar`
# - Up-to-date game state:
#   - `globalPublic`
#   - `playerPublic`
#   - `playerHidden`:
#     - for "me": real instance (juntehai + tsumohai + furiten)
#     - for "others": mock-up instance (only juntehai/tsumohai count)
# - All `can`-methods for "me" with same interface as Kyoku
#
# It does NOT support:
# - performing actions directly on KyokuView (submit to Kyoku instead)
# - re-emitting of event (use original events from Kyoku instead)
# - kyoku-ending actions/events (no need to keep state anymore)
#
# NOTE: KyokuView is highly coupled and dependent on the internal workings of
# Kyoku, and attempts to reuse as much code from Kyoku as possible.

require! {
  '../package.json': {version: VERSION}
  './pai': Pai

  './kyoku': Kyoku
  './kyoku-player-hidden': PlayerHidden
  './kyoku-player-public': PlayerPublic
  './kyoku-player-hidden-mock': PlayerHiddenMock
}

module.exports = class KyokuView
  # initialization:
  # Kyoku instance => packed representation => KyokuView constructor
  #
  # NOT included:
  # - rulevar: provide separately to constructor
  # - playerHidden[me]{bins, decompTenpai}: recomputed
  # - playerHidden[others]: mock only
  #
  # NOTE:
  # - decompTenpai can be out of sync if packed right after chi/pon (see
  #   PlayerHidden juntehai state diagram); this is corrected after dahai
  @packFromKyoku = (kyoku, me) ->
    if kyoku.VERSION != VERSION # TODO: semver
      throw Error "riichi-core: KyokuView: packFromKyoku: incompatible version 
        (ours: #VERSION; their: #{kyoku.VERSION}"
    pack = {me}
    if kyoku.phase != \end
      pack{
        gameStateBefore
        seq, phase, currPlayer, lastAction
        globalPublic, playerPublic
      } = kyoku
      pack.playerHidden = kyoku.playerHidden.map (ph, i) ->
        if i == me
          ph{
            tsumohai, juntehai
            furiten, sutehaiFuriten, doujunFuriten, riichiFuriten
          }
        else
          hasTsumohai: ph.tsumohai?
          nJuntehai: ph.juntehai.length
    else
      pack{
        gameStateBefore
        seq, phase
        result, gameStateAfter
      } = kyoku
    pack

  # constructor
  # - fix serialized pai
  # - restore classes
  # - re-compute omitted
  (@rulevar, pack) ->
    @{me, gameStateBefore, seq, phase, currPlayer} = pack

    @chancha = @gameStateBefore.chancha

    # NOTE: [] always reads/pops `void`
    @globalHidden =
      piipai: []
      rinshan: []
      doraHyouji: []
      uraDoraHyouji: []
    @globalPublic = Pai.cloneFix pack.globalPublic
    @playerPublic = pack.playerPublic.map (pp) ->
      PlayerPublic with Pai.cloneFix pp
    @playerHidden = pack.playerHidden.map (ph, i) ->
      if i == @me
        # restore `bins` and `decompTenpai` using `juntehai` and `tsumohai`
        ph = Pai.cloneFix ph
        with new PlayerHidden ph.juntehai
          ..tsumo ph.tsumohai
          # copy furiten flags
          ..{
            furiten, sutehaiFuriten, doujunFuriten, riichiFuriten
          } = ph
      else PlayerHiddenMock with ph

    @lastAction = Pai.cloneFix pack.lastAction
    @lastDecl =
      chi: null, pon: null, kan: null, ron: null
      0: null, 1: null, 2: null, 3: null
      clear: !-> @chi = @pon = @kan = @ron = @0 = @1 = @2 = @3 = null


  # game flow reconstruction from events
  resolve: !-> Kyoku::resolveQuery.call @
  handleAction: (action) ->
    if action.seq != @seq + 1 then return false
    {type, player, details}:action = Pai.cloneFix action
    switch type
    | \tsumo =>
      if player == @me
        {pai, rinshan} = details
        if rinshan
          @globalHidden.rinshan.push pai
        else
          @globalHidden.piipai.push pai
      switch @phase
      | \begin => @nextTurn!
      | \query => @resolve! # indirectly calls `@nextTurn`

    | \dahai =>
      {pai, riichi, tsumokiri} = details
      if player != @me then @playerHidden[player].nextDahai = pai
      if tsumokiri then pai = null
      Kyoku::dahai.call @, player, pai, riichi

    | \chi, \pon =>
      @_declareAction action
      @resolve!

    | \kan =>
      switch details.type
      | \daiminkan =>
        @_declareAction action
        @resolve!

      | \ankan =>
        {pai, ownPai} = details
        if player != @me then @playerHidden[player].nextRemoved = ownPai
        Kyoku::ankan.call @, player, pai

      | \kakan =>
        {kakanPai} = details
        if player != @me then @playerHidden[player].nextRemoved = [kakanPai]
        Kyoku::kakan.call @, player, kakanPai

    return true

  handleDoraHyouji: (doraHyouji) !->
    @globalPublic.doraHyouji.push doraHyouji


  # original game flow methods are kept unchanged
  _emit: (!->)
  ::{_publishAction, _declareAction, nextTurn} = Kyoku:: #

  # `can`-methods: ignore others (none of "my" business)
  ignoreOthers = (fn) -> (player) ->
    if player != @me then valid: true else fn.apply @, &
  <[
    canDahai canAnkan canKakan canTsumoAgari canKyuushuukyuuhai
    canChi canPon canDaiminkan canRon
  ]>.forEach -> KyokuView::[it] = ignoreOthers Kyoku::[it]

  # actions during query: called in event handlers above for replay
  ::{_chi, _pon, _daiminkan, resolveQuery} = Kyoku:: #


  # internal state updates: case-by-case analysis

  # doraHyouji: ignored (lack information; `handleDoraHyouji` instead)
  _revealDoraHyouji: (!->)

  # furiten:
  # - after dahai: ignore others (lack information)
  # - after resolve: no change needed (others faked by PlayerHiddenMock)
  _updateFuritenDahai: ignoreOthers Kyoku::_updateFuritenDahai
  _updateFuritenResolve: Kyoku::_updateFuritenResolve

  # riichi: unchanged (all public)
  ::{_checkAcceptedRiichi, _clearIppatsu} = Kyoku:: #

  # ryoukyoku: ignored (kyoku-ending)
  _checkRyoukyoku: (!->)

  # predicates: unchanged (all public)
  ::{
    suufonrenta, suukaikan, suuchariichi
    isKuikae, isTrueFirstTsumo, suukantsuCandidate, ronPai
  } = Kyoku:: #

  # agari wrapper: ignore others (none of "my" business)
  _agari: ignoreOthers Kyoku::_agari
