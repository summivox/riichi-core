module.exports =
  SERVER:
    url: 'ws://localhost:8000/ws'
    realm: 'riichi'
    #use_es6_promises: yes
  PREFIX: 'io.github.summivox.riichi'
  TIME:
    # lobby:
    idle: 180e3_ms        # kick after inaction
    poll: 0.5e3_ms

    # game:
    gameStart: 10e3_ms    # extra pause before 1st kyoku
    kyokuStart: 5e3_ms    # pause before every kyoku
    turn: 15e3_ms         # timeout for player's turn
    # query resolution:
    queryMax: 10e3_ms     # timeout for forced resolution
    queryRand: 3e3_ms     # upper bound of random delay
    queryMin: 0.5e3_ms    # lower bound of random delay
