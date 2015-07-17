# game

require! {
  './util': {escapeHTML}
  './conf': {SERVER, PREFIX}
  './ui': ui
}

qS = -> document.querySelector it
qSA = -> document.querySelectorAll it

svg = qS \#main
con = qS \#con

debugStr = con.innerHTML
debug = !-> 
  con.innerHTML = debugStr += escapeHTML(it) + '\n' # NOTE: inside <pre>


###########################################################


# hashtag unpacking
gameId = null
G = null # root URI of game
playerName = null
playerToken = null
playerSeat = null
playerNames = null
do !->
  try
    s = document.location.hash.substr 1
    j = JSON.parse decodeURIComponent s
    {gameId, playerNames, playerSeat, playerToken} := j
    playerName := playerNames[playerSeat]
    G = "#PREFIX.game.#gameId"
  catch e
    debug "*** invalid game URL ***"
    throw e

# setup connection
conn = new autobahn.Connection SERVER
S = null # session
conn.onopen = onOpen
conn.onclose = onClose
process.nextTick ->
  debug "connecting to #{SERVER.url} ..."
  conn.open!

function onOpen
  debug "connected"
  S := conn.session
  subscribe!
    .catch (err) ->
      debug "error: #err"
      console.error err
      conn.close!
      setTimeout (-> conn.open!), 1500
    .then -> getState!
    .catch (err) -> void
    # NOTE: here getState could only fail because kyoku hasn't started,
    # in which case we can simply wait for \kyoku event
function onClose(reason, details)
  debug "lost connection. reason: #reason"
  console.error details
  S := null

subscription = null
function subscribe
  S.subscribe G, handler
    .then -> subscription := it
function unSubscribe
  if S and subscription then S.unsubscribe subscription


###########################################################


kyokuState = null

!function onGameEvent([type, ...details]:args, kwargs)
  switch type
  | \kyoku =>
    ... # TODO

function getState
  debug "updating state..."
  S.call "#G.get_state", [playerToken, \all]
    .then (state) ->
      debug "  updated"
      kyokuState := state
