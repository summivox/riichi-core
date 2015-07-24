# server entry point

global.AUTOBAHN_DEBUG = true
require! {
  './conf': {SERVER}:CONF

  autobahn

  debug

  './lobby-random': RandomLobby
}

debugIndex = debug 'index'

# initialize game engine
process.nextTick -> require 'riichi-core' .init!

# start the only connection for demo
conn = with new autobahn.Connection SERVER
  ..onopen = onOpen
  ..onclose = onClose
  ..open!

function onOpen(session)
  debugIndex 'open'
  new RandomLobby session, 'demo_lobby'

# die fast on disconnect
function onClose(reason, details)
  debugIndex "close: #reason"
  console.dir details
  debugIndex "will die"
  process.exit 1
