/**
@module kyoku
*/

require! {
  events: {EventEmitter}

  'lodash.defaultsdeep': defaultsDeep

  '../package.json': {version: VERSION}
  './pai': Pai
  './agari': Agari
  './decomp': {decompTenpai}
  './util': {OTHER_PLAYERS}
  './rulevar-default': rulevarDefault

  './event': Event

  './player-state/hidden': PlayerHidden
}

CurrDecl =
  validate: ({type, player}:decl) ->
    if @[type]? and type != \ron
      throw Error "duplicate declare: #type from player #player"
    if @[player]?
      throw Error "duplicate declare: #type from player #player"
  add: ({type, player}:decl) ->
    @[type] = @[player] = decl
    @count++
  clear: ->
    @chi = @pon = @daiminkan = @ron = @0 = @1 = @2 = @3 = null
    @count = 0
  resolve: -> @daiminkan ? @pon ? @chi

Result =
  # called when a player declares riichi
  giveKyoutaku: (player) ->
    @delta[player] -= @KYOUTAKU_UNIT
    @kyoutaku++
  # called when a player wins
  takeKyoutaku: (player) ->
    @delta[player] += @kyoutaku * @KYOUTAKU_UNIT
    @kyoutaku = 0

/**
@classdesc

@global
@class Kyoku
*/
module.exports = class Kyoku implements EventEmitter::
  # constructor {{{
  #   rulevar: (see `./rulevar-default`)
  #   startState: (see below)
  #   forPlayer: ?Integer
  #     null: server
  #     0/1/2/3: client player id
  ({rulevar, startState, forPlayer} = {}) ->
    @VERSION = VERSION

    # subscribe to executed events: `kyoku.on \event, (event) -> ...`
    EventEmitter.call @

    # rulevar: use default for missing entries
    @rulevar = defaultsDeep rulevar, rulevarDefault

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
      # clientd instance
      @me = forPlayer
      @isClient = true
    else
      # server instance
      @isClient = false

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
    #     after tsumo: tsumohai (can be null in client)
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

    # TODO: move CurrDecl and Result to separate files and make factories

    # conflict resolution for declarations
    # after a particular event:
    # - one player may at most declare once
    # - chi can only be declared by one player
    # - pon/daiminkan can only be declared once
    # - ron can be declared by multiple players (multi-ron)
    # - if no one declares, default to next natural turn
    #
    # NOTE: ron resolution order is natural turn order after current player
    @currDecl = CurrDecl with
      chi: null, pon: null, daiminkan: null, ron: null
      0: null, 1: null, 2: null, 3: null
      count: 0

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
    @result = Result with
      KYOUTAKU_UNIT: rulevar.riichi.kyoutaku
      type: null
      delta: [0 0 0 0]
      kyoutaku: startState.kyoutaku
      renchan: false
      points: ~-> [@delta[p] + startState.points[p] for p til 4]

    # same format as `startState` -- see `getEndState` and `_end`
    @endState = null
  # }}}

  # execute an event
  # TODO: use new event format
  exec: (event) !->
    if !event.kyoku? then event.init this
    assert.equal event.kyoku, this
    assert.equal event.seq, @seq
    event.apply!
    @seq++
    @emit \event, event

  # game progress methods (server only) {{{

  # prepare wall and start game
  #   wall: ?[136]Pai -- defaults to randomly shuffled
  # TODO: adapt to new event format
  deal: (wall) ->
    if @isClient then throw Error "can only be executed on server"
    @exec new Event.deal this, {wall}

  # start player's turn: tsumo or ryoukyoku
  # TODO: adapt to new event format
  go: ->
    if @isClient then throw Error "can only be executed on server"
    unless @phase == \preTsumo
      throw Error "wrong phase #{@phase} (should be 'preTsumo')"
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

  /*
  # FIXME
  # resolve declarations after dahai/ankan/kakan
  # TODO: adapt to new event format
  resolve: !->
    if @isClient then throw Error "can only be executed on server"
    assert @phase in <[postDahai postAnkan postKakan]>#
    if @currDecl.ron?
      {atamahane, double, triple} = @rulevar.ron
      nRon = ..length
      chancha = @chancha
      if (nRon == 2 and not double) or (nRon == 3 and not triple)
        return @exec new Event.ryoukyoku this,
          renchan: ..some (.player == chancha)
          reason: if nRon == 2 then \doubleRon else \tripleRon
      if atamahane
        @exec new Event.ron this, {player, +isFirst, +isLast}
      else for {player}, i in ..
        @exec new Event.ron this, {
          player
          isFirst: i == 0
          isLast: i == nRon - 1
        }
    else if @currDecl.resolve!?
      # chi/pon/daiminkan
      ...
    else
      # nextTurn
      ...
  */

  # }}}

  # read-only helper methods {{{

  # get doraHyouji to be revealed, accounting for minkan delay (server only)
  getNewDoraHyouji: (type) ->
    assert not @isClient
    if not (rule = @rulevar.dora.kan) then return []
    lo = @doraHyouji.length
    hi = @nKan + (rule[type] ? 0)
    if hi < lo then return null
    return @wallParts.doraHyouji[lo to hi]

  # get all revealed uraDoraHyouji after agari under riichi (server only)
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
      # all-last oya top (agariyame)
      if end.agariyame and bakaze == end.normal - 1 and chancha == 3
      and points[0 to 2].every (< points[3])
          return null
      honba++
    else
      if result.type == \ryoukyoku then honba++ else honba = 0
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
    if @currPai.equivPai not in tenpaiDecomp.tenpaiSet then return false
    if @phase == \postAnkan
      return @rulevar.yaku.kokushiAnkan and
        tenpaiDecomp.decomps.0?.k7 == \kokushi
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
  #
  # NOTE: this does not depend on current kyoku state by design
  isKuikae: (fuuro, dahai) ->
    {type, ownPai, otherPai} = fuuro
    if type not in <[minjun minko]> then return false
    bans = @rulevar.banKuikae
    if !bans? then return false
    {moro, suji, pon} = bans

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

  # }}}

  # state mutating hooks (common building blocks of events) {{{

  # TODO: describe, link to getNewDoraHyouji
  _addDoraHyouji: (doraHyouji) ->
    if doraHyouji?.length > 0
      @doraHyouji.push ...doraHyouji

  # always called by an event after conflict resolution if no ron has been
  # declared on dahai/ankan/kakan
  _didNotHoujuu: (type) !->
    # end of ippatsu/virgin
    naturalEnd = (@phase == \postDahai and type == \nextTurn)
    if naturalEnd
      # natural end of ippatsu for current player
      # virgin can be considered ippatsu of north player
      @playerPublic[@currPlayer].riichi.ippatsu = false
      if @virgin and @currPlayer == (@chancha + 3)%4 then @virgin = false
    else
      # fuuro has happened -- all ippatsu broken
      @playerPublic.forEach (.riichi.ippatsu = false)
      @virgin = false

    # if riichi was just declared, it becomes accepted
    with @playerPublic[@currPlayer].riichi
      if ..declared and not ..accepted
        ..accepted = true
        ..ippatsu = naturalEnd # fuuro on riichi => still no ippatsu
        @result.giveKyoutaku @currPlayer

    # maintain furiten state: see `PlayerPublic::furiten`
    if @phase == \postDahai
      PP = @playerPublic[@currPlayer]
      with @playerHidden[@currPlayer] => if not ..isMock
        ..sutehaiFuriten = ..tenpaiDecomp.tenpaiSet.some ->
          PP.sutehaiContains it
        ..doujunFuriten = false
        ..furiten = ..sutehaiFuriten or ..riichiFuriten # or ..doujunFuriten
    for op in OTHER_PLAYERS[@currPlayer]
      with @playerHidden[op] => if not ..isMock
        if @isKeiten ..tenpaiDecomp
          ..furiten = true
          ..doujunFuriten = true
          ..riichiFuriten = @playerPublic[op].riichi.accepted

  # rebuild/build revealed hand
  # TODO: cross-check furiten retroactively
  _revealHidden: (player, juntehai, tsumohai) ->
    if @playerHidden[player].isMock
      @playerHidden[player] = (new PlayerHidden juntehai) <<< {tsumohai}
    else
      @playerHidden[player]

  _end: !->
    @endState = @getEndState @result
    @phase = \end

  # }}}

