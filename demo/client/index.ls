# create and join game

require! {
  './util': {utf8_to_b64, escapeHTML}
  './conf': {SERVER, PREFIX}
}

qS = -> document.querySelector it
qSA = -> document.querySelectorAll it

inputGameId = qS \#inputGameId
btnNew = qS \#btnNew
inputName = qS \#inputName
btnJoin = qS \#btnJoin
btnLeave = qS \#btnLeave
con = qS \#con

debugStr = con.innerHTML
debug = !-> 
  con.innerHTML = debugStr += escapeHTML(it) + '\n' # NOTE: inside <pre>


####################################

joined = false
updateJoined = ->
  joined := it
  btnJoin.disabled = joined
  btnLeave.disabled = not joined

gameId = null
G = null # root URI of game

playerName = null
playerToken = null
playerSeat = null

playerNames = null # of everyone (ordered by seat wind)


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
function onClose(reason, details)
  debug "lost connection. reason: #reason"
  console.error details
  S := null
  updateJoined false

btnNew.addEventListener 'click', ->
  if not S?.isOpen then return debug "error: not connected yet"
  debug "try create new game..."
  S.call "#PREFIX.game.new"
    .then (gameId) ->
      debug "  new game #gameId created"
      inputGameId.value = gameId
    .catch (err) ->
      debug "  error: #err"
      console.error err

btnJoin.addEventListener 'click', ->
  if not S?.isOpen then return debug "error: not connected yet"
  if joined then return debug "error: already joined"
  if (gameId := inputGameId.value.trim!).length == 0
    return debug "empty game id"
  playerName := inputName.value.trim!
  G := "#PREFIX.game.#gameId"

  subscribe!
    .then ->
      debug "joining..."
      S.call "#G.join", [playerName]
    .then (token) ->
      debug "  joined. player token: #token"
      playerToken := token
      updateJoined true
    .catch (err) ->
      debug "  error: #err"
      console.error err
      unSubscribe!

btnLeave.addEventListener 'click', ->
  if not S?.isOpen then return debug "error: not connected yet"
  if not joined then return debug "error: not joined"

  debug "leaving..."
  S.call "#G.leave", [playerToken]
    .then ->
      debug "  leaved."
      playerToken := null
      updateJoined false
      unSubscribe!
    .catch (err) ->
      debug "  error: #err"
      console.error err

subscription = null
function subscribe
  S.subscribe G, handler
    .then -> subscription := it
function unSubscribe
  if S and subscription then S.unsubscribe subscription

function handler([type, details]:args)
  switch type
  | \join =>
    debug "player #details has joined"
  | \leave =>
    debug "player #details has leaved"
  | \start =>
    playerNames := details
    playerSeat := playerNames.indexOf playerName
    if playerSeat == -1
      debug "game started without you (WTF?)"
      conn.close!
    else
      startGame!

function startGame
  conn.close!
  args = {gameId, playerNames, playerSeat, playerToken}
  s = encodeURIComponent JSON.stringify args
  window.location = 'game.html#' + s
