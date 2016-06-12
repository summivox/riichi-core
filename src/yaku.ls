# Yaku list: high priority listed first (on top)
# - conflict(optional): if high priority yaku is valid, all listed lower
#   priority yaku will be skipped (for this particular decomposition)
# - kuiHan: (kui == not menzen, as in "kuitan")
#     0 => yaku not valid when not menzen
# - predicate functions are not embedded in the list for stylistic reasons
#
# NOTE:
# - \pinfu is NOT included (handled during fu calculation)
# - \chiitoitsu is included (other mentsu-agnostic yaku might still apply)
#   no need to list as conflict in mentsu-specific yaku
# - any yakuman overrides all normal yaku
# - some names contain extra 'n' -- this agrees with Japanese IME input rules
# - conflict list is incomplete (but this is okay)

require! {
  './pai': Pai
  './util': {sum, count}
}

export YAKU_LIST =
  # == 6 han ==
  * name: \chinniisou
    conflict: <[honniisou sanshokudoujun sanshokudoukou honchantaiyaochuu]> #
    menzenHan: 6, kuiHan: 5

  # == 3 han ==
  * name: \ryanpeikou
    conflict: <[iipeikou sanshokudoukou toitoihou]> #
    menzenHan: 3, kuiHan: 0

  * name: \junchantaiyaochuu
    conflict: <[honchantaiyaochuu ikkitsuukan tanyaochuu]> #
    menzenHan: 3, kuiHan: 2

  * name: \honniisou
    conflict: <[sanshokudoujun sanshokudoukou]> #
    menzenHan: 3, kuiHan: 2

  # == 2 han ==
  * name: \doubleRiichi
    conflict: <[riichi]> #
    menzenHan: 2, kuiHan: 0

  * name: \shousangen
    menzenHan: 2, kuiHan: 2

  * name: \sankantsu
    menzenHan: 2, kuiHan: 2

  * name: \sanshokudoukou
    conflict: <[sanshokudoujun ikkitsuukan]> #
    menzenHan: 2, kuiHan: 2

  * name: \honraotou # NOTE: agrees with `Pai::isRaotoupai`
    conflict: <[honchantaiyaochuu tanyaochuu]> #
    menzenHan: 2, kuiHan: 2

  * name: \sannankou
    conflict: <[sanshokudoujun ikkitsuukan]> #
    menzenHan: 2, kuiHan: 2 # NOTE: okay to chi (only once)

  * name: \toitoihou
    conflict: <[sanshokudoujun ikkitsuukan]> #
    menzenHan: 2, kuiHan: 2

  * name: \chiitoitsu
    menzenHan: 2, kuiHan: 0

  * name: \honchantaiyaochuu
    conflict: <[ikkitsuukan]> #
    menzenHan: 2, kuiHan: 1

  * name: \ikkitsuukan
    menzenHan: 2, kuiHan: 1

  * name: \sanshokudoujun
    menzenHan: 2, kuiHan: 1

  # == 1 han ==
  * name: \houteiraoyui
    menzenHan: 1, kuiHan: 1

  * name: \haiteiraoyue # also '~mouyue' (not used)
    conflict: <[chankan]> #
    menzenHan: 1, kuiHan: 1

  * name: \chankan
    menzenHan: 1, kuiHan: 1

  * name: \rinshankaihou
    menzenHan: 1, kuiHan: 1

  * name: \sangenpaiHaku # NOTE: separated so that yaku value stays fixed
    menzenHan: 1, kuiHan: 1

  * name: \sangenpaiHatsu
    menzenHan: 1, kuiHan: 1

  * name: \sangenpaiChun
    menzenHan: 1, kuiHan: 1

  * name: \bakazehai
    menzenHan: 1, kuiHan: 1

  * name: \jikazehai
    menzenHan: 1, kuiHan: 1

  * name: \iipeikou
    menzenHan: 1, kuiHan: 0

  * name: \tanyaochuu
    menzenHan: 1, kuiHan: 1 # NOTE: kuitan rule handled by predicate

  * name: \menzenchintsumohou
    menzenHan: 1, kuiHan: 0

  * name: \ippatsu
    menzenHan: 1, kuiHan: 0

  * name: \riichi
    menzenHan: 1, kuiHan: 0


# yakuman
# - \kokushi and \kokushi13 are NOT included (exclusive override)
# - "times yakuman" is specified in rule variations instead
export YAKUMAN_LIST =
  * name: \tenhou
  * name: \chiihou
  * name: \junseichuurenpoutou
    conflict: <[chuurenpoutou]>
  * name: \chuurenpoutou
  * name: \suukantsu
  * name: \chinraotou
  * name: \ryuuiisou
  * name: \daisuushi
    conflict: <[shousuushi]>
  * name: \shousuushi
  * name: \tsuuiisou
  * name: \daisangen
  * name: \suuankouTanki
    conflict: <[suuankou]>
  * name: \suuankou


########################################


# yaku predicate functions: (decomp, agariObj) -> true/false
#
# NOTE: for "strong-weak" pairs: since the "strong" yaku has higher priority,
# common results can be cached in decomp to be used by the "weak"

export


  # flag-only
  riichi: (decomp, {riichi}) ->
    riichi.accepted
  doubleRiichi: (decomp, {riichi}) ->
    riichi.accepted and riichi.double
  ippatsu: (decomp, {riichi}) ->
    riichi.accepted and riichi.ippatsu
  menzenchintsumohou: (decomp, {menzen, isTsumo}) ->
    menzen and isTsumo
  rinshankaihou: (decomp, {rinshan, isTsumo}) ->
    rinshan and isTsumo
  chankan: (decomp, {chankan, isRon}) ->
    chankan and isRon
  haiteiraoyue: (decomp, {isHaitei, isTsumo}) ->
    isHaitei and isTsumo
  houteiraoyui: (decomp, {isHaitei, isRon}) ->
    isHaitei and isRon
  chiitoitsu: (decomp) ->
    decomp.k7 == \chiitoi
  tenhou: (decomp, {isTsumo, virgin, agariPlayer, chancha}) ->
    isTsumo and virgin and agariPlayer == chancha
  chiihou: (decomp, {isTsumo, virgin, agariPlayer, chancha}) ->
    isTsumo and virgin and agariPlayer != chancha


  # tehai-only
  tanyaochuu: (decomp, {tehai, rulevar, menzen}) ->
    # kuitan => okay if not menzen
    (menzen or rulevar.yaku.kuitan) and tehai.every (.isChunchanpai)
  tsuuiisou: (decomp, {tehai}) ->
    tehai.every (.isTsuupai)
  ryuuiisou: (decomp, {tehai}) ->
    tehai.every (in Pai<[2s 3s 4s 6s 8s 6z]>)
  chinraotou: (decomp, {tehai}) ->
    tehai.every (.isRaotoupai)
  honraotou: (decomp, {tehai}) ->
    tehai.every (.isYaochuupai) # NOTE: no need to exclude kokushi


  # bins-only

  # dai/shou-suushi: 1234z
  daisuushi: (decomp, {bins}) ->
    with decomp.suushi = suushi = bins.3[0 1 2 3].sort!
      return ..0 >= 3 and ..1 >= 3 and ..2 >= 3 and ..3 >= 3
  shousuushi: (decomp) ->
    with decomp.suushi
      return ..0 == 2 and ..1 >= 3 and ..2 >= 3 and ..3 >= 3

  # dai/shou-sangen: 567z
  daisangen: (decomp, {bins}) ->
    with decomp.sangen = sangen = bins.3[4 5 6].sort!
      return ..0 >= 3 and ..1 >= 3 and ..2 >= 3
  shousangen: (decomp) ->
    with decomp.sangen
      return ..0 == 2 and ..1 >= 3 and ..2 >= 3

  # yakuhai = bakaze + jikaze + sangenpai
  bakazehai: (decomp, {bins, bakaze}) -> bins.3[bakaze] >= 3
  jikazehai: (decomp, {bins, jikaze}) -> bins.3[jikaze] >= 3
  sangenpaiHaku:  (decomp, {bins})    -> bins.3.4       >= 3
  sangenpaiHatsu: (decomp, {bins})    -> bins.3.5       >= 3
  sangenpaiChun:  (decomp, {bins})    -> bins.3.6       >= 3

  # chinn/honn-iisou (aka chinn/honn-itsu)
  chinniisou: (decomp, {binsSum}) ->
    decomp.binsSumSort = a = binsSum[0 1 2].sort!
    binsSum.3 == 0 and a.0 == 0 and a.1 == 0 and a.2 > 0
  honniisou: (decomp) ->
    a = decomp.binsSumSort
    a.0 == 0 and a.1 == 0 and a.2 > 0

  # jun/chuuren:
  #     [3 1 2 1 1 1 1 1 3]
  #   - [3 1 1 1 1 1 1 1 3]
  # --------------------------
  #     [0 0 1 0 0 0 0 0 0]
  #
  # if the odd one is agariPai => junsei
  junseichuurenpoutou: (decomp, {menzen, bins, agariPai}) ->
    if not menzen then return false
    s = agariPai.S
    if s == 3 then return false
    a = bins[s].slice!
    a.0 -= 3
    for i from 1 to 7 => a[i]--
    a.8 -= 3
    n = null
    for i til 9 => switch a[i]
    | 1 =>
      if n? then return false
      n = i
    | 0 => void
    | _ => return false
    decomp.chuurenpoutou = true
    return n == agariPai.N
  chuurenpoutou: (decomp) -> !!(decomp.chuurenpoutou)


  # koutsu-only

  # 4/3-anko(u)/tanki
  suuankouTanki: (decomp, {menzen}) ->
    decomp.anko = anko = count decomp.mentsu, (.type == \anko)
    menzen and anko == 4 and decomp.wait == \tanki
  suuankou: (decomp, {menzen}) ->
    menzen and decomp.anko == 4
  sannankou: (decomp) ->
    decomp.anko == 3

  # 4/3-kantsu
  suukantsu: (decomp, {fuuro}) ->
    decomp.kantsu = kantsu =
      count fuuro, (.type in <[daiminkan ankan kakan]>)
    kantsu == 4
  sankantsu: (decomp) ->
    decomp.kantsu == 3

  # toitoi
  toitoihou: (decomp, {fuuro}) ->
    !decomp.k7? and
    fuuro.every (.type != \minjun) and
    decomp.mentsu.every (.type != \shuntsu)


  # mentsu matching

  # 2/1-peikou: # of identical shuntsu pairs
  ryanpeikou: (decomp) ->
    shuntsu = {}
    peikou = 0
    for m in decomp.mentsu
      if m.type == \shuntsu
        with m.anchor.toString!
          if shuntsu[..]
            shuntsu[..] = false
            peikou++
          else
            shuntsu[..] = true
    decomp.peikou = peikou
    return peikou == 2
  iipeikou: (decomp) -> decomp.peikou == 1

  # 1-tsuu: 123, 456, 789 in one of the suites
  ikkitsuukan: (decomp, {fuuro}) ->
    a = [[0 0 0], [0 0 0], [0 0 0]]
    for f in fuuro
      if f.type == \minjun and f.anchor.N in [0 3 6]
        a[f.anchor.S][f.anchor.N/3]++
    # parallel
    for m in decomp.mentsu
      if m.type == \shuntsu and m.anchor.N in [0 3 6]
        a[m.anchor.S][m.anchor.N/3]++
    (a.0.0 and a.0.1 and a.0.2) or
    (a.1.0 and a.1.1 and a.1.2) or
    (a.2.0 and a.2.1 and a.2.2)

  # sanshoku: 3 shuntsu with same number in each suite
  sanshokudoujun: (decomp, {fuuro}) ->
    a = [[], [], []]
    for f in fuuro
      if f.type == \minjun
        a[f.anchor.S][f.anchor.N] = true
        if a[0][f.anchor.N] and a[1][f.anchor.N] and a[2][f.anchor.N]
          return true
    # parallel
    for m in decomp.mentsu
      if m.type == \shuntsu
        a[m.anchor.S][m.anchor.N] = true
        if a[0][m.anchor.N] and a[1][m.anchor.N] and a[2][m.anchor.N]
          return true
    return false

  # sandoukou: 3 koutsu/kantsu with same number in each suite
  sanshokudoukou: (decomp, {fuuro}) ->
    a = [[], [], []]
    for f in fuuro
      if f.type != \minjun  and f.anchor.isSuupai
        a[f.anchor.S][f.anchor.N] = true
        if a[0][f.anchor.N] and a[1][f.anchor.N] and a[2][f.anchor.N]
          return true
    # parallel
    for m in decomp.mentsu
      if m.type != \shuntsu and m.anchor.isSuupai
        a[m.anchor.S][m.anchor.N] = true
        if a[0][m.anchor.N] and a[1][m.anchor.N] and a[2][m.anchor.N]
          return true
    return false

  # jun/hon-chanta:
  # - jantou : 11/99
  # - koutsu : 111/999
  # - shuntsu: 123/789
  junchantaiyaochuu: (decomp, {fuuro, binsSum}) ->
    if decomp.k7 then return false
    if decomp.jantou.isChunchanpai then return false
    for f in fuuro
      if f.anchor.isTsuupai then continue
      if f.type == \minjun
        if f.anchor.N not in [0 6] then return false
      else
        if f.anchor.N not in [0 8] then return false
    # parallel
    for m in decomp.mentsu
      if m.anchor.isTsuupai then continue
      if m.type == \shuntsu
        if m.anchor.N not in [0 6] then return false
      else
        if m.anchor.N not in [0 8] then return false
    decomp.honchantaiyaochuu = true
    return binsSum.3 == 0
  honchantaiyaochuu: (decomp) -> !!(decomp.honchantaiyaochuu)
