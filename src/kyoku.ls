# kyoku {round}
# A complete game {chan} consists of a number of mutually independent kyoku's.
# Most of the game logic is implemented in this module.

require! {
  'events': {EventEmitter}
  './decomp.js': {decompDiscardTenpai, decompTenpai, decompAgari}
  './pai.js': Pai
}

module.exports = class Kyoku implements EventEmitter::
  # start a new kyoku with `init` (immutable):
  #   bakaze: 0/1/2/3 => E/S/W/N
  #   nKyoku: 1/2/3/4
  #   honba: >= 0
  #   kyoutaku: >= 0
  #   tenbou: array of score/points/sticks of each player
  # e.g. {1 3 2 1} =>
  # - Nan {South} 3 Kyoku {Round}
  # - current dealer = player 2
  # - 2 Honba (dealer has renchan'd twice)
  # - 1*1000 kyoutaku {riichi bet} on table
  #
  # NOTE:
  # - tenbou does not take into account of riichi kyoutaku within this round
  #   actual value is 1000 less if in valid riichi state
  #
  # TODO: doc rulevar
  (@init, @rulevar, wall = null) ->
    EventEmitter.call @
    # divide wall:                  136         cumulative sum
    #   haipai {initial deal}       13*4 = 52   52
    #   piipai {live wall}          70          122
    #   dora hyoujihai {indicator}  5*2         132
    #   rinshan {kan tsumo}         4           136
    #
    # NOTE:
    #
    # - wall defaults to shuffled (can be given instead e.g. for testing)
    #
    # - orders are different from table-top practices as shuffling is i.i.d.
    #   uniform and unpredictable (of course depending on PRNG quality)
    #   - both piipai and rinshan are drawn from tail (`.pop()`)
    #   - when rinshan is drawn, remove one from head of piipai (`.shift()`)
    #   - even though internal representation is simplified, client may choose
    #     to visualize in a way analogous to table-top play
    #
    # - dora handling:
    #   - @globalHidden.doraHyouji: always the original 5*2 tiles
    #     [0] => omote {up}, [1] => ura {down}
    #   - @globalPublic.doraHyouji: revealed ones
    #   - @globalPublic.dora: corresponding actually indicated dora
    wall = Pai.shuffleAll @rulevar.dora.akapai
    haipai =
      wall[0  til 13]
      wall[13 til 26]
      wall[26 til 39]
      wall[39 til 52]
    piipai = wall[52 til 122]
    doraHyouji =
      wall[122 til 127]
      wall[127 til 132]
    rinshan = wall[132 til 136]

    # player id:
    #   chancha {dealer}
    #   playerSeq: by jikaze {seat wind} order
    chancha = init.nKyoku - 1
    @playerSeq = seq =
      (chancha + 0)%4 #  ton   east  (chancha)
      (chancha + 1)%4 #  nan   south
      (chancha + 2)%4 #  shaa  west
      (chancha + 3)%4 #  pei   north

    # all mutable states
    @globalHidden =
      piipai
      rinshan
      doraHyouji
    @globalPublic =
      kyoutaku: @init.kyoutaku # increases as riichi succeeds
      nPiipaiLeft: 70
      nKan: 0 # increases as player completes kan (up to 4)
      doraHyouji: []
      dora: []
      player: chancha
      state: @BEGIN # see below state machine
      activeAction: null # see below TODO doc
      result: null # result of this kyoku
    @playerHidden = [new PlayerHidden i, haipai[i] for i til 4]
    @playerPublic = [new PlayerPublic i, seq[i]    for i til 4]

    # reveal initial dora {motodora}
    @_revealDoraHyouji\init

    # kyoku ready


  # internal methods (with underscore prefix)

  # kyoku state machine
  # e.g. `@AFTER_TSUMO`
  #
  STATE_LIST: STATE_LIST = <[
    BEGIN
    NORMAL_START NORMAL_QUERY NORMAL_END
    KAN_QUERY KAN_SUCCESS
    RIICHI_DAHAI RIICHI_QUERY RIICHI_SUCCESS
    END
  ]>
  STATE_LIST.map ~> @[it] = [it]

  # run the state machine until player action is needed to proceed
  _advance: !->
    {player, state} = @globalPublic
    switch state
    | @BEGIN          => @_tsumo!
    | @END            => @_finish!
    # normal turn flow (`player`'s turn)
    | @NORMAL_START   => @emit \turn , \normal, player, @
    | @NORMAL_QUERY   => @emit \query, \normal, player, @
    | @NORMAL_END     => @_endTurn!
    # kan (declared by `player`)
    | @KAN_QUERY      => @emit \query, \kan   , player, @
    | @KAN_SUCCESS    => @_kan!
    # riichi (declared by `player`)
    | @RIICHI_DAHAI   => @emit \turn , \riichi, player, @
    | @RIICHI_QUERY   => @emit \query, \riichi, player, @
    | @RIICHI_SUCCESS => @_riichi!
    #
    | _ => throw new Error "riichi-core: kyoku: _advance: bad state (#state)"


  # reveal dora hyoujihai(s)
  # previously delayed kan-dora will always be revealed
  # type: \init, \daiminkan, \kakan, \ankan
  #
  # see rule variations: `.dora.kan`
  _revealDoraHyouji: (type) !->
    # shorthands (too messy using `with`)
    ghdh = @globalHidden.doraHyouji[0]
    gpdh = @globalPublic.doraHyouji
    gpd  = @globalPublic.dora
    rule = @rulevar.dora.kan

    begin = gpdh.length
    end = if rule then @globalPublic.nKan - (rule[type] ? 0) else 0
    for i from begin to end
      gpdh.push dh = ghdh[i]
      gpd.push dh.succ

  _tsumo: (rinshan = false) !->
    with @globalHidden
      if rinshan
        pai = ..rinshan.pop()
        ..piipai.shift()
      else
        pai = ..piipai.pop()
    with @globalPublic
      @playerHidden[..player].addTsumo pai
      ..state = @TURN
      ..nPiipaiLeft--
    @_advance!
  _rinshanTsumo: (player) !-> @_tsumo true

  _finish: -> ...


  # player action interface
  #
  # - "can"-prefixed methods: judge if the action is valid
  #   return: {valid, reason}: reason (string) is given if invalid
  #   NOTE: "can" methods do NOT depend on state hidden to the player
  #
  # - methods without prefix: attempt to perform the action
  #   corresponding "can"-prefixed method is called first; throw if invalid

  # helper function: check if the action is allowed in current state
  function checkStateTurn(player, states)
    with @globalPublic
      if player != ..player
        return valid: false, reason: "not your turn"
      switch ..state
      | @NORMAL_START, @RIICHI_DAHAI => yes
      | _ => return valid: false, reason: "wrong state: #{..state}"
  function checkStateQuery(player, states)
    with @globalPublic
      if player == ..player
        return valid: false, reason: "your query"
      switch ..state
      | @NORMAL_START, @RIICHI_DAHAI => yes
      | _ => return valid: false, reason: "wrong state: #{..state}"

  # declare 9-9 ryoukyoku
  # see rule variations: `.ryoukyoku.kyuushuukyuuhai`
  canKyuushuukyuuhai: (player) ->
    if player != @globalPublic.player
      return valid: false, reason: "not your turn"
    if !@rulevar.ryoukyoku.kyuushuukyuuhai
      return valid: false, reason: "not allowed by rulevar"
    with @playerPublic
      menzen = ..0.menzen && ..1.menzen && ..2.menzen && ..3.menzen
      if not menzen
        return valid: false, reason: "not menzen"
      if ..[player].sutehai.length > 0
        return valid: false, reason: "already discarded"
    nYaochuu = 0
    for pai in @playerHidden[player].juntehai
      if pai.isYaochuu then nYaochuu++
    if nYaochuu < 9
      return valid: false, reason: "only #nYaochuu*yaochuu (>= 9 needed)"
    return valid: true
  kyuushuukyuuhai: (player) !->
    {valid, reason} = @canKyuushuukyuuhai player
    if not valid
      throw new Error "riichi-core: kyoku: kyuushuukyuuhai: #reason"
    with @globalPublic
      ..state = @END
      ..result =
        type: \ryoukyoku
        renchan

  # tsumohou

  canTsumohou: (player) ->
    if player != @globalPublic.player
      return valid: false, reason: "not your turn"
    #TODO: relies on `agari`
    ...
    return valid: true
  tsumohou: (player) !->
    {valid, reason} = @canTsumohou player
    if not valid
      throw new Error "riichi-core: kyoku: tsumohou: #reason"
    ...
    with @globalPublic
      ..state = @END
      ..result =
        type: \tsumohou
        player: ..player

  # declare riichi
  # see rule variations: `.riichi`
  canRiichi: (player) ->
    if player != @globalPublic.player
      return valid: false, reason: "not your turn"
    ph = @playerHidden[player]
    pp = @playerPublic[player]
    if not pp.menzen
      return valid: false, reason: "not menzen"
    if (tenbou = @init.tenbou[player]) < 1000
      return valid: false, reason: "bankrupt (you have #tenbou, need 1000)"
    decomps = decompDiscardTenpai ph.juntehaiBins
    ...
  riichi: (player) !->
    {valid, reason} = @canRiichi player
    if not valid
      throw new Error "riichi-core: kyoku: riichi: #reason"
    @globalPublic.state = @RIICHI_DAHAI
    @_advance!

  # declare ankan
  # see rule variations: `.yaku.kokushiAnkan`
  canAnkan: (player, pai) ->
    {valid} = ret = checkStateTurn player, [@NORMAL_START]
    if not valid then return ret
    if n = @playerHidden.juntehaiBins[pai.equivNumber-1][pai.suiteNumber] < 4
      return valid: false, reason: "not enough #pai (you have #n, need 4)"
    return valid: true
  ankan: (player, pai) !->
    {valid, reason} = @canAnkan player, pai
    if not valid
      throw new Error "riichi-core: kyoku: ankan: #reason"
    if @rulevar.yaku.kokushiAnkan
      # ankan chankan possible
      @globalPublic.state = @KAN_QUERY
    else
      @globalPublic.state = @KAN_SUCCESS
    @_advance!

  # declare kakan
  canKakan: (player, pai) ->
    {valid} = ret = checkStateTurn player, [@NORMAL_START]
    if not valid then return ret
    if n = @playerHidden.juntehaiBins[pai.equivNumber-1][pai.suiteNumber] != 1
      return valid: false, reason:
        "must have exactly one #pai in juntehai (you have #n)"
    # TODO: relies on fuuro handling
    ...
  kakan: !->
    {valid, reason} = @canKakan player, pai
    if not valid
      throw new Error "riichi-core: kyoku: kakan: #reason"
    ...

  # tsumokiri
  canTsumokiri: (player) ->
    with @globalPublic
      if player != ..player
        return valid: false, reason: "not your turn"
      switch ..state
      | @NORMAL_START, @RIICHI_DAHAI => yes
      | _ => return valid: false, reason: "wrong state: #{..state}"
    return @playerPrivate.canTsumokiri!
  tsumokiri: !->
    {valid, reason} = @canTsumokiri player, pai
    if not valid
      throw new Error "riichi-core: kyoku: tsumokiri: #reason"
  dahai: !->
    ...

  endQuery: !->
    with @globalPublic
      switch ..state
      | @QUERY => ..state = @NORMAL_END
      | @QUERY_CHANKAN => ..state = @KAN
    @_advance!


class PlayerHidden
  (@id, haipai) ->
    @juntehai = haipai
    @juntehaiBins = Pai.binsFromArray haipai
    @tsumo = null
    @sutehaiFuriten = false
    @doujunFuriten = false
    @riichiFuriten = false

  # juntehai actions
  # without tsumo: 13 tiles, can `addTsumo`
  # with    tsumo: 14 tiles, can either `tsumokiri` or `dahai`

  canAddTsumo: ->
    if !@tsumo? then return valid: true
    return valid: false, reason: "already has tsumo (#{@tsumo})"
  addTsumo: (pai) !->
    @juntehaiBins[pai.equivNumber-1][pai.suiteNumber]++
    @tsumo = pai

  canTsumokiri: ->
    if !@tsumo? then return valid: false, reason: "no tsumo"
    return valid: true
  tsumokiri: !->
    {valid, reason} = @canTsumokiri!
    if not valid
      throw new Error "riichi-core: kyoku: PlayerHidden: tsumokiri: #reason"
    pai = @tsumo
    @juntehaiBins[pai.equivNumber-1][pai.suiteNumber]--
    @tsumo = null

  canDahai: (pai) ->
    if !@tsumo? then return valid: false, reason: "no tsumo"
    for p, i in @juntehai
      if p == pai then break
    if p != pai
      return valid: false, reason:
        "#{pai} not in player #{@id}'s juntehai #{Pai.stringFromArray a}"
    return valid: true, i: i
  dahai: (pai) !->
    {valid, reason, i} = @canDahai pai
    if not valid
      throw new Error "riichi-core: kyoku: PlayerHidden: dahai: #reason"
    @juntehaiBins[pai.equivNumber-1][pai.suiteNumber]--
    @juntehai
      ..[i] = @tsumo
      ..sort Pai.compare

class PlayerPublic
  (@id, @jikaze) ->
    # sutehai {discarded tile}:
    #   fuuroPlayer:
    #     claimed by a player through chi/pon/kan => id of this player
    #     otherwise => null
    #   sutehaiBitmap: for fast check of `sutehaiFuriten` condition
    #     same convention as `Pai.binFromBitmap`
    #   lastSutehai == sutehai[*-1]
    @sutehai = []
    @sutehaiBitmaps = [0 0 0 0]
    @lastSutehai = null

    @fuuro = []
    @menzen = true # NOTE: menzen != no fuuro (due to ankan {concealed kan})
    @riichi = false
    @doubleRiichi = false
    @ippatsu = false
    @kan = null # valid: null, \daiminkan, \kakan, \ankan

  tsumokiri: (pai) -> @dahai pai, true
  dahai: (pai, tsumokiri = false) ->
    @sutehaiBitmaps[pai.suiteNumber] .|.= 1 .<<. (pai.equivNumber-1)
    with {pai, tsumokiri, fuuroPlayer: null}
      @sutehai.push ..
      @lastSutehai = ..
      return ..

# determine if a player has indeed tsumohou'd or ron'd, and if yes, determine
# the hand decomposition that maximizes tokuten {score/points gain}
function agari(kyoku, player)
  ...
