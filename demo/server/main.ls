global.AUTOBAHN_DEBUG = true
require! {
  # comm
  autobahn
  './conf': {SERVER, PREFIX, TIMEOUT}:CONF

  # util
  'node-uuid': uuid
  debug
  moment

  # game engine
  'riichi-core': {Pai, Kyoku, decomp, rule, util}
}

# FIXME: I can't find better place for this
process.nextTick -> decomp.init!

# debug logger
debug.log = console.info.bind console
debugMain = debug 'main'

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

# socket
S = null # session
ACK = acknowledge: true # shorthand for publish + ack
conn = new autobahn.Connection SERVER
conn.onopen = main
conn.onclose = (reason, details) ->
  debugMain "connection closed: #{reason}"
  S = null
conn.open!

function main(session)
  debugMain "connected"
  S := conn.session
  S.prefix "riichi", PREFIX
  S.register "riichi:game.new", newGame

games = {}
function newGame()
  # find short but unique gameId
  while (gameId = uuid!substring(0, 8)) of games => void
  debugMain "new game #{gameId}"
  games[gameId] = g = new Game gameId
  g.init!

# NOTE: methods are snake_case named for consistency with WAMP protocol
class Game
  (@gameId) !->
    @debug = debug "game:#gameId"
    @prefix = "riichi:game.#gameId"
    @state = null
    @players = []
    @playerMap = {}

    # kyoku
    @kyoku = null
    @kyokuStr = ''
    @kyokuResult = null

    # timeouts
    @joinTimeout = @idleTimeout = @turnTimeout = @queryTimeout = null
    @queryTime = moment!

    # sequence number: prevent acting on stale state
    @seq = 0
    # bitmap of whether a player has answered to a query
    @answered = 0

    # initial condition
    @bakaze = 0
    @chancha = 0
    @honba = 0
    @kyoutaku = 0
    @points = [25000 25000 25000 25000]

  _error: (type, ...reason) ~>
    throw new autobahn.Error "#{@prefix}.#type.error", reason

  # logistics (before game actually starts)
  init: ->
    @debug "init"
    @state = \init
    P = @prefix
    Promise.all [
      S.register "#P.join", @join
      S.register "#P.leave", @leave
      S.register "#P.get_state", @get_state
      S.register "#P.can_act", @can_act
      S.register "#P.act", @act
      S.register "#P.can_declare", @can_declare
      S.register "#P.declare", @declare
    ]
      .then (@hooks) ~>
        @joinTimeout = setTimeout @end, TIMEOUT.join
        @idleTimeout = setTimeout @end, TIMEOUT.idle
        @debug "init: complete"
        @state = \idle
        return @gameId
  end: (result = 'timeout') ~>
    @debug "end: [#result]"
    if @state == \idle
      clearTimeout @joinTimeout
      clearTimeout @idleTimeout
    @state = \end
    delete games[@gameId]
    Promise.all (@hooks.map -> S.unregister it)
      .then ~>
        @debug "end: broadcast"
        S.publish @prefix, [\end, result], {}, ACK
  join: ([name]) ~>
    @debug "join: #name"
    if @state != \idle then @_error \join, "game in #{@state} state"
    # reset join timeout
    clearTimeout @joinTimeout
    @joinTimeout = setTimeout @end, TIMEOUT.join
    # check for name clash / double join
    if @players.some (.name == name)
      @_error 'join', "player with name #name already exists"
    # add player to list
    token = uuid!
    @players.push name: name, token: token
    S.publish @prefix, [\join, name], {}, ACK
      .then ~> @start!
    return token
  leave: ([token]) ~>
    @debug "leave: #token"
    if @state != \idle
      @_error 'leave', "cannot leave; game in #{@state} state"
    # reset join timeout
    clearTimeout @joinTimeout
    @joinTimeout = setTimeout @end, TIMEOUT.join
    # find player and take it out
    for player, i in @players
      if player.token == token
        @players.splice i, 1
        S.publish @prefix, [\leave, player.name], {}, ACK
          .then ~> @start!
        return true
    @_error 'leave', "player with token #token does not exist"
  start: ~>
    @debug "start: state=#{@state}, nPlayer = #{@players.length}"
    if @state != \idle or @players.length != 4 then return false
    # clear join/idle timeouts
    clearTimeout @joinTimeout
    clearTimeout @idleTimeout
    # assign seats
    util.randomShuffle @players
    for player, i in @players
      player.seat = i
      @playerMap[player.token] = player
    @state = \playing
    @debug "start: good to go"
    S.publish @prefix, [\start, @players.map (.name)]
    setTimeout @start_kyoku, TIMEOUT.preStart
    return true

  # game

  start_kyoku: ~>
    @kyokuStr = "#{'ESWN'[@bakaze]}#{@chancha + 1}.#{@honba} [#{@points}]"
    @debug "start_kyoku: #{@kyokuStr}"

    @kyoku = with new Kyoku @, rule
      ..on \turn, (player) ~>
        @debug "#{player}P\#TURN"
        @seq++
        S.publish @prefix, [\turn, player, @seq], {}, ACK
          .then ~>
            @turnTimeout = setTimeout (~> @autoplay player), TIMEOUT.turn

      ..on \query, (player, lastAction) ~>
        @debug "#{player}P?QUERY"
        @seq++
        @answered = 0
        S.publish @prefix, [\query, player, @seq, lastAction], {}, ACK
          .then ~>
            @queryTime = moment! # TODO: for random delay
            @queryTimeout = setTimeout @_resolve, TIMEOUT.queryMax

      ..on \declare, (player, type) ~>
        @debug "#{player}P!#type"
        S.publish @prefix, [\declare, player, type]

      ..on \end, @end_kyoku
    S.publish @prefix, [\kyoku], @{bakaze, chancha, honba, points}
    @kyoku.advance!

  end_kyoku: (result) !~>
    @debug "end_kyoku: #{@kyokuStr}"
    @kyoku = null
    # tidy up result a litte bit
    @kyokuResult = with result
      delete ..details.rulevar
    # apply delta
    for i til 4 => @points[i] += result.delta[i]
    # strictly negative points => end
    if @points.some (< 0) then return @end @points
    if result.renchan
      @honba++
      # all-last oya top => end
      if @chancha == 3 and @bakaze == 1
      and util.max(@points) == @points[3]
        return @end @points
    else
      if result.type == \RYOUKYOKU then @honba++
      if ++@chancha == 4
        @chancha = 0
        @bakaze++
    # handle sudden death (overtime)
    switch @bakaze
    | 0, 1 => void
    | 2, 3 =>
      if @points.some (> 30000)
        return @end @points
    | 4 => return @end @points
    # continue
    S.publish @prefix, [\result], {points: @points, result}, ACK
      .then ~> setTimeout @start_kyoku, TIMEOUT.preStart

  get_state: ([token, type]) ~>
    if not @kyoku
      @_error 'get_state', "kyoku not started"
    if not (p = @playerMap[token])
      @_error 'get_state', "bad player token #token"
    p .= seat
    @debug "get_state: [#p] #type"
    switch type
    | \playerPublic => return @kyoku.playerPublic
    | \playerHidden => return @kyoku.playerHidden[p]
    | \globalPublic => return @kyoku.globalPublic
    | \all => return {
      seq: @seq # FIXME: should have better place for this
      playerPublic: @kyoku.playerPublic
      playerHidden: @kyoku.playerHidden[p]
      globalPublic: @kyoku.globalPublic
    }
    | _ => @_error 'get_state', "bad request #type"

  # call kyoku method:
  #   success => callback (synchronous)
  #   error => convert error
  _exec: (method, args, cb) ~>
    if method
      try
        ret = @kyoku[method](...args)
      catch e
        @_error 'kyoku', e.message
    if cb? then cb!
    ret

  _resolve: ~>
    @debug "resolve"
    @kyoku.resolveQuery!

  can_act: ([token, seq, action, ...args]) ~>
    if not @kyoku
      @_error 'can_act', "kyoku not started"
    if not (p = @playerMap[token])
      @_error 'can_act', "bad player token: #token"
    p .= seat
    if seq != @seq
      @_error 'can_act', "bad sequence number: #seq"
    @debug "can_act: [#p]{#seq} can-#action(#args)"
    if not (method = KYOKU_TURN[action])
      @_error 'can_act', "unrecognized action: #action"
    args.unshift p
    @_exec method, args

  act: ([token, seq, action, ...args]) ~>
    if not @kyoku
      @_error 'act', "kyoku not started"
    if not (p = @playerMap[token])
      @_error 'act', "bad player token: #token"
    p .= seat
    if seq != @seq
      @_error 'act', "bad sequence number: #seq"
    @debug "act: [#p]{#seq} #action(#args)"
    if action not of KYOKU_TURN
      @_error 'act', "unrecognized action: #action"
    args.unshift p
    @_exec action, args, ~>
      clearTimeout @turnTimeout

  autoplay: (player) ~>
    @debug "autoplay for #{player}P"
    # FIXME: nop for now

  can_declare: ([token, seq, decl, ...args]) ~>
    if not @kyoku
      @_error 'can_declare', "kyoku not started"
    if not (p = @playerMap[token])
      @_error 'can_declare', "bad player token: #token"
    p .= seat
    if seq != @seq
      @_error 'can_declare', "bad sequence number: #seq"
    @debug "can_declare: [#p]{#seq} can-#decl(#args)"
    # no double declare during one query
    if @answered.&.(1.<<.p)
      @_error 'can_declare', "duplicate response"
    # always okay to "pass" with explicit null
    if decl == null then return valid: true
    if not (method = KYOKU_QUERY[decl])
      @_error 'can_declare', "unrecognized declaration: #decl"
    args.unshift p
    @_exec method, args

  declare: ([token, seq, decl, ...args]) ~>
    if not @kyoku
      @_error 'declare', "kyoku not started"
    if not (p = @playerMap[token])
      @_error 'declare', "bad player token: #token"
    p .= seat
    if seq != @seq
      @_error 'declare', "bad sequence number: #seq"
    @debug "can_declare: [#p]{#seq} #decl(#args)"
    # no double declare during one query
    if @answered.&.(1.<<.p)
      @_error 'declare', "duplicate response"
    # always okay to "pass" with explicit null
    if decl != null and decl not of KYOKU_QUERY
      @_error 'declare', "unrecognized declaration: #decl"
    args.unshift p
    @_exec decl, args, ~>
      if (@answered.|.= (1.<<.p)) == 2~1111
        # everyone has answered
        clearTimeout @queryTimeout
        now = moment!diff @queryTime, 'ms'
        @debug "declare: received all answers at #now ms"
        # random lower bound of resolve delay
        expected = util.randomRange(TIMEOUT.queryMin, TIMEOUT.queryRand)
        if (dt = expected - now) > 5
          @debug "declare: random delay #dt ms"
          setTimeout @_resolve, dt
        else
          process.nextTick @_resolve!
