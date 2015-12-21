# Kyoku {round}
# Implements core game logic
#
# A Kyoku instance is both the "table" and the "referee" of one round of game.
# Responsiblity:
# - maintaining all states and transitions according to game rules
# - providing interfaces for both carrying out and announcing player actions
#   and declarations
#
# NOTE: This is a God Class out of necessity and essential complexity.

require! {
  'events': {EventEmitter}

  'lodash.merge': merge

  '../package.json': {version: VERSION}
  './pai': Pai
  './wall': splitWall
  './agari': Agari
  './util': {OTHER_PLAYERS, floorTo}
  './rulevar-default': rulevarDefault

  './kyoku-player-hidden': PlayerHidden
  './kyoku-player-public': PlayerPublic
}

module.exports = class Kyoku implements EventEmitter::
  ({rulevar, gameStateBefore, wall}) ->
    @VERSION = VERSION

    # events: always emitted asynchronously (see `@_emit`)
    #   action(action)
    #   declare(player, type)
    #   doraHyouji(pai)
    #   end(result, gameStateAfter)
    EventEmitter.call @

    # rulevar: missing object/fields filled with default
    @rulevar = rulevar = merge {}, rulevarDefault, rulevar

    # gameStateBefore:
    #   seq: origin of action sequence number (see `@seq`)
    #   bakaze: 0/1/2/3 => E/S/W/N {prevailing wind}
    #   chancha: 0/1/2/3 {dealer}
    #   honba: 0/1/2/... {count of renchan}
    #   kyoutaku: 0/1/2/... {count of riichi bet}
    #   points: array of each player's points at the start of kyoku
    #
    # NOTE:
    # - gameStateBefore is immutable
    # - if not supplied, defaults to first kyoku in game
    # - kyoutaku during this kyoku is not reflected in `.points` due to
    #   immutability; see `@globalPublic.delta`
    p0 = rulevar.setup.points.initial
    @gameStateBefore = gameStateBefore ?=
      seq: 0
      bakaze: 0
      chancha: 0
      honba: 0
      kyoutaku: 0
      points: [p0, p0, p0, p0]

    # wall: defaults to new randomly shuffled wall if not supplied
    if !wall? then wall = Pai.shuffleAll rulevar.dora.akahai
    @wall = wall
    # initial deal: see `splitWall`
    # handling of dora indicators:
    # - @globalHidden.doraHyouji/uraDoraHyouji: all 5 stacks
    # - @globalPublic.doraHyouji: only revealed ones
    {haipai, piipai, rinshan, doraHyouji, uraDoraHyouji} = splitWall wall

    # id of chancha {dealer}
    @chancha = chancha = gameStateBefore.chancha
    # jikaze {seat wind} of each player
    jikaze =
      (4 - chancha)%4
      (5 - chancha)%4
      (6 - chancha)%4
      (7 - chancha)%4

    # table state: {global, player}{hidden, public}
    @globalHidden = {piipai, rinshan, doraHyouji, uraDoraHyouji}
    @globalPublic = {
      nPiipaiLeft: piipai.length # == 70
      nKan: 0
      doraHyouji: [doraHyouji[0]]

      # riichi-related: see `@_checkAcceptedRiichi`
      kyoutaku: gameStateBefore.kyoutaku
      delta: [0 0 0 0]
      nRiichi: 0
    }
    @playerHidden = [new PlayerHidden haipai[jikaze[i]] for i til 4]
    @playerPublic = [new PlayerPublic        jikaze[i]  for i til 4]

    # game progression: (TODO DOC)
    #   seq: action sequence number
    #     == `@gameStateBefore.seq`+1, +2, +3, ...
    #     == `lastAction.seq`
    #   phase:
    #     begin: after turn starts or successful kan; before tsumo
    #     turn : after tsumo; before own-turn action
    #     query: after own-turn action; awaiting declaration (chi/pon/kan/ron)
    #     end  : end of kyoku
    #   currPlayer: (obvious)
    @seq = gameStateBefore.seq
    @phase = \begin
    @currPlayer = chancha

    # action: {seq, type, player, details}
    #   type/details:
    #     tsumo: {pai, rinshan: true/false}
    #     dahai: {pai, riichi: true/false, tsumokiri: true/false}
    #     chi/pon/kan: fuuro object (see PlayerPublic)
    @lastAction = {type: null, seq: @seq}
    @actionLog = []

    # declarations yet to be resolved during current query
    #
    # NOTE: during one query:
    # - player may only declare once
    # - chi can only be declared by one player
    # - pon/kan can only be declared by one player
    # - ron is not exclusive and might be overwritten; however, this doesn't
    #   matter (see `_resolveRon`)
    @lastDecl =
      chi: null, pon: null, kan: null, ron: null
      0: null, 1: null, 2: null, 3: null
      clear: !-> @chi = @pon = @kan = @ron = @0 = @1 = @2 = @3 = null

    # result: null when still playing
    # common fields:
    #   type: <[tsumoAgari ron ryoukyoku]>
    #   delta: array of points increment for each player
    #   kyoutaku: how much kyoutaku {riichi bet} should remain on table
    #   renchan: true/false
    # details:
    #   tsumoAgari: agari object
    #   ron: array of agari object(s) by natural turn order
    #   ryoukyoku: reason (string)
    @result = null

    # gameStateAfter: see `@_end`
    @gameStateAfter = null

    # done (call `nextTurn` to start kyoku)


  # NOTE: underscore-prefixed methods should not be called from outside


  # delayed event:
  # - clears call stack
  # - allows methods to finish cleanup
  _emit: (...a) -> process.nextTick ~> @emit ...a


  # called after action executed:
  # - log the action
  # - emit event AFTER action finishes cleanup
  _publishAction: (action) !->
    action.seq = ++@seq
    @lastAction = action
    @actionLog.push action
    @_emit \action, action

  # called after \query action *declared* (see below)
  # NOTE: details of declared action should NOT be published
  _declareAction: ({type, player}:action) !->
    with @lastDecl
      ..[type] == ..[player] = action
    @_emit \declare, player, type


  # preparation for a new turn:
  # - check for ryoukyoku
  # - (rinshan) tsumo
  # NOTE:
  # - howanpai already handled by ryoukyoku checks
  # - rinshan tsumo also removes one piipai from tail side so that total
  #   piipai count always decreases by 1 regardless of rinshan or not
  nextTurn: !->
    if @_checkRyoukyoku! then return

    {currPlayer: player, lastAction} = @
    isAfterKan = (lastAction.type == \kan)
    @globalPublic.nPiipaiLeft--
    with @globalHidden
      if isAfterKan
        pai = ..rinshan.pop()
        ..piipai.shift()
      else
        pai = ..piipai.pop()
    @playerHidden[player].tsumo pai
    @_publishAction {type: \tsumo, player, details: isAfterKan}
    @phase = \turn

  # called when kyoku should end:
  # - calculate what next kyoku should be (`gameStateAfter`)
  # - publish result
  SEQ_MAJOR = 10000
  _end: (@result) !->
    {setup:
      points: {origin}
      end
    } = @rulevar
    @gameStateAfter = gameStateAfter = do ~>
      seq = floorTo(++@seq, SEQ_MAJOR) + SEQ_MAJOR
      {bakaze, chancha, honba, points} = @gameStateBefore
      {kyoutaku, delta} = result

      # apply delta to points
      result.points = points .= slice!
      for i til 4
        if (points[i] += delta[i]) < 0
          # strictly negative points not allowed
          return null

      # determine next bakaze/chancha
      newBakaze = false
      if result.renchan
        honba++
        # all-last oya top
        if end.oyaTop and bakaze == end.bakaze - 1 and chancha == 3
        and util.max(points) == points[3]
          return null
      else
        if result.type == \ryoukyoku then honba++
        else honba = 0
        if ++chancha == 4
          chancha = 0
          bakaze++
          newBakaze = true

      # handle overtime / sudden-death
      if bakaze < end.bakaze then void
      else if bakaze < end.overtime
        if (newBakaze or end.suddenDeath)
        and points.some (> origin) then return null
      else return null

      # next kyoku
      return {seq, bakaze, chancha, honba, kyoutaku, points}
    @phase = \end
    @_emit \end, result, gameStateAfter


  # method pair with & without `can`-prefix: action interface
  #
  # - `can`-method judge if the action is valid
  #   return: {valid, reason}
  #
  # - prefix-less method:
  #   - call `can`-method first to determine if the action is valid;
  #     invalid => throw error with reason
  #   - perform action & update state
  #   - update `lastAction` and emits event
  #
  # NOTE:
  # - neither method rely on information hidden from player, i.e. they do not
  #   access `@globalHidden` or `@playerHidden[someOtherPlayer]`

  # common check for `can`-methods: if player can make any move at all
  _checkTurn: (player) ->
    if player != @currPlayer or @phase != \turn
      return valid: false, reason: "not your turn"
    return valid: true
  _checkQuery: (player) ->
    # NOTE: not typo!
    if player == @currPlayer or @phase != \query
      return valid: false, reason: "not your turn"
    # extra: should only declare once
    if (action = @lastDecl[player])
      return valid: false, reason: "you already declared #{action.type}"
    return valid: true


  # actions available in normal turn:
  # - dahai (including riichi declaration)
  # - kakan/ankan
  # - tsumoAgari
  # - kyuushuukyuuhai (the only dedicated ryoukyoku action)
  @METHOD_ACTION = {
    +dahai, +ankan, +kakan, +tsumoAgari, +kyuushuukyuuhai
  }

  # dahai {discard}
  # - pai: null => tsumokiri
  # - riichi: true => declare riichi before discard
  #
  # NOTE: when publishing event, `null` for tsumokiri is replaced with actual
  # pai as it becomes revealed; `tsumokiri` flag is set instead
  canDahai: (player, pai, !!riichi) ->
    with @_checkTurn player => if not ..valid then return ..
    tsumokiri = !pai?

    if @playerPublic[player].riichi.accepted and not tsumokiri
      return valid: false, reason: "can only tsumokiri after riichi"
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
    with @lastAction
      if ..type in <[chi pon]> and ..player == player
      and @isKuikae ..details, pai
        return valid: false, reason: "kuikae"
    return valid: true

  dahai: (player, pai, !!riichi) !->
    {valid, reason} = @canDahai player, pai, riichi
    if not valid
      throw Error "riichi-core: kyoku: dahai: #reason"
    tsumokiri = !pai?
    pp = @playerPublic[player]
    ph = @playerHidden[player]

    if riichi
      pp.riichi.declared = true
      if @isTrueFirstTsumo player then pp.riichi.double = true
    if tsumokiri
      pp.tsumokiri pai = ph.tsumokiri!
    else
      pp.dahai ph.dahai pai

    @_updateFuritenDahai player
    @_revealDoraHyouji!
    @_clearOwnIppatsu player # NOTE: clear own only!

    @_publishAction {
      type: \dahai, player
      details: {pai, riichi, tsumokiri}
    }
    @phase = \query

  # ankan
  canAnkan: (player, pai) ->
    with @_checkTurn player => if not ..valid then return ..
    if not pai?.paiStr
      return valid: false, reason: "invalid pai"

    with @globalPublic
      if ..nPiipaiLeft <= 0
        return valid: false, reason: "cannot kan when no piipai left"
      if ..nKan >= 4 and not @suukantsuCandidate!?
        return valid: false, reason: "cannot kan when no rinshan left"
    if @lastAction.type in <[chi pon]>
      return valid: false, reason: "cannot ankan after #{@lastAction.type}"
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
      type: \ankan
      pai, ownPai
      otherPai: null
      fromPlayer: null
      kakanPai: null
    }

    @_revealDoraHyouji \ankan
    @_clearAllIppatsu!

    @_publishAction {type: \kan, player, details: fuuro}
    if @rulevar.yaku.kokushiAnkan
      @phase = \query
    else
      @phase = \begin
      @nextTurn!

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
    if @lastAction.type in <[chi pon]>
      return valid: false, reason: "cannot kakan after #{@lastAction.type}"
    pai .= equivPai
    found = false
    for fuuro in @playerPublic[player].fuuro
      if fuuro.type == \minko and fuuro.pai == pai
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
    fuuro
      ..type = \kakan
      ..kakanPai = kakanPai

    @_revealDoraHyouji \kakan
    @_clearAllIppatsu!

    @_publishAction {type: \kan, player, details: fuuro}
    @phase = \query

  # tsumoAgari
  canTsumoAgari: (player) ->
    with @_checkTurn player => if not ..valid then return ..
    if not (tsumohai = @playerHidden[player].tsumohai)
      return valid: false, reason: "no tsumohai"
    if not (agari = @_agari player, tsumohai)
      return valid: false, reason: "no yaku"
    return valid: true, agari: agari
  tsumoAgari: (player) !->
    {valid, reason, agari} = @canTsumoAgari player
    if not valid
      throw Error "riichi-core: kyoku: tsumoAgari: #reason"
    delta = @globalPublic.delta # NOTE: delta is modified
    for i til 4 => delta[i] += agari.delta[i]
    delta[player] += @globalPublic.kyoutaku*1000
    @_end {
      type: \tsumoAgari
      delta
      kyoutaku: 0 # taken
      renchan: @chancha == player
      details: agari
    }

  # kyuushuukyuuhai ryoukyoku
  #   - available at player's true first tsumo
  #   - player must have at least 9 **KINDS** of yaochuupai
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
    @_end {
      type: \ryoukyoku
      delta: @globalPublic.delta
      kyoutaku: @globalPublic.kyoutaku # remains on table
      renchan
      details: \kyuushuukyuuhai
    }


  # actions available to other players after current player's dahai/kan:
  # - chi/pon/daiminkan (not after kan)
  # - ron (including chankan)
  #
  # `player` (in argument): the player who declares
  # `fromPlayer`: `@currPlayer` == `@lastAction.player`
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

  @METHOD_DECL = {
    +chi, +pon, +daiminkan, +ron
  }

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
    if @playerPublic[player].riichi.accepted
      return valid: false, reason: "cannot chi after riichi"
    if @globalPublic.nPiipaiLeft <= 0
      return valid: false, reason: "cannot chi when no piipai left"
    with @lastAction
      fromPlayer = ..player
      if ..type != \dahai or (fromPlayer+1)%4 != player
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

    | _         =>       return valid: false, reason: "wrong direction"

    with @playerHidden[player]
      if not (..countEquiv pai0 and ..countEquiv pai1)
        return valid: false, reason: "[#pai0#pai1] not in juntehai"
      if useAkahai and ..count1 (p = P[0])
        switch 5
        | pai0.number => pai0 = p
        | pai1.number => pai1 = p

    return valid: true, action: {
      type: \chi, player
      details: {
        type: \minjun
        pai
        ownPai: [pai0, pai1]
        otherPai
        fromPlayer
        kakanPai: null
      }
    }
  chi: (player, dir, useAkahai) !->
    {valid, reason, action} = @canChi player, dir, useAkahai
    if not valid
      throw Error "riichi-core: kyoku: chi: #reason"
    @_declareAction action

  _chi: ({player, details: fuuro}:action) -> # see `@_pon`
    {ownPai: [pai0, pai1], fromPlayer} = fuuro
    @currPlayer = player
    @playerHidden[player].remove2 pai0, pai1
    @playerPublic[player]
      ..fuuro.push fuuro
      ..menzen = false
    @playerPublic[fromPlayer].lastSutehai.fuuroPlayer = player

    @_clearAllIppatsu!

    @_publishAction action
    @phase = \turn # do not advance yet -- see `@resolveQuery`

  # pon: specify max # of akahai {red 5} from juntehai
  # (defaults to 2 which means "use as many as you have")
  canPon: (player, maxAkahai = 2) ->
    with @_checkQuery player => if not ..valid then return ..
    if not (0 <= maxAkahai <= 2)
      return valid: false, reason: "maxAkahai should be 0/1/2"
    if @playerPublic[player].riichi.accepted
      return valid: false, reason: "cannot pon after riichi"
    if @globalPublic.nPiipaiLeft <= 0
      return valid: false, reason: "cannot pon when no piipai left"
    with @lastAction
      if ..type != \dahai
        return valid: false, reason: "can only pon after dahai"
      otherPai = ..details.pai
      fromPlayer = ..player
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
      type: \pon, player
      details: {
        type: \minko
        pai, ownPai, otherPai, fromPlayer
        kakanPai: null
      }
    }
  pon: (player, maxAkahai = 2) !->
    {valid, reason, action} = @canPon player, maxAkahai
    if not valid
      throw Error "riichi-core: kyoku: pon: #reason"
    @_declareAction action

  _pon: ::_chi # same code as above
  # reason why this works: action object in same format (both have 2 ownPai)

  # daiminkan
  # no need to specify which one to use at all
  # NOTE: much code comes from ankan/kakan and pon even though daiminkan is not
  # declared during player's own turn
  canDaiminkan: (player) ->
    with @_checkQuery player => if not ..valid then return ..
    if @playerPublic[player].riichi.accepted
      return valid: false, reason: "cannot daiminkan after riichi"
    with @globalPublic
      if ..nPiipaiLeft <= 0
        return valid: false, reason: "cannot kan when no piipai left"
      if ..nKan >= 4 and not @suukantsuCandidate!?
        return valid: false, reason: "cannot kan when no rinshan left"
    with @lastAction
      if ..type != \dahai
        return valid: false, reason: "can only daiminkan after dahai"
      otherPai = ..details.pai
      fromPlayer = ..player
    pai = otherPai.equivPai
    ownPai = @playerHidden[player].getAllEquiv pai
    if (n = ownPai.length) < 3 then return valid: false, reason:
      "not enough [#pai] (you have #n, need 3)"
    return valid: true, action: {
      type: \kan, player
      details: {
        type: \daiminkan
        pai, ownPai, otherPai, fromPlayer
        kakanPai: null
      }
    }
  daiminkan: (player) !->
    {valid, reason, action} = @canDaiminkan player
    if not valid
      throw Error "riichi-core: kyoku: daiminkan: #reason"
    @_declareAction action

  _daiminkan: ({player, details: fuuro}:action) !->
    {pai, fromPlayer} = fuuro
    @currPlayer = player
    if ++@globalPublic.nKan > 4 then return @_checkRyoukyoku!

    @playerHidden[player].removeEquivN pai, 3
    @playerPublic[player]
      ..fuuro.push fuuro
      ..menzen = false
    @playerPublic[fromPlayer].lastSutehai.fuuroPlayer = player

    @_revealDoraHyouji \daiminkan
    @_clearAllIppatsu!

    @_publishAction action
    @phase = \begin

  # ron
  canRon: (player) ->
    with @_checkQuery player => if not ..valid then return ..
    if @playerHidden[player].furiten
      return valid: false, reason: "furiten"
    pai = @ronPai!
    equivPai = pai.equivPai
    houjuuPlayer = @currPlayer
    {wait} = @playerHidden[player].decompTenpai
    if equivPai not in wait then return valid: false, reason:
      "#pai not in your tenpai set #{Pai.stringFromArray[wait]}"
    if not (agari = @_agari player, pai, houjuuPlayer)
      return valid: false, reason: "no yaku"
    return valid: true, action: {
      type: \ron, player
      details: agari
    }
  ron: (player) !->
    {valid, reason, action} = @canRon player
    if not valid
      throw Error "riichi-core: kyoku: ron: #reason"
    @_declareAction action


  # resolution of declarations during query
  # called e.g. after query times out or all responses have been received
  resolveQuery: !->
    if @phase != \query then return
    with @lastDecl
      if ..ron then return @_resolveRon!
      # check for doujun/riichi furiten
      @_updateFuritenResolve!
      # if declared riichi isn't ron'd, it becomes accepted
      @_checkAcceptedRiichi!

      switch
      | (action = ..kan)? => @_daiminkan action
      | (action = ..pon)? => @_pon       action
      | (action = ..chi)? => @_chi       action
      | _ =>
        # no declarations, move on
        # NOTE: kakan/ankan => stay in player's turn
        if @lastAction.type == \dahai
          @currPlayer = (@currPlayer + 1)%4
        @start!
      # clear all declarations now that they're resolved
      ..clear!
      # proceed to next turn
      if @phase == \begin then @nextTurn!

  # (multi-)ron resolution
  # priority of players are decided by natural turn order after houjuu player:
  #   shimocha{next/right} > toimen{opposite} > kamicha{prev/left}
  # kyoutaku: all taken by highest priority
  # double/triple ron:
  #   atamahane: true => highest priority only
  #   double/triple: false => double/triple ron results in ryoukyoku instead
  _resolveRon: !->
    {atamahane, double, triple} = @rulevar.ron

    nRon = 0
    ronList = []
    agariList = []

    {delta, kyoutaku} = @globalPublic # NOTE: delta is modified
    renchan = false
    houjuuPlayer = @currPlayer

    for player in OTHER_PLAYERS[houjuuPlayer]
      with @lastDecl[player]
        if ..?.type == \ron
          nRon++
          ronList.push ..
          agariList.push (agari = ..details)
          for i til 4 => delta[i] += agari.delta[i]
          delta[player] += kyoutaku*1000
          kyoutaku = 0 # all taken by highest priority
          if player == @chancha then renchan = true
          if atamahane then break

    if (nRon == 2 and not double) or (nRon == 3 and not triple)
      @_end {
        type: \ryoukyoku
        delta
        kyoutaku # remains on table
        renchan
        details: if nRon == 2 then \doubleRon else \tripleRon
      }
    else
      @_end {
        type: \ron
        delta
        kyoutaku: 0 # taken
        renchan
        details: agariList
      }


  # state updates after player action

  # reveal dora hyoujihai(s)
  # previously delayed kan-dora will always be revealed
  # kanType: \daiminkan, \kakan, \ankan
  #   anything else: treat as not delayed
  _revealDoraHyouji: (type) !->
    if not (rule = @rulevar.dora.kan) then return
    dhp = @globalPublic.doraHyouji
    dhh = @globalHidden.doraHyouji
    begin = dhp.length
    end = @globalPublic.nKan - (rule[type] ? 0)
    for i from begin to end
      dhp.push (d = dhh[i])
      @_emit \doraHyouji, d

  # update player's own furiten {sacred discard} status flags after dahai
  _updateFuritenDahai: (player) !->
    pp = @playerPublic[player]
    @playerHidden[player]
      # sutehai~: one of your tenpai has been previously discarded
      ..sutehaiFuriten = ..decompTenpai.wait.some -> pp.sutehaiContains it
      # doujun~: effective until dahai
      ..doujunFuriten = false
      # sum it up (NOTE: we've just set doujunFuriten to false)
      ..furiten = ..sutehaiFuriten or ..riichiFuriten # or ..doujunFuriten

  # set doujun/riichi furiten flags if dahai {discard} matches the tenpai set
  # of a player who didn't/couldn't ron
  _updateFuritenResolve: (player) !->
    for player in OTHER_PLAYERS[@currPlayer]
      with @playerHidden[player]
        if @ronPai!equivPai in ..decompTenpai.wait
          ..furiten = true
          ..doujunFuriten = true
          ..riichiFuriten = @playerPublic[player].riichi.accepted

  # if riichi dahai not ron'd, it becomes accepted
  _checkAcceptedRiichi: !->
    with @lastAction
      if not (..type == \dahai and ..details.riichi) then return
      player = ..player
    @playerPublic[player].riichi
      ..accepted = true
      ..ippatsu = true
    @globalPublic
      ..kyoutaku++
      ..delta[player] -= 1000
      ..nRiichi++

  # clear ippatsu flag:
  # - for current player only (after dahai)
  # - across the table (after fuuro)
  _clearOwnIppatsu: (player) !-> @playerPublic[player].riichi.ippatsu = false
  _clearAllIppatsu: !-> @playerPublic.forEach (.riichi.ippatsu = false)

  # enforce ryoukyoku {abortive/exhaustive draw} rules
  # see `@suufonrenta` and friends below
  # return: true/false: if ryoukyoku takes place
  _checkRyoukyoku: ->
    # tochuu ryoukyoku {abortive draw}
    for type, allowed of @rulevar.ryoukyoku.tochuu
      switch allowed
      | false => continue
      | true  => renchan = true
      | _     => renchan = false
      # perform check if this rule is implemented
      if @[type]?! then return @_end {
        type: \ryoukyoku
        delta: @globalPublic.delta
        kyoutaku: @globalPublic.kyoutaku # remains on table
        renchan
        details: type
      }
    # howanpai ryoukyoku {exhaustive draw}
    # (*normal* case of ryoukyoku)
    if @globalPublic.nPiipaiLeft == 0
      ten = []
      noTen = []
      delta = @globalPublic.delta # NOTE: delta is modified
      for i til 4
        if @playerHidden[i].decompTenpai.wait.length then ten.push i
        else noTen.push i
      # TODO: nagashimangan
      if ten.length && noTen.length
        sTen = 3000 / ten.length
        sNoTen = 3000 / noTen.length
        for i in ten => delta[i] += sTen
        for i in noTen => delta[i] -= sNoTen
      return @_end {
        type: \ryoukyoku
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
  # - `is` prefix omitted to simplify calling (see `@_checkRyoukyoku`)
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
  isKuikae: (fuuro, dahai) ->
    {type, ownPai, otherPai} = fuuro
    if type not in <[minjun minko]> then return false
    {moro, suji, pon} = @rulevar.banKuikae

    # NOTE: fuuro object is NOT modified
    # shorthands: (pq) chi (o) dahai (d)
    d = dahai.equivPai
    o = otherPai.equivPai
    if moro and type == \minjun and d == o or
       pon  and type == \minko   and d == o then return true

    if suji and type == \minjun and d.suite == o.suite
      [p, q] = ownPai
      p .= equivPai
      q .= equivPai
      return p.succ == q and (
        (o.succ == p and q.succ == d) or # OPQD: PQ chi O => cannot dahai D
        (d.succ == p and q.succ == o)    # DPQO: PQ chi O => cannot dahai D
      )

    return false

  # check if `player` has taken his natural first tsumo without disruption
  isTrueFirstTsumo: (player) ->
    with @playerPublic
      return ..[player].sutehai.length == 0 and ..every (.fuuro.length == 0)

  # check if one player alone has made 4 kan (qualifies for suukantsu yakuman)
  suukantsuCandidate: ->
    if @globalPublic.nKan < 4 then return null
    for player til 4
      with @playerPublic[player].fuuro
        if ..length == 4 and ..every (.type not in <[minjun minko]>)
          return player
    return null

  # find pai that might be ron'd: dahai or kakanPai (for chankan)
  ronPai: ->
    with @lastAction
      switch ..type
      | \kakan => return ..details.kakanPai
      | _ => return ..details.pai


  # assemble information to determine whether a player has a valid win and how
  # many points is it worth
  _agari: (agariPlayer, agariPai, houjuuPlayer = null) ->
    if not agariPai then return null
    gsb = @gameStateBefore
    gh = @globalHidden
    gp = @globalPublic
    ph = @playerHidden[agariPlayer]
    pp = @playerPublic[agariPlayer]
    la = @lastAction
    input = {
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

      honba: gsb.honba
      bakaze: gsb.bakaze
      jikaze: pp.jikaze
      doraHyouji: gh.doraHyouji
      uraDoraHyouji: gh.uraDoraHyouji
      nKan: gp.nKan

      isAfterKan: la.type == \kan or (la.type == \tsumo and la.details == true)
      isHaitei: gp.nPiipaiLeft == 0
      isTrueFirstTsumo: @isTrueFirstTsumo agariPlayer
    }
    a = new Agari input
    if not a.isAgari then return null
    {[k, v] for k, v of a when k not of AGARI_BLACKLIST}

  AGARI_BLACKLIST = {
    -rulevar
    -decompTenpai
  }
