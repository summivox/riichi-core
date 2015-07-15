module.exports =
  SERVER:
    url: 'ws://localhost:8000/ws'
    realm: 'riichi'
  PREFIX: 'io.github.summivox.riichi'
  TIMEOUT:
    join: 50e3_ms
    idle: 100e3_ms
    preStart: 10e3_ms
    turn: 15e3_ms
    queryMax: 10e3_ms
    queryRand: 3e3_ms
    queryMin: 0.5e3_ms
