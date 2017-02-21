'use strict'
require! {
  '../pai': Pai
}

!function precond(kyoku)
  unless kyoku.phase == \postDahai
    throw Error "wrong phase #{kyoku.phase} (should be 'postDahai')"

# dir: Number
#   < 0 : e.g. 34m chi 5m
#   = 0 : e.g. 46m chi 5m
#   > 0 : e.g. 67m chi 5m
# preferAkahai: Boolean
#   when you can use either akahai or normal 5 to chi:
#     true : use akahai
#     false: use normal 5
function infer(kyoku, dir, preferAkahai)
  with kyoku.currPai # sutehai
    n = ..equivNumber
    P = Pai[..S]
  switch
  | dir <  0
    if n in [1 2] then throw Error "wrong input"
    a = P[n - 2] ; b = P[n - 1]

  | dir == 0
    if n in [1 9] then throw Error "wrong input"
    a = P[n - 1] ; b = P[n + 1]

  | dir >  0
    if n in [8 9] then throw Error "wrong input"
    a = P[n + 1] ; b = P[n + 2]

  | _ => throw Error "wrong input"
  ownPai = [a, b]

  PH = kyoku.playerHidden[player]
  unless PH.countEquiv(a) and PH.countEquiv(b)
    throw Error "you must have [#a#b] in juntehai"

  # check whether we replace one of ownPai with corresponding akahai
  if a.number == 5 then i = 0 ; p5 = a
  if b.number == 5 then i = 1 ; p5 = b
  if p5?
    p0 = p5.akahai
    p5n = PH.count1(p5)
    p0n = PH.count1(p0)
    # truth table: (prefer akahai), (have normal, have akahai) -> use akahai
    # |   || 00 | 01 | 11 | 10 |
    # |===||====|====|====|====|
    # | 0 || X  | 1  | 0  | 0  |
    # | 1 || X  | 1  | 1  | 0  |
    if p5n == 0 or (p0n > 0 and preferAkahai) then ownPai[i] = p0

  return ownPai

function createFuuro(kyoku, ownPai)
  # hand sort ownPai ++ currPai
  [a, b] = ownPai
  c = kyoku.currPai
  if a.N > b.N then [a, b] = ownPai = [b, a]
  if c.N < a.N
    p = c ; q = a ; r = b
  else if c.N < b.N
    p = a ; q = c ; r = b
  else
    p = a ; q = b ; r = c
  unless p.suite == q.suite == r.suite and
      p.succ == q.equivPai and
      q.succ == r.equivPai
    throw Error "[#p#q#r] is not valid shuntsu"

  # verify juntehai has ownPai
  player = (kyoku.currPlayer + 1)%4
  PH = kyoku.playerHidden[player]
  if not PH.isMock
    unless PH.countEquiv(a) > 0 and PH.countEquiv(b) > 0
      throw Error "you must have [#a#b] in juntehai"

  return {
    type: \minjun
    anchor: p
    ownPai
    otherPai: c
    fromPlayer: kyoku.currPlayer
    kakanPai: null
  }

#   player: `(currPlayer + 1)%4` -- implicit
#   <canonical>
#     ownPai: [2]Pai -- should satisfy the following:
#       both must exist in juntehai
#       ownPai.0.equivNumber < ownPai.1.equivNumber
#       `ownPai ++ kyoku.currPai` should form a shuntsu
export function create(kyoku, {
  ownPai, dir, preferAkahai = true
})
  precond kyoku
  player = (kyoku.currPlayer + 1)%4
  if kyoku.isClient and kyoku.me != player
    throw Error "not your turn"
  seq = kyoku.seq - kyoku.currDecl.count

  if ownPai?
    ownPai = Pai.arrayN(ownPai, 2)
  else
    ownPai = infer kyoku, dir, preferAkahai
  {ownPai} = createFuuro kyoku, player, ownPai
  return {type: \chi, seq, ownPai}

# NOTE: only called through `declare.fromClient`
export function fromClient(kyoku, {
  type, seq
  ownPai
})
  precond kyoku
  if kyoku.isClient
    throw Error "must be called on server side"
  unless type == \chi
    throw Error "wrong type #type (should be 'chi')"
  # seq already validated in `declare.fromClient`

  ownPai = Pai.arrayN(ownPai, 2)
  fuuro = createFuuro kyoku, ownPai

  return chi-server with {kyoku, seq, fuuro}

export function fromServer(kyoku, {
  type, seq
  ownPai
})
  precond kyoku
  unless kyoku.isClient
    throw Error "must be called on client side"
  unless type == \chi
    throw Error "wrong type #type (should be 'chi')"
  unless kyoku.seq == seq
    throw Error "seq mismatch: kyoku at #{kyoku.seq}, event at #seq"

  ownPai = Pai.arrayN(ownPai, 2)
  fuuro = createFuuro kyoku, ownPai

  return chi-client with {kyoku, seq, fuuro}

chi-server =
  toLog: -> {type: \chi, @seq, @ownPai}

  toClients: ->
    x = {type: \chi, @seq, @ownPai}
    [x, x, x, x]

  apply: !->
    {kyoku, seq, {ownPai: [a, b]}:fuuro} = @
    seqBeforeDecl = kyoku.seq - kyoku.currDecl.count
    unless seq == seqBeforeDecl
      throw Error "seq mismatch: kyoku at #seqBeforeDecl, event at #seq"
    @seq = kyoku.seq
    player = (kyoku.currPlayer + 1)%4

    kyoku._didNotHoujuu \chi
    kyoku.playerHidden[player].remove2 a, b
    kyoku.playerPublic[player]
      ..fuuro.push fuuro
      ..menzen = false
    kyoku.playerPublic[kyoku.currPlayer].lastSutehai.fuuroPlayer = player

    kyoku.currDecl.clear!
    kyoku.currPlayer = player
    kyoku.phase = \postChiPon

chi-client =
  apply: !->
    {kyoku, seq, {ownPai: [a, b]}:fuuro} = @
    unless kyoku.seq == seq
      throw Error "seq mismatch: kyoku at #{kyoku.seq}, event at #seq"
    player = (kyoku.currPlayer + 1)%4

    kyoku._didNotHoujuu \chi
    kyoku.playerHidden[player].remove2 a, b
    kyoku.playerPublic[player]
      ..fuuro.push fuuro
      ..menzen = false
    kyoku.playerPublic[kyoku.currPlayer].lastSutehai.fuuroPlayer = player

    kyoku.currDecl.clear!
    kyoku.currPlayer = player
    kyoku.phase = \postChiPon
