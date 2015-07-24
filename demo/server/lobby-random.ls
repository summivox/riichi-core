# simple random-assigning lobby for demo

require! {
  './conf': {PREFIX, TIME}:CONF

  autobahn

  'node-uuid': uuid
  debug
  moment
  'lodash.sample': sample

  './game': Game
  'riichi-core': {rule}
}

module.exports = class RandomLobby
  # 2-step construction
  (session, @name) ->
    @debug = debug "lobbies:#name"
    @$ = session
    @P = P = "#PREFIX.lobbies.#name"
    @hooks = []
    @playerByToken = {}
    @playerByHandle = {}
    @readyPlayers = {} # also with token as key
    @pollInterval = null # for new game
  init: ->
    methods = <[join ready unready]> #
    @debug 'initializing...'
    P = @P
    Promise.all methods.map ~>
      @$.register "#P.#it", @[it]
    .then (@hooks) ~>
      @pollInterval = setInterval @poll, TIME.poll
      @debug '  done'
    .catch (err) ~>
      @debug '  FAIL'
      console.error err
      process.exit 2
  end: ->
    @debug 'end: cleaning up...'
    clearInterval @pollInterval
    Promise.all @hooks.map ~> @$.unregister it
    .then ~>
      @debug '  done'
    .catch (err) ~>
      @debug '  FAIL'
      console.error err
      process.exit 2

  # throw user-facing error
  error: (type, ...reason) ~>
    throw new autobahn.Error "error.lobby.random.#type", reason

  # join/leave
  # - only need player handle for now
  # - token is randomly assigned
  # - kick player on timeout
  join: ([handle]) !~>
    if handle in playerByHandle
      @error 'join', "player handle already exists", handle
    token = uuid!
    player = {token, handle, idleTimeout: null, ready: false}
    @playerByToken[token] = player
    @playerByHandle[handle] = player
    @setIdleTimeout token
  leave: ([token]) !~>
    if !(player = playerByToken[token])?
      @error 'leave', "player with given token does not exist", token
    {handle} = player
    @clearIdleTimeout token
    delete @playerByToken[token]
    delete @playerByHandle[handle]
    delete @readyPlayers[token]
    @debug "player left: [#token] #handle"

  # timeout
  # TODO: document, and "not idle when playing a game"
  setIdleTimeout: (token) !->
    if !(player = playerByToken[token])? then return
    player.idleTimeout = setTimeout (~> @timeout token), TIME.idle
  clearIdleTimeout: (token) !->
    if !(player = playerByToken[token])? then return
    clearTimeout player.idleTimeout
    player.idleTimeout = null
  timeout: (token) !~>
    if !(player = playerByToken[token])? then return
    # TODO: notify player of timeout (really necessary?)
    @leave [token]

  # ready
  # - put player in ready list
  # - duplicate ready ignored
  ready: ([token]) !~>
    if !(player = playerByToken[token])?
      @error 'ready', "player with given token does not exist", token
    if player.ready then return
    player.ready = true
    readyPlayers[token] = player
  unready: ([token]) !~>
    if !(player = playerByToken[token])?
      @error 'ready', "player with given token does not exist", token
    player.ready = false
    delete readyPlayers[token]

  # poll
  # - try sample 4 from ready list and create game
  # - notify players and remove from ready list when game created
  poll: !~>
    p = sample @readyPlayers, 4 # NOTE: lodash.sample can handle dicts
    if p.length < 4 then return
    # TODO: new game might be async, on another node, or using new conn
    gameId = uuid!
    game = new Game session, gameId, rule, p.map -> it{token, handle}
    game.init!
    .then ~>
      @debug "game created: #gameId"
      @debug "notifying players..."
      Promise.all p.map ({token}:player, seat) ~>
        @$.call "#{@P}.players.#token.game", [gameId, seat]
    .catch (err) ~>
      @debug "  FAIL: not all players notified"
      process.exit 2
    .then ~>
      @debug "  done"
      game.start!
