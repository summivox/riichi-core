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
      doraHyouji: []
      uraDoraHyouji: []
      lastDeclared:
        CHI: null, PON: null, KAN: null, RON: null
        clear: !-> @CHI = @PON = @KAN = @RON = null

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
    @advance!


  # game flow reconstruction from events:
  #
  # - actions before turn: automatic (no input needed)
  # - actions during turn: replay locally
  # - declarations during query: ignore (visible state not affected)
  # - query resolution:
  #   - register result of resolution upon action event
  #   - `resolveQuery` upon resolved event

  handleAction: (player, action) !->
    details = Pai.cloneFix action.details
    switch action.type
    | @TSUMO, @RINSHAN_TSUMO =>
      if player != @me then @playerHidden[player].tsumo!
      # (otherwise: see `handleOwnTsumo`)

    | @DAHAI =>
      {pai, riichi, tsumokiri} = details
      if player != @me then @playerHidden[player].nextDahai = pai
      if tsumokiri then pai = null
      Kyoku::dahai.call this, player, pai, riichi

    | @CHI =>
      @globalHidden.lastDeclared.CHI = action

    | @PON =>
      @globalHidden.lastDeclared.PON = action

    | @KAN =>
      switch details.type
      | @DAIMINKAN =>
        @globalHidden.lastDeclared.KAN = action

      | @ANKAN =>
        {pai, ownPai} = details
        if player != @me then @playerHidden[player].nextRemoved = ownPai
        Kyoku::ankan.call this, player, pai

      | @KAKAN =>
        {kakanPai} = details
        if player != @me then @playerHidden[player].nextRemoved = [kakanPai]
        Kyoku::kakan.call this, player, kakanPai

  handleResolved: Kyoku::resolveQuery

  # special cases:
  # - "my" own tsumo: separately fed and patched after `_begin`
  # - doraHyouji revealed upon event
  handleOwnTsumo: (tsumohai) ->
    @playerHidden[@me].tsumo tsumohai
  handleDoraHyouji: (doraHyouji) ->
    @globalPublic.doraHyouji.push doraHyouji



  # original game flow methods are kept unchanged
  emit: (!->)
  ::{advance, _goto, _publishAction, _declareAction, _begin} = Kyoku:: #

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

  # doraHyouji: ignored (handled by `handleDoraHyouji`)
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
