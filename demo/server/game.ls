global.AUTOBAHN_DEBUG = true
require! {
  './conf': {SERVER, PREFIX, TIME}:CONF

  autobahn

  debug
  moment

  'riichi-core': {Pai, Kyoku, KyokuView, rule, util}
}

# kyoku player-facing method map: action -> test
KYOKU_TURN = {
  dahai: \canDahai
  ankan: \canAnkan
  kakan: \canKakan
  tsumoAgari: \canTsumoAgari
  kyuushuukyuuhai: \canKyuushuukyuuhai
}
KYOKU_QUERY = {
  chi: \canChi
  pon: \canPon
  daiminkan: \canDaiminkan
  ron: \canRon
}

class Game
  # constructor: initialize object only
  (session, @gameId, @rulevar, @players) !->
    @debug = debug "games:#{gameId.substr(0, 8)}"

    # connection
    @$ = session
    @P = P = "#PREFIX.games.#gameId"
    @hooks = []

    # players
    @handles = [..handle for players]
    @uris = ["#P.players." + ..token for players]
    @seatByToken = {[token, i] for {token}, i in players}

    # game engine
    @kyoku = null
    @kyokuInit = null
    @kyokuStr = '' # human-friendly "kyoku title" e.g. "E1.0", "S4.2"

    # init and result of every kyoku
    @history = []

    # sequence number
    # incremented before event is actually published; NEVER reset
    @seq = 0

    # query resolution:
    # timestamp of most recent query
    @queryTime = null
    # bitmap of whether a player has answered to a query
    @answered = 0

  ALL_ANSWERED = (1.<<.4) - 1

  # init: setup connection
  methods = <[
    snapshot
    can_act act
    can_declare declare
  ]> #
  init: ->
    {P, $} = @
    @debug 'initializing...'
    Promise.all [$.register "#P.#m", @[m] for m in methods]
    .catch (err) ~>
      @debug '  FAIL'
      console.error err
      process.exit 3
    .then (@hooks) ~>
      setTimeout @start_kyoku, TIME.preStart
      @debug '  done'

  # end: teardown connection
  end: ~>
    @debug "end"
    Promise.all (@hooks.map -> @$.unregister it)
    .then ~>
      @debug "  hooks removed"
      @$.publish @P, [\end, result]

  # throw user-facing error
  error: (type, ...reason) !->
    throw new autobahn.Error "error.game.#type", reason


  # start: delayed start of 1st kyoku
  # rationale: wait for players to subscribe to events
  start: !~> setTimeout @start_kyoku, TIME.gameStart

  # start a kyoku, setup its events, then notify the players
  # 1st turn is delayed (same reason as `start`)
  start_kyoku: !~>
    @kyokuStr = "#{'ESWN'[@bakaze]}#{@chancha + 1}.#{@honba} [#{@points}]"
    @debug "start kyoku #{@kyokuStr}"
    events = "#{@P}.events"
    $ = @$
    @kyoku = kyoku = with new Kyoku @kyokuInit, @rulevar
      # state transition
      ..on \turn, (p) !~>
        s = ++@seq
        @debug "#s: #{p}P\#TURN"
        $.publish events, [\turn, s, p]
        @turnTimeout = setTimeout (~> @autoplay p), TIME.turn
      ..on \query, (p, lastAction) !~>
        s = ++@seq
        @debug "#s: #{p}P?QUERY"
        @answered = 1.<<.p # the asking p doesn't need to answer
        $.publish events, [\query, s, p, lastAction]
        @queryTime = moment!
        @queryTimeout = setTimeout @resolve, TIME.queryMax
      ..on \resolved, !~>
        s = ++@seq
        @debug "#s: #{p}P"
        $.publish events, [\resolved, s, p]
        clearTimeout @queryTimeout
      ..on \end, @end_kyoku

      # player action
      ..on \action, (p, details) !~>
        s = ++@seq
        @debug "#s: #{p}P@ACTION"
        @$.publish events, [\action, s, p, details]
      ..on \declare, (p, type) !~>
        s = ++@seq
        @debug "#s: #{p}P!#type"
        @$.publish events, [\declare, s, p, type]

      # dora
      ..on \dora, (pai) !~>
        s = ++@seq

      # tsumo:
      # - sent to one player
      # - seq# not increased
      # - always after RINSHAN_/TSUMO
      ..on \tsumo, (p, pai) !~>
        @debug "    (#{p}P tsumo #pai)"
        @$.call "#{uris[p]}.tsumo", [@seq, pai]
        

    @$.publish events, [\kyoku], @{bakaze, chancha, honba, points}
    setTimeout (-> kyoku.advance!), TIME.kyokuStart

  end_kyoku: !~>
    @debug "end_kyoku: #{@kyokuStr}"
    @kyoku = null
    # TODO
    ...
    # continue
    @$.publish @P, [\result], {points: @points, result}
    @start_kyoku!


  # player-facing methods
  # see helpers below

  # return all state visible to this player
  snapshot: ([token]) ~>
    p = @check token
    @debug "snapshot for #{p}P"
    {
      seq: @seq
      handles: @handles
      history: @history
      kyoku: KyokuView.packFromKyoku @kyoku
    }

  can_act: ([token, seq, action, ...args]) ~>
    p = @check token, seq
    @debug "can_act: [#p]{#seq} can-#action(#args)"
    if not (method = KYOKU_TURN[action])
      @error 'can_act', "unrecognized action: #action"
    args.unshift p
    @exec method, args

  act: ([token, seq, action, ...args]) ~>
    if not @kyoku
      @error 'act', "kyoku not started"
    if not (p = @playerMap[token])
      @error 'act', "bad player token: #token"
    p .= seat
    if seq != @seq
      @error 'act', "bad sequence number: #seq"
    @debug "act: [#p]{#seq} #action(#args)"
    if action not of KYOKU_TURN
      @error 'act', "unrecognized action: #action"
    args.unshift p
    @exec action, args, ~>
      clearTimeout @turnTimeout

  can_declare: ([token, seq, decl, ...args]) ~>
    if not @kyoku
      @error 'can_declare', "kyoku not started"
    if not (p = @playerMap[token])
      @error 'can_declare', "bad player token: #token"
    p .= seat
    if seq != @seq
      @error 'can_declare', "bad sequence number: #seq"
    @debug "can_declare: [#p]{#seq} can-#decl(#args)"
    # no double declare during one query
    if @answered.&.(1.<<.p)
      @error 'can_declare', "duplicate response"
    # always okay to "pass" with explicit null
    if decl == null then return valid: true
    if not (method = KYOKU_QUERY[decl])
      @error 'can_declare', "unrecognized declaration: #decl"
    args.unshift p
    @exec method, args

  declare: ([token, seq, decl, ...args]) ~>
    if not @kyoku
      @error 'declare', "kyoku not started"
    if not (p = @playerMap[token])
      @error 'declare', "bad player token: #token"
    p .= seat
    if seq != @seq
      @error 'declare', "bad sequence number: #seq"
    @debug "can_declare: [#p]{#seq} #decl(#args)"
    # no double declare during one query
    if @answered.&.(1.<<.p)
      @error 'declare', "duplicate response"
    # always okay to "pass" with explicit null
    if decl != null and decl not of KYOKU_QUERY
      @error 'declare', "unrecognized declaration: #decl"
    args.unshift p
    @exec decl, args, ~>
      if (@answered.|.= (1.<<.p)) == 2~1111
        # everyone has answered
        clearTimeout @queryTimeout
        now = moment!diff @queryTime, 'ms'
        @debug "declare: received all answers at #now ms"
        # random lower bound of resolve delay
        expected = util.randomRange(TIME.queryMin, TIME.queryRand)
        if (dt = expected - now) > 5
          @debug "declare: random delay #dt ms"
          setTimeout @resolve, dt
        else
          process.nextTick @resolve!


  # helpers

  # common checks: token and sequence number
  # return player seat index if okay to proceed
  # otherwise throw error
  check: (token, seq) ->
    if not @kyoku
      @error 'check', "kyoku not started"
    if not (p = @seatByToken[token])
      @error 'check', "bad player token #token"
    if seq? and seq != @seq
      @error 'check', "bad sequence number #seq (should be #{@seq})"
    return p

  # call a kyoku method:
  #   success => callback (synchronous) then return
  #   error => convert error
  exec: (method, args, cb) ~>
    if method
      try
        ret = @kyoku[method](...args)
      catch e
        @error 'kyoku', e.message
    if cb? then cb!
    ret


  # wrapper for resolving current query
  resolve: ~>
    @debug "resolve"
    @kyoku.resolveQuery!

  # default actions when a player is AFK or disconnected
  autoplay: (p) ~>
    @debug "autoplay for #{p}P"
    # FIXME: nop for now
