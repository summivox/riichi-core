# agari : everything[1] you wish to know about a winning hand

require! {
  './pai': Pai
  './decomp': {tenpaiDecomp, decompAgariFromTenpai}
  './util': {OTHER_PLAYERS, ceilTo, sum, count}
  './yaku': {YAKU_LIST, YAKUMAN_LIST}:Yaku
}

# properties: almost all flattened as a dictionary
#
# NOTE: objects originally passed as input are NOT modified; copies are made
# before any modification
#
# INPUT:
#   `rulevar`
#
#   ===== hand =====
#   `agariPai`
#   `juntehai`
#   `tenpaiDecomp`: corresponds to `juntehai`
#   `fuuro`
#   `menzen`
#   `riichi`: {accepted, double, ippatsu}
#
#   ===== players =====
#   `chancha`
#   `agariPlayer`
#   `houjuuPlayer`: null => tsumo
#
#   ===== kyoku =====
#   `honba`
#   `bakaze`
#   `jikaze`
#   `doraHyouji`
#   `uraDoraHyouji`
#   `nKan`
#
#   ===== conditions =====
#   `rinshan`
#   `chankan`
#   `isHaitei`: for haiteiraoyue and houteiraoyui
#   `virgin`: for tenhou and chiihou
#
# OUTPUT:
#   `isAgari`: true/false
#   `delta`: score gains for each agariPlayer
#   `dora`: number of {dora, uraDora, akaDora}
#   `doraTotal`: sum of `dora`
#   highest-points interpretation:
#     `basicPoints`: "net worth" of the hand
#     `yakuman`: array of {name, times}
#     `yakumanTotal`: sum of yakuman.times (capped by rule)
#     `yaku`: array of {name, han}
#     `yakuTotal`: sum of yaku.han
#     `han`: `yakuTotal + doraTotal` if not yakuman
#     `fu`

module.exports = class Agari
  (input) ->
    import all input

    # tenpai and agari decompsition
    if @tenpaiDecomp.length == 0 then return @isAgari = false
    @agariDecomp = decompAgariFromTenpai @tenpaiDecomp, @agariPai
    if @agariDecomp.length == 0 then return @isAgari = false

    # copy and augment fuuro
    @fuuro = Pai.cloneFix @fuuro
    @fuuroFu = augmentFuuro @

    # juntehai: now also includes agariPai
    # tehai: juntehai + fuuro
    # NOTE: tehai.length not always 14 (due to kan)
    @juntehai = with @juntehai.slice!
      ..push @agariPai
      ..sort Pai.compare
    @tehai = with @juntehai.slice!
      for f in @fuuro => [].push.apply .., f.allPai
      ..sort Pai.compare
    # bins: correspond to full tehai
    @bins = Pai.binsFromArray @tehai
    @binsSum = @bins.map sum

    # dora
    @dora = getDora @
    @doraTotal = @dora.dora + @dora.uraDora + @dora.akaDora

    @isRon = @houjuuPlayer?
    @isTsumo = not @isRon

    # maximize basic points over all decompositions
    maxBasicPoints = 0
    maxDecompResult = null
    for {wait}:decomp in @agariDecomp
      # kokushi: exclusive override
      if wait in <[kokushi kokushi13]>
        times = (@rulevar.yakuman[wait] ? 1) <? @rulevar.yakuman.max
        maxBasicPoints = getBasicPointsYakuman times
        maxDecompResult = {
          yakuman: {name: wait, times}
          yakumanTotal: times
          basicPoints: maxBasicPoints
        }
        break # <-- cannot be any other form at the same time
      # yakuman
      {basicPoints}:yakumanResult = getYakumanResult decomp, @
      if basicPoints > maxBasicPoints
        maxBasicPoints = basicPoints
        maxDecompResult = yakumanResult
        continue # <-- all other yaku overridden
      # yaku-han-fu
      {basicPoints}:yakuResult = getYakuResult decomp, @
      if basicPoints > maxBasicPoints
        maxBasicPoints = basicPoints
        maxDecompResult = yakuResult

    if maxBasicPoints == 0 then return @isAgari = false
    import all maxDecompResult
    @delta = getDelta @

  import all {
    augmentFuuro
    getDora
    getBasicPoints, getBasicPointsYakuman
    getDelta
    getYakuResult, getYakumanResult
  }

# add fields for each fuuro object:
#   allPai: sorted Pai array
#   fu: mentsu fu value (see also `getYakuResult`)
# convert enums of fuuro type to lower-case strings
#
# return: sum of all fuuro.fu
function augmentFuuro({fuuro})
  fuuroFu = 0
  for f in fuuro
    f.allPai = with f.ownPai.slice!
      if f.otherPai => ..push f.otherPai
      if f.kakanPai => ..push f.kakanPai
      ..sort Pai.compare
    switch f.type
    | \minjun             => fu = 0
    | \minko              => fu = 2
    | \daiminkan, \kakan  => fu = 8
    | \ankan              => fu = 16
    | _ => throw Error "unknown type"
    if f.anchor.isYaochuupai then fu *= 2
    f.fu = fu
    fuuroFu += fu
  return fuuroFu

# count all 3 kinds of dora: {dora, uraDora, akaDora}
# rule variations:
#   `.dora`
function getDora({
  rulevar: {dora: {ura, kan, kanUra}}
  tehai, fuuro, riichi
  doraHyouji, uraDoraHyouji, nKan
})
  n = if kan then nKan + 1 else 1
  m = if kanUra then n else 1
  dora = doraHyouji[0 til n].map (.succDora)
  if ura and riichi.accepted
    uraDora = uraDoraHyouji[0 til m].map (.succDora)
  else
    uraDora = []

  ret = dora: 0, uraDora: 0, akaDora: 0
  for p in tehai
    if p.isAkahai then ret.akaDora++
    p .= equivPai
    ret.dora += count dora, p
    ret.uraDora += count uraDora, p
  ret

function getBasicPoints({han, fu})
  switch han
  | 0 => 0
  | 1, 2, 3, 4, 5 => (fu*(1.<<.(2+han)) <? 2000)
  | 6, 7      => 3000
  | 8, 9, 10  => 4000
  | 11, 12    => 6000
  | _         => 8000
function getBasicPointsYakuman(yakumanTotal) => 8000 * yakumanTotal

function getDelta({
  rulevar: {points: {honba: HONBA_UNIT}}
  basicPoints, chancha, agariPlayer, houjuuPlayer, isRon, honba
})
  # distribution {fudangaku} calculation
  # [0] tsumo : ko  <- each ko
  # [1] tsumo : oya <- each ko
  #             ko  <- oya
  # [2] ron   : ko  <- houjuuPlayer
  # [3] ron   : oya <- houjuuPlayer
  [tsumoKoKo, tsumoOyaKo, ronKo, ronOya] = [1 2 4 6].map ->
    basicPoints*it |> ceilTo _, 100

  tsumoKoKo += HONBA_UNIT * honba
  tsumoOyaKo += HONBA_UNIT * honba
  ronKo += HONBA_UNIT * 3 * honba
  ronOya += HONBA_UNIT * 3 * honba

  delta = [0 0 0 0]
  if isRon
    if agariPlayer == chancha
      delta[chancha] = +(ronOya)
      delta[houjuuPlayer] = -(ronOya)
    else # ko
      delta[agariPlayer] = +(ronKo)
      delta[houjuuPlayer] = -(ronKo)
  else # tsumo
    if agariPlayer == chancha
      delta[chancha] = +(3*tsumoOyaKo)
      for p in OTHER_PLAYERS[chancha]
        delta[p] = -(tsumoOyaKo)
    else # ko
      delta[agariPlayer] = +(2*tsumoKoKo + tsumoOyaKo)
      for p in OTHER_PLAYERS[agariPlayer]
        if p == chancha
          delta[p] = -(tsumoOyaKo)
        else # ko
          delta[p] = -(tsumoKoKo)
  return delta

function getYakuResult(decomp, {
  bakaze, jikaze, fuuroFu, isTsumo, menzen, doraTotal
}:agariObj)

  # yaku
  yaku = []
  yakuTotal = 0
  blacklist = {}
  for {name, conflict, menzenHan, kuiHan} in YAKU_LIST
    # check if overridden by higher priority yaku
    if name of blacklist then continue
    # check if yaku is menzen-only
    if not menzen and kuiHan == 0 then continue
    if Yaku[name](decomp, agariObj)
      han = if menzen then menzenHan else kuiHan
      yaku.push {name, han}
      yakuTotal += han
      if conflict? then for c in conflict => blacklist[c] = true
  # NOTE: pinfu not considered yet

  # fu
  {wait, mentsu, jantou} = decomp
  if wait == \chiitoi
    fu = 25
  else
    # NOTE: This is perhaps the most convoluted rule in the whole game mostly
    # owing to historical reasons. The following implementation agrees with
    # this entry on Japanese Wikipedia: <http://bit.ly/1KYQCV4>
    #
    # The reason why Pinfu (the yaku) is not considered together with other
    # yaku is by its very original definition: "the yaku of no fu", and other
    # (modern) special rules effectively coupling pinfu and fu together.
    #
    # see also `augmentFuuro` for minko/minkan/ankan parts

    # calculate 3 main parts: mentsu, jantou, machi/wait
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
    switch wait
    | \ryanmen, \shanpon => waitFu = 0
    | _ => waitFu = 2

    # 2*2*2 decision tree (pinfu-form * menzen * tsumo/ron)
    x = mentsuFu + jantouFu + waitFu
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
  han = yakuTotal + doraTotal
  basicPoints = getBasicPoints {han, fu}
  return {basicPoints, yaku, yakuTotal, han, fu}

# mostly parallel to getYakuResult (the yaku part)
function getYakumanResult(decomp, {rulevar}:agariObj)
  yakuman = []
  yakumanTotal = 0
  blacklist = {}
  for {name, conflict} in YAKUMAN_LIST
    if name of blacklist then continue
    if Yaku[name](decomp, agariObj)
      times = rulevar.yakuman[name] ? 1 # <-- different from yaku-han-fu
      yakuman.push {name, times}
      yakumanTotal += times
      if conflict? then for c in conflict => blacklist[c] = true
  yakumanTotal <?= rulevar.yakuman.max
  if yakumanTotal == 0 then return {basicPoints: 0}
  basicPoints = getBasicPointsYakuman yakumanTotal
  return {basicPoints, yakuman, yakumanTotal}

# [1]: your mileage may vary
