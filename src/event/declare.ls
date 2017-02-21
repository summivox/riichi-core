'use strict'

CPKR =
  chi: require './chi'
  pon: require './pon'
  daiminkan: require './daiminkan'
  ron: require './ron'

export function fromClient(kyoku, {type, seq}:decl)
  if kyoku.isClient
    throw Error "must be called on server side"

  cpkr = CPKR[type]
  unless cpkr? => throw Error "wrong type #type"

  seqBeforeDecl = kyoku.seq - kyoku.currDecl.count
  unless seq == seqBeforeDecl
    throw Error "seq mismatch: kyoku at #seqBeforeDecl, event at #seq"

  kyoku.currDecl.validate decl

  return declare-server with {
    kyoku.seq, kyoku
    decl: cpkr.fromClient kyoku, decl
  }

export function fromServer(kyoku, {type, seq, decl})
  unless kyoku.isClient
    throw Error "must be called on client side"
  unless type == \declare
    throw Error "wrong type #type (should be 'declare')"
  unless kyoku.seq == seq
    throw Error "seq mismatch: kyoku at #{kyoku.seq}, event at #seq"

  unless decl.type in <[chi pon daiminkan ron]>
    throw Error "wrong type #{decl.type}"

  kyoku.currDecl.validate decl

  return declare-client with {
    kyoku.seq, kyoku
    decl
  }

declare-server =
  toLog: -> {type: \declare, @seq, @decl.toLog!}

  toClients: ->
    x = {type: \declare, @seq, decl: @decl{type, player}}
    [x, x, x, x]

  apply: !->
    {kyoku, seq, decl} = @
    unless kyoku.seq == seq
      throw Error "seq mismatch: kyoku at #{kyoku.seq}, event at #seq"

    kyoku.currDecl.add decl

declare-client =
  apply: declare-server.apply
