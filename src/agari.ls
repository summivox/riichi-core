'use strict'
require! {
  './pai': Pai
  './decomp': {decompAgari}
  './util': {OTHER_PLAYERS, ceilTo, sum}
  './yaku': {YAKU_LIST, YAKUMAN_LIST}:Yaku
}

{slice, push} = []

# return:
#   if not agari: null
#   else:
#
#     agariPlayer, houjuuPlayer
#     isTsumo, isRon
#     riichi
#     tehai
#
#     basicPoints (not final --- see `score`)
#     if yaku:
#       yaku: [{name, han}]
#       yakuTotal: sum of yaku[i].han
#       fu
#     else (yakuman):
#       yakuman: [{name, times}]
#       yakumanTotal: sum of yakuman[i].times
export function create(kyoku, agariPlayer)
  isTsumo = (agariPlayer == kyoku.currPlayer)
  isRon = not isTsumo
  houjuuPlayer = if isTsumo then null else kyoku.currPlayer
  agariPai = kyoku.currPai
  return null if !agariPai?

  {chancha, honba, bakaze} = kyoku.startState
  {jikaze, fuuro, menzen, riichi} = kyoku.playerPublic[agariPlayer]
  {juntehai, tenpaiDecomp} = kyoku.playerHidden[agariPlayer]

  # decomp
  return null unless kyoku.isKeiten tenpaiDecomp
  agariDecomp = decompAgari tenpaiDecomp, agariPai, isRon
  return null if agariDecomp.length == 0

  # collect all tehai (juntehai + agariPai + fuuro)
  # also calculate fu from fuuro (since we go through all fuuro anyway)
  tehai = juntehai.slice!
  tehai.push agariPai
  fuuroFu = 0
  for f in fuuro
    push.apply tehai, f.ownPai
    if f.otherPai then tehai.push that
    if f.kakanPai then ret.push that
    switch f.type
    | \minjun             => ff = 0
    | \minko              => ff = 2
    | \daiminkan, \kakan  => ff = 8
    | \ankan              => ff = 16
    | _ => throw Error "unknown fuuro '#that'"
    if f.anchor.isYaochuupai then ff *= 2
    fuuroFu += ff
  tehai.sort Pai.compare

  # bins from tehai
  bins = Pai.binsFromArray tehai
  binsSum = bins.map sum

  # vars for yaku predicates
  context = {
    kyoku.rulevar

    # who won from whom
    agariPlayer, houjuuPlayer
    isTsumo, isRon

    # winner's hand
    agariPai, juntehai, tehai
    bins, binsSum
    fuuro
    menzen, riichi

    # environment
    chancha, honba, bakaze, jikaze
    kyoku.nKan

    # special conditions
    kyoku.virgin
    kyoku.rinshan
    isHaitei: kyoku.nTsumoLeft == 0
    chankan: kyoku.phase in <[postKakan postAnkan]>#
    # NOTE: kokushiAnkan handled in `Kyoku#isKeiten`
  }

  # choose the best decomp

  # placeholder for no solution
  bestResult = {
    basicPoints: 0
    yakuTotal: 0
    fu: 0
  }

  for {tenpaiType}:decomp in agariDecomp
    # kokushi: exclusive override
    if tenpaiType in <[kokushi kokushi13]>
      times = (@rulevar.yakuman[tenpaiType] ? 1) <? @rulevar.yakuman.max
      bestResult = {
        basicPoints: basicPointsYakuman times
        yakuman: [{name: tenpaiType, times}]
        yakumanTotal: times
        decomp
      }
      break # <-- cannot be any other form at the same time

    # yakuman
    yakumanResult = getYakumanResult decomp, context
    if compareResult(yakumanResult, bestResult) > 0
      bestResult = yakumanResult
      continue # <-- yakuman shadows all normal yaku

    # yaku-han-fu
    yakuResult = getYakuResult decomp, context
    if compareResult(yakuResult, bestResult) > 0
      bestResult = yakuResult

  return null if bestResult.basicPoints == 0

  return bestResult <<< {
    agariPlayer, houjuuPlayer
    isTsumo, isRon
    tehai
    riichi
  }

# add/modify the following to agariObj and return it:
#   if yaku:
#     nDora, nUraDora, nAkaDora
#     nDoraTotal = nDora + nUraDora + nAkaDora
#     han = yakuTotal + nDoraTotal
#     basicPoints: (final)
#
# NOTE: this can be called multiple times even on the same agariObj, e.g.
# once without uraDoraHyouji and once with.
export function score(kyoku, agariObj, noHonbaBonus)
  {
    rulevar:
      dora:
        ura: allowUra
        kanUra: allowKanUra
      points: honba: HONBA_UNIT
    startState: {chancha, honba}
    nKan
    doraHyouji, uraDoraHyouji
  } = kyoku
  {
    agariPlayer, houjuuPlayer
    tehai
    riichi
    yakuTotal
  } = agariObj
  if noHonbaBonus then honba = 0

  if yakuTotal
    # collect final list of dora(-hyouji)
    doraList = doraHyouji.map (.succDora)
    if allowUra and riichi.accepted
      n = if allowKanUra then doraHyouji.length else 1
      uraDoraList = uraDoraHyouji[til n].map (.succDora)
    else
      uraDoraList = []

    # count dora in tehai
    nDora = nUraDora = nAkaDora = 0
    for p in tehai
      if p.isAkahai then nAkaDora++
      p .= equivPai
      # NOTE: lists are usually short so this is okay
      for d in doraList => if d == p then nDora++
      for d in uraDoraList => if d == p then nUraDora++
    nDoraTotal = nDora + nUraDora + nAkaDora

    agariObj <<< {nDora, nUraDora, nAkaDora, nDoraTotal}
    agariObj.han = yakuTotal + nDoraTotal
    agariObj.basicPoints = basicPointsYaku agariObj.han, agariObj.fu

  # point distribution
  # tsumo : ko  <- each ko      (1x)
  # tsumo : oya <- each ko      (2x)
  #         ko  <- oya          (2x)
  # ron   : ko  <- houjuuPlayer (4x)
  # ron   : oya <- houjuuPlayer (6x)
  tsumoKoKo  = (basicPoints   |> ceilTo _, 100) + honba*HONBA_UNIT
  tsumoOyaKo = (basicPoints*2 |> ceilTo _, 100) + honba*HONBA_UNIT
  ronKo      = (basicPoints*4 |> ceilTo _, 100) + honba*HONBA_UNIT*3
  ronOya     = (basicPoints*6 |> ceilTo _, 100) + honba*HONBA_UNIT*3

  delta = [0 0 0 0]
  if isRon
    x = if agariPlayer == chancha then ronOya else ronKo
    delta[agariPlayer]  = +(x)
    delta[houjuuPlayer] = -(x)
  else # tsumo
    if agariPlayer == chancha
      delta[chancha] = +(3*tsumoOyaKo)
      for p in OTHER_PLAYERS[chancha]
        delta[p] = -(tsumoOyaKo)
    else # ko
      delta[agariPlayer] = +(2*tsumoKoKo + tsumoOyaKo)
      for p in OTHER_PLAYERS[agariPlayer]
        delta[p] = if p == chancha then -(tsumoOyaKo) else -(tsumoKoKo)
  agariObj <<< {delta}

  return agariObj

########################################

function basicPointsYaku(han, fu)
  switch han
  | 0 => 0
  | 1, 2, 3, 4, 5 => (fu*(1.<<.(2+han)) <? 2000)
  | 6, 7      => 3000
  | 8, 9, 10  => 4000
  | 11, 12    => 6000
  | _         => 8000
function basicPointsYakuman(yakumanTotal) => 8000 * yakumanTotal

function getYakuResult(decomp, {
  bakaze, jikaze, fuuroFu, isTsumo, menzen, doraTotal
}:context)

  # yaku
  yaku = []
  yakuTotal = 0
  shadowed = {}
  for {name, shadows, menzenHan, kuiHan} in YAKU_LIST
    # check if overridden by higher priority yaku
    if name of shadowed then continue
    # check if yaku is menzen-only
    if not menzen and kuiHan == 0 then continue
    if Yaku[name](decomp, context)
      han = if menzen then menzenHan else kuiHan
      yaku.push {name, han}
      yakuTotal += han
      if shadows? then for c in shadows => shadowed[c] = true
  # NOTE: pinfu not considered yet

  # fu
  {tenpaiType, mentsu, jantou} = decomp
  if tenpaiType == \chiitoi
    fu = 25
  else
    # NOTE: This is perhaps the most convoluted rule in the whole game mostly
    # owing to historical reasons. The following implementation agrees with
    # this entry on Japanese Wikipedia: <http://bit.ly/1KYQCV4>
    #
    # The reason why Pinfu (the yaku) is not considered together with other
    # yaku is by its very original definition: "the yaku of no fu", and other
    # (modern) special rules effectively coupling pinfu and fu together.

    # calculate 3 main parts: mentsu, jantou, machi
    mentsuFu = fuuroFu
    for m in mentsu
      switch m.type
      | \shuntsu => mf = 0
      | \minko => mf = 2
      | \anko => mf = 4
      if m.anchor.isYaochuupai then mf *= 2 # NOTE: shuntsu is still 0
      mentsuFu += mf
    switch jantou
    | Pai.FONPAI[bakaze, jikaze], Pai<[5z 6z 7z]> => jantouFu = 2
    | _ => jantouFu = 0
    switch tenpaiType
    | \ryanmen, \shanpon => machiFu = 0
    | _ => machiFu = 2

    # 2*2*2 decision tree (pinfu-form * menzen * tsumo/ron)
    x = mentsuFu + jantouFu + machiFu
    if x == 0
      if menzen
        # pinfu yaku (NOT listed in `./yaku`)
        yaku.push {name: \pinfu, han: 1}
        yakuTotal++
        if isTsumo then fu = 20 else fu = 30
      else
        # kui-pin
        fu = 30
    else
      if menzen
        if isTsumo then fu = 22+x else fu = 30+x
      else
        if isTsumo then fu = 22+x else fu = 20+x
    fu = ceilTo fu, 10

  if yakuTotal == 0 then return {basicPoints: 0}
  basicPoints = basicPointsYaku yakuTotal, fu # dora is counted later
  return {basicPoints, yaku, yakuTotal, fu, decomp}

# mostly parallel to getYakuResult (the yaku part)
function getYakumanResult(decomp, {rulevar}:context)
  yakuman = []
  yakumanTotal = 0
  shadowed = {}
  for {name, shadows} in YAKUMAN_LIST
    if name of shadowed then continue
    if Yaku[name](decomp, context)
      times = rulevar.yakuman[name] ? 1 # <-- different from yaku-han-fu
      yakuman.push {name, times}
      yakumanTotal += times
      if shadows? then for c in shadows => shadowed[c] = true
  yakumanTotal <?= rulevar.yakuman.max
  if yakumanTotal == 0 then return {basicPoints: 0}
  basicPoints = basicPointsYakuman yakumanTotal
  return {basicPoints, yakuman, yakumanTotal, decomp}

function compareYakuResult(l, r)
  if l.basicPoints - r.basicPoints then return that
  if l.yakuTotal - r.yakuTotal then return that
  return l.fu - r.fu

function compareYakumanResult(l, r)
  if l.basicPoints - r.basicPoints then return that
  return l.yakumanTotal - r.yakumanTotal

function compareResult(l, r)
  lm = l.yakuman?
  rm = r.yakuman?
  if lm != rm then return lm - rm
  if lm then compareYakumanResult(l, r) else compareYakuResult(l, r)
