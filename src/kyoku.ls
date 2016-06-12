require! {
  events: {EventEmitter}

  'chai': {assert}
  'lodash.merge': merge

  '../package.json': {version: VERSION}
  './pai': Pai
  './agari': Agari
  './decomp': {decompTenpai}
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
  ({rulevar, startState, forPlayer} = {}) ->
    @VERSION = VERSION

    # events:
    #   only one event type: `kyoku.on \event, (e) -> ...`
    #   TODO: specify event feed format (log, [4]partial)
    EventEmitter.call @

    # rulevar: use default for missing entries
    # XXX: consider using  `_.defaultsDeep` (mutates `rulevar`)
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
    p0 = rulevar.points.initial
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
      @isReplicate = true
    else
      # master instance
      @isReplicate = false

    # TODO: doc
    @wallParts = null

    # common state:
    #   seq: Integer -- number of executed events
    #   phase: String
    #     begin/preTsumo/postTsumo/postDahai/
    #     postAnkan/postKakan/postChiPon/end
    #     TODO: doc
    #   currPlayer: 0/1/2/3
    #   currPai: ?Pai -- most recently touched pai
    #     after tsumo: tsumohai (can be null in replicate)
    #     after dahai: sutehai
    #     after fuuro:
    #       chi/pon/daiminkan/ankan: ownPai
    #       kakan: kakanPai
    #   rinshan: Boolean
    #   virgin: Boolean
    #     original definition: first 4 tsumo-dahai in natural order,
    #     uninterrupted by any declarations
    #     equivalent: ippatsu of chancha's kamicha (previous)
    #   nTsumoLeft: Integer -- how many times players may still tsumo
    #   nKan: 0/1/2/3/4 -- total number of kan (cache)
    #   doraHyouji: []Pai -- currently REVEALED dora-hyoujihai
    #   uraDoraHyouji: []Pai -- currently REVEALED uradora-hyoujihai
    @seq = 0
    @phase = \begin
    @currPlayer = chancha
    @currPai = null
    @rinshan = false
    @virgin = true
    @nTsumoLeft = 70 # == 34*4 - 13*4 - 7*2 == piipai.length (at start)
    @nKan = 0
    @doraHyouji = []
    @uraDoraHyouji = []

    # player state: placeholder; initialized by `Event.deal::apply`
    @playerHidden = null
    @playerPublic = null

    # conflict resolution for declarations
    # after a particular event:
    # - one player may at most declare once
    # - chi can only be declared by one player
    # - pon/daiminkan can only be declared once
    # - ron can be declared by multiple players (multi-ron)
    # - if no one declares, default to next natural turn
    #
    # NOTE: ron resolution order is natural turn order after current player
    kyoku = this # for reference to `currPlayer`
    @currDecl =
      chi: null, pon: null, daiminkan: null, ron: null
      0: null, 1: null, 2: null, 3: null
      add: ({what, player}:decl) -> @[what] = @[player] = decl
      clear: -> @chi = @pon = @daiminkan = @ron = @0 = @1 = @2 = @3 = null
      resolve: ->
        | @ron?
          for p in OTHER_PLAYERS[kyoku.currPlayer]
            if @[p]?.what == \ron then @[p]
        | @daiminkan? => that
        | @pon? => that
        | @chi? => that
        | _ => {what: \nextTurn, args: null}
        # NOTE: no need to call `clear` (Event::apply will)

    # result: updated as game proceeds
    #   common:
    #     type: tsumoAgari/ron/ryoukyoku
    #     delta: []Integer -- points increment for each player
    #     points: []Integer -- current points for each player (derived)
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
      points: ~-> [@delta[p] + startState.points[p] for p til 4]
      # called when a player declares riichi
      giveKyoutaku: (player) ->
        @delta[player] -= KYOUTAKU_UNIT
        @kyoutaku++
      # called when a player wins
      takeKyoutaku: (player) ->
        @delta[player] += @kyoutaku * KYOUTAKU_UNIT
        @kyoutaku = 0

    # same format as `startState` -- see `getEndState` and `_end`
    @endState = null
  # }}}

  # execute an event
  exec: (event) !->
    if !event.kyoku? then event.init this
    assert.equal event.kyoku, this
    assert.equal event.seq, @seq
    event.apply!
    @seq++
    @emit \event, event

  # execute an (unserialized) event
  execImported: (event) !->
    @exec (Event.import event).init(this)

  # game progress methods (master only) {{{

  # prepare wall and start game
  #   wall: ?[136]Pai -- defaults to randomly shuffled
  deal: (wall) ->
    assert not @isReplicate
    @exec new Event.deal this, {wall}

  # begin of turn: tsumo or ryoukyoku
  begin: ->
    assert not @isReplicate
    assert @phase != \end
    # check for tochuu ryoukyoku
    for reason in <[suufonrenta suukaikan suuchariichi]>
      switch @rulevar.ryoukyoku.tochuu[reason]
      | false => continue
      | true => renchan = true
      | _ => renchan = false
      if @[reason]!
        return @exec new Event.ryoukyoku this, {renchan, reason}
    # check for howanpai ryoukyoku
    if @nTsumoLeft == 0 then return @exec new Event.howanpai this
    # nothing happens; go on with tsumo
    @exec new Event.tsumo this

  # resolve declarations after dahai/ankan/kakan
  resolve: !->
    assert not @isReplicate
    assert @phase in <[postDahai postAnkan postKakan]>#
    with @currDecl.resolve!
      if .. not instanceof Array
        # chi/pon/daiminkan/nextTurn
        @exec new Event[..what](this, ..args)
      else
        # (multi-)ron
        # NOTE: ordering handled by `@currDecl.resolve`
        {atamahane, double, triple} = @rulevar.ron
        nRon = ..length
        chancha = @chancha
        if (nRon == 2 and not double) or (nRon == 3 and not triple)
          return @exec new Event.ryoukyoku this,
            renchan: ..some (.player == chancha)
            reason: if nRon == 2 then \doubleRon else \tripleRon
        if atamahane
          @exec new Event.ron this, {player, +isFirst, +isLast}
        else for {player, args: {player}}, i in ..
          @exec new Event.ron this, {
            player
            isFirst: i == 0
            isLast: i == nRon - 1
          }

  # }}}

  # read-only helper methods {{{

  # get doraHyouji to be revealed, accounting for minkan delay (master only)
  getNewDoraHyouji: ({type}:event) ->
    assert not @isReplicate
    if not (rule = @rulevar.dora.kan) then return []
    lo = @doraHyouji.length
    hi = @nKan + (rule[type] ? 0)
    if hi < lo then return null
    return @wallParts.doraHyouji[lo to hi]

  # get all revealed uraDoraHyouji after agari under riichi (master only)
  getUraDoraHyouji: (player) ->
    {ura, kanUra} = @rulevar.dora
    switch
    | not @playerPublic[player].riichi.accepted => []
    | not ura => []
    | not kanUra => [@wallParts.uraDoraHyouji.0]
    | _ => @wallParts.uraDoraHyouji[0 to @nKan]

  # calculate `endState`:
  #   result: same format as @result
  #   return:
  #     null: game over
  #     same format as `startState`: `startState` of next kyoku in game
  getEndState: (result) ->
    {points: {origin}, end} = @rulevar.setup
    {bakaze, chancha, honba} = @startState
    {kyoutaku, renchan, points} = result

    # negative points means game over
    if points.some (<0) then return null

    # determine next bakaze/chancha
    newBakaze = false
    if renchan
      # all-last oya top
      if end.oyaALTop and bakaze == end.normal - 1 and chancha == 3
      and points[0 to 2].every (< points[3])
          return null
      honba++
    else
      honba = 0
      if ++chancha == 4
        chancha = 0
        bakaze++
        newBakaze = true

    # handle overtime / sudden-death
    if bakaze < end.normal then void
    else if bakaze < end.overtime
      if (newBakaze or end.suddenDeath)
      and points.some (>= origin) then return null
    else return null

    # next kyoku
    return {bakaze, chancha, honba, kyoutaku, points}

  # tochuu ryoukyoku conditions {{{
  # NOTE: assuming pre-tsumo
  suufonrenta: ->
    pai = new Array 4
    for p til 4 => with @playerPublic[p]
      if ..fuuro.length == 0 and ..sutehai.length == 1
        pai[p] = ..sutehai.0.pai
      else return false
    return pai.0.isFonpai and pai.0 == pai.1 == pai.2 == pai.3
  suukaikan: ->
    switch @nKan
    | 0, 1, 2, 3 => false
    | 4 => not @suukantsuCandidate!? # all by the same player => not suukaikan
    | _ => true # one more from another player => suukaikan
  suuchariichi: -> @playerPublic.every (.riichi.accepted)
  # }}}

  # precondition for declaring ron, without regard of yaku
  # keiten == keishiki-tenpai (tenpai in form)
  # TODO: pick a better name (this name usually has a narrower connotation)
  isKeiten: (tenpaiDecomp) ->
    if @currPai.equivPai not in tenpaiDecomp.wait then return false
    if @phase == \postAnkan
      return @rulevar.yaku.kokushiAnkan and tenpaiDecomp.0?.k7 == \kokushi
    return true

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
    if @nKan < 4 then return null
    for player til 4
      with @playerPublic[player].fuuro
        if ..length == 4 and ..every (.type not in <[minjun minko]>)
          return player
    return null

  # TODO: describe
  agari: ({type, player, juntehai, tsumohai, tenpaiDecomp}:event) ->
    switch type
    | \ron
      agariPlayer = player
      houjuuPlayer = @currPlayer
      agariPai = @currPai
      if @rulevar.ron.honbaAtamahane and not event.isFirst
        honba = 0
      else
        honba = @startState.honba
    | \tsumoAgari
      agariPlayer = @currPlayer
      houjuuPlayer = null
      agariPai = tsumohai
      honba = @startState.honba
    | _ => return null

    {jikaze, fuuro, menzen, riichi} = @playerPublic[agariPlayer]
    tenpaiDecomp ?= decompTenpai Pai.binsFromArray juntehai

    input = {
      rulevar: @rulevar

      agariPai: tsumohai ? @currPai
      juntehai
      tenpaiDecomp
      fuuro
      menzen
      riichi

      chancha: @chancha
      agariPlayer
      houjuuPlayer

      honba
      bakaze: @startState.bakaze
      jikaze
      doraHyouji: @doraHyouji
      uraDoraHyouji: @uraDoraHyouji
      nKan: @nKan

      rinshan: @rinshan
      chankan: @phase in <[postKakan postAnkan]>#
      # NOTE: kokushiAnkan already handled in `isKeiten`
      isHaitei: @nTsumoLeft == 0
      virgin: @virgin
    }
    a = new Agari input
    if not a.isAgari then return null
    {[k, v] for k, v of a when k not of AGARI_BLACKLIST} # FIXME

  AGARI_BLACKLIST = {
    -rulevar
    -tenpaiDecomp
  }

  # }}}

  # state mutating hooks (common building blocks of events) {{{

  # TODO: describe, link to getNewDoraHyouji
  _addDoraHyouji: (doraHyouji) ->
    if doraHyouji?.length > 0
      @doraHyouji.push ...doraHyouji

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

    # if riichi was just declared, it becomes accepted
    with @playerPublic[@currPlayer].riichi
      if ..declared and not ..accepted
        ..accepted = true
        ..ippatsu = true
        @result.giveKyoutaku @currPlayer

    # maintain furiten state: see `PlayerPublic::furiten`
    if @phase == \postDahai
      PP = @playerPublic[@currPlayer]
      with @playerHidden[@currPlayer] => if .. instanceof PlayerHidden
        ..sutehaiFuriten = ..tenpaiDecomp.wait.some -> PP.sutehaiContains it
        ..doujunFuriten = false
        ..furiten = ..sutehaiFuriten or ..riichiFuriten # or ..doujunFuriten
    for op in OTHER_PLAYERS[@currPlayer]
      with @playerHidden[op] => if .. instanceof PlayerHidden
        if @isKeiten ..tenpaiDecomp
          ..furiten = true
          ..doujunFuriten = true
          ..riichiFuriten = @playerPublic[op].riichi.accepted

  _end: !->
    @endState = @getEndState @result
    @phase = \end

  # }}}

