# Kyoku {round}
# Implements core game state flow and logic
#
# A Kyoku instance is both the "table" and the "referee" of a round of game.
# Responsiblity:
# - maintaining all states and transitions according to game rules
# - providing interfaces for both carrying out and announcing player actions
#   and declarations
#
# NOTE: This is a God Class out of necessity and essential complexity.

require! {
  'events': {EventEmitter}
  './pai': Pai
  './wall': splitWall
  './agari': Agari
  './util': {Enum, OTHER_PLAYERS}

  './kyoku-player-hidden': PlayerHidden
  './kyoku-player-public': PlayerPublic
}

module.exports = class Kyoku implements EventEmitter::
  (@init, @rulevar, wall = null) ->
    # events:
    #   state transition: see state machine below
    #     turn(player)
    #     query(player, action)
    #     resolved(): see `resolveQuery` (additional seq point)
    #     end(result, next)
    #   player action:
    #     action(player, details)
    #     declare(player, type)
    #   extra info:
    #     tsumo(player, pai): NOT broadcast, see `_begin`
    #     doraHyouji(pai)
    #
    # NOTE:
    # - tsumo has 2 events:
    #   - action(player, {type: tsumo, nPiipaiLeft}): broadcast for all
    #   - tsumo(player, pai): intended for only that player
    EventEmitter.call @

    # `init` (immutable): default to first kyoku in game
    #   bakaze: 0/1/2/3 => E/S/W/N {prevailing wind}
    #   chancha: 0/1/2/3 {dealer}
    #   honba: >= 0
    #   kyoutaku: >= 0
    #   points: array of each player's points **at the start of kyoku**
    # e.g. {1 2 2 1} =>
    # - Nan {South} 3 Kyoku {Round}
    # - current dealer = player 2
    # - 2 Honba (dealer has renchan'd twice)
    # - 1*1000 kyoutaku {riichi bet} on table
    #
    # NOTE:
    # - kyoutaku (deduction of player's points due to riichi) is not reflected in
    #   `init.points` as `init` is immutable; see `@globalPublic.delta`
    # - wall defaults to shuffled but can be provided (e.g. for testing)
    p0 = rulevar.setup.points
    init ?=
      bakaze: 0
      chancha: 0
      honba: 0
      kyoutaku: 0
      points: [p0, p0, p0, p0]

    # dora handling:
    # - @globalHidden.doraHyouji/uraDoraHyouji: all 5 stacks
    # - @globalPublic.doraHyouji: only revealed ones
    #
    # rule variations:
    #   `.dora.akahai`
    if !wall? then wall = Pai.shuffleAll @rulevar.dora.akahai
    {haipai, piipai, rinshan, doraHyouji, uraDoraHyouji} = splitWall wall

    # id of chancha {dealer}
    @chancha = chancha = init.chancha
    # jikaze {seat wind} of each player
    jikaze =
      (4 - chancha)%4
      (5 - chancha)%4
      (6 - chancha)%4
      (7 - chancha)%4

    # all mutable states
    @globalHidden = {
      piipai
      rinshan
      doraHyouji
      uraDoraHyouji

      # see `resolveQuery`
      lastDeclared:
        CHI: null, PON: null, KAN: null, RON: null
        clear: !-> @CHI = @PON = @KAN = @RON = null
    }
    @globalPublic = {
      # visible on the table:
      nPiipaiLeft: 70
      nKan: 0
      doraHyouji: [doraHyouji[0]]
      # riichi-related:
      kyoutaku: init.kyoutaku # +1000 when riichi accepted
      delta: [0 0 0 0] # -1000 when riichi accepted (for each player)
      nRiichi: 0 # +1 when riichi accepted

      # game progression (see below for details)
      player: chancha
      state: @BEGIN
      actionLog: []
      lastAction: {type: null} # == actionLog[*-1]
    }
    @playerHidden = [new PlayerHidden haipai[jikaze[i]] for i til 4]
    @playerPublic = [new PlayerPublic        jikaze[i]  for i til 4]

    # result: null when still playing
    # common fields:
    #   type: \TSUMO_AGARI \RON \RYOUKYOKU
    #   delta: array of points increment for each player
    #   kyoutaku: how much kyoutaku {riichi bet} should remain on field
    #   renchan: true/false
    # details:
    #   TSUMO_AGARI: agari object
    #   RON: array of agari objects by natural turn order
    #   RYOUKYOKU: reason
    @result = null

    # next: `init` for next kyoku, or null if whole game ends
    @next = null

    # done

  # NOTE: underscore-prefixed methods should not be called from outside

  # state machine
  #   BEGIN: player starts turn normally or after kan
  #   TURN : awaiting player decision after tsumo
  #   QUERY: awaiting other players' declaration (chi/pon/kan/ron)
  #   END  : game has finished
  ::<<<< @STATES = Enum <[ BEGIN TURN QUERY END ]> #
  advance: !->
    {player, state} = @globalPublic
    switch state
    | @BEGIN  => @_begin!
    | @TURN   => @emit \turn , player
    | @QUERY  => @emit \query, player, @globalPublic.lastAction
    | @END    => @emit \end  , @result, @next
    | _ => throw Error "riichi-core: kyoku: advance: bad state (#state)"
  _goto: -> @globalPublic.state = it

  # actions: {type, player, details}
  #   details for each type:
  #     TSUMO/RINSHAN_TSUMO: # of piipai left
  #     DAHAI: {pai: Pai, riichi: true/false, tsumokiri: true/false}
  #     CHI/PON/KAN: fuuro object (see PlayerPublic)
  #     TSUMO_AGARI/RON: agari object
  #     RYOUKYOKU: reason (= \kyuushuukyuuhai)
  ::<<<< @ACTIONS = Enum <[
    TSUMO RINSHAN_TSUMO TSUMO_AGARI DAHAI CHI PON KAN RON RYOUKYOKU
  ]> #

  # called after action executed
  _publishAction: !->
    with @globalPublic
      ..actionLog.push it
      ..lastAction = it
    @emit \action, it.player, it

  # called after @QUERY action *declared* (see below)
  # NOTE: details of declared action should NOT be published
  # (see `PlayerHidden::declaredAction`)
  _declareAction: ({type, player}:action) !->
    @playerHidden[player].declaredAction = action
    @globalHidden.lastDeclared[type] = action
    @emit \declare, player, type

  # fuuro types: see `PlayerPublic::fuuro`
  ::<<<< @FUURO_TYPES = Enum <[ SHUNTSU MINKO DAIMINKAN KAKAN ANKAN ]> #


  # actions before player's turn
  _begin: !->
    if @_checkRyoukyoku! then return

    # tsumo {draw} from either piipai or rinshan
    # NOTE:
    # - rinshan tsumo also removes one piipai from the other end so that
    #   total piipai count always decreases by 1 for each tsumo
    # - separate events (see above for events definition)
    {player, lastAction} = @globalPublic
    isAfterKan = (lastAction.type == @KAN)
    n = --@globalPublic.nPiipaiLeft
    with @globalHidden
      if isAfterKan
        pai = ..rinshan.pop()
        ..piipai.shift()
        @_publishAction {type: @RINSHAN_TSUMO, player, details: n}
      else
        pai = ..piipai.pop()
        @_publishAction {type: @TSUMO, player, details: n}
    @playerHidden[player].tsumo pai
    @emit \tsumo, player, pai
    @_goto @TURN # NOTE: don't advance yet

    # if only option while in riichi is dahai, do it without asking
    # FIXME: okurikan is perma-banned here -- need more checks if you want it
    # enabled instead!
    if @playerPublic[player].riichi.accepted
    and not @canAnkan player, pai .valid
    and not @canTsumoAgari player .valid
      if @rulevar.riichi.autoTsumokiri # DEBUG
        return @dahai player, null
    @advance!

  # mark end of kyoku and calculate `next`
  # rule variations:
  #   `.setup`
  _end: (@result) !->
    {setup:
      points: {origin}
      end
    } = @rulevar
    @next = do ~>
      {bakaze, chancha, honba, kyoutaku, points} = @init
      points .= slice!
      for i til 4
        if (points[i] += result.delta[i]) < 0
          # strictly negative points not allowed
          return null

      newBakaze = false
      if result.renchan
        honba++
        # all-last oya top
        if end.oyaTop and bakaze == end.bakaze - 1 and chancha == 3
        and util.max(points) == points[3]
          return null
      else
        if result.type == \RYOUKYOKU then honba++
        else honba = 0
        if ++chancha == 4
          chancha = 0
          bakaze++
          newBakaze = true

      if bakaze < end.bakaze then void
      else if bakaze < end.overtime
        if (newBakaze or end.suddenDeath)
        and points.some (> origin) then return null
      else return null

      # next kyoku
      return {bakaze, chancha, honba, kyoutaku, points}
    @_goto @END ; @advance!




  # method pair with & without `can`-prefix: player action interface
  # NOTE: neither method rely on information hidden from player, i.e. they do
  # not access `@globalHidden` or `@playerHidden[someOtherPlayer]`
  #
  # - `can`-method judge if the action is valid
  #   return: {valid, reason}
  #
  # - prefix-less method:
  #   - call `can`-method first to determine if the action is valid;
  #     invalid => throw error with reason
  #   - perform action & update state
  #   - update `lastAction` and emits event

  # common check for `can`-methods: if player can make any move at all
  _checkTurn: (player) ->
    with @globalPublic
      if player != ..player or ..state != @TURN
        return valid: false, reason: "not your turn"
    return valid: true
  _checkQuery: (player) ->
    with @globalPublic
      # NOTE: not typo!
      if player == ..player or ..state != @QUERY
        return valid: false, reason: "not your turn"
    # extra: should only declare once
    if (action = @playerHidden[player].declaredAction?)
      return valid: false, reason: "you already declared #{action.type}"

    return valid: true


  # player actions available in normal turn:
  # - dahai (including riichi declaration)
  # - kakan/ankan
  # - tsumoAgari
  # - kyuushuukyuuhai (the only dedicated ryoukyoku action)

  # dahai {discard}
  # - pai: null => tsumokiri
  # - riichi: true => declare riichi before discard
  #
  # NOTE: when publishing event, `null` for tsumokiri is replaced with actual
  # pai as it becomes revealed; `tsumokiri` flag is set instead
  #
  # rule variations:
  #   `.riichi`
  canDahai: (player, pai, !!riichi) ->
    with @_checkTurn player => if not ..valid then return ..
    tsumokiri = !pai?

    with @playerHidden[player]
      with (if tsumokiri then ..canTsumokiri! else ..canDahai pai)
        if not ..valid then return ..
      if riichi
        if (n = @globalPublic.nPiipaiLeft) < (m = @rulevar.riichi.minPiipaiLeft)
          return valid: false, reason: "not enough piipai (#n left, need #m)"
        if tsumokiri
          decomp = ..decompTenpai
        else
          decomp = ..decompTenpaiWithout pai
        if !decomp? or decomp.wait.length == 0
          return valid: false, reason: "not tenpai if dahai is [#pai]"
    with @globalPublic.lastAction
      if ..type in [@CHI, @PON] and ..player == player
      and @isKuikae ..details, pai
        return valid: false, reason: "kuikae"
    return valid: true

  dahai: (player, pai, !!riichi) !->
    {valid, reason} = @canDahai player, pai, riichi
    if not valid
      throw Error "riichi-core: kyoku: dahai: #reason"
    tsumokiri = !pai?

    if riichi then with @playerPublic[player].riichi
      ..declared = true
      if @isTrueFirstTsumo player then ..double = true
    if tsumokiri
      @playerPublic[player].tsumokiri pai = @playerHidden[player].tsumokiri!
    else
      @playerPublic[player].dahai @playerHidden[player].dahai pai

    @_publishAction {
      type: @DAHAI, player
      details: {pai, riichi, tsumokiri}
    }
    @playerPublic[player].riichi.ippatsu = false
    @_updateFuritenDahai player
    @_revealDoraHyouji!
    @_goto @QUERY ; @advance!

  # ankan
  # rule variations:
  #   `.yaku.kokushiAnkan`: ankan can be chankan'd by kokushi musou
  #   `.riichi.ankan/okurikan`
  canAnkan: (player, pai) ->
    with @_checkTurn player => if not ..valid then return ..
    if not pai?.paiStr
      return valid: false, reason: "invalid pai"

    with @globalPublic
      if ..nPiipaiLeft <= 0
        return valid: false, reason: "cannot kan when no piipai left"
      if ..nKan >= 4 and not @suukantsuCandidate!?
        return valid: false, reason: "cannot kan when no rinshan left"
      if (type = ..lastAction.type) in [@CHI, @PON]
        return valid: false, reason: "cannot ankan after #type"
    pai .= equivPai
    ph = @playerHidden[player]
    if (n = ph.countEquiv pai) < 4
      return valid: false, reason: "not enough [#pai] (you have #n, need 4)"
    if @playerPublic[player].riichi.accepted
      if not @rulevar.riichi.ankan
        return valid: false, reason: "riichi ankan: not allowed by rule"
      # riichi ankan condition (simplified)
      #   basic: all tenpai decomps must have `pai` as koutsu
      #   okurikan: can only use tsumo for ankan
      d = ph.decompTenpai
      allKoutsu = d.decomps.every -> it.mentsu.some ->
        it.type == \koutsu and it.pai == pai
      if not allKoutsu
        return valid: false, reason: "riichi ankan: change of form"
      if @rulevar.riichi.okurikan and ph.tsumohai.equivPai != pai
        return valid: false, reason: "riichi ankan: okurikan"
    return valid: true

  ankan: (player, pai) !->
    {valid, reason} = @canAnkan player, pai
    if not valid
      throw Error "riichi-core: kyoku: ankan: #reason"
    if ++@globalPublic.nKan > 4 then return @_checkRyoukyoku!

    pai .= equivPai
    ownPai = @playerHidden[player].removeEquivN pai, 4
    @playerPublic[player].fuuro.push fuuro = {
      type: @ANKAN, pai, ownPai, otherPai: null
    }

    @_publishAction {type: @KAN, player, details: fuuro}
    @_revealDoraHyouji @ANKAN
    @_clearIppatsu!
    if @rulevar.yaku.kokushiAnkan then @_goto @QUERY else @_goto @BEGIN
    @advance!

  # kakan
  # NOTE: code mostly parallel with ankan
  canKakan: (player, pai) ->
    with @_checkTurn player => if not ..valid then return ..
    if not pai?.paiStr
      return valid: false, reason: "invalid pai"

    with @globalPublic
      if ..nPiipaiLeft <= 0
        return valid: false, reason: "cannot kan when no piipai left"
      if ..nKan >= 4 and not @suukantsuCandidate!?
        return valid: false, reason: "cannot kan when no rinshan left"
      if (type = ..lastAction.type) in [@CHI, @PON]
        return valid: false, reason: "cannot ankan after #type"
    pai .= equivPai
    found = false
    for fuuro in @playerPublic[player].fuuro
      if fuuro.type == @MINKO and fuuro.pai == pai
        found = true
        break
    if not found
      return valid: false, reason: "must have minko of 3*[#pai]"
    if (n = @playerHidden[player].countEquiv pai) != 1
      return valid: false, reason: "must have one [#pai] in juntehai"
    return valid: true, fuuro: fuuro

  kakan: (player, pai) !->
    {valid, reason, fuuro} = @canKakan player, pai
    if not valid
      throw Error "riichi-core: kyoku: kakan: #reason"
    if ++@globalPublic.nKan > 4 then return @_checkRyoukyoku!

    pai .= equivPai
    [kakanPai] = @playerHidden[player].removeEquivN pai, 1
    with fuuro
      ..type = @KAKAN
      ..kakanPai = kakanPai

    @_publishAction {type: @KAN, player, details: fuuro}
    @_revealDoraHyouji @KAKAN
    @_clearIppatsu!
    @_goto @QUERY ; @advance!

  # tsumoAgari
  canTsumoAgari: (player) ->
    with @_checkTurn player => if not ..valid then return ..
    if not (agari = @_agari player, @playerHidden[player].tsumohai)
      return valid: false, reason: "no yaku"
    return valid: true, agari: agari
  tsumoAgari: (player) !->
    {valid, reason, agari} = @canTsumoAgari player
    if not valid
      throw Error "riichi-core: kyoku: tsumoAgari: #reason"
    delta = @globalPublic.delta.slice!
    for i til 4 => delta[i] += agari.delta[i]
    delta[player] += @globalPublic.kyoutaku
    @_end {
      type: \TSUMO_AGARI
      delta
      kyoutaku: 0 # taken
      renchan: @chancha == player
      details: agari
    }

  # kyuushuukyuuhai ryoukyoku
  #   - available at player's true first tsumo
  #   - player must have at least 9 **KINDS** of yaochuupai
  # rule variations:
  #   `.ryoukyoku.kyuushuukyuuhai`
  canKyuushuukyuuhai: (player) ->
    with @_checkTurn player => if not ..valid then return ..
    switch @rulevar.ryoukyoku.kyuushuukyuuhai
    | false => return valid: false, reason: "not allowed by rule"
    | true  => renchan = true
    | _     => renchan = false
    if not @isTrueFirstTsumo player
      return valid: false, reason: "not your true first tsumo"
    nYaochuu = @playerHidden[player].yaochuu!filter (>0) .length
    if nYaochuu < 9
      return valid: false, reason: "only #nYaochuu*yaochuu (>= 9 needed)"
    return valid: true, renchan: renchan

  kyuushuukyuuhai: (player) !->
    {valid, reason, renchan} = @canKyuushuukyuuhai player
    if not valid
      throw Error "riichi-core: kyoku: kyuushuukyuuhai: #reason"
    @_publishAction {type: @RYOUKYOKU, player, details: \kyuushuukyuuhai}
    @_end {
      type: \RYOUKYOKU
      delta: @globalPublic.delta.slice!
      kyoutaku: @globalPublic.kyoutaku # remains on table
      renchan
      details: \kyuushuukyuuhai
    }


  # actions available to other players after current player's dahai/kan:
  # - chi/pon/daiminkan (not after kan)
  # - ron (including chankan)
  #
  # `player` (in argument): the player who declares
  # `otherPlayer`: `@globalPublic.player` == `@globalPublic.lastAction.player`
  #
  # NOTE: Calling one of these methods only *declares* the action (analogous to
  # verbal declaration in table-top play). During one query, only the call with
  # highest priority (ron > kan > pon > chi) is selected (except in the case of
  # multi-ron) and consequently executed (by internally calling corresponding
  # underscore-prefixed method).
  #
  # Convention: `can`-methods are responsible for building the action object.
  # As a result, prefix-less methods are simply wrappers around `can`-methods.
  # Rationale: if you know if you can chi/pon/kan you already have the info to
  # actually do it

  # chi:
  #   dir:
  #     < 0 : e.g. 34m chi 5m
  #     = 0 : e.g. 46m chi 5m
  #     > 0 : e.g. 67m chi 5m
  #   useAkahai:
  #     true => use akahai when you have it (default)
  #     false => don't use even if you have it
  canChi: (player, dir, useAkahai) ->
    with @_checkQuery player => if not ..valid then return ..
    if @globalPublic.nPiipaiLeft <= 0
      return valid: false, reason: "cannot chi when no piipai left"
    with @globalPublic.lastAction
      otherPlayer = ..player
      if ..type != @DAHAI or (otherPlayer+1)%4 != player
        return valid: false, reason: "can only chi after kamicha dahai"
      {S, equivNumber: x} = otherPai = ..details.pai

    P = Pai[S]
    switch
    | dir < 0   =>
      if x in [1 2] then return valid: false, reason: "wrong direction"
      pai0 = P[x - 2] ; pai1 = P[x - 1] ; pai = pai0
    | dir == 0  =>
      if x in [1 9] then return valid: false, reason: "wrong direction"
      pai0 = P[x - 1] ; pai1 = P[x + 1] ; pai = pai0
    | dir > 0   =>
      if x in [8 9] then return valid: false, reason: "wrong direction"
      pai0 = P[x + 1] ; pai1 = P[x + 2] ; pai = otherPai

    with @playerHidden[player]
      if not (..countEquiv pai0 and ..countEquiv pai1)
        return valid: false, reason: "[#pai0#pai1] not in juntehai"
      if useAkahai and ..count1 (p = P[0])
        switch 5
        | pai0.number => pai0 = p
        | pai1.number => pai1 = p

    return valid: true, action: {
      type: @CHI, player
      details: {
        type: @SHUNTSU
        pai
        ownPai: [pai0, pai1]
        otherPai
        otherPlayer
      }
    }
  chi: (player, dir, useAkahai) !->
    {valid, reason, action} = @canChi player, dir, useAkahai
    if not valid
      throw Error "riichi-core: kyoku: chi: #reason"
    @_declareAction action

  _chi: ({player, details: fuuro}:action) -> # see `_pon`
    {ownPai: [pai0, pai1], otherPlayer} = fuuro
    @globalPublic.player = player
    @playerHidden[player].remove2 pai0, pai1
    with @playerPublic[player]
      ..fuuro.push fuuro
      ..menzen = false
    @playerPublic[otherPlayer].lastSutehai.fuuroPlayer = player

    @_publishAction action
    @_clearIppatsu!
    @_goto @TURN # do not advance yet -- see `resolveQuery`

  # pon: specify max # of akahai {red 5} from juntehai
  # (defaults to 2 which means "use as many as you have")
  canPon: (player, maxAkahai = 2) ->
    with @_checkQuery player => if not ..valid then return ..
    if not (0 <= maxAkahai <= 2)
      return valid: false, reason: "maxAkahai should be 0/1/2"
    if @globalPublic.nPiipaiLeft <= 0
      return valid: false, reason: "cannot pon when no piipai left"
    with @globalPublic.lastAction
      if ..type != @DAHAI
        return valid: false, reason: "can only pon after dahai"
      otherPai = ..details.pai
      otherPlayer = ..player
    pai = otherPai.equivPai
    with @playerHidden[player]
      nAll = ..countEquiv pai
      if nAll < 2 then return valid: false, reason:
        "not enough [#pai] (you have #nAll, need 2)"
      if pai.number == 5
        # could have akahai
        akahai = Pai[pai.S][0]
        nAkahai = ..count1 akahai
        nAkahai <?= maxAkahai
      else
        nAkahai = 0
    ownPai = switch nAkahai
    | 0 => [pai, pai]
    | 1 => [akahai, pai]
    | 2 => [akahai, akahai]
    return valid: true, action: {
      type: @PON, player
      details: {
        type: @MINKO
        pai, ownPai, otherPai, otherPlayer
      }
    }
  pon: (player, maxAkahai = 2) !->
    {valid, reason, action} = @canPon player, maxAkahai
    if not valid
      throw Error "riichi-core: kyoku: pon: #reason"
    @_declareAction action

  _pon: ::_chi # <--- http://bit.ly/1HDdOal
  # reason why this works: action object in same format (both have 2 ownPai)

  # daiminkan
  # no need to specify which one to use at all
  # NOTE: much code comes from ankan/kakan and pon even though daiminkan is not
  # declared during player's own turn
  canDaiminkan: (player) ->
    with @_checkQuery player => if not ..valid then return ..
    with @globalPublic
      if ..nPiipaiLeft <= 0
        return valid: false, reason: "cannot kan when no piipai left"
      if ..nKan >= 4 and not @suukantsuCandidate!?
        return valid: false, reason: "cannot kan when no rinshan left"
      with ..lastAction
        if ..type != @DAHAI
          return valid: false, reason: "can only daiminkan after dahai"
        otherPai = ..details.pai
        otherPlayer = ..player
    pai = otherPai.equivPai
    ownPai = @playerHidden[player].getAllEquiv pai
    if (n = ownPai.length) < 3 then return valid: false, reason:
      "not enough [#pai] (you have #n, need 3)"
    return valid: true, action: {
      type: @KAN, player
      details: {
        type: @DAIMINKAN
        pai, ownPai, otherPai, otherPlayer
      }
    }
  daiminkan: (player) !->
    {valid, reason, action} = @canDaiminkan player
    if not valid
      throw Error "riichi-core: kyoku: daiminkan: #reason"
    @_declareAction action

  _daiminkan: ({player, details: fuuro}:action) !->
    {pai, otherPlayer} = fuuro
    @globalPublic.player = player
    if ++@globalPublic.nKan > 4 then return @_checkRyoukyoku!

    @playerHidden[player].removeEquivN pai, 3
    with @playerPublic[player]
      ..fuuro.push fuuro
      ..menzen = false
    @playerPublic[otherPlayer].lastSutehai.fuuroPlayer = player
    @_revealDoraHyouji @DAIMINKAN
    @_publishAction action
    @_clearIppatsu!
    @_goto @BEGIN # do not advance yet -- see `resolveQuery`

  # ron
  canRon: (player) ->
    with @_checkQuery player => if not ..valid then return ..
    if @playerHidden[player].furiten
      return valid: false, reason: "furiten"
    pai = @ronPai!
    equivPai = pai.equivPai
    houjuuPlayer = @globalPublic.player
    {wait} = @playerHidden[player].decompTenpai
    if equivPai not in wait then return valid: false, reason:
      "#pai not in your tenpai set #{Pai.stringFromArray[wait]}"
    if not (agari = @_agari player, pai, houjuuPlayer)
      return valid: false, reason: "no yaku"
    return valid: true, action: {
      type: @RON, player
      details: agari
    }
  ron: (player) !->
    {valid, reason, action} = @canRon player
    if not valid
      throw Error "riichi-core: kyoku: ron: #reason"
    @_declareAction action


  # resolution of declarations during query
  # called e.g. after query times out or all responses have been received
  #
  # NOTE: cleanup between `@_goto` and `@advance`
  resolveQuery: !->
    with @globalHidden.lastDeclared
      if ..RON then return @_resolveRon!
      # check for doujun/riichi furiten
      @_updateFuritenResolve!
      # if declared riichi isn't ron'd, it becomes accepted
      @_checkAcceptedRiichi!

      switch
      | (action = ..KAN)? => @_daiminkan action
      | (action = ..PON)? => @_pon       action
      | (action = ..CHI)? => @_chi       action
      | _ =>
        # no declarations, move on
        # NOTE: kakan/ankan => stay in player's turn
        with @globalPublic
          if ..lastAction.type == @DAHAI
            ..player = (..player + 1)%4
        @_goto @BEGIN
      # clear all declarations now that they're resolved
      ..clear!
      for i til 4 => @playerHidden[i].declaredAction = null
    @emit \resolved
    @advance!

  # (multi-)ron resolution
  # priority of players are decided by natural turn order after houjuu player:
  #   shimocha{next/right} > toimen{opposite} > kamicha{prev/left}
  # kyoutaku: all taken by highest priority
  # double/triple ron:
  #   atamahane: true => highest priority only
  #   double/triple: false => double/triple ron results in ryoukyoku instead
  #
  # rule variations:
  #  `.ron`
  _resolveRon: !->
    {atamahane, double, triple} = @rulevar.ron
    nRon = 0
    ronList = []
    agariList = []
    delta = @globalPublic.delta.slice!
    renchan = false
    {kyoutaku, player: houjuuPlayer} = @globalPublic
    for player in OTHER_PLAYERS[houjuuPlayer]
      with @playerHidden[player].declaredAction
        if ..?.type == @RON
          nRon++
          ronList.push ..
          agariList.push (agari = ..details)
          for i til 4 => delta[i] += agari.delta[i]
          delta[player] += kyoutaku
          kyoutaku = 0
          if player == @chancha then renchan = true
          if atamahane then break
    if (nRon == 2 and not double) or (nRon == 3 and not triple)
      @_end {
        type: \RYOUKYOKU
        delta: @globalPublic.delta.slice!
        kyoutaku: @globalPublic.kyoutaku # remains on table
        renchan
        details: if nRon == 2 then "double ron" else "triple ron"
      }
    else
      for action in ronList => @_publishAction action
      @_end {
        type: \RON
        delta
        kyoutaku: 0 # taken
        renchan
        details: agariList
      }


  # state updates after player action

  # reveal dora hyoujihai(s)
  # previously delayed kan-dora will always be revealed
  # kanType: @DAIMINKAN, @KAKAN, @ANKAN
  #   anything else: treat as not delayed
  #
  # rule variations:
  #   `.dora.kan`
  _revealDoraHyouji: (type) !->
    if not (rule = @rulevar.dora.kan) then return
    with @globalPublic.doraHyouji
      begin = ..length
      end = @globalPublic.nKan - (rule["#type"] ? 0)
      for i from begin to end
        ..push (d = @globalHidden.doraHyouji[i])
        @emit \doraHyouji, d

  # update player's own furiten {sacred discard} status flags after dahai
  _updateFuritenDahai: (player) !->
    pp = @playerPublic[player]
    with @playerHidden[player]
      # sutehai~: one of your tenpai has been previously discarded
      ..sutehaiFuriten = ..decompTenpai.wait.some -> pp.sutehaiContains it
      # doujun~: effective until dahai
      ..doujunFuriten = false
      # sum it up (NOTE: we've just set doujunFuriten to false)
      ..furiten = ..sutehaiFuriten or ..riichiFuriten # or ..doujunFuriten

  # set doujun/riichi furiten flags if dahai {discard} matches the tenpai set
  # of a player who didn't/couldn't ron
  _updateFuritenResolve: (player) !->
    for player in OTHER_PLAYERS[@globalPublic.player]
      with @playerHidden[player]
        if @ronPai!equivPai in ..decompTenpai.wait
          ..furiten = true
          ..doujunFuriten = true
          ..riichiFuriten = @playerPublic[player].riichi.accepted

  # if riichi dahai not ron'd, it becomes accepted
  _checkAcceptedRiichi: !->
    with @globalPublic.lastAction
      if ..type == @DAHAI and ..details.riichi
        player = ..player
        with @playerPublic[player].riichi
          ..accepted = true
          ..ippatsu = true
        with @globalPublic
          ..kyoutaku += 1000
          ..delta[player] -= 1000
          ..nRiichi++

  # clear ippatsu flag across the field (after any fuuro)
  _clearIppatsu: !-> @playerPublic.forEach (.riichi.ippatsu = false)

  # enforce ryoukyoku {abortive/exhaustive draw} rules
  # see `suufonrenta` and friends below
  # return: true/false: if ryoukyoku takes place
  # rule variations:
  #   `.ryoukyoku`
  _checkRyoukyoku: ->
    # tochuu ryoukyoku {abortive draw}
    for type, allowed of @rulevar.ryoukyoku.tochuu
      switch allowed
      | false => continue
      | true  => renchan = true
      | _     => renchan = false
      # perform check if this rule is implemented
      if @[type]?! then return @_end {
        type: \RYOUKYOKU
        delta: @globalPublic.delta.slice!
        kyoutaku: @globalPublic.kyoutaku # remains on table
        renchan
        details: type
      }
    # howanpai ryoukyoku {exhaustive draw}
    # (*normal* case of ryoukyoku)
    if @globalPublic.nPiipaiLeft == 0
      ten = []
      noTen = []
      delta = @globalPublic.delta.slice!
      for i til 4
        if @playerHidden[i].decompTenpai.wait.length then ten.push i
        else noTen.push i
      # TODO: nagashi mankan
      if ten.length && noTen.length
        sTen = 3000 / ten.length
        sNoTen = 3000 / noTen.length
        for i in ten => delta[i] += sTen
        for i in noTen => delta[i] -= sNoTen
      return @_end {
        type: \RYOUKYOKU
        delta
        kyoutaku: @globalPublic.kyoutaku # remains on table
        renchan: @chancha in ten # all-no-ten & all-ten => also renchan
        details: \howanpai
      }
    return false


  # predicates

  # tochuu ryoukyoku {aborative draw} conditions
  # NOTE:
  # - should be called before tsumo
  # - `is` prefix omitted to simplify calling (see `_checkRyoukyoku`)
  suufonrenta: ->
    pai = new Array 4
    for i til 4 => with @playerPublic[i]
      if ..fuuro.length == 0 and ..sutehai.length == 1
        pai[i] = ..sutehai[0].pai
      else return false
    return pai.0.isFonpai and pai.0 == pai.1 == pai.2 == pai.3
  suukaikan: ->
    switch @globalPublic.nKan
    | 0, 1, 2, 3 => false
    | 4 => not @suukantsuCandidate!? # all same player => not suukaikan
    | _ => true
  suuchariichi: -> @globalPublic.nRiichi == 4

  # kuikae {swap call}: refers to the situation where a player declares chi
  # with two pai in juntehai and then dahai {discards} one, but these three pai
  # alone can be considered as a shuntsu; this is usually forbidden. Depending
  # on rule variations, it could also be forbidden to pon then dahai the same
  # pai. Akahai {red 5} is treated the same as regular 5.
  #
  # Examples: (also included in rule variations)
  # - moro: has 34m , chi 0m => cannot dahai 5m
  # - suji: has 34m , chi 0m => cannot dahai 2m
  # - pon : has 555m, pon 0m => cannot dahai 5m
  #
  # return: true if given situation is kuikae forbidden by rule
  #
  # rule variations:
  #   `.banKuikae`
  isKuikae: (fuuro, dahai) ->
    {type, ownPai, otherPai} = fuuro
    if type in [@DAIMINKAN, @KAKAN, @ANKAN] then return false
    {moro, suji, pon} = @rulevar.banKuikae

    # NOTE: fuuro object is NOT modified
    # shorthands: (pq) chi (o) dahai (d)
    d = dahai.equivPai
    o = otherPai.equivPai
    if moro and type == @SHUNTSU and d == o or
       pon  and type == @MINKO  and d == o then return true

    if suji and type == @SHUNTSU and d.suite == o.suite
      [p, q] = ownPai.map (.= equivPai) .sort Pai.compare
      return p.succ == q and (
        (o.succ == p and q.succ == d) or # OPQD: PQ chi O => cannot dahai D
        (d.succ == p and q.succ == o)    # DPQO: PQ chi O => cannot dahai D
      )

    return false

  # if everyone has not made fuuro and `player` has not discarded
  # i.e. `player` has taken his first tsumo without disruption
  isTrueFirstTsumo: (player) ->
    with @playerPublic
      return ..every (.fuuro.length == 0) and ..[player].sutehai.length == 0

  # check if one player alone has made 4 kan's (suukantsu candidate)
  suukantsuCandidate: ->
    if @globalPublic.nKan < 4 then return null
    for player til 4
      with @playerPublic[player].fuuro
        # FIXME: not-so-elegant hack for matching @DAIMINKAN, @ANKAN, @KAKAN
        if ..length == 4 and ..every (.type.0.match /KAN$/)
          return player
    return null

  # find pai that might be ron'd: dahai or kakanPai (for chankan)
  ronPai: ->
    with @globalPublic.lastAction
      switch ..type
      | @KAKAN => return ..details.kakanPai
      | _ => return ..details.pai


  # assemble information to determine whether a player has a valid win and how
  # many points is it worth
  _agari: (agariPlayer, agariPai, houjuuPlayer = null) ->
    gh = @globalHidden
    gp = @globalPublic
    ph = @playerHidden[agariPlayer]
    pp = @playerPublic[agariPlayer]
    dict = {
      rulevar: @rulevar

      agariPai
      juntehai: ph.juntehai
      decompTenpai: ph.decompTenpai
      fuuro: pp.fuuro
      menzen: pp.menzen
      riichi: pp.riichi

      chancha: @chancha
      agariPlayer: agariPlayer
      houjuuPlayer: houjuuPlayer

      honba: @init.honba
      bakaze: @init.bakaze
      jikaze: pp.jikaze
      doraHyouji: gh.doraHyouji
      uraDoraHyouji: gh.uraDoraHyouji
      nKan: gp.nKan

      isAfterKan: gp.lastAction.type in [@KAN, @RINSHAN_TSUMO]
      isHaitei: gp.nPiipaiLeft == 0
      isTrueFirstTsumo: @isTrueFirstTsumo agariPlayer
    }
    a = new Agari dict
    if not a.isAgari then return null
    return a
