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
  # NOTE: decompTenpai is not packed, but instead re-computed upon
  # construction. This causes it to be out of sync if right after chi/pon (see
  # PlayerHidden juntehai state diagram), but soon corrected after dahai.
  @packFromKyoku = (kyoku, me) ->
    pack = {me}
    pack{init, rulevar, globalPublic, playerPublic} = kyoku
    pack.playerHidden = kyoku.playerHidden.map (ph, i) ->
      if i == me
        ph{
          tsumohai, juntehai
          furiten, sutehaiFuriten, doujunFuriten, riichiFuriten
          declaredAction
        }
      else
        hasTsumohai: ph.tsumohai?
        nJuntehai: ph.juntehai.length
    pack

  # constructor
  # - fix serialized pai
  # - restore classes
  # - re-compute derived data
  (pack) ->
    @{me, init, rulevar} = pack
    @chancha = @init.chancha

    @globalHidden =
      piipai: []  # pop => `void`
      rinshan: [] # ^
      doraHyouji: []
      uraDoraHyouji: []
      lastDeclared:
        chi: null, pon: null, kan: null, ron: null
        clear: !-> @chi = @pon = @kan = @ron = null

    @globalPublic = Pai.cloneFix pack.globalPublic
    @playerPublic = pack.playerPublic.map (pp) -> PlayerPublic with pp
    @playerHidden = pack.playerHidden.map (ph, i) ->
      if i == @me
        # restore `bins` and `decompTenpai` using `juntehai` and `tsumohai`
        ph = Pai.cloneFix ph
        with new PlayerHidden ph.juntehai
          if ph.tsumohai then ..tsumo ph.tsumohai
          # copy the rest
          ..{
            furiten, sutehaiFuriten, doujunFuriten, riichiFuriten
            declaredAction
          } = ph
      else PlayerHiddenMock with ph
    @nextTurn!


  # game flow reconstruction from events:
  #
  # - actions before turn: automatic (no input needed)
  # - actions during turn: replay locally
  # - declarations during query: ignore (visible state not affected)
  # - query resolution:
  #   - receive chi/pon/daiminkan action: register then resolve
  #   - receive tsumo instead: resolve first

  resolve: !-> Kyoku::resolveQuery.call this
  handleAction: (action) !->
    player = action.player
    details = Pai.cloneFix action.details
    switch action.type
    | \tsumo =>
      if player != me and @globalPublic.state == \query then @resolve!
      # NOTE: `nextTurn` and `handleOwnTsumo` handle the rest

    | \dahai =>
      {pai, riichi, tsumokiri} = details
      if player != @me then @playerHidden[player].nextDahai = pai
      if tsumokiri then pai = null
      Kyoku::dahai.call this, player, pai, riichi

    | \chi =>
      @globalHidden.lastDeclared.chi = action
      @resolve!

    | \pon =>
      @globalHidden.lastDeclared.pon = action
      @resolve!

    | \kan =>
      switch details.type
      | \daiminkan =>
        @globalHidden.lastDeclared.kan = action
        @resolve!

      | \ankan =>
        {pai, ownPai} = details
        if player != @me then @playerHidden[player].nextRemoved = ownPai
        Kyoku::ankan.call this, player, pai

      | \kakan =>
        {kakanPai} = details
        if player != @me then @playerHidden[player].nextRemoved = [kakanPai]
        Kyoku::kakan.call this, player, kakanPai

  # own tsumo: overrides public tsumo event
  handleOwnTsumo: (tsumohai) !->
    if @globalPublic.state == \query then @resolve!
    @playerHidden[@me].tsumo tsumohai

  handleDoraHyouji: (doraHyouji) !->
    @globalPublic.doraHyouji.push doraHyouji


  # original game flow methods are kept unchanged
  emit: (!->)
  ::{_goto, _publishAction, _declareAction, nextTurn} = Kyoku:: #

  # `can`-methods: ignore others (none of "my" business)
  ignoreOthers = (fn) -> (player) ->
    if player == @me then valid: true else fn.apply this, arguments
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
