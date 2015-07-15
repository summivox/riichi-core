global.AUTOBAHN_DEBUG = true
require! {
  # comm
  autobahn
  './conf': {SERVER, PREFIX, TIMEOUT}:CONF
}

conn = new autobahn.Connection SERVER
S = null
conn.onopen = main
conn.onclose = (reason, details) ->
  export S := null
conn.open!

function main
  console.log 'ready'
  export S := conn.session
  S.prefix "riichi", PREFIX

  P = ''
  export ids = []

  S.call "riichi:game.new"
    .then (gameId) ->
      export gameId
      export P := "riichi:game.#gameId"
      Promise.all [
        S.call "#P.join", ['A']
        S.call "#P.join", ['B']
        S.call "#P.join", ['C']
      ]
    .then (newIds) ->
      [].push.apply ids, newIds
      S.call "#P.leave", ['123']
    .catch (e) ->
      console.log "== error caught =="
      console.error e
      S.call "#P.leave", [ids[2]]
    .then ->
      ids.pop!
      S.subscribe P, handler
    .then ->
      Promise.all [
        S.call "#P.join", ['X']
        S.call "#P.join", ['Y']
      ]
    .then (newIds) ->
      [].push.apply ids, newIds
      S.call "#P.join", ['Z']
    .catch (e) ->
      console.log "== error caught =="
      console.log JSON.stringify(e)

function handler(args, kwargs)
  console.log "== EVENT =="
  console.dir args
  console.dir kwargs

export
  autobahn
  CONF
