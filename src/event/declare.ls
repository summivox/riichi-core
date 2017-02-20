'use strict'

CPKR =
  chi: require './chi'
  pon: require './pon'
  daiminkan: require './daiminkan'
  ron: require './ron'

# `what` => "what did this player declare"

export function fromClient(kyoku, {type, seq, player}:what)
  if kyoku.isClient
    throw Error "must be called on server side"

  cpkr = CPKR[type]
  unless cpkr? => throw Error "wrong type #type"

  seqBeforeDecl = kyoku.seq - kyoku.currDecl.count
  unless seq == seqBeforeDecl
    throw Error "seq mismatch: kyoku at #seqBeforeDecl, event at #seq"

  return declare-server with {
    kyoku.seq, kyoku
    what: cpkr.fromClient kyoku, what
  }

export function fromServer(kyoku, {type, seq, what})
  unless kyoku.isClient
    throw Error "must be called on client side"
  unless type == \declare
    throw Error "wrong type #type (should be 'declare')"
  unless kyoku.seq == seq
    throw Error "seq mismatch: kyoku at #{kyoku.seq}, event at #seq"

  unless what.type in <[chi pon daiminkan ron]>
    throw Error "wrong type #{what.type}"

  return declare-client with {
    kyoku.seq, kyoku
    what
  }

declare-server =
  toLog: -> {type: \declare, @seq, @what.toLog!}

  toClients: ->
    x = {type: \declare, @seq, what: @what{type, player}}
    [x, x, x, x]

  apply: !-> @kyoku.currDecl.add @what

declare-client =
  apply: declare-server.apply




export class declare # {{{
  # SPECIAL: EVENT WRAPPER
  # minimal:
  #   what: chi/pon/daiminkan/ron
  #   args: (constructor args for constructing corresponding event)
  #     player: 0/1/2/3
  # partial:
  #   player: 0/1/2/3 -- `args.player`
  #   what
  # full:
  #   player
  #   what
  #   args

  (kyoku, {@what, @args}) -> with kyoku
    @type = \declare
    @seq = ..seq
    @init kyoku

  init: (kyoku) -> with @kyoku = kyoku
    assert.equal @type, \declare
    assert @what in <[chi pon daiminkan ron]>#
    if @args?
      @player ?= new exports[@what](kyoku, @args) .player
    assert.isNull ..currDecl[@player],
      "a player can only declare once during one turn"
    return this

  apply: !-> with kyoku = @kyoku
    ..currDecl.add @{what, player, args} # NOTE: `args` can be null

  toPartials: ->
    for p til 4
      # FIXME: just make it uniform?
      if p == @player
        @{type, seq, what, player, args}
      else
        @{type, seq, what, player}

  toMinimal: -> @{type, seq, what, args}
# }}}
