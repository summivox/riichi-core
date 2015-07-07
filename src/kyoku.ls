# kyoku {round}
# Complete implementation of one kyoku {round} of game.
#
# NOTE: This has inevitably become a God Class, partially due to the complexity
# of the game itself. On top of that, `_agari` is technically a method of this
# class as well, but has to be put into a separate file, so that this file can
# at least concentrate on the control flow of the game and leave the equally
# dazzling "how many points is this hand worth" problem to `_agari` instead.

require! {
  'events': {EventEmitter}
  './decomp.js': {decompTenpai}
  './pai.js': Pai
  './wall.js': splitWall
  './agari.js': _agari
}

# stub: emulated enums
function Enum(names)
  o = {}
  for name in names => o[name] = [name]
  o

module.exports = class Kyoku implements EventEmitter::
  _agari: _agari

  # start a new kyoku
  #
  # `init` (immutable):
  #   bakaze: 0/1/2/3 => E/S/W/N {prevailing wind}
  #   nKyoku: 1/2/3/4
  #   honba: >= 0
  #   kyoutaku: >= 0
  #   tenbou: array of score/points/sticks of each player
  # e.g. {1 3 2 1} =>
  # - Nan {South} 3 Kyoku {Round}
  # - current dealer = player 2
  # - 2 Honba (dealer has renchan'd twice)
  # - 1*1000 kyoutaku {riichi bet} on table
  #
  # NOTE:
  # - tenbou does not take into account of riichi kyoutaku within this round;
  #   actual value is 1000 less if in valid riichi state
  # - wall defaults to shuffled but can be provided (e.g. for testing)
  (@init, @rulevar, wall = null) ->
    EventEmitter.call @
    # dora handling:
    # - @globalHidden.doraHyouji/uraDoraHyouji: always the original 5 stacks
    # - @globalPublic.doraHyouji: revealed ones
    #
    # rule variations:
    #   `.dora.akahai`
    if !wall? then wall = Pai.shuffleAll @rulevar.dora.akahai
    {haipai, piipai, rinshan, doraHyouji, uraDoraHyouji} = splitWall wall

    # id of chancha {dealer}
    chancha = init.nKyoku - 1
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
    }
    @globalPublic =
      # visible on the table:
      nPiipaiLeft: 70
      nKan: 0
      doraHyouji: [doraHyouji[0]]
      # riichi-related:
      kyoutaku: @init.kyoutaku # +1000 when riichi accepted
      delta: [0 0 0 0] # -1000 when riichi accepted (for each player)
      nRiichi: 0 # +1 when riichi accepted

      # game progression (see below for details)
      player: chancha
      state: @BEGIN
      actionLog: []
      lastAction: {type: null} # always last item in actionLog
      lastDeclared:
        CHI: null, PON: null, KAN: null, RON: null
        clear: !-> @CHI = @PON = @KAN = @RON = null
    @playerHidden = [new PlayerHidden i, haipai[jikaze[i]] for i til 4]
    @playerPublic = [new PlayerPublic i,        jikaze[i]  for i til 4]

    # result: null when still playing
    # common fields:
    #   type: \TSUMO_AGARI \RON \RYOUKYOKU
    #   delta: array of tenbou {score} increment of each player
    #   kyoutaku: how much kyoutaku {riichi bet} should remain on field
    #   renchan: true/false
    # details:
    #   TSUMO_AGARI: agari object
    #   RON: array of agari objects by natural turn order
    #   RYOUKYOKU: reason
    @result = null

    # done

  # NOTE: underscore-prefixed methods should not be called from outside

  # state machine
  #   BEGIN: player starts turn normally or after kan
  #   TURN : awaiting player decision after tsumo
  #   QUERY: awaiting other players' declaration (chi/pon/kan/ron)
  #   END  : game has finished
  ::<<< Enum <[ BEGIN TURN QUERY END ]> #
  advance: !->
    {player, state} = @globalPublic
    switch state
    | @BEGIN  => @_begin!
    | @TURN   => @emit \turn , player
    | @QUERY  => @emit \query, player, @globalPublic.lastAction
    | @END    => @emit \end  , @result
    | _ => throw new Error "riichi-core: kyoku: advance: bad state (#state)"
  _goto: -> @globalPublic.state = it

  # actions: {type, player, details}
  #   details for each type:
  #     TSUMO: # of piipai left
  #     DAHAI: {pai: Pai, riichi: true/false, tsumokiri: true/false}
  #     CHI/PON/KAN: fuuro object (see PlayerPublic)
  #     TSUMO_AGARI/RON: agari object
  #     RYOUKYOKU: reason (= \kyuushuukyuuhai)
  ::<<< Enum <[ TSUMO TSUMO_AGARI DAHAI CHI PON KAN RON RYOUKYOKU ]> #

  # called after action executed
  _publishAction: !->
    with @globalPublic
      ..actionLog.push it
      ..lastAction = it
    @emit \action, it.player, it

  # called after @QUERY action *declared* (see below)
  # NOTE: details of declared action should NOT be published until the action
  # is executed (when `_publishAction` is then called)
  _declareAction: ({type, player}:action) !->
    @playerHidden[player].declaredAction = action
    @globalPublic.lastDeclared[type] = action
    @emit \declare, player, type # only type should be published

  # fuuro types
  ::<<< Enum <[ SHUNTSU KOUTSU DAIMINKAN KAKAN ANKAN ]> #


  # actions before player's turn
  _begin: !->
    {player, lastAction} = @globalPublic
    if @_checkRyoukyoku! then return

    # tsumo {draw} from either piipai or rinshan
    # NOTE: rinshan tsumo also removes one piipai from the other end so that
    # total piipai count always decreases by 1 for each tsumo
    with @globalHidden
      if lastAction.type == @KAN
        pai = ..rinshan.pop()
        ..piipai.shift()
      else
        pai = ..piipai.pop()
    n = --@globalPublic.nPiipaiLeft
    @playerHidden[player].addTsumo pai
    @_publishAction {type: @TSUMO, player, details: n}
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

  _end: (result) ->
    @result = result
    @_goto @END ; @advance!
    true



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
    with @playerHidden[player]
      with (if pai? then ..canDahai pai else ..canTsumokiri!)
        if not ..valid then return ..
      if riichi
        if (n = @globalPublic.nPiipaiLeft) < (m = @rulevar.riichi.minPiipaiLeft)
          return valid: false, reason: "not enough piipai (#n left, need #m)"
        decomp = ..decompTenpaiWithout pai
        if !decomp? or decomp.wait.length == 0
          return valid: false, reason: "not tenpai if dahai is [#pai]"
    with @globalPublic.lastAction
      if ..type in [@CHI, @PON] and ..player == player
      and @isKuikae ..details, pai
        return valid: false, reason: "kuikae"
    return valid:true

  dahai: (player, pai, !!riichi) !->
    {valid, reason} = @canDahai player, pai
    if not valid
      throw new Error "riichi-core: kyoku: dahai: #reason"

    if riichi then with @playerPublic[player].riichi
      ..declared = true
      if @isTrueFirstTsumo player then ..double = true
    if (tsumokiri = !pai?)
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
      if @rulevar.riichi.okurikan and ph.tsumo.equivPai != pai
        return valid: false, reason: "riichi ankan: okurikan"
    return valid: true

  ankan: (player, pai) !->
    {valid, reason} = @canAnkan player, pai
    if not valid
      throw new Error "riichi-core: kyoku: ankan: #reason"
    if ++@globalPublic.nKan > 4 then return @_checkRyoukyoku!

    pai .= equivPai
    with @playerHidden[player]
      ownPai = ..removeEquiv pai, 4
      ..cleanup!
    @playerPublic[player].fuuro.push fuuro = {
      type: @ANKAN, pai, ownPai, otherPai: null
    }

    @_publishAction {type: @KAN, player, details: fuuro}
    @_revealDoraHyouji @ANKAN
    @_clearIppatsu!
    if @rulevar.yaku.kokushiAnkan then @_goto @QUERY else @_goto @BEGIN ; @advance!

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
    equivPai = pai.equivPai
    found = false
    for fuuro in @playerPublic[player].fuuro
      if fuuro.type == @KOUTSU and fuuro.pai == equivPai
        found = true
        break
    if not found
      return valid: false, reason: "must have minko of 3*[#pai]"
    if (n = @playerHidden[player].count pai) != 1
      return valid: false, reason: "must have one [#pai] in juntehai"
    return valid: true, fuuro: fuuro

  kakan: (player, pai) !->
    {valid, reason, fuuro} = @canKakan player, pai
    if not valid
      throw new Error "riichi-core: kyoku: kakan: #reason"
    if ++@globalPublic.nKan > 4 then return @_checkRyoukyoku!

    pai .= equivPai
    with @playerHidden[player]
      [kakanPai] = ..removeEquiv pai, 1
      ..cleanup!
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
    if not (agari = @_agari player)
      return valid: false, reason: "no yaku"
    return valid: true, agari: agari
  tsumoAgari: (player) !->
    {valid, reason, agari} = @canTsumoAgari player
    if not valid
      throw new Error "riichi-core: kyoku: tsumoAgari: #reason"
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

  # kyuushuukyuuhai (often abbreviated as 9-9 in this project)
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
      throw new Error "riichi-core: kyoku: kyuushuukyuuhai: #reason"
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

  # chi: specify 2 pai from juntehai
  # NOTE: Akahai {red 5} considered *different* from regular 5!
  canChi: (player, pai0, pai1) ->
    with @_checkQuery player => if not ..valid then return ..
    if not pai0?.paiStr or not pai1?.paiStr
      return valid: false, reason: "invalid pai"
    if @globalPublic.nPiipaiLeft <= 0
      return valid: false, reason: "cannot chi when no piipai left"
    with @globalPublic.lastAction
      otherPlayer = ..player
      if ..type != @DAHAI or (otherPlayer+1)%4 != player
        return valid: false, reason: "can only chi after kamicha dahai"
      otherPai = ..details.pai
    if not @isShuntsu [pai0, pai1, otherPai]
      return valid: false, reason: "[#pai0#pai1]+[#otherPai] not shuntsu"
    with @playerHidden[player]
      if not (..count(pai0) and ..count(pai1))
        return valid: false, reason: "[#pai0] or [#pai1] not in juntehai"
    if Pai.compare(pai0, pai1) > 0
      [pai0, pai1] = [pai1, pai0]
    return valid: true, action: {
      type: @CHI, player
      details: {
        type: @SHUNTSU
        pai: pai0 <? otherPai
        ownPai: [pai0, pai1]
        otherPai
        otherPlayer
      }
    }
  chi: (player, pai0, pai1) !->
    {valid, reason, action} = @canChi player, pai0, pai1
    if not valid
      throw new Error "riichi-core: kyoku: chi: #reason"
    @_declareAction action

  _chi: ({player, details: fuuro}:action) -> # see `_pon`
    {ownPai: [pai0, pai1], otherPlayer} = fuuro
    @globalPublic.player = player

    with @playerHidden[player]
      ..remove pai0, 1
      ..remove pai1, 1
      ..cleanup!
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
      if nAll < 2
        return valid: false, reason: "not enough [#pai] (you have #nAll, need 2)"
      if pai.number == 5
        # could have akahai
        paiRed = Pai[0][pai.S]
        nRed = ..count paiRed
        nRed <?= maxAkahai
      else
        nRed = 0
    ownPai = switch nRed
    | 0 => [pai, pai]
    | 1 => [paiRed, pai]
    | 2 => [paiRed, paiRed]
    return valid: true, action: {
      type: @PON, player
      details: {
        type: @KOUTSU
        pai, ownPai, otherPai, otherPlayer
      }
    }
  pon: (player, maxAkahai = 2) !->
    {valid, reason, action} = @canPon player, maxAkahai
    if not valid
      throw new Error "riichi-core: kyoku: pon: #reason"
    @_declareAction action

  _pon: -> @_chi ... # <--- http://bit.ly/1HDdOal
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
    # NOTE: need to get ownPai without removing them
    # fortunately, player doesn't have tsumo now
    ownPai = @playerHidden[player].juntehai.filter (.equivPai == pai)
    if (n = ownPai.length) < 3
      return valid: false, reason: "not enough [#pai] (you have #n, need 3)"
    return valid:true, action: {
      type: @KAN, player
      details: {
        type: @DAIMINKAN
        pai, ownPai, otherPai, otherPlayer
      }
    }
  daiminkan: (player) !->
    {valid, reason, action} = @canDaiminkan player
    if not valid
      throw new Error "riichi-core: kyoku: daiminkan: #reason"
    @_declareAction action

  _daiminkan: ({player, details: fuuro}:action) !->
    {pai, otherPlayer} = fuuro
    @globalPublic.player = player
    if ++@globalPublic.nKan > 4 then return @_checkRyoukyoku!

    with @playerHidden[player]
      ..removeEquiv pai, 3
      ..cleanup!
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
    pai = @_ronPai!
    equivPai = pai.equivPai
    {wait} = @playerHidden[player].decompTenpai
    if equivPai not in wait then return valid: false, reason:
      "#pai not in your tenpai set #{Pai.stringFromArray[wait]}"
    if not (agari = @_agari player, pai)
      return valid: false, reason: "no yaku"
    agari.houjuuPlayer = @globalPublic.player # NOTE: NOT included in agari
    return valid: true, action: {
      type: @RON, player
      details: agari
    }
  ron: (player) !->
    {valid, reason, action} = @canRon player
    if not valid
      throw new Error "riichi-core: kyoku: ron: #reason"
    @_declareAction action

  # helper: find the pai to be ron'd
  _ronPai: ->
    with @globalPublic.lastAction
      switch ..type
      | @KAKAN => return ..details.kakanPai # <-- NOTE: this is why (chankan)
      | _ => return ..details.pai

  # resolution of declarations during query
  # called e.g. after query times out
  resolveQuery: !->
    with @globalPublic.lastDeclared
      switch
      | (action = ..RON)? => @_resolveRon! ; return # kyoku ends after ron
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
      # if riichi was declared, it now becomes accepted (not ron'd)
      @_checkAcceptedRiichi!
      # clear all declarations now that they're resolved
      ..clear!
      for i til 4 => @playerHidden[i].declaredAction = null
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
    agariList = []
    delta = @globalPublic.delta.slice!
    renchan = false
    {kyoutaku, player: houjuuPlayer} = @globalPublic
    for i in [1 2 3]
      player = (houjuuPlayer + i) % 4
      with @playerHidden[player]
        if ..declaredAction?.type == @RON
          agari = ..declaredAction.details
          agari.houjuuPlayer = houjuuPlayer
          agariList.push agari
          for i til 4 => delta[i] += agari.delta[i]
          delta[player] += kyoutaku
          kyoutaku = 0
          if player == @chancha then renchan = true
          if atamahane then break
        else if @_ronPai!equivPai in ..decompTenpai.wait
          ..furiten = true
          ..doujunFuriten = true
          ..riichiFuriten = @playerPublic[player].riichi.accepted
          if player == @chancha then renchan = true
    if (nRon == 2 and not double) or (nRon == 3 and not triple)
      @_end {
        type: \RYOUKYOKU
        delta: @globalPublic.delta.slice!
        kyoutaku: @globalPublic.kyoutaku # remains on table
        renchan
        details: if nRon == 2 then "double ron" else "triple ron"
      }
    else
      for agari in agariList => @_publishAction {
        type: @RON
        player: agari.player
        details: agari
      }
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
        ..push @globalHidden.doraHyouji[i]

  # update player's own furiten {sacred discard} status flags after dahai
  _updateFuritenDahai: (player) !->
    pp = @playerPublic[player]
    with @playerHidden[player]
      # sutehai~: one of your tenpai has been previously discarded
      ..sutehaiFuriten = ..decompTenpai.wait.some -> pp.sutehaiContains it
      # doujun~: effective until dahai
      ..doujunFuriten = false
      # sum it up
      ..furiten = ..sutehaiFuriten or ..doujunFuriten or ..riichiFuriten

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
  # - `is` prefix omitted to simplify usage (see `_checkRyoukyoku`)
  suufonrenta: ->
    pai = new Array 4
    for i til 4 => with @playerPublic[i]
      if ..fuuro.length == 0 and ..sutehai.length == 1
        pai[i] = ..sutehai[0].pai
      else return false
    return pai.0.isFonpai and pai.0 == pai.1 == pai.2 == pai.3
  suukaikan: ->
    switch @globalPublic.nKan
    | 0, 1, 2, 3 => return false
    | 4 => return @suukantsuCandidate!?
    | _ => return true
  suuchariichi: -> @globalPublic.nRiichi == 4

  # if given 3 pai (in array) can form a shuntsu
  # NOTE: arr is modified
  isShuntsu: (arr) ->
    [p, q, r] = arr.sort Pai.compare
    p.succ == q.equivPai and q.succ == r.equivPai

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
       pon  and type == @KOUTSU  and d == o then return true

    if suji and type == @SHUNTSU and d.suite == o.suite
      [p, q] = ownPai.map (.= equivPai) .sort Pai.compare
      D = d.number ; O = o.number ; P = p.number ; Q = q.number
      return P+1 == Q and (
        (O+1 == P and Q+1 == D) or # OPQD: PQ chi O => cannot dahai D
        (D+1 == P and Q+1 == O)    # DPQO: PQ chi O => cannot dahai D
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
        if ..length == 4 and ..every (.type == @KAN)
          return player
    return null


class PlayerHidden
  (@id, haipai) ->
    # juntehai (updated through methods)
    # - (3*n+1) tiles
    #   - action: `addTsumo`
    #   - decomp: decompTenpai
    # - (3*n+2) tiles
    #   - action: `tsumokiri`/`dahai`
    #   - decomp:
    #     - decompTenpai: excluding tsumo
    #     - decompTenpaiWithout(pai): excluding specified pai
    @juntehai = haipai.sort Pai.compare # Pai array format
    @juntehaiBins = bins = Pai.binsFromArray haipai # bins format
    @tsumo = null # null or Pai

    # tenpai decomposition (updated through methods)
    # when 
    @decompTenpai = decompTenpai bins

    # furiten (managed externally)
    @furiten = false
    @sutehaiFuriten = false
    @doujunFuriten = false
    @riichiFuriten = false

    # stores declared but yet to be resolved action (chi/pon/kan/ron)
    @declaredAction = null

  # NOTE: this is only used internally so no "can"-prefix method
  addTsumo: (pai) !->
    if @tsumo?
      throw new Error "riichi-core: kyoku: PlayerHidden: "+
        "already has tsumo (#{@tsumo})"
    @juntehaiBins[pai.S][pai.N]++
    @tsumo = pai

  canTsumokiri: ->
    if !@tsumo? then return valid: false, reason: "no tsumo"
    return valid: true
  tsumokiri: ->
    {valid, reason} = @canTsumokiri!
    if not valid
      throw new Error "riichi-core: kyoku: PlayerHidden: tsumokiri: #reason"

    pai = @tsumo
    @juntehaiBins[pai.S][pai.N]--
    @tsumo = null

    @decompTenpai = decompTenpai @juntehaiBins
    return pai

  canDahai: (pai) ->
    i = @juntehai.indexOf pai
    if i == -1 then return valid: false, reason:
      "[#pai] not in juntehai [#{Pai.stringFromArray @juntehai}]"
    return valid: true, i: i
  dahai: (pai) ->
    {valid, reason, i} = @canDahai pai
    if not valid
      throw new Error "riichi-core: kyoku: PlayerHidden: dahai: #reason"

    @juntehaiBins[pai.S][pai.N]--
    with @juntehai
      if @tsumo then ..[i] = @tsumo else ..splice(i, 1)
      ..sort Pai.compare
      @tsumo = null

    @decompTenpai = decompTenpai @juntehaiBins
    return pai

  # decompose (3*n+2) hand excluding given pai
  decompTenpaiWithout: (pai) ->
    if !@tsumo then return null
    bins = @juntehaiBins
    if bins[pai.S][pai.N] <= 0 then return null
    bins[pai.S][pai.N]--
    decomp = decompTenpai bins
    bins[pai.S][pai.N]++
    return decomp


  # helper functions
  # mostly for fuuro (chi/pon/kan)
  # NOTE: ALWAYS COUNT BEFORE REMOVE! (no sanity check)

  # count given in juntehai & tsumo
  count: (pai) ->
    s = +(@tsumo == pai)
    for p in @juntehai => if p == pai then s++
    s
  # count given pai in juntehai & tsumo, treating 0m/0p/0s as 5m/5p/5s
  countEquiv: (pai) ->
    @juntehaiBins[pai.S][pai.N]
  # remove n * given pai in juntehai & tsumo
  remove: (pai, n = 1) !->
    @juntehaiBins[pai.S][pai.N] -= n
    @juntehai = @juntehai.filter -> !(it == pai && --n >= 0)
    if @tsumo == pai && --n >= 0 then @tsumo = null
  # remove n * given pai in juntehai & tsumo, treating 0m/0p/0s as 5m/5p/5s
  # return all removed pai
  removeEquiv: (pai, n = 1) ->
    ret = []
    pai .= equivPai
    @juntehaiBins[pai.S][pai.N] -= n
    @juntehai = @juntehai.filter ->
      if it.equivPai == pai && --n >= 0
        ret.push it
        return false
      return true
    if @tsumo?.equivPai == pai && --n >= 0
      ret.push @tsumo
      @tsumo = null
    ret
  # cleanup after removing
  cleanup: !->
    if @tsumo
      @juntehai.push @tsumo
      @tsumo = null
    @juntehai.sort Pai.compare

  # wrapper for `Pai.yaochuuFromBins`
  yaochuu: -> Pai.yaochuuFromBins @juntehaiBins


class PlayerPublic
  (@id, @jikaze) ->
    # sutehai {discarded tile}: (updated through methods)
    #   fuuroPlayer: (only property that can be set externally)
    #     claimed by a player through chi/pon/kan => id of this player
    #     otherwise => null
    #   riichi: if used to *declare* riichi
    # sutehaiBitmap: for fast check of `sutehaiFuriten` condition
    #   same convention as `Pai.binFromBitmap`
    # lastSutehai == sutehai[*-1]
    @sutehai = []
    @sutehaiBitmaps = [0 0 0 0]
    @lastSutehai = null

    # fuuro {melds}: (managed externally)
    #   type: Enum <[ SHUNTSU KOUTSU DAIMINKAN ANKAN KAKAN ]>
    #   pai: equiv. Pai with smallest number (e.g. 67m chi 0m => 5m)
    #   ownPai: array of Pai from this player's juntehai
    #   kakanPai: last Pai that makes the kakan
    #   otherPai: Pai taken from other player
    #   otherPlayer: (as advertised)
    @fuuro = []
    @menzen = true # NOTE: menzen != no fuuro (due to ankan {concealed kan})

    # riichi flags
    @riichi =
      declared: false # goes true immediately after player declares
      accepted: false # goes true when the dahai did not cause ron
      double: false   # goes true if declared during "true first tsumo"
      ippatsu: false  # true only during ippatsu period

  tsumokiri: (pai) -> @dahai pai, true
  dahai: (pai, !!tsumokiri) ->
    @sutehaiBitmaps[pai.suiteNumber] .|.= 1 .<<. pai.N
    sutehai = {
      pai
      riichi: @riichi.declared
      tsumokiri
      fuuroPlayer: null
    }
    @sutehai.push sutehai
    @lastSutehai = sutehai

  # check if pai has been discarded before
  sutehaiContains: (pai) ->
    !!(@sutehaiBitmaps[pai.suiteNumber] .&. (1 .<<. pai.N))
