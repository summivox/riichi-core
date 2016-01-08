require! {
  events: {EventEmitter}

  'chai': {assert}
  'lodash.merge': merge

  '../package.json': {version: VERSION}
  './pai': Pai
  './agari': Agari
  './util': {OTHER_PLAYERS}
  './rulevar-default': rulevarDefault

  './kyoku-event': Event
  './kyoku-player-public': PlayerPublic
  './kyoku-player-hidden': PlayerHidden
}

module.exports = class Kyoku implements EventEmitter::
  # constructor {{{
  #   rulevar: (see `./rulevar-default`)
  #   startState: (see below)
  #   forPlayer: ?Integer
  #     null: master
  #     0/1/2/3: replicate player id
  ({rulevar, startState, forPlayer}) ->
    @VERSION = VERSION

    # events: always emitted asynchronously (see `@_emit`)
    #   only one event type: `kyoku.on 'event', (e) -> ...`
    #   TODO: specify event feed format (log, [4]partial)
    EventEmitter.call @

    # rulevar: use default for missing entries
    @rulevar = rulevar = merge {}, rulevarDefault, rulevar

    # startState: initial condition for this kyoku
    #   bakaze: 0/1/2/3 => E/S/W/N
    #   chancha: 0/1/2/3
    #   honba: 0/1/2/...
    #   kyoutaku: 0/1/2/...
    #   points: array of each player's points at the start of kyoku
    # NOTE:
    # - immutable
    # - defaults to first kyoku in game
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
      nPiipaiLeft: 70 # == 34*4 - 13*4 - 7*2 == piipai.length (at start)
      nKan: 0 # redundant -- maintained here for easy checks
      doraHyouji: [] # visible ones only
    }
    @playerPublic = for p til 4
      new PlayerPublic (4 - chancha + p)%4

    # hidden table state: built by `deal` event
    @globalHidden = null
    @playerHidden = null

    # game progression:
    #   seq: Integer -- number of executed events
    #   phase: begin/preTsumo/postTsumo/postDahai/postKan/postChiPon/end
    #   currPlayer: 0/1/2/3
    #   currPai: Pai -- most recently touched pai
    #     after dahai: sutehai
    #     after fuuro:
    #       chi/pon/daiminkan/ankan: `ownPai`
    #       kakan: `kakanPai`
    #   rinshan: Boolean
    #   virgin: Boolean
    #     original definition: first 4 tsumo-dahai in natural order,
    #     uninterrupted by any declarations
    #     equivalent: ippatsu of chancha's kamicha (previous)
    @seq = 0
    @phase = \begin
    @currPlayer = chancha
    @currPai = null
    @rinshan = false
    @virgin = true

    # conflict resolution for declarations
    # - player may only declare one action
    # - chi can only be declared by one player
    # - pon/daiminkan can only be declared by one player
    # - ron can be declared by multiple players
    @currDecl =
      chi: null, pon: null, daiminkan: null, ron: null
      0: null, 1: null, 2: null, 3: null
      add: ({what, player}:x) -> @[what] = @[player] = x
      resolve: (player) ->
        switch
        | (@ron)?
          ret = [@[..] for OTHER_PLAYERS[player] when @[..]?.what == \ron]
        | (ret = @daiminkan)? => void
        | (ret = @pon)? => void
        | (ret = @chi)? => void
        | _ => ret = {what: \nextTurn}
        @chi = @pon = @daiminkan = @ron = @0 = @1 = @2 = @3 = null
        return ret

    # result: updated as game progresses
    #   common:
    #     type: tsumoAgari/ron/ryoukyoku
    #     delta: []Integer -- points increment for each player
    #     kyoutaku: Integer -- how much kyoutaku remains on table
    #     renchan: Boolean
    #   tsumoAgari:
    #     agari: Agari
    #   ron:
    #     agari: []Agari -- in natural turn order from `houjuuPlayer`
    #   ryoukyoku:
    #     reason: String
    KYOUTAKU_UNIT = rulevar.riichi.kyoutaku
    @result =
      type: null
      delta: [0 0 0 0]
      kyoutaku: startState.kyoutaku
      renchan: false
      # called when a player declares riichi
      giveKyoutaku: (player) ->
        @delta[player] -= KYOUTAKU_UNIT
        @kyoutaku++
      # called when a player wins
      takeKyoutaku: (player) ->
        @delta[player] += @kyoutaku * KYOUTAKU_UNIT
        @kyoutaku = 0

    # same format as `startState`
    @endState = null

    # done (call `nextTurn` to start kyoku)
  # }}}

  # execute an event, then run automatic hooks
  exec: (event) !->
    if !event.kyoku? then event.init this
    assert.equal event.kyoku, this
    event.apply!
    process.nextTick ~> @emit \event, {event}
    if @phase == \preTsumo
      if not @_checkRyoukyoku!
        @exec new Event.tsumo this
    #switch @phase
    #| \preTsumo => @exec new Event.tsumo this
    #| \postDahai => @_checkRyoukyoku!

  # game progress methods on master {{{

  # prepare wall and start game
  #   wall: ?[136]Pai -- defaults to randomly shuffled
  deal: (wall) -> @exec new Event.deal this, {wall}

  # resolve declarations after dahai/ankan/kakan
  resolve: !->
    assert @phase in <[postDahai, postKan]>#
    with @currDecl.resolve @currPlayer
      if .. not instanceof Array
        # chi/pon/daiminkan
        @exec new Event[..what](this, ..args)
      else
        # (multi-)ron
        {atamahane, double, triple} = @rulevar.ron
        nRon = ..length
        chancha = @chancha
        if (nRon == 2 and not double) or (nRon == 3 and not triple)
          return @exec new Event.ryoukyoku this,
            renchan: ..some (.player == chancha)
            reason: if nRon == 2 then \doubleRon else \tripleRon
            # TODO: ryoukyoku ctor API
        for {player, args}, i in ..
          args.isLast = i == nRon - 1
          @exec new Event.ron this, args
          if atamahane then break

  # }}}

  # read-only helper methods {{{

  # calculate `endState`:
  #   result: same format as @result
  #   return:
  #     null: game over
  #     same format as `startState`: `startState` of next kyoku in game
  getEndState: (result) ->
    {setup:
      points: {origin}
      end
    } = @rulevar
    {bakaze, chancha, honba, points} = @startState
    {kyoutaku, delta, renchan} = result

    # apply delta to points
    points = points .= slice!
    for i til 4
      if (points[i] += delta[i]) < 0
        # strictly negative points not allowed
        return null

    # determine next bakaze/chancha
    newBakaze = false
    if renchan
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

  # tochuu ryoukyoku conditions {{{
  # NOTE: assuming pre-tsumo
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
    | 4 => not @suukantsuCandidate!? # all by the same player => not suukaikan
    | _ => true # one more from another player => suukaikan
  suuchariichi: -> @playerPublic.every (.riichi.accepted)
  # }}}

  # kuikae: refers to the situation where a player declares chi with two pai in
  # juntehai and then dahai {discards} one, but these three pai alone can be
  # considered as a shuntsu; this is usually forbidden. Depending on rule
  # variations, it could also be forbidden to pon then dahai the same pai.
  # Akahai {red 5} is treated the same as normal 5.
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

  # check if one player alone has made 4 kan (see `suukaikan`)
  suukantsuCandidate: ->
    if @globalPublic.nKan < 4 then return null
    for player til 4
      with @playerPublic[player].fuuro
        if ..length == 4 and ..every (.type not in <[minjun minko]>)
          return player
    return null

  # TODO: describe
  agari: (agariPlayer, {juntehai, tsumohai}, houjuuPlayer) ->
    SS = @startState
    GH = @globalHidden
    GP = @globalPublic
    PP = @playerPublic[agariPlayer]
    input = {
      rulevar: @rulevar

      agariPai: tsumohai ? @currPai
      juntehai
      decompTenpai: decompTenpai Pai.binsFromArray juntehai
      fuuro: PP.fuuro
      menzen: PP.menzen
      riichi: PP.riichi

      chancha: @chancha
      agariPlayer: agariPlayer
      houjuuPlayer: houjuuPlayer

      honba: SS.honba
      bakaze: SS.bakaze
      jikaze: PP.jikaze
      doraHyouji: GH.doraHyouji
      uraDoraHyouji: GH.uraDoraHyouji
      nKan: GP.nKan

      rinshan: @rinshan
      chankan: @phase == \afterKan
      isHaitei: GP.nPiipaiLeft == 0
      virgin: @virgin
    }
    a = new Agari input
    if not a.isAgari then return null
    {[k, v] for k, v of a when k not of AGARI_BLACKLIST} # FIXME

  AGARI_BLACKLIST = {
    -rulevar
    -decompTenpai
  }

  # }}}

  # state mutating hooks (common building blocks of events) {{{

  # always called by an event after conflict resolution if no ron has been
  # declared on dahai/ankan/kakan
  _didNotHoujuu: (event) !->
    # end of ippatsu/virgin
    # NOTE: this must happen before accepting riichi
    if @phase == \postDahai and event.type == \nextTurn
      # natural end of ippatsu for current player
      # virgin can be considered ippatsu of north player
      @playerPublic[@currPlayer].riichi.ippatsu = false
      if @currPlayer == (@chancha + 3)%4 then @virgin = false
    else
      # fuuro has happened -- all ippatsu broken
      @playerPublic.forEach (.riichi.ippatsu = false)
      @virgin = false
    # if riichi was declared, it becomes accepted
    @playerPublic[@currPlayer].riichi
      ..accepted = true
      ..ippatsu = true
    @result.giveKyoutaku @currPlayer
    # if `currPai` belongs to some player's tenpai set, he enters doujun/riichi
    # furiten state until he actively chooses dahai
    for op in OTHER_PLAYERS[@currPlayer]
      with @playerHidden[op] => if .. instanceof PlayerHidden
        if @currPai.equivPai in ..decompTenpai.wait
          ..furiten = true
          ..doujunFuriten = true
          ..riichiFuriten = @playerPublic[op].riichi.accepted

  # }}}

  # LEGACY METHODS YET TO BE MERGED {{{

  # state updates after player action

  # enforce ryoukyoku {abortive/exhaustive draw} rules
  # see `@suufonrenta` and friends
  _checkRyoukyoku: !->
    # tochuu ryoukyoku {abortive draw}
    # FIXME: security risk?
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

  # }}}
