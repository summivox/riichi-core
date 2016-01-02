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
  events: {EventEmitter}

  'lodash.merge': merge

  '../package.json': {version: VERSION}
  './pai': Pai
  './agari': Agari
  './util': {OTHER_PLAYERS}
  './rulevar-default': rulevarDefault

  './kyoku-event': Event
  './kyoku-player-public': PlayerPublic
}

module.exports = class Kyoku implements EventEmitter::
  # constructor {{{
  #   required:
  #     rulevar: (see `./rulevar-default`)
  #     startState: (see below)
  #   client/replicate:
  #     forPlayer: replicate player id: 0/1/2/3
  #
  ({rulevar, startState, forPlayer}) ->
    @VERSION = VERSION

    # events: always emitted asynchronously (see `@_emit`)
    #   only one event type: `kyoku.on 'event', (e) -> ...`
    EventEmitter.call @

    # rulevar: missing object/fields filled with default
    @rulevar = rulevar = merge {}, rulevarDefault, rulevar

    # startState:
    #   bakaze: 0/1/2/3 => E/S/W/N
    #   chancha: 0/1/2/3
    #   honba: 0/1/2/...
    #   kyoutaku: 0/1/2/...
    #   points: array of each player's points at the start of kyoku
    # NOTE:
    # - immutable
    # - if not supplied, defaults to first kyoku in game
    # - kyoutaku during this kyoku is not reflected in `.points` due to
    #   immutability; see `@globalPublic.delta`
    p0 = rulevar.setup.points.initial
    @startState = startState ?=
      bakaze: 0
      chancha: 0
      honba: 0
      kyoutaku: 0
      points: [p0, p0, p0, p0]
    @chancha = chancha = startState.chancha

    if forPlayer?
      # replicated instance
      @me = forPlayer
      @isReplicated = true
    else
      # master instance
      @isReplicated = false

    # table state visible to all
    @globalPublic = {
      nPiipaiLeft: 70 # == 34*4 - 13*4 - 7*2 == piipai.length
      nKan: 0
      doraHyouji: [] # visible ones only (see `@globalPublic.doraHyouji`)

      # riichi-related: see `@_checkAcceptedRiichi`
      kyoutaku: startState.kyoutaku
      delta: [0 0 0 0]
      nRiichi: 0
    }
    @playerPublic = for p til 4
      new PlayerPublic (4 - chancha + p)%4

    void

    # game progression:
    #   seq: FIXME number of executed events
    #   phase: begin/preTsumo/postTsumo/postDahai/postKan/postChiPon/end
    #   currPlayer: 0/1/2/3
    #   currPai: most recently touched pai
    #     after dahai: sutehai
    #     after fuuro:
    #       chi/pon/daiminkan/ankan: ownPai
    #       kakan: kakanPai
    #   rinshan: true/false
    #     TODO: set flag after kan, clear flag after rinshan tsumo
    @seq = 0
    @phase = \begin
    @currPlayer = chancha
    @currPai = null
    @rinshan = false

    # declarations yet to be resolved during current query
    #
    # NOTE: during one query:
    # - player may only declare once
    # - chi can only be declared by one player
    # - pon/daiminkan can only be declared by one player
    # - ron is not exclusive and might be overwritten; however, this doesn't
    #   matter (see `_resolveRon`)
    @lastDecl =
      chi: null, pon: null, daiminkan: null, ron: null
      0: null, 1: null, 2: null, 3: null
      clear: !-> @chi = @pon = @daiminkan = @ron = @0 = @1 = @2 = @3 = null

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

    # endState: see `@_end`
    @endState = null

    # done (call `nextTurn` to start kyoku)
  #}}}

  # delayed event:
  # - clears call stack
  # - allows methods to finish cleanup
  _emit: (...a) -> process.nextTick ~> @emit ...a

  # called after \query action *declared* (see below)
  # NOTE: details of declared action should NOT be published
  # FIXME
  #_declareAction: ({type, player}:action) !->
    #with @lastDecl
      #..[type] = ..[player] = action
    #@_emit \declare, player, type

  # <master> prepare wall and start game
  #   wall:
  #     [136]pai: given wall (see `./wall`)
  #     null: randomly shuffled wall
  deal: (wall) !->
    if !wall? then wall = Pai.shuffleAll rulevar.dora.akahai
    e = new Event.deal @, wall
    # TODO


  # preparation for a new turn:
  # - check for ryoukyoku
  # - (rinshan) tsumo
  # NOTE:
  # - howanpai already handled by ryoukyoku checks
  # - rinshan tsumo also removes one piipai from tail side so that total
  #   piipai count always decreases by 1 regardless of rinshan or not
  nextTurn: !->
    if @_checkRyoukyoku! then return
    # TODO: Event.tsumo

  # called when kyoku should end:
  # - calculate what next kyoku should be (`endState`)
  _end: (@result) !->
    {setup:
      points: {origin}
      end
    } = @rulevar
    @endState = endState = let
      {bakaze, chancha, honba, points} = @startState
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
        honba = 0
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
      return {bakaze, chancha, honba, kyoutaku, points}
    @phase = \end
    @seq++


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
  _checkQuery: (player) ->
    if player not in [0 1 2 3]
      return valid: false, reason: "bad player"
    if player == @currPlayer or not @phase.startsWith \query
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

  # dahai {discard}
  # - pai: null => tsumokiri
  # - riichi: true => declare riichi before discard

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
    # FIXME: kokushiAnkan
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
  _checkRyoukyoku: !->
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
    | _ => true # one more from another player => suukaikan
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
    if (moro and type == \minjun and d == o) or
       (pon  and type == \minko  and d == o) then return true

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
  # FIXME: kokushiAnkan
  ronPai: ->
    with @lastAction
      switch ..type
      | \kakan => return ..details.kakanPai
      | _ => return ..details.pai


  # assemble information to determine whether a player has a valid win and how
  # many points is it worth
  # FIXME: use new flags
  _agari: (agariPlayer, agariPai, houjuuPlayer = null) ->
    if not agariPai then return null
    gsb = @startState
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
